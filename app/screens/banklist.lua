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
    toolbar = nil,
    -- If true, when enter is pressed in the filter box to activate an
    -- articulation, the last non-Reaticulate window is refocused.  This is set
    -- to true when the "Focus articulation filter" action is activated.
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
    -- app.viewport:scrollto(0, 0)
end

local function handle_filter_keypress(self, event)
    if event.keycode == rtk.keycodes.UP or event.keycode == rtk.keycodes.DOWN or 
       event.keycode == rtk.keycodes.ESCAPE then
        -- These are handled at the app layer
        return false
    elseif event.keycode == rtk.keycodes.ENTER then
        if self.value ~= '' then
            if screen.selected_articulation then
                app:activate_selected_articulation(nil, screen.filter_refocus_on_activation)
            else
                local art = screen.get_firstlast_articulation()
                if art then
                    app:activate_articulation(art, screen.filter_refocus_on_activation)
                end
            end
        elseif screen.filter_refocus_on_activation then
            -- No articulation activation needed but we do need to refocus still.
            app:refocus()
        end
        reaper.defer(function()
            screen.clear_selected_articulation()
            screen.clear_filter()
        end)
    end
end

function screen.draw_button_midi_channel(art, button, offx, offy, event)
    local hovering = event:is_widget_hovering(button) or button.hover
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
            local fill = (channel == hover_channel) or (rfx.active_notes & (1 << channel) > 0)
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
        local tpadding = art.spacer and (art.spacer & 0xff) * 20 or 0
        bank.vbox:add(art.button, {lpadding=30, tpadding=tpadding})
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
    for _, bank, _, _, hash in rfx.get_banks() do
        if bank then
            showbank(bank.msb, bank.lsb)
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
end

function screen.update_error_box()
    if not rfx.fx or not rfx.appdata.err then
        screen.errorbox:hide()
    else
        local msg = screen.error_msgs[rfx.appdata.err] or screen.error_msgs.default
        screen.errormsg:attr('label', msg)
        screen.errorbox:show()
    end
end


function screen.focus_filter()
    screen.filter_entry:focus()
    screen.filter_refocus_on_activation = not rtk.in_window
    return rtk.focus()
end


function screen.clear_filter()
    screen.filter_entry:attr('value', '')
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

    screen.errorbox = rtk.VBox({
        bg='#3f0000',
        tborder='#ff0000',
        bborder='#ff0000',
        tpadding=20, bpadding=20,
        lpadding=10, rpadding=10
    })
    local hbox = screen.errorbox:add(rtk.HBox())
    hbox:add(rtk.ImageBox:new({image=app:get_image("error_outline_24x24.png")}))
    screen.errormsg = hbox:add(rtk.Label({wrap=true}), {lpadding=10, valign='center'})
    local button = app:make_button("edit_white_18x18.png", "Open Track Settings")
    button.onclick = function()
        app:push_screen('trackcfg')
    end
    screen.errorbox:add(button, {halign='center', tpadding=20})
    screen.widget:add(screen.errorbox, {fillw=true})

    screen.banks = rtk.VBox({bpadding=20})
    screen.viewport = rtk.Viewport({child=screen.banks})
    screen.widget:add(screen.viewport, {fillw=true})

    -- Info / button when no banks are configured on track (hidden when there are banks)
    screen.no_banks_box = rtk.VBox:new()
    screen.widget:add(screen.no_banks_box, {
        halign=rtk.Widget.CENTER, valign=rtk.Widget.CENTER, expand=1, bpadding=100
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
        candidate = _get_adjacent_art(target)
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
        art.button:scrolltoview(50, 10)
    end
end

function screen.update()
    screen.clear_selected_articulation()
    screen.update_error_box()
    screen.show_track_banks()
end

return screen
