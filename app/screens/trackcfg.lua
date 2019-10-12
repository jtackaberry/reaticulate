-- Copyright 2017-2019 Jason Tackaberry
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

local log = require 'lib.log'
local rtk = require 'lib.rtk'
local rfx = require 'rfx'
local reabank = require 'reabank'
local feedback = require 'feedback'

local screen = {
    widget = nil,
    -- VBox containing the list of banks
    banklist = nil,
    info_icon = nil,
    error_icon = nil
}

local function channel_menu_to_channel(id)
    local n = tonumber(id)
    return n & 0xff, (n & 0xff00) >> 8
end


function screen.init()
    screen.error_icon = app:get_image("warning_amber_24x24.png")
    screen.info_icon = app:get_image("info_outline_white_24x24.png")
    local vbox = rtk.VBox:new()
    screen.widget = rtk.Viewport({child=vbox, rpadding=10})

    screen.toolbar = rtk.HBox:new({spacing=0})

    -- Back button: return to bank list
    local back_button = app:make_button("arrow_back_white_18x18.png", "Back")
    back_button.onclick = function()
        -- Force a resync of RFX to ensure channel assignments for banks get refreshed in the bank list.
        rfx.sync(rfx.track, true)
        app:pop_screen()
    end
    screen.toolbar:add(back_button)

    local heading = rtk.Heading:new({label="Track Articulations"})
    vbox:add(heading, {
        lpadding=10, tpadding=10, bpadding=20
    })

    screen.banklist = vbox:add(rtk.VBox:new({spacing=10}), {lpadding=10})

    local spacer = rtk.Spacer({h=150, w=1.0, y=0, z=10})
    spacer.ondropfocus = function(self, event, _, srcbankbox)
        screen.move_bankbox(srcbankbox, nil)
        return true
    end

    vbox:add(spacer, {tpadding=-20, bpadding=-130})

    local add_bank_button = app:make_button("add_circle_outline_white_18x18.png", "Add Bank", true)
    add_bank_button.onclick = function()
        local limit = rfx.params.banks_end - rfx.params.banks_start + 1
        if #screen.banklist.children >= limit then
            reaper.ShowMessageBox("You have reached the limit of banks for this track.",
                                  "Too many banks :(", 0)
        else
            local bankbox = screen.create_bank_ui()
            screen.banklist:add(bankbox)
            bankbox.bank_menu.onchange()
        end
    end
    vbox:add(add_bank_button, {lpadding=20, tpadding=20, bpadding=40})

    -- Build menus for src and dst channels
    screen.src_channel_menu = {{'Omni', 17}}
    for i = 1, 16 do
        screen.src_channel_menu[#screen.src_channel_menu+1] = {
            string.format('Ch %d', i),
            i
        }
    end

    screen.dst_channel_menu = {
        {'Bus 1', nil, rtk.OptionMenu.ITEM_DISABLED},
        rtk.OptionMenu.SEPARATOR,
        {'Source', 17 | (1 << 8)}
    }
    for i = 1, 16 do
        screen.dst_channel_menu[#screen.dst_channel_menu+1] = {string.format('Ch %d', i), i | (1 << 8)}
    end
    screen.dst_channel_menu[#screen.dst_channel_menu+1] = rtk.OptionMenu.SEPARATOR
    for i = 2, 16 do
        local submenu = {{'Source', 17 | (i << 8), 0, string.format('%d/Source', i, 0)}}
        for j = 1, 16 do
            submenu[#submenu + 1] = {
                string.format('Ch %d', j),
                j | (i << 8),
                0,
                string.format('Ch %d/%d', i, j)
            }
        end
        screen.dst_channel_menu[#screen.dst_channel_menu+1] = {
            string.format('Bus %d', i),
            submenu
        }
    end
    screen.update()
end

function screen.set_banks_from_banklist()
    local banks = {}
    for n = 1, #screen.banklist.children do
        local bankbox = screen.banklist:get_child(n)
        local bank = reabank.get_bank_by_msblsb(bankbox.bank_menu.selected_id)
        local srcchannel, _ = channel_menu_to_channel(bankbox.srcchannel_menu.selected_id)
        local dstchannel, dstbus = channel_menu_to_channel(bankbox.dstchannel_menu.selected_id)
        banks[#banks+1] = {bank, srcchannel, dstchannel, dstbus}
    end
    rfx.set_banks(banks)
    screen.check_errors_and_update_ui()
    -- This will also write appdata (which contains the bank list and error
    -- code) to the rfx.
    rfx.sync_banks_to_rfx()
    app.screens.banklist.update()
end

-- Position: -1 = before, 1 = after.  If target is nil, then always move to
-- bottom.
function screen.move_bankbox(bankbox, target, position)
    if bankbox ~= target then
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
end

function screen.move_bankbox_finish()
    screen.set_banks_from_banklist()
end

function screen.create_bank_ui()
    local bankbox = rtk.VBox:new({spacing=10, tpadding=10, bpadding=10})
    local banklist_menu_spec = reabank.to_menu()
    local row = bankbox:add(rtk.HBox:new({spacing=10}))

    bankbox.ondropfocus = function(self, event, _, srcbankbox)
        return true
    end
    bankbox.ondropmousemove = function(self, event, _, srcbankbox)
        if self ~= srcbankbox then
            local rely = event.y - self.cy - event.offy - self.ch / 2
            if rely < 0 then
                screen.move_bankbox(srcbankbox, bankbox, -1)
            else
                screen.move_bankbox(srcbankbox, bankbox, 1)
            end
        end
    end

    -- Bank row
    local drag_handle = rtk.ImageBox:new({
        image=app:get_image('drag_vertical_24x24.png'),
        cursor='ruler_scroll',
        w=24,
        halign=rtk.Widget.CENTER
    })
    drag_handle.ondragstart = function(event)
        bankbox.bg = '#5b7fac30'
        bankbox.tborder = {'#497ab7', 2}
        bankbox.bborder = bankbox.tborder
        return bankbox
    end
    drag_handle.ondragend = function(event)
        bankbox.bg = nil
        bankbox.tborder = nil
        bankbox.bborder = nil
        screen.move_bankbox_finish()
    end
    drag_handle.onmouseenter = function() return true end
    row:add(drag_handle)
    local bank_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bank_menu, {expand=1, fillw=true, rpadding=0})
    bankbox.bank_menu = bank_menu
    bank_menu:setmenu(banklist_menu_spec)
    bank_menu:select(1)

    -- Channel row
    local row = bankbox:add(rtk.HBox:new({spacing=10}))
    row:add(rtk.Spacer({w=24, h=24}))

    bankbox.srcchannel_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bankbox.srcchannel_menu, {lpadding=0, expand=1, fillw=true})
    bankbox.srcchannel_menu:setmenu(screen.src_channel_menu)
    bankbox.srcchannel_menu:select(17)

    row:add(rtk.Label:new({label=' → '}), {valign=rtk.Widget.CENTER})


    bankbox.dstchannel_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bankbox.dstchannel_menu, {lpadding=0, expand=1, fillw=true})
    bankbox.dstchannel_menu:setmenu(screen.dst_channel_menu)
    bankbox.dstchannel_menu:select(17 | (1<<8))

    local delete_button = app:make_button("delete_white_18x18.png", nil, true, {
        color={0.5, 0.2, 0.2, 1},
        textcolor='#ffffff', tpadding=3, bpadding=3
    })
    row:add(delete_button, {rpadding=10})
    delete_button.onclick = function()
        -- TODO: provide some means of undo (a la mobile phones)
        screen.banklist:remove(bankbox)
        screen.set_banks_from_banklist()
    end

    bankbox.bank_menu.onchange = function(self)
        local bank = reabank.get_bank_by_msblsb(bankbox.bank_menu.selected_id)
        local slot = screen.banklist:get_child_index(bankbox)
        if not slot then
            -- Shouldn't be possible, but handle it anyway.
            log.error("trackcfg: can't find bank in bank list")
        else
            screen.set_banks_from_banklist()
            if bank.off ~= nil then
                -- New bank with off program.  Activate that program now.
                local art = bank:get_articulation_by_program(bank.off)
                if art then
                    app:activate_articulation(art)
                end
            end
        end
    end
    bankbox.srcchannel_menu.onchange = bankbox.bank_menu.onchange
    bankbox.dstchannel_menu.onchange = bankbox.bank_menu.onchange

    -- Info row
    local row = bankbox:add(rtk.HBox:new({spacing=10}))
    bankbox.info = row
    row:add(rtk.ImageBox:new({image=screen.info_icon}), {valign=rtk.Widget.TOP})
    row.label = row:add(rtk.Label:new({wrap=true}), {valign=rtk.Widget.CENTER})

    -- Warning row
    local row = bankbox:add(rtk.HBox:new({spacing=10}))
    bankbox.warning = row
    row:add(rtk.ImageBox:new({image=screen.error_icon}), {valign=rtk.Widget.TOP})
    row.label = row:add(rtk.Label:new({wrap=true}), {valign=rtk.Widget.CENTER})
    return bankbox
