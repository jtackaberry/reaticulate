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
--


-- This module contains functions used to manage the Reaticulate JSFX (RFX)
-- instances, including discovery, installation, and communication with the
-- instances.

local reabank = require 'reabank'

local NO_PROGRAM = 128



local rfx = {
    -- MSB of first parameter must be set to this or else it's not an RFX instance.
    MAGIC = 42 << 24,

    -- Opcodes for programming the RFX.  See rfx.opcode().
    OPCODE_NOOP = 0,
    OPCODE_CLEAR = 1,
    OPCODE_ACTIVATE_ARTICULATION = 2,
    OPCODE_NEW_ARTICULATION = 3,
    OPCODE_SET_ARTICULATION_INFO = 4,
    OPCODE_ADD_OUTPUT_EVENT = 5,
    OPCODE_SYNC_TO_FEEDBACK_CONTROLLER = 7,
    OPCODE_SET_CC_FEEDBACK_ENABLED = 8,
    OPCODE_NEW_BANK = 9,
    OPCODE_SET_BANK_CHASE_CC = 10,
    OPCODE_SET_OUTPUT_EVENT_INFO1 = 11,

    params_by_version = {
        [1 << 16] = {
            -- byte 0: change serial, byte 1: reabank version (mod 256), byte 2: RFX version, byte 3: magic
            -- This is the only parameter that must be hardcoded at 0 regardless of version.
            metadata = 0,
            -- Bitmap of MIDI channels with active notes
            active_notes = 2,
            -- MIDI channel control data -- defines behaviour of the RFX instance for
            -- input on each channel.
            --     byte 0: current program number for group 1; 128 == not set
            --     byte 1: current program number for group 2; 128 == not set
            --     byte 2: current program number for group 3; 128 == not set
            --     byte 3: current program number for group 4; see group_4_enabled_programs
            control_start = 9,
            control_end = 24,

            -- Slider MSB is unusable, so for group 4, use a serparate slider to track whether
            -- a program is set.  This slider holds a bitmap where bits 0-15 represent programs
            -- enabled for MIDI channels 1-16 in group 4.
            group_4_enabled_programs = 25,

            -- Banks defined on this track.  Each parameter is:
            --      byte 0: Source MIDI channel (offset from 0, 16 = default)
            --      byte 1: Destination MIDI channel (offset from 0, 16 = default)
            --      byte 2: Bank MSB
            --      byte 3: Bank LSB
            banks_start = 29,
            banks_end = 40,
            opcode = 63,
        }
    },
    -- The current track (set via rfx.sync())
    track = nil,
    -- Reaper FX id of the Reaticulate FX on current track, or nil if
    -- no valid one was found.
    fx = nil,
    -- Metadata field of current RFX, which contains the byte-packed values for
    -- magic, version and change serial.
    metadata = nil,

    -- Version of the RFX instance (relevant iff fx isn't nil). Parsed from metadata.
    version = nil,
    -- The current change serial of the RFX.  When this changes without the track
    -- changing, then an articulation has changed on at least one channel.  Parsed
    -- from metadata.
    program_serial = nil,
    notes_serial = nil,
    -- The Reabank version that was used to build the MIDI channel control data.
    -- Parsed from metadata.
    reabank_version = nil,
    -- One of the params_by_version tables above, per the current RFX version
    params = nil,

    -- Current program numbers on this track indexed by MIDI channel and sub-indexed
    -- by group. Initialized in init()
    programs = {},
    -- Maps channel number to list of bank objects for current track
    banks_by_channel = {},
    -- Bitmap of channels with active notes
    active_notes = 0,
    -- Callback invoked when the articulation changes on a channel
    onartchange = function(channel, group, last, current, track_changed) end,

    -- Saved state so we don't butcher things like last touched FX and automation
    -- by setting parameters on the RFX.
    state = {
        depth = 0,
        tracks = {},
        global_automation_override = nil,
        last_touched_fx = {
            track = nil,
            automation_mode = nil,
            param = nil,
            fx = nil,
            -- true if there is currently a deferred function pending to restore last fx state.
            deferred = false,
        }
    }
}

-- Maps output type as specified in reabank file to the value used by OPCODE_ADD_OUTPUT_EVENT.
local output_type_to_rfx_param = {
    ["none"] = 0,
    ["program"] = 1,
    ["cc"] = 2,
    ["note"] = 3,
    ["note-hold"] = 4,
    ["art"] = 5,
}

function rfx.init()
    -- rfx.params_by_version[2 << 16] = rfx.params_by_version[1 << 16];
    for channel = 1, 16 do
        rfx.programs[channel] = {NO_PROGRAM, NO_PROGRAM, NO_PROGRAM, NO_PROGRAM}
    end
end

function rfx.get(track)
    return reaper.TrackFX_GetByName(track, "Reaticulate", false)
end

-- Discover the Reaticulate FX on the given track.  Sets rfx.fx to the fx id if valid, and returns
-- true if the fx is detected to have changed (e.g. track changed or FX became enabled) or false
-- otherwise.
--
-- This function is called frequently (for each deferred cycle) so it needs to be as efficient as
-- possible for the common case of idling on a track.
function rfx.sync(track, forced)
    local track_changed = (track ~= rfx.track) or forced
    rfx.track = track
    if not track then
        rfx.fx = nil
    else
        local fx = rfx.validate(track, rfx.get(track))
        track_changed = track_changed or (fx ~= rfx.fx)
        local metadata = rfx.metadata or 0
        local program_serial = metadata & 0x0f
        local notes_serial = metadata & 0xf0
        local program_changed = (rfx.program_serial ~= program_serial)
        local notes_changed = (rfx.notes_serial ~= notes_serial)

        rfx.program_serial = program_serial
        rfx.notes_serial = notes_serial
        rfx.fx = fx
        -- Track whether either the track changed or the RFX on the
        -- current track changed.
        if fx then
            if track_changed then
                -- Track changed, need to update banks_by_channel map
                rfx.reabank_version = (rfx.metadata >> 8) & 0xff
                if rfx.reabank_version ~= reabank.version % 256 then
                    -- The control data was synced from a different reabank version, so need
                    -- to regenerate.  (This implicitly calls sync_banks_by_channel())
                    rfx.sync_articulation_details()
                else
                    -- Reabank version wasn't changed, so just sync the banks.
                    rfx.sync_banks_by_channel()
                end
            end
            if program_changed or track_changed then
                -- Serial has changed with MSB=1 so an articulation has changed on at least one
                -- channel.
                group4_enabled = rfx.get_param(rfx.params.group_4_enabled_programs)
                for param = rfx.params.control_start, rfx.params.control_end do
                    local channel = (param - rfx.params.control_start) + 1
                    local programs = rfx.get_param(param)
                    for group = 1, 4 do
                        local program = (programs >> (8 * (group - 1))) & 0xff
                        if group == 4 then
                            if group4_enabled & (1 << (channel - 1)) == 0 then
                                program = NO_PROGRAM
                            end
                        end
                        local last_program = rfx.programs[channel][group]
                        if (track_changed and program ~= NO_PROGRAM) or last_program ~= program then
                            rfx.onartchange(channel, group, last_program, program, track_changed)
                        end
                        rfx.programs[channel][group] = program
                    end
                end
            end
            if notes_changed then
                -- Sync active notes.
                rfx.active_notes, _, _ = reaper.TrackFX_GetParam(track, fx, rfx.params.active_notes)
            end
        end
    end
    return track_changed
end

-- Determine if the given fx is a legit Reaticulate FX.  It returns the suppled fx if valid, or
-- nil otherwise.  This function is called frequently (via rtk.sync())
function rfx.validate(track, fx)
    if fx == nil or fx == -1 then
        return nil
    end

    local r, _, _ = reaper.TrackFX_GetParam(track, fx, 0)
    if r < 0 then
        return nil
    end
    local metadata = math.floor(r)
    local magic = metadata & 0xff000000
    if magic ~= rfx.MAGIC then
        return nil
    end

    local version = metadata & 0x00ff0000
    if version ~= rfx.version then
        local params = rfx.params_by_version[version]
        if params == nil then
            -- Unsupported RFX version
            log("unsupported rfx version %s", version >> 16)
            return nil
        end
        rfx.version = version
        rfx.params = params
    end
    rfx.metadata = metadata
    return fx
end

-- An iterator that yields (srcchannel, dstchannel, msb, lsb) for each bank
-- assigned to this track.  Channel starts at 1.
function rfx.get_banks()
    if not rfx.fx then
        -- RFX not loaded, so nothing to iterate over.
        return function() end
    end
    local param = rfx.params.banks_start
    return function()
        if param <= rfx.params.banks_end then
            local b0, b1, b2, b3 = rfx.get_data(param)
            param = param + 1
            if b2 > 0 and b3 > 0 then
                return b0 + 1, b1 + 1, b2, b3
            end
        end
    end
end

-- Slot index and channel start at 1.  Caller will need to call rfx.sync_articulation_details()
-- after.
function rfx.set_bank(slot, srcchannel, dstchannel, bank)
    rfx.push_state(rfx.track)
    if bank then
        rfx.set_data(slot + rfx.params.banks_start - 1,
                     srcchannel - 1, dstchannel - 1,
                     bank.msb, bank.lsb)
    else
        -- Clear slot.
        rfx.set_data(slot + rfx.params.banks_start - 1, 0, 0, 0)
    end
    rfx.pop_state()
end


function rfx.get_banks_conflicts()
    -- Tracks program details where the key is 128 * channel + program
    local programs = {}
    local conflicts = {}
    for channel = 1, 16 do
        local first = nil
        local banks = rfx.banks_by_channel[channel]
        if banks then
            for _, bank in ipairs(banks) do
                for _, art in ipairs(bank.articulations) do
                    local idx = 128 * channel + art.program
                    -- Keep track of output events, because conflicting programs with the same output
                    -- events shouldn't count as conflicts.
                    --
                    -- FIXME: order shouldn't matter either, but this implementation requires same order.
                    local outputs = table.tostring(art:get_outputs())
                    -- Has this program been seen before?
                    local first = programs[idx]
                    if not first then
                        programs[idx] = {
                            bank = bank,
                            art = art,
                            outputs = outputs
                        }
                    elseif first.outputs ~= outputs then
                        -- Program has been seen before on the same channel.
                        local conflict = conflicts[bank]
                        if not conflict then
                            conflicts[bank] = {
                                source = first.bank,
                                channels = 1 << (channel - 1),
                                program = art.program
                            }
                        else
                            conflict.channels = conflict.channels | (1 << (channel - 1))
                        end
                    end
                end
            end
        end
    end
    return conflicts
end


-- Constructs the rfx.banks_by_channel map based on current banks list stored in the RFX.
function rfx.sync_banks_by_channel()
    if not rfx.fx then
        return
    end
    rfx.banks_by_channel = {}
    for srcchannel, dstchannel, msb, lsb in rfx.get_banks() do
        -- log("Track bank: %s -> %s   %s %s", srcchannel, dstchannel, msb, lsb)
        local bank = reabank.get_bank(msb, lsb)
        if not bank then
            log("Error: RFX instance refers to undefined bank: msb=%s lsb=%s", msb, lsb)
        else
            bank.srcchannel = srcchannel
            bank.dstchannel = dstchannel
            if srcchannel == 17 then
                -- Omni: bank is available on all channels
                for srcchannel = 1, 16 do
                    local banks_list = rfx.banks_by_channel[srcchannel]
                    if not banks_list then
                        banks_list = {}
                        rfx.banks_by_channel[srcchannel] = banks_list
                    end
                    banks_list[#banks_list + 1] = bank
                end
            else
                local banks_list = rfx.banks_by_channel[srcchannel]
                if not banks_list then
                    banks_list = {}
                    rfx.banks_by_channel[srcchannel] = banks_list
                end
                banks_list[#banks_list + 1] = bank
            end
        end
    end

    -- Update the reabank version stored in the RFX
    rfx.reabank_version = reabank.version % 256
    local metadata = (rfx.metadata & 0xffff00ff) | (rfx.reabank_version << 8)
    -- Only update the metadata if it actually changed.
    if metadata ~= rfx.metadata then
        rfx.push_state(rfx.track)
        rfx.set_param(rfx.params.metadata, metadata)
        rfx.pop_state()
    end
end

-- Called when bank list is changed.  This sends the articulation details for all current
-- banks in the bank list.
-- TODO: will eventually need something like this that can sync all tracks in the project.
function rfx.sync_articulation_details()
    if not rfx.fx then
        return
    end
    rfx.push_state(rfx.track)
    rfx.opcode(rfx.OPCODE_CLEAR)
    rfx.sync_banks_by_channel()
    for param = rfx.params.control_start, rfx.params.control_end do
        local channel = param - rfx.params.control_start + 1
        local banks = rfx.banks_by_channel[channel]
        if banks then
            for _, bank in ipairs(banks) do
                bank:realize()
                local param1 = (channel - 1) | (0 << 4)
                rfx.opcode(rfx.OPCODE_NEW_BANK, param1, bank.msb, bank.lsb)
                for _, cc in ipairs(bank:get_chase_cc_list()) do
                    rfx.opcode(rfx.OPCODE_SET_BANK_CHASE_CC, cc)
                end
                for _, art in ipairs(bank.articulations) do
                    local version = 0
                    local group = art.group - 1
                    local outputs = art:get_outputs()
                    local version = 0
                    -- If the articulation has a conditional output event then we need to use a
                    -- v1 articulation record to allow OPCODE_SET_OUTPUT_EVENT_INFO1 later.
                    if art:has_conditional_output() then
                        version = 1
                    end
                    -- First nybble of param1 is source channel, while second is articulation record version.
                    local param1 = (channel - 1) | (version << 4)
                    rfx.opcode(rfx.OPCODE_NEW_ARTICULATION, param1, art.program, (group << 4) + #outputs)
                    rfx.opcode(rfx.OPCODE_SET_ARTICULATION_INFO, art.flags, art.off or bank.off or 128, 0)

                    for _, output in ipairs(outputs) do
                        local dstchannel = output.channel
                        if not dstchannel then
                            if bank.dstchannel ~= 17 then
                                dstchannel = bank.dstchannel
                            else
                                dstchannel = channel
                            end
                        end
                        local param1 = tonumber(output.args[1] or 0)
                        local param2 = tonumber(output.args[2] or 0)
                        -- Set bit 7 of param1 if this output event should not setup routing
                        if not output.route then
                            param1 = param1 | 0x80
                        end
                        local typechannel = ((dstchannel - 1) << 4) + (output_type_to_rfx_param[output.type] or 0)
                        rfx.opcode(rfx.OPCODE_ADD_OUTPUT_EVENT, typechannel, param1, param2)

                        -- Set filter program if the output event is conditional.
                        local filter = output.filter_program and (output.filter_program | 0x80) or 0
                        if version > 0 and filter > 0 then
                            rfx.opcode(rfx.OPCODE_SET_OUTPUT_EVENT_INFO1, filter, 0, 0)
                        end
                    end
                end
            end
        else
            rfx.set_data(param, NO_PROGRAM, NO_PROGRAM, NO_PROGRAM, NO_PROGRAM)
        end
    end
    rfx.pop_state()
end

-- Clears the current program for the given channel.  Channel and group
-- are offset from 1.
function rfx.clear_channel_program(channel, group)
    if group == 4 then
        local value = rfx.get_param(rfx.params.group_4_enabled_programs)
        value = value & ~(1 << (channel - 1))
        rfx.set_param(rfx.params.group_4_enabled_programs, value)
    else
        local param = rfx.params.control_start + channel - 1
        local value = rfx.get_param(param)
        local shift = 8 * (group - 1)
        value = (value & ~(0xff << shift)) | (NO_PROGRAM << shift)
        rfx.set_param(param, value)
    end
end

function rfx.activate_articulation(channel, program)
    rfx.push_state(rfx.track)
    rfx.opcode(rfx.OPCODE_ACTIVATE_ARTICULATION, channel, program)
    rfx.pop_state()
    -- It may be tempting to sync() now but the RFX will trigger the articulation
    -- asynchronously, so syncing now will miss it most of the time.  Might as well
    -- just wait for the next refresh.
end


-- Stores automation state of the given track as well as last touched FX to ensure that
-- that manipulation of the RFX is as transparent as possible.
--
-- This is called enough that it tries to be light weight in the common case.  That is,
-- if track automation is read only, then there's no need to temporarily change it.
-- And if additionally there's no last touched FX, this function is effectively a
-- no-op (at least in that it does not leave side effects).
function rfx.push_state(track)
    local state = rfx.state
    local track_mode = 0
    if track then
        track_mode = reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE")
    end
    if state.depth == 0 then
        -- state.t0 = os.clock()
        state.global_automation_override = reaper.GetGlobalAutomationOverride()

        -- Remember last touched FX and clear automation modes.
        local last = state.last_touched_fx
        local lr, ltracknum, lfx, lparam = reaper.GetLastTouchedFX()
        if lr then
            -- XXX: GetLastTouchedFX() is not compatible with subprojects.
            -- https://forum.cockos.com/showthread.php?p=1967642
            if ltracknum > 0 then
                last.track = reaper.GetTrack(0, ltracknum - 1)
            else
                last.track = reaper.GetMasterTrack(0)
            end
            last.fx = lfx
            -- Do the quick magic test on the last touched FX to see if it's an RFX.
            -- We don't want to restore last touched FX for any RFX.  The magic test
            -- can result in false positives, but it's _probably_ ok here.
            local val, _, _ = reaper.TrackFX_GetParam(last.track, lfx, 0)
            if val < 0 or (math.floor(val) & 0xff000000) ~= rfx.MAGIC then
                -- Last FX isn't an RFX, so we're ok to restore it.
                last.param = lparam
                last.rfx = false
            else
                -- Last touched FX is (somehow) an RFX.  Let's at least change the last
                -- touched parameter to something innocuous.  (This parameter is unused.)
                last.param = 61
                last.rfx = true
            end
            last.automation_mode = reaper.GetMediaTrackInfo_Value(last.track, "I_AUTOMODE")
            if last.automation_mode > 1 then
                state.tracks[last.track] = last.automation_mode
                reaper.SetMediaTrackInfo_Value(last.track, "I_AUTOMODE", 0)
            end
        elseif track_mode <= 1 then
            -- No last touched FX, and track automation mode is non-writing.  So there is really
            -- nothing for us to do.
            return
        else
            -- No last touched FX but the current track has a writable automation mode so there's
            -- more to do.
            last.track = nil
        end
        -- Undo block _seems_ not to be necessary.  TBD.  Without it, it shows up as a general
        -- Edit FX Parameter: Track XXX: Reaticulate.   It might be nice to have the custom
        -- message from Undo_EndBlock() in the undo history, but that comes at a *very* significant
        -- cost (about 0.02 seconds on my system).  Not worth it if functionally things seem ok
        -- otherwise.
        -- reaper.Undo_BeginBlock()
        reaper.PreventUIRefresh(1)
        if state.global_automation_override > 1 then
            reaper.SetGlobalAutomationOverride(-1)
        end
    end
    state.depth = state.depth + 1
    if track_mode > 1 and state.tracks[track] == nil then
        -- Track is valid with a writable automation mode.
        state.tracks[track] = track_mode
        reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", 0)
    end
end


-- Restores the track's automation state / last touched FX if it was previously saved.
function rfx.pop_state()
    local state = rfx.state
    if state.depth == 0 then
        -- Nothing to do.  If push_state() was called it didn't need to do anything.
        return
    end
    state.depth = state.depth - 1
    if state.depth > 0 then
        return
    end

    -- Restore last touched FX
    local last = state.last_touched_fx
    if last.track and reaper.ValidatePtr2(0, last.track, "MediaTrack*") then
        if last.automation_mode > 1 then
            reaper.SetMediaTrackInfo_Value(last.track, "I_AUTOMODE", 0)
        end
        -- If the last touched FX is an RFX or the last touched track is different than
        -- the current one, we can safely restore the last touched FX synchronously because
        -- we know any action that occurred in between push_state() and pop_state() wouldn't
        -- have interfered with the last toucehd FX.
        --
        -- Otherwise, we defer restoration of last touched FX in case we've just activated an
        -- articulation that's generated an output event that ends up modifying the last
        -- touched FX.
        --
        -- For example, in CSS, if the user clicks in the UI e.g. the con sordino button, this
        -- sets the last touched FX to the host parameter for con sordino.  Then if we activate
        -- the articulation for con sord, this would modify the con sord state.  If we now read
        -- and restore that param before the VSTi has a chance to communicate the change back,
        -- we will have undone the articulation change.
        function restore()
            if last.track and reaper.ValidatePtr2(0, last.track, "MediaTrack*") then
                local lastval, _, _ = reaper.TrackFX_GetParam(last.track, last.fx, last.param)
                reaper.TrackFX_SetParam(last.track, last.fx, last.param, lastval)
            end
            last.deferred = false
            last.track = nil
        end
        if last.rfx or last.track ~= rfx.track then
            restore()
        elseif not last.deferred then
            last.deferred = true
            reaper.defer(restore)
        end
    else
        last.track = nil
    end

    -- Due to what must be a bug in Reaper, we need to restore the track automation modes
    -- _after_ ending the undo block, otherwise the parameters adjusted above end up
    -- getting automatically armed.
    -- reaper.Undo_EndBlock("Reaticulate: communication to RFX", 2)

    -- For some reason, restoring track automation modes doesn't end up cluttering
    -- undo history even though we are outside of an undo block (probably another
    -- Reaper bug?).
    for track, mode in pairs(state.tracks) do
        reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", mode)
        state.tracks[track] = nil
    end

    if state.global_automation_override > 1 then
        reaper.SetGlobalAutomationOverride(state.global_automation_override)
    end
    reaper.PreventUIRefresh(-1)
    -- log("push/pop took %f", os.clock() - state.t0)
end


-- Lower level functions

-- Send an operation to program the RFX.  This is primarily used as a way to
-- load large amounts of data into the RFX whose size exceeds what can be stored
-- in the available FX parameters.
--
-- This is perhaps a bit of a precarious hack: it only works because *all* parameters
-- set via TrackFX_SetParam are reliably seen by the JSFX.  This is either because
-- the @slider section in the JSFX is evaluated immediately and synchronously within
-- TrackFX_SetParam, or there is some queuing mechanism to allow all parameters to
-- be replayed within the JSFX asynchronously.
--
-- This may depend too much on a coincidence of implementation.  If Reaper decides to
-- begin lazily evaluating FX parameters, perhaps as an optimization, this whole approach
-- will collapse.
--
-- For now, will take my chances: https://forum.cockos.com/showthread.php?p=1893338
--
function rfx.opcode(opcode, b0, b1, b2)
    rfx.set_data(rfx.params.opcode, b0 or 0, b1 or 0, b2 or 0, opcode)
end

function rfx.get_data(param)
    if rfx.track and rfx.fx then
        local r = rfx.get_param(param)
        if r then
            local b0, b1, b2 = r & 0xff, (r & 0xff00) >> 8, (r & 0xff0000) >> 16
            local b3 = (r & 0x7f000000) >> 24
            return b0, b1, b2, b3
        end
    end
    return nil, nil, nil, nil
end


function rfx.set_data(param, b0, b1, b2, b3)
    if rfx.track and rfx.fx then
        if b0 == nil or b1 == nil or b2 == nil or b3 == nil then
            local ob0, ob1, ob2, ob3 = rfx.get_data(param)
            b0, b1, b2, b3 = b0 or ob0, b1 or ob1, b2 or ob2, b3 or ob3
        end
        local value = b0 + (b1 << 8) + (b2 << 16) + ((b3 & 0x7f) << 24)
        r = reaper.TrackFX_SetParam(rfx.track, rfx.fx, param, value)
    end
    return false
end


function rfx.get_param(param, value)
    if rfx.track and rfx.fx then
        local r, _, _ = reaper.TrackFX_GetParam(rfx.track, rfx.fx, param)
        if r >= 0 then
            return math.floor(r) & 0xffffffff
        end
    end
    return nil
end


function rfx.set_param(param, value)
    if rfx.track and rfx.fx then
        return reaper.TrackFX_SetParam(rfx.track, rfx.fx, param, value or 0)
    end
    return false
end

return rfx