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

local screen = {
    widget = nil,
    -- VBox containing the list of banks
    banklist = nil,
    info_icon = nil,
    error_icon = nil
}

local function channel_menu_to_channel(channel)
    if channel == 1 then
        return 17
    else
        return channel - 1
    end
end

local function channel_to_channel_menu(channel)
    if channel == 17 then
        return 1
    else
        return channel + 1
    end
end

function screen.init()
    screen.error_icon = rtk.Image:new(Path.join(Path.imagedir, "warning_amber_24x24.png"))
    screen.info_icon = rtk.Image:new(Path.join(Path.imagedir, "info_outline_white_24x24.png"))
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
    screen.update()
end

function screen.sync_banks_to_rfx()
    local banks = {}
    for n = 1, #screen.banklist.children do
        local bankbox = screen.banklist:get_child(n)
        local bank = reabank.get_bank_by_msblsb(bankbox.bank_menu.selected_id)
        local srcchannel = channel_menu_to_channel(bankbox.srcchannel_menu.selected)
        local dstchannel = channel_menu_to_channel(bankbox.dstchannel_menu.selected)
        banks[#banks+1] = {bank, srcchannel, dstchannel}
    end
    rfx.set_banks(banks)
end

-- Position: -1 = before, 1 = after.  If target is nil, then always move to
-- bottom.
function screen.move_bankbox(bankbox, target, position)
    if bankbox ~= target then
        if target then
            local bankboxidx = screen.banklist:get_child_index(bankbox)
            local targetidx = screen.banklist:get_child_index(target)
            if bankboxidx > targetidx then
                screen.banklist:reorder_before(bankbox, target)
            else
                screen.banklist:reorder_after(bankbox, target)
            end
        else
            screen.banklist:reorder(bankbox, #screen.banklist.children + 1)
        end
        return true
    end
end

function screen.move_bankbox_finish()
    screen.sync_banks_to_rfx()
    app.screens.banklist.update()
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

    local channel_menu = {
        'Omni', 'Ch 1', 'Ch 2', 'Ch 3', 'Ch 4',
        'Ch 5', 'Ch 6', 'Ch 7', 'Ch 8',
         'Ch 9', 'Ch 10', 'Ch 11', 'Ch 12',
         'Ch 13', 'Ch 14', 'Ch 15', 'Ch 16'
    }

    bankbox.srcchannel_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bankbox.srcchannel_menu, {lpadding=0, expand=1, fillw=true})
    bankbox.srcchannel_menu:setmenu(channel_menu)
    bankbox.srcchannel_menu:attr('selected', 1)

    row:add(rtk.Label:new({label=' → '}), {valign=rtk.Widget.CENTER})

    channel_menu[1] = 'Source'
    bankbox.dstchannel_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bankbox.dstchannel_menu, {lpadding=0, expand=1, fillw=true})
    bankbox.dstchannel_menu:setmenu(channel_menu)
    bankbox.dstchannel_menu:attr('selected', 1)

    local delete_button = app:make_button("delete_white_18x18.png", nil, true, {
        color={0.5, 0.2, 0.2, 1},
        textcolor='#ffffff', tpadding=3, bpadding=3
    })
    row:add(delete_button, {rpadding=10})
    delete_button.onclick = function()
        -- TODO: provide some means of undo (a la mobile phones)
        screen.banklist:remove(bankbox)
        screen.sync_banks_to_rfx()
        app.screens.banklist.update()
    end

    bankbox.bank_menu.onchange = function(self)
        local bank = reabank.get_bank_by_msblsb(bankbox.bank_menu.selected_id)
        local slot = screen.banklist:get_child_index(bankbox)
        if not slot then
            -- Shouldn't be possible, but handle it anyway.
            log.error("trackcfg: can't find bank in bank list")
        else
            local srcchannel = channel_menu_to_channel(bankbox.srcchannel_menu.selected)
            local dstchannel = channel_menu_to_channel(bankbox.dstchannel_menu.selected)
            screen.sync_banks_to_rfx()
            if bank.off ~= nil then
                -- New bank with off program.  Activate that program now.
                local art = bank:get_articulation_by_program(bank.off)
                if art then
                    app:activate_articulation(art)
                end
            end
            screen.check_errors()
            app.screens.banklist.update()
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

function screen.check_errors()
    local conflicts = rfx.get_banks_conflicts()
    local banks = {}
    for n = 1, #screen.banklist.children do
        local bankbox = screen.banklist:get_child(n)
        local bank = reabank.get_bank_by_msblsb(bankbox.bank_menu.selected_id)
        local channel = channel_menu_to_channel(bankbox.srcchannel_menu.selected)
        local info = nil

        if bank.message then
            bankbox.info.label:attr('label', bank.message)
            bankbox.info:show()
        else
            bankbox.info:hide()
        end

        if banks[bank] then
            bankbox.warning.label:attr('label', 'Error: bank is already listed above.')
            bankbox.warning:show()
        else
            banks[bank] = {bankbox=bankbox, channel=channel}
            local conflict = conflicts[bank]
            if conflict and conflict.source ~= bank then
                -- There is a channel behaviour conflict.  Verify the channel conflict with the previously
                -- listed bank, to rule out the possiblity of a later duplicate bank causing the conflict
                -- (in which case the error will appear with the later bank)
                local previous = banks[conflict.source]
                if channel == 17 or (previous and (previous.channel == 17 or channel == previous.channel)) then
                    local label = "Error: bank conflict on same channel: " .. conflict.source.name
                    bankbox.warning.label:attr('label', label)
                    bankbox.warning:show()
                    log.warn("trackcfg: conflict: %s with program %s on channel %s", conflict.source.name, conflict.program, channel)
                end
            else
                bankbox.warning:hide()
            end
        end
    end
end

function screen.update()
    screen.widget:scrollto(0, 0)
    screen.banklist:clear()
    for bank, srcchannel, dstchannel, hash in rfx.get_banks() do
        local bankbox = screen.create_bank_ui()
        bankbox.srcchannel_menu:select(channel_to_channel_menu(srcchannel), false)
        bankbox.dstchannel_menu:select(channel_to_channel_menu(dstchannel), false)
        -- Set the option menu label which will be used if the MSB/LSB isn't found
        -- in the bank list.
        bankbox.bank_menu:attr('label', string.format('Unknown Bank (%s)', hash))
        bankbox.bank_menu:select(tostring((bank.msb << 8) + bank.lsb), false)
        screen.banklist:add(bankbox)
    end
    screen.check_errors()
end

return screen
