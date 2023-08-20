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

require 'lib.utils'
require 'lib.crc64'
local rtk = require 'rtk'
local log = rtk.log

local reabank = {
    -- Used when user-configurable default is not provided.
    DEFAULT_CHASE_CCS = '1,2,11,64-69',

    reabank_filename_factory = nil,
    reabank_filename_user = nil,
    filename_tmp = nil,
    version = nil,
    -- Just the factory banks, indexed by guid
    banks_factory = nil,

    -- Maps bank guid to Bank object for both factory banks and user banks.
    --
    -- See reabank.get_bank_by_guid().
    banks_by_guid = {},
    -- LEGACY: mapping of packed MSB/LSB values to Bank object, *only* for legacy banks
    -- that define explicit MSB/LSB values.
    --
    -- This isn't necessarily going to be the MSB/LSB actually used for the bank, however.
    -- add_bank_to_project() will use this MSB/LSB if it's available, but in case it's
    -- already taken by another bank, will assign a different one.
    --
    -- See reabank.get_legacy_bank_by_msblsb().
    legacy_banks_by_msblsb = {},
    -- Maps fully qualified group/name to bank object specifically for handling clones.
    banks_by_path = {},
    -- If true, it means we currently have a deferred call awaiting for
    -- reabank._sync_project()
    project_sync_queued = false,
    -- Maps all MSB/LSB (stringified packed MSB/LSB to allow persistence) written to the
    -- last project reabank to the corresponding bank hashes. This is used by
    -- write_reabank_for_project() to determine if there were any changes to the existing
    -- tmp reabank.
    last_written_msblsb = nil,

    -- Cache for reabank.to_menu(), which
    menu = nil,

    -- Default articulation colors.
    default_colors = {
        ['default'] = '#666666',
        ['short'] = '#6c30c6',
        ['short-light'] = '#9630c6',
        ['short-dark'] = '#533bca',
        ['legato'] = '#218561',
        ['legato-dark'] = '#1c5e46',
        ['legato-light'] = '#49ba91',
        ['long'] = '#305fc6',
        ['long-light'] = '#4474e1',
        ['long-dark'] = '#2c4b94',
        ['textured'] = '#9909bd',
        ['fx'] = '#883333'
    },
    -- Predefined articulation color names are authoritative in app config,
    -- user-configurable in the settings page.  This table contains colors parsed from the
    -- reabank, which for predefined color names is now deprecated, but still applies to
    -- user-defined color names (though this is a little-used feature).
    --
    -- Table is updated by reabank.parse_colors()
    colors = {},
    textcolors = {
        ['default'] = '#ffffff'
    }
}



--------------------------------------------------------------
-- Articulation class
--------------------------------------------------------------
Articulation = rtk.class('Articulation')
Articulation.static.FLAG_CHASE = 1 << 0
Articulation.static.FLAG_ANTIHANG = 1 << 1
Articulation.static.FLAG_ANTIHANG_CC = 1 << 2
Articulation.static.FLAG_BLOCK_BANK_CHANGE = 1 << 3
Articulation.static.FLAG_TOGGLE = 1 << 4
Articulation.static.FLAG_HIDDEN = 1 << 5
Articulation.static.FLAG_IS_FILTER = 1 << 6


local function _parse_flags(flags, value)
    if not flags then
        return value
    end
    for _, flag in ipairs(flags:split(',')) do
        local negate = false
        local mask = 0
        if flag:startswith("!") then
            negate = true
            flag = flag:sub(2)
        end
        if flag == 'chase' then
            mask = Articulation.FLAG_CHASE
        elseif flag == 'antihang' then
            mask = Articulation.FLAG_ANTIHANG
        elseif flag == 'antihangcc' then
            mask = Articulation.FLAG_ANTIHANG_CC
        elseif flag == 'nobank' then
            mask = Articulation.FLAG_BLOCK_BANK_CHANGE
        elseif flag == 'toggle' then
            mask = Articulation.FLAG_TOGGLE
        elseif flag == 'hidden' then
            mask = Articulation.FLAG_HIDDEN
        end
        if negate then
            value = value & ~mask
        else
            value = value | mask
        end
    end
    return value
end


function Articulation:initialize(bank, program, name, attrs)
    self.color = 'default'
    -- 16-bit bitmap of channels this articulation is active on (on current track).
    -- This value is set by the main app layer on track change.
    self.channels = 0
    -- Store the bank guid instead of the bank itself to avoid the circular reference.
    self.bank_guid = bank.guid
    self.program = program
    self.name = name
    self._attrs = attrs
    -- True if any output event has a filter program, false otherwise, or nil if
    -- we don't know (because we haven't called get_outputs())
    self._has_conditional_output = nil
    table.merge(self, attrs)
    -- Coerce types of non-string properties
    self.group = tonumber(self.group or 1)
    self.spacer = tonumber(self.spacer)
    self.flags = _parse_flags(self.flags, bank.flags)
    -- 16-bit bitmap of buses that output events are specifically targeting.  Will
    -- be valid after get_outputs() is called.
    self.buses = nil
end

function Articulation:has_transforms()
    return self.velrange or self.pitchrange or self.transpose or self.velocity
end

-- Returns (transpose, velocity, min pitch, max pitch, min velocity, max velocity).
-- No-op defaults are returned if values are not specified in the articulation
-- definition (or if the values that *are* specified are invalid).
function Articulation:get_transforms()
    if self._transforms then
        return self._transforms
    end
    -- Defaults
    local transforms = {0, 1.0, 0, 127, 0, 127}
    if self.transpose then
        transforms[1] = tonumber(self.transpose) or 0
    end
    if self.velocity then
        transforms[2] = tonumber(self.velocity) or 1
    end
    if self.pitchrange then
        local min, max = self.pitchrange:match('(%d*)-?(%d*)')
        transforms[3] = tonumber(min) or 0
        transforms[4] = tonumber(max) or 127
    end
    if self.velrange then
        local min, max = self.velrange:match('(%d*)-?(%d*)')
        transforms[5] = tonumber(min) or 0
        transforms[6] = tonumber(max) or 127
    end
    self._transforms = transforms
    return transforms
