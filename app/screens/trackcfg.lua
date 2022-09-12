-- Copyright 2017-2022 Jason Tackaberry
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local rtk = require 'rtk'
local rfx = require 'rfx'
local reabank = require 'reabank'
local feedback = require 'feedback'
local log = rtk.log

local screen = {
    minw = 250,
    max_bankui_width = 650,
    widget = nil,
    -- VBox containing the list of banks
    banklist = nil,
    -- The track whose configuration is currently visible.
    track = nil,
    -- The rtk.OptionList for the track select feedback message menu
    track_select_feedback_menu = nil,
    -- The max (i.e. worst) error affecting the current track, as determined by
    -- check_errors*()
    error = nil
}

local function channel_menu_to_channel(id)
    local n = tonumber(id)
    return n & 0xff, (n & 0xff00) >> 8
end

local function printable_guid(guid, name)
    -- As of Reaticulate 0.5, the bank name is included in the track data, so we can know
    -- it even if the bank is missing from the system.  It will not be present on banks
    -- added with older versions.
    local prefix = name and string.format('%s with ', name) or ''
    if type(guid) == 'number' or tonumber(guid) then
        guid = tonumber(guid)
        -- If GUID is a number rather than a string then it means this is an old style
        -- MSB/LSB bank reference that we couldn't resolve.  Translate it.
        return string.format('%sMSB/LSB %d/%d', prefix, (guid >> 8) & 0xff, guid & 0xff)
    else
        return string.format('%sGUID %s', prefix, guid)
    end
end

