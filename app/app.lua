-- Copyright 2017-2018 Jason Tackaberry
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

local BaseApp = require 'lib.baseapp'
local rtk = require 'lib.rtk'
local rfx = require 'rfx'
local reabank = require 'reabank'
local articons = require 'articons'
local feedback = require 'feedback'
require 'lib.utils'

App = class('App', BaseApp)

function App:initialize(basedir)
    BaseApp.initialize(self, 'reaticulate', basedir)
    -- log("")

    -- Currently selected track (or nil if no track is selected)
    self.track = nil
    -- Default MIDI Channel for banks not pinned to channels.  Offset from 1.
    self.default_channel = 1
    -- hwnd of the last seen MIDI editor
    self.last_midi_hwnd = nil
    -- Last seen active notes bitmap from the current track RFX.  Just a copy of
    -- rfx.active_notes so we can detect changes.
    self.active_notes = 0
    -- Keys are 16-bit values with channel in byte 0, and group in byte 1 (offset from 1).
    self.active_articulations = {}
    -- Tracks articulations that have been activated but not yet processed by the RFX and/or
    -- detected by the GUI.  Same index and value as active_articulations.  Pending articulations
    -- that are processed and detected will be removed from this list.  Useful for fast events
    -- (e.g. scrolling through articulations via the relative CC action) where, for UX, we can't
    -- afford to wait for the full activation round trip.
    self.pending_articulations = {}

    table.merge(self.config, {
        -- Configuration that's persisted across restarts.
        cc_feedback_device = -1,
        cc_feedback_bus = 1,
        -- Togglable via action
        cc_feedback_active = true,
        autostart = 0
    })

    self:add_screen('installer', 'screens.installer')
    self:add_screen('banklist', 'screens.banklist')
    self:add_screen('trackcfg', 'screens.trackcfg')
    self:add_screen('settings', 'screens.settings')

    rfx.init()
    reabank.init()
    articons.init(Path.imagedir)
    rtk.scale = self.config.scale

    self:set_statusbar('Reaticulate')
    self:replace_screen('banklist')
    self:set_default_channel(1)
    self:run()
end

function App:ontrackchange(last, cur)
    local lr, ltracknum, lfx, lparam = reaper.GetLastTouchedFX()
    log("Last touched: lr=%s num=%s fx=%s param=%s", lr, ltracknum, lfx, lparam)
    reaper.PreventUIRefresh(1)
    self:sync_midi_editor()
    self.screens.banklist.filter_entry:onchange()
    feedback.ontrackchange(last, cur)
    reaper.PreventUIRefresh(-1)
end

function App:onartclick(art, event)
    if event.button == rtk.mouse.BUTTON_LEFT then
        self:activate_articulation(art, true, false)
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
        self:activate_articulation(art, true, true)
    end
end

-- Deletes all bank select or program change events at the given ppq.
-- The caller passes an index of a CC event which must exist at the ppq,
-- but in case there are multiple events at that ppq, it's not required that
-- it's the first.
local function delete_program_events_at_ppq(take, idx, max, ppq)
    -- The supplied index is at the ppq, but there may be others ahead of it.  So
    -- rewind to the first.
    while idx >= 0 do
        local rv, selected, muted, evtppq, command, chan, msg2, msg3 = reaper.MIDI_GetCC(take, idx)
        if evtppq ~= ppq then
            break
        end
        idx = idx - 1
    end
    idx = idx + 1
    -- Now idx is the first CC at ppq.  Enumerate subsequent events and delete
    -- any bank selects or program changes until we move off the ppq.
    while idx < max do
        local rv, selected, muted, evtppq, command, chan, msg2, msg3 = reaper.MIDI_GetCC(take, idx)
        if evtppq ~= ppq then
            return
        end
        if (command == 0xb0 and (msg2 == 0 or msg2 == 0x20)) or (command == 0xc0) then
            reaper.MIDI_DeleteCC(take, idx)
        else
            -- If we deleted the event, we don't advance idx because the old value would
            -- point to the adjacent event.  Otherwise we do need to increment it.
            idx = idx + 1
        end
    end