end

-- An iterator that returns errors (if any) for each bank
function screen.get_errors()
    local conflicts = rfx.get_banks_conflicts()
    local get_next_bank = rfx.get_banks()
    local feedback_enabled = feedback.is_enabled()
    local banks = {}

    return function()
        local n, bank, srcchannel, dstchannel, dstbus, hash, userdata = get_next_bank()
        if not bank then
            return
        end

        local error = rfx.ERROR_NONE
        local conflict = nil

        if (bank.buses & (1 << 15) > 0 or dstbus == 16) and feedback_enabled then
            error = rfx.ERROR_BUS_CONFLICT
        end
        if banks[bank] then
            -- Other errors take precedence but set if currently no error
            if not error then
                error = rfx.ERROR_DUPLICATE_BANK
            end
        else
            banks[bank] = {idx=n, channel=srcchannel}
            conflict = conflicts[bank]
            if conflict and conflict.source ~= bank then
                -- There is a channel behaviour conflict.  Verify the channel conflict with the previously
                -- listed bank, to rule out the possiblity of a later duplicate bank causing the conflict
                -- (in which case the error will appear with the later bank)
                local previous = banks[conflict.source]
                if srcchannel == 17 or (previous and (previous.channel == 17 or srcchannel == previous.channel)) then
                    error = rfx.ERROR_PROGRAM_CONFLICT
                end
            end
        end

        return n, bank, error, conflict
    end
