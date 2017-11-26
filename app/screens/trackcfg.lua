-- Copyright 2017 Jason Tackaberry
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
    if channel == 16 then
        return 1
    else
        return channel + 1
    end
end

function screen.init()
    screen.error_icon = rtk.Image:new(Path.join(Path.imagedir, "warning_amber_24x24.png"))
    screen.info_icon = rtk.Image:new(Path.join(Path.imagedir, "info_outline_white_24x24.png"))
    screen.widget = rtk.widget:add(rtk.VBox:new())

    screen.toolbar = rtk.HBox:new({spacing=0})

    -- Back button: return to bank list
    local back_button = make_button("arrow_back_white_18x18.png", "Back")
    back_button.onclick = function()
        -- Force a resync of RFX to ensure channel assignments for banks get refreshed in the bank list.
        rfx.sync(rfx.track, true)
        App.screens.pop()
    end
    screen.toolbar:add(back_button)

    local heading = rtk.Heading:new({label="Track Articulations"})
    screen.widget:add(heading, {
        lpadding=10, tpadding=50, bpadding=20
    })

    screen.banklist = screen.widget:add(rtk.VBox:new({spacing=20}), {lpadding=20})

    local add_bank_button = make_button("add_circle_outline_white_18x18.png", "Add Bank", true)
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
    screen.widget:add(add_bank_button, {lpadding=20, tpadding=20, bpadding=20})
    screen.update()
end

function screen.sync_banks_to_rfx()
    for n = 1, #screen.banklist.children do
        local bankbox = screen.banklist:get_child(n)
        local bank = reabank.get_bank_by_msblsb(bankbox.bank_menu.selected_id)
        local srcchannel = channel_menu_to_channel(bankbox.srcchannel_menu.selected)
        local dstchannel = channel_menu_to_channel(bankbox.dstchannel_menu.selected)
        rfx.set_bank(n, srcchannel, dstchannel, bank)
    end
    rfx.sync_articulation_details()
    screen.check_errors()
end