end

function App:activate_articulation(art, refocus, force_insert)
    if art.program < 0 then
        return false
    end
    if refocus then
        reaper.defer(function() self:refocus() end)
    end

    local bank = art:get_bank()
    local channel = bank:get_src_channel(app.default_channel) - 1
    local take = nil

    -- If MIDI Editor is open, use the current take there.
    local hwnd = reaper.MIDIEditor_GetActive()
    if hwnd then
        -- Magic value 32060 is the MIDI editor context
        local stepInput = reaper.GetToggleCommandStateEx(32060, 40481)
        if stepInput == 1 or force_insert then
            take = reaper.MIDIEditor_GetTake(hwnd)
        end
    elseif force_insert then
        -- No active MIDI editor and we want to force insert.  Try to find the current
        -- take on the selected track based on edit cursor position.
        --
        -- FIXME: might support multiple selected tracks.
        local track = reaper.GetSelectedTrack(0, 0)
        if track then
            local cursor = reaper.GetCursorPosition()
            for idx = 0, reaper.CountTrackMediaItems(track) - 1 do
                local item = reaper.GetTrackMediaItem(track, idx)
                local startpos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
                local endpos = startpos + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
                if cursor >= startpos and cursor <= endpos then
                    take = reaper.GetActiveTake(item)
                    break
                end
            end
        end
    end
    reaper.PreventUIRefresh(1)
    if take then
        reaper.Undo_BeginBlock2(0)
        -- Take was found (either because MIDI editor is open with step input enabled or because
        -- force insert was used), so inject the PC event at the current cursor position.

        -- This is a bit tragic.  There's no native function to get a list of MIDI events given a
        -- ppq.  So knowing that the event indexes will be ordered by time, we do a binary search
        -- across the events until we converge on the ppq.
        --
        -- If the events at the ppq are program changes, we delete them (as we're about to replace
        -- them).
        local cursor = reaper.GetCursorPosition()
        local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursor)

        local _, _, n_events, _ = reaper.MIDI_CountEvts(take)
        local skip = math.floor(n_events / 2)
        local idx = skip
        while idx > 0 and idx < n_events and skip > 0.5 do
            local rv, _, _, evtppq, _, _, _, _ = reaper.MIDI_GetCC(take, idx)
            skip = skip / 2
            if evtppq > ppq then
                -- Event is ahead of target ppq, back up.
                idx = idx - math.ceil(skip)
            elseif evtppq < ppq then
                -- Event is behind target ppq, skip ahead.
                idx = idx + math.ceil(skip)
            else
                delete_program_events_at_ppq(take, idx, n_events, ppq)
                break
            end
        end
        -- Insert program change at ppq
        reaper.MIDI_InsertCC(take, false, false, ppq, 0xb0, channel, 0, bank.msb)
        reaper.MIDI_InsertCC(take, false, false, ppq, 0xb0, channel, 32, bank.lsb)
        reaper.MIDI_InsertCC(take, false, false, ppq, 0xc0, channel, art.program, 0)
        local item = reaper.GetMediaItemTake_Item(take)
        reaper.UpdateItemInProject(item)
        rfx.activate_articulation(channel, art.program)
        reaper.Undo_EndBlock2(0, "Reaticulate: insert articulation (" .. art.name .. ")", -1)
    else
        rfx.activate_articulation(channel, art.program)
    end
    reaper.PreventUIRefresh(-1)
    reaper.StuffMIDIMessage(0, 0xb0 + channel, 0, bank.msb)
    reaper.StuffMIDIMessage(0, 0xb0 + channel, 0x20, bank.lsb)
    reaper.StuffMIDIMessage(0, 0xc0 + channel, art.program, 0)

    -- Set articulation as pending.
    local idx = (channel + 1) + (art.group << 8)
    self.pending_articulations[idx] = art
end