function screen.init()
    local vbox = rtk.VBox()
    screen.widget = rtk.Viewport{child=vbox, rpadding=10}
    screen.toolbar = rtk.HBox{spacing=0}

    -- Back button: return to bank list
    local back_button = rtk.Button{'Back', icon='arrow_back', flat=true}
    back_button.onclick = function()
        app:pop_screen()
    end
    screen.toolbar:add(back_button)
    vbox:add(rtk.Heading{'Track Articulations', margin={10, 0, 10, 10}})

    screen.banklist = vbox:add(rtk.VBox{spacing=10}, {lpadding=10})

    -- Create an artificial drop target at the bottom of the list so that it's
    -- possible to drag a bank to the end of the list.
    local spacer = rtk.Spacer{h=1.0, w=1.0, y=0, z=10, position='absolute'}
    spacer.ondropfocus = function(self, event, src, srcbankbox)
        screen.move_bankbox(srcbankbox, nil)
        return true
    end
    vbox:add(spacer)

    local add_bank_button = rtk.Button{label='Add Bank to Track', icon='add_circle_outline', color='#2d5f99'}
    add_bank_button.onclick = function()
        if #screen.banklist.children >= rfx.MAX_BANKS then
            reaper.ShowMessageBox("You have reached the limit of banks for this track.",
                                  "Too many banks :(", 0)
        else
            local bankbox = screen.create_bank_ui(nil, 17, 17, 1)
            screen.banklist:add(bankbox, {xmaxw=screen.max_bankui_width})
            bankbox.bank_menu.onchange()
        end
    end
    vbox:add(add_bank_button, {lpadding=20, tpadding=20})

    vbox:add(rtk.Heading{'Track Tweaks', margin={40, 0, 10, 10}})
    local section = vbox:add(rtk.VBox{spacing=10, margin={0, 10, 0, 20}})
    section:add(rtk.Button{
        'Fix numeric articulation names',
        icon='auto_fix',
        tooltip='Removes any non-Reaticulate ReaBank assignment from this track to ' ..
                'fix numeric Program Change event names (e.g. 43-1-22)',
        flat=true,
        onclick=function()
            -- Before we do anything, check for the obvious: if we have any unknown banks
            -- assigned to the track then that's the obvious problem, and that needs
            -- user intervention.
            if screen.error == rfx.ERROR_UNKNOWN_BANK then
                return reaper.MB(
                    "This track has banks assigned that aren't currently installed on this system, " ..
                    "which is the likely cause of numeric articulation names.\n\nPlease first select " ..
                    "an available bank.",
                    'User action required',
                    0
                )
            end
            local cleared = app:clear_track_reabank_mapping(rfx.current.track)
            if cleared then
                log.info('trackcfg: cleared non-Reaticulate bank on current track')
            end
            app:force_recognize_bank_change_one_track(rfx.current.track)
            local n_remapped = 0
            if #screen.banklist.children == 1 then
                -- With just one bank mapped on this track, there's no ambiguity: we can update
                -- all bank selects to this bank's current MSB/LSB.
                local bankbox = screen.banklist:get_child(1)
                local guid = bankbox.bank_menu.selected_id
                local bank = reabank.get_bank_by_guid(guid)
                n_remapped = remap_bank_select(rfx.current.track, nil, bank)
                log.info('trackfg: remapped %s bank select events on track', n_remapped)
            end
            rtk.defer(
                reaper.MB,
                "Reaticulate tried to correct common issues causing numeric articulation names" ..
                ((cleared or n_remapped > 0) and ' (and did find some things to fix)' or '') ..
                ".\n\nIf you still see numeric articulation names, the likely reason is that " ..
                "the articulations don't actually exist in the current banks assigned to this track. " ..
                "This is usually caused by inserting articulations with some other bank and then " ..
                "later removing that bank from the track.\n\nIf that's the case, you'll need " ..
                "to replace the articulations in the MIDI editor manually.",
                'Fix Numeric Articulation Names',
                0
            )
        end
    })
    section:add(rtk.Button{
        'Clear active articulations in UI',
        icon='eraser',
        tooltip='Clears all articulation selections on all channels in the GUI. This can also be done per ' ..
                'articulation by middle-clicking the articulation.',
        flat=true,
        onclick=function()
            local n = app.screens.banklist.clear_all_active_articulations()
            local msg = string.format('Cleared %d articulation assignments on this track', n)
            rtk.defer(reaper.MB, msg, 'Clear Articulations', 0)
        end
    })

    vbox:add(rtk.Heading{'Advanced Settings', margin={40, 0, 10, 10}})
    local section = vbox:add(rtk.VBox{spacing=10, margin={0, 10, 0, 20}})
    screen.create_track_feedback_option(section)

    -- Build menus for src and dst channels which will be used in create_bank_ui().
    screen.src_channel_menu = {{'Omni', id=17}}
    for i = 1, 16 do
        screen.src_channel_menu[#screen.src_channel_menu+1] = {
            string.format('Ch %d', i),
            id=i
        }
    end

    screen.dst_channel_menu = {
        {'Bus 1', disabled=true},
        rtk.NativeMenu.SEPARATOR,
        {'Source', id=17 | (1 << 8)}
    }
    for i = 1, 16 do
        screen.dst_channel_menu[#screen.dst_channel_menu+1] = {
            string.format('Ch %d', i),
            id=i | (1 << 8)
        }
    end
    screen.dst_channel_menu[#screen.dst_channel_menu+1] = rtk.NativeMenu.SEPARATOR
    for i = 2, 16 do
        local submenu = {{'Source', id=17 | (i << 8), altlabel=string.format('%d/Source', i, 0)}}
        for j = 1, 16 do
            submenu[#submenu + 1] = {
                string.format('Ch %d', j),
                id=j | (i << 8),
                altlabel=string.format('Ch %d/%d', i, j)
            }
        end
        screen.dst_channel_menu[#screen.dst_channel_menu+1] = {
            string.format('Bus %d', i),
            submenu=submenu
        }
    end
    screen.update()
end

function screen.create_track_feedback_option(section)
    local tooltip =
        "Sends the given MIDI message(s) to the control surface (configured in Reaticulate's " ..
        "settings) whenever this track is selected.\n\nThis message is sent before the " ..
        "messages for current articulation and current CC values."
    local row = section:add(rtk.HBox{spacing=10, valign='center'})
    row:add(rtk.Text{
        'Feedback on Track Select',
        xfontflags=rtk.font.BOLD,
        tooltip=tooltip,
    })
    local subsection = section:add(rtk.VBox{spacing=10, maxw=350})
    -- rtk.VBox for the input values of each of the different feedback types
    local options = {}
    local row = subsection:add(rtk.HBox{spacing=10, lpadding=10, valign='center'})
    -- Width of the label (simulated) column
    local labelw = 45
    row:add(rtk.Text{'MIDI:', w=labelw, halign='right', tooltip=tooltip})

    local menu = row:add(rtk.OptionMenu{tooltip=tooltip}, {fillw=true})
    menu:attr('menu', {
        {'Disabled', id='disabled', args={}},
        {'Bank Select', id='bankselect', args={'MSB #', 'LSB #'}},
        {'Program Change', id='program', args={'Program #'}},
        {'CC', id='cc', args={'CC #', 'Val'}},
        {'Note', id='note', args={'Note #', 'Vel'}},
        {'Note On', id='note-on', args={'Note #', 'Vel'}},
        {'Note Off', id='note-off', args={'Note #', 'Vel'}},
        {'Raw MIDI', id='raw', args={'MIDI hex bytes'}},
    })
    -- Generate table used for creating channel OptionList
    local channels = {}
    for i = 1, 16 do
        channels[#channels+1] = string.format('Ch %d', i)
    end
    -- Forward declaration of error rtk.Text widget, which we instantiate later but
    -- reference in feedback_data_onchange()
    local error
    -- Shared event handler when any of the option values change
    local feedback_data_onchange = function()
        -- Construct messages table based on UI configuration. Internally, feedback
        -- supports multiple MIDI messages but the UI only surfaces one for now.
        local msgs = {}
        local item = menu.selected_item
        local selected = menu.selected_index
        local row = options[selected]
        if row then
            -- Get current values
            local data1 = row.data1.value
            local data2 = row.data2 and row.data2.value
            local channel = row.channel and row.channel.selected_index
            if item.id == 'raw' then
                -- Raw messages have no channel or second data byte
                msgs[#msgs+1] = {type=item.id, data1=data1}
            else
                msgs[#msgs+1] = {type=item.id, channel=channel, data1=data1, data2=data2}
            end
        end
        rfx.current:set_track_data('track_select_feedback', msgs)
        local _, errmsg = rfx.current:sync_custom_feedback_events()
        -- If there was some parse or validation error, display the message
        error:attr('visible', errmsg and true or false)
        if errmsg then
            error:attr('text', errmsg)
        end
    end

    for n, item in ipairs(menu.menu) do
        if item.id ~= 'disabled' then
            local row = subsection:add(rtk.HBox{spacing=10, lpadding=10+10+labelw, valign='center'})
            options[n] = row
            if item.id == 'raw' then
                row.data1 = row:add(rtk.Entry{
                    placeholder='MIDI hex bytes',
                    textwidth=9,
                    tooltip='Arbitrarily many MIDI events (including SysEx) expressed as hexadecimal octets.' ..
                            '\n\nFor example, "90 09 42 f0 a0 08 ee f7 80 09 00"'
                }, {fillw=true})
            else
                row.data1 = row:add(rtk.Entry{placeholder=item.args[1]})
                if #item.args == 2 then
                    row.data2 = row:add(rtk.Entry{placeholder=item.args[2]})
                    row.data2.onchange = feedback_data_onchange
                end
                row.channel = row:add(rtk.OptionMenu{channels, selected=1}, {fillw=true})
                row.channel.onchange = feedback_data_onchange
            end
            row.data1.onchange = feedback_data_onchange
            row:hide()
        end
    end
    -- FIXME: error won't be initialized until user interacts with text entries
    error = subsection:add(rtk.Text{color='#ff5266', lpadding=10+10+labelw, tmargin=-8, visible=false})
    menu.onchange = function(menu, item, last)
        local lastrow = last and options[last.index]
        if lastrow then
            lastrow:hide()
        end
        local newrow = item and options[item.index]
        if newrow then
            local msgs = rfx.current:get_track_data('track_select_feedback')
            -- RFX supports multiple messages but we only surface one in the UI for now.
            local msg = msgs and msgs[1]
            if newrow.channel then
                newrow.channel:select(msg and msg.channel or 1, false)
            end
            -- If we toggled between non-raw types preserve data byte 1, otherwise clear it
            local keepd1 = not last or (last.id ~= 'raw' and item.id ~= 'raw')
            -- Only set data values if we've selected the same type as the persisted message
            newrow.data1:attr('value', msg and keepd1 and msg.data1, false)
            if newrow.data2 then
                newrow.data2:attr('value', msg and msg.data2, false)
            end
            newrow:show()
        end
        if item and last then
            -- If both new and last selection is set then we've changing the type, in
            -- which case we invoke the Entry handler to force a sync to the RFX.
            feedback_data_onchange()
        end
        error:hide()
    end
    -- Add a screen-level reference for use in update()
    screen.track_select_feedback_menu = menu
end

function screen.set_banks_from_banklist()
    local banks = {}
    for n = 1, #screen.banklist.children do
        local bankbox = screen.banklist:get_child(n)
        local srcchannel, _ = channel_menu_to_channel(bankbox.srcchannel_menu.selected_id)
        local dstchannel, dstbus = channel_menu_to_channel(bankbox.dstchannel_menu.selected_id)
        local guid = bankbox.bank_menu.selected_id or bankbox.fallback_guid
        assert(guid, string.format('missing guid: bankbox.guid is %s (%s)', bankbox.guid, type(bankbox.guid)))
        -- This can be nil if we have a reference to a non-existent bank on the system.
        -- We pass the name to set_banks() if we know it.
        local bank = reabank.get_bank_by_guid(guid)
        banks[#banks+1] = {guid, srcchannel, dstchannel, dstbus, bank and bank.name or bankbox.fallback_name}
        if bank then
            reabank.add_bank_to_project(bank)
        end
    end
    rfx.current:set_banks(banks)
    screen.check_errors_and_update_ui()
    -- This will also write appdata (which contains the bank list and error
    -- code) to the rfx.
    rfx.current:sync_banks_to_rfx()
    app.screens.banklist.update()
    app:queue(App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK)
end

-- Position: -1 = before, 1 = after.  If target is nil, then always move to
-- bottom.
function screen.move_bankbox(bankbox, target, position)
    if not rtk.isa(bankbox, rtk.Box) or bankbox == target then
        -- Nothing to move.
        return false
    end
    if target then
        local bankboxidx = screen.banklist:get_child_index(bankbox)
        local targetidx = screen.banklist:get_child_index(target)
        if bankboxidx > targetidx and position < 0 then
            screen.banklist:reorder_before(bankbox, target)
        elseif targetidx > bankboxidx and position > 0 then
            screen.banklist:reorder_after(bankbox, target)
        end
    else
        screen.banklist:reorder(bankbox, #screen.banklist.children + 1)
    end
    return true
end

function screen.move_bankbox_finish()
    screen.set_banks_from_banklist()
end

function screen.create_bank_ui(guid, srcchannel, dstchannel, dstbus, name)
    local bankbox = rtk.VBox{
        spacing=10,
        tpadding=10,
        bpadding=10,
        -- Invisible border so we occupy the same space when dragging (where
        -- a border *is* visible)
        tborder={'#00000000', 2},
        bborder={'#00000000', 2},
    }
    local banklist_menu_spec = reabank.to_menu()
    local row = bankbox:add(rtk.HBox{spacing=10})

    -- Fallbacks in case bank_menu.selected_id is nil, which can happen when initializing
    -- to a missing bank.  That is, the RFX bankinfo indicates a bank that is not
    -- available on the system.  So we propagate the guid (which can either be a
    -- proper guid, or a legacy msblsb string) as well as the bank name
    bankbox.fallback_guid = guid
    bankbox.fallback_name = name

    bankbox.ondropfocus = function(self, event, _, srcbankbox)
        return true
    end
    bankbox.ondropmousemove = function(self, event, dragging, srcbankbox)
        if self ~= srcbankbox and dragging.bankbox then
            local rely = event.y - self.clienty - self.calc.h / 2
            if rely < 0 then
                screen.move_bankbox(srcbankbox, bankbox, -1)
            else
                screen.move_bankbox(srcbankbox, bankbox, 1)
            end
        end
    end

    -- Bank row
    local drag_handle = rtk.ImageBox{
        image=rtk.Image.make_icon('drag_vertical:large'),
        cursor=rtk.mouse.cursors.REAPER_HAND_SCROLL,
        halign='center',
        show_scrollbar_on_drag=true,
        tooltip='Click-drag to reorder bank'
    }
    -- Used by ondropmousemove() above to ensure the widget being dragged is a bankbox and
    -- not something incompatible (like e.g. the resize handle for undocked windows).
    drag_handle.bankbox = true
    drag_handle.ondragstart = function(event)
        bankbox:attr('bg', '#5b7fac30')
        bankbox:attr('tborder', {'#497ab7', 2})
        bankbox:attr('bborder', bankbox.tborder)
        return bankbox
    end
    drag_handle.ondragend = function(event)
        bankbox:attr('bg', nil)
        bankbox:attr('tborder', {'#00000000', 2})
        bankbox:attr('bborder', bankbox.tborder)
        screen.move_bankbox_finish()
    end
    drag_handle.onmouseenter = function() return true end
    row:add(drag_handle)
    local bank_menu = rtk.OptionMenu()
    row:add(bank_menu, {expand=1, fillw=true, rpadding=0})
    bankbox.bank_menu = bank_menu
    bank_menu:attr('menu', banklist_menu_spec)

    -- If guid is nil it means we're initializing a fresh bank and just select the
    -- first item.
    bank_menu:select(guid and tostring(guid) or 1, false)
    if not bank_menu.selected_id then
        -- Bank was not found on the local system.
        local label = string.format('Unknown Bank (%s)', printable_guid(guid))
        bankbox.bank_menu:attr('label', label)
    end

    -- Channel row
    local row = bankbox:add(rtk.HBox{spacing=10})
    row:add(rtk.Spacer{w=24, h=24})

    bankbox.srcchannel_menu = rtk.OptionMenu{
        tooltip='Source MIDI channel for bank'
    }
    row:add(bankbox.srcchannel_menu, {lpadding=0, expand=1, fillw=true})
    bankbox.srcchannel_menu:attr('menu', screen.src_channel_menu)
    bankbox.srcchannel_menu:select(tostring(srcchannel), false)

    row:add(rtk.Text{'→'}, {valign='center'})

    bankbox.dstchannel_menu = rtk.OptionMenu{
        tooltip='Destination MIDI channel/bus when articulations do not specify an explicit destination channel'
    }
    row:add(bankbox.dstchannel_menu, {lpadding=0, expand=1, fillw=true})
    bankbox.dstchannel_menu:attr('menu', screen.dst_channel_menu)
    bankbox.dstchannel_menu:select(tostring(dstchannel | (dstbus << 8)), false)


    local delete_button = rtk.Button{
        icon='delete',
        color='#9f2222',
        tooltip='Remove bank from track',
    }
    delete_button.delete=true
    row:add(delete_button)
    delete_button.onclick = function()
        -- TODO: provide some means of undo (a la mobile phones)
        screen.banklist:remove(bankbox)
        screen.set_banks_from_banklist()
    end

    bankbox.bank_menu.onchange = function(self, item, last)
        local bank = reabank.get_bank_by_guid(bankbox.bank_menu.selected_id)
        local slot = screen.banklist:get_child_index(bankbox)
        if not slot then
            -- Shouldn't be possible, but handle it anyway.
            log.error("trackcfg: can't find bank in bank list")
            return
        end
        screen.set_banks_from_banklist()
        if bank.off ~= nil then
            -- New bank with off program.  Activate that program now.
            local art = bank:get_articulation_by_program(bank.off)
            if art then
                app:activate_articulation(art)
            end
        end
        -- We want to migrate Bank Selects on this track from the old bank's MSB/LSB to
        -- the new bank's MSB/LSB.

        -- false acts as a sentinel, because nil has meaning
        local remap_from = false
        if #screen.banklist.children == 1 then
            -- There's just a single bank assigned to this track, so we can remap all Bank
            -- Selects to the new bank.
            remap_from = nil
        elseif last and last.id then
            -- The last menu item has been provided so we know the bank's GUID
            remap_from = reabank.get_bank_by_guid(last.id) or false
        elseif bankbox.fallback_guid then
            -- We have a fallback GUID, which is actually either a proper GUID or a
            -- stringified packed MSB/LSB number.
            local frommsb, fromlsb
            local msblsb = tonumber(bankbox.fallback_guid)
            if msblsb then
                -- Missing bank is referenced by a legacy MSB/LSB
                frommsb = (msblsb >> 8) & 0xff
                fromlsb = msblsb & 0xff
            else
                -- Missing bank is referenced by new-style GUID.
                frommsb, fromlsb = reabank.get_project_msblsb_for_guid(bankbox.fallback_guid)
            end
            if frommsb then
                remap_from = {frommsb, fromlsb}
            end
        end
        if remap_from ~= false then
            -- Remap existing Bank Selects via defer so that we do it *after*
            -- App:refresh_banks() has a chance to run.  This avoids a flicker in the
            -- arrange view when selecting a new bank not yet in the project where, if we
            -- had called remap_bank_select() immediately, the program names would show as
            -- "PC" in the arrange view until refresh_banks() lays down the new tmp
            -- reabank and kicks the track.  Deferring ensures we do the remapping after
            -- REAPER already knows about the new bank.
            rtk.defer(remap_bank_select, rfx.current.track, remap_from, bank)
        end
        -- If the selection changed, it can only be to a valid id.  So we can clear the
        -- fallback guid and name for this bankbox.
        bankbox.fallback_guid = nil
        bankbox.fallback_name = nil
    end
    bankbox.srcchannel_menu.onchange = bankbox.bank_menu.onchange
    bankbox.dstchannel_menu.onchange = bankbox.bank_menu.onchange

    -- Info row
    local row = bankbox:add(rtk.HBox{spacing=10})
    bankbox.info = row
    row:add(rtk.ImageBox{'info_outline:large'}, {valign='top'})
    row.label = row:add(rtk.Text{wrap=true}, {valign='center'})

    -- Warning row
    local row = bankbox:add(rtk.HBox{spacing=10})
    bankbox.warning = row
    row:add(rtk.ImageBox{'warning_amber:large'}, {valign='top'})
    row.label = row:add(rtk.Text{wrap=true}, {valign='center'})
    return bankbox
end

-- An iterator that returns errors (if any) for each bank
function screen.get_errors()
    local conflicts = rfx.current:get_banks_conflicts()
    local get_next_bank = rfx.current:get_banks()
    local feedback_enabled = feedback.is_enabled()
    local banks = {}

    return function()
        local b = get_next_bank()
        if not b then
            -- get_banks() iterator is exhausted
            return
        end
        local bank = b.bank
        local error = rfx.ERROR_NONE
        local conflict = nil

        if not bank then
            error = rfx.ERROR_UNKNOWN_BANK
        else
            if (bank.buses & (1 << 15) > 0 or b.dstbus == 16) and feedback_enabled then
                error = rfx.ERROR_BUS_CONFLICT
            end
            if banks[bank] then
                -- Other errors take precedence but set if currently no error
                if not error then
                    error = rfx.ERROR_DUPLICATE_BANK
                end
            else
                banks[bank] = {idx=b.idx, channel=b.srcchannel}
                conflict = conflicts[bank]
                if conflict and conflict.source ~= bank then
                    -- There is a channel behaviour conflict.  Verify the channel conflict with the previously
                    -- listed bank, to rule out the possiblity of a later duplicate bank causing the conflict
                    -- (in which case the error will appear with the later bank)
                    local previous = banks[conflict.source]
                    if b.srcchannel == 17 or (previous and (previous.channel == 17 or b.srcchannel == previous.channel)) then
                        error = rfx.ERROR_PROGRAM_CONFLICT
                    end
                end
            end
        end
        return b.idx, bank, b.guid or b.v, b.name, error, conflict
    end
end

local function _max_error(a, b)
    return (a and b) and math.max(a, b) or a or b
end


-- Updates the UI according to any existing bank errors and sets rfx error accordingly.
-- Returns true if the rfx error changed, which the caller may use to decide if
-- rfx.set_appdata() should be called.
function screen.check_errors_and_update_ui()
    local error = nil
    for n, bank, guid, name, bank_error, conflict in screen.get_errors() do
        local bankbox = screen.banklist:get_child(n)

        if bank and bank.message then
            bankbox.info.label:attr('text', bank.message)
            bankbox.info:show()
        else
            bankbox.info:hide()
        end

        local errmsg = nil
        if bank_error == rfx.ERROR_BUS_CONFLICT then
            errmsg = 'Error: bank uses bus 16 which conflicts with MIDI controller feedback feature'
        elseif bank_error == rfx.ERROR_DUPLICATE_BANK then
            errmsg = 'Error: bank is already listed above.'
        elseif bank_error == rfx.ERROR_PROGRAM_CONFLICT then
            errmsg = "Error: program numbers on the same source channel conflict with " .. conflict.source.name
        elseif bank_error == rfx.ERROR_UNKNOWN_BANK then
            errmsg = string.format(
                'Error: This bank (%s) could not be found on this system ' ..
                'and will not be shown on the main screen.',
                printable_guid(guid, name)
            )
        end
        screen.set_bankbox_warning(bankbox, errmsg)
        error = _max_error(error, bank_error)
    end
    screen.error = error
    rfx.current:set_error(error)
end

-- Checks the current track banks for errors and sets rfx error accordingly.
-- This function does not depend on the UI and is meant for use when the
-- trackcfg screen is not visible.
function screen.check_errors()
    local error = nil
    for n, bank, guid, name, bank_error, conflict in screen.get_errors() do
        error = _max_error(error, bank_error)
    end
    screen.error = error
    rfx.current:set_error(error)
end

function screen.set_bankbox_warning(bankbox, msg)
    if msg then
        bankbox.warning.label:attr('text', msg)
        bankbox.warning:show()
    else
        bankbox.warning:hide()
    end
end

function screen.update()
    if not rfx.current.fx then
        return
    end
    if screen.track ~= rfx.current.track then
        -- Reset scroll position only if the track has changed.
        screen.widget:scrollto(0, 0)
        screen.track = rfx.current.track
    end
    screen.banklist:remove_all()
    for b in rfx.current:get_banks() do
        -- If the guid is nil then this must be a legacy style bank that wasn't able to be
        -- migrated (due to not being available on the system), so we fallback to the packed
        -- MSB/LSB value instead.
        local bankbox = screen.create_bank_ui(b.guid or b.v, b.srcchannel, b.dstchannel, b.dstbus, b.name)
        screen.banklist:add(bankbox)
    end
    screen.check_errors_and_update_ui()
    -- Revert current menu selection to nil.  This is a cheeky way to signal to the menu's
    -- onchange handler not to sync to the RFX when select() is called next with the *real*
    -- value.
    screen.track_select_feedback_menu:select(nil)
    local msgs = rfx.current:get_track_data('track_select_feedback')
    screen.track_select_feedback_menu:select(msgs and msgs[1] and msgs[1].type or 1)
end

return screen