function screen.create_bank_ui()
    local bankbox = rtk.VBox:new({spacing=10, bpadding=20})
    local banklist_menu_spec = reabank.to_menu()
    local row = bankbox:add(rtk.HBox:new({spacing=10}))

    -- Bank row
    local up_button = make_button("keyboard_arrow_up_white_18x18.png", nil, true, {
        color={0.3, 0.3, 0.6, 1},
        lpadding=3, rpadding=3, tpadding=3, bpadding=3
    })
    row:add(up_button)
    up_button.onclick = function()
        local idx = screen.banklist:remove(bankbox) - 1
        if idx < 1 then
            idx = #screen.banklist.children + 1
        end
        screen.banklist:insert(idx, bankbox)
        screen.sync_banks_to_rfx()
        App.screens.banklist.update()
    end
    local bank_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bank_menu, {expand=1, fill=true, rpadding=10})
    bankbox.bank_menu = bank_menu
    bank_menu:setmenu(banklist_menu_spec)

    -- Channel row
    local row = bankbox:add(rtk.HBox:new({spacing=10}))
    local down_button = make_button("keyboard_arrow_down_white_18x18.png", nil, true, {
        color={0.3, 0.3, 0.6, 1},
        lpadding=3, rpadding=3, tpadding=3, bpadding=3
    })
    row:add(down_button)
    down_button.onclick = function()
        local idx = screen.banklist:remove(bankbox) + 1
        if idx > #screen.banklist.children + 1 then
            idx = 1
        end
        screen.banklist:insert(idx, bankbox)
        screen.sync_banks_to_rfx()
        App.screens.banklist.update()
    end

    local channel_menu = {
        'Omni', 'Ch 1', 'Ch 2', 'Ch 3', 'Ch 4',
        'Ch 5', 'Ch 6', 'Ch 7', 'Ch 8',
         'Ch 9', 'Ch 10', 'Ch 11', 'Ch 12',
         'Ch 13', 'Ch 14', 'Ch 15', 'Ch 16'
    }

    bankbox.srcchannel_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bankbox.srcchannel_menu, {lpadding=0, expand=1, fill=true})
    bankbox.srcchannel_menu:setmenu(channel_menu)
    bankbox.srcchannel_menu:attr('selected', 1)

    row:add(rtk.Label:new({label=' → '}), {valign=rtk.Widget.CENTER})

    channel_menu[1] = 'Source'
    bankbox.dstchannel_menu = rtk.OptionMenu:new({tpadding=3, bpadding=3})
    row:add(bankbox.dstchannel_menu, {lpadding=0, expand=1, fill=true})
    bankbox.dstchannel_menu:setmenu(channel_menu)
    bankbox.dstchannel_menu:attr('selected', 1)


    local delete_button = make_button("delete_white_18x18.png", nil, true, {
        color={0.5, 0.2, 0.2, 1},
        textcolor='#ffffff', tpadding=3, bpadding=3
    })
    row:add(delete_button, {rpadding=10})
    delete_button.onclick = function()
        local slot = screen.banklist:get_child_index(bankbox)
        screen.banklist:remove(bankbox)
        rfx.set_bank(#screen.banklist.children + 1, nil, nil, nil)
        screen.sync_banks_to_rfx()
        App.screens.banklist.update()
    end

    bankbox.bank_menu.onchange = function()
        local bank = reabank.get_bank_by_msblsb(bankbox.bank_menu.selected_id)
        local slot = screen.banklist:get_child_index(bankbox)
        if not slot then
            -- Shouldn't be possible, but handle it anyway.
            log("ERROR: can't find bank in bank list")
        else
            local srcchannel = channel_menu_to_channel(bankbox.srcchannel_menu.selected)
            local dstchannel = channel_menu_to_channel(bankbox.dstchannel_menu.selected)
            rfx.set_bank(slot, srcchannel, dstchannel, bank)
            rfx.sync_articulation_details()
            if bank.off ~= nil then
                -- New bank with off program.  Activate that program now.
                local art = bank:get_articulation_by_program(bank.off)
                if art then
                    App.activate_articulation(art)
                end
            end

            screen.check_errors()
            App.screens.banklist.update()
        end
    end
    bankbox.srcchannel_menu.onchange = bankbox.bank_menu.onchange
    bankbox.dstchannel_menu.onchange = bankbox.bank_menu.onchange

    -- Info row
    local row = bankbox:add(rtk.HBox:new({spacing=10}))
    bankbox.info = row
    row:add(rtk.ImageBox:new({image=screen.info_icon}), {valign=rtk.Widget.TOP})
    row.label = row:add(rtk.Label:new(), {valign=rtk.Widget.CENTER})

    -- Warning row
    local row = bankbox:add(rtk.HBox:new({spacing=10}))
    bankbox.warning = row
    row:add(rtk.ImageBox:new({image=screen.error_icon}), {valign=rtk.Widget.CENTER})
    row.label = row:add(rtk.Label:new(), {valign=rtk.Widget.CENTER})
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
        bankbox.warning:hide()

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
                    local label = "Error: bank conflict on same channel:\n" .. conflict.source.name
                    bankbox.warning.label:attr('label', label)
                    bankbox.warning:show()
                    log("Conflict: %s with program %s on channel %s", conflict.source.name, conflict.program, channel)
                end
            end
        end

    end
end

function screen.update()
    screen.banklist:clear()
    for srcchannel, dstchannel, msb, lsb in rfx.get_banks() do
        local bankbox = screen.create_bank_ui()
        bankbox.srcchannel_menu:select(channel_to_channel_menu(srcchannel), false)
        bankbox.dstchannel_menu:select(channel_to_channel_menu(dstchannel), false)
        bankbox.bank_menu:select(tostring((msb << 8) + lsb), false)
        screen.banklist:add(bankbox)
    end
    screen.check_errors()
end

return screen