function App:refocus()
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
    local last_art = app.active_articulations[artidx]
    local channel_bit = 2^(channel - 1)

    -- If there is an active articulation in the same channel/group, then unset the old one now.
    if last_art then
        last_art.channels = last_art.channels & ~channel_bit
        if last_art.channels == 0 then
            if last_art.button then
                last_art.button.flags = rtk.Button.FLAT_LABEL
            end
            app.active_articulations[artidx] = nil
        end
    end

    app.pending_articulations[artidx] = nil

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
                app.active_articulations[artidx] = art
                break
            end
        end
    end
    rtk.queue_draw()
end

local function _cmd_arg_to_channel(arg)
    local channel = tonumber(arg)
    if channel == 0 then
        return app.default_channel
    else
        return channel
    end
end

function App:handle_command(cmd, arg)
    if cmd == 'set_default_channel' then
        self:set_default_channel(tonumber(arg))
        feedback.dump_ccs(self.track)
    elseif cmd == 'activate_articulation' and rfx.fx then
        -- Look at all visible banks and find the matching articulation.
        local args = string.split(arg, ',')
        local channel = _cmd_arg_to_channel(args[1])
        local program = tonumber(args[2])
        local force_insert = tonumber(args[3] or 0)
        local art = nil
        for _, bank in ipairs(self.screens.banklist.visible_banks) do
            if bank.srcchannel == 17 or bank.srcchannel == channel then
                art = bank:get_articulation_by_program(program)
                if art then
                    break
                end
            end
        end
        if art then
            self:activate_articulation(art, false, force_insert)
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
        self:activate_relative_articulation_in_group(channel, group, distance)
    elseif cmd == 'dump_ccs' and rfx.fx then
        feedback.dump_ccs(self.track)
    elseif cmd == 'set_midi_feedback_active' then
        local enabled = tonumber(arg)
        if enabled == -1 then
            -- Toggle
            feedback.set_active(not self.config.cc_feedback_active)
        else
            feedback.set_active(enabled == 1 and true or false)
        end
        feedback.dump_ccs(self.track)
    end
    return BaseApp.handle_command(self, cmd, arg)
end

function App:set_default_channel(channel)
    self.default_channel = channel
    self.screens.banklist.highlight_channel_button(channel)
    self:sync_midi_editor()
    rtk.queue_draw()
end


-- distance < 0 means previous, otherwise means next.
function App:activate_relative_articulation_in_group(channel, group, distance)
    local artidx = channel + (group << 8)
    local art = self.pending_articulations[artidx]
    if not art then
        art = self.active_articulations[artidx]
    end
    if not art or not art.button.visible then
        -- No articulation is currently selected, so we need to pick one to use as a
        -- starting point.  For negative distances, pick the first articulation, and
        -- for positive distances, pick the last.
        if distance < 0 then
            local bank = self.screens.banklist.get_first_bank()
            if bank then
                art = bank:get_first_articulation()
            end
        else
            local bank = self.screens.banklist.get_last_bank()
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
                bank = self.screens.banklist.get_bank_before(bank)
                if bank then
                    candidate = bank:get_last_articulation()
                end
            else
                bank = self.screens.banklist.get_bank_after(bank)
                if bank then
                    candidate = bank:get_first_articulation()
                end
            end
        end
        if not candidate then
            -- We're at the top or bottom of the banklist, so wrap around.
            if distance < 0 then
                bank = self.screens.banklist.get_last_bank()
                candidate = bank:get_last_articulation()
            else
                bank = self.screens.banklist.get_first_bank()
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
        self:activate_articulation(target, false, false)
        target.button:scrolltoview(130, 40)
    end
end


function App:sync_midi_editor(hwnd)
    if not hwnd then
        hwnd = reaper.MIDIEditor_GetActive()
    end
    -- Set channel for new events to <channel>
    reaper.MIDIEditor_OnCommand(hwnd, 40482 + self.default_channel - 1)
end

function App:handle_ondock()
    BaseApp.handle_ondock(self)
    self:update_dock_buttons()
end

