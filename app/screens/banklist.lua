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
local articons = require 'articons'
local log = rtk.log


local screen = {
    minw = 250,
    widget = nil,
    midi_channel_buttons = {},
    visible_banks = {},
    toolbar = nil,
    -- VBox that holds current track errors
    errorbox = nil,
    -- VBox that holds current track warnings
    warningbox = nil,
    -- rtk.Font instance for channel overlays
    button_font = nil,

    -- If not nil, is the hwnd of the window to be refocused after the user hits either
    -- enter or escape on the filter entry.  This is set to the current non-Reaticulate
    -- window (if applicable) by screen.focus_filter() for the "Focus articulation filter"
    -- action. articulation, the last non-Reaticulate window is refocused.
    filter_refocus_on_activation = false,
    selected_articulation = nil,

    error_msgs = {
        [rfx.ERROR_PROGRAM_CONFLICT] =
            'Some banks on this track have conflicting program numbers. ' ..
            'Some articulations may not work as expected.',
        [rfx.ERROR_BUS_CONFLICT] =
            'A bank on this track uses bus 16 which conflicts with the MIDI ' ..
            'controller feedback feature. Avoid the use of bus 16 in your banks ' ..
            "or disable MIDI feedback in Reaticulate's global settings.",
        [rfx.ERROR_DUPLICATE_BANK] =
            'The same bank is mapped to this track multiple times which is not ' ..
            'allowed.  Only one instance will appear below.',
        [rfx.ERROR_UNKNOWN_BANK] =
            'A bank assigned to this track could not be found on the local system ' ..
            'and will not be shown below.',
        default = 'There is some issue with the banks on this track. ' ..
                  'Open the Track Settings page to learn more.'
    }
}

-- SublimeText style substring match
local function get_filter_score(name, filter)
    local last_match_pos = 0
    local score = 0
    local match = false

    local filter_pos = 1
    local filter_char = filter:sub(filter_pos, filter_pos)
    for name_pos = 1, #name do
        local name_char = name:sub(name_pos, name_pos)
        if name_char == filter_char then
            local distance = name_pos - last_match_pos
            score = score + (100 - distance)
            if filter_pos == #filter then
                -- We have matched all characters in the filter term
                return score
            else
                last_match_pos = name_pos
                filter_pos = filter_pos + 1
                filter_char = filter:sub(filter_pos, filter_pos)
            end
        end
    end
    return 0
end

-- For the currently visible banks, show only articulations matching the given filter.
function screen.filter_articulations(filter)
    for _, bank in ipairs(screen.visible_banks) do
        for _, art in ipairs(bank.articulations) do
            -- TODO: indicate in the UI the match with the highest score and ensure hitting enter
            -- selects that one.
            local score = -1
            if filter:len() > 0 then
                score = get_filter_score((art.shortname or art.name):lower(), filter)
            end
            -- Show articulation if the score is non-zero (in which case there is a match).
            -- We don't further filter based on the bank's source channel vs the current
            -- default channel (as we once did).
            if score ~= 0 then
                if not art.button.visible then
                    art.button:show()
                end
            elseif art.button.visible then
                art.button:hide()
            end
        end
    end
end

local function handle_filter_keypress(self, event)
    if event.keycode == rtk.keycodes.UP or event.keycode == rtk.keycodes.DOWN then
        -- These are handled at the app layer
        return false
    elseif event.keycode == rtk.keycodes.ESCAPE then
        if screen.filter_refocus_on_activation then
            app:refocus(screen.filter_refocus_on_activation)
        end
        screen.clear_filter()
        return true
    elseif event.keycode == rtk.keycodes.ENTER or event.keycode == rtk.keycodes.INSERT then
        local force_insert = event.shift or event.ctrl or event.keycode == rtk.keycodes.INSERT
        local insert_at_cursor = event.alt
        if self.value ~= '' then
            if screen.selected_articulation then
                app:activate_selected_articulation(nil, nil, force_insert, nil, insert_at_cursor)
            else
                local art = screen.get_firstlast_articulation()
                if art then
                    app:activate_articulation(art, nil, force_insert, nil, insert_at_cursor)
                end
            end
        end
        if screen.filter_refocus_on_activation then
            -- No articulation activation needed but we do need to refocus still.
            app:refocus(screen.filter_refocus_on_activation)
            screen.filter_refocus_on_activation = nil
        end
        rtk.defer(function()
            screen.clear_selected_articulation()
            screen.clear_filter()
        end)
        return self.value ~= ''
    end