end

local function _max_error(a, b)
    return (a and b) and math.max(a, b) or a or b
end


-- Updates the UI according to any existing bank errors and sets rfx.error
-- accordingly.  Returns true if the rfx.error changed, which the caller
-- may use to decide if rfx.set_appdata() should be called.
function screen.check_errors_and_update_ui()
    local error = nil
    for n, bank, bank_error, conflict in screen.get_errors() do
        local bankbox = screen.banklist:get_child(n)

        if bank.message then
            bankbox.info.label:attr('label', bank.message)
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
            errmsg = "Error: program numbers on the same source channel conflicts with " .. conflict.source.name
        end
        screen.set_bankbox_warning(bankbox, errmsg)
        error = _max_error(error, bank_error)
    end
    rfx.set_error(error)
end

-- Checks the current track banks for errors and sets rfx.error accordingly.
-- This function does not depend on the UI and is meant for use when the
-- trackcfg screen is not visible.
function screen.check_errors()
    local error = nil
    for n, bank, bank_error, conflict in screen.get_errors() do
        error = _max_error(error, bank_error)
    end
    log.info("-> set error: %s -> %s", rfx.appdata.err, error)
    rfx.set_error(error)
end

function screen.set_bankbox_warning(bankbox, msg)
    if msg then
        bankbox.warning.label:attr('label', msg)
        bankbox.warning:show()
    else
        bankbox.warning:hide()
    end
end

function screen.update()
    if not rfx.fx then
        return
    end
    screen.widget:scrollto(0, 0)
    screen.banklist:clear()
    for _, bank, srcchannel, dstchannel, dstbus, hash, userdata in rfx.get_banks() do
        if bank then
            local bankbox = screen.create_bank_ui()
            bankbox.srcchannel_menu:select(tostring(srcchannel), false)
            bankbox.dstchannel_menu:select(tostring(dstchannel | (dstbus << 8)), false)
            -- Set the option menu label which will be used if the MSB/LSB isn't found
            -- in the bank list.
            bankbox.bank_menu:attr('label', string.format('Unknown Bank (%s)', hash))
            bankbox.bank_menu:select(tostring((bank.msb << 8) + bank.lsb), false)
            screen.banklist:add(bankbox)
        end
    end
    screen.check_errors_and_update_ui()
end

return screen
