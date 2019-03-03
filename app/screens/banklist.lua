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

local rtk = require 'lib.rtk'
local rfx = require 'rfx'
local reabank = require 'reabank'
local articons = require 'articons'

local screen = {
    name = 'banklist',
    widget = nil,
    midi_channel_buttons = {},
    visible_banks = {},
    filter_tabbed = false,
    toolbar = nil
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
    -- app.viewport:scrollto(0, 0)
end

local function handle_filter_keypress(self, event)
    if event.keycode == rtk.keycodes.ESCAPE then
        self:attr('value', '')
    elseif event.keycode == rtk.keycodes.TAB then
        -- Tab is handled by the main app, so we return false to indicate the event
        -- is not handled.
        screen.filter_tabbed = true
        return false
    elseif event.keycode == rtk.keycodes.ENTER then
        -- Select the first visible articulation and clear the filter.
        local activated = false
        for _, bank in ipairs(screen.visible_banks) do
            for _, art in ipairs(bank.articulations) do
                if art.button.visible then
                    app:activate_articulation(art, false)
                    activated = true
                    break
                end
            end
            if activated then
                break
            end
        end
        if event.keycode == rtk.keycodes.ENTER then
            self:attr('value', '')
        end
    end
end


function screen.draw_button_midi_channel(art, button, offx, offy, event)
    local hovering = event:is_widget_hovering(button)
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
        local x = offx + button.cx + button.cw
        gfx.setfont(1, button.font, (button.fontsize - 2) * rtk.scale, rtk.fonts.BOLD)
        for idx, channel in ipairs(channels) do
            local lw, lh = gfx.measurestr(channel + 1)
            x = x - (lw + 15)
            local y = offy + button.cy + (button.ch - lh) / 2
            button:setcolor('#ffffff')
            local fill = (channel == hover_channel) or (app.active_notes & (1 << channel) > 0)
            gfx.rect(x - 5, y - 1, lw + 10, lh + 2, fill)
            if fill then
                button:setcolor('#000000')
            end
            gfx.x = x
            gfx.y = y
            gfx.drawstr(channel + 1)
        end
    end
end



function screen.create_banklist_ui(bank)
    bank.vbox = rtk.VBox:new({spacing=10})
    bank.heading = rtk.Heading:new({label=bank.shortname or bank.name})
    bank.vbox:add(bank.heading, {lpadding=10, tpadding=#reabank.banks > 0 and 40 or 20, bpadding=10})

    for n, art in ipairs(bank.articulations) do
        local color = art.color or reabank.colors.default
        local textcolor = '#ffffff'
        if not color:starts('#') then
            color = reabank.colors[color] or reabank.colors.default
        end
        local textcolor = color2luma(color) > 0.7 and '#000000' or '#ffffff'
        art.icon = articons.get(art.iconname) or articons.get('note-eighth')
        local flags = art.channels > 0 and 0 or rtk.Button.FLAT_LABEL
        art.button = rtk.Button:new({
            -- Prefix a bit of whitespace to distance from icon
            label='  ' .. (art.shortname or art.name),
            icon=art.icon,
            color=color,
            textcolor=textcolor,
            tpadding=1, rpadding=1, bpadding=1, lpadding=1,
            flags=flags,
            rspace=40
        })
        -- Make button width fill container (with 10px margin at right)
        art.button:resize(-10, nil)
        art.button.onclick = function(button, event) app:onartclick(art, event) end
        art.button.ondraw = function(button, offx, offy, event)
            screen.draw_button_midi_channel(art, button, offx, offy, event)
        end
        art.button.onmouseleave = function(button, event) app:set_statusbar(nil) end
        art.button.onmouseenter = function(button, event)
            if not art.outputstr then
                art.outputstr = art:describe_outputs()
            end
            app:set_statusbar(art.outputstr)
            return true
        end
        bank.vbox:add(art.button, {lpadding=30})
    end
    bank.vbox:hide()
    return bank.vbox
end

-- Shows the articulation banks for the current track in the order
-- defined by the track's RFX.
function screen.show_track_banks()
    if not rfx.fx then
        -- No FX on current track, nothing to do.
        return
    end

    -- Clear the banks list
    screen.banks:clear()

    -- Now (re)add all the banks to the list in the order stored in the RFX.
    local visible = {}
    local visible_by_msblsb = {}
    function showbank(msb, lsb)
        local msblsb = (msb << 8) + lsb
        if visible_by_msblsb[msblsb] then
            return
        end
        local bank = reabank.get_bank_by_msblsb(msblsb)
        if bank then
            if not bank.vbox then
                screen.create_banklist_ui(bank)
            end
            screen.banks:add(bank.vbox:show())
            visible[#visible+1] = bank
            visible_by_msblsb[msblsb] = 1
        end
    end
    for _, _, msb, lsb in rfx.get_banks() do
        showbank(msb, lsb)
    end
    screen.visible_banks = visible
    if #visible > 0 then
        screen.no_banks_box:hide()
    else
        screen.no_banks_box:show()
    end
end

function screen.focus_filter()
    screen.filter_entry:focus()
    screen.filter_refocus_on_activation = not rtk.in_window
    return rtk.focus()
end

function screen.init()
    screen.widget = rtk.VBox:new()

    local topbar = rtk.VBox:new({
        spacing=0,
        bg=rtk.theme.window_bg,
        y=0,
        focusable=true,
        tpadding=0,
        bpadding=15,
        z=50
    })
    screen.toolbar = rtk.HBox:new({spacing=0})
    screen.widget:add(topbar, {lpadding=0})

    local track_button = app:make_button("view_list_white_18x18.png")
    screen.toolbar:add(track_button, {rpadding=0})
    track_button.onclick = function()
        app:push_screen('trackcfg')
    end
    screen.toolbar:add(rtk.HBox.FLEXSPACE)

    -- Filter text entry
    local row = topbar:add(rtk.HBox:new({spacing=10}), {tpadding=10})
    local icon = app:get_image('search_white_18.png')
    local entry = rtk.Entry:new({icon=icon, label="Filter articulations", bg2='#0000007f'})
    screen.filter_entry = entry
    entry.onkeypress = handle_filter_keypress
    entry.onchange = function(self)
        screen.filter_articulations(self.value:lower())
    end
    row:add(entry, {expand=1, fillw=true, lpadding=20, rpadding=20})

    -- MIDI channel button rows
    row = rtk.HBox:new({spacing=2})
    topbar:add(row, {tpadding=20, halign=rtk.Widget.CENTER})
    for channel = 1, 16 do
        local label = string.format("%02d", channel)
        local button = rtk.Button:new({
            label=label, color=rtk.theme.entry_border_focused, w=25, h=20,
            fontscale=0.9, halign=rtk.Widget.CENTER,
            flags=rtk.Button.FLAT_LABEL
        })
        local button = row:add(button)
        button.onclick = function()
            app:set_default_channel(channel)
            app:refocus()
        end
        screen.midi_channel_buttons[channel] = button
        if channel == 8 then
            row = rtk.HBox:new({spacing=2})
            topbar:add(row, {tpadding=0, halign=rtk.Widget.CENTER})
        end
    end
    screen.banks = rtk.VBox({bpadding=20})
    screen.viewport = rtk.Viewport({child=screen.banks})
    screen.widget:add(screen.viewport, {fillw=true})

    -- Info / button when no banks are configured on track (hidden when there are banks)
    screen.no_banks_box = rtk.VBox:new()
    screen.widget:add(screen.no_banks_box, {
        halign=rtk.Widget.CENTER, valign=rtk.Widget.CENTER, tpadding=20
    })
    local label = rtk.Label:new({
        label="No banks on this track", fontsize=24,
        color={1, 1, 1, 0.5}
    })
    screen.no_banks_box:add(label, {halign=rtk.Widget.CENTER})

    local button = rtk.Button:new({
        icon=track_button.icon, label="Edit Track Banks",
        space=10, color={0.3, 0.3, 0.3, 1},
        tpadding=5, bpadding=5, lpadding=5, rpadding=10
    })
    screen.no_banks_box:add(button, {halign=rtk.Widget.CENTER, tpadding=20})
    button.onclick = track_button.onclick
end

-- Ensures the default channel is highlighted.  Called by the main app when the default
-- channel is changed.
function screen.highlight_channel_button(new_channel)
    for channel, button in ipairs(screen.midi_channel_buttons) do
        if channel == new_channel then
            button:attr('flags', 0)
        else
            button:attr('flags', rtk.Button.FLAT_LABEL)
        end
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



function screen.update()
    screen.show_track_banks()
end

return screen
