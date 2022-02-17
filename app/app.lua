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

local BaseApp = require 'lib.baseapp'
local rtk = require 'rtk'
local rfx = require 'rfx'
local reabank = require 'reabank'
local articons = require 'articons'
local feedback = require 'feedback'
local json = require 'lib.json'
local log = rtk.log

require 'lib.utils'

App = rtk.class('App', BaseApp)

-- Constants for App:queue() and App:refresh_banks()
--
-- Queues a save of the current project state.  This will dirty the project.
App.static.SAVE_PROJECT_STATE = 1
-- Queues a refresh_banks()
App.static.REFRESH_BANKS = 2
-- Whether we should remove unreferenced banks from the project state.  Also implies
-- REFRESH_BANKS.
App.static.CLEAN_UNUSED_BANKS = 4
-- Whether refresh_banks() should re-parse Reaticulate.reabank. Implies REFRESH_BANKS.
App.static.REPARSE_REABANK_FILE = 8
-- Whether we should kick REAPER to force-reload track support data on the current track.
-- Note this explicitly does *not* imply a bank refresh, because we might be assigning
-- a bank to a track that already exists in the project and just need to kick the track.
App.static.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK = 16
-- Whether we should kick REAPER to force reload track support data on the *entire
-- project*. This implies REFRESH_BANKS. Unfortunately it's extremely slow on modest
-- projects.
App.static.FORCE_RECOGNIZE_BANKS_PROJECT = 32

-- Bitmap of actions that imply refresh_banks()
App.static.REFRESH_BANKS_ACTIONS = 2|4|8|32


function App:initialize(basedir, t0, t1)
    -- Configuration that's persisted across restarts.
    self.config = {
        cc_feedback_device = -1,
        cc_feedback_bus = 1,
        -- 1=Program Change, 2=CC
        cc_feedback_articulations = 1,
        -- 0 means use Program Changes, otherwise it's the CC #
        cc_feedback_articulations_cc = 0,
        -- Togglable via action
        cc_feedback_active = true,
        autostart = 0,
        art_colors = nil,

        -- If true, if the MIDI editor is open, the item that is target for event insertion
        -- will dictate which track is selected in the TCP.
        track_selection_follows_midi_editor = true,

        -- If true, focusing an FX window will select the corresponding track.
        track_selection_follows_fx_focus = false,

        -- If true, articulation insertions will be inserted at selected note positions
        -- when the MIDI editor is open.
        art_insert_at_selected_notes = true,

        -- If true, we ensure only one instrument floating instrument FX window is visible.
        -- EXPERIMENTAL and requires JS extension
        single_floating_instrument_fx_window = false,

        -- If true, enables a pseudo sloppy focus within Reaper between arrange view, TCP, MCP,
        -- MIDI editor, and Lua GFX windows.
        keyboard_focus_follows_mouse = false,

        -- How the default channel syncing should behave: 1 = global, 2 = per track, 3 = per item.
        -- If nil, then
        default_channel_behavior = nil,

        -- Comma-delimited range list of CCs to chase.  If nil (or empty string) then
        -- the hardcoded default will be used.
        chase_ccs = nil,
    }

    self.config_map_to_script = {
        track_selection_follows_midi_editor = {0, 'Reaticulate_Toggle track selection follows MIDI editor target item.lua'},
        track_selection_follows_fx_focus = {0, 'Reaticulate_Toggle track selection follows focused FX window.lua'},
        single_floating_instrument_fx_window = {0, 'Reaticulate_Toggle single floating instrument FX window for selected track.lua'},
        keyboard_focus_follows_mouse = {0, 'Reaticulate_Toggle keyboard focus follows mouse.lua'},
    }

    -- List of hwnd classes that we recognize for sloppy focus
    self.known_focus_classes = {
        -- What are these on OS X and Linux?
        REAPERmidieditorwnd = 'midi_editor',
        REAPERTCPDisplay = 'tcp',
        REAPERTrackListWindow  = 'arrange',
        REAPERMCPDisplay = 'hwnd',
        Lua_LICE_gfx_standalone = 'hwnd',
        eelscript_gfx = 'hwnd',
        -- Most reaper dialogs (including FX windows) -- not a great UX because
        -- windows go into the foreground when hovered over.
        -- XXX: OTOH not a great UX without either.  Example: click FX slot to open FX
        -- window, move mouse over FX window -- focus gets stolen from window while
        -- moving over arrange view -- now typing a FX filter name doesn't work.
        ['#32770'] = 'hwnd',
    }

    if BaseApp.initialize(self, 'reaticulate', 'Reaticulate', basedir) == false then
        return
    end

    -- Currently selected track (or nil if no track is selected)
    self.track = nil
    -- The random cookie (a guid actually) stored in the current project and
    -- periodically regenerated. This is used to determine when the current
    -- active project changes.
    self.project_change_cookie = nil
    -- The last result of IsProjectDirty()
    self.project_dirty = nil
    -- Map of project state and refreshed in onprojectchange()
    self.project_state = nil
    -- A bitmap of constants defining actions that have been queued via App:queue().  0 means
    -- nothing is queued.
    self.queued_actions = 0
    -- The set of cookies for all currently opened project tabs, simply mapping the cookie
    -- guid to true for fast inclusion tests.  This table is maintained in
    -- handle_onupdate() and is used to distinguish between a project being opened versus
    -- just a project tab change.  This determination is passed to onprojectchange() so we
    -- can take certain actions on project load that are otherwise too expensive to do on
    -- every tab change (such a project bank GC).
    self.active_projects_by_cookie = {}

    -- The previously selected track.  This is never cleared to nil.
    self.last_track = nil
    -- Default MIDI Channel for banks not pinned to channels.  Offset from 1.
    self.default_channel = 1
    -- hwnd of the last seen MIDI editor
    self.midi_hwnd = nil
    -- The last selected take in the MIDI editor.  nil if the editor is closed.
    self.midi_editor_take = nil
    -- The track of the active take in the MIDI editor or nil if the editor is closed
    -- (or no take is selected).
    self.midi_editor_track = nil
    -- If true, then the default channel will be synced between Reaticulate's UI
    -- and the MIDI editor
    self.midi_linked = false
    -- Keys are 16-bit values with channel in byte 0, and group in byte 1 (offset from 1).
    self.active_articulations = {}
    -- Tracks articulations that have been activated but not yet processed by the RFX and/or
    -- detected by the GUI.  Same index and value as active_articulations.  Pending articulations
    -- that are processed and detected will be removed from this list.  Useful for fast events
    -- (e.g. scrolling through articulations via the relative CC action) where, for UX, we can't
    -- afford to wait for the full activation round trip.
    self.pending_articulations = {}
    -- The articulation that was explicitly last activated by the user on this track
    self.last_activated_articulation = nil
    -- Timestamp of the previous activation of a selected articulation.  Used to implement
    -- "double click" functionality for the "Activate selected articulation" action.
    self.last_activation_timestamp = nil
    -- Last focused window
    self.last_focused_hwnd = nil
-- Timestamp of when the focus last changed.
    self.last_focus_time = nil
    -- Window handle that should be refocused on articulation changes.  This is usually a
    -- Reaper window to avoid focus stealing on articulation change, but can be the
    -- Reaticulate window if the user keeps it focused for a period.
    self.saved_focus_window = nil
    -- If not nil, is the time a deferred refocus should trigger.
    self.refocus_target_time = nil
    -- True if we're running a version of REAPER that supports new actions to force reload
    -- track support data (reabank, notably) on selected tracks.  We use this to ensure REAPER
    -- notices when we swap out the global reabank.  The primary (only, really) use case is
    -- to force it to update the "PC" names in the arrange view.
    self.reaper_supports_track_data_reload = rtk.check_reaper_version(6, 46)

    articons.init()
    rfx.init()
    reabank.init()

    -- Migrate colors from reabank to configuration
    if not self.config.art_colors then
        self.config.art_colors = {}
        for color, value in pairs(reabank.default_colors) do
            if reabank.colors[color] and reabank.colors[color] ~= value then
                self.config.art_colors[color] = value
            end
        end
    end
    self:add_screen('installer', 'screens.installer')
    self:add_screen('banklist', 'screens.banklist')
    self:add_screen('trackcfg', 'screens.trackcfg')
    self:add_screen('settings', 'screens.settings')
    self:replace_screen('banklist')

    self:set_default_channel(1)
    self:run()
    local now = reaper.time_precise()
    log.debug('app: initialization took: %s (import=%s build=%s)', now-t0, t1-t0, now-t1)
end

function App:get_config()
    local cfg = BaseApp.get_config(self)
    if not cfg.default_channel_behavior then
        -- Default this setting based on how the "One MIDI editor per" setting is configured.
        local ok, editor = reaper.get_config_var_string('midieditor')
        -- If REAPER config value can't be determined, assume one per project
        editor = tonumber(editor) or 1
        -- If one per project or one per track is chosen, remember channel per track.
        if editor & 1 ~= 0 or editor & 2 ~= 0 then
            cfg.default_channel_behavior = 2
        else
            -- Editor per item, remember channel per item.
            cfg.default_channel_behavior = 3
        end
    end
    return cfg
end


