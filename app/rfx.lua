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
--


-- This module contains functions used to manage the Reaticulate JSFX (RFX)
-- instances, including discovery, installation, and communication with the
-- instances.

local rtk = require 'rtk'
local binser = require 'lib.binser'
local json = require 'lib.json'
local reabank = require 'reabank'
local log = rtk.log
require 'lib.utils'

local NO_PROGRAM = 128


local rfx = {
    -- MSB of first parameter must be set to this or else it's not an RFX instance.
    MAGIC = 42 << 24,

    -- Opcodes for programming the RFX.
    --
    -- See rfx.opcode(), and Reaticuate.jsfx for more details on the API.
    OPCODE_NOOP = 0,
    OPCODE_CLEAR = 1,
    OPCODE_ACTIVATE_ARTICULATION = 2,
    OPCODE_NEW_ARTICULATION = 3,
    OPCODE_ADD_ARTICULATION_EXTENSION = 4,
    OPCODE_ADD_OUTPUT_EVENT = 5,
    OPCODE_ADD_OUTPUT_EVENT_EXTENSION = 6,
    OPCODE_SYNC_TO_FEEDBACK_CONTROLLER = 7,
    OPCODE_SET_CC_FEEDBACK_ENABLED = 8,
    OPCODE_NEW_BANK = 9,
    OPCODE_SET_BANK_CHASE_CC = 10,
    OPCODE_FINALIZE_ARTICULATIONS = 11,

    -- Note: RFX app data is deprecated and replaced by P_EXT track data in 0.5. Preserved
    -- for backward compatibility and only used to clear out app data after migration.
    OPCODE_SET_APPDATA = 12,
    OPCODE_CLEAR_ARTICULATION = 13,
    OPCODE_ADVANCE_HISTORY = 14,
    OPCODE_UPDATE_CURRENT_CCS = 15,
    OPCODE_SUBSCRIBE = 16,

    -- Shared gmem buffer indices offsets.  The indexes come in two flavors:
    --    * global indices (GIDX): relative to gmem[0]
    --    * instance indices (IIDX): relative to the instance's gmem_index

    --
    -- These are the global indices (relative to gmem[0]).  Most of them are
    -- written in rfx.init()
    --

    -- Magic value so that RFX instances know we have initialized the global
    -- gmem parameters.
    GMEM_GIDX_MAGIC = 0,
    -- The version number for the memory arrangement. The GMEM_VERSION will be
    -- written here.  Probably will never be used but included to allow for
    -- radically differnt arrangements.
    GMEM_GIDX_VERSION = 1,
    -- The monotonically increasing serial (wall clock) written once when the main
    -- script is initialized.  This can be used by the RFX to detect when the main
    -- script has restarted.
    GMEM_GIDX_SERIAL = 2,
    -- A shared region used (carefully) by the RFX instances to determine what gmem
    -- slots are available for the per-RFX gmem index.  This data isn't opaque to
    -- the main script: rfc.gc() will modify it.
    GMEM_GIDX_ID_BITMAP_OFFSET = 3,
    -- The current app default channel is stored at this index
    GMEM_GIDX_DEFAULT_CHANNEL = 4,
    -- Contains the value of GMEM_RFX_OFFSET, which is the index from gmem[0] where
    -- instance data begins.
    GMEM_GIDX_RFX_OFFSET = 5,
    -- Contains the value of GMEM_RFX_STRIDE, which holdes the number of slots for
    -- each RFX instance region.
    GMEM_GIDX_RFX_STRIDE = 6,
    -- Holds the value of GMEM_IIDX_OPCODES so the RFX knows where to read
    GMEM_GIDX_OPCODES_OFFSET = 20,
    -- Holds the value of GMEM_IIDX_APP_DATA so the RFX knows where to read/write
    --
    -- Note: RFX app data is deprecated and replaced by P_EXT track data in 0.5. Preserved
    -- for backward compatibility.
    GMEM_GIDX_APP_DATA_OFFSET = 21,
    -- Holds the value of GMEM_IIDX_INSTANCE_DATA so the RFX knows where to write
    GMEM_GIDX_INSTANCE_DATA_OFFSET = 22,
    -- Holds the value of GMEM_IIDX_INSTANCE_DATA_SUBSCRIPTION
    GMEM_GIDX_SUBSCRIPTION_OFFSET = 23,


    -- Global gmem parameters.  When these change (other than magic which can
    -- never change), GMEM_VERSION must change too.
    GMEM_VERSION = 1,
    GMEM_MAGIC = 0xbadc0de,
    -- Index from gmem buffer where the instance id bitmap begins.  See rfx.gc()
    -- here and gmem_allocate() in Reaticulate.jsfx for more details.
    GMEM_ID_BITMAP_OFFSET = 1000,
    -- Index from gmem buffer where the first RFX instance region begins.
    GMEM_RFX_OFFSET = 2000,
    -- The number of slots for each RFX instance region.  Together with
    -- GMEM_RFX_OFFSET and the id bitmap, RFX instances are able to allocate a
    -- unique instance id and gmem_index.
    GMEM_RFX_STRIDE = 3000,


    --
    -- These are the instance indicies, relative to the RFX's gmem_index
    --

    -- Slot (relative to gmem_index) that holds the main script's view of the
    -- RFX's instance id.
    GMEM_IIDX_INSTANCE_ID = 0,
    -- Slot (relative to gmem_index) that holds the global serial written when
    -- the RFX's gmem_index is allocated.
    GMEM_IIDX_SERIAL = 1,
    -- Slot (relative to gmem_index) that holds the the pong value (expected to
    -- be the value written at GMEM_GIDX_PING)
    GMEM_IIDX_PONG = 2,
    -- This index holds a bitmap of things the main app is interested in
    -- reading from instance data.  See SUBSCRIPTION_* constants.
    GMEM_IIDX_INSTANCE_DATA_SUBSCRIPTION = 3,
    -- Slot (relative to gmem_index) for enqueued opcodes to be executed by the RFX
    GMEM_IIDX_OPCODES = 100,
    -- Slot (relative to gmem_index) that holds the serialized application data as
    -- stored by rfx._write_appdata().
    --
    -- Note: RFX app data is deprecated and replaced by P_EXT track data in 0.5. Preserved
    -- for backward compatibility.
    GMEM_IIDX_APP_DATA = 1000,
    -- Slot (relative to gmem_index) that holds data the instance is communicating
    -- back to us, such as current selected programs or active notes.
    GMEM_IIDX_INSTANCE_DATA = 2000,

    -- The available number of slots for opcodes (GMEM_IIDX_INSTANCE_DATA - GMEM_IDX_APP_DATA)
    GMEM_OPCODES_BUFFER_SIZE = 1000 - 100,
    -- Available number of slots for app data
    GMEM_APP_DATA_BUFFER_SIZE = 2000 - 1000,

    -- Constants for the rfx.Track.error value.
    ERROR_NONE = nil,
    -- These are critical errors that will be set when fx == nil
    ERROR_MISSING_RFX = 1,
    ERROR_TRACK_FX_BYPASSED = 2,
    ERROR_RFX_BYPASSED = 3,
    ERROR_BAD_MAGIC = 4,
    ERROR_UNSUPPORTED_VERSION = 5,
    ERROR_DESERIALIZATION_FAILED = 6,


    -- These are non-critical application level errors that can occur even when
    -- fx is valid, and usually indicate some possible issue with functionality.
    -- This will be set via rfx.set_error(), in which case it is persisted in
    -- rfx appdata's err attribute and restored when the track is selected.
    --
    -- These should be listed in ascending order of severity as when there are
    -- multiple errors on a bank, the highest will be used.
    ERROR_DUPLICATE_BANK = 1,
    ERROR_BUS_CONFLICT = 2,
    ERROR_PROGRAM_CONFLICT = 3,
    ERROR_UNKNOWN_BANK = 4,

    MAX_BANKS = 16,

    -- Constants for OPCODE_SUBSCRIBE.
    SUBSCRIPTION_NONE = 0,
    SUBSCRIPTION_CC = 1 << 0,
    SUBSCRIPTION_NOTES = 1 << 1,

    params_by_version = {
        [1] = {
            -- byte 0: change serial, byte 1: reabank version (mod 256), byte 2: RFX version, byte 3: magic
            -- This is the only parameter that must be hardcoded at 0 regardless of version.
            metadata = 0,
            -- Index within the gmem buffer for the instance's start of data
            gmem_index = 1,
            instance_id = 3,

            history_serial = 61,
            opcode = 63,

            --
            -- Parameters below are DEPRECATED by communication via gmem buffer
            --

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

        }
    },

    last_gmem_gc_time = 0,
    last_instance_num = 0,
    global_serial = 0,

    -- If not nil, it's a map of gmem_index -> {track, fx, appdata} representing
    -- the RFX instances that have queued opcodes that need to be committed and,
    -- if not nil, the appdata which should be stored during commit.  These are
    -- committed via rfx.opcode_commit_all().
    rfx_awaiting_commit = nil,

    -- Bitmap of channels with active notes
    active_notes = 0,
    -- Callback invoked when the articulation changes on a channel
    onartchange = function(channel, group, last, current, track_changed) end,
    -- Callback invoked when active notes change
    onnoteschange = function(old, new) end,
    -- Callback invoked when CCs on default channel change
    onccchange = function() end,
    -- Callback invoked when selecting a track with a different bank hash
    onhashchange = function() end,
    -- Callback invoked by presync() just before unsubscribing from the current
    -- track.
    onunsubscribe = function() end,

    -- Saved state so we don't butcher things like last touched FX and automation
    -- by setting parameters on the RFX.  See rfx.push_state().
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
    ["pitch"] = 6,

}

