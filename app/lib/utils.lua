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

-- Common utility functions.

local rtk = require 'rtk'
local log = rtk.log
Path = {
    sep = package.config:sub(1, 1),
    resourcedir = reaper.GetResourcePath()
}

function Path.init(basedir)
    Path.basedir = basedir
end

Path.join = function(first, ...)
    local args = {...}
    local joined = first
    local prev = first
    for _, part in ipairs(args) do
        if prev:sub(-1) ~= Path.sep then
            joined = joined .. Path.sep .. part
        else
            joined = joined .. part
        end
        prev = part
    end
    return joined
end


local notes = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'}
-- Given a note number between 0-127, returns the stringified note name (e.g. 'C4').
--
-- The octave respects REAPER's "MIDI octave name display offset" setting.
function note_to_name(note)
    local offset = 2 - reaper.SNM_GetIntConfigVar("midioctoffs", 0)
    return string.format('%s%d', notes[(note % 12) + 1], math.floor(note / 12) - offset)
end

-- Returns a table containing positional elements for all arguments passed to this
-- function, with nil values filtered out.
function as_filtered_table(...)
    local args = table.pack(...)
    local new = {}
    for i = 1, args.n do
        local v = args[i]
        if v ~= nil then
            new[#new+1] = v
        end
    end
    return new
end

-- Remaps the MSB/LSB of all bank select (CC0 + CC32) events on a track based on
-- the given MSB/LSB map.
--
-- msblsbmap is in the form {srcmsb -> {srclsb -> {dstmsb, dstlsb, Bank object}}, ...}.
--
-- If there is a src MSB/LSB of -1/-1 then this is used as a fallback when the actual
-- source MSB/LSB isn't found in the map.
function remap_bank_select_multiple(track, msblsbmap)
    log.info('utils: remap bank selects: %s', table.tostring(msblsbmap))
    -- channel -> {srcmsb, cc0-ccidx, lsbmap}
    local lastmsb = {}
    local n_remapped = 0
    for itemidx = 0, reaper.CountTrackMediaItems(track) - 1 do
        -- Fetch item and see if there are any MIDI CC events (that
        -- could possibly be program changes)
        local item = reaper.GetTrackMediaItem(track, itemidx)
        for takeidx = 0, reaper.CountTakes(item) - 1 do
            local dosort = false
            local take = reaper.GetTake(item, takeidx)
            local _, _, numccs, _ = reaper.MIDI_CountEvts(take)
            for ccidx = 0, numccs - 1 do
                local r, selected, muted, evtppq, command, evtchan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
                if command == 0xb0 then
                    if msg2 == 0 then
                        local lsbmap = msblsbmap[msg3] or msblsbmap[-1]
                        if lsbmap then
                            lastmsb[evtchan] = {msg3, ccidx, lsbmap}
                        end
                    elseif msg2 == 32 and lastmsb[evtchan] then
                        local srcmsb, srcidx, lsbmap = table.unpack(lastmsb[evtchan])
                        local targetmap = lsbmap[msg3] or lsbmap[-1]
                        if targetmap then
                            local dstmsb, dstlsb, bank = table.unpack(targetmap)
                            if dstmsb and (srcmsb ~= dstmsb or msg3 ~= dstlsb) then
                                reaper.MIDI_SetCC(take, srcidx, nil, nil, nil, nil, nil, nil, dstmsb, true)
                                reaper.MIDI_SetCC(take, ccidx, nil, nil, nil, nil, nil, nil, dstlsb, true)
                                n_remapped = n_remapped + 1
                                dosort = true
                            end
                        end
                        lastmsb[evtchan] = nil
                    end
                end
            end
            if dosort then
                reaper.MIDI_Sort(take)
            end
        end
    end
    return n_remapped
end

function remap_bank_select(track, frombank, tobank)
    if not reaper.ValidatePtr2(0, track, "MediaTrack*") then
        return 0
    end
    if not tobank then
        log.warning('remap_bank_select: target bank is nil')
        return 0
    end
    local tomsb, tolsb, frommsb, fromlsb
    if #tobank == 2 then
        tomsb, tolsb = table.unpack(tobank)
    else
        tomsb, tolsb = tobank:get_current_msb_lsb()
    end
    if not tomsb then
        log.warning('remap_bank_select: target bank %s has no MSB/LSB mapping in project', tobank.name)
        return 0
    end
    if frombank then
        if #frombank == 2 then
            frommsb, fromlsb = table.unpack(frombank)
        else
            frommsb, fromlsb = frombank:get_current_msb_lsb()
        end
        if not frommsb then
            log.warning('remap_bank_select: source bank %s has no MSB/LSB mapping in project', frombank.name)
            return 0
        end
    else
        -- No from bank specified, translate all events.
        frommsb = -1
        fromlsb = -1
    end
    reaper.Undo_BeginBlock2(0)
    local n = remap_bank_select_multiple(track, {[frommsb]={[fromlsb]={tomsb, tolsb, tobank}}})
    reaper.Undo_EndBlock2(0, 'Reaticulate: update Bank Select events', UNDO_STATE_ITEMS)
    return n
end

function call_and_preserve_selected_tracks(func, ...)
    local selected = {}
    for i = 0, reaper.CountSelectedTracks(0) - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local n = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
        selected[n] = true
    end
    reaper.PreventUIRefresh(1)
    local r = func(...)
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local n = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
        reaper.SetTrackSelected(track, selected[n] or false)
    end
    reaper.PreventUIRefresh(-1)
    return r
end