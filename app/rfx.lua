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

local log = require 'lib.log'
local binser = require 'lib.binser'
local reabank = require 'reabank'

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
    GMEM_GIDX_RFX_OFFSET = 5,
    GMEM_GIDX_RFX_STRIDE = 6,

    -- Holds the value of GMEM_IIDX_OPCODES so the RFX knows where to read
    GMEM_GIDX_OPCODES_OFFSET = 20,
    -- Holds the value of GMEM_IIDX_APP_DATA so the RFX knows where to read/write
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
    GMEM_IIDX_APP_DATA = 1000,
    -- Slot (relative to gmem_index) that holds data the instance is communicating
    -- back to us, such as current selected programs or active notes.
    GMEM_IIDX_INSTANCE_DATA = 2000,

    -- The available number of slots for opcodes (GMEM_IIDX_INSTANCE_DATA - GMEM_IDX_APP_DATA)
    GMEM_OPCODES_BUFFER_SIZE = 1000 - 100,
    -- Available number of slots for app data
    GMEM_APP_DATA_BUFFER_SIZE = 2000 - 1000,

    -- Constants for the rfx.error value.
    ERROR_NONE = nil,
    -- These are critical errors that will be set when rfx.fx == nil
    ERROR_MISSING_RFX = 1,
    ERROR_TRACK_FX_BYPASSED = 2,
    ERROR_RFX_BYPASSED = 3,
    ERROR_BAD_MAGIC = 4,
    ERROR_UNSUPPORTED_VERSION = 5,
    ERROR_DESERIALIZATION_FAILED = 6,


    -- These are non-critical application level errors that can occur even when
    -- rfx.fx is valid, and usually indicate some possible issue with
    -- functionality.  This will be set via rfx.set_error(), in which case it is
    -- persisted in rfx appdata as rfx.appdata.err and restored when the track
    -- is selected.
    --
    -- These should be listed in ascending order of severity as when there are
    -- multiple errors on a bank, the highest will be used.
    ERROR_DUPLICATE_BANK = 1,
    ERROR_BUS_CONFLICT = 2,
    ERROR_PROGRAM_CONFLICT = 3,
    ERROR_UNKNOWN_BANK = 4,


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

    -- The current track (set via rfx.sync())
    track = nil,
    -- Reaper FX id of the Reaticulate FX on current track, or nil if
    -- no valid one was found.
    fx = nil,
    -- If not nil, then is one of the ERROR constants above.  If this is set
    -- then fx must be nil.
    error = nil,
    -- Metadata field of current RFX, which contains the byte-packed values for
    -- magic, version and change serial.
    metadata = nil,

    -- Version of the RFX instance (relevant iff fx isn't nil). Parsed from metadata.
    version = nil,
    -- The current change serial of the RFX.  When this changes without the track
    -- changing, then something about the RFX has changed and we consult slot 0 of
    -- the instance app data.  Parsed from metadata.
    serial = nil,
    -- The Reabank version that was used to build the MIDI channel control data.
    -- Parsed from metadata.
    reabank_version = nil,
    -- One of the params_by_version tables above, per the current RFX version
    params = nil,
    -- Application data stored in the RFX
    appdata = nil,
    -- If not nil, is a list of banks referenced by the RFX but not available.
    unknown_banks = nil,

    -- gmem shared buffer index for this RFX.
    gmem_index = 0,

    -- If not nil, it's a map of gmem_index -> {track, fx, appdata} representing
    -- the RFX instances that have queued opcodes that need to be committed and,
    -- if not nil, the appdata which should be stored during commit.  These are
    -- committed via rfx.opcode_commit_all().
    rfx_awaiting_commit = nil,

    -- Current program numbers on this track indexed by MIDI channel and sub-indexed
    -- by group. Initialized in init()
    programs = {},
    -- Maps channel number to list of Bank objects for current track.  If the Bank objects
    -- are regenerated (e.g. because reabank.refresh() is called) then this table must be
    -- regenerated via rfx.index_banks_by_channel()
    banks_by_channel = {},
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

function rfx.init()
    reaper.gmem_attach('reaticulate')
    rfx.global_serial = os.time()
    reaper.gmem_write(rfx.GMEM_GIDX_SERIAL, rfx.global_serial)
    reaper.gmem_write(rfx.GMEM_GIDX_ID_BITMAP_OFFSET, rfx.GMEM_ID_BITMAP_OFFSET)
    reaper.gmem_write(rfx.GMEM_GIDX_RFX_OFFSET, rfx.GMEM_RFX_OFFSET)
    reaper.gmem_write(rfx.GMEM_GIDX_RFX_STRIDE, rfx.GMEM_RFX_STRIDE)
    reaper.gmem_write(rfx.GMEM_GIDX_OPCODES_OFFSET, rfx.GMEM_IIDX_OPCODES)
    reaper.gmem_write(rfx.GMEM_GIDX_APP_DATA_OFFSET, rfx.GMEM_IIDX_APP_DATA)
    reaper.gmem_write(rfx.GMEM_GIDX_INSTANCE_DATA_OFFSET, rfx.GMEM_IIDX_INSTANCE_DATA)
    reaper.gmem_write(rfx.GMEM_GIDX_SUBSCRIPTION_OFFSET, rfx.GMEM_IIDX_INSTANCE_DATA_SUBSCRIPTION)

    -- Now that all global gmem parameters have been initialized, write the version and
    -- magic. RFX instances will watch for version changes and reassign gmem index
    -- if changed, provided the magic is present.
    reaper.gmem_write(rfx.GMEM_GIDX_VERSION, rfx.GMEM_VERSION)
    reaper.gmem_write(rfx.GMEM_GIDX_MAGIC, rfx.GMEM_MAGIC)

    for channel = 1, 16 do
        rfx.programs[channel] = {NO_PROGRAM, NO_PROGRAM, NO_PROGRAM, NO_PROGRAM}
    end

    -- rfx.params_by_version[2] = rfx.params_by_version[1]
end

function rfx.get(track)
    return reaper.TrackFX_GetByName(track, "Reaticulate", false)
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
function rfx.gc()
    -- Because this function involves enumerating every track across every
    -- loaded project, it's not exactly cheap.  So we only bother doing this
    -- when we have ~1000 gmem ids already allocated (offset 30).
    --
    -- Mask low 32-bits before comparison because gmem_read() returns a 64-bit
    -- value on 64-bit architectures.
    if reaper.gmem_read(rfx.GMEM_ID_BITMAP_OFFSET + 30) & 0xffffffff ~= 0xffffffff then
        -- Not under enough pressure yet to bother
        return
    end
    local now = os.clock()
    if now - rfx.last_gmem_gc_time < 30 then
        -- Don't do this more than once per 30 seconds.
        return
    end
    rfx.last_gmem_gc_time = now

    log.time_start()
    -- Iterate through all projects and tracks and determine the RFX instance ids
    -- for all valid RFX.  Create a set of 100 32-bit bitmaps according to what
    -- is expected to be in the gmem id bitmap slots based on the current RFX.
    slots = {}
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
        if bitmap == 0xffffffff and slots[i] ~= 0xffffffff then
            log.debug('rfx: gc slot %d: %x != %x', i, bitmap, slots[i] or 0)
            reaper.gmem_write(rfx.GMEM_ID_BITMAP_OFFSET + i, slots[i] or 0)
        end
        if bitmap ~= 0 then
            log.debug2('slot %d: %x -> %x', i, bitmap, slots[i] or 0)
        end
    end
    log.debug('rfx: gc complete')
    log.time_end()
end

-- Discover the Reaticulate FX on the given track.  Sets rfx.fx to the fx id if valid, and returns
-- true if the fx is detected to have changed (e.g. track changed or FX became enabled) or false
-- otherwise.
--
-- This function is called frequently (for each deferred cycle) so it needs to be as efficient as
-- possible for the common case of idling on a track.
function rfx.sync(track, forced)
    local last_track = rfx.track
    local last_fx = rfx.fx

    local track_changed = (track ~= last_track) or forced
    if track_changed and last_track and last_fx then
        rfx.subscribe(rfx.SUBSCRIPTION_NONE)
    end

    rfx.track = track
    rfx.error = rfx.ERROR_NONE
    if not track then
        rfx.fx = nil
        return track_changed
    end

    local fx = rfx._sync_params(track, rfx.get(track))
    track_changed = track_changed or (fx ~= rfx.fx)
    local metadata = rfx.metadata or 0
    local serial = metadata & 0xff;
    local serial_changed = rfx.serial ~= serial or track_changed
    rfx.serial = serial
    rfx.fx = fx
    -- Remember whether either the track changed or the RFX on the
    -- current track changed.
    if not fx then
        return track_changed
    end
    if track_changed then
        local migrated = false
        rfx.subscribe(rfx.SUBSCRIPTION_NOTES) -- | rfx.SUBSCRIPTION_CC)
        -- Track changed, need to update banks_by_channel map
        rfx.reabank_version = (rfx.metadata >> 8) & 0xff
        rfx.appdata = rfx._read_appdata()
        -- FIXME: there *may* be a race on JSFX instantiation where magic is set
        -- before appdata is.  This means appdata will be nil and will cause us
        -- to initialize/migrate even if there was existing appdata.
        if type(rfx.appdata) ~= 'table' or not rfx.appdata.banks then
            if rfx.get_param(rfx.params.banks_start) ~= 0 then
                rfx._migrate_to_appdata()
                -- Ensure we call sync_banks_to_rfx() just below.  In 0.4.0 we changed the
                -- way dirty detection was done (by moving from reabank version to the
                -- bank hash) so we just blindly resync if we've done a migration.
                migrated = true
            else
                rfx._init_appdata()
            end
        end
        if rfx.index_banks_by_channel() or migrated then
            log.info("rfx: resyncing banks due to hash mismatch")
            rfx.onhashchange()
            rfx.sync_banks_to_rfx()
        end
        rfx.onccchange()
        rfx.gc()
    end
    if serial_changed then
        local offset = rfx.get_gmem_index(track, fx, rfx.GMEM_IIDX_INSTANCE_DATA)
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
                    local last_program = rfx.programs[channel][group]
                    if (track_changed and program ~= NO_PROGRAM) or last_program ~= program then
                        rfx.onartchange(channel, group, last_program, program, track_changed)
                    end
                    rfx.programs[channel][group] = program
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
            local cc_offset = reaper.gmem_read(offset + 3) & 0xffff
            local v = reaper.gmem_read(offset + cc_offset + 1)
            rfx.onccchange()
        end
    end
    return track_changed