--------------------------------------------------------------
-- Module functions
--------------------------------------------------------------

function rfx.init()
    rfx.global_serial = os.time()
    reaper.gmem_attach('reaticulate')
    reaper.gmem_write(rfx.GMEM_GIDX_SERIAL, rfx.global_serial)
    reaper.gmem_write(rfx.GMEM_GIDX_ID_BITMAP_OFFSET, rfx.GMEM_ID_BITMAP_OFFSET)
    reaper.gmem_write(rfx.GMEM_GIDX_RFX_OFFSET, rfx.GMEM_RFX_OFFSET)
    reaper.gmem_write(rfx.GMEM_GIDX_RFX_STRIDE, rfx.GMEM_RFX_STRIDE)
    reaper.gmem_write(rfx.GMEM_GIDX_OPCODES_OFFSET, rfx.GMEM_IIDX_OPCODES)
    -- App data region is deprecated and has been replaced by P_EXT track data. It is now
    -- maintained for backward compatibility with Reaticulate 0.4.0 and earlier.
    reaper.gmem_write(rfx.GMEM_GIDX_APP_DATA_OFFSET, rfx.GMEM_IIDX_APP_DATA)
    -- Note that while we (the main app) dictate the offsets within the RFX gmem region,
    -- the JSFX itself dictates how the instance data region itself is sliced and diced.
    -- See the comment for GMEM_GIDX_INSTANCE_DATA_OFFSET in Reaticulate.jsfx.
    reaper.gmem_write(rfx.GMEM_GIDX_INSTANCE_DATA_OFFSET, rfx.GMEM_IIDX_INSTANCE_DATA)
    reaper.gmem_write(rfx.GMEM_GIDX_SUBSCRIPTION_OFFSET, rfx.GMEM_IIDX_INSTANCE_DATA_SUBSCRIPTION)


    -- Now that all global gmem parameters have been initialized, write the version and
    -- magic. RFX instances will watch for version changes and reassign gmem index
    -- if changed, provided the magic is present.
    reaper.gmem_write(rfx.GMEM_GIDX_VERSION, rfx.GMEM_VERSION)
    reaper.gmem_write(rfx.GMEM_GIDX_MAGIC, rfx.GMEM_MAGIC)

    -- Singleton instance whose context is updated as the track changes.
    rfx.current = rfx.Track()
end


function rfx.get(track)
    if reaper.ValidatePtr2(0, track, "MediaTrack*") then
        return reaper.TrackFX_GetByName(track, "Reaticulate", false)
    end
end

-- Returns true if the audio device is open, false otherwise.
function rfx.is_audio_device_open()
    local r, _ = reaper.GetAudioDeviceInfo('MODE', '')
    return r
end

-- Determine if the given fx is a legit Reaticulate FX.  It returns the suppled
-- fx if valid, or nil otherwise.
--
-- Returns (fx, metadata, version, params, gmem_index, error) where all non-error parameters
-- nil if the validation failed, in which case error will be set to an
-- rfx.ERROR_* constant.
--
-- This function is called frequently (via rfx.sync())
function rfx.validate(track, fx)
    if fx == nil or fx == -1 then
        return nil, nil, nil, nil, nil, rfx.ERROR_MISSING_RFX
    end

    local r, _, _ = reaper.TrackFX_GetParam(track, fx, 0)
    if r < 0 then
        return nil, nil, nil, nil, nil, rfx.ERROR_MISSING_RFX
    end

    if reaper.GetMediaTrackInfo_Value(track, "I_FXEN") ~= 1 then
        return nil, nil, nil, nil, nil, rfx.ERROR_TRACK_FX_BYPASSED
    end
    if not reaper.TrackFX_GetEnabled(track, fx) or reaper.TrackFX_GetOffline(track, fx) then
        return nil, nil, nil, nil, nil, rfx.ERROR_RFX_BYPASSED
    end

    local metadata = math.floor(r)
    local magic = metadata & 0xff000000
    if magic ~= rfx.MAGIC then
        return nil, nil, nil, nil, nil, rfx.ERROR_BAD_MAGIC
    end

    local version = (metadata & 0x00ff0000) >> 16
    local params = rfx.params_by_version[version]
    if params == nil then
        return nil, nil, nil, nil, nil, rfx.ERROR_UNSUPPORTED_VERSION
    end
    local gmem_index, _, _ = reaper.TrackFX_GetParam(track, fx, params.gmem_index)
    if gmem_index == 0 then
        -- It's possible we just initialized the global gmem params, so bump the opcode
        -- param to force the rfx to gmem_alloc() inside @slider and then try fetching
        -- again.  But meanwhile, it's not the end of the world if we wait until the next
        -- cycle, we'll just get a bit of a flicker.
        --
        -- There's an obscure bug here as well: if opening REAPER with the audio device
        -- closed (e.g. start REAPER (show audio configuration on startup) shortcut), when
        -- selecting a track with Reaticulate, this warning will spew on the console not
        -- just until the audio device is open, but the track is reselected (or, more
        -- precisely, record arm is toggled).  Touching the opcode parameter doesn't make
        -- a difference, so this seems to be a specific REAPERism at play.  I think we can
        -- live with this wart.
        log.warning("rfx: instance missing gmem_index")
        return nil, nil, nil, nil, nil, rfx.ERROR_MISSING_RFX
    end
    return fx, metadata, version, params, gmem_index, nil
end


-- The JSFX instances autonomously allocate their own instance ids
-- based on 100 32-bit slots in the ID_BITMAP gmem region.  As instances come
-- and go, the instance id normally just continuously increases.
--
-- This function scans all active RFX instances and adjusts the gmem
-- instance slots based on what's current, effectively zeroing the bits
-- for defunct RFX.
--
-- It's safe to invoke this function frequently as it self-throttles.
function rfx.gc(force)
    -- Because this function involves enumerating every track across every
    -- loaded project, it's not exactly cheap.  So we only bother doing this
    -- when we have ~1000 gmem ids already allocated (offset 30).
    --
    -- Mask low 32-bits before comparison because gmem_read() returns a 64-bit
    -- value on 64-bit architectures.
    if reaper.gmem_read(rfx.GMEM_ID_BITMAP_OFFSET + 30) & 0xffffffff ~= 0xffffffff and not force then
        -- Not under enough pressure yet to bother
        return
    end
    local now = reaper.time_precise()
    if now - rfx.last_gmem_gc_time < 30 and not force then
        -- Don't do this more than once per 30 seconds.
        return
    end
    rfx.last_gmem_gc_time = now

    log.time_start()
    -- Iterate through all projects and tracks and determine the RFX instance ids
    -- for all valid RFX.  Create a set of 100 32-bit bitmaps according to what
    -- is expected to be in the gmem id bitmap slots based on the current RFX.
    local slots = {}
    -- Tiny bit of paranoia about an infinite loop, so cap the number of currently
    -- loaded projects we'll check to 100.  Surely that's enough.
    for pidx = 0, 100 do
        local proj, _ = reaper.EnumProjects(pidx, '')
        if not proj then
            break
        end
        for tidx = 0, reaper.CountTracks(proj) - 1 do
            local track = reaper.GetTrack(proj, tidx)
            local fx = rfx.get(track)
            local fx, metadata, version, error = rfx.validate(track, fx)
            if fx then
                local params = rfx.params_by_version[version]
                local id, _, _ = reaper.TrackFX_GetParam(track, fx, params.instance_id)
                local idx = math.floor(id / 32)
                local bit = (1 << (id % 32))
                if (slots[idx] or 0) & bit == 0 then
                    slots[idx] = (slots[idx] or 0) | bit
                else
                    log.error('BUG: track %s does not have a unique Reaticulate instance id!', track)
                end
            end
        end
    end

    for i = 0, 100 do
        local bitmap = reaper.gmem_read(rfx.GMEM_ID_BITMAP_OFFSET + i) & 0xffffffff
        -- The Lua API doesn't have an atomic setifequal like JSFX.  We solve
        -- this by only cleaning slots that have all 32 bits set, which the JSFX
        -- will not touch.
        if (bitmap == 0xffffffff and slots[i] ~= 0xffffffff) or (force and slots[i] and bitmap ~= slots[i]) then
            log.debug('rfx: gc slot %d: %x != %x', i, bitmap, slots[i] or 0)
            reaper.gmem_write(rfx.GMEM_ID_BITMAP_OFFSET + i, slots[i] or 0)
        end
        -- if bitmap ~= 0 then
        --     log.debug2('slot %d: %x -> %x', i, bitmap, slots[i] or 0)
        -- end
    end
    log.debug('rfx: gc complete')
    log.time_end()