end

function screen.draw_button_midi_channel(art, button, offx, offy, alpha, event)
    local hovering = button.hovering or button.hover
    if not hovering and not art:is_active() then
        -- No channel boxes to draw.
        return
    end

    local channels = {}
    local bitmap = art.channels
    local hover_channel = nil
    if hovering then
        local bank = art:get_bank()
        hover_channel = bank:get_src_channel(app.default_channel) - 1
        bitmap = bitmap | (1 << hover_channel)
    end

    local channel = 0
    while bitmap > 0 do
        if bitmap & 1 > 0 then
            channels[#channels+1] = channel
        end
        bitmap = bitmap >> 1
        channel = channel + 1
    end
    if channels then
        local scale = rtk.scale.value
        local calc = button.calc
        local x = offx + calc.x + calc.w
        for idx, channel in ipairs(channels) do
            local text = tostring(channel + 1)
            local lw, lh = screen.button_font:measure(text)
            x = x - lw - 12 *scale
            local y = offy + calc.y + (calc.h - lh) / 2
            local fill = (channel == hover_channel) or (rfx.active_notes & (1 << channel) > 0)
            button:setcolor('#ffffff', alpha)
            gfx.rect(x - 5*scale, y - 1*scale, lw + 10*scale, lh + 2*scale, fill)
            if fill then
                button:setcolor('#000000', alpha)
            end
            screen.button_font:draw(text, x, y + (rtk.os.mac and 1 or 0))
        end
    end
end

function screen.onartclick(art, event)
    if event.button == rtk.mouse.BUTTON_LEFT then
        -- insert at cursor if alt is pressed.
        app:activate_articulation(art, true, false, nil, event.alt)
    elseif event.button == rtk.mouse.BUTTON_MIDDLE and event.modifiers == 0 then
        -- Middle click on articulation.  Clear all channels currently assigned to that articulation.
        -- rfx.push_state(rfx.current.track)
        if screen.clear_articulation(art) > 0 then
            rfx.current:sync(rfx.current.track, true)
        end
        -- rfx.pop_state()
    elseif event.button == rtk.mouse.BUTTON_RIGHT then
        app:activate_articulation(art, true, true, nil, event.alt)
    end
end

function screen.clear_all_active_articulations()
    local cleared = 0
    for b in rfx.current:get_banks() do
        if b.bank then
            for n, art in ipairs(b.bank.articulations) do
                cleared = cleared + screen.clear_articulation(art)
            end
        end
    end
    if cleared > 0 then
        rfx.current:sync(rfx.current.track, true)
    end
    return cleared
end

-- Clears the given articulation on all channels.
--
-- Returns the number of channels that were cleared, where 0 means the articulation was
-- never active.
function screen.clear_articulation(art)
    local cleared = 0
    for channel = 0, 15 do
        if art.channels & (1 << channel) ~= 0 then
            rfx.current:clear_channel_program(channel + 1, art.group)
            cleared = cleared + 1
        end
    end
    return cleared
end

function screen.create_banklist_ui(bank)
    bank.vbox = rtk.VBox{spacing=10}
    -- Box for Bank name and info button
    local hbox = rtk.HBox()
    bank.vbox:add(hbox, {lpadding=10, tpadding=10, bpadding=10})
    -- Bank name
    bank.heading = rtk.Heading{bank.shortname or bank.name}
    hbox:add(bank.heading, {valign='center'})
    hbox:add(rtk.Box.FLEXSPACE)
    -- Bank message button, which is only added if message exists
    if bank.message then
        local button = rtk.Button{
            icon='info_outline',
            flat=true,
            alpha=bank.message and 1.0 or 0.7,
            tooltip='Toggle bank message',
        }
        hbox:add(button, {valign='center', rpadding=10})

        -- Box for bank message and info icon
        local msgbox = rtk.HBox{spacing=10, autofocus=true}
        bank.vbox:add(msgbox, {lpadding=10, rpadding=10, bpadding=10})
        -- Info icon
        msgbox:add(rtk.ImageBox{image='info_outline:large'}, {valign='top'})
        -- Bank message text
        local label = msgbox:add(rtk.Text{bank.message, wrap=true}, {valign='center'})
        -- Info button toggles visibility of message box and remembers that
        -- setting as part of the RFX bank userdata
        button.onclick = function()
            msgbox:toggle()
            button.alpha = msgbox.visible and 1.0 or 0.5
            rfx.current:set_bank_userdata(bank, 'showinfo', msgbox.visible)
        end
        -- For convenience, clicking on the message box itself also hides.
        msgbox.onclick = button.onclick
        -- Initialize visibility of box (and button opacity) based on RFX bank
        -- userdata setting, defaulting to hidden.
        msgbox:attr('visible', rfx.current:get_bank_userdata(bank, 'showinfo') or false)
        button.alpha = msgbox.visible and 1.0 or 0.5
    end

    local artbox = bank.vbox:add(rtk.FlowBox{vspacing=7, hspacing=0, lpadding=30})
    -- local artbox = bank.vbox:add(rtk.VBox{spacing=10, lpadding=30})
    for n, art in ipairs(bank.articulations) do
        local color = art.color or reabank.colors.default
        local darkicon = false
        if not color:startswith('#') then
            color = app:get_articulation_color(color)
        end
        if rtk.color.luma(color) > rtk.light_luma_threshold then
            darkicon = true
        end
        art.icon = articons.get(art.iconname, darkicon, 'note-eighth')
        art.button = rtk.Button{
            label=art.shortname or art.name,
            icon=art.icon,
            tooltip=art.message,
            color=color,
            padding=2,
            -- Enough space for 2 channel icons, which means we'll cramp over the
            -- art name with more than 2 channels mapped to this articulation (unless
            -- the window is wider and we have fill room).
            rpadding=60,
            tagged=true,
            flat=art.channels == 0 and 'label' or false,
        }
        art.button.onclick = function(button, event)
            screen.onartclick(art, event)
        end
        art.button.onlongpress = function(button, event)
            app:activate_articulation(art, true, true, nil, event.alt)
            -- Return true to prevent onclick()
            return true
        end
        art.button.ondraw = function(button, offx, offy, alpha, event)
            screen.draw_button_midi_channel(art, button, offx, offy, alpha, event)
        end
        art.button.onmouseleave = function(button, event)
            app:set_statusbar(nil)
        end
        art.button.onmouseenter = function(button, event)
            if not art.outputstr then
                art.outputstr = art:describe_outputs()
            end
            app:set_statusbar(art.outputstr)
            return true
        end
        art.button.start_insert_animation = function()
            if art.button:get_animation('color') then
                -- We're already in the middle of activating this articulation.
                return
            end
            local target
            local orig = art.button.color
            local h, s, l = rtk.color.hsl(orig)
            if rtk.color.luma(orig) > 0.8 then
                target = table.pack(rtk.color.hsl2rgb(h, s * 1.2, l * 0.8))
            else
                target = table.pack(rtk.color.hsl2rgb(h, s * 1.2, l * 1.8))
            end
            art.button:animate{attr='color', dst=target, duration=0.15, easing='out-circ'}
                :after(function()
                    art.button:animate{attr='color', dst=orig, duration=0.1, easing='out-circ'}
                end)
        end
        local tpadding = art.spacer and (art.spacer & 0xff) * 20 or 0
        -- XXX: should minw be based on longest art name in bank?  (Or, rather, across
        -- *all* banks on track otherwise columns across multiple banks will be uneven)
        artbox:add(art.button, {lpadding=0, tpadding=tpadding, fillw=true, rpadding=20, minw=250})
    end
    bank.vbox:hide()
    return bank.vbox
end

-- Shows the articulation banks for the current track in the order
-- defined by the track's RFX.
function screen.show_track_banks()
    if not rfx.current.fx then
        -- No FX on current track, nothing to do.
        return
    end

    -- Clear the banks list
    screen.banks:remove_all()

    -- Now (re)add all the banks to the list in the order stored in the RFX.
    local visible = {}
    local visible_by_guid = {}
    local function showbank(bank)
        if visible_by_guid[bank.guid] then
            return
        end
        if not bank.vbox then
            screen.create_banklist_ui(bank)
        end
        screen.banks:add(bank.vbox:show())
        visible[#visible+1] = bank
        visible_by_guid[bank.guid] = 1
    end
    for b in rfx.current:get_banks() do
        if b.bank then
            showbank(b.bank)
        end
    end
    screen.visible_banks = visible
    if #visible > 0 then
        screen.viewport:show()
        screen.no_banks_box:hide()
    else
        screen.viewport:hide()
        screen.no_banks_box:show()
    end
    if rfx.current.appdata then
        local y = rfx.current.appdata.y
        if y then
            -- Restore saved scroll position for this track
            screen.viewport:scrollto(nil, y, false)
        end
    end
end

function screen.set_warning(msg)
    if msg then
        screen.warningmsg:attr('text', msg)
        screen.warningbox:show()
        -- dst=nil means we animate toward the box's intrinsic height.  The widgets
        -- inside the box (image and text) are able to clip to the container bounding
        -- box.
        screen.warningbox:animate{attr='h', src=0, dst=nil, duration=0.3}
        screen.warningbox:animate{attr='alpha', src=0, dst=1, duration=0.3}
    else
        screen.warningbox:hide()
    end
end


function screen.update_error_box()
    if not rfx.current.fx or not rfx.current.appdata.err then
        screen.errorbox:hide()
    else
        local msg = screen.error_msgs[rfx.current.appdata.err] or screen.error_msgs.default
        screen.errormsg:attr('text', msg)
        screen.errorbox:show()
    end
end


function screen.focus_filter()
    screen.filter_entry:focus()
    screen.filter_refocus_on_activation = not app.window.in_window and rtk.focused_hwnd
    return app.window:focus()
end


function screen.clear_filter()
    screen.filter_entry:attr('value', '')
end

function screen.init()
    screen.button_font = rtk.Font('Calibri', 16, nil, rtk.font.BOLD)
    screen.widget = rtk.VBox()
    screen.toolbar = rtk.HBox{spacing=0}

    local topbar = rtk.VBox{
        spacing=0,
        bg=rtk.theme.bg,
        y=0,
        tpadding=0,
        bpadding=15,
    }
    screen.widget:add(topbar, {lpadding=0, halign='center'})

    local track_button = rtk.Button{
        icon='view_list',
        flat=true,
        tooltip='Configure track for Reaticulate',
    }
    track_button.onclick = function()
        app:push_screen('trackcfg')
    end
    screen.toolbar:add(track_button, {rpadding=0})
    screen.toolbar:add(rtk.Box.FLEXSPACE)

    -- MIDI channel button rows
    local row = rtk.HBox{spacing=2}
    topbar:add(row, {tpadding=20, halign='center'})
    for channel = 1, 16 do
        local label = string.format("%02d", channel)
        local button = rtk.Button{
            label,
            w=25,
            h=20,
            color=rtk.theme.entry_border_focused,
            textcolor='#ffffff',
            fontscale=0.9,
            halign='center',
            padding=0,
            flat=true,
            tooltip='Set inserted articulations and MIDI editor to channel ' .. tostring(channel),
        }
        local button = row:add(button)
        button.onclick = function(button, event)
            if event.button == 1 then
                app:set_default_channel(channel)
            elseif event.button == 2 then
                log.warning('TODO: reassign selected MIDI Events to channel %s', channel)
            end
            app:refocus()
        end
        screen.midi_channel_buttons[channel] = button
        if channel == 8 then
            row = rtk.HBox{spacing=2}
            topbar:add(row, {tpadding=0, halign='center'})
        end
    end

    -- Filter text entry
    local row = topbar:add(rtk.HBox{spacing=10}, {tpadding=10})
    local entry = rtk.Entry{icon='search', placeholder='Filter articulations'}
    entry.onkeypress = handle_filter_keypress
    entry.onchange = function(self)
        screen.filter_articulations(self.value:lower())
    end
    row:add(entry, {fillw=true, lpadding=20, rpadding=20})
    screen.filter_entry = entry

    screen.warningbox = rtk.VBox{
        bg=rtk.theme.dark and '#696f16' or '#ebfb74',
        tborder='#ccd733',
        bborder='#ccd733',
        padding=10,
        -- Default to hidden
        visible=false,
    }
    local hbox = screen.warningbox:add(rtk.HBox())
    -- Force scale for animation
    hbox:add(rtk.ImageBox{image='alert_circle_outline:large', scale=1})
    screen.warningmsg = hbox:add(rtk.Text{wrap=true}, {lpadding=10, valign='center'})
    screen.widget:add(screen.warningbox, {fillw=true})

    screen.errorbox = rtk.VBox{
        bg=rtk.theme.dark and '#3f0000' or '#ff9fa6',
        tborder='#ff0000',
        bborder='#ff0000',
        padding={20, 10},
    }
    local hbox = screen.errorbox:add(rtk.HBox())
    hbox:add(rtk.ImageBox{image='alert_circle_outline:large'})
    screen.errormsg = hbox:add(rtk.Text{wrap=true}, {lpadding=10, valign='center'})
    local button = rtk.Button{'Open Track Settings', icon='view_list', flat=true, color='#aa000099'}
    button.onclick = function()
        app:push_screen('trackcfg')
    end
    screen.errorbox:add(button, {halign='center', tpadding=20})
    screen.widget:add(screen.errorbox, {fillw=true})

    screen.banks = rtk.VBox{bpadding=20, spacing=20}
    screen.viewport = rtk.Viewport{child=screen.banks, h=1.0}
    screen.widget:add(screen.viewport, {fillw=true})

    -- Info / button when no banks are configured on track (hidden when there are banks)
    screen.no_banks_box = rtk.VBox()
    screen.widget:add(screen.no_banks_box, {
        halign='center', valign='center', expand=1, bpadding=100
    })
    local label = rtk.Text{'No articulations on this track', fontsize=24, alpha=0.5}
    screen.no_banks_box:add(label, {halign='center'})

    local button = rtk.Button{
        'Open Track Settings',
        icon=track_button.icon,
        color={0.3, 0.3, 0.3, 1},
    }
    screen.no_banks_box:add(button, {halign='center', tpadding=20})
    button.onclick = track_button.onclick
end

-- Ensures the default channel is highlighted.  Called by the main app when the default
-- channel is changed.
function screen.highlight_channel_button(new_channel)
    for channel, button in ipairs(screen.midi_channel_buttons) do
        button:attr('flat', channel ~= new_channel and 'flat' or false)
    end
end

local function _get_bank_idx(bank)
    for idx, candidate in ipairs(screen.visible_banks) do
        if bank == candidate then
            return idx
        end
    end
end

function screen.get_bank_before(bank)
    local idx = _get_bank_idx(bank) - 1
    if idx >= 1 then
        return screen.visible_banks[idx]
    end
end

function screen.get_bank_after(bank)
    local idx = _get_bank_idx(bank) + 1
    if idx <= #screen.visible_banks then
        return screen.visible_banks[idx]
    end
end

function screen.get_first_bank()
    return screen.visible_banks[1]
end

function screen.get_last_bank()
    return screen.visible_banks[#screen.visible_banks]
end


-- Returns the first or last *visible* articulation on the track
function screen.get_firstlast_articulation(last)
    if not last then
        local bank = screen.get_first_bank()
        if bank then
            for _, art in ipairs(bank.articulations) do
                if art.button.visible then
                    return art
                end
            end
        end
    else
        local bank = screen.get_last_bank()
        if bank then
            for i = #bank.articulations, 1, -1 do
                local art = bank.articulations[i]
                if art.button.visible then
                    return art
                end
            end
        end
    end
end

-- If group is specified then we find the closest articulation in this group.
function screen.get_relative_articulation(art, distance, group)
    local bank = art:get_bank()
    local function _get_adjacent_art(art)
        if distance < 0 then
            return bank:get_articulation_before(art)
        else
            return bank:get_articulation_after(art)
        end
    end

    local absdistance = math.abs(distance)
    local target = art
    -- TODO: infinite loop potential here.  Give this a closer look for bugs.
    while absdistance > 0 do
        local candidate = _get_adjacent_art(target)
        if not candidate then
            -- We have hit the edge of the current.  Check to see if we have other banks to move to.
            if distance < 0 then
                bank = screen.get_bank_before(bank)
                if bank then
                    candidate = bank:get_last_articulation()
                end
            else
                bank = screen.get_bank_after(bank)
                if bank then
                    candidate = bank:get_first_articulation()
                end
            end
        end
        if not candidate then
            -- We're at the top or bottom of the banklist, so wrap around.
            if distance < 0 then
                bank = screen.get_last_bank()
                candidate = bank:get_last_articulation()
            else
                bank = screen.get_first_bank()
                candidate = bank:get_first_articulation()
            end
        end
        if candidate then
            target = candidate
            if (candidate.group == group or not group) and candidate.button.visible then
                absdistance = absdistance - 1
            end
        end
    end
    if (target.group == group or not group) and target.button.visible then
        return target
    end
end

function screen.get_selected_articulation()
    local sel = screen.selected_articulation
    if sel and sel.button.visible then
        return sel
    end
end

function screen.clear_selected_articulation()
    if screen.selected_articulation then
        screen.selected_articulation.button:attr('hover', false)
        screen.selected_articulation = nil
    end
end


function screen.select_relative_articulation(distance)
    local current = screen.get_selected_articulation()
    -- There could be a selected articulation even if current is nil, for
    -- example if we in the middle of selecting but then applied a filter that
    -- hid the articulation.
    --
    -- clear_selected_articulation() doesn't discriminate about whether it's
    -- visible, so use that.
    screen.clear_selected_articulation()
    if not current then
        -- Ask app layer what the currently *active* articulation
        local last = app.last_activated_articulation
        local group = last and last.group or nil
        current = app:get_active_articulation(nil, group)
    end
    local target
    if current then
        target = screen.get_relative_articulation(current, distance, nil)
    else
        -- Last resort: get either the first or last (depending on direction)
        target = screen.get_firstlast_articulation(distance < 0)
    end
    if target then
        target.button:attr('hover', true)
        screen.scroll_articulation_into_view(target)
        screen.selected_articulation = target
    end
end

function screen.scroll_articulation_into_view(art)
    if art.button then
        -- Include a bit more padding on the top to account for the bank title.
        art.button:scrolltoview{50, 0, 10, 0}
    end
end

-- Stores the current scroll position to rfx track metadata.  It is restored
-- in show_track_banks().
function screen.save_scroll_position()
    -- Avoid queue_write_appdata() if the position didn't actually change, because
    -- this dirties the project.
    if rfx.current.track and rfx.current.appdata.y ~= screen.viewport.scroll_top then
        rfx.current.appdata.y = screen.viewport.scroll_top
        rfx.current:queue_write_appdata()
    end
end

function screen.clear_cache()
    for _, bank in pairs(reabank.banks_by_guid) do
        bank.vbox = nil
    end
    screen.update()
end

function screen.update()
    screen.clear_selected_articulation()
    screen.update_error_box()
    screen.show_track_banks()
end

return screen