-- Encodes the project_state field as JSON and saves it to the current project.
--
-- Don't call this function directly: use queue() instead.
function App:_run_queued_actions()
    local flags = self.queued_actions
    if flags & App.SAVE_PROJECT_STATE ~= 0 then
        local state = json.encode(self.project_state)
        reaper.SetProjExtState(0, 'reaticulate', 'state', state)
        log.info('app: saved project state (%s bytes)', #state)
        log.debug('app: current project state: %s', state)
    end
    if flags & App.REFRESH_BANKS_ACTIONS ~= 0 then
        self:refresh_banks(flags)
    elseif flags & App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK ~= 0 then
        -- We only need to do this if refresh_banks() wasn't called. If it was, this
        -- will happen automatically.
        if self:has_arrange_view_pc_names() or self.midi_hwnd then
            self:force_recognize_bank_change_one_track(rfx.current.track, true)
        end
    end
    self.queued_actions = 0
end

-- Queues a save of the current project state on the next defer cycle.
--
-- flags is a bitmap of constants that controls how the project state is
-- saved.
function App:queue(flags)
    if self.queued_actions == 0 then
        rtk.defer(self._run_queued_actions, self)
    end
    self.queued_actions = self.queued_actions | (flags or 0)
end

-- Dumps the project's MSB/LSB mappings.
function App:log_msblsb_mapping()
    local text = {}
    for guid, msblsb in pairs(self.project_state.msblsb_by_guid) do
        local bank = reabank.get_bank_by_guid(guid)
        text[#text+1] = string.format(
            '       %s -> %s/%s (%s)',
            guid, (msblsb >> 8) & 0xff, msblsb & 0xff,
            bank and bank.name or 'UNKNOWN!'
        )
    end
    log.debug('MSB/LSB assignment:\n%s', table.concat(text, '\n'))
end


-- Invoked by handle_onupdate() when the current project changes, which includes
-- changing project tabs or reloading the current project.
function App:onprojectchange(opened)
    local r, data = reaper.GetProjExtState(0, 'reaticulate', 'state')
    log.info('app: project changed (opened=%s cookie=%s)', opened, self.project_change_cookie)
    log.debug('app: loaded project state: %s', data)
    self.project_state = {}
    if r ~= 0 then
        local ok, decoded = pcall(json.decode, data)
        if ok then
            self.project_state = decoded
        else
            log.error('failed to restore Reaticulate project state: %s', decoded)
        end
    end

    -- Determine which actions we need to execute.  Minimally we know we'll need to
    -- refresh banks to generate the new project reabank.
    local flags = App.REFRESH_BANKS
    -- Inform the reabank module of the project change.  It will initialize and
    -- maintain any fields it needs within project state.
    reabank.onprojectchange()
    if r == 0 then
        -- There was no prior project state, so we assume it's a pre-0.5 project that ust
        -- be migrated. (This can also happen on new projects but then migration will just
        -- be a no-op.)
        log.info('app: beginning project migration to GUID')
        self:migrate_project_to_guid()
        -- Queue save project state now that we've migrated.
        flags = flags | App.SAVE_PROJECT_STATE
    end
    if opened then
        -- If we're loading a new project from scratch, ensure REAPER notices the new
        -- global reabank on all tracks in the project.  (This is slow, but will only do
        -- it if the project reabank has changes or additions relative to the current
        -- one). Also run a GC on project banks to remove any unreferenced banks.
        flags = flags | App.FORCE_RECOGNIZE_BANKS_PROJECT | App.CLEAN_UNUSED_BANKS
    end
    -- Queue actions determined by the above flags.
    self:queue(flags)
end

-- Invoked by handle_onupdate() when the current track changes.  cur represents
-- the REAPER track object, but this can be nil if no track is currently
-- selected.
--
-- Note: control surface feedback is done in handle_onupdate().
function App:ontrackchange(last, cur)
    -- Sanity check pointers which can go stale when changing projects
    last = reaper.ValidatePtr2(0, last, 'MediaTrack*') and last or nil
    cur = reaper.ValidatePtr2(0, cur, 'MediaTrack*') and cur or nil
    local lastn, curn
    if last then
        lastn = reaper.GetMediaTrackInfo_Value(last, 'IP_TRACKNUMBER')
    end
    if cur then
        curn = reaper.GetMediaTrackInfo_Value(cur, 'IP_TRACKNUMBER')
    end
    log.info('app: track change: %s -> %s', lastn, curn)

    reaper.PreventUIRefresh(1)
    self.screens.banklist.filter_entry:onchange()
    if cur then
        -- This fixes a general REAPER bug where tracks selected programmatically
        -- don't reflect on the control surface.  It's not specific to Reaticulate,
        -- but we have the opportunity to make REAPER suck a bit less with other
        -- scripts, so why not.
        reaper.CSurf_OnTrackSelection(cur)
        -- Sync the FX window if single floating FX is enabled.
        if self.config.single_floating_instrument_fx_window then
            self:do_single_floating_fx()
        end
    end
    -- Ensure we have detected any errors on this track and update the UI.
    self:check_banks_for_errors()
    reaper.PreventUIRefresh(-1)
end


local function _check_track_for_midi_events(track)
    for itemidx = 0, reaper.CountTrackMediaItems(track) - 1 do
        -- Fetch item and see if there are any MIDI CC events (that
        -- could possibly be program changes)
        local item = reaper.GetTrackMediaItem(track, itemidx)
        for takeidx = 0, reaper.CountTakes(item) - 1 do
            local take = reaper.GetTake(item, takeidx)
            local r = reaper.MIDI_GetCC(take, 0)
            if r then
                return true
            end
        end
    end
    return false
end

-- Clears the project guid-to-msblsb map and re-adds all currently referenced banks in the
-- project across all tracks.  This can act as a form of garbage collection by removing
-- bank references that are no longer used by the project.  But it only works if there are
-- no pre-0.5 disabled RFX in the project. (0.5+ is fine because of the move to native
-- track appdata which is accessible even when the track is disabled.)
function App:migrate_project_to_guid()
    -- Start by assuming Bank GC (i.e. removal of unreferenced bank guid->msb/lsb mappings)
    -- is fine.  We set to false if we find a disabled RFX on a track without P_EXT appdata,
    -- because it means the appdata is stored in the RFX (pre-0.5) and as it's disabled we
    -- can't read it, can't know what banks it needs, and therefore can't be sure we can
    -- safely remove a bank reference from the project.
    self.project_state.gc_ok = true

    log.time_start()
    local old = self.project_state.msblsb_by_guid
    self.project_state.msblsb_by_guid = {}
    for idx, rfxtrack in rfx.get_tracks(0, true) do
        if rfxtrack.appdata == nil then
            -- Here we have a disabled RFX with no appdata, which means it's a pre-0.5
            -- track.  Since we don't have a global view of all Reaticulate banks assigned
            -- to the project, we will be unable to garbage collect.
            self.project_state.gc_ok = false
        else
            for b, migrator in rfxtrack:get_banks(true) do
                if b.type == 'g' and b.bank then
                    -- Already GUID-based bankinfo, nothing to migrate. Add bank to
                    -- project based on the previously assigned MSB/LSB for this bank.  If
                    -- this MSB/LSB conflicts with another bank in the project, then the
                    -- migrator will take care of updating all PC events in the project
                    -- when we call remap_bank_select_msblsb() below.
                    --
                    -- Initialize to nil: if there is no previously assigned MSB/LSB then we
                    -- pass nil for these values to add_bank_to_project() which will assign
                    -- arbitrary values, rather than trying to reuse the previous mapping.
                    local msb, lsb
                    local last = old[b.guid]
                    if last then
                        msb, lsb = last and last >> 8, last and last & 0xff
                    end
                    migrator:add_bank_to_project(b.bank, msb, lsb)
                end
                if not b.bank then
                    -- Referenced bank was not found.
                    if b.type == 'g' and b.guid then
                        -- This is a GUID bank that we couldn't find on the system.  If
                        -- the old project state had an MSB/LSB mapping for this GUID,
                        -- then let's preserve that mapping in case the bank gets imported
                        -- later.  (If it's missing, then old[bankinfo.v] will be nil,
                        -- making the assignment a no-op.)
                        self.project_state.msblsb_by_guid[b.guid] = old[b.guid]
                        log.warning('app: bank GUID not found: %s', b.guid)
                    else
                        log.warning('app: legacy bank MSB/LSB not found: %s', b.v)
                    end
                end
            end
        end
    end
    log.info('app: done full track scrub')
    log.time_end()
    return true
end

-- GC banks that were previously mapped but then removed for the project.
function App:clean_unused_project_banks()
    -- Just wrap the migration code which serves the same purpose.
    self:migrate_project_to_guid()
end

-- Returns the 2-tuple {hwnd, fxid} for the first instrument FX on the
-- given track.
local function get_instrument_hwnd_for_track(track)
    if track then
        local vsti = reaper.TrackFX_GetInstrument(track)
        if vsti >= 0 then
            return reaper.TrackFX_GetFloatingWindow(track, vsti), vsti
        end
    end
    return nil, nil
end

-- Called via ontrackchange() and ensures there is only one floating window for
-- instrument FX.
function App:do_single_floating_fx()
    if not rtk.has_js_reascript_api then
        return
    end
    log.time_start()
    local cur = self.track
    -- Find tracks that have floating instrument FX windows.
    local lastfx = nil
    local tracks = {}
    local hidden = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local hwnd, fx = get_instrument_hwnd_for_track(track)
        if hwnd then
            if reaper.JS_Window_IsVisible(hwnd) then
                tracks[#tracks+1] = {track, fx, hwnd}
                if track == self.last_track then
                    lastfx = tracks[#tracks]
                end
            else
                hidden[#hidden+1] = {track, fx}
            end
        end
    end
    if #tracks > 0 and self.config.single_floating_instrument_fx_window then
        if not lastfx then
            lastfx = tracks[1]
        end
        if #tracks > 1 then
            -- We have more than one track with an open floating instrument FX, so
            -- first indiscriminately close all of them except for lastfx.
            for i, fxinfo in ipairs(tracks) do
                if fxinfo[1] ~= lastfx[1] and fxinfo[1] ~= cur then
                    reaper.TrackFX_Show(fxinfo[1], fxinfo[2], 2)
                end
            end
        end
        local last_track, last_fx, last_hwnd = table.unpack(lastfx)
        local cur_hwnd, cur_fx = get_instrument_hwnd_for_track(cur)
        if not cur_hwnd and cur_fx then
            reaper.TrackFX_Show(cur, cur_fx, 3)
            cur_hwnd, _ = get_instrument_hwnd_for_track(cur)
        end
        if cur_hwnd and last_hwnd and cur_hwnd ~= last_hwnd then
            local _, target_x, target_y, _, _ = reaper.JS_Window_GetRect(last_hwnd)
            reaper.JS_Window_Move(cur_hwnd, target_x, target_y)
            reaper.JS_Window_Show(cur_hwnd, "SHOW")
            reaper.JS_Window_SetZOrder(cur_hwnd, "INSERT_AFTER", last_hwnd)
            -- TODO: would be good to move hidden window to last_hwnd's prior position and
            -- pinned status
            rtk.defer(reaper.JS_Window_Show, last_hwnd, "HIDE")
        end
        self:refocus()
    end

    -- TODO: maintain LRU cache of N items so we don't keep gobs of FX windows mapped
    if (#tracks == 0 and #hidden > 0) or not self.config.single_floating_instrument_fx_window then
        -- No visible instrument FX but we did have some hidden ones.  Close those
        -- properly now.
        rtk.defer(function()
            for i, fxinfo in ipairs(hidden) do
                local _, name = reaper.GetTrackName(fxinfo[1], "")
                reaper.TrackFX_Show(fxinfo[1], fxinfo[2], 2)
            end
        end)
    end
    log.debug("app: done manging fx windows")
    log.time_end()
end


-- Returns the active take on the given track and and time position.
function App:get_take_at_position(track, pos)
    if not track then
        return
    end
    for idx = 0, reaper.CountTrackMediaItems(track) - 1 do
        local item = reaper.GetTrackMediaItem(track, idx)
        local startpos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        local endpos = startpos + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        if pos >= startpos and pos < endpos then
            return item, reaper.GetActiveTake(item)
        end
    end
end

-- Deletes all bank select or program change events at the given ppq. The caller passes an
-- index of a CC event which must exist at the ppq, but in case there are multiple events
-- at that ppq, it's not required that it's the first.
--
-- Returns {msb, lsb, program} of the last PC event deleted within the range.
local function _delete_program_events_at_ppq(take, channel, idx, max, startppq, endppq)
    -- The supplied index is at the ppq, but there may be others ahead of it.  So
    -- rewind to the first.
    while idx >= 0 do
        local rv, selected, muted, evtppq, command, evtchan, msg2, msg3 = reaper.MIDI_GetCC(take, idx)
        if evtppq ~= startppq then
            break
        end
        idx = idx - 1
    end
    local lastmsb, lastlsb, msb, lsb, program = nil, nil, nil, nil, nil
    idx = idx + 1
    -- Now idx is the first CC at ppq.  Enumerate subsequent events and delete
    -- any bank selects or program changes until we move off the ppq.
    while idx < max do
        local rv, selected, muted, evtppq, command, evtchan, msg2, msg3 = reaper.MIDI_GetCC(take, idx)
        if evtppq < startppq or evtppq > endppq then
            break
        end
        if command == 0xb0 and msg2 == 0 and channel == evtchan then
            lastmsb = msg3
            reaper.MIDI_DeleteCC(take, idx)
        elseif command == 0xb0 and msg2 == 32 and channel == evtchan then
            lastlsb = msg3
            reaper.MIDI_DeleteCC(take, idx)
        elseif command == 0xc0 and channel == evtchan then
            msb, lsb, program = lastmsb, lastlsb, msg2
            reaper.MIDI_DeleteCC(take, idx)
        else
            -- If we deleted the event, we don't advance idx because the old value would
            -- point to the adjacent event.  Otherwise we do need to increment it.
            idx = idx + 1
        end
    end
    return msb, lsb, program
end

-- Finds the index of the CC event in the given take and at the given ppq position.
-- Note that *any* CC will do, this does not filter for program changes.
--
-- Returns a table consisting of the following elements:
--  * found: true/false if there was a CC at the given ppq
--  * previdx: the index of the CC event immediately preceding the ppq
--  * prevppq: the ppq of the previous CC
--  * nextidx: the index of the CC event either at ppq (if found is true) or
--             immediately following ppq (if found is false).
--  * nextppq: the ppq of nextidx, which will be the same as the supplied ppq
--             when found is true.
--  * n_events: total number of MIDI events on this take
local function _get_cc_idx_at_ppq(take, ppq)
    -- This is a bit tragic.  There's no native function to get a list of MIDI events given a
    -- ppq.  So knowing that the event indexes will be ordered by time, we do a binary search
    -- across the events until we converge on the ppq.
    local _, _, n_events, _ = reaper.MIDI_CountEvts(take)
    local skip = math.floor(n_events / 2)
    local idx = skip
    local previdx, prevppq = nil, nil
    local nextidx, nextppq = nil, nil
    while idx > 0 and idx < n_events and skip > 0.5 do
        local rv, _, _, evtppq, _, evtchan, _, _ = reaper.MIDI_GetCC(take, idx)
        -- ppq calculated from cursor positions can be fractional, although inserted
        -- events seem to always be rounded to integer values.  Here we accept any
        -- ppq that's within 1 ppq of the target.
        local delta = math.abs(evtppq - ppq)
        if delta < 1 then
            return true, previdx, prevppq, idx, evtppq, n_events
        end
        skip = skip / 2
        if evtppq > ppq then
            nextidx, nextppq = idx, evtppq
            -- Event is ahead of target ppq, back up.
            idx = idx - math.ceil(skip)
        elseif evtppq < ppq then
            previdx, prevppq = idx, evtppq
            -- Event is behind target ppq, skip ahead.
            idx = idx + math.ceil(skip)
        end
    end
    return false, previdx, prevppq, nextidx, nextppq, n_events
end

-- Deletes all PC events between startppq and endppq on the given take and channel.
-- Returns the MSB, LSB, and program number of the last PC that was deleted.
local function _delete_program_changes(take, channel, startppq, endppq)
    local found, _, _, idx, ppq, n_events = _get_cc_idx_at_ppq(take, startppq)
    if not found then
        return
    end
    local msb, lsb, program = _delete_program_events_at_ppq(take, channel, idx, n_events, ppq, endppq)
    return msb, lsb, program
end

-- Inserts a PC at the given take and ppq.
--
-- If there's an existing PC at the given ppq then it's replaced, provided that
-- overwrite is true.
local function _insert_program_change(take, ppq, channel, msb, lsb, program, overwrite)
    -- If the events at the ppq are program changes, we delete them (as we're about to
    -- replace them).  foundppq may differ from ppq even if found is true, because the
    -- incoming ppq could be fractional, but event ppqs appear to be rounded.  So we need
    -- to use the event's actual ppq later when we delete existing PCs.
    local found, _, _, idx, foundppq, n_events = _get_cc_idx_at_ppq(take, ppq)
    if found then
        if not overwrite then
            -- FIXME: this doesn't actually work.  found indicates that *some* event
            -- is found at that ppq, not that specifically a program change is
            -- found.
            log.exception('TODO: fix this bug')
            return
        end
        _delete_program_events_at_ppq(take, channel, idx, n_events, foundppq, foundppq)
    end
    -- Insert program change at ppq.  MIDI_Sort() isn't needed with MIDI_InsertCC().
    reaper.MIDI_InsertCC(take, false, false, ppq, 0xb0, channel, 0, msb)
    reaper.MIDI_InsertCC(take, false, false, ppq, 0xb0, channel, 32, lsb)
    reaper.MIDI_InsertCC(take, false, false, ppq, 0xc0, channel, program, 0)
end

-- Identify all selected notes and queue an insertion at the first selected note and at
-- any note where there is a gap in the selection (i.e. there is an unselected note before
-- the selected note).
--
-- Returns two tables:
--   insert_ppqs: a list of {take, ppq, channel, program} tables representing all positions
--                where an articulation needs to be inserted.
--   delete_ppqs: a list of {take, startppq, endppq, channel} representing all ranges where
--                existing PC events need to be deleted prior to any insertions, because
--                the new insertions intend to replace them.
local function _get_insertion_points_by_selected_notes(take, program)
    -- List of {take, ppq, channel} the articulation should be inserted at
    -- (assuming force_insert is true)
    local insert_ppqs = {}
    -- Table of {take, startppq, endppq, channel} indicating the ranges between which all
    -- program changes should be deleted prior to insertion.
    local delete_ppqs = {}
    -- Insertions at notes are offset by this amount (3ms)
    -- Offset used for insertions at notes.
    local offset = 0
    -- XXX: disabled for now as it may not be necessary and it's a
    -- kludge worth avoiding if possible.
    -- offset = reaper.MIDI_GetPPQPosFromProjTime(take, 0.003) -
    --          reaper.MIDI_GetPPQPosFromProjTime(take, 0)

    local idx = -1
    -- Contiguous selection ranges by channel.
    -- channel -> {startidx, startppq, endidx, endppq}
    local selranges = {}
    local last_notes = {}
    -- There is something about the way MIDI_EnumSelNotes() works that
    -- makes me suspicious about infinite loops.  So out of paranoia we
    -- ensure we don't loop more than there are notes in the take.
    local paranoia_counter = 0
    local _, n_notes, _, _ = reaper.MIDI_CountEvts(take)
    while paranoia_counter <= n_notes do
        local nextidx = reaper.MIDI_EnumSelNotes(take, idx)
        if nextidx == -1 then
            break
        end
        local r, _, _, noteppq, noteppqend, notechan, _, _ = reaper.MIDI_GetNote(take, nextidx)
        if not r then
            -- This shouldn't happen, so abort altogether if it does.
            break
        end
        last_notes[notechan] = {nextidx, noteppq}
        -- Loop through all unselected notes between last selected
        -- note and this selected note (if any) and look for gaps.
        -- We also insert at the next selected note of any gap (per
        -- channel)
        if idx ~= -1 then
            for unselidx = idx + 1, nextidx - 1 do
                local r, _, _, _, _, unselchan, _, _ = reaper.MIDI_GetNote(take, unselidx)
                if not r then
                    -- Again, shouldn't really happen.
                    break
                end
                local selinfo = selranges[unselchan]
                if selinfo and selinfo[3] then
                    -- We have an unselected note which means we've started a gap
                    -- on this channel, but there was previously a contiguous selection
                    -- range.  Mark programs in that range for deletion.
                    delete_ppqs[#delete_ppqs + 1] = {take, selinfo[2], selinfo[4], unselchan}
                end
                selranges[unselchan] = nil
            end
        end
        if not selranges[notechan] then
            -- Always insert articulation at first selected note of channel.
            insert_ppqs[#insert_ppqs + 1] = {take, math.ceil(noteppq - offset), notechan, program}
            selranges[notechan] = {nextidx, noteppq - offset, nil, nil}
        else
            selranges[notechan][3] = nextidx
            selranges[notechan][4] = noteppq - offset
        end
        idx = nextidx
        paranoia_counter = paranoia_counter + 1
    end
    for ch, selinfo in pairs(selranges) do
        if selinfo[3] then
            -- Delete programs in all remaining ranges at the end of the
            -- selection (after all gaps) on each channel.
            delete_ppqs[#delete_ppqs + 1] = {take, selinfo[2], selinfo[4], ch}
        end
    end

    -- After marking selection boundaries for insertion of the new articulation, now we
    -- insert the previous articulation at the next unselected note outside of the
    -- selection, to preserve its articulation as it wasn't part of the selection.
    --
    -- XXX: disabled because it's janky.
    --[[
    for ch, noteinfo in pairs(last_notes) do
        local idx, lastppq = table.unpack(noteinfo)
        -- Find the next note on that channel
        for idx = idx + 1, n_notes do
            local r, _, _, noteppq, noteppqend, notechan, _, _ = reaper.MIDI_GetNote(take, idx)
            if not r then
                break
            end
            if notechan == ch then
                -- Find a PC on that channel before this note.  Provided the PC is before the
                -- last selected note, we will use that PC for this note.
                local ccidx = idx
                while ccidx >= 0 do
                    local rv, _, _, ccppq, msg1, ccchan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
                    log.info('   CC was: %s %s %s', msg1, msg2, msg3)
                    if rv and msg1 == 0xc0 and ccchan == notechan then
                        -- This is a PC on the note's channel.
                        if ccppq < lastppq then
                            log.info('    - insert')
                            insert_ppqs[#insert_ppqs + 1] = {take, math.ceil(noteppq - offset), notechan, msg2}
                        end
                        break
                    end
                    ccidx = ccidx - 1
                end
                break
            end
        end
    end
    --]]
    return insert_ppqs, delete_ppqs
end

-- Inserts an PC event on the given rfx.Track. The take object, if defined, is the take
-- within which the articulation is to be inserted, but if nil then a suitable take is
-- found at the edit cursor position.  A new item is created if necessary.
--
-- If bank is provided, then it's a reabank.Bank object that, otherwise it's nil and a
-- bank will be discovered on the track that contains the given program number.  The
-- latter is used for inserting articulations on multiple tracks at the same time,
-- in which case we can't pass a single bank and must discover it.  In this situation,
-- if no bank can be found that defines the given program, false is returned.
--
-- Channel is offset 0.
--
-- Return value is true if the articulation was inserted, or false otherwise which
-- can happen if bank is nil and no valid program can be found on the track.
function App:_insert_articulation(rfxtrack, bank, program, channel, take, skip_create_item)
    local track = rfxtrack.track
    local insert_ppqs, delete_ppqs
    if take and reaper.ValidatePtr(take, 'MediaItem_Take*') then
        -- We have a take in the MIDI editor.  Check it for selected notes.
        insert_ppqs, delete_ppqs = _get_insertion_points_by_selected_notes(take, program)
    end

    local msb, lsb
    if bank then
        -- Bank was supplied, so use it.
        msb, lsb = bank:get_current_msb_lsb()
    else
        -- Bank not supplied, so find the (first) bank MSB/LSB on the track that contains
        -- this program, and use that for insertion.
        for b in rfxtrack:get_banks() do
            -- If the bank has the program number and it's mapped on the requested
            -- channel, then use its MSB/LSB. Note that srcchannel is offset 1, while
            -- given channel is offset 0.
            if (b.srcchannel == 17 or b.srcchannel == channel+1) and
               b.bank and b.bank:get_articulation_by_program(program) then
                msb, lsb = b.bank:get_current_msb_lsb()
                break
            end
        end
    end
    if not msb or not lsb then
        local n = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
        log.warning('app: program %d could not be found on track %d for insertion', program, n)
        return false
    end

    -- If we haven't managed to find selected notes (assuming the feature is even
    -- enabled), then fall back to the take at the edit cursor and use the cursor position
    -- for the articulation insertion point.  This may not be the take active in the MIDI
    -- editor either, if the edit cursor is somewhere else.
    if not insert_ppqs or #insert_ppqs == 0 then
        local cursor = reaper.GetCursorPositionEx(0)
        _, take = self:get_take_at_position(track, cursor)
        if take then
            local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursor)
            insert_ppqs = {{take, ppq, nil, program}}
            -- Note: deletion of any existing PCs at this ppq is taken care of by
            -- _insert_program_change() later.
        elseif not skip_create_item then
            local item = reaper.CreateNewMIDIItemInProj(track, cursor, cursor + 1, false)
            -- CreateNewMIDIItemInProj() does not honor project defaults. There's no easy
            -- way to determine what they are, so we just default to the more sane
            -- behavior of not looping MIDI items.
            reaper.SetMediaItemInfo_Value(item, 'B_LOOPSRC', 0)
            take = reaper.GetActiveTake(item)
            local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursor)
            insert_ppqs = {{take, ppq, nil, program}}
        else
            -- We've been told to skip creation of a new item, and there's no take under
            -- the edit cursor, so we're done.
            return
        end
    end

    if delete_ppqs then
        for _, range in ipairs(delete_ppqs) do
            local take, startppq, endppq, delchan = table.unpack(range)
            _delete_program_changes(take, delchan, startppq, endppq)
        end
    end

    local takes = {}
    for _, ppqchan in ipairs(insert_ppqs) do
        local take, ppq, chan, program = table.unpack(ppqchan)
        _insert_program_change(take, ppq, chan or channel, msb, lsb, program, true)
        takes[take] = 1
    end
    for take, _ in pairs(takes) do
        local item = reaper.GetMediaItemTake_Item(take)
        local track = reaper.GetMediaItem_Track(item)
        reaper.UpdateItemInProject(item)
        reaper.MarkTrackItemsDirty(track, item)
    end

    -- The 1 for flags indicates this articulation (plus other channels)
    -- should be saved by the JSFX in the new undo history slot (having
    -- advanced it above).  This allows redo after an undo if it's the last
    -- program change in the undo history, and also ensures that if we undo
    -- we restore this articulation instead of temporary changes the user
    -- may have done in the interim.
    rfxtrack:activate_articulation(channel, program, 1)
    return true
end

-- Activates and possibly inserts an articulation on the given channel.
--
-- An articulation that's activated twice within 500ms is automatically inserted.
-- Otherwise it won't be inserted unless force_insert is true.
--
-- Insertion position depends on the insert-at-selected-notes option is enabled
-- (which it is by default).  If enabled, articulations are inserted at the beginning
-- of each independent group of notes on all applicable note channels.  If disabled,
-- or if no notes are selected, then insertion occurs at the edit cursor, creating a
-- new item if necessary.
--
-- If refocus is true, then the last window that had focus will be refocused after
-- the articulation is activated (500ms after, specifically, to allow for double-
-- click insertions).
function App:activate_articulation(art, refocus, force_insert, channel, insert_at_cursor)
    if not art or art.program < 0 then
        return false
    end
    log.time_start()
    if refocus then
        -- If not already force inserting, delay a refocus by 500ms to give a chance for
        -- double click.
        self:refocus_delayed(force_insert and 0 or 0.5)
    end

    local bank = art:get_bank()
    local srcchannel = bank:get_src_channel(channel or app.default_channel) - 1

    local recording = reaper.GetAllProjectPlayStates(0) & 4 ~= 0
    if recording then
        -- If the transport is recording then stuff the program change instead of
        -- insertion.  This ensures the events are part of the undo state of the
        -- record action, and an undo action will undo the entire record action.
        -- Otherwise, with insertion, you end up with articulations in the undo
        -- history independent of the recording, which would be unexpected.
        local msb, lsb = bank:get_current_msb_lsb()
        reaper.StuffMIDIMessage(0, 0xb0 + srcchannel, 0, msb)
        reaper.StuffMIDIMessage(0, 0xb0 + srcchannel, 0x20, lsb)
        reaper.StuffMIDIMessage(0, 0xc0 + srcchannel, art.program, 0)
        art.button.start_insert_animation()
        return
    end

    -- Force insert if activated within 500ms
    if not force_insert or force_insert == 0 then
        local delta = reaper.time_precise() - (self.last_activation_timestamp or 0)
        if delta < 0.5 and art == self.last_activated_articulation then
            force_insert = true
            if refocus then
                -- Immediately refocus and override the delayed refocus from the first
                -- click.
                self:refocus_delayed(0)
            end
        end
    end
    self.last_activation_timestamp = reaper.time_precise()

    -- Find active take for articulation insertion.
    local insert_ppqs, delete_ppqs
    if force_insert and force_insert ~= 0 then
        local midi_take, midi_track
        if self.config.art_insert_at_selected_notes and not insert_at_cursor then
            -- We want to insert the articulation based on selected notes.
            -- So look for the best take to find selected notes.

            -- If MIDI Editor is open, use the current take there.
            local hwnd = reaper.MIDIEditor_GetActive()
            if hwnd then
                midi_take = reaper.MIDIEditor_GetTake(hwnd)
            end
            if not hwnd and rfx.current.track then
            -- MIDI editor isn't open.  If the inline MIDI editor open on any
            -- selected take on the current track, look there for selected
            -- notes.
                for idx = 0, reaper.CountSelectedMediaItems(0) - 1 do
                    local item = reaper.GetSelectedMediaItem(0, idx)
                    if reaper.GetMediaItem_Track(item) == rfx.current.track then
                        local itemtake = reaper.GetActiveTake(item)
                        if reaper.BR_IsMidiOpenInInlineEditor(itemtake) then
                            midi_take = itemtake
                            break
                        end
                    end
                end
            end
            if midi_take and reaper.ValidatePtr(midi_take, 'MediaItem_Take*') then
                midi_track = reaper.GetMediaItemTake_Track(midi_take)
            end
        end

        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock2(0)

        -- Insert the articulation on all selected tracks.  For the selected that that is
        -- the current RFX track (which would be the first track in the selection), then
        -- we use the bank for the given Articulation object.  For all other tracks, we
        -- pass nil to _insert_articulation() and let it discover the appropriate bank for
        -- the program and channel.
        --
        -- Remember which track numbers we inserted on, so we don't duplicate insertions
        -- when we look at selected MIDI items later.
        local inserted_tracks = {}
        -- We'll reuse this rfx.Track instance as we iterate over selected tracks and items
        local rfxtrack = rfx.Track()
        for i = 0, reaper.CountSelectedTracks(0) - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            local n = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
            local take = midi_track == track and midi_take
            if track == rfx.current.track then
                self:_insert_articulation(rfx.current, bank, art.program, srcchannel, take)
                inserted_tracks[n] = true
            else
                if rfxtrack:presync(track) then
                    self:_insert_articulation(rfxtrack, nil, art.program, srcchannel, take)
                    inserted_tracks[n] = true
                end
            end
        end
        -- Now insert the articulation on all selected media items when the items are on
        -- Reaticulate-managed tracks and they intersect with the editor cursor.
        --
        -- XXX: disabled for now. Needs further consideration as this breaks key workflows
        --[[
        for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            local track = reaper.GetMediaItem_Track(item)
            local n = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
            if not inserted_tracks[n] and rfxtrack:presync(track) then
                local take = reaper.GetActiveTake(item)
                -- Pass true here to skip creation of new items if there isn't already one
                -- under the edit cursor.
                self:_insert_articulation(rfxtrack, nil, art.program, srcchannel, take, true)
            end
        end
        ]]--

        -- Advances the undo history serial slider in the JSFX.  This causes the
        -- old value to be retained in Reaper's undo history.  We actually store
        -- the state for the new undo slot below in rfx.activate_articulation().
        rfx.current:opcode(rfx.OPCODE_ADVANCE_HISTORY)
        rfx.current:opcode_flush()
        reaper.Undo_EndBlock2(0, "Reaticulate: insert articulation (" .. art.name .. ")", UNDO_STATE_ITEMS | UNDO_STATE_FX)
        reaper.PreventUIRefresh(-1)
        art.button.start_insert_animation()
    else
        rfx.current:activate_articulation(srcchannel, art.program)
        local ntracks = reaper.CountSelectedTracks(0)
        if ntracks > 1 then
            local rfxtrack = rfx.Track()
            for i = 0, ntracks - 1 do
                local track = reaper.GetSelectedTrack(0, i)
                if track ~= rfx.current.track and rfxtrack:presync(track) then
                    rfxtrack:activate_articulation(srcchannel, art.program)
                end
            end
        end
    end

    -- Set articulation as pending.
    local idx = (srcchannel + 1) + (art.group << 8)
    self.pending_articulations[idx] = art
    self.last_activated_articulation = art

    -- Defer unsetting hover until next update so we can check the rfx once again to
    -- detect the new articulation choice.  This prevents flickering.
    local banklist = self.screens.banklist
    if banklist.selected_articulation then
        rtk.defer(banklist.clear_selected_articulation)
    end
    log.time_end('app: done activation/insert')
end

-- A slightly more robust variant of activate_articulation() that tolerates the
-- Articulation object being nil.
--
-- If not nil, then it's activated as if activate_articulation() was called directly. If
-- nil, however, then the control surface is resynced based on the current articulation.
-- This handles articulation change requests coming from control surfaces that may have
-- opportunistically updated, and as the requested articulation didn't actually exist, the
-- control surface needs to be updated to reflect the old articulation is still active.
function App:activate_articulation_if_exists(art, refocus, force_insert, insert_at_cursor)
    if art then
        self:activate_articulation(art, refocus, force_insert, nil, insert_at_cursor)
    else
        -- Requested articulation doesn't exist.  We re-sync current articulations to the
        -- control surface (if feedback is enabled) to handle the case where the articulation
        -- was triggered from a control surface which may now be in an incorrect state.
        feedback.sync(self.track, feedback.SYNC_ARTICULATIONS)
    end
end

-- Inserts the last activated articulation.
function App:insert_last_articulation(channel)
    local art = self.last_activated_articulation
    if not art then
        art = self:get_active_articulation(channel)
    end
    if art then
        self:activate_articulation(art, false, true, channel)
    end
end

-- Activates an articulation relative to the current active articulation in the given
-- group.  Distance indicates the number of slots adjacent to the current articulation,
-- where negative numbers are before, and positive numbers are after.  All values wrap
-- as needed.
function App:activate_relative_articulation_in_group(channel, group, distance)
    local target
    local banklist = self.screens.banklist
    local current = self:get_active_articulation(channel, group)
    if current then
        target = banklist.get_relative_articulation(current, distance, group)
    else
        target = banklist.get_firstlast_articulation(distance < 0)
    end
    if target then
        self:activate_articulation(target, false, false)
    end
end

-- Activates whatever articulation is currently selected in the banklist screen (by means
-- of the banklist's select_relative_articulation() function).
function App:activate_selected_articulation(channel, refocus, force_insert, insert_at_cursor)
    local banklist = self.screens.banklist
    local current = banklist.get_selected_articulation()
    if not current then
        current = self.last_activated_articulation
    end
    if current then
        self:activate_articulation(current, refocus, force_insert, channel, insert_at_cursor)
        rtk.defer(banklist.clear_filter)
    end
end

-- Schedules a refocus of the currently-focused window after the given delay.
--
-- delay is in seconds, and can be fractional.  If hwnd is specified, then it's
-- used instead of the currently focused hwnd.  defer is an internal argument
-- used for self-invocation.
function App:refocus_delayed(delay, hwnd, defer)
    hwnd = hwnd or self.saved_focus_window
    if hwnd == rtk.focused_hwnd then
        return
    end
    local now = reaper.time_precise()
    if delay then
        if not self.refocus_target_time then
            -- Refocus not already running.
            defer = true
        end
        -- Set (or reset) target time
        self.refocus_target_time = now + delay
    elseif not self.refocus_target_time then
        -- Cancelled (or completed immediately by passing delay=0)
        return
    end
    if now >= self.refocus_target_time then
        self.refocus_target_time = nil
        self:refocus(hwnd)
    elseif defer then
        rtk.defer(self.refocus_delayed, self, nil, hwnd, true)
    end
end

-- Immediately refocuses the last focused window, or the given hwnd if specified.
--
-- This is most robust with js_ReaScriptAPI as we can focus specific windows.  Without the
-- extension, we either focus the MIDI editor or the arrange view, based on whether the
-- MIDI editor is currently open.  It's a dubious heuristic but hopefully better than
-- focus-stealing.
function App:refocus(hwnd)
    hwnd = hwnd or self.saved_focus_window
    if hwnd then
        reaper.JS_Window_SetFocus(hwnd)
    else
        -- No JS extension so we do our best at guessing.
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
end

-- Called by RFX just before we clear the current RFX-enabled track. This currently just
-- remembers the banklist scroll position in the track data.
function rfx.onunsubscribe()
    app.screens.banklist.save_scroll_position()
end

-- Called by the RFX when an articulation is changed. This happens both in response to an
-- articulation change induced by the UI, but also occurs during playback, or when an
-- articulation has been manually activated via note-based keyswitch.
function rfx.onartchange(channel, group, last_program, new_program, track_changed)
    log.debug("app: articulation change: %s -> %d  (ch=%d group=%d)", last_program, new_program, channel, group)
    local artidx = channel + (group << 8)
    local last_art = app.active_articulations[artidx]
    local channel_bit = 2^(channel - 1)

    -- If there is an active articulation in the same channel/group, then unset the old one now.
    if last_art then
        last_art.channels = last_art.channels & ~channel_bit
        if last_art.channels == 0 then
            if last_art.button then
                last_art.button:attr('flat', 'label')
            end
            app.active_articulations[artidx] = nil
        end
    end

    app.pending_articulations[artidx] = nil

    local banks = rfx.current.banks_by_channel[channel]
    if banks then
        for _, bank in ipairs(banks) do
            local art = bank.articulations_by_program[new_program]
            if art and art.group == group then
                art.channels = art.channels | channel_bit
                -- If articulaton button exists then reset flat state
                if art.button then
                    art.button:attr('flat', false)
                end
                app.active_articulations[artidx] = art
                if not track_changed then
                    app.screens.banklist.scroll_articulation_into_view(art)
                end
                break
            end
        end
    end
    app.window:queue_draw()
end

-- Called by the RFX when the active notes are changed.
function rfx.onnoteschange(old_notes, new_notes)
    -- Force redraw of articulation buttons to reflect state change.
    if app:current_screen() == app.screens.banklist then
        app.window:queue_draw()
    end
end

-- Called by the RFX when CC values for the current default channel changes.
-- XXX: disabled for now, as rfx.Track:sync() does not subscribe to CC changes.
function rfx.onccchange()
    -- log.info('CC CHANGE: %s', rfx.current:get_cc_value(1))
end


-- Given a channel number (which can be stringified), returns either the channel given or,
-- if channel is 0, returns the current default channel.
--
-- Used for incoming commands where channel arguments use 0 to signify default channel.
local function _cmd_arg_to_channel(arg)
    local channel = tonumber(arg)
    if channel == 0 then
        return app.default_channel
    else
        return channel
    end
end

-- For actions meant to be controlled by MIDI CC or mouse wheel, this function calculates
-- a meaningful distance given the mode, resolution, and offset which come from
-- reaper.get_action_context().
local function _cmd_arg_to_distance(mode, resolution, offset)
    local mode = tonumber(mode)
    local resolution = tonumber(resolution)
    local offset = tonumber(offset)

    -- Normalize offset into distance
    if mode == 2 and offset % 15 == 0 then
        -- Mode 2 is used by mousewheel as well.  Encoder left/wheel down is negative,
        -- encoder right/wheel up is positive.  So we actually want to invert the mouse wheel
        -- direction (such that down is positive).  Also, we need to treat the sensitivity
        -- differently for mouse.  Unfortunately the only way to detect it is the heuristic
        -- that values from mousewheel events are integer multiples of 15.
        return -offset / 15
    else
        -- MIDI CC activated.  Adjust based on resolution and reduce the velocity effect.
        local sign = offset < 0 and -1 or 1
        return sign * math.ceil(math.abs(offset) * 16.0 / resolution)
    end
end


-- Handles a command dispatched by BaseApp:check_commands().  Commands are
-- received via non-persisted global REAPER state, based on the app id (which
-- is 'reaticulate'), and the 'command' key.
--
-- See actions/*.lua for the sending side.
function App:handle_command(cmd, arg)
    if cmd == 'set_default_channel' then
        -- Setting the default channel will implicitly call feedback.sync()
        -- so we don't need to do it here.
        self:set_default_channel(tonumber(arg))

    elseif cmd == 'activate_articulation' and rfx.current:valid() then
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
        self:activate_articulation_if_exists(art, false, force_insert)

    elseif cmd == 'activate_articulation_by_slot' and rfx.current:valid() then
        local args = string.split(arg, ',')
        local channel = _cmd_arg_to_channel(args[1])
        local slot = tonumber(args[2])
        local art = nil
        for _, bank in ipairs(self.screens.banklist.visible_banks) do
            if bank.srcchannel == 17 or bank.srcchannel == channel then
                if slot > #bank.articulations then
                    slot = slot - #bank.articulations
                else
                    art = bank.articulations[slot]
                    break
                end
            end
        end
        self:activate_articulation_if_exists(art, false, false)

    elseif cmd == 'activate_relative_articulation' and rfx.current:valid() then
        local args = string.split(arg, ',')
        local channel = _cmd_arg_to_channel(args[1])
        local group = tonumber(args[2])
        local distance = _cmd_arg_to_distance(args[3], args[4], args[5])
        self:activate_relative_articulation_in_group(channel, group, distance)

    elseif cmd == 'select_relative_articulation' and rfx.current:valid() then
        local args = string.split(arg, ',')
        local distance = _cmd_arg_to_distance(args[1], args[2], args[3])
        self.screens.banklist.select_relative_articulation(distance)

    elseif cmd == 'activate_selected_articulation' and rfx.current:valid() then
        local args = string.split(arg, ',')
        local channel = _cmd_arg_to_channel(args[1])
        self:activate_selected_articulation(channel, false)

    elseif cmd == 'insert_articulation' then
        local args = string.split(arg, ',')
        local channel = _cmd_arg_to_channel(args[1])
        self:insert_last_articulation(channel)

    elseif cmd == 'sync_feedback' and rfx.current:valid() then
        if self.track then
            reaper.CSurf_OnTrackSelection(self.track)
            feedback.sync(self.track)
        end

    elseif cmd == 'set_midi_feedback_active' then
        local enabled = self:handle_toggle_option(arg, 'cc_feedback_active', false)
        feedback.set_active(enabled)
        feedback.sync(self.track)

    elseif cmd == 'focus_filter' then
        self.screens.banklist.focus_filter()

    elseif cmd == 'select_last_track' then
        if self.last_track and reaper.ValidatePtr2(0, self.last_track, "MediaTrack*") then
            self:select_track(self.last_track, false)
        end
    elseif cmd == 'set_track_selection_follows_midi_editor' then
        self:handle_toggle_option(arg, 'track_selection_follows_midi_editor', true)
    elseif cmd == 'set_track_selection_follows_fx_focus' then
        self:handle_toggle_option(arg, 'track_selection_follows_fx_focus', true)
    elseif cmd == 'set_single_floating_instrument_fx_window' then
        -- TODO: experimental alert popup
        self:handle_toggle_option(arg, 'single_floating_instrument_fx_window', true)
        self:do_single_floating_fx()
    elseif cmd == 'set_keyboard_focus_follows_mouse' then
        -- TODO: experimental alert popup
        self:handle_toggle_option(arg, 'keyboard_focus_follows_mouse', true)
    end
    return BaseApp.handle_command(self, cmd, arg)
end

-- Called by commands that toggle some boolean option.
--
-- args is 1 or 3 comma-delimited values: the first value indicates whether the
-- value is enabled, disabled, or toggled, while, if given, the 2nd and 3rd value are the
-- section id and command id of the REAPER command state to be toggled.  cfgitem is the
-- key within self.config to persist the value when store is true.
--
-- Returns the new boolean value.
function App:handle_toggle_option(argstr, cfgitem, store)
    local args = string.split(argstr, ',')
    local enabled = tonumber(args[1])
    local section_id, cmd_id
    if #args > 2 then
        section_id = tonumber(args[2])
        cmd_id = tonumber(args[3])
    end
    return self:set_toggle_option(cfgitem, enabled, store, section_id, cmd_id)
end

-- If enabled is -1 then toggle, otherwise set to given value.  If section_id
-- and cmd_id are supplied, those will be used to set the command state,
-- otherwise they will be discovered.
function App:set_toggle_option(cfgitem, enabled, store, section_id, cmd_id)
    local value = self:get_toggle_option(cfgitem)
    if enabled == -1 then
        value = not value
    elseif type(enabled) == 'boolean' then
        value = enabled
    else
        value = (enabled == 1 and true or false)
    end
    if store then
        self.config[cfgitem] = value
        self:queue_save_config()
    end
    log.info("app: set toggle option: %s -> %s", cfgitem, value)

    if not cmd_id and self.config_map_to_script[cfgitem] then
        local section, filename = table.unpack(self.config_map_to_script[cfgitem])
        local script = Path.join(Path.basedir, 'actions', filename)
        local cmd = reaper.AddRemoveReaScript(true, section, script, false)
        if cmd > 0 then
            section_id = section
            cmd_id = cmd
        end
    end

    if cmd_id then
        reaper.SetToggleCommandState(section_id, cmd_id, value and 1 or 0)
        reaper.RefreshToolbar2(section_id, cmd_id)
    end
    if self:current_screen() == self.screens.settings then
        self.screens.settings.update()
    end
    return value
end

-- Returns the current value of the given config item.  Provides API symmetry to
-- set_toggle_option()
function App:get_toggle_option(cfgitem)
    return self.config[cfgitem]
end

-- Sets Reaticulate's default channel, syncs the new channel to any active MIDI Editor,
-- updates the RFX global gmem region with the new value, stores it in track appdata,
-- syncs the change to the control surface, and, depending on configuration, stores the
-- value as item metadata (if per-item channels is enabled).
function App:set_default_channel(channel)
    self.default_channel = channel
    self.screens.banklist.highlight_channel_button(channel)
    if self.midi_hwnd then
        -- Set channel for new events to 01 (plus the offset for the given channel)
        reaper.MIDIEditor_OnCommand(self.midi_hwnd, 40482 + channel - 1)
    end
    -- If there's an active MIDI editor, then the default channel is dictated by the current
    -- take (that is, the channel stored in the state for the track that take is on).
    -- If no active take (or no active MIDI editor), then use the selected track.
    local track = self.midi_editor_track or self.track
    if not track then
        -- We can't update track appdata, but we can at least update the global gmem slot.
        return rfx.set_gmem_global_default_channel(channel)
    end
    local rfxtrack = (track == self.track) and rfx.current or rfx.get_track(track)
    if not rfxtrack then
        -- Here again, at least ensure we update the global gmem slot for default channel.
        return rfx.set_gmem_global_default_channel(channel)
    end
    -- This will write the channel selection to the global gmem slot *and* update the
    -- default channel in the track's appdata.
    rfxtrack:set_default_channel(channel)
    -- Now feed back the channel selection to the control surface, plus all current
    -- CC values to sync control surface faders to the new channel.
    feedback.sync(track, feedback.SYNC_ALL)
    if self.config.default_channel_behavior == 3 and self.midi_editor_item then
        -- Per-item default channel behavior is configured, so store the channel as a key
        -- in the Reaticulate userdata table for this item.
        rfxtrack:set_item_userdata_key(self.midi_editor_item, 'default_channel', channel)
    end
end

-- Discovers the default channel stored either in the track or the active item, depending
-- on configuration, and reflects the persisted value in the GUI and active MIDI editor.
function App:sync_default_channel_from_rfx()
    -- Same as set_default_channel(): the track whose default channel we update depends on
    -- the current take, or current selected track if no current take.
    local track = self.midi_editor_track or self.track
    if not track then
        return
    end
    local rfxtrack = (track == self.track) and rfx.current or rfx.get_track(track)
    if not rfxtrack or not rfxtrack.appdata then
        -- Not a Reaticulate-configured track
        return
    end
    -- Check if channel per track or per item is configured.
    if self.config.default_channel_behavior ~= 1 then
        local channel = rfxtrack.appdata.defchan
        if self.config.default_channel_behavior == 3 and self.midi_editor_item then
            local itemdata = rfxtrack:get_item_userdata(self.midi_editor_item)
            if not itemdata.default_channel then
                -- This is a new MIDI item without a channel stored.  There's nothing for
                -- us to restore, so save the current channel to the item's userdata instead.
                self:set_default_channel(channel or self.default_channel)
                return
            end
            channel = itemdata.default_channel
        end
            -- Per item configuration.  Check P_EXT on the active item, if there is one.
        if channel ~= self.default_channel then
            -- New tracks would not have defchan defined, so default to 1.
            channel = channel or 1
            self.default_channel = channel
            self.screens.banklist.highlight_channel_button(channel)
            -- Ensure gmem is updated
            rfxtrack:set_default_channel(channel)
            -- And tell control surface about the new channel
            feedback.sync(track, feedback.SYNC_ALL)
        end
    end
    -- If we're here, this is a Reaticulate-managed track. Regardless of the default
    -- channel persistence config, sync to the MIDI editor.
    if self.midi_hwnd then
        -- Set channel for new events to 01 (plus the offset for the given channel).
        reaper.MIDIEditor_OnCommand(self.midi_hwnd, 40482 + self.default_channel - 1)
    end
end

-- distance < 0 means previous, otherwise means next.  If group is nil, try all
-- groups.
function App:get_active_articulation(channel, group)
    channel = channel or self.default_channel
    local groups
    if group then
        groups = {group}
    else
        groups = {1, 2, 3, 4}
    end
    for _, group in ipairs(groups) do
        local artidx = channel + (group << 8)
        local art = self.pending_articulations[artidx]
        if not art then
            art = self.active_articulations[artidx]
        end
        if art and art.button.visible then
            return art
        end
    end
end

-- Returns the rtk-compatible color to be used for the given articulation color name.
function App:get_articulation_color(name)
    local color = self.config.art_colors[name] or reabank.colors[name] or reabank.default_colors[name]
    if color and color:len() > 0 then
        return color
    end
    -- This must be a custom color name.  Check for it in the reabank.
    color = reabank.colors[color]
    -- Return it if it's valid, otherwise fallback to the 'default' color.  We don't need
    -- to test color:len() as above because this isn't coming from settings where the
    -- empty string implies to use the built-in color.
    return color or self.config.art_colors.default or reabank.colors.default or reabank.default_colors.default
end

-- Event handler when dock state has changed.
function App:handle_ondock()
    BaseApp.handle_ondock(self)
    self:update_dock_buttons()
end

-- Event handler on each key press after all widgets have had the chance to respond.
function App:handle_onkeypresspost(event)
    BaseApp.handle_onkeypresspost(self, event)
    if not event.handled then
        log.debug(
            "app: keypress: keycode=%d char=%s norm=%s ctrl=%s shift=%s meta=%s alt=%s",
            event.keycode, event.char, event.keynorm,
            event.ctrl, event.shift, event.meta, event.alt
        )
        if self:current_screen() == self.screens.banklist then
            if event.keycode >= 49 and event.keycode <= 57 then
                self:set_default_channel(event.keycode - 48)
            elseif event.keycode == rtk.keycodes.DOWN then
                self.screens.banklist.select_relative_articulation(1)
            elseif event.keycode == rtk.keycodes.UP then
                self.screens.banklist.select_relative_articulation(-1)
            elseif event.keycode == rtk.keycodes.ENTER then
                self:activate_selected_articulation(self.default_channel, true)
            elseif event.keycode == rtk.keycodes.ESCAPE then
                self.screens.banklist.clear_filter()
                self.screens.banklist.clear_selected_articulation()
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
        elseif event.char == '/' then
            self.screens.banklist.focus_filter()
        elseif event.char == '\\' and (event.ctrl or event.meta) then
            self.window:close()
        end
    end
end

-- Event handler for drag-and-drop files in the Reaticualte window.
function App:handle_ondropfiles(event)
    local contents = {}
    for n, fname in ipairs(event.files) do
        contents[#contents+1] = rtk.file.read(fname)
    end
    local data = table.concat(contents, '\n')
    reabank.import_banks_from_string_with_feedback(data, string.format('%d dragged files', #event.files))
end

-- Updates the toolbar buttons based on the current dock state.
function App:update_dock_buttons()
    if self.toolbar.dock then
        if not self.window.docked then
            self.toolbar.undock:hide()
            self.toolbar.dock:show()
        else
            self.toolbar.dock:hide()
            self.toolbar.undock:show()
        end
    end
end


-- Returns true when the user has configured Appearance | Peaks/Waveforms | Display
-- Program Names, and we have a versio of REAPER that has the action to refresh the PC
-- names based on the current global reabank.
function App:has_arrange_view_pc_names()
--  This is stored in the midipeaks param and, rather oddly, is enabled when bit 0 is OFF.
    local ok, midipeaks = reaper.get_config_var_string('midipeaks')
    return (tonumber(ok and midipeaks) or 1) & 1 == 0 and
           self.reaper_supports_track_data_reload
end

-- Updates the tmp Reabank file given the current project state, and syncs the
-- current track (and UI) to reflect any changes to banks on the track.
--
-- If parse is true, then Reaticulate.reabank is reparsed from disk and all
-- tracks are synced to any changes affecting the banks mapped on those tracks.
--
-- Called when any banks may have changed
function App:refresh_banks(flags)
    log.time_start()
    flags = flags or 0
    if flags & App.REPARSE_REABANK_FILE ~= 0 then
        reabank.parseall()
        log.debug("app: refresh: reabank.parseall() done")
        -- Sweep all tracks with active RFX and resync banks if the hash changed as a
        -- result of this reparsing.
        rfx.all_tracks_sync_banks_if_hash_changed()
    end
    if flags & App.CLEAN_UNUSED_BANKS ~= 0 then
        log.info('app: refresh: performing GC on project banks')
        self:clean_unused_project_banks()
    end

    -- changes is a table of GUIDs for banks that have been modified (but not added)
    -- relative to last write.  If no changes, then nil is returned.
    local changes, additions = reabank.write_reabank_for_project()
    -- Force REAPER to notice changes made to the global Reabank.  As of REAPER 6.46, we
    -- have a new action available for this.
    --
    -- Unfortunately, it's quite slow, particularly when updating the entire project (can
    -- be multiple seconds).  At the moment, the only scenario where we really need the
    -- action is to update "PC" names in the arrange view.  Given the poor performance,
    -- it's in our interests to only run the action when we need to: specifically, when
    -- the user has REAPER configured to display PC names in the arrange view.
    if self:has_arrange_view_pc_names() then
        -- Arrange view shows PC names, and we have a version of REAPER that supports
        -- kicking tracks in the head.
        if (changes or additions) and flags & App.FORCE_RECOGNIZE_BANKS_PROJECT ~= 0 then
            -- Done on project load (not tab changes). SLLLLLOOOOOWWWWWW but necessary
            -- when loading a project with banks not in the current tmp reabank in order
            -- to force arrange view to refresh PC names.  We only need to do this when
            -- the newly written project reabank has additions or changes, at least.
            self:force_recognize_bank_change_many_tracks()
        elseif changes then
            -- One or more banks changed their definitions.  We need to kick all the
            -- affected tracks.
            --
            -- We're not refreshing the entire project so we can be a bit more surgical.
            -- This only updates tracks that reference the bank GUIDs that have been
            -- added/changed since last tmp reabank generation.
            self:force_recognize_bank_change_many_tracks(nil, changes)
        elseif flags & App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK ~= 0 and rfx.current.track then
            -- The likely scenario here is that we changed a bank on the current track in
            -- the track configuration screen.  A new bank may have been added to the
            -- project (which would not be reflected in the changes table above as
            -- additions are excluded) but that's ok, because we know an addition to the
            -- project can only affect the current track.
            self:force_recognize_bank_change_one_track(rfx.current.track)
        end
    else
        -- No PC display in arrange view, we just update the MIDI editor (if any).
        self:force_recognize_bank_change_one_track(nil, true)
    end
    -- Force a resync of the RFX
    rfx.current:sync(rfx.current.track, true)
    log.debug("app: refresh: synced RFX")
    self:ontrackchange(nil, self.track)
    log.debug("app: refresh: ontrackchange() done")
    -- Update articulation list to reflect any changes that were made to the Reabank template.
    -- If the banks have changed then rfx.onhashchanged() will have already been called via
    -- rfx.current:sync() above.
    self.screens.banklist.update()
    log.debug("app: refresh: updated screens")
    log.info("app: refresh: all done (flags=%s changes=%s additions=%s)", flags, changes, additions)
    log.time_end()
    self:log_msblsb_mapping()
end


function App:check_banks_for_errors()
    if self:current_screen() == self.screens.trackcfg then
        -- Track configuration screen is visible, so update the UI.  This
        -- implicitly checks for errors and will persist appdata if needed.
        self.screens.trackcfg.update()
    else
        self.screens.trackcfg.check_errors()
    end
    self.screens.banklist.update_error_box()
end


-- Invoked by the RFX when selecting a track with a different bank hash than the previous
-- track.
function rfx.onhashchange()
    app:check_banks_for_errors()
end


-- Removes any track-level ReaBank assignment (MIDIBANKPROGFN in the track state chunk)
-- from the given track.
--
-- Returns true if MIDIBANKPROGFN was found and removed, or false otherwise.
function App:clear_track_reabank_mapping(track)
    if not rfx.get(track) then
        return false
    end
    -- Can't use reaper.Get/SetTrackStateChunk() which horks with large (>~5MB) chunks.
    local fast = reaper.SNM_CreateFastString("")
    local ok = reaper.SNM_GetSetObjectState(track, fast, false, false)
    local chunk = reaper.SNM_GetFastString(fast)
    reaper.SNM_DeleteFastString(fast)
    if not ok or not chunk or not chunk:find("MIDIBANKPROGFN") then
        return false
    end
    chunk = chunk:gsub('MIDIBANKPROGFN "[^"]*"', 'MIDIBANKPROGFN ""')
    local fast = reaper.SNM_CreateFastString(chunk)
    reaper.SNM_GetSetObjectState(track, fast, true, false)
    reaper.SNM_DeleteFastString(fast)
    return true
end

-- This induces REAPER to notice the global ReaBank has changed.  If track is specified,
-- then all items on the track will be kicked.  Otherwise if midi_editor is true, then the
-- active item in the MIDI editor (if there is one) will only be kicked.
function App:force_recognize_bank_change_one_track(track, midi_editor)
    log.time_start()
    -- This rewrites the state chunk which causes REAPER to notice when a new
    -- reabank file has been mapped.
    local function kick_item(item)
        local fast = reaper.SNM_CreateFastString("")
        -- Can't use reaper.Get/SetTrackStateChunk() which horks with large (>~5MB) chunks.
        if reaper.SNM_GetSetObjectState(item, fast, false, false) then
            reaper.SNM_GetSetObjectState(item, fast, true, false)
        end
        reaper.SNM_DeleteFastString(fast)
    end
    if track and reaper.ValidatePtr2(0, track, 'MediaTrack*') then
        if self.reaper_supports_track_data_reload then
            -- Kick using new action
            local tracks = track and {track}
            self:force_recognize_bank_change_many_tracks(tracks)
        else
            -- Old method where we kick each item on the track.
            for itemidx = 0, reaper.CountTrackMediaItems(track) - 1 do
                local item = reaper.GetTrackMediaItem(track, itemidx)
                kick_item(item)
            end
        end
    elseif midi_editor then
        local hwnd = reaper.MIDIEditor_GetActive()
        if hwnd then
            local take = reaper.MIDIEditor_GetTake(hwnd)
            if take and reaper.ValidatePtr2(0, take, 'MediaItem_Take*') then
                local item = reaper.GetMediaItemTake_Item(take)
                kick_item(item)
            end
        end
    end
    log.time_end('app: force recognize bank change: track=%s midi=%s', track, midi_editor)
end

function App:force_recognize_bank_change_many_tracks(tracks, guids)
    -- In REAPER 6.46, schwa added actions to more robustly reload reabank data,
    -- so we use that.
    call_and_preserve_selected_tracks(function()
        if not tracks and not guids then
            -- Full project.  This is ssssssllllllooooowwww but it's the only way to
            -- ensure PC names in arrange view get refreshed.
            log.info('app: force recognize bank change on entire project')
            -- Track: Select all tracks
            reaper.Main_OnCommandEx(40296, 0, 0)
        else
            -- Track: Unselect (clear selection of) all tracks
            reaper.Main_OnCommandEx(40297, 0, 0)
            if tracks then
                log.info('app: force recognize bank change on %s tracks', #tracks)
                for _, track in ipairs(tracks) do
                    reaper.SetTrackSelected(track, true)
                end
            elseif guids then
                log.info('app: force recognize bank change by MSB/LSB')
                for idx, rfxtrack in rfx.get_tracks(0, true) do
                    for b in rfxtrack:get_banks() do
                        if guids[b.guid] then
                            reaper.SetTrackSelected(rfxtrack.track, true)
                        end
                    end
                end
            end
        end
        log.time_start()
        -- MIDI: Reload track support data (bank/program files, notation, etc) for all MIDI items on selected tracks
        reaper.Main_OnCommandEx(42465, 0, 0)
        log.time_end('app: invoked REAPER action to reload reabank on selected tracks')
    end)

end

-- Scans all tracks in the project and clears the track-level Reabank mapping, and
-- kicks REAPER in the head on all tracks to reload track support data (on supported
-- REAPER versions).
--
-- This action is horrendously slow -- as in multiple seconds -- and is only usable
-- as a last-resort sledgehammer.
function App:beat_reaper_into_submission()
    log.time_start()
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        self:clear_track_reabank_mapping(track)
    end
    self:force_recognize_bank_change_many_tracks()
    reaper.MB('Force-refreshed all tracks in project.', 'Refresh Project', 0)
    log.debug('app: finished track chunk sweep')
    log.time_end()
end

-- Invoked by BaseApp:initialize() when the rtk.Window has been created and the UI is ready
-- to be created.
function App:build_frame()
    BaseApp.build_frame(self)

    local menubutton = rtk.OptionMenu{
        icon='edit',
        flat=true,
        icononly=true,
        tooltip='Manage banks',
    }
    if rtk.os.windows then
        menubutton:attr('menu', {
            'Import Banks from Clipboard',
            'Edit in Notepad',
            'Open in Default App',
            'Show in Explorer'
        })
    elseif rtk.os.mac then
        menubutton:attr('menu', {
            'Import Banks from Clipboard',
            'Edit in TextEdit',
            'Open in Default App',
            'Show in Finder'
        })
    else
        menubutton:attr('menu', {
            'Import Banks from Clipboard',
            'Edit in Editor',
            'Show in File Browser',

        })
    end

    local toolbar = self.toolbar
    toolbar:add(menubutton)
    menubutton.onselect = function(self)
        reabank.create_user_reabank_if_missing()
        if self.selected_index == 1 then
            local clipboard = rtk.clipboard.get()
            reabank.import_banks_from_string_with_feedback(clipboard, 'the clipboard')
        elseif rtk.os.windows then
            if self.selected_index == 2 then
                reaper.ExecProcess('cmd.exe /C start /B notepad ' .. reabank.reabank_filename_user, -2)
            elseif self.selected_index == 3 then
                reaper.ExecProcess('cmd.exe /C start /B "" "' .. reabank.reabank_filename_user .. '"', -2)
            elseif self.selected_index == 4 then
                reaper.ExecProcess('cmd.exe /C explorer /select,' .. reabank.reabank_filename_user, -2)
            end
        elseif rtk.os.mac then
            if self.selected_index == 2 then
                os.execute('open -a TextEdit "' .. reabank.reabank_filename_user .. '"')
            elseif self.selected_index == 3 then
                os.execute('open -t "' .. reabank.reabank_filename_user .. '"')
            elseif self.selected_index == 4 then
                local path = Path.join(Path.resourcedir, "Data")
                os.execute('open "' .. path .. '"')
            end
		else
            if self.selected_index == 2 then
                os.execute('xdg-open "' .. reabank.reabank_filename_user .. '"')
            elseif self.selected_index == 3 then
                local path = Path.join(Path.resourcedir, "Data")
                os.execute('xdg-open "' .. path .. '"')
            end
        end
    end

    local button = toolbar:add(rtk.Button{icon='sync', flat=true})
    button:attr('tooltip', 'Reload ReaBank files from disk')
    button.onclick = function(b, event)
        rtk.defer(function()
            app:refresh_banks(App.REPARSE_REABANK_FILE | App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK)
            if event.shift then
                self:beat_reaper_into_submission()
            end
        end)
    end

    self.toolbar.dock = toolbar:add(rtk.Button{icon='dock_window', flat=true, tooltip='Dock window'})
    self.toolbar.undock = toolbar:add(rtk.Button{icon='undock_window', flat=true, tooltip='Undock window'})
    self.toolbar.dock.onclick = function()
        self.window:attr('docked', true)
    end

    self.toolbar.undock.onclick = function()
        self.window:attr('docked', false)
    end

    self:update_dock_buttons()

    local button = toolbar:add(rtk.Button{icon='settings', flat=true, tooltip='Manage Reaticulate Settings'})
    button.onclick = function()
        self:push_screen('settings')
    end
end

function App:zoom(increment)
    BaseApp.zoom(self, increment)
    if self:current_screen() == self.screens.settings then
        self.screens.settings.update_ui_scale_menu()
    end
end

-- Generates a random UUID4 for the current project, which is used to detect
-- project changes (which includes reopening the same project).  The new project
-- cookie is stored int he project via SetProjExtState(), but this *doesn't* dirty
-- the project, which is what we want (otherwise the mere act of opening a project
-- would immediately dirty it).
--
-- See handle_onupdate() for more.
function App:gen_new_change_cookie()
    local cookie = rtk.uuid4()
    self.project_change_cookie = cookie
    self.active_projects_by_cookie[cookie] = true
    reaper.SetProjExtState(0, 'reaticulate', 'change_cookie', cookie)
    log.debug('app: generated new project cookie: %s', cookie)
end

-- Programmatically selects the given track, making it the only selected track.
--
-- The mixer will always be scrolled into view.  If scroll_arrange is true, then the
-- arrange view is also scrolled vertically to ensure the track is visible.
function App:select_track(track, scroll_arrange)
    reaper.PreventUIRefresh(1)
    reaper.SetOnlyTrackSelected(track)
    feedback.scroll_mixer(track)
    if scroll_arrange then
        -- Track: Vertical scroll selected tracks into view.
        reaper.Main_OnCommandEx(40913, 0, 0)
    end
    reaper.CSurf_OnTrackSelection(track)
    reaper.PreventUIRefresh(-1)
end

-- Selects the track based on the currently focused FX window.
--
-- Returns true if a track was selected, or false if the current focused window
-- isn't an FX.
function App:select_track_from_fx_window()
    local w = rtk.focused_hwnd
    while w ~= nil do
        local title = reaper.JS_Window_GetTitle(w)
        local tracknum = title:match('Track (%d+)')
        if tracknum then
            local track = reaper.GetTrack(0, tracknum - 1)
            self:select_track(track, true)
            log.debug("app: selecting track %s due to focused FX", tracknum)
            return true
        end
        w = reaper.JS_Window_GetParent(w)
    end
    return false
end

function App:open_config_ui()
    self:send_command('reaticulate.cfgui', 'ping', function(response)
        if response == nil then
            -- Config UI isn't currently open, so open it.
            -- Lookup cmd id saved from previous invocation.
            local cmd = reaper.GetExtState("reaticulate", "cfgui_command_id")
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

-- If focus-follows-mouse is enabled, focuses the window under the mouse.
function App:check_sloppy_focus()
    if not self.config.keyboard_focus_follows_mouse then
        return
    end
    -- FIXME: problem here is when focusing floating windows, they are raised to top, which
    -- is extremely obnoxious.  Maybe limit just to arrange view, TCP, MCP, and midi editor?
    local x, y = reaper.GetMousePosition()
    local hwnd = reaper.JS_Window_FromPoint(x, y)
    if hwnd == self.last_sloppy_focus_hwnd then
        -- No change
        return
    end
    self.last_sloppy_focus_hwnd = hwnd
    if not hwnd or rtk.is_modal() or rtk.dragging then
        -- Nothing to focus or we have modal widgets in which case we disable
        -- sloppy focus.
        return
    end

    local curhwnd = hwnd
    local is_reaper_window = false
    local known_class = nil
    while curhwnd ~= nil do
        if curhwnd == rtk.reaper_hwnd then
            is_reaper_window = true
            break
        end
        if not known_class then
            local class = reaper.JS_Window_GetClassName(curhwnd)
            known_class = self.known_focus_classes[class]
            hwnd = curhwnd
        end
        -- log.debug("hwnd class: %s %s (%s) -> %s", curhwnd, class, rtk.reaper_hwnd, known_class)
        curhwnd = reaper.JS_Window_GetParent(curhwnd)
    end
    if not is_reaper_window and not known_class then
        return
    end
    -- log.debug("found class: %s %s", known_class, hwnd)
    reaper.PreventUIRefresh(-1)
    if known_class == 'arrange' then
        reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND"), 0, 0)
    elseif known_class == 'tcp' then
        reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_BR_FOCUS_TRACKS"), 0, 0)
    elseif known_class == 'midi_editor' then
        reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR"), 0, 0)
    elseif known_class == 'hwnd' and hwnd then
        reaper.JS_Window_SetFocus(hwnd)
    end
    reaper.PreventUIRefresh(1)
end

-- Auto-selects a new track based on various criteria:
--  1. If Track follows focused FX is enabled and the focus has changed
--  2. If Track selection follows active MIDI take" is enabled and the
--     the take changes in the active MIDI Editor.
--
-- If this function changes tracks, then it returns true, otherwise returns false.
--
-- If the track doesn't need changing, then the midi_editor_take and midi_editor_track
-- fields are updated. The default channel is also synced based on the current take's
-- track, to handle the case when the user has disabled "track selection follows active
-- take"
function App:_change_track_if_needed(hwnd, track_changed, focus_changed)
    if focus_changed and self.config.track_selection_follows_fx_focus then
        -- Track follows FX is enabled and the focus has changed
        if self:select_track_from_fx_window() then
            return true
        end
    end
    if hwnd then
        local take = reaper.MIDIEditor_GetTake(hwnd)
        if take and reaper.ValidatePtr(take, "MediaItem_Take*") then
            if take ~= self.midi_editor_take then
                local track = reaper.GetMediaItemTake_Track(take)
                local item = reaper.GetMediaItemTake_Item(take)
                local item_changed = item ~= self.midi_editor_item
                self.midi_editor_item = item
                self.midi_editor_take = take
                if track ~= self.midi_editor_track then
                    self.midi_editor_track = track
                    if self.track ~= track and self.config.track_selection_follows_midi_editor then
                        self:select_track(track, false)
                        return true
                    end
                    -- We aren't changing tracks, but that could be because the track selection follows
                    -- editor option is disabled. Ensure we sync the default channel from the take's
                    -- track.
                    self:sync_default_channel_from_rfx()
                elseif item_changed and self.config.default_channel_behavior == 3 then
                    -- Item has changed and we're configured for per-item default channel.  Also
                    -- sync.
                    self:sync_default_channel_from_rfx()
                end
            end
            return false
        end
    end
    -- If we're here, it means the MIDI editor is closed or there's no active take.
    if self.midi_editor_track then
        self.midi_editor_track = nil
        self.midi_editor_item = nil
        self.midi_editor_take = nil
    end
    return false
end

-- Called on each defer cycle.
--
-- This is Reaticulate's primary event loop from which almost everything is dispatched.
function App:handle_onupdate()
    BaseApp.handle_onupdate(self)
    self:check_sloppy_focus()

    -- Prefer the last touched track as the active track for Reaticulate.
    local track = reaper.GetLastTouchedTrack()
    if track and not reaper.IsTrackSelected(track) then
        -- The last touched track isn't currently selected, so fallback to the first
        -- selected track.  (Unsure if this scenario can actually happen, but just to be
        -- on the safe side.)
        track = reaper.GetSelectedTrack(0, 0)
    end
    local last_track = self.track
    local track_changed = self.track ~= track
    local current_screen = self:current_screen()

    -- Detect if the current project has changed.
    --
    -- We do this by storing a random cookie in the project and regenerate the
    -- cookie when a) we detect the project was loaded (or switched to its tab)
    -- and b) when the project dirty state changes.
    --
    -- When the change cookie of the current project no longer matches the one
    -- from the previous run, it means the project has changed.
    local _, change_cookie = reaper.GetProjExtState(0, 'reaticulate', 'change_cookie')
    local dirty = reaper.IsProjectDirty(0)
    if change_cookie ~= self.project_change_cookie then
        local active = self.active_projects_by_cookie
        -- If false, this is a tab change. If true, a project has been opened (or reopened)
        local opened = not active[change_cookie]
        -- Refresh the list of active project cookies which we use to detect tab changes
        -- versus projects being opened.
        self.active_projects_by_cookie = {}
        -- There is no CountProjects().  Capping avoids infinite loop potential as the
        -- return value of EnumProjects() is not documented so can't be trusted to
        -- return nil at end of project list.
        for pidx = 0, 100 do
            local proj, _ = reaper.EnumProjects(pidx, '')
            if not proj then
                break
            end
            local ok, cookie = reaper.GetProjExtState(proj, 'reaticulate', 'change_cookie')
            -- If the cookie isn't in project state, it will be the empty string, not nil.
            -- Avoid adding this to the active projects, otherwise we will fail to detect
            -- loading projects without the cookie.
            if ok and cookie ~= '' then
                self.active_projects_by_cookie[cookie] = true
            end
        end
        -- Always generate a new cookie on project change so that we can detect re-opening
        -- the same project.  This is considered a project change because the current
        -- state of the project and state being reverted may be different.
        self:gen_new_change_cookie()
        rfx.current:reset()
        self:onprojectchange(opened)
    elseif dirty ~= self.project_dirty then
        -- Project was just saved or has become dirty.  The project hasn't
        -- changed, but we generate a new cookie in case it gets saved or the
        -- previous saved version reopened.
        --
        -- Regenerating the cookie doesn't itself dirty the project, so there is
        -- an edge case where if the user saves the project immediately after
        -- cookie regeneration and reloads it, we won't detect the reload.  But
        -- this should be ok since we're only concerned about when the project
        -- state truly changes, and if the user saves out the project when it's
        -- not dirty, there can't have been any meaningful changes.
        self:gen_new_change_cookie()
    end
    self.project_dirty = dirty

    -- If rfx.current:sync() returns true then the FX has changed and we need
    -- to update the main screen for the new articulations.  Before we sync,
    -- check to see if the RFX is currently valid.
    local valid_before = rfx.current:valid()
    if rfx.current:sync(track) then
        if not track_changed and not valid_before then
            -- We didn't change tracks, but the current track flipped from no valid RFX to
            -- a valid RFX.  We can assume we had an offline RFX that was just onlined.
            -- Force an error check.
            self:check_banks_for_errors()
        end
        self.screens.banklist.update()
        if self.screens.trackcfg.widget.visible then
            self.screens.trackcfg.update()
        end
    end

    local focus_changed = self.last_focused_hwnd ~= rtk.focused_hwnd
    if focus_changed then
        self.last_focused_hwnd = rtk.focused_hwnd
        if not self.window.is_focused or not self.saved_focus_window then
            self.saved_focus_window = rtk.focused_hwnd
        else
            -- Reaticulate window is focused.  Start timer.
            self.last_focus_time = reaper.time_precise()
        end
    elseif self.last_focus_time ~= nil and reaper.time_precise() - self.last_focus_time > 1 then
        -- Reaticulate window was focused for more than 1 second, so save it as
        -- the focused window for refocus()
        self.saved_focus_window = rtk.focused_hwnd
        self.last_focus_time = nil
    end

    local hwnd = reaper.MIDIEditor_GetActive()
    local midi_closed = self.midi_hwnd and not hwnd
    self.midi_hwnd = hwnd

    -- Check if track has changed
    if track_changed then
        if self.track ~= nil then
            self.last_track = self.track
        end
        self.track = track
        -- Clear current take so we rediscover the track the take belongs to,
        -- in case the active take in the editor was moved to another track.
        self.midi_editor_take = nil
        self:ontrackchange(last_track, track)
    end

    -- Having called rfx.current:sync(), if rfx.current:valid() returns true then this is
    -- a Reaticulate-enabled track.
    local first_screen = self.screens.stack[1]
    if rfx.current:valid() then
        if first_screen ~= self.screens.banklist then
            self:replace_screen('banklist', 1)
        end
    elseif first_screen ~= self.screens.installer then
        self:replace_screen('installer', 1)
    elseif current_screen == self.screens.trackcfg then
        self:replace_screen('installer', 1)
        self:pop_screen()
    elseif current_screen == self.screens.installer then
        self.screens.installer.update()
    end

    -- Auto change tracks if we have track-follows-FX enabled or if the MIDI editor active
    -- take changes to a different track (and following is enabled).  If this returns
    -- true, then it means the track change has occurred, and so we wait for the next
    -- defer cycle for things to settle by ensuring the return value is false before we
    -- run the code to handle default channel syncing.
    local track_change_pending, take_changed = self:_change_track_if_needed(hwnd, track_changed, focus_changed)
    -- Skip this behavior on tracks without Reaticulate
    if not track_change_pending and rfx.current:valid() then
        if track_changed or midi_closed then
            self:sync_default_channel_from_rfx()
        end
        local banklist = self.screens.banklist
        if self.midi_editor_track and self.track and self.midi_editor_track ~= self.track then
            -- If the current track doesn't match the active take's track, then show a
            -- warning, because the displayed articulations won't (or at least *might*
            -- not) match what the MIDI editor is currently showing.
            if not banklist.warningbox.visible then
                banklist.set_warning(
                    'The selected track is different than the active take in the MIDI editor. ' ..
                    'The articulations below may not apply to the active take.'
                )
            end
        elseif self.midi_editor_track == self.track or not hwnd then
            -- The selected track matches the current take, or the editor is closed.
            -- Either way, hide the warning box if it's currently visible.
            if banklist.warningbox.visible then
                banklist.set_warning(nil)
            end
        end
        if hwnd then
            local channel = reaper.MIDIEditor_GetSetting_int(hwnd, 'default_note_chan') + 1
            if channel ~= self.default_channel then
                -- The user has made a change to the default note channel via the MIDI editor,
                -- so sync that back to Reaticulate.
                self:set_default_channel(channel)
            end
        end
    end
    -- Update feedback send, which we need to do even on non-RFX tracks to ensure we
    -- remove the send from the previous RFX-managed track, which is why this isn't
    -- in the previous conditional block, which is only for track with RFX.
    if track_changed and not track_change_pending then
        -- Call this here instead of in ontrackchange() to ensure that we feedback *after*
        -- setting the default channel.  Note there is a slight delay in the control
        -- surface receiving the update when selecting a track with automatic record arm
        -- there doesn't seem to be anything we can do about this.
        feedback.ontrackchange(last_track, track)
    end
    rfx.opcode_commit_all()
end

return App