end

-- Updates the default channel in the global gmem slot.  This value is shared by all RFX.
--
-- Channel number is offset from 1.
function rfx.set_gmem_global_default_channel(channel)
    reaper.gmem_write(rfx.GMEM_GIDX_DEFAULT_CHANNEL, channel - 1)
end



--
-- Low-level module functions.  Generally using an rfx.Track is preferred, but these
-- lower level functions can be useful for performance.
--

-- Enqueue an opcode to the specified track and RFX.  If the queue is full, the pending
-- opcodes are flushed, which will unfortunately generate undo.
--
-- This function assumes the given track/fx has already been validated using
-- rfx.validate().
--
-- See rfx.Track:opcode() for more details, which is the preferred method.
function rfx.opcode(opcode, args, track, fx, gmem_index, opcode_param, do_commit)
    local offset = gmem_index + rfx.GMEM_IIDX_OPCODES
    if not offset then
        -- This shouldn't happen.  Log an error and a stack trace.
        return log.exception("rfx: opcode() called on track without valid RFX")
    end
    local n_committed = reaper.gmem_read(offset)

    if n_committed > 0 then
        -- We're trying to enqueue an opcode while there are committed opcodes
        -- not yet processed by the RFX.  Although the main loop (via
        -- App:handle_onupdate) commits all pending opcodes, it doesn't flush
        -- them, lest we risk polluting undo history.  If we're here, it means
        -- we committed in the last cycle and we're waiting for the RFX still.
        -- Since we can't modify a committed queue, we forfeit our goal to
        -- avoid polluting undo by writing an FX parameter to force the RFX's
        -- @slider code to execute.
        --
        -- At least with Reaper at the time of writing, this is executed
        -- synchronosly, so by the time TrackFX_SetParam() returns, @slider has
        -- finished running (which means all queued opcodes have been processed)
        --
        -- If this happens more frequently in practice, we can consider double
        -- buffering the opcode queue.
        --
        rfx.opcode_flush(track, fx, gmem_index, opcode_param)
        if not rfx.is_audio_device_open() then
            -- Audio device is closed, so the opcode flush failure is expected.  Surface
            -- an error message to the user to explain why things aren't working.
            log.error('reaticulate: audio device is closed, some functionality will not work')
        else
            log.warning("rfx: %s committed opcodes during enqueue, forced a flush", n_committed)
            log.trace(log.INFO)
        end

        -- Sanity check that indeed the opcodes were synchronously executed by the RFX.
        n_committed = reaper.gmem_read(offset)
        if n_committed > 0 then
            -- This shouldn't happen.  It means the RFX didn't respond synchronously.
            -- The opcode is now lost.
            return log.critical("rfx: opcode flush did not seem to work")
        end

    end
    -- Number of arguments
    local argc = args and #args or 0
    -- Check to see if the queue is full and needs to be flushed.
    local queue_size = reaper.gmem_read(offset + 1)

    if 2 + queue_size + 1 + argc >= rfx.GMEM_OPCODES_BUFFER_SIZE then
        -- The opcode queue gmem region is full, so we need to force the flush now.
        rfx.opcode_flush(track, fx, gmem_index, opcode_param)
        queue_size = 0
    end

    -- Write the opcode and the provided arguments (if any) to the gmem buffer.
    local opidx = offset + 2 + queue_size
    reaper.gmem_write(opidx, opcode | (argc << 8))
    for i = 1, argc do
        reaper.gmem_write(opidx + i, args[i])
    end
    reaper.gmem_write(offset + 1, queue_size + 1 + argc)

    if do_commit ~= false then
        rfx._queue_commit(track, fx, nil, gmem_index)
    end
end

-- Like rfx.opcode(), but can be called on an unvalidated track when the RFX id isn't
-- known.
--
-- This function will perform the validation, discover the RFX, and send the given opcode.
-- If discovery and validation was successful, true is returned.  Otherwise false is
-- returned.
function rfx.opcode_on_track(track, opcode, args)
    local fx, _, _, params, gmem_index, _ = rfx.validate(track, rfx.get(track))
    if fx then
        rfx.opcode(opcode, args, track, fx, gmem_index, params.opcode)
        return true
    else
        return false
    end
end

-- Internal function to mark the given RFX
function rfx._queue_commit(track, fx, appdata, gmem_index)
    gmem_index = tostring(gmem_index)
    if rfx.rfx_awaiting_commit == nil then
        rfx.rfx_awaiting_commit = {[gmem_index] = {track, fx, appdata}}
    else
        local t = rfx.rfx_awaiting_commit[gmem_index]
        if t == nil then
            rfx.rfx_awaiting_commit[gmem_index] = {track, fx, appdata}
        else
            t[2] = fx or t[2]
            t[3] = appdata or t[3]
        end
    end
end

-- Commit previously enqueued opcodes to make them visible to the RFX. Commited opcodes
-- will be executed asynchronously at some unspecified time unless rfx.opcode_flush() is
-- called.
function rfx._opcode_commit(track, fx, gmem_index)
    if gmem_index == nil then
        log.exception('_opcode_commit given nil offset')
        return
    end
    local offset = gmem_index + rfx.GMEM_IIDX_OPCODES
    local n_buffered = reaper.gmem_read(offset + 1)
    log.debug('rfx: commit opcodes gmem_index=%s n=%s first=%s', gmem_index, n_buffered, reaper.gmem_read(offset + 2))
    reaper.gmem_write(offset + 1, 0)
    reaper.gmem_write(offset, n_buffered)
    rfx.rfx_awaiting_commit[gmem_index] = nil
end

-- Commit all enqueued opcodes across all tracks, as well as any appdata that's pending
-- for write.
function rfx.opcode_commit_all()
    if rfx.rfx_awaiting_commit ~= nil then
        for gmem_index, trackfx in pairs(rfx.rfx_awaiting_commit) do
            local track, fx, appdata = table.unpack(trackfx)
            if reaper.ValidatePtr2(0, track, "MediaTrack*") then
                if appdata then
                    rfx._write_appdata(track, appdata)
                end
                if fx then
                    -- There are actual RFX opcodes for this track, so commit.  It's
                    -- possible for this to be nil if only track appdata was queued for
                    -- write.
                    rfx._opcode_commit(track, fx, gmem_index)
                end
            end
        end
        rfx.rfx_awaiting_commit = nil
    end
end

-- Synchronously flushes all pending opcodes on the given track.  This generates
-- undo, so the caller is expected to wrap it in a begin/end undo block stanza
-- if applicable.
function rfx.opcode_flush(track, fx, gmem_index, opcode_param)
    if not reaper.ValidatePtr2(0, track, "MediaTrack*") then
        -- Track abruptly deleted
        return
    end
    if rfx.rfx_awaiting_commit then
        rfx._opcode_commit(track, fx, gmem_index)
    end
    rfx.push_state(track)
    -- 42 is not magic: anything other than 0 will suffice to wake the JSFX.
    reaper.TrackFX_SetParam(track, fx, opcode_param, 42)
    rfx.pop_state()