end

function Articulation:get_outputs()
    if self._outputs then
        return self._outputs
    end

    self.buses = 0
    self._has_conditional_output = false
    self._outputs = {}
    for spec in (self.outputs or ''):gmatch('([^/]+)') do
        local output = {type=nil, channel=nil, args={}, route=true, filter_program=nil}
        for prefix, part in ('/' .. spec):gmatch('([/@:%%])([^@:%%]+)') do
            if prefix == '/' then
                if part:startswith('-') then
                    output.route = false
                    output.type = part:sub(2)
                else
                    output.type = part
                end
            elseif prefix == '@' then
                if part == '-' then
                    -- Use current routing for output event.
                    output.route = false
                    output.channel = 0
                    output.bus = 0
                else
                    if part:find('%.') then
                        local channel, bus = part:match('(%d*).(%d*)')
                        output.channel = tonumber(channel)
                        output.bus = tonumber(bus)
                        -- If bus is invalid, it will be nil which means we default
                        -- to the dst bus at the track level.
                        if output.bus then
                            self.buses = self.buses | (1 << (output.bus - 1))
                        end
                    else
                        output.channel = tonumber(part)
                        -- Default to the bus defined at the bank level when the
                        -- bank is mapped to a track
                        output.bus = nil
                    end
                end
            elseif prefix == ':' then
                output.args = part:split(',')
            elseif prefix == '%' then
                output.filter_program = tonumber(part)
                self._has_conditional_output = true
            end
        end
        self._outputs[#self._outputs+1] = output
    end
    return self._outputs
end

function Articulation:has_conditional_output()
    return self._has_conditional_output
end

-- Returns a human readable string explaining what the outputs do.
function Articulation:describe_outputs()
    local outputs = self:get_outputs()
    local description = ''
    local last_verb = nil
    for n, output in ipairs(outputs) do
        local s = nil
        local verb = 'Sends'
        local channel = nil
        if output.channel == 0 then
            channel = 'current channels'
        elseif output.channel then
            channel = string.format('ch %d', output.channel)
        end
        if output.bus then
            channel = (channel and (channel .. ' ') or '') .. string.format('bus %s', output.bus)
        end

        -- output.args is unsanitized, so we need to be defensive.
        local args = {tonumber(output.args[1]), tonumber(output.args[2])}
        if output.type == 'program' then
            s = string.format('program change %d', args[1] or 0)
        elseif output.type == 'cc' then
            s = string.format('CC %d val %d', args[1] or 0, args[2] or 0)
        elseif output.type == 'note' or output.type == 'note-hold' then
            local note = args[1] or 0
            local name = note_to_name(note)
            verb = output.type == 'note' and 'Sends' or 'Holds'
            if (args[2] or 127) == 127 then
                s = string.format('note %s (%d)', name, note)
            else
                s = string.format('note %s (%d) vel %d', name, note, args[2] or 127)
            end
        elseif output.type == 'pitch' then
            s = string.format('pitch bend val %d', args[1] or 0)
        elseif output.type == 'art' then
            local program = args[1] or 0
            local bank = self:get_bank()
            local art = bank.articulations_by_program[program]
            if art then
                s = art.name or 'unnamed articulation'
            else
                s = 'undefined articulation'
            end
        elseif output.type == nil and channel then
            verb = 'Routes'
            s = string.format('to %s', channel)
        end
        if s then
            if output.type and output.channel then
                s = s .. string.format(' on %s', channel)
            end
            if last_verb then
                if verb == last_verb then
                    description = string.format('%s, %s', description, s)
                else
                    description = string.format('%s, %s %s', description, verb:lower(), s)
                end
            else
                description = string.format('%s %s', verb, s)
            end
            last_verb = verb
        end
    end
    return description
end

function Articulation:copy_to_bank(bank)
    local clone = Articulation(bank, self.program, self.name, self._attrs)
    bank:add_articulation(clone)
end

function Articulation:get_bank()
    return reabank.get_bank_by_guid(self.bank_guid)
end


function Articulation:is_active()
    return self.channels ~= 0
end


--------------------------------------------------------------
-- Bank class
--------------------------------------------------------------

local Bank = rtk.class('Bank')
function Bank:initialize(msb, lsb, name, attrs, factory)
    -- reabank.parse_from_string() which calls us will catch this and log an error.
    assert(name, 'bank name must be specified')
    self.factory = factory
    self._msb = tonumber(msb)
    self._lsb = tonumber(lsb)
    if self._msb and self._lsb then
        self.msblsb = (self._msb << 8) + self._lsb
    end
    self.name = name
    -- Set to true when Bank:realize() is called.
    self.realized = false
    -- List of articulations in order defined in Reabank file
    self.articulations = {}
    -- Articulation objects keyed by program number.
    self.articulations_by_program = {}
    -- Set by the app layer when a track is selected which uses this bank.
    -- 1 = channel 1, 17 = omni
    self.channel = 17
    table.merge(self, attrs)
    -- Remember the supplied attributes for copy_missing_attributes_from()
    self._attrs = attrs

    self.flags = _parse_flags(self.flags,
        -- Defaults
        Articulation.FLAG_CHASE |
        Articulation.FLAG_ANTIHANG |
        Articulation.FLAG_ANTIHANG_CC |
        Articulation.FLAG_BLOCK_BANK_CHANGE
    )

    -- Bank-level hidden flag is an exception.  It doesn't propagate to the
    -- articulations but rather controls whether the bank should be visible
    -- in the UI.
    self.hidden = (self.flags & Articulation.FLAG_HIDDEN) ~= 0
    self.flags = self.flags & ~Articulation.FLAG_HIDDEN
    -- Cached value from hash()
    self._cached_hash = nil
end

-- Generates a 32-bit numeric hash.
--
-- All aspects of the bank except GUID are included in the hash.
--
-- If dynamic is true, then external aspects relevant to the RFX such as user-configurable
-- chase CCs are included in the hash.  If false, then only elements directly from the
-- bank definition are hashed.
function Bank:_hash(dynamic)
    local arts = {}
    log.time_start()
    for _, art in pairs(self.articulations_by_program) do
        -- Nil values are filtered out before we hash, which ensures the hash will remain
        -- the same even as we add new attributes, as long as those attributes are not
        -- specified.
        arts[#arts+1] = as_filtered_table(
            art.program,
            art.name,
            art.group,
            art.flags,
            art.iconname,
            art.spacer,
            art.message,
            art.color,
            art.outputs,
            art.velrange,
            art.pitchrange,
            art.transpose,
            art.velocity
        )
    end

    local bankinfo = as_filtered_table(
        self.name,
        self.shortname,
        self.group,
        self.flags,
        dynamic and (self.chase or '') or self:get_chase_cc_string(),
        self.clone,
        self.off,
        self.message,
        arts
    )
    log.time_end('reabank: computed hash for %s', self.name)
    return crc64(table.tostring(bankinfo))
end

function Bank:hash()
    if not self._cached_hash then
        self._cached_hash = self:_hash(true)
    end
    return self._cached_hash
end

function Bank:ensure_guid()
    if self.guid then
        -- GUID already exists, doesn't need to be generated.
        return
    end
    if self.msblsb then
        -- This is a legacy bank that explicitly defines an MSB/LSB, so we want to choose
        -- a deterministic guid that would also be chosen on a different system, given the
        -- same bank definition.
        --
        -- We do this by generating a hash of the bank and constructing the GUID based on
        -- the hash. Consequently, this attempts to preserve similar behavior to the
        -- pre-guid versions of Reaticulate.
        local hash = string.format('%016x', self:_hash(false))
        -- One CRC64 takes care of 64 bits, but we need another 32-bits for the second and
        -- third segment of the UUID4.  Just take a CRC64 of the first hash as a lame way
        -- to fake a larger hash.
        local hash2 = string.format('%016x', crc64(hash))
        -- The first segment of UUIDs for converted legacy non-factory banks is all 1s,
        -- unless the MSB is >= 92 which indicates it is an OTR bank, in which case we use
        -- all 2s. (I assigned MSB >= 92 to OTR v2 knowing that it would be transitional
        -- until GUIDs arrived.)
        local msb = self.msblsb >> 8
        self.guid = string.format(
            '%s-%s-%s-%s-%s',
            msb >= 92 and '22222222' or '11111111',
            hash2:sub(1, 4),
            hash2:sub(5, 8),
            hash:sub(1, 4),
            hash:sub(5)
        )
    else
        -- New style bank with undefined MSB/LSB, so generate a fully random guid.
        self.guid = rtk.uuid4()
    end
    -- Update all our articulations as they reference our GUID which has now been set.
    for _, art in ipairs(self.articulations) do
        art.bank_guid = self.guid
    end
    log.info('bank: missing GUID: %s %s', self.name, self.guid)
    return true
end

function Bank:get_current_msb_lsb()
    local msb, lsb = reabank.get_project_msblsb_for_guid(self.guid)
    if not msb then
        log.exception('BUG: bank %s (guid=%s) missing from project state', self.name, self.guid)
    else
        return msb, lsb
    end
end

function Bank:add_articulation(art)
    art._index = #self.articulations + 1
    self.articulations[art._index] = art
    self.articulations_by_program[art.program] = art
end

function Bank:get_articulation_by_program(program)
    return self.articulations_by_program[program]
end

function Bank:get_articulation_before(art)
    if art then
        local idx = art._index - 1
        if idx >= 1 then
            return self.articulations[idx]
        end
    end
end

function Bank:get_articulation_after(art)
    if art then
        local idx = art._index + 1
        if idx <= #self.articulations then
            return self.articulations[idx]
        end
    end
end

function Bank:get_first_articulation()
    return self.articulations[1]
end

function Bank:get_last_articulation()
    return self.articulations[#self.articulations]
end

function Bank:get_src_channel(default_channel)
    if self.srcchannel == 17 then
        return default_channel
    else
        return self.srcchannel
    end
end

-- Returns a comma-delimited range list of CCs for this bank.
--
-- If the list is explicitly defined in the bank, that gets returned.  Otherwise
-- the user-configurable list is returned if it's both defined and valid, and
-- finally if not, the hardcoded default is used.
function Bank:get_chase_cc_string()
    if self.chase then
        return self.chase
    end
    -- Try user config
    local s = (app.config.chase_ccs or ''):gsub('%s', '')
    local valid = not s:find('[^%d,-]')
    if #s > 0 and valid then
        return s
    else
        return reabank.DEFAULT_CHASE_CCS
    end
end

-- Returns a parsed, unpacked table based on get_chase_cc_string()
function Bank:get_chase_cc_list()
    if self._cached_chase then
        return self._cached_chase
    end
    local ccs = {}
    local chase = self:get_chase_cc_string()
    for _, elem in ipairs(chase:split(',')) do
        if elem:find('-') then
            local subrange = elem:split('-')
            for i = tonumber(subrange[1]), tonumber(subrange[2]) do
                ccs[#ccs+1] = i
            end
        else
            ccs[#ccs+1] = tonumber(elem)
        end
    end
    self._cached_chase = ccs
    return ccs
end

function Bank:get_path()
    if not self.group then
        return self.shortname or self.name
    else
        return self.group .. '/' .. (self.shortname or self.name)
    end
end

-- Returns vendor, product, patch name
function Bank:get_name_info()
    if not self.group then
        return nil, nil, self.shortname
    else
        if not self.group:find('/') then
            return nil, self.group, self.shortname
        else
            local vendor, product = self.group:match('([^/]+)/(.+)')
            return vendor, product, self.shortname
        end
    end
end

function Bank:copy_articulations_from(from_bank)
    for _, art in ipairs(from_bank.articulations) do
        art:copy_to_bank(self)
    end
end

function Bank:copy_missing_attributes_from(from_bank)
    for k, v in pairs(from_bank._attrs) do
        if not self._attrs[k] then
            self._attrs[k] = v
            self[k] = v
        end
    end
end

-- Perform any necessary post-processing after all articulations are instantiated
-- in the bank.  This need only be called when the bank is actually used by the user.
function Bank:realize()
    if self.realized then
        return
    end
    -- Discover which articulations are used as filters for other articulations'
    -- output events and set Articulation.FLAG_IS_FILTER on them.
    for _, art in ipairs(self.articulations) do
        local outputs = art:get_outputs()
        for _, output in ipairs(outputs) do
            if output.filter_program then
                local filter = self:get_articulation_by_program(output.filter_program)
                if filter then
                    filter.flags = filter.flags | Articulation.FLAG_IS_FILTER
                end
            end
        end
    end
    self.realized = true
end


--------------------------------------------------------------
-- Module functions
--------------------------------------------------------------

local function get_reabank_file()
    local ini = rtk.file.read(reaper.get_ini_file())
    return ini and ini:match("mididefbankprog=([^\n]*)")
end

function reabank.init()
    log.time_start()
    -- This is allowed to be nil, and will be if the key doesn't exist.
    reabank.last_written_msblsb = app:get_ext_state('last_written_msblsb')
    reabank.reabank_filename_factory = Path.join(Path.basedir, "Reaticulate-factory.reabank")
    reabank.reabank_filename_user = Path.join(Path.resourcedir, "Data", "Reaticulate.reabank")
    log.info("reabank: init files factory=%s user=%s", reabank.reabank_filename_factory, reabank.reabank_filename_user)
    local cur_factory_bank_size, err = rtk.file.size(reabank.reabank_filename_factory)
    local file = get_reabank_file() or ''
    local tmpnum = file:lower():match("-tmp(%d+).")
    if tmpnum and rtk.file.exists(file) then
        log.debug("reabank: tmp file exists: %s", file)
        reabank.version = tonumber(tmpnum)
        reabank.filename_tmp = file
        -- Determine if the factory bank has changed file size.  If it has (because e.g. the user
        -- upgraded), ensure the tmp bank is refreshed.  This isn't foolproof, but it's good enough.
        local last_factory_bank_size = reaper.GetExtState("reaticulate", "factory_bank_size")
        if cur_factory_bank_size == tonumber(last_factory_bank_size) then
            reabank.menu = nil
            reabank.parseall()
            log.info("reabank: parsed bank files (factory banks unchanged since last start)")
            log.time_end()
            return
        else
            log.info("reabank: factory bank has changed: cur=%s last=%s", cur_factory_bank_size, last_factory_bank_size)
        end
    end

    -- Either tmp reabank doesn't exist or factory banks have changed, so regenerate.
    log.info("reabank: generating new reabank")
    reabank.parseall()
    reaper.SetExtState("reaticulate", "factory_bank_size", tostring(cur_factory_bank_size), true)
    log.info("reabank: refreshed reabank %s", reabank.filename_tmp)
    log.time_end()
end

-- This function will be called after app project state is loaded.
function reabank.onprojectchange()
    local state = app.project_state
    if not state.msblsb_by_guid then
        state.msblsb_by_guid = {}
    end
end

-- Allocate an MSB/LSB for the given bank and update the msblsb_by_guid map.
-- Returns msb, lsb that were selected.
--
-- The optional msb/lsb parameters are a requested starting point, but the actual chosen
-- MSB/LSB will depend on what's available in the project.  That is, unless required is
-- true, in which case we refuse to add the bank to the project and return nil.
function reabank.add_bank_to_project(bank, msb, lsb, required)
    local msblsb_by_guid = app.project_state.msblsb_by_guid
    local msblsb = msblsb_by_guid[bank.guid]
    if msblsb then
        -- Bank already exists in project.  Just return already-assigned MSB/LSB.
        log.info('reabank: bank already exists in project with msb=%s lsb=%s', msblsb >> 8, msblsb & 0xff)
        return (msblsb >> 8) & 0xff, msblsb & 0xff
    end
    log.info('reabank: add bank guid=%s msb=%s lsb=%s required=%s', bank.guid, msb, lsb, required)
    if msb and lsb then
        -- Check to see if requested MSB/LSB is already taken.
        local existing_guid = msblsb_by_guid[msb << 8 | lsb]
        if existing_guid and existing_guid ~= bank.guid then
            log.warning('reabank: requested msb/lsb %s,%s for bank %s conflicts with %s',
                        msb, lsb, bank.name, existing_guid)
            msb = nil
            lsb = nil
        end
    end
    if not msb or not lsb then
        if bank.msblsb then
            -- Explicit MSB/LSB was defined in bank.  Prefer that.
            msb = (bank.msblsb >> 8) & 0xff
            lsb = bank.msblsb & 0xff
            log.debug('reabank: bank has defined msb=%s lsb=%s', msb, lsb)
        else
            -- Generate a starting MSB/LSB from CRC of the bank guid.  We hash MSB below
            -- 64, avoiding the range reserved for factory banks.  This is more out of
            -- paranoia, or the possibility of future uses of these ranges.
            local crc = crc64(bank.guid)
            msb = (crc >> 32) % 64
            lsb = (crc & 0xffffffff) % 128
            log.debug('reabank: generated MSB/LSB from CRC: msb=%s lsb=%s', msb, lsb)
        end
    end

    local candidate = (msb << 8) | lsb
    -- Sanity: add an upper bound to how much we should search for a free MSB/LSB.  We
    -- should never hit this in practice.
    for i = 0, 16000 do
        -- Check to see if another bank is already using this MSB/LSB.
        --
        -- This is O(n) with respect to number of banks in project.  Should probably be
        -- fine even for fairly large projects though.
        local found = false
        for guid, msblsb in pairs(msblsb_by_guid) do
            if msblsb == candidate and guid ~= bank.guid then
                -- We've found a conflicting MSB/LSB for a different guid.
                found = true
                break
            end
        end
        if not found then
            -- Candidate MSB/LSB didn't conflict with anything, so we can use it.
            msblsb_by_guid[bank.guid] = candidate
            break
        else
            if required then
                -- Caller requires use of requested MSB/LSB, so we give up.
                log.info('reabank: failed to allocate requested msb/lsb (%s, %s) for bank %s',
                         msb, lsb, bank.guid)
                return nil
            end
            -- Candidate MSB/LSB was already assigned in this project.  Just increment,
            -- avoiding MSB 64-127 reserved for factory banks -- at least for now.
            candidate = candidate + 1
            if candidate >= (64 << 8) then
                candidate = (1 << 8) | 1
            elseif (candidate & 0xff) == 0 then
                -- Just avoid LSB 0 for good measure.
                candidate = candidate + 1
            end
        end
    end
    app:queue(App.SAVE_PROJECT_STATE | App.REFRESH_BANKS | App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK)
    msb, lsb = candidate >> 8, candidate & 0xff
    log.info('reabank: generated msblsb=%s,%s for bank %s', msb, lsb, bank.guid)
    return msb, lsb
end


-- Clears the cache used by Bank:get_chase_cc_list() across all Bank objects.
-- Call this when the user-configurable chase list changes.
function reabank.clear_chase_cc_list_cache()
    for guid, bank in pairs(reabank.banks_by_guid) do
        bank._cached_chase = nil
        -- Chase CCs affects the bank's hash
        bank._cached_hash = nil
    end
end

-- Parses a set of color definitions from the reabank and stores in the module's
-- colors table.
--
-- For predefined articulation colors, app config is authoritative, but this is
-- still used for user-defined color names.
function reabank.parse_colors(colors)
    for name, color in colors:gsub(',', ' '):gmatch('(%S+)=([^"]%S*)') do
        reabank.colors[name] = color
    end
end

-- Parses a line of key=value or key="multi word value" properties and returns the
-- resulting table.
local function parse_properties(line)
    local props = {}
    for key, value in line:gmatch('(%w+)=([^"]%S*)') do
        props[key] = value
    end
    for key, value in line:gmatch('(%w+)="([^"]*)"') do
        props[key] = value:gsub('\\n', '\n'):gsub('&quot;', '"')
    end
    return props
end

-- Parses a single file containing one or more Reaticulate-annotated bank definitions.
--
function reabank.parse(filename)
    local data, err = rtk.file.read(filename)
    if not data then
        return
    end
    local factory = filename == reabank.reabank_filename_factory
    local banks, dupes, dirty, outlines = reabank.parse_from_string(data, factory)
    log.info('reabank: read %s banks from %s', #banks, filename)
    if dirty then
        log.info('reabank: rewriting %s with %s lines', filename, #outlines)
        local data = table.concat(outlines, '\n')
        err = rtk.file.write(filename, data)
        if err then
            return app:fatal_error(
                'Failed to rewrite updated Reaticulate reabank file after generating bank GUIDs: ' ..
                tostring(err)
            )
        end
    end
end

-- Updates the key k in the given table t with the value v only if the key does not
-- already exist in the table.
local function merge(t, k, v)
    if t[k] == nil then
        t[k] = v
    end
end

-- Parses a string containing one or more banks and registers them.
--
-- Banks lacking guids will have a guid generated.
--
-- Return value is (banks, dupes, dirty, outlines) where dirty is true if any banks
-- needed a guid to be generated, and outlines is a table of lines that contain
-- the bank that should be written out.  (Caller must concatenate.)
function reabank.parse_from_string(data, factory)
    if not data then
        return {}, {}, false, nil
    end
    -- If true, it means at least one of the banks is dirty (needs resaving),
    -- likely due to a dynamically generated guid.
    local dirty = false
    -- Lines of the bank, modified as needed (and if so, dirty will be true), to
    -- be saved back out by the caller if needed.
    -- FIXME: should not include duplicate banks
    local outlines = {}
    -- Bank objects that were created and were unique
    local banks = {}
    -- Bank objects that were defined by were duplicates
    local dupes = {}
    -- Current bank being processed
    local bank = nil
    -- Track banks which are cloned
    local clones = {}

    -- After a bank has been has been parsed, this registers it so it's available for use.
    -- It's done after being fully parsed to ensure that if we need to generate a hash for
    -- a legacy bank with defined MSB/LSB, we can ensure the articulations are included in
    -- the hash.
    local function register(bank)
        if not bank then
            return
        end
        local generated = bank:ensure_guid()
        if generated and bank.guid_line_number then
            outlines[bank.guid_line_number] = string.format('//! id=%s', bank.guid)
            bank.guid_line_number = nil
        end
        local existing = reabank.get_bank_by_guid(bank.guid)
        if existing and not existing.factory then
            -- This guid already exists.  Refuse to overwrite unless the original
            -- was a factory bank where we allow users to replace.
            log.error('reabank: bank %s has conflicting GUID (%s) with %s', bank.name, bank.guid, existing.name)
            dupes[#dupes + 1] = bank
        else
            banks[#banks+1] = bank
            reabank.register_bank(bank)
        end
        return generated
    end

    local metadata = {}
    for origline in data:gmatch("[^\n]*") do
        local line = origline:gsub("^%s*(.-)%s*$", "%1")
        if line:startswith("Bank", true) then
            -- Registers the previously parsed bank, if any.
            dirty = register(bank) or dirty
            -- Start of new bank.  MSB/LSB of * means dynamic.
            local msb, lsb, name = line:match(".... +([%d*]+) +([%d*]+) +(.*)")
            local status
            status, bank = xpcall(Bank,
                function ()
                    log.error('failed to load bank due to syntax error: %s', line)
                end,
                msb, lsb, name, metadata, factory
            )
            if bank then
                if not bank.guid then
                    outlines[#outlines + 1] = '// generated guid goes here'
                    bank.guid_line_number = #outlines
                end
                if bank.clone then
                    clones[#clones + 1] = bank
                end
                outlines[#outlines + 1] = origline:strip()
                metadata = {}
            end
        elseif line:startswith("//!") then
            outlines[#outlines + 1] = origline:strip()
            -- Reaticulate metadata for the next program/bank
            local props = parse_properties(line)
            merge(metadata, 'color', props.c)
            merge(metadata, 'iconname', props.i)
            merge(metadata, 'shortname', props.n)
            merge(metadata, 'group', props.g)
            merge(metadata, 'off', props.off and tonumber(props.off) or nil)
            merge(metadata, 'outputs', props.o)
            merge(metadata, 'flags', props.f)
            merge(metadata, 'message', props.m)
            merge(metadata, 'clone', props.clone)
            merge(metadata, 'chase', props.chase)
            merge(metadata, 'spacer', props.spacer)
            merge(metadata, 'guid', props.id)
            -- Transformations
            merge(metadata, 'velrange', props.velrange)
            merge(metadata, 'pitchrange', props.pitchrange)
            merge(metadata, 'transpose', props.transpose)
            merge(metadata, 'velocity', props.velocity)
            if props.colors then
                reabank.parse_colors(props.colors)
            end
        elseif line:len() > 0 and not line:startswith("//") then
            local program, name = line:match("^ *(%d+) +(.*)")
            if bank and program and name then
                outlines[#outlines + 1] = origline:strip()
                local art = Articulation(bank, tonumber(program), name, metadata)
                if art.flags & Articulation.FLAG_HIDDEN == 0 then
                    bank:add_articulation(art)
                end
            end
            -- Reinitialize for next articulation
            metadata = {}
        else
            -- Empty line or comment
            outlines[#outlines + 1] = origline:strip()
        end
    end
    -- Registers the previously parsed bank, if any.
    dirty = register(bank) or dirty
    -- Now that all banks have been parsed, we can loop through all clones and copy the
    -- attributes/articulations from the sources they were cloned from.
    for _, bank in ipairs(clones) do
        local source = reabank.banks_by_guid[bank.clone] or reabank.banks_by_path[bank.clone]
        if source then
            bank:copy_missing_attributes_from(source)
            bank:copy_articulations_from(source)
        end
    end
    log.debug('reabank: parsed banks sz=%d factory=%s', #data, factory)
    return banks, dupes, dirty, outlines
end

-- Parses both factory and user banks and updates bank lookup tables.
function reabank.parseall()
    reabank.banks_by_guid = {}
    reabank.legacy_banks_by_msblsb = {}
    reabank.banks_by_path = {}

    if not reabank.banks_factory then
        reabank.parse(reabank.reabank_filename_factory)
        reabank.banks_factory = table.shallow_copy(reabank.banks_by_guid)
    else
        log.debug("skipping factory parse")
        -- Need to register the banks after having cleared the banks_by_* maps.
        for _, bank in pairs(reabank.banks_factory) do
            reabank.register_bank(bank)
        end
    end
    reabank.parse(reabank.reabank_filename_user)
end

-- Imports one or more Reaticulate-annotated reabanks from the given string.
function reabank.import_banks_from_string(data)
    local banks, dupes, dirty, outlines = reabank.parse_from_string(data, false)
    if #banks > 0 then
        for _, bank in ipairs(banks) do
            if app.project_state.msblsb_by_guid[bank.guid] then
                -- The imported bank was previously added to the project.  Re-add
                -- it now in case the MSB/LSB has changed.
                reabank.add_bank_to_project(bank)
            end
        end
        local filename = reabank.reabank_filename_user
        local origdata, err = rtk.file.read(filename)
        local data = (origdata or '') .. '\n\n' .. table.concat(outlines, '\n')
        err = rtk.file.write(filename, data)
        if err then
            log.error('reabank: failed to rewrite %s after import', filename)
        else
            log.info('reabank: rewrote %s with %d new banks', filename, #banks)
        end
        reabank.menu = nil
    end
    return banks, dupes
end

-- Variant of import_banks_from_string() that pops up a summary box describing
-- what was (or wasn't) imported.
function reabank.import_banks_from_string_with_feedback(data, srcname)
    local banks, dupes = reabank.import_banks_from_string(data)
    local msg
    if #banks > 0 then
        msg = string.format('%d banks were imported from %s:', #banks, srcname)
        for _, bank in ipairs(banks) do
            msg = msg .. string.format('\n   - %s', bank.name)
        end
    elseif #dupes == 0 then
        msg = string.format('No valid Reaticulate banks could be found in %s.', srcname)
    else
        msg = 'No banks were imported.'
    end
    if #dupes > 0 then
        msg = msg .. string.format('\n\n%d banks were ignored because they were already installed:', #dupes)
        for _, bank in ipairs(dupes) do
            msg = msg .. string.format('\n   - %s', bank.name)
        end
    end
    if #banks > 0 then
        app:queue(App.REFRESH_BANKS)
    end
    -- Defer message box to give GUI a chance to update to reflect (potential)
    -- changes.
    rtk.defer(reaper.ShowMessageBox, msg, 'Import Reaticulate Banks', 0)
end

-- Adds the given Bank object to the global tables so that it can later be
-- looked up via reabank.get_bank_by_guid() or reabank.get_legacy_bank_by_msblsb().
function reabank.register_bank(bank)
    reabank.banks_by_guid[bank.guid] = bank
    reabank.banks_by_path[bank:get_path()] = bank
    if bank.msblsb then
        -- Legacy bank that defines explicitly MSB/LSB
        reabank.legacy_banks_by_msblsb[bank.msblsb] = bank
    end
    -- Invalidate cache for reabank.to_menu()
    reabank.menu = nil
end

-- Creates Data/Reaticulate.reabank if it doesn't exist, seeding it with
-- the initial comment from the factory bank file.
function reabank.create_user_reabank_if_missing()
    local f = io.open(reabank.reabank_filename_user)
    if f then
        f:close()
        return
    end
    -- File is missing, create with header from factory reabank.
    local inf = io.open(reabank.reabank_filename_factory)
    local outf = io.open(reabank.reabank_filename_user, 'w')
    for line in inf:lines() do
        if line:startswith("//!") then
            break
        end
        outf:write(line .. '\n')
    end
    inf:close()
    outf:close()
end

-- Updates REAPER's configuration for the global default reabank.
local function set_reabank_file(reabank)
    -- TODO: SNM_SetStringConfigVar() is in SWS pre-releases.  May make for a simpler
    -- viable alternative in future.
    local inifile = reaper.get_ini_file()
    local ini, err = rtk.file.read(inifile)
    if err then
        -- Can't read REAPER's ini file.  This shouldn't happen.  Something is wrong with the
        -- installation.
        return app:fatal_error("Failed to read REAPER's ini file: " .. tostring(err))
    end
    if ini:find("mididefbankprog=") then
        ini = ini:gsub("mididefbankprog=[^\n]*", "mididefbankprog=" .. reabank)
    else
        local pos = ini:find('%[REAPER%]\n')
        if not pos then
            pos = ini:find('%[reaper%]\n')
        end
        if pos then
            ini = ini:sub(1, pos + 8) .. "mididefbankprog=" .. reabank .. "\n" .. ini:sub(pos + 9)
        end
    end
    log.info("reabank: updating ini file %s", inifile)
    err = rtk.file.write(inifile, ini)
    if err then
        return app:fatal_error("Failed to write ini file: " .. tostring(err))
    end
end

-- Generates a non-annotated ReaBank file for all banks in the current project,
-- and returns the result as a string.
--
-- If 'compare' is provided, it is a map of stringified packed MSB/LSB to Bank hash and is
-- used to track whether there were additions or bank definition changes relative to this
-- table. Added or modified banks are inserted in the 'changes' table that's returned.
-- Note that DELETIONS are not detected: as long as all existing project banks are in the
-- compare table with the same definition, true is returned.  If the compare table is nil,
-- then all banks in the project are included in the changes table.
--
-- 3 values are returned:
--   1. A table mapping packed MSB/LSB to bank hash of all banks in the project. The keys are
--      stringified to enable serialization to JSON. (This is why the keys in the compare
--      table are also expected to be strings.)
--   2. A table of changes, mapping bank GUID to the current project's MSB/LSB (packed number)
--   3. A string holding the rendered reabank contents
function reabank.project_banks_to_reabank_string(compare)
    local changes = {updates=0, additions=0}
    local msblsbmap = {}
    local s = ''
    -- Ensure the order we enumerate the current project banks is deterministic so that
    -- the caller is able to compare contents of successive calls to detect changes.
    local guids = table.keys(app.project_state.msblsb_by_guid)
    table.sort(guids)
    for _, guid in ipairs(guids) do
        local msblsb = app.project_state.msblsb_by_guid[guid]
        local bank = reabank.get_bank_by_guid(guid)
        if bank then
            local msblsbstr = tostring(msblsb)
            local hash = bank:hash()
            -- Technically we should be checking the GUID as well, as hash doesn't include
            -- GUID. But this seems safe: even if this ends up referencing a different
            -- bank GUID, if the actual bank contents are identical it doesn't make any
            -- difference to REAPER.  The PC numbers and names must be the same.
            if compare and compare[msblsbstr] then
                if compare[msblsbstr] ~= hash then
                    changes[bank.guid] = msblsb
                    changes.updates = changes.updates + 1
                end
            else
                changes.additions = changes.additions + 1
            end
            msblsbmap[msblsbstr] = hash
            local msb = msblsb >> 8
            local lsb = msblsb & 0xff
            s = s .. string.format('\n\nBank %d %d %s\n', msb, lsb, bank.name)
            for _, art in ipairs(bank.articulations) do
                s = s .. string.format('%d %s\n', art.program, art.name)
            end
        end
    end
    -- If there aren't any project banks and we have an empty reabank, consider it not
    -- changed.
    return msblsbmap, changes, s
end

-- Writes a ReaBank file for all banks in the project and their ephemeral MSB/LSB mappings,
-- and sets this new file as Reaper's global default.
--
-- If the newly generated project reabank file has banks that saw material changes, then
-- the changes table (as received from project_banks_to_reabank_string()) is returned.  If
-- there were no modifications then nil is returned. This is the case even if there were
-- additions to the project reabank -- only modifications are returned.
function reabank.write_reabank_for_project()
    local msblsbmap = reabank.last_written_msblsb
    local new_msblsbmap, changes, contents = reabank.project_banks_to_reabank_string(msblsbmap)
    if changes.updates == 0 and changes.additions == 0 then
        -- No additions or alterations relative to the current tmp reabank.  We skip
        -- replacing it, and return nil to indicate to the caller no relevant changes
        -- were made.  "Relevant" because the current tmp reabank may contain banks not
        -- referenced by the current project, but that's ok for our purposes.
        log.info('reabank: project reabank has no changes/additions, skipping write')
        return
    end

    local tmpnum = 1
    if reabank.filename_tmp then
        tmpnum = tonumber(reabank.filename_tmp:match("-tmp(%d+).")) + 1
    end

    -- FIXME: assumes case
    local newfile = reabank.reabank_filename_user:gsub("(.*).reabank", "%1-tmp" .. tmpnum .. ".reabank")
    -- Insert a comment block at the top of our new contents
    contents = "// Generated file.  DO NOT EDIT!  CONTENTS WILL BE LOST!\n" ..
               "// Edit this instead: " .. reabank.reabank_filename_user .. "\n\n\n\n" ..
               contents
    if not msblsbmap and reabank.filename_tmp then
        -- If we don't know the MSB/LSB map for the last written tmp reabank (in which case
        -- msblsbmap is nil), then we fall back to a more brute force approach by comparing
        -- the actual file contents between current and planned reabank.
        local existing = rtk.file.read(reabank.filename_tmp)
        if existing == contents then
            log.debug('reabank: project reabank contents is not changing, skipping write')
            return
        end
    end
    -- Write contents to tmp reabank
    log.debug('reabank: stringified banks nbytes=%s', #contents)
    local err = rtk.file.write(newfile, contents)
    if err then
        return app:fatal_error("Failed to write project Reabank file: " .. tostring(err))
    end
    log.debug('reabank: wrote %s', newfile)
    set_reabank_file(newfile)
    log.debug('reabank: installed new Reaper global reabank')

    if reabank.filename_tmp and rtk.file.exists(reabank.filename_tmp) then
        log.debug("reabank: deleting old reabank file: %s", reabank.filename_tmp)
        os.remove(reabank.filename_tmp)
    end
    reabank.filename_tmp = newfile
    log.info("reabank: finished switching to new reabank file: %s", newfile)
    reabank.version = tmpnum
    -- Store this as REAPER state so optimizations which depend on an accurate change list
    -- survive restarts (either of Reaticulate or of REAPER).
    app:set_ext_state('last_written_msblsb', new_msblsbmap, true)
    reabank.last_written_msblsb = new_msblsbmap
    -- Return the changes table only if there were actually changes
    return changes.updates > 0 and changes or nil, changes.additions > 0
end

-- Returns the Bank object known by the given GUID, or nil if not found.
function reabank.get_bank_by_guid(guid)
    return reabank.banks_by_guid[guid]
end

-- Returns the legacy style Bank object that had explicitly defined the given
-- packed MSB/LSB.  This
function reabank.get_legacy_bank_by_msblsb(msblsb)
    -- math.floor() used to cast float to int
    return reabank.legacy_banks_by_msblsb[math.floor(tonumber(msblsb) or 0)]
end

-- Returns the MSB and LSB for Bank with the given GUID as it's mapped in the current
-- project.
--
-- Prefer Bank:get_current_msb_lsb() if possible.
function reabank.get_project_msblsb_for_guid(guid)
    local msblsb = app.project_state.msblsb_by_guid[guid]
    if msblsb then
        return (msblsb >> 8) & 0xff, msblsb & 0xff
    end
end

-- Returns a rtk.NativeMenu-compatible menu table for all banks currently installed
-- on the system (both user and factory banks).
function reabank.to_menu()
    if reabank.menu then
        return reabank.menu
    end
    local bankmenu = {}
    for _, bank in pairs(reabank.banks_by_guid) do
        local submenu = bankmenu
        if bank.group then
            local group = (bank.factory and 'Factory/' or 'User/') .. bank.group
            for part in group:gmatch("[^/]+") do
                local lowerpart = part:lower()
                -- Find the index of this part in the current submenu.
                local found = false
                for n, tmpmenu in ipairs(submenu) do
                    if tmpmenu.lowername == lowerpart then
                        submenu = tmpmenu.submenu
                        found = true
                        break
                    end
                end
                if not found then
                    -- No existing submenu was found, so create a new one given the name
                    -- (and case) for this bank.
                    local tmpmenu = {part, submenu={}, lowername=lowerpart}
                    submenu[#submenu+1] = tmpmenu
                    submenu = tmpmenu.submenu
                end
            end
        end
        submenu[#submenu+1] = {
            bank.shortname or bank.name,
            id=bank.guid,
            disabled=bank.hidden,
            altlabel=bank.name
        }
    end

    local function cmp(a, b)
        return a[1] < b[1]
    end
    local function sort(t)
        for _, menu in pairs(t) do
            if menu.submenu then
                sort(menu.submenu)
            end
        end
        table.sort(t, cmp)
    end
    sort(bankmenu)
    reabank.menu = bankmenu
    return bankmenu
end

return reabank