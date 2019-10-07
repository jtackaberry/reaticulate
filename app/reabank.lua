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

require 'lib.utils'
require 'lib.crc32'
local log = require 'lib.log'
local rtk = require 'lib.rtk'

local reabank = {
    DEFAULT_CHASE_CCS = '1,2,11,64-69',

    reabank_filename_factory = nil,
    reabank_filename_user = nil,
    filename_tmp = nil,
    version = nil,
    -- Just the factory banks
    banks_factory = nil,
    -- User and factory banks combined
    banks = {},
    -- Maps fully qualified group/name to bank object.
    banks_by_path = {},
    articulation_map = {},
    menu = nil,
    colors = {
        ['default'] = '#666666'
    },
    textcolors = {
        ['default'] = '#ffffff'
    }

}

local function insert_program_change(take, selected, ppq, channel, bank_msb, bank_lsb, program)
    reaper.MIDI_InsertCC(take, selected, false, ppq, 0xb0, channel, 0, bank_msb)
    reaper.MIDI_InsertCC(take, selected, false, ppq, 0xb0, channel, 32, bank_lsb)
    reaper.MIDI_InsertCC(take, selected, false, ppq, 0xc0, channel, program, 0)
    local item = reaper.GetMediaItemTake_Item(take)
    reaper.UpdateItemInProject(item)
end



Articulation = class('Articulation')
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
        if flag:starts("!") then
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
    -- Store the bank index instead of the bank itself to avoid the circular reference.
    self.bankidx = (bank.msb << 8) + bank.lsb
    self.program = program
    self.name = name
    self._attrs = attrs
    -- True if any output event has a filter program, false otherwise, or nil if
    -- we don't know (because we haven't called get_outputs())
    self._has_conditional_output = nil
    table.merge(self, attrs)
    self.group = tonumber(self.group or 1)
    self.flags = _parse_flags(self.flags, bank.flags)
    -- 16-bit bitmap of buses that output events are specifically targeting.  Will
    -- be valid after get_outputs() is called.
    self.buses = nil
end

function Articulation:get_outputs()
    if not self._outputs then
        self.buses = 0
        self._has_conditional_output = false
        self._outputs = {}
        for spec in (self.outputs or ''):gmatch('([^/]+)') do
            output = {type=nil, channel=nil, args={}, route=true, filter_program=nil}
            for prefix, part in ('/' .. spec):gmatch('([/@:%%])([^@:%%]+)') do
                if prefix == '/' then
                    if part:starts('-') then
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
        if output.channel == -1 then
            channel = 'current channels'
        elseif output.channel then
            channel = string.format('ch %d', output.channel)
        end

        if output.type == 'program' then
            s = string.format('program change %d', output.args[1] or 0)
        elseif output.type == 'cc' then
            s = string.format('CC %d val %d', output.args[1] or 0, output.args[2] or 0)
        elseif output.type == 'note' or output.type == 'note-hold' then
            local note = tonumber(output.args[1] or 0)
            local name = note_to_name(note)
            verb = output.type == 'note' and 'Sends' or 'Holds'
            if (output.args[2] or 127) == 127 then
                s = string.format('note %s', name)
            else
                s = string.format('note %s vel %d', name, output.args[2] or 127)
            end
        elseif output.type == 'pitch' then
            s = string.format('pitch bend val %d', output.args[1] or 0)
        elseif output.type == 'art' then
            local program = tonumber(output.args[1] or 0)
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
    return reabank.get_bank_by_msblsb(self.bankidx)
end

function Articulation:stuff_midi(force_insert, default_channel)
    if self.program >= 0 then
        local bank = self:get_bank()
        local channel = bank:get_src_channel(default_channel) - 1
        reaper.StuffMIDIMessage(0, 0xb0 + channel, 0, bank.msb)
        reaper.StuffMIDIMessage(0, 0xb0 + channel, 0x20, bank.lsb)
        reaper.StuffMIDIMessage(0, 0xc0 + channel, self.program, 0)
        return true
    else
        return false
    end
end


function Articulation:is_active()
    return self.channels ~= 0
end


local Bank = class('Bank')
function Bank:initialize(filename, msb, lsb, name, attrs)
    self.filename = filename
    self.factory = filename == reabank.reabank_filename_factory
    self.msb = tonumber(msb)
    self.lsb = tonumber(lsb)
    self.name = name
    -- Set to true when Bank:realize() is called.
    self.realized = false
    self.msblsb = (self.msb << 8) + self.lsb
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
    self._hash = nil
end

function Bank:hash()
    if self._hash then
        return self._hash
    end
    -- TODO: Should we have an option to only hash things used by the RFX?
    local arts = {}
    for _, art in pairs(self.articulations_by_program) do
        arts[#arts+1] = {
            art.program,
            art.name,
            art.group,
            art.flags,
            art.iconname,
            art.color,
            art.outputs,
        }
    end

    local bankinfo = {
        self.name,
        self.shortname,
        self.group,
        self.flags,
        self.chase,
        self.clone,
        self.off,
        self.message,
        arts
    }
    self._hash = crc32(table.tostring(bankinfo))
    return self._hash
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