end

-- Serialize and store the given appdata table in the RFX.
function rfx._write_appdata(track, appdata)
    -- '2' is the appdata serialization version, which allows us to rev the format.
    local data = '2' .. (appdata and json.encode(appdata) or '')
    reaper.GetSetMediaTrackInfo_String(track, 'P_EXT:reaticulate', data, true)
    reaper.MarkProjectDirty(0)
    log.info('rfx: wrote %s bytes of track appdata', #data)
end

-- Stores automation state of the given track as well as last touched FX to
-- ensure that that manipulation of the RFX is as transparent as possible.
--
-- In terms of RFX manipulation, this generally only needs to be called when
-- rfx.opcode_flush() is called, because opcode_flush() sets a track parameter
-- to kick the RFX.  In most cases, this can be avoided, except when a)
-- immediate response is needed or b) we send more opcodes than can be queued,
-- requiring a flush.
--
-- This tries to be light weight in the common case.  That is, if track
-- automation is read only, then there's no need to temporarily change it. And
-- if additionally there's no last touched FX, this function is effectively a
-- no-op (at least in that it does not leave side effects).
function rfx.push_state(track)
    local state = rfx.state
    local track_mode = 0
    if track and reaper.ValidatePtr2(0, track, "MediaTrack*") then
        track_mode = reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE")
    end
    state.depth = state.depth + 1
    if state.depth == 1 then
        -- First push, do all the things.
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
            if reaper.ValidatePtr2(0, last.track, "MediaTrack*") then
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
            else
                -- This is unexpected, but it seems to somehow be possible:
                -- https://github.com/jtackaberry/reaticulate/issues/70#issuecomment-513583393
                last.track = nil
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
        local function restore()
            if last.track and reaper.ValidatePtr2(0, last.track, "MediaTrack*") then
                local lastval, _, _ = reaper.TrackFX_GetParam(last.track, last.fx, last.param)
                reaper.TrackFX_SetParam(last.track, last.fx, last.param, lastval)
            end
            last.deferred = false
            last.track = nil
        end
        if last.rfx or last.track ~= rfx.current.track then
            restore()
        elseif not last.deferred then
            last.deferred = true
            rtk.defer(restore)
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
end

-- An iterator that yields rfx.Track objects for each Reaticulate track found in
-- the given project number (defaulting to current project).  The rfx.Track will
-- be presynced, so appdata will be available.
--
-- This yields the same rfx.Track object each time, just with different state.
-- So the caller would need to clone the rfx.Track if it wants to reuse the
-- object beyond the scope of the inner loop.
function rfx.get_tracks(project, include_disabled)
    project = project or 0
    local rfxtrack = rfx.Track()
    local ntracks = reaper.CountTracks(project)
    local idx = 0
    return function()
        while idx < ntracks do
            local track = reaper.GetTrack(project, idx)
            idx = idx + 1
            if rfxtrack:presync(track) then
                return idx, rfxtrack
            elseif (rfxtrack.error == rfx.ERROR_TRACK_FX_BYPASSED or
                    rfxtrack.error == rfx.ERROR_RFX_BYPASSED) and
                   include_disabled then
                    return idx, rfxtrack
            end
        end
    end
end

-- Returns an rfx.Track object given the underlying REAPER Track.  If the REAPER track
-- is invalid, then nil is returned.
function rfx.get_track(track)
    if not reaper.ValidatePtr2(0, track, 'MediaTrack*') then
        return
    end
    local rfxtrack = rfx.Track()
    rfxtrack:presync(track)
    return rfxtrack
end

-- Checks all tracks with enabled RFX and resyncs if any banks' hashes have changed.
function rfx.all_tracks_sync_banks_if_hash_changed()
    log.time_start()
    -- sync_banks_if_hash_changed() will call sync_banks_to_rfx() if the hash changes,
    -- and sync_banks_to_rfx() begins its own undo block.  Ensure we wrap all those in
    -- an outer undo block to prevent polluting undo history (and the performance hit that
    -- comes with that).
    reaper.Undo_BeginBlock2(0)
    for idx, rfxtrack in rfx.get_tracks(0, true) do
        assert(not rfxtrack.banks_by_channel)
        rfxtrack:sync_banks_if_hash_changed()
    end
    reaper.Undo_EndBlock2(0, "Reaticulate: update track banks (cannot be undone)", UNDO_STATE_FX)
    log.time_end('rfx: done resyncing RFX on all tracks')
end



--------------------------------------------------------------
-- GUID Migrator class
--
-- A helper class to migrate tracks to the new GUID-based system.
--------------------------------------------------------------
rfx.GUIDMigrator = rtk.class('rfx.GUIDMigrator')

function rfx.GUIDMigrator:initialize(track)
    -- RFXTrack instance
    self.track = track
    -- Map is {srcmsb -> {srclsb -> {dstmsb, dstlsb}}, ...}
    self.msblsbmap = {}
    -- True if remap_bank_select() has work to do, and set, if necessary, in
    -- add_bank_to_project()
    self.conversion_needed = false
end

-- Migrates a bankinfo table created by Reaticulate 0.4.x to 0.5.x GUID bankinfo. The
-- newly migrated bank is added to the project, with the previous MSB/LSB preserved if
-- possible (i.e. not already in use by another bank), otherwise a different MSB/LSB is
-- allocated.
--
-- Returns the Bank object for the migrated bank, or nil if no migration was
-- performed.
function rfx.GUIDMigrator:migrate_bankinfo(bankinfo)
    local msb, lsb
    if not bankinfo.t then
        -- Old style bankinfo that was in the format {src, dst, msb, lsb}.
        -- This might only have been present in prereleases, but we'll migrate
        -- it anyway.
        local src, dst = bankinfo[1], bankinfo[2]
        msb, lsb = bankinfo[3], bankinfo[4]
        -- Remove existing elements in bankinfo table rather than creating a new table,
        -- since it points to an existing table within the appdata and we want to preserve
        -- that.
        while #bankinfo > 0 do
            table.remove(bankinfo)
        end
        bankinfo.src = src
        bankinfo.dst = dst
        bankinfo.v = (msb << 8) | lsb
    elseif bankinfo.t == 'b' then
        -- MSB/LSB bankinfo
        msb, lsb = bankinfo.v >> 8, bankinfo.v & 0xff
    else
        -- Must be a GUID-based bankinfo (bankinfo.t == 'g'). Nothing to migrate.
        return
    end
    local bank = reabank.get_legacy_bank_by_msblsb(bankinfo.v)
    if not bank then
        log.warning('rfx: bank %s/%s could not be found for migration', msb, lsb)
        return
    else
        bankinfo.name = bank.name
    end
    if bank.guid then
        -- Convert the bankinfo to GUID.
        bankinfo.t = 'g'
        bankinfo.v = bank.guid
        self.track:queue_write_appdata()
        self:add_bank_to_project(bank, msb, lsb)
    else
        -- This should never happen because Bank GUIDs are generated if needed on parse.
        log.error('rfx: migration failed: bank %s is missing GUID', bank.name)
    end
    return bank
end

-- Adds the given bank to the current project with the requested MSB/LSB, based on the
-- pre-migrated MSB/LSB for that bank.
--
-- If the requested MSB/LSB could not be satisfied, then the conversion_needed flag is
-- set, which indicates that remap_bank_select() must be called in order to modify
-- all Bank Select events on the track being migrated.
--
-- Returns the MSB, LSB pair that was actually assigned in the project.
function rfx.GUIDMigrator:add_bank_to_project(bank, msb, lsb)
    local gotmsb, gotlsb = reabank.add_bank_to_project(bank, msb, lsb)
    if (msb or lsb) and (gotmsb ~= msb or gotlsb ~= lsb) then
        -- We had a previous MSB/LSB assigned to this bank but that assignment
        -- conflicted
        if self.msblsbmap[msb] then
            self.msblsbmap[msb][lsb] = {gotmsb, gotlsb, bank}
        else
            self.msblsbmap[msb] = {[lsb] = {gotmsb, gotlsb, bank}}
        end
        self.conversion_needed = true
    end
    log.info('rfx: migrate MSB/LSB bank reference to GUID: %s (%s/%s -> %s/%s)',
             bank.name, msb, lsb, gotmsb, gotlsb)
    return gotmsb, gotlsb
end

-- Remaps the MSB/LSB of all bank select (CC0 + CC32) events on the track based on the
-- MSB/LSB map maintained by add_bank_to_project().
--
-- If during migration all requested MSB/LSB could be satisfied in the project, then
-- no remapping is needed and this method is a no-op.
function rfx.GUIDMigrator:remap_bank_select()
    if not self.conversion_needed then
        return
    end
    remap_bank_select_multiple(self.track.track, self.msblsbmap)
end


--------------------------------------------------------------
-- Track class
--------------------------------------------------------------
rfx.Track = rtk.class('rfx.Track')

function rfx.Track:initialize()
    -- Metadata field of current RFX, which contains the byte-packed values for
    -- magic, version and change serial.
    self.metadata = nil
    -- Version of the RFX instance (relevant iff fx isn't nil). Parsed from metadata.
    self.version = nil
    -- The current change serial of the RFX.  When this changes without the track
    -- changing, then something about the RFX has changed and we consult slot 0 of
    -- the instance app data.  Parsed from metadata.
    self.serial = nil
    -- One of the params_by_version tables above, per the current RFX version
    self.params = nil
    -- gmem shared buffer index for this RFX.
    self.gmem_index  = nil
    -- Application data stored in the RFX
    self.appdata = nil
    -- If not nil, is a list of banks referenced by the RFX but not available.
    self.unknown_banks = nil
    -- Current program numbers on this track indexed by MIDI channel and
    -- sub-indexed by group.
    self.programs = {}
    -- Maps channel number to list of Bank objects for current track.  If the Bank objects
    -- are regenerated (e.g. because reabank.parseall() is called) then this table must be
    -- regenerated via rfx.Track:index_banks_by_channel_and_check_hash()
    self.banks_by_channel = nil
    self:reset()
end

function rfx.Track:reset()
    -- The current track (set via rfx.presync())
    self.track = nil
    -- Reaper FX id of the Reaticulate FX on current track, or nil if
    -- no valid one was found.
    self.fx = nil
    -- If not nil, then is one of the ERROR constants above.  If this is set
    -- then fx must be nil.
    self.error = nil
    for channel = 1, 16 do
        self.programs[channel] = {NO_PROGRAM, NO_PROGRAM, NO_PROGRAM, NO_PROGRAM}
    end
end

-- Validates the given fx and (if valid) sets the rfx table attributes according
-- to the RFX instance.  If the RFX's gmem_index hasn't been set then allocate
-- it now.
--
-- Returns the fx if valid, and nil otherwise in which case the error attribute
-- will be set.
--
-- This function is called frequently (via rfx.sync())
function rfx.Track:_sync_params(track, fx)
    local fx, metadata, version, params, gmem_index, error = rfx.validate(track, fx)
    if error then
        self.error = error
        return nil
    end
    if version ~= self.version then
        self.version = version
        self.params = params
    end
    self.gmem_index = gmem_index
    self.metadata = metadata
    return fx
end

-- Discover the Reaticulate FX on the given track.  Sets the fx attribute to the fx id if
-- valid, and returns true if the fx is detected to have changed (e.g. track changed or FX
-- became enabled) or false otherwise.
--
-- This function is called frequently (via rfx.sync())
function rfx.Track:presync(track, forced, unsubscribe)
    local last_track = self.track
    local last_fx = self.fx

    local track_changed = (track ~= last_track) or forced
    if unsubscribe and track_changed and last_track and last_fx then
        rfx.onunsubscribe()
        self:subscribe(rfx.SUBSCRIPTION_NONE)
    end

    self.track = track
    self.error = rfx.ERROR_NONE
    if not track then
        self.fx = nil
        return nil, track_changed, false
    end

    local candidate_fx = rfx.get(track)
    local fx = self:_sync_params(track, candidate_fx)
    -- Remember whether either the track changed or the RFX on the current track changed.
    track_changed = track_changed or (fx ~= self.fx)
    local metadata = self.metadata or 0
    local serial = metadata & 0xff;
    local serial_changed = self.serial ~= serial or track_changed
    self.serial = serial
    self.fx = fx
    local migrated = false
    if track_changed then
        -- banks_by_channel is now invalid, set to nil to ensure we detect if we've failed
        -- to regenerate it
        self.banks_by_channel = nil
        if candidate_fx and candidate_fx ~= -1 then
            -- We have found an RFX on the track.  It might not actually be valid
            -- (track could be disabled, FX bypassed, unsupported RFX version) but
            -- it's good enough for us bother trying to read appdata.
            self.appdata = self:_read_appdata()
        end
        if fx then
            -- This is a legit enabled RFX, so need to update banks_by_channel map
            if type(self.appdata) ~= 'table' or not self.appdata.banks then
                if self:get_param(self.params.banks_start) ~= 0 then
                    self:migrate_to_appdata()
                    migrated = true
                else
                    self:_init_appdata()
                end
            end
        end
    end
    return fx, track_changed, serial_changed, migrated
end

-- Discover Reaticulate JSFX (via presync()) on the given track and look for changes
-- relevant to the GUI, invoking the various on* callbacks as needed.
--
-- This function is called frequently (for each deferred cycle) so it needs to be as
-- efficient as possible for the common case of idling on a track.
function rfx.Track:sync(track, forced)
    local fx, track_changed, serial_changed, migrated = self:presync(track, forced, true)
    if not track or not fx then
        return track_changed
    end
    if track_changed then
        self:subscribe(rfx.SUBSCRIPTION_NOTES)-- | rfx.SUBSCRIPTION_CC)
        if self:index_banks_by_channel_and_check_hash() or migrated then
            -- In 0.4.0 we changed the way dirty detection was done (by moving from
            -- reabank version to the bank hash) so we just blindly resync if we've done a
            -- migration.
            log.info("rfx: resyncing banks due to hash mismatch")
            if self == rfx.current then
                rfx.onhashchange()
            end
            self:sync_banks_to_rfx()
        end
        rfx.onccchange()
        -- This is called on every track select, but it only actually sweeps the project
        -- every 30 seconds, and only then once we've burned around 1000 gmem ids.
        rfx.gc()
    end
    if serial_changed then
        local offset = self.gmem_index + rfx.GMEM_IIDX_INSTANCE_DATA
        local change_bitmap = reaper.gmem_read(offset)
        if change_bitmap > 0 then
            reaper.gmem_write(offset, 0)
        end
        if change_bitmap & (1 << 2) ~= 0 or track_changed then
            -- Indicates the offset for program data plus the number of slots (from which we can
            -- infer the number of groups, because it's 16 slots per group)
            local info = reaper.gmem_read(offset + 2)
            local programs_offset = info & 0xffff
            local len = info >> 16
            for channel = 1, 16 do
                for group = 1, len / 16 do
                    local program_offset = ((group - 1) * 16) + (channel - 1)
                    local program = reaper.gmem_read(offset + programs_offset + program_offset)
                    local last_program = self.programs[channel][group]
                    if (track_changed and program ~= NO_PROGRAM) or last_program ~= program then
                        rfx.onartchange(channel, group, last_program, program, track_changed)
                    end
                    self.programs[channel][group] = program
                end
            end
        end
        if change_bitmap & (1 << 1) ~= 0 then
            -- Sync active notes.
            local notes_offset = reaper.gmem_read(offset + 1) & 0xffff
            local last_notes = rfx.active_notes
            rfx.active_notes = reaper.gmem_read(offset + notes_offset)
            if rfx.active_notes ~= last_notes then
                rfx.onnoteschange(last_notes, rfx.active_notes)
            end
        end
        if change_bitmap & (1 << 3) ~= 0 then
            -- Handler can call get_cc_value() to fetch current values from gmem.
            rfx.onccchange()
        end
    end
    return track_changed
end

-- Returns true if the track has a valid and enabled RFX.
function rfx.Track:valid()
    return self.fx ~= nil
end

function rfx.Track:get_cc_value(cc)
    local offset = self.gmem_index + rfx.GMEM_IIDX_INSTANCE_DATA
    local cc_offset = reaper.gmem_read(offset + 3) & 0xffff
    return reaper.gmem_read(offset + cc_offset + cc)
end

function rfx.Track:_init_appdata()
    self.appdata = {
        v = 1,
        banks = {}
    }
    self:queue_write_appdata()
end

-- Migrates a pre-0.4 track in which banks mapped to the track are stored in FX parameters
-- to an appdata table where each bank is described as a "bankinfo" table.
--
-- In Reaticulate 0.4.x, appdata was serialized and stored in the RFX itself.  In 0.5,
-- we store appdata as track P_EXT data.  This method now migrates pre-0.4 FX parameters
-- directly to GUID bankinfo tables stored in P_EXT appdata.
--
-- Once the migration is complete, the FX parameters are zeroed out.
function rfx.Track:migrate_to_appdata()
    log.debug('migrating old RFX version to use appdata')
    if type(self.appdata) ~= 'table' then
        self.appdata = {v=1}
    end
    self.appdata.banks = {}
    for param = self.params.banks_start, self.params.banks_end do
        local b0, b1, b2, b3 = self:get_data(param)
        if b2 > 0 and b3 > 0 then
            local msblsb = (b2 << 8) | b3
            local bank = reabank.get_legacy_bank_by_msblsb(msblsb)
            if not bank then
                -- Legacy appdata references a bank by MSB/LSB that's not available on
                -- this system.  We can't migrate the appdata to GUID
                log.warning('unable to migrate unknown bank msb=%d lsb=%d', b2, b3)
            end
            local hash = bank and bank:hash() or nil
            -- All banks get GUIDs generated at parse time, so this assertion snould never
            -- fail except due to a bug.
            assert(not bank or bank.guid, 'BUG: bank does not have a GUID during migration to appdata')
            self.appdata.banks[#self.appdata.banks + 1] = {
                t = bank and 'g' or 'b',
                v = bank and bank.guid or msblsb,
                h = hash,
                src = b0 + 1,
                dst = b1 + 1,
                -- Older versions did not support custom output bus and assumed 1.
                dstbus = 1
            }
        end
    end
    -- Reset the bank parameters now that the banks have been migrated to
    -- appdata.
    reaper.Undo_BeginBlock2(0)
    self:_write_appdata()
    for param = self.params.banks_start, self.params.banks_end do
        self:set_param(param, 0)
    end
    reaper.Undo_EndBlock2(0, "Reaticulate: migrate track to new version (cannot be undone)", UNDO_STATE_FX)
end


-- Sets the default channel and syncs the channel selection with appdata.  The RFX is also
-- asked to sync CCs for the new channel to the gmem instance data region.
--
-- Channel number is offset from 1.
function rfx.Track:set_default_channel(channel)
    rfx.set_gmem_global_default_channel(channel)
    if self:valid() and channel ~= self.appdata.defchan then
        self:opcode(rfx.OPCODE_UPDATE_CURRENT_CCS)
        self.appdata.defchan = channel
        self:queue_write_appdata()
    end
end

-- Stores an error message in the track appdata.
function rfx.Track:set_error(error)
    if self:valid() and error ~= self.appdata.err then
        self.appdata.err = error
        self:queue_write_appdata()
    end
end

-- Sets the current list of banks on the track.
--
-- Argument is a table of banks where each bank is in the form {guid, srcchannel,
-- dstchannel, dstbus} and where channels are offset from 1.
--
-- The user-supplied list is translated to a list of tables as below before
-- storing to appdata:
--       t: type: u=uuid b=msb/lsb
--       v: val: uuid if type=u, msblsb if type=b
--       h: hash = of last Bank object
--     src: src channel (offset from 1, 17 = Omni)
--     dst: dst channel (offset from 1, 17 = Source)
--  dstbus: dst bus (offset from 1)
--      ud: user data (only set if present)
--
-- If this function returns true, it means sync_banks_to_rfx() needs to be invoked
-- by the caller.
function rfx.Track:set_banks(banks)
    self.appdata.banks = {}
    for _, bankinfo in ipairs(banks) do
        local guid, srcchannel, dstchannel, dstbus, bankname = table.unpack(bankinfo)
        assert(guid, 'bug: attempting to set invalid bank')
        -- Note that hash is not set here but rather in sync_banks_to_rfx() so that the
        -- current hash can be refreshed even if the bank assignment doesn't change for
        -- the track.
        self.appdata.banks[#self.appdata.banks + 1] = {
            -- If the given guid evaluates as a number (even though it's a string), then
            -- this in fact *isn't* a GUID, it's a legacy MSB/LSB that wasn't able to be
            -- migrated because it's missing from the current system.  In this case, we
            -- will need to continue to use the deprecated MSB/LSB bankinfo for this bank.
            t = tonumber(guid) and 'b' or 'g',
            v = guid,
            src = srcchannel,
            dst = dstchannel,
            dstbus = dstbus,
            name = bankname,
        }
    end
    return self:index_banks_by_channel_and_check_hash()
end

-- An iterator that yields a table containing bank information for each bank assigned to
-- this track.  Channel starts at 1, bank is a Bank object.
--
-- The returned table includes the following fields:
--   * idx: index within the rfx.Track.appdata.banks table the bank represents
--   * bank: reabank.Bank object if it exists for this bank (may be nil)
--   * guid: a shorthand for bank.guid -- will be nil if bank is nil
--   * type: 't' field from bankinfo indicating the internal type ('g' or 'b')
--   * srcchannel: source channel in track assignment, 17 = omni
--   * dstchannel: dst channel in track assignment, 17 = source
--   * dstbus: destination bus, offset from 1
--   * hash: last stored hash of the bank; may be different than bank:hash()
--   * userdata: caller-managed data -- though use get/set_bank_userdata() instead
--   * name: stored name of this bank (mainly for logging/UI purposes when not
--     installed on local system)
--   * v: the 'v' field from bankinfo indicating the internal bank value, which
--     may either be a guid or a packed MSB/LSB for legacy banks that couldn't
--     be migrated.
-- Banks with invalid bankinfo will be skipped over with a warning logged.  This
-- should never happen except through bugs, but we should be robust in this case
-- rather than fail.
--
-- If migrate is true, then rfx.GUIDMigrator is always instantiated and yielded
-- as the second element.  Used by App for project migration purposes.
function rfx.Track:get_banks(migrate)
    if not self.fx then
        -- RFX not loaded, so nothing to iterate over.
        return function() end
    end
    local idx = 1
    local migrator = migrate and rfx.GUIDMigrator(self)
    return function()
        if self:valid() and self.appdata.banks and idx <= #self.appdata.banks then
            local bankinfo = self.appdata.banks[idx]
            idx = idx + 1
            if bankinfo and bankinfo.v then
                local bank
                if bankinfo.t == 'g' then
                    -- If the bankinfo is GUID type then we don't need to use the migrator.
                    -- This still could return nil, if the GUID type bankinfo refers to a GUID
                    -- not available on this system, but at least we know it doesn't need to
                    -- be migrated.
                    bank = reabank.get_bank_by_guid(bankinfo.v)
                else
                    -- Non-GUID bankinfo that needs migration.  bankinfo.t is 'b' (MSB/LSB
                    -- packed in bankinfo.v) or it's the older prerelease 4-element table
                    -- format.
                    --
                    -- In most cases, non-GUID bankinfos will already have been migrated
                    -- via App:migrate_project_to_guid() when the project changes, but
                    -- this scenario can still happen for disabled tracks.
                    if not migrator then
                        migrator = rfx.GUIDMigrator(self)
                    end
                    -- May implicitly call migrator:add_bank_to_project()
                    bank = migrator:migrate_bankinfo(bankinfo)
                end
                return {
                    idx=idx-1,
                    bank=bank,
                    guid=bank and bank.guid,
                    type=bankinfo.t,
                    srcchannel=bankinfo.src,
                    dstchannel=bankinfo.dst,
                    dstbus=bankinfo.dstbus,
                    hash=bankinfo.h,
                    userdata=bankinfo.ud,
                    name=bankinfo.name,
                    v=bankinfo.v,
                }, migrator
                -- return idx-1, bank, bankinfo.src, bankinfo.dst, bankinfo.dstbus,
                --     bankinfo.h, bankinfo.ud, bank and bank.guid or bankinfo.v, bankinfo.name
            else
                log.warning('rfx: invalid bank found during get_banks(): %s', bankinfo and table.tostring(bankinfo))
            end
        else
            if migrator then
                migrator:remap_bank_select()
            end
        end
    end
end

local function _get_bank_appdata_record(self, bank)
    if not self:valid() or not self.appdata.banks then
        return nil
    end
    -- XXX: O(n) - may need a lookup table if this gets called a lot
    for n, bankdata in ipairs(self.appdata.banks) do
        local v = bankdata.t == 'g' and bank.guid or bank.msblsb
        if tostring(bankdata.v) == v then
            return bankdata
        end
    end
end

function rfx.Track:get_bank_userdata(bank, attr)
    local bankdata = _get_bank_appdata_record(self, bank)
    if bankdata and bankdata.ud then
        return bankdata.ud[attr]
    end
end

function rfx.Track:set_bank_userdata(bank, attr, value)
    local bankdata = _get_bank_appdata_record(self, bank)
    if not bankdata then
        log.error('bank %s not found in appdata', bank.name)
        return false
    end
    if not bankdata.ud then
        bankdata.ud = {[attr] = value}
    else
        bankdata.ud[attr] = value
    end
    self:queue_write_appdata()
    return true
end

function rfx.Track:get_banks_conflicts()
    if not self.fx then
        -- No RFX on this track, no conflicts by definition.
        return {}
    end
    -- Tracks program details where the key is 128 * channel + program
    local programs = {}
    local conflicts = {}
    for channel = 1, 16 do
        local first = nil
        local banks = self.banks_by_channel[channel]
        if banks then
            for _, bank in ipairs(banks) do
                local buses = 0
                for _, art in ipairs(bank.articulations) do
                    local idx = 128 * channel + art.program
                    -- Keep track of output events, because conflicting programs with the same output
                    -- events shouldn't count as conflicts.
                    --
                    -- FIXME: order shouldn't matter either, but this implementation requires same order.
                    local outputs = table.tostring(art:get_outputs())
                    buses = buses | art.buses
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
                bank.buses = buses
            end
        end
    end
    return conflicts
end


-- Constructs the banks_by_channel map based on current banks list stored in the
-- RFX.
--
-- Returns true if hashes have changed and sync_banks_to_rfx() needs to be
-- called, false if hashes haven't changed, and nil if rfx is invalid.
function rfx.Track:index_banks_by_channel_and_check_hash()
    if not self.fx then
        return
    end
    self.banks_by_channel = {}
    self.unknown_banks = nil
    -- Will be set to true if there are any bank hash mismatches
    local resync = false
    for b in self:get_banks() do
        local bank = b.bank
        if not bank then
            if not self.unknown_banks then
                self.unknown_banks = {}
            end
            self.unknown_banks[#self.unknown_banks+1] = b.guid
            log.warning("rfx: instance refers to undefined bank %s", b.guid)
        else
            log.debug("rfx: index bank=%s  hash=%s -> %s", bank.name, b.hash, bank:hash())
            bank.srcchannel = b.srcchannel
            bank.dstchannel = b.dstchannel
            bank.dstbus = b.dstbus
            if b.srcchannel == 17 then
                -- Omni: bank is available on all channels
                for src = 1, 16 do
                    local banks_list = self.banks_by_channel[src]
                    if not banks_list then
                        banks_list = {}
                        self.banks_by_channel[src] = banks_list
                    end
                    banks_list[#banks_list + 1] = bank
                end
            else
                local banks_list = self.banks_by_channel[b.srcchannel]
                if not banks_list then
                    banks_list = {}
                    self.banks_by_channel[b.srcchannel] = banks_list
                end
                banks_list[#banks_list + 1] = bank
            end
            if b.hash ~= bank:hash() then
                resync = true
            end
            if not app.project_state.msblsb_by_guid[bank.guid] then
                -- Track references a bank which is not currently part of the
                -- project, is add it now.
                reabank.add_bank_to_project(bank)
            end
        end
    end
    return resync
end

-- Called when bank list is changed.  This sends the articulation details for all current
-- banks in the bank list.
--
-- This function uses the banks_by_channel map, so index_banks_by_channel_and_check_hash()
-- must first have been called.
function rfx.Track:sync_banks_to_rfx()
    if not self.fx then
        return
    end
    if not self:valid() or not self.appdata.banks then
        -- This shouldn't happen.
        return log.error("rfx: unexpectedly no track appdata or banks")
    end

    assert(self.banks_by_channel, 'Called sync_banks_to_rfx() before calling index_banks_by_channel_and_check_hash()')

    log.time_start()
    reaper.Undo_BeginBlock2(0)
    rfx.push_state(self.track)
    self:opcode(rfx.OPCODE_CLEAR)

    for channel = 1, 16 do
        local banks = self.banks_by_channel[channel]
        if banks then
            for _, bank in ipairs(banks) do
                bank:realize()
                local param1 = (channel - 1) | (0 << 4) -- 0 is bank version
                local msb, lsb = bank:get_current_msb_lsb()
                self:opcode(rfx.OPCODE_NEW_BANK, {param1, msb, lsb})
                for _, cc in ipairs(bank:get_chase_cc_list()) do
                    self:opcode(rfx.OPCODE_SET_BANK_CHASE_CC, {cc})
                end
                for _, art in ipairs(bank.articulations) do
                    local version = 2
                    local group = art.group - 1
                    local outputs = art:get_outputs()
                    -- First nybble of param1 is source channel, while second is articulation record version.
                    local param1 = (channel - 1) | (version << 4)
                    self:opcode(rfx.OPCODE_NEW_ARTICULATION, {param1, art.program, group,
                                                             art.flags, art.off or bank.off or 128, 0})

                    -- Append extensions to the articulation before adding the output events.
                    if art:has_transforms() then
                        -- Add transform extension.
                        local transforms = art:get_transforms()
                        self:opcode(rfx.OPCODE_ADD_ARTICULATION_EXTENSION, {
                            -- Transform extension
                            0,
                            (transforms[1] + 128) | (math.floor(transforms[2] * 100) << 8),
                            transforms[3] | (transforms[4] << 8),
                            transforms[5] | (transforms[6] << 8)
                        })
                    end

                    for _, output in ipairs(outputs) do
                        local outchannel = output.channel or bank.dstchannel
                        local outbus = output.bus or bank.dstbus or 1
                        local param1 = tonumber(output.args[1] or 0)
                        local param2 = tonumber(output.args[2] or 0)
                        if not output.route then
                            -- Set bit 7 of param1 if this output event should not setup routing
                            param1 = param1 | 0x80
                        end
                        if outchannel == 17 then
                            outchannel = channel
                        elseif outchannel == 0 then
                            -- Route output event to channels set up by previous articulation.
                            param2 = param2 | 0x80
                            -- This option implies output.route == false
                            param1 = param1 | 0x80
                            -- outchannel and bus will be ignored by the RFX here, but set it to something
                            -- that ensures we don't try to bitshift a negative number below.
                            outchannel = 1
                            outbus = 1
                        end
                        if output.type == 'pitch' then
                            -- Convert 14-bit pitch value to MSB/LSB parameters.
                            param1 = math.max(-8192, math.min(8191, param1)) + 8192
                            param2 = (param1 >> 7) & 0x7f
                            param1 = param1 & 0x7f
                        end
                        -- The output event is considered to have an explicit channel if
                        -- either the output event itself defines a target channel or
                        -- the bank is assigned on the track to an explicit channel rather
                        -- than Source.  Likewise, the bus is considered to be explicit if
                        -- defined by the output event or on the track config > 1.
                        local haschannel = output.channel or bank.dstchannel ~= 17
                        local hasbus = output.bus or bank.dstbus ~= 1
                        local typechannel = (output_type_to_rfx_param[output.type] or 0) |
                                            ((outchannel - 1) << 4) |
                                            ((outbus - 1) << 8) |
                                            ((haschannel and 1 or 0) << 12) |
                                            ((hasbus and 1 or 0) << 13)
                        self:opcode(rfx.OPCODE_ADD_OUTPUT_EVENT, {typechannel, param1, param2})
                        if output.filter_program then
                            -- Filter program is set: add output event extension 0.
                            self:opcode(rfx.OPCODE_ADD_OUTPUT_EVENT_EXTENSION, {0, output.filter_program | 0x80})
                        end
                    end
                end
            end
        end
    end

    self:opcode(rfx.OPCODE_FINALIZE_ARTICULATIONS)
    -- Update the hash of all banks
    for b in self:get_banks() do
        self.appdata.banks[b.idx].h = b.bank and b.bank:hash() or nil
    end
    self:_write_appdata()

    rfx.pop_state()
    reaper.Undo_EndBlock2(0, "Reaticulate: update track banks (cannot be undone)", UNDO_STATE_FX)
    log.info("rfx: sync articulations done")
    log.time_end()
end

-- Checks all banks on this track and resyncs the banks to RFX if any of their hashes
-- have changed.
--
-- Returns true if any hash changed and a resync was done, false otherwise.
function rfx.Track:sync_banks_if_hash_changed()
    if not self.track then
        return false
    end
    -- This is optimized under the assumption that most tracks won't need to be synced,
    -- because for those that do, we loop over banks here, and then again via the
    -- call to index_banks_by_channel_and_check_hash() if the hash changed.
    local changed = false
    for b in self:get_banks() do
        -- bank may be nil for bank references not found on current system
        if b.bank and b.hash ~= b.bank:hash() then
            changed = true
            break
        end
    end
    if changed then
        if not self.banks_by_channel then
            self:index_banks_by_channel_and_check_hash()
        end
        self:sync_banks_to_rfx()
        if self == rfx.current then
            rfx.onhashchange()
        end
    end
end

-- Clears the current program for the given channel.  Channel and group
-- are offset from 1.
function rfx.Track:clear_channel_program(channel, group)
    self:opcode(rfx.OPCODE_CLEAR_ARTICULATION, {channel - 1, group - 1})
end

function rfx.Track:activate_articulation(channel, program, flags)
    self:opcode(rfx.OPCODE_ACTIVATE_ARTICULATION, {channel, program, flags or 0})
end

function rfx.Track:subscribe(subscription, track, fx)
    self:opcode(rfx.OPCODE_SUBSCRIBE, {subscription})
end

-- Reads userdata from a media item.  If no userdata currently exists in the item then an
-- empty table is returned.
--
-- This isn't managed by the RFX strictly speaking but as a convenience function it seems
-- reasonable to put in rfx.Track.
function rfx.Track:get_item_userdata(item)
    local ok, data = reaper.GetSetMediaItemInfo_String(item, 'P_EXT:reaticulate', '', false)
    if not ok then
        return {}
    end
    local ok, decoded = pcall(json.decode, data)
    return ok and type(decoded) == 'table' and decoded or {}
end

-- Stores a table as userdata in the given media item.  Not strictly handled by the RFX,
-- but the approach is the same as track data.
function rfx.Track:set_item_userdata(item, itemdata)
    local encoded = json.encode(itemdata)
    reaper.GetSetMediaItemInfo_String(item, 'P_EXT:reaticulate', encoded, true)
end

-- Sets a specific key in the media item's userdata.
function rfx.Track:set_item_userdata_key(item, key, value)
    local itemdata = self:get_item_userdata(item)
    itemdata[key] = value
    self:set_item_userdata(item, itemdata)
end


-- Lower level functions

-- Asynchronously invoke an RFX API via an "operation code" and a variable
-- number of 32-bit parameters.  The invocation can be made synchronous via
-- rfx.opcode_flush()
--
-- This interface is a well-defined API between the main script and the
-- Reaticulate JSFX.  There are opcodes to both control current behaviour as
-- well as program how the RFX responds to articulation changes.
--
-- Opcodes are in the above OPCODE_* constants and each takes 0 or more 32-bit
-- integer parameters, where the meaning of the parameters varies by opcode.
--
-- This works by appending the opcode and parameters to the opcode region of the
-- RFX instance's gmem buffer.  Slot 0 contains the length of all *committed*
-- opcodes plus parameters, after which point further opcodes may not enqueued
-- until processed by the RFX. Slot 1 contains the length of uncommitted queued
-- opcodes.  From slot 2 onward, each group of 1+n slots represents the opcode
-- and its n parameters.
--
-- If the opcode region of the gmem buffer is full, a flush will be forced.
-- Similarly, if there are committed opcodes, we will force a flush before
-- enqueuing the new one.  A flush is accomplished by setting an FX parameter on
-- the RFX, which causes it to synchronously process all committed queued
-- opcodes (via @slider), allowing us to safely enqueue more.  See the comment
-- below for more details.
--
-- Enqueued opcodes will not generate undo, but if a flush is forced because of
-- one of the conditions mentioned above, then an undo point *may* be generated.
-- (It's not clear when or why this happens sometimes and not others.)

function rfx.Track:opcode(opcode, args)
    return rfx.opcode(opcode, args, self.track, self.fx, self.gmem_index, self.params.opcode)
end


function rfx.Track:opcode_flush()
    if self.track and self.fx then
        rfx.opcode_flush(self.track, self.fx, self.gmem_index, self.params.opcode)
    end
end


function rfx.Track:queue_write_appdata()
    -- Pass nil for fx as we don't need to communicate with the RFX for appdata.
    rfx._queue_commit(self.track, nil, self.appdata, self.gmem_index)
end

-- Immediately writes appdata
function rfx.Track:_write_appdata(appdata)
    rfx._write_appdata(self.track, appdata or self.appdata)
end

-- Reads the appdata table previously stored with rfx._write_appdata()
--
-- As of Reaticulate 0.5, userdata is stored using native track extension-specific state.
-- Prior versions stored userdata in the RFX and was automatically written to the gmem
-- buffer when a gmem_index is assigned to the RFX.
function rfx.Track:_read_appdata()
    if not self.track then
        return nil
    end
    -- First try the native track data approach.
    local r, data = reaper.GetSetMediaTrackInfo_String(self.track, 'P_EXT:reaticulate', '', false)
    if r then
        local version = data:sub(1, 1)
        if version == '2' then
            log.debug('rfx: deserialize new appdata ver=%s: %s', version, data)
            local ok, decoded = pcall(json.decode, data:sub(2))
            if ok then
                return decoded
            end
        else
            log.error("rfx: could not understand stored Reaticulate FX data (serialization version %s)", version)
            return nil
        end
    end

    -- No native track userdata.  Check the JSFX for 0.4.0 style data and migrate.
    if not self.fx then
        -- Unlike the native approach above, we need the JSFX for this.
        return nil
    end
    local t0 = reaper.time_precise()
    local offset = self.gmem_index + rfx.GMEM_IIDX_APP_DATA
    local ok
    local appdata = nil
    local version = reaper.gmem_read(offset + 0)
    log.debug("rfx: read appdata version=%s from offset=%s", version, offset)
    if version == 1 then
        local strlen = reaper.gmem_read(offset + 1)
        local bytes = {}
        for i = 1, strlen, 3 do
            local packed = reaper.gmem_read(offset + 3 + (i-1)/3)
            bytes[#bytes+1] = string.char(packed & 0xff)
            bytes[#bytes+1] = string.char((packed >> 8) & 0xff)
            bytes[#bytes+1] = string.char((packed >> 16) & 0xff)
        end
        local str = table.concat(bytes, '', 1, strlen)

        ok, appdata = pcall(binser.deserialize, str)
        local t1 = reaper.time_precise()
        if not ok then
            log.error("rfx: deserialization of %s bytes failed: %s", #str, appdata)
            return nil
        end
        log.debug("rfx: deserialize ver=%s from %s took: %s", version, offset, t1-t0, version)
        -- Use logf so we don't incur the cost of table.tostring() when not debugging.
        log.logf(log.DEBUG2, "rfx: resulting data: sz=%s   %s\n",
            function() return strlen, table.tostring(appdata) end
        )

        -- Migrate to native track data.
        log.info('rfx: migrating appdata to native track extension data')
        self:_write_appdata(appdata[1])
        -- Clear JSFX appdata
        reaper.gmem_write(offset + 1, 0)
        reaper.gmem_write(offset + 2, 0)
        self:opcode(rfx.OPCODE_SET_APPDATA)
        return appdata[1]
    else
        log.error("rfx: could not understand rfx stored data (serialization version %s)", version)
    end

    return appdata
end


--
-- DEPRECATED
--
-- Below are legacy functions used for migration purposes
--

function rfx.Track:get_param(param)
    if self.track and self.fx then
        local r, _, _ = reaper.TrackFX_GetParam(self.track, self.fx, param)
        if r >= 0 then
            return math.floor(r) & 0xffffffff
        end
    end
    return nil
end


function rfx.Track:set_param(param, value)
    if self.track and self.fx then
        return reaper.TrackFX_SetParam(self.track, self.fx, param, value or 0)
    end
    return false
end

function rfx.Track:get_data(param)
    local r = self:get_param(param)
    if r then
        local b0, b1, b2 = r & 0xff, (r & 0xff00) >> 8, (r & 0xff0000) >> 16
        local b3 = (r & 0x7f000000) >> 24
        return b0, b1, b2, b3
    else
        return nil, nil, nil, nil
    end
end



return rfx