function BaseApp:handle_onkeypresspost(event)
    log("keypress: keycode=%d  handled=%s", event.keycode, event.handled)
    if not event.handled then
        if self:current_screen() == self.screens.banklist then
            if event.keycode >= 49 and event.keycode <= 57 then
                self:set_default_channel(event.keycode - 48)
            elseif event.keycode == rtk.keycodes.DOWN then
                self:activate_relative_articulation_in_group(self.default_channel, 1, 1)
            elseif event.keycode == rtk.keycodes.UP then
                self:activate_relative_articulation_in_group(self.default_channel, 1, -1)
            end
        end
        -- If the app sees an unhandled space key then we do what is _probably_ what
        -- the user wants, which is to toggle transport play and refocus outside of
        -- Reaticulate.  This fails if the user has bound space to something else,
        -- but it's worth the risk.
        if event.keycode == rtk.keycodes.SPACE then
            -- Transport: Play/stop
            reaper.Main_OnCommandEx(40044, 0, 0)
            self:refocus()
        end
    end
end

function App:update_dock_buttons()
    if self.toolbar.dock then
        if (self.config.dockstate or 0) & 0x01 == 0 then
            -- Not docked.
            self.toolbar.undock:hide()
            self.toolbar.dock:show()
        else
            -- Docked
            self.toolbar.dock:hide()
            self.toolbar.undock:show()
        end
    end
end

function App:refresh_banks()
    local function kick_item(item)
        local fast = reaper.SNM_CreateFastString("")
        if reaper.SNM_GetSetObjectState(item, fast, false, false) then
            reaper.SNM_GetSetObjectState(item, fast, true, false)
        end
        reaper.SNM_DeleteFastString(fast)
    end

    local t0 = os.clock()
    reabank.refresh()
    log("stage 0 refresh took %.03fs", os.clock() - t0)
    -- Kick all media items on the current track as well as the selected media
    -- item in the ass to recognize the changes made to the reabank.
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        kick_item(item)
    end
    if self.track then
        for idx = 0, reaper.GetTrackNumMediaItems(self.track) - 1 do
            local item = reaper.GetTrackMediaItem(self.track, idx)
            kick_item(item)
        end
    end

    log("stage 1 refresh took %.03fs", os.clock() - t0)
    -- Ensure redirection config for banks are synced to RFX.
    -- FIXME: this needs to work across all tracks.
    rfx.sync_articulation_details()
    log("stage 2 refresh took %.03fs", os.clock() - t0)
    rfx.sync(rfx.track, true)
    self:ontrackchange(nil, self.track)
    log("stage 3 refresh took %.03fs", os.clock() - t0)
    -- Update articulation list to reflect any changes that were made to the Reabank template.
    self.screens.banklist.update()
    log("stage 4 refresh took %.03fs", os.clock() - t0)
    if self:current_screen() == self.screens.trackcfg then
        self.screens.trackcfg.update()
    end
    log("bank refresh took %.03fs", os.clock() - t0)
    -- This is necessary if an existing Reaticulate-managed track references a non-Reaticulate
    -- bank.  Unfortunately it's *SLOW*.  And most of the time it shouldn't be necessary.
    -- So we should probably move it to some action the user intentionally activates.
    if false then
        local t0 = os.clock()
        for i = 0, reaper.CountTracks(0) - 1 do
            local track = reaper.GetTrack(0, i)
            -- local track = reaper.GetSelectedTrack(0, 0)
            if rfx.get(track) then
                -- Can't use reaper.Get/SetTrackStateChunk() which horks with large (>~5MB) chunks.
                local fast = reaper.SNM_CreateFastString("")
                local ok = reaper.SNM_GetSetObjectState(track, fast, false, false)
                chunk = reaper.SNM_GetFastString(fast)
                reaper.SNM_DeleteFastString(fast)
                log("BEFORE XML: %s", chunk:len())
                if ok and chunk and chunk:find("MIDIBANKPROGFN") then
                    local fast = reaper.SNM_CreateFastString(chunk)
                    chunk = chunk:gsub('MIDIBANKPROGFN "[^"]*"', 'MIDIBANKPROGFN ""')
                    log("AFTER XML: %s", chunk:len())
                    reaper.SNM_GetSetObjectState(track, fast, true, false)
                    reaper.SNM_DeleteFastString(fast)
                end
            end
        end
        log("track chunk sweep took %.03fs", os.clock() - t0)
    end
