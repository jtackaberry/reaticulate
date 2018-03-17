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

require 'lib.utils'
local rtk = require 'lib.rtk'
local rfx = require 'rfx'
local reabank = require 'reabank'
local articons = require 'articons'
local feedback = require 'feedback'

App = {
    -- Currently selected track (or nil if no track is selected)
    track = nil,
    -- Default MIDI Channel for banks not pinned to channels.  Offset from 1.
    default_channel = 1,
    -- hwnd of the last seen MIDI editor
    last_midi_hwnd = nil,
    -- Last seen active notes bitmap from the current track RFX.  Just a copy of
    -- rfx.active_notes so we can detect changes.
    active_notes = 0,

    screens = {
        stack = {}
    },
    -- Keys are 16-bit values with channel in byte 0, and group in byte 1 (offset from 1).
    active_articulations = {},
    -- Tracks articulations that have been activated but not yet processed by the RFX and/or
    -- detected by the GUI.  Same index and value as active_articulations.  Pending articulations
    -- that are processed and detected will be removed from this list.  Useful for fast events
    -- (e.g. scrolling through articulations via the relative CC action) where, for UX, we can't
    -- afford to wait for the full activation round trip.
    pending_articulations = {},

    -- Configuration that's persisted across restarts.
    config = {
        -- Initial dimensions
        w = 640,
        h = 480,
        dockstate = 0,
        scale = 1.0,
        bg = nil,
        cc_feedback_device = -1,
        cc_feedback_bus = 1,
        -- Togglable via action
        cc_feedback_active = true
    },

    toolbar = {
    }
}

App.screens.installer = require 'screens.installer'
App.screens.banklist = require 'screens.banklist'
App.screens.trackcfg = require 'screens.trackcfg'
App.screens.settings = require 'screens.settings'


-- Utility button factory
function get_image(file)
    return rtk.Image:new(Path.join(Path.imagedir, file))
end

function make_button(iconfile, label, textured, attrs)
    local icon = nil
    local button = nil
    if iconfile then
        icon = get_image(iconfile)
        if label then
            flags = textured and 0 or (rtk.Button.FLAT_ICON | rtk.Button.FLAT_LABEL)
            button = rtk.Button:new({icon=icon, label=label,
                                     flags=flags, tpadding=5, bpadding=5, lpadding=5,
                                     rpadding=10})
        else
            flags = textured and 0 or rtk.Button.FLAT_ICON
            button = rtk.Button:new({icon=icon, flags=flags,
                                    tpadding=5, bpadding=5, lpadding=5, rpadding=5})
        end
        button:setattrs(attrs)
    end
    return button
end



function App.screens.init()
    for _, screen in pairs(App.screens) do
        if type(screen) == 'table' and screen.init then
            screen.init()
            if screen.toolbar then
                screen.toolbar:hide()
                App.toolbar.box:insert(1, screen.toolbar)
            end
            screen.widget:hide()
        end
    end
end

function App.screens.show(screen)
    for _, s in ipairs(App.screens.stack) do
        s.widget:hide()
        if s.toolbar then
            s.toolbar:hide()
        end
    end
    if screen then
        screen.update()
        screen.widget:show()
        if screen.toolbar then
            screen.toolbar:show()
        end
    end
    App.set_statusbar(nil)
end