end

function rfx.get_cc_value(cc)
    local offset = rfx.get_gmem_index(track, fx, rfx.GMEM_IIDX_INSTANCE_DATA)
    local cc_offset = reaper.gmem_read(offset + 3) & 0xffff
    return reaper.gmem_read(offset + cc_offset + cc)
end

-- Validates the given fx and (if valid) sets the rfx table attributes according to the RFX
-- instance.  If the RFX's gmem_index hasn't been set then allocate it now.
--
-- Returns the fx if valid, and nil otherwise in which case rfx.error will be set.
--
-- This function is called frequently (via rfx.sync())
function rfx._sync_params(track, fx)
    local fx, metadata, version, params, gmem_index, error = rfx.validate(track, fx)
    if error then
        rfx.error = error
        return nil
    end
    if version ~= rfx.version then
        rfx.version = version
        rfx.params = params
    end
    rfx.gmem_index = gmem_index
    rfx.metadata = metadata
    return fx
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
    if not reaper.TrackFX_GetEnabled(track, fx) then
        return nil, nil, nil, nil, nil, rfx.ERROR_RFX_BYPASSED
    end

    local metadata = math.floor(r)
    local magic = metadata & 0xff000000
    if magic ~= rfx.MAGIC then
        return nil, nil, nil, nil, nil, rfx.ERROR_BAD_MAGIC
    end

    local version = (metadata & 0x00ff0000) >> 16

    local params = rfx.params
    if version ~= rfx.version then
        -- Params is different than currently cached one, so look it up.
        params = rfx.params_by_version[version]
        if params == nil then
            return nil, nil, nil, nil, nil, rfx.ERROR_UNSUPPORTED_VERSION
        end
    end
    local gmem_index, _, _ = reaper.TrackFX_GetParam(track, fx, params.gmem_index)
    if gmem_index == 0 then
        -- TODO: it's possible we just initialized the global gmem params, so
        -- bump the opcode param to force the rfx to gmem_alloc() inside @slider
        -- and then try fetching again.  But meanwhile, it's not the end of the
        -- world if we wait until the next cycle, we'll just get a bit of a flicker.
        log.warn("rfx: instance missing gmem_index")
        return nil, nil, nil, nil, nil, rfx.ERROR_MISSING_RFX
    end
    return fx, metadata, version, params, gmem_index, nil