function Bank:get_chase_cc_list()
    if self._chase then
        return self._chase
    end
    ccs = {}
    chase = self.chase or reabank.DEFAULT_CHASE_CCS
    for _, elem in ipairs(chase:split(',')) do
        if elem:find('-') then
            subrange = elem:split('-')
            for i = tonumber(subrange[1]), tonumber(subrange[2]) do
                ccs[#ccs+1] = i
            end
        else
            ccs[#ccs+1] = tonumber(elem)
        end
    end
    self._chase = ccs
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
            vendor, product = self.group:match('([^/]+)/(.+)')
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


function reabank.parse_colors(colors)
    for name, color in colors:gsub(',', ' '):gmatch('(%S+)=([^"]%S*)') do
        reabank.colors[name] = color
    end
end


local function parse_properties(line)
    props = {}
    for key, value in line:gmatch('(%w+)=([^"]%S*)') do
        props[key] = value
    end
    for key, value in line:gmatch('(%w+)="([^"]*)"') do
        props[key] = value
    end
    return props
end


function reabank.parse(filename)
    banks = {}
    -- Track banks which are cloned
    cloned = {}
    local f = io.open(filename)
    if f == nil then
        return banks
    end

    function merge(metadata, attr, value)
        if metadata[attr] == nil then
            metadata[attr] = value
        end
    end

    local bank = nil
    local metadata = {}
    for line in f:lines() do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line:starts("Bank", true) then
            -- Start of new bank
            local msb, lsb, name = line:match(".... +(%d+) +(%d+) +(.*)")
            bank = Bank(filename, msb, lsb, name, metadata)
            banks[bank.msblsb] = bank
            reabank.banks_by_path[bank:get_path()] = bank
            if bank.clone then
                cloned[#cloned + 1] = bank
            end
            metadata = {}
        elseif line:starts("//!") then
            -- Reaticulate metadata for the next program/bank
            local props = parse_properties(line)
            for key, value in line:gmatch('(%w+)=([^"]%S*)') do
                props[key] = value
            end
            for key, value in line:gmatch('(%w+)="([^"]*)"') do
                props[key] = value
            end
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
            if props.colors then
                reabank.parse_colors(props.colors)
            end
        elseif line:len() > 0 and not line:starts("//") then
            program, name = line:match("(%d+) +(.*)")
            if program and name then
                art = Articulation(bank, tonumber(program), name, metadata)
                if art.flags & Articulation.FLAG_HIDDEN == 0 then
                    bank:add_articulation(art)
                end
            end
            -- Reinitialize for next articulation
            metadata = {}
        end
    end
    f:close()
    for _, bank in ipairs(cloned) do
        local source = reabank.banks_by_path[bank.clone]
        if source then
            bank:copy_missing_attributes_from(source)
            bank:copy_articulations_from(source)
        end
    end
    return banks
end

function reabank.parseall()
    if not reabank.banks_factory then
        reabank.banks_factory = reabank.parse(reabank.reabank_filename_factory)
    else
        log.debug("skipping factory parse")
    end
    local user_banks = reabank.parse(reabank.reabank_filename_user)
    return table.merge(table.merge({}, reabank.banks_factory), user_banks)
end

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
        if line:starts("//!") then
            break
        end
        outf:write(line .. '\n')
    end
    inf:close()
    outf:close()
end

local function set_reabank_file(reabank)
    local inifile = reaper.get_ini_file()
    local ini, err = read_file(inifile)
    if err then
        -- Can't read REAPER's ini file.  This shouldn't happen.  Something is wrong with the
        -- installation.
        return app.fatal_error("Failed to read REAPER's ini file: " .. tostring(err))
    end
    if ini:find("mididefbankprog=") then
        ini = ini:gsub("mididefbankprog=[^\n]*", "mididefbankprog=" .. reabank)
    else
        pos = ini:find('%[REAPER%]\n')
        if not pos then
            pos = ini:find('%[reaper%]\n')
        end
        if pos then
            ini = ini:sub(1, pos + 8) .. "mididefbankprog=" .. reabank .. "\n" .. ini:sub(pos + 9)
        end
    end
    log.info("updating ini file %s", inifile)
    err = write_file(inifile, ini)
    if err then
        return app.fatal_error("Failed to write ini file: " .. tostring(err))
    end
end

function reabank.banks_to_reabank_string()
    s = ''
    for _, bank in pairs(reabank.banks) do
        s = s .. string.format('\n\nBank %d %d %s\n', bank.msb, bank.lsb, bank.name)
        for _, art in ipairs(bank.articulations) do
            s = s .. string.format('%d %s\n', art.program, art.name)
        end
    end
    return s
end

local function get_reabank_file()
    local ini = read_file(reaper.get_ini_file())
    return ini and ini:match("mididefbankprog=([^\n]*)")
end

function reabank.init()
    reabank.reabank_filename_factory = Path.join(Path.basedir, "Reaticulate-factory.reabank")
    reabank.reabank_filename_user = Path.join(Path.resourcedir, "Data", "Reaticulate.reabank")
    log.info("reabank: init files factory=%s user=%s", reabank.reabank_filename_factory, reabank.reabank_filename_user)
    log.time_start()

    local cur_factory_bank_size, err = file_size(reabank.reabank_filename_factory)
    local file = get_reabank_file() or ''
    local tmpnum = file:lower():match("-tmp(%d+).")
    if tmpnum and file_exists(file) then
        log.debug("reabank: tmp file exists: %s", file)
        reabank.version = tonumber(tmpnum)
        reabank.filename_tmp = file
        -- Determine if the factory bank has changed file size.  If it has (because e.g. the user
        -- upgraded), ensure the tmp bank is refreshed.  This isn't foolproof, but it's good enough.
        local last_factory_bank_size = reaper.GetExtState("reaticulate", "factory_bank_size")
        if cur_factory_bank_size == tonumber(last_factory_bank_size) then
            reabank.menu = nil
            reabank.banks = reabank.parseall()
            log.info("reabank: existing materialized reabank parsed")
            log.time_end()
            return
        else
            log.info("reabank: factory bank has changed: cur=%s last=%s", cur_factory_bank_size, last_factory_bank_size)
        end
    end

    -- Either tmp reabank doesn't exist or factory banks have changed, so regenerate.
    log.info("reabank: generating new reabank")
    reabank.refresh()
    reaper.SetExtState("reaticulate", "factory_bank_size", tostring(cur_factory_bank_size), true)
    log.info("reabank: refreshed reabank %s", reabank.filename_tmp)
    log.time_end()
end


function reabank.refresh()
    local tmpnum = 1
    if reabank.filename_tmp then
        tmpnum = tonumber(reabank.filename_tmp:match("-tmp(%d+).")) + 1
    end

    -- FIXME: assumes case
    local newfile = reabank.reabank_filename_user:gsub("(.*).reabank", "%1-tmp" .. tmpnum .. ".reabank")
    -- Copy contents to tmp reabank
    local header = "// Generated file.  DO NOT EDIT!  CONTENTS WILL BE LOST!\n"
    header = header .. "// Edit this instead: " .. reabank.reabank_filename_user .. "\n\n\n\n"

    log.time_start()
    reabank.banks = reabank.parseall()
    log.info("reabank: parsed all banks")
    local err = write_file(newfile, header .. reabank.banks_to_reabank_string())
    if err then
        log.time_end()
        return app.fatal_error("Failed to write Reabank file: " .. tostring(err))
    end
    log.debug('reabank: wrote %s', newfile)
    set_reabank_file(newfile)
    log.info('reabank: installed new bank')

    if reabank.filename_tmp and reaper.file_exists(reabank.filename_tmp) then
        log.info("reabank: deleting old reabank file: %s", reabank.filename_tmp)
        os.remove(reabank.filename_tmp)
    end
    reabank.filename_tmp = newfile
    log.info("reabank: finished switching to new reabank file: %s", newfile)
    log.time_end()
    reabank.version = tmpnum
    reabank.menu = nil
end


function reabank.get_bank(msb, lsb)
    return reabank.get_bank_by_msblsb((msb << 8) + lsb)
end

function reabank.get_bank_by_msblsb(msblsb)
    -- math.floor() used to cast float to int
    return reabank.banks[math.floor(msblsb or 0)]
end

function reabank.to_menu()
    if reabank.menu then
        return reabank.menu
    end

    local bankmenu = {}
    for _, bank in pairs(reabank.banks) do
        local submenu = bankmenu
        if bank.group then
            local group = (bank.factory and 'Factory/' or 'User/') .. bank.group
            for part in group:gmatch("[^/]+") do
                -- Find the index of this part in the current submenu.
                local found = false
                for n, tmpmenu in ipairs(submenu) do
                    if tmpmenu[1] == part then
                        submenu = tmpmenu[2]
                        found = true
                        break
                    end
                end
                if not found then
                    tmpmenu = {part, {}}
                    submenu[#submenu+1] = tmpmenu
                    submenu = tmpmenu[2]
                end
            end
        end
        submenu[#submenu+1] = {
            bank.shortname or bank.name,
            tostring(bank.msblsb),
            bank.hidden and rtk.OptionMenu.ITEM_DISABLED or rtk.OptionMenu.ITEM_NORMAL,
            bank.name
        }
    end

    function cmp(a, b)
        return a[1] < b[1]
    end
    function sort(t)
        for _, submenu in pairs(t) do
            if type(submenu[2]) == 'table' then
                sort(submenu[2])
            end
        end
        table.sort(t, cmp)
    end
    sort(bankmenu)
    reabank.menu = bankmenu
    return bankmenu
end

return reabank