function App.screens.push(screen)
    if #App.screens.stack > 0 and App.screens.get_current() ~= screen then
        App.screens.show(screen)
        App.screens.stack[#App.screens.stack+1] = screen
    end
end

function App.screens.pop()
    if #App.screens.stack > 1 then
        App.screens.show(App.screens.stack[#App.screens.stack-1])
    end
    table.remove(App.screens.stack)
end

function App.screens.replace(screen)
    App.screens.show(screen)
    local idx = #App.screens.stack
    if idx == 0 then
        idx = 1
    end
    App.screens.stack[idx] = screen
end

function App.screens.get_current()
    return App.screens.stack[#App.screens.stack]
end

function App.ontrackchange(last, cur)
    reaper.PreventUIRefresh(1)
    App.sync_midi_editor()
    App.screens.banklist.filter_entry:onchange()
    feedback.ontrackchange(last, cur)
    reaper.PreventUIRefresh(-1)
end

function App.onartclick(art, event)
    if event.button == rtk.mouse.BUTTON_LEFT then
        App.activate_articulation(art, true, false)
    elseif event.button == rtk.mouse.BUTTON_MIDDLE then
        -- Middle click on articulation.  Clear all channels currently assigned to that articulation.
        rfx.push_state(rfx.track)
        for channel = 0, 15 do
            if art.channels & (1 << channel) ~= 0 then
                rfx.clear_channel_program(channel + 1, art.group)
            end
        end
        rfx.sync(rfx.track, true)
        rfx.pop_state()
    elseif event.button == rtk.mouse.BUTTON_RIGHT then
        App.activate_articulation(art, true, true)
    end
end

function App.activate_articulation(art, refocus, force_insert)
    if art:activate(refocus or false, force_insert) then
        local bank = art:get_bank()
        local channel = bank:get_src_channel()
        local idx = channel + (art.group << 8)
        App.pending_articulations[idx] = art
    end
end

function App.refocus()
    -- If the MIDI editor is open, focus.
    if reaper.MIDIEditor_GetActive() ~= nil then
        local cmd = reaper.NamedCommandLookup('_SN_FOCUS_MIDI_EDITOR')
        if cmd ~= 0 then
            -- Version of SWS that supports MIDI editor focus.
            reaper.Main_OnCommandEx(cmd, 0, 0)
        end
    else
        -- Focus arrange view
        reaper.Main_OnCommandEx(reaper.NamedCommandLookup('_BR_FOCUS_ARRANGE_WND'), 0, 0)
    end
end

function rfx.onartchange(channel, group, last_program, new_program, track_changed)
    log("articulation change: %d -> %d  ch=%d  group=%d  track_changed=%s", last_program, new_program, channel, group, track_changed)
    local artidx = channel + (group << 8)
    local last_art = App.active_articulations[artidx]
    local channel_bit = 2^(channel - 1)

    -- If there is an active articulation in the same channel/group, then unset the old one now.
    if last_art then
        last_art.channels = last_art.channels & ~channel_bit
        if last_art.channels == 0 then
            if last_art.button then
                last_art.button.flags = rtk.Button.FLAT_LABEL
            end
            App.active_articulations[artidx] = nil
        end
    end

    App.pending_articulations[artidx] = nil

    local banks = rfx.banks_by_channel[channel]
    if banks then
        for _, bank in ipairs(banks) do
            local art = bank.articulations_by_program[new_program]
            if art and art.group == group then
                art.channels = art.channels | channel_bit
                -- If articulaton button exists then clear the FLAT_LABEL flag.
                if art.button then
                    art.button.flags = 0
                end
                App.active_articulations[artidx] = art
                break
            end
        end
    end
    rtk.queue_draw()
end

local function _cmd_arg_to_channel(arg)
    local channel = tonumber(arg)
    if channel == 0 then
        return App.default_channel
    else
        return channel
    end
end

function App.handle_command(cmd, arg)
    log("cmd: %s(%s)", cmd, arg)
    if cmd == 'set_default_channel' then
        App.set_default_channel(tonumber(arg))
        feedback.dump_ccs(App.track)
    elseif cmd == 'activate_articulation' and rfx.fx then
        -- Look at all visible banks and find the matching articulation.
        local args = string.split(arg, ',')
        local channel = _cmd_arg_to_channel(args[1])
        local program = tonumber(args[2])
        local force_insert = tonumber(args[3] or 0)
        local art = nil
        for _, bank in ipairs(App.screens.banklist.visible_banks) do
            if bank.srcchannel == 17 or bank.srcchannel == channel then
                art = bank:get_articulation_by_program(program)
                if art then
                    break
                end
            end
        end
        if art then
            App.activate_articulation(art, false, force_insert)
        end
    elseif cmd == 'activate_relative_articulation' and rfx.fx then
        local args = string.split(arg, ',')
        local channel = _cmd_arg_to_channel(args[1])
        local group = tonumber(args[2])
        local mode = tonumber(args[3])
        local resolution = tonumber(args[4])
        local offset = tonumber(args[5])
        local distance = 0

        -- Normalize offset into distance
        if mode == 2 and offset % 15 == 0 then
            -- Mode 2 is used by mousewheel as well.  Encoder left/wheel down is negative,
            -- encoder right/wheel up is positive.  So we actually want to invert the mouse wheel
            -- direction (such that down is positive).  Also, we need to treat the sensitivity
            -- differently for mouse.  Unfortunately the only way to detect it is the heuristic
            -- that values from mousewheel events are integer multiples of 15.
            distance = -offset / 15
        else
            -- MIDI CC activated.  Adjust based on resolution and reduce the velocity effect.
            local sign = offset < 0 and -1 or 1
            distance = sign * math.ceil(math.abs(offset) * 16.0 / resolution)
        end
        App.activate_relative_articulation_in_group(channel, group, distance)
    elseif cmd == 'dump_ccs' and rfx.fx then
        feedback.dump_ccs(App.track)
    elseif cmd == 'set_midi_feedback_active' then
        local enabled = tonumber(arg)
        if enabled == -1 then
            -- Toggle
            feedback.set_active(not App.config.cc_feedback_active)
        else
            feedback.set_active(not not enabled)
        end
        feedback.dump_ccs(App.track)
    end
end

function App.set_default_channel(channel)
    App.default_channel = channel
    App.screens.banklist.highlight_channel_button(channel)
    App.sync_midi_editor()
    rtk.queue_draw()
end


-- distance < 0 means previous, otherwise means next.
function App.activate_relative_articulation_in_group(channel, group, distance)
    local artidx = channel + (group << 8)
    local art = App.pending_articulations[artidx]
    if not art then
        art = App.active_articulations[artidx]
    end
    if not art or not art.button.visible then
        -- No articulation is currently selected, so we need to pick one to use as a
        -- starting point.  For negative distances, pick the first articulation, and
        -- for positive distances, pick the last.
        if distance < 0 then
            local bank = App.screens.banklist.get_first_bank()
            if bank then
                art = bank:get_first_articulation()
            end
        else
            local bank = App.screens.banklist.get_last_bank()
            if bank then
                art = bank:get_last_articulation()
            end
        end
        if not art then
            return
        end
    end

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
                bank = App.screens.banklist.get_bank_before(bank)
                if bank then
                    candidate = bank:get_last_articulation()
                end
            else
                bank = App.screens.banklist.get_bank_after(bank)
                if bank then
                    candidate = bank:get_first_articulation()
                end
            end
        end
        if not candidate then
            -- We're at the top or bottom of the banklist, so wrap around.
            if distance < 0 then
                bank = App.screens.banklist.get_last_bank()
                candidate = bank:get_last_articulation()
            else
                bank = App.screens.banklist.get_first_bank()
                candidate = bank:get_first_articulation()
            end
        end
        if candidate then
            target = candidate
            if candidate.group == group and candidate.button.visible then
                absdistance = absdistance - 1
            end
        end
    end
    if target ~= art and target.group == group and target.button.visible then
        App.activate_articulation(target, false, false)
        target.button:scrolltoview(130, 40)
    end
end



function App.sync_midi_editor(hwnd)
    if not hwnd then
        hwnd = reaper.MIDIEditor_GetActive()
    end
    -- Set channel for new events to <channel>
    reaper.MIDIEditor_OnCommand(hwnd, 40482 + App.default_channel - 1)
end

function App.get_config()
    if reaper.HasExtState("reaticulate", "config") then
        local state = reaper.GetExtState("reaticulate", "config")
        local config = table.fromstring(state)
        -- Merge stored config into runtime config
        for k, v in pairs(config) do
            App.config[k] = v
        end
    end
end

function App.save_config()
    reaper.SetExtState("reaticulate", "config", table.tostring(App.config), true)
end

function App.set_debug(level)
    App.config.debug_level = level
    App.save_config()
    if level == 0 then
        rtk.debug = false
    else
        rtk.debug = true
        log("Reaticulate debugging is enabled")
    end
end

function rtk.ondock()
    App.config.dockstate = rtk.dockstate
    if (rtk.dockstate or 0) & 0x01 ~= 0 then
        App.config.last_dockstate = rtk.dockstate
    end
    App.save_config()
    App.toolbar.update_dock_buttons()
end

function rtk.onresize()
    -- Only save dimensions when not docked.
    if (rtk.dockstate or 0) & 0x01 == 0 then
        App.config.w, App.config.h = rtk.w, rtk.h
        App.save_config()
    end
end

function rtk.onmousewheel(event)
    if event.ctrl then
        -- ctrl-wheel scaling
        if event.wheel < 0 then
            rtk.scale = rtk.scale + 0.05
        else
            rtk.scale = rtk.scale - 0.05
        end
        App.set_statusbar(string.format('Zoom UI to %.02fx', rtk.scale))
        App.config.scale = rtk.scale
        App.save_config()
        rtk.queue_reflow()
        event.wheel = 0
    end
end

function rtk.onkeypresspost(event)
    log("keypress: keycode=%d  handled=%s", event.keycode, event.handled)
    if not event.handled then
        if App.screens.get_current() == App.screens.banklist then
            if event.keycode >= 49 and event.keycode <= 57 then
                App.set_default_channel(event.keycode - 48)
            elseif event.keycode == rtk.keycodes.DOWN then
                App.activate_relative_articulation_in_group(App.default_channel, 1, 1)
            elseif event.keycode == rtk.keycodes.UP then
                App.activate_relative_articulation_in_group(App.default_channel, 1, -1)
            end
        end
        -- If the app sees an unhandled space key then we do what is _probably_ what
        -- the user wants, which is to toggle transport play and refocus outside of
        -- Reaticulate.  This fails if the user has bound space to something else,
        -- but it's worth the risk.
        if event.keycode == rtk.keycodes.SPACE then
            -- Transport: Play/stop
            reaper.Main_OnCommandEx(40044, 0, 0)
            App.refocus()
        end
    end
end

function App.set_theme_colors()
    local bg = int2hex(reaper.GSC_mainwnd(20)) -- COLOR_BTNHIGHLIGHT
    -- Determine from theme background color if we should use the light or dark theme.
    local luma = color2luma(bg)
    if luma > 0.7 then
        rtk.theme = rtk.colors.light
    else
        rtk.theme = rtk.colors.dark
    end
    rtk.theme.window_bg = bg
    -- rtk.theme.window_bg = '#252525'
end

function App.set_statusbar(label)
    if label then
        App.statusbar.label:attr('label', label)
    else
        App.statusbar.label:attr('label', " ")
    end
end


function App.toolbar.update_dock_buttons()
    if App.toolbar.dock then
        if (App.config.dockstate or 0) & 0x01 == 0 then
            -- Not docked.
            App.toolbar.undock:hide()
            App.toolbar.dock:show()
        else
            -- Docked
            App.toolbar.dock:hide()
            App.toolbar.undock:show()
        end
    end
end

function App.refresh_banks()
    local t0 = os.clock()
    reabank.refresh()
    -- Ensure redirection config for banks are synced to RFX.
    -- FIXME: this needs to work across all tracks.
    rfx.sync_articulation_details()
    rfx.sync(rfx.track, true)
    App.ontrackchange(nil, App.track)
    -- Update articulation list to reflect any changes that were made to the Reabank template.
    App.screens.banklist.update()
    if App.screens.get_current() == App.screens.trackcfg then
        App.screens.trackcfg.update()
    end
    log("bank refresh took %.03fs", os.clock() - t0)
end

local function build_toolbar()
    local toolbar = rtk.HBox:new({spacing=0, bg=rtk.theme.window_bg})
    App.toolbar.box = toolbar

    toolbar:add(rtk.HBox.FLEXSPACE)

    local icon = rtk.Image:new(Path.join(Path.imagedir, "edit_white_18x18.png"))
    local menubutton = rtk.OptionMenu:new({
        icon=icon, flags=rtk.Button.FLAT_ICON | rtk.OptionMenu.HIDE_LABEL,
        tpadding=5, bpadding=5, lpadding=5, rpadding=5
    })
    if reaper.GetOS():starts('Win') then
        menubutton:setmenu({
            'Edit in Notepad',
            'Open in Default App',
            'Show in Explorer'
        })
    elseif reaper.GetOS():starts('OSX') then
        menubutton:setmenu({
            'Edit in TextEdit',
            'Open in Default App',
            'Show in Finder'
        })
    end
    toolbar:add(menubutton)
    menubutton.onchange = function(self)
        reabank.create_user_reabank_if_missing()
        if reaper.GetOS():starts('Win') then
            if self.selected == 1 then
                reaper.ExecProcess('cmd.exe /C start /B notepad ' .. reabank.reabank_filename_user, -2)
            elseif self.selected == 2 then
                reaper.ExecProcess('cmd.exe /C start /B ' .. reabank.reabank_filename_user, -2)
            elseif self.selected == 3 then
                reaper.ExecProcess('cmd.exe /C explorer /select,' .. reabank.reabank_filename_user, -2)
            end
        elseif reaper.GetOS():starts('OSX') then
            if self.selected == 1 then
                os.execute('open -a TextEdit "' .. reabank.reabank_filename_user .. '"')
            elseif self.selected == 2 then
                os.execute('open -t "' .. reabank.reabank_filename_user .. '"')
            elseif self.selected == 3 then
                local path = Path.join(Path.resourcedir, "Data")
                os.execute('open "' .. path .. '"')
            end
        end
    end

    local button = toolbar:add(make_button("loop_white_18x18.png"))
    button.onclick = function() reaper.defer(App.refresh_banks) end

    App.toolbar.dock = toolbar:add(make_button("dock_window_white_18x18.png"))
    App.toolbar.undock = toolbar:add(make_button("undock_window_white_18x18.png"))
    App.toolbar.dock.onclick = function()
        -- Restore last dock position but default to right dock if not previously docked.
        gfx.dock(App.config.last_dockstate or 513)
    end

    App.toolbar.undock.onclick = function()
        gfx.dock(0)
    end

    App.toolbar.update_dock_buttons()

    local button = toolbar:add(make_button("settings_white_18x18.png"), {rpadding=0})
    button.onclick = function()
        App.screens.push(App.screens.settings)
    end

    return toolbar
end


function App.init(basedir)
    if reaper.NamedCommandLookup('_SWS_TOGSELMASTER') == 0 then
        -- Sunk before we started.
        reaper.ShowMessageBox("Reaticulate requires the SWS extensions (www.sws-extension.org).\n\nAborting!",
                              "SWS extension missing", 0)
        return
    end

    rtk.debug=true
    Path.init(basedir)
    Path.imagedir = Path.join(Path.basedir, 'img')

    App.get_config()
    App.set_debug(App.config.debug_level or 0)
    App.set_theme_colors()
    rtk.init("Reaticulate", App.config.w, App.config.h, App.config.dockstate)
    rtk.widget = rtk.Container:new()
    rfx.init()
    reabank.init()
    articons.init(Path.imagedir)
    rtk.scale = App.config.scale

    -- Testing binary serialization.
    if false then
        local cfg = {
            b = {
                {17, 17, 1, 1},
                {17, 17, 1, 2},
                {17, 17, 1, 3},
                {17, 17, 1, 4},
                {17, 17, 1, 5},
                {17, 17, 1, 6},
                {17, 17, 1, 7}
            }
        }
        local binser = require 'lib.binser'
        local s = binser.serialize(cfg)
        log("serialized: %d %s", #s, s)
        t0 = os.clock()
        d = binser.deserialize(s)
        t1 = os.clock()
        log("deserialized: %f", t1-t0)
    end

    App.overlay = rtk.VBox:new({position=rtk.Widget.FIXED, z=100})
    rtk.widget:add(App.overlay)

    App.overlay:add(build_toolbar())

    App.statusbar = rtk.HBox:new({bg=rtk.theme.window_bg, lpadding=10, tpadding=5, bpadding=5, rpadding=10})
    App.statusbar.label = App.statusbar:add(rtk.Label:new({color=rtk.theme.text_faded}), {expand=1})
    App.overlay:add(rtk.VBox.FLEXSPACE)
    App.overlay:add(App.statusbar)
    App.set_statusbar('Reaticulate')

    App.screens.init()

    App.screens.replace(App.screens.banklist)
    -- App.screens.push(App.screens.settings)
    App.set_default_channel(1)

    rtk.onupdate = function()
        exists, val = reaper.GetProjExtState(0, "reaticulate", "command")
        if exists ~= 0 then
            reaper.SetProjExtState(0, "reaticulate", "command", '')
            for cmd, arg in val:gmatch('(%S+)=([^"]%S*)') do
                App.handle_command(cmd, arg)
            end
        end

        local track = reaper.GetSelectedTrack(0, 0)
        local last_track = App.track
        local track_changed = App.track ~= track
        local current_screen = App.screens.get_current()

        if track_changed and #App.active_articulations > 0 then
            for _, art in pairs(App.active_articulations) do
                art.channels = 0
                art.button.flags = rtk.Button.FLAT_LABEL
            end
            App.active_articulations = {}
            App.pending_articulations = {}
        end

        -- If rfx.sync() returns true then the FX has changed and we need
        -- to update the main screen for the new articulations.
        if rfx.sync(track) then
            App.screens.banklist.update()
            if App.screens.trackcfg.widget.visible then
                App.screens.trackcfg.update()
            end
        end

        -- Check if track has changed
        if track ~= App.track then
            last_track = App.track
            App.track = track
            App.ontrackchange(last_track, track)
        end

        -- Having called rfx.sync(), if rfx.fx is set then this is a Reaticulate-enabled track.
        if rfx.fx then
            -- If the main screen is hidden, show it now.
            if #App.screens.stack == 1 and current_screen ~= App.screens.banklist then
                App.screens.replace(App.screens.banklist)
            end
            local hwnd = reaper.MIDIEditor_GetActive()
            if hwnd ~= App.last_midi_hwnd then
                App.sync_midi_editor(hwnd)
                App.last_midi_hwnd = hwnd
            end
            if rfx.active_notes ~= App.active_notes then
                App.active_notes = rfx.active_notes
                rtk.queue_draw()
            end
        elseif #App.screens.stack == 1 then
            App.screens.installer.update()
            if current_screen ~= App.screens.installer then
                App.screens.replace(App.screens.installer)
            end
        end
    end
    -- Explicitly call onupdate() before first draw to set up the screens.
    rtk.onupdate()
    reaper.defer(rtk.run)
end

return App