end

function rfx._init_appdata()
    rfx.appdata = {
        v = 1,
        banks = {}
    }
    rfx.queue_write_appdata()
end


function rfx._migrate_to_appdata()
    log.debug('migrating old RFX version to use appdata')
    if type(rfx.appdata) ~= 'table' then
        rfx.appdata = {v=1}
    end
    rfx.appdata.banks = {}
    for param = rfx.params.banks_start, rfx.params.banks_end do
        local b0, b1, b2, b3 = rfx.get_data(param)
        if b2 > 0 and b3 > 0 then
            local msblsb = (b2 << 8) | b3
            local bank = reabank.get_bank_by_msblsb(msblsb)
            if not bank then
                log.warn('unable to migrate unknown bank msb=%d lsb=%d', b2, b3)
            end
            local hash = bank and bank:hash() or nil
            rfx.appdata.banks[#rfx.appdata.banks + 1] = {
                t = 'b',
                v = msblsb,
                h = hash,
                src = b0 + 1,
                dst = b1 + 1,
                -- Older versions did not support custom output bus and assumed 1.
                dstbus = 1
            }
        end
    end
    rfx.queue_write_appdata()

    -- Reset the bank parameters now that the banks have been migrated to
    -- appdata.
    for param = rfx.params.banks_start, rfx.params.banks_end do
        rfx.set_param(param, 0)
    end
end



function rfx.get_gmem_index(track, fx, offset)
    if not rfx.params then
        return
    end
    local idx = rfx.gmem_index
    if fx and track and (rfx.track ~= track or rfx.fx ~= fx) then
        -- RFX explicitly passed.  Discover offset from that.
        idx, _, _ = reaper.TrackFX_GetParam(track, fx, rfx.params.gmem_index)
    end
    if idx <= 0 then
        return nil
    else
        return idx + (offset or 0)
    end
end

function rfx.set_default_channel(channel)
    reaper.gmem_write(rfx.GMEM_GIDX_DEFAULT_CHANNEL, channel - 1)
    if rfx.fx then
        rfx.opcode(rfx.OPCODE_UPDATE_CURRENT_CCS)
    end
end

function rfx.set_error(error)
    if rfx.appdata and error ~= rfx.appdata.err then
        rfx.appdata.err = error
        rfx.queue_write_appdata()
    end
end

-- Sets the current list of banks on the track.
--
-- Argument is a table of banks in the form {msblsb, srcchannel, dstchannel} where
-- channels start at 1.
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

function rfx.set_banks(banks)
    rfx.appdata.banks = {}
    for _, bankinfo in ipairs(banks) do
        msblsb, src, dstchannel, dstbus = table.unpack(bankinfo)
        -- Note that hash is not set here but rather in sync_banks_to_rfx()
        -- so that the current hash can be refreshed even if the bank assignment
        -- doesn't change for the track.
        rfx.appdata.banks[#rfx.appdata.banks + 1] = {
            t = 'b',
            v = msblsb,
            src = src,
            dst = dstchannel,
            dstbus = dstbus
        }
    end
    -- This will implicitly call rfx.sync_banks_to_rfx() if necessary.
    return rfx.index_banks_by_channel()
end


-- An iterator that yields (idx, bank, srcchannel, dstchannel, hash, userdata, msblsb)
-- for each bank assigned to this track.  Channel starts at 1, bank is a Bank
-- object.
--
-- hash is the bank's hash at the time of set_banks(), which *could* be
-- different than the Bank object's current hash.  If the caller wishes to do
-- something about a hash inconsistency, it can resyn
function rfx.get_banks()
    if not rfx.fx then
        -- RFX not loaded, so nothing to iterate over.
        return function() end
    end
    local idx = 1
    return function()
        if rfx.appdata and rfx.appdata.banks and idx <= #rfx.appdata.banks then
            local bankinfo = rfx.appdata.banks[idx]
            local bank = reabank.get_bank_by_msblsb(bankinfo.v)
            idx = idx + 1
            -- The main point of also including idx is to ensure that we don't yield
            -- nil as the first value if bank could not be found, which would terminate
            -- the iterator.
            return idx-1, bank, bankinfo.src, bankinfo.dst, bankinfo.dstbus,
                   bankinfo.h, bankinfo.ud, bankinfo.v
        end
    end
end

local function _get_bank_appdata_record(bank)
    if not rfx.appdata or not rfx.appdata.banks then
        return nil
    end
    -- XXX: O(n) - may need a lookup table if this gets called a lot
    for n, bankdata in ipairs(rfx.appdata.banks) do
        if tostring(bankdata.v) == tostring(bank.msblsb) then
            return bankdata
        end
    end
end

function rfx.get_bank_userdata(bank, attr)
    local bankdata = _get_bank_appdata_record(bank)
    if bankdata and bankdata.ud then
        return bankdata.ud[attr]
    end
end

function rfx.set_bank_userdata(bank, attr, value)
    local bankdata = _get_bank_appdata_record(bank)
    if not bankdata then
        log.error('bank %s not found in appdata', bank.name)
        return false
    end
    if not bankdata.ud then
        bankdata.ud = {[attr] = value}
    else
        bankdata.ud[attr] = value
    end
    rfx.queue_write_appdata()
    return true
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


-- Constructs the rfx.banks_by_channel map based on current banks list stored in
-- the RFX.
--
-- Returns true if hashes have changed and rfx.sync_banks_to_rfx() needs to be
-- called, false if hashes haven't changed, and nil if rfx is invalid.
function rfx.index_banks_by_channel()
    if not rfx.fx then
        return
    end
    rfx.banks_by_channel = {}
    rfx.unknown_banks = nil
    -- Will be set to true if there are any bank hash mismatches
    local resync = false
    for _, bank, srcchannel, dstchannel, dstbus, hash, _, msblsb in rfx.get_banks() do
        if not bank then
            if not rfx.unknown_banks then
                rfx.unknown_banks = {}
            end
            -- TODO: should pass (TBD) uuid instead of msblsb
            rfx.unknown_banks[#rfx.unknown_banks+1] = msblsb
            log.warn("rfx: instance refers to undefined bank %s", msblsb)
        else
            log.debug("rfx: bank=%s  hash: %s vs. %s", bank.name, hash, bank:hash())
            bank.srcchannel = srcchannel
            bank.dstchannel = dstchannel
            bank.dstbus = dstbus
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
            if hash ~= bank:hash() then
                resync = true
            end
        end
    end
    return resync
end

-- Called when bank list is changed.  This sends the articulation details for all current
-- banks in the bank list.
-- TODO: will eventually need something like this that can sync all tracks in the project.
function rfx.sync_banks_to_rfx()
    if not rfx.fx then
        return
    end
    if not rfx.appdata or not rfx.appdata.banks then
        -- This shouldn't happen.
        return log.error("rfx: unexpectedly no track appdata or banks")
    end

    log.time_start()
    reaper.Undo_BeginBlock2(0)
    rfx.push_state(rfx.track)
    rfx.opcode(rfx.OPCODE_CLEAR)

    for channel = 1, 16 do
        local banks = rfx.banks_by_channel[channel]
        if banks then
            for _, bank in ipairs(banks) do
                bank:realize()
                local param1 = (channel - 1) | (0 << 4) -- 0 is bank version
                rfx.opcode(rfx.OPCODE_NEW_BANK, {param1, bank.msb, bank.lsb})
                for _, cc in ipairs(bank:get_chase_cc_list()) do
                    rfx.opcode(rfx.OPCODE_SET_BANK_CHASE_CC, {cc})
                end
                for _, art in ipairs(bank.articulations) do
                    local version = 2
                    local group = art.group - 1
                    local outputs = art:get_outputs()
                    -- First nybble of param1 is source channel, while second is articulation record version.
                    local param1 = (channel - 1) | (version << 4)
                    rfx.opcode(rfx.OPCODE_NEW_ARTICULATION, {param1, art.program, group,
                                                             art.flags, art.off or bank.off or 128, 0})

                    -- Append extensions to the articulation before adding the output events.
                    if art:has_transforms() then
                        -- Add transform extension.
                        local transforms = art:get_transforms()
                        rfx.opcode(rfx.OPCODE_ADD_ARTICULATION_EXTENSION, {
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
                        rfx.opcode(rfx.OPCODE_ADD_OUTPUT_EVENT, {typechannel, param1, param2})
                        if output.filter_program then
                            -- Filter program is set: add output event extension 0.
                            rfx.opcode(rfx.OPCODE_ADD_OUTPUT_EVENT_EXTENSION, {0, output.filter_program | 0x80})
                        end
                    end
                end
            end
        end
    end

    rfx.opcode(rfx.OPCODE_FINALIZE_ARTICULATIONS)
    -- Update the hash of all banks
    for i, bank, _, _, _, userdata in rfx.get_banks() do
        rfx.appdata.banks[i].h = bank and bank:hash() or nil
    end
    rfx.queue_write_appdata()

    rfx.pop_state()
    reaper.Undo_EndBlock2(0, "Reaticulate: update track banks (cannot be undone)", UNDO_STATE_FX)
    log.info("rfx: sync articulations done")
    log.time_end()
end

-- Clears the current program for the given channel.  Channel and group
-- are offset from 1.
function rfx.clear_channel_program(channel, group)
    rfx.opcode(rfx.OPCODE_CLEAR_ARTICULATION, {channel - 1, group - 1})
end

function rfx.activate_articulation(channel, program, flags)
    rfx.opcode(rfx.OPCODE_ACTIVATE_ARTICULATION, {channel, program, flags or 0})
end

function rfx.subscribe(subscription, track, fx)
    rfx.opcode(rfx.OPCODE_SUBSCRIBE, {subscription}, track, fx)
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
-- no-op (at least in that it does not leave side effects). function

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

function rfx.opcode(opcode, args, track, fx)
    local offset = rfx.get_gmem_index(track, fx, rfx.GMEM_IIDX_OPCODES)
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
        rfx.opcode_flush()
        log.warn("rfx: %s committed opcodes during enqueue, forced a flush", n_committed)
        log.trace(log.INFO)

        -- Sanity check that indeed the opcodes were synchronously executed by the RFX.
        n_committed = reaper.gmem_read(offset)
        if n_committed > 0 then
            -- This shouldn't happen.  It means the RFX didn't respond synchrously.
            -- The opcode is now lost.
            return log.fatal("rfx: opcode flush did not seem to work")
        end

    end
    -- Number of arguments
    local argc = args and #args or 0
    -- Check to see if the queue is full and needs to be flushed.
    local queue_size = reaper.gmem_read(offset + 1)

    if 2 + queue_size + 1 + argc >= rfx.GMEM_OPCODES_BUFFER_SIZE then
        -- The opcode queue gmem region is full, so we need to force the flush now.
        rfx.opcode_flush(track, fx, offset)
        queue_size = 0
    end

    -- Write the opcode and the provided arguments (if any) to the gmem buffer.
    local opidx = offset + 2 + queue_size
    reaper.gmem_write(opidx, opcode | (argc << 8))
    for i = 1, argc do
        reaper.gmem_write(opidx + i, args[i])
    end
    reaper.gmem_write(offset + 1, queue_size + 1 + argc)

    rfx._queue_commit(offset, track or rfx.track, fx or rfx.fx)
end

function rfx._queue_commit(offset, track, fx, appdata)
    offset = offset or rfx.get_gmem_index(track, fx, rfx.GMEM_IIDX_OPCODES)
    if rfx.rfx_awaiting_commit == nil then
        rfx.rfx_awaiting_commit = {[offset] = {track, fx, appdata}}
    else
        if rfx.rfx_awaiting_commit[offset] == nil then
            rfx.rfx_awaiting_commit[offset] = {track, fx, appdata}
        elseif appdata then
            rfx.rfx_awaiting_commit[offset][3] = appdata
        end
    end
end

function rfx.queue_write_appdata(track, fx, appdata)
    rfx._queue_commit(nil, track or rfx.track, fx or rfx.fx, appdata or rfx.appdata)
end

-- Commit previously enqueued opcodes to make them visible to the RFX. Commited
-- opcodes will be executed asynchronously at some unspecified time unless
-- rfx.opcode_flush() is called.
function rfx._opcode_commit(track, fx, offset)
    if offset == nil then
        offset = rfx.get_gmem_index(track, fx, rfx.GMEM_IIDX_OPCODES)
    end
    local n_buffered = reaper.gmem_read(offset + 1)
    reaper.gmem_write(offset + 1, 0)
    reaper.gmem_write(offset, n_buffered)
    rfx.rfx_awaiting_commit[offset] = nil
end

-- Commit all enqueued opcodes across all tracks.
function rfx.opcode_commit_all()
    if rfx.rfx_awaiting_commit ~= nil then
        for offset, trackfx in pairs(rfx.rfx_awaiting_commit) do
            if trackfx[3] then
                rfx._write_appdata(trackfx[1], trackfx[2], trackfx[3])
            end
            if reaper.ValidatePtr2(0, trackfx[1], "MediaTrack*") then
                rfx._opcode_commit(trackfx[1], trackfx[2], offset)
            end
        end
        rfx.rfx_awaiting_commit = nil
    end
end

-- Synchronously flushes all pending opcodes on the given track.  This generates
-- undo, so the caller is expected to wrap it in a begin/end undo block stanza
-- if applicable.
function rfx.opcode_flush(track, fx, offset)
    if rfx.rfx_awaiting_commit then
        rfx._opcode_commit(track, fx, offset)
    end
    rfx.push_state(track or rfx.track)
    reaper.TrackFX_SetParam(track or rfx.track, fx or rfx.fx, rfx.params.opcode, 42)
    rfx.pop_state()
end



-- Serialize and store the given appdata table in the RFX.
function rfx._write_appdata(track, fx, appdata)
    local str = binser.serialize(appdata)
    if #str > rfx.GMEM_APP_DATA_BUFFER_SIZE * 3 then
        -- We don't have enough room to store the app data.  This really shouldn't
        -- happen except in case of a bug, so log the critical error (which will
        -- cause the console to popup if it's not already visible) and bail.
        log.critical('rfx: instance app data exceeds allowable size (%s)', #str)
        return
    end
    local offset = rfx.get_gmem_index(track, fx, rfx.GMEM_IIDX_APP_DATA)
    -- serialization protocol version (may not ever be used but allocating in case)
    reaper.gmem_write(offset + 0, 1)
    -- Length of original serialized string
    reaper.gmem_write(offset + 1, #str)
    -- Number of slots used up in gmem buffer.
    reaper.gmem_write(offset + 2, math.ceil(#str / 3.0))
    for i = 1, #str, 3 do
        local b0, b1, b2 = str:byte(i, i + 3)
        local packed = (b0 or 0) + ((b1 or 0) << 8) + ((b2 or 0) << 16)
        reaper.gmem_write(offset + 3 + (i-1)/3, packed)
    end
    rfx.opcode(rfx.OPCODE_SET_APPDATA)
end


-- Reads the appdata table previously stored with rfx._write_appdata()
--
-- Userdata is automatically written to the gmem buffer when a gmem_index is
-- assigned to the RFX.  So no need to send an opcode, just read the buffer
-- right away.
function rfx._read_appdata()
    if not rfx.track or not rfx.fx then
        return nil
    end
    local t0 = os.clock()
    local offset = rfx.get_gmem_index(nil, nil, rfx.GMEM_IIDX_APP_DATA)
    local appdata = nil
    local version = reaper.gmem_read(offset + 0)
    log.debug("rfx: read version=%s from offset=%s", version, offset)
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

        status, appdata = pcall(binser.deserialize, str)
        local t1 = os.clock()
        if not status then
            log.error("rfx: deserialization of %s bytes failed: %s", #str, appdata)
            return nil
        end
        log.debug("rfx: deserialize ver=%s from %s took: %s", version, offset, t1-t0, version)
        log.debug2("rfx: resulting data: sz=%s   %s\n", strlen, table.tostring(appdata))
        return appdata[1]
    else
        log.error("rfx: could not understand rfx stored data (serialization version %s)", version)
    end

    return appdata
end


--
-- Functions to fetch data from FX parameters.
--
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

-- Legacy function used for migration purposes
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



return rfx