end

function App:build_frame()
    BaseApp.build_frame(self)

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

    local toolbar = self.toolbar
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

    local button = toolbar:add(self:make_button("loop_white_18x18.png"))
    button.onclick = function() reaper.defer(function() app:refresh_banks() end) end

    self.toolbar.dock = toolbar:add(self:make_button("dock_window_white_18x18.png"))
    self.toolbar.undock = toolbar:add(self:make_button("undock_window_white_18x18.png"))
    self.toolbar.dock.onclick = function()
        -- Restore last dock position but default to right dock if not previously docked.
        gfx.dock(self.config.last_dockstate or 513)
    end

    self.toolbar.undock.onclick = function()
        gfx.dock(0)
    end

    self:update_dock_buttons()

    local button = toolbar:add(self:make_button("settings_white_18x18.png"), {rpadding=0})
    button.onclick = function()
        self:push_screen('settings')
    end
    return self.frame
end


function App:handle_onupdate()
    BaseApp.handle_onupdate(self)

    local track = reaper.GetSelectedTrack(0, 0)
    local last_track = self.track
    local track_changed = self.track ~= track
    local current_screen = self:current_screen()

    if track_changed and #self.active_articulations > 0 then
        for _, art in pairs(self.active_articulations) do
            art.channels = 0
            art.button.flags = rtk.Button.FLAT_LABEL
        end
        self.active_articulations = {}
        self.pending_articulations = {}
    end

    -- If rfx.sync() returns true then the FX has changed and we need
    -- to update the main screen for the new articulations.
    if rfx.sync(track) then
        self.screens.banklist.update()
        if self.screens.trackcfg.widget.visible then
            self.screens.trackcfg.update()
        end
    end

    -- Check if track has changed
    if track ~= self.track then
        last_track = self.track
        self.track = track
        self:ontrackchange(last_track, track)
    end

    -- Having called rfx.sync(), if rfx.fx is set then this is a Reaticulate-enabled track.
    if rfx.fx then
        -- If the main screen is hidden, show it now.
        -- XXX: uncomment me
        if #self.screens.stack == 1 and current_screen ~= self.screens.banklist then
            self:replace_screen('banklist')
        end
        local hwnd = reaper.MIDIEditor_GetActive()
        if hwnd ~= self.last_midi_hwnd then
            self:sync_midi_editor(hwnd)
            self.last_midi_hwnd = hwnd
        end
        if rfx.active_notes ~= self.active_notes then
            self.active_notes = rfx.active_notes
            rtk.queue_draw()
        end
    -- FIXME: if in trackcfg and then switched to a non-rfx track, we should
    -- swap the banklist's slot in the screen stack for the installer.
    elseif #self.screens.stack == 1 then
        self.screens.installer.update()
        if current_screen ~= self.screens.installer then
            self:replace_screen('installer')
        end
    end
end

function App:open_config_ui()
    self:send_command('reaticulate.cfgui', 'ping', function(response)
        if response == nil then
            -- Config UI isn't currently open, so open it.
            -- Lookup cmd id saved from previous invocation.
            -- cmd = reaper.SetExtState("reaticulate", "cfgui_command_id", '', false)
            cmd = reaper.GetExtState("reaticulate", "cfgui_command_id")
            if cmd == '' or not cmd or not reaper.ReverseNamedCommandLookup(tonumber(cmd)) then
                -- This is the command id for the default script location
                cmd = reaper.NamedCommandLookup('FIXME')
            end
            if cmd == '' or not cmd or cmd == 0 then
                reaper.ShowMessageBox(
                    "Couldn't open the configuration window.  This is due to a REAPER limitation.\n\n" ..
                    "Workaround: open REAPER's actions list and manually run Reaticulate_Configuration_App.\n\n" ..
                    "You will only need to do this once.",
                    "Reaticulate: Error", 0
                )
            else
                reaper.Main_OnCommandEx(tonumber(cmd), 0, 0)
            end
        else
            self:send_command('reaticulate.cfgui', 'quit')
        end
    end, 0.05)
end

return App