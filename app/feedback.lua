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

local rfx = require 'rfx'

local feedback = {
    track = nil,
}

-- A special value we set on the BUS Translator JSFX to identify whether the instance
-- was instantiated by Reaticulate.
local BUS_TRANSLATOR_MAGIC = 0x42424242


function feedback.ontrackchange(last, cur)
    if (App.config.cc_feedback_device or -1) < 0 then
        -- No feedback enabled.
        return
    end
    rfx.push_state()
    if last and reaper.ValidatePtr2(0, last, "MediaTrack*") then
        rfx.push_state(last)
        feedback._set_track_enabled(last, 0)
        rfx.pop_state()
    end
    if cur and rfx.fx then
        -- Track must be monitored for MIDI input for CC feedback to be triggered.
        local input = reaper.GetMediaTrackInfo_Value(cur, "I_RECINPUT")
        rfx.push_state(cur)
        if input and input & 4096 ~= 0 then
            -- Indicate to RFX that it should start sending CCs to bus 16
            feedback._set_track_enabled(cur, 1)
            if feedback.install_feedback(cur) then
                -- Feedback send was just created (not already there), so we need to take
                -- care of some niggles.  Notably if mixer is supposed to scroll to
                -- selected track, the scroll position is broken after the send is installed
                -- (sigh), so we reset it.  Also, we must defer dumping CCs for a few cycles
                -- otherwise they go into a blackhole -- ostensibly Reaper needs some time to
                -- realize there is a new send.
                feedback.scroll_mixer(cur)
                cycles = 5
                function dump()
                    if cycles == 0 then
                        -- This is done asynchronously, so use the public version of dump_ccs() which
                        -- pushes/pops automation settings.
                        feedback.dump_ccs(cur)
                    else
                        cycles = cycles - 1
                        reaper.defer(dump)
                    end
                end
                reaper.defer(dump)
            else
                -- CCs can be dumped immediately as send already exists.
                feedback._dump_ccs()
            end
            -- rfx.pop_state()
        end
        rfx.pop_state()
    end
    rfx.pop_state()
end

function feedback.scroll_mixer(track)
    local scroll_mixer = reaper.GetToggleCommandStateEx(0, 40221)
    if scroll_mixer and track then
        function scroll()
            reaper.SetMixerScroll(track)
        end
        scroll()
        reaper.defer(scroll)
    end
end


function feedback.get_feedback_send(track)
    local feedback_track = feedback.get_feedback_track()
    if feedback_track then
        for idx = 0, reaper.GetTrackNumSends(track, 0) -1 do
            local target = reaper.BR_GetMediaTrackSendInfo_Track(track, 0, idx, 1)
            local flags = reaper.GetTrackSendInfo_Value(track, 0, idx, 'I_MIDIFLAGS')
            if target == feedback_track then
                return idx
            end
        end
    end
    return nil
end

-- Installs feedback for a given track.  If no feedback track exists, then one is
-- created.  Assumes caller has already ensured feedback is enabled by user.
--
-- Returns false if feedback was already installed, and true otherwise.
function feedback.install_feedback(track)
    local feedback_track = feedback.ensure_feedback_track()
    if feedback.get_feedback_send(track) then
        return false
    else
        -- No feedback send, so create one.
        local idx = reaper.CreateTrackSend(track, feedback_track)
        reaper.SetTrackSendInfo_Value(track, 0, idx, 'I_SRCCHAN', -1)
        -- Reaper's API documentation does not explain how MIDI buses are encoded.  Empirically
        -- bit 18 needs to be on to indicate all channels on bus 16.
        reaper.SetTrackSendInfo_Value(track, 0, idx, 'I_MIDIFLAGS', 1 << 18)
        return true
    end
end

function feedback._set_track_enabled(track, enabled)
    local device = App.config.cc_feedback_device - 1
    local bus = 15
    if App.config.cc_feedback_device < 0 then
        enabled = 0
    end
    -- FIXME: not validated, can't easily call rfx.validate()
    local fx = rfx.get(track)
    if fx >= 0 and rfx.params then
        local param = enabled + (bus << 8) + ((rfx.OPCODE_SET_CC_FEEDBACK_ENABLED & 0x7f) << 24)
        reaper.TrackFX_SetParam(track, fx, rfx.params.opcode, param)
    end
end


function feedback.get_feedback_track()
    if feedback.track and reaper.ValidatePtr2(0, feedback.track, "MediaTrack*") then
        return feedback.track
    end
    -- Locate feedback track (whichever track has the BUS Translator FX)
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local fx = reaper.TrackFX_GetByName(track, "BUS Translator", false)
        if fx >= 0 then
            -- Test magic value to ensure this instance was one created by Reaticulate
            local val, _, _ = reaper.TrackFX_GetParam(track, fx, 3)
            if val == BUS_TRANSLATOR_MAGIC then
                -- Remember for future calls
                feedback.track = track
                return track
            end
        end
    end
    return nil
end

-- Creates a track for MIDI feedback.  Assumes the caller has already checked that
-- none already exists via get_feedback_track().
function feedback.create_feedback_track()
    reaper.PreventUIRefresh(1)
    local idx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(idx, false)
    feedback.track = reaper.GetTrack(0, idx)
    reaper.GetSetMediaTrackInfo_String(feedback.track, 'P_NAME', "MIDI Feedback (Reaticulate)", true)
    -- Install FX.
    local fx = reaper.TrackFX_AddByName(feedback.track, 'Feedback Translate.jsfx', 0, 1)
    feedback.update_feedback_track_settings()

    reaper.SetMediaTrackInfo_Value(feedback.track, 'B_SHOWINTCP', 0)
    reaper.SetMediaTrackInfo_Value(feedback.track, 'B_SHOWINMIXER', 0)
    feedback.scroll_mixer(App.track)
    reaper.PreventUIRefresh(-1)
    return feedback.track
end

function feedback.destroy_feedback_track()
    -- First iterate over all tracks and remove sends to feedback track
    local feedback_track = feedback.get_feedback_track()
    if feedback_track then
        for idx = 0, reaper.CountTracks(0) - 1 do
            local track = reaper.GetTrack(0, idx)
            if track then
                local send = feedback.get_feedback_send(track)
                if send then
                    reaper.RemoveTrackSend(track, 0, send)
                end
            end
        end
        reaper.DeleteTrack(feedback_track)
        feedback.track = nil
    end
end

function feedback.update_feedback_track_settings()
    local feedback_track = feedback.get_feedback_track()
    if feedback_track then
        reaper.SetMediaTrackInfo_Value(feedback_track, "I_MIDIHWOUT", App.config.cc_feedback_device << 5)
        local fx = reaper.TrackFX_GetByName(feedback_track, "BUS Translator", false)
        if fx == -1 then
            log("CC feedback is enabled but BUS Translator FX not found")
        else
            rfx.push_state(feedback_track)
            reaper.TrackFX_SetParam(feedback_track, fx, 0, App.config.cc_feedback_active and 1 or 0)
            reaper.TrackFX_SetParam(feedback_track, fx, 2, App.config.cc_feedback_bus - 1)
            reaper.TrackFX_SetParam(feedback_track, fx, 3, BUS_TRANSLATOR_MAGIC)
            rfx.pop_state()
        end
    end
end

function feedback.ensure_feedback_track()
    local feedback_track = feedback.get_feedback_track()
    if feedback_track then
        return feedback_track
    else
        return feedback.create_feedback_track()
    end
end

function feedback._dump_ccs()
    rfx.opcode(rfx.OPCODE_DUMP_CCS)
end

function feedback.dump_ccs(track)
    if App.config.cc_feedback_device == -1 or not track then
        return
    end
    rfx.push_state(track)
    feedback._dump_ccs()
    rfx.pop_state()
end

function feedback.set_active(active)
    App.config.cc_feedback_active = active
    feedback.update_feedback_track_settings()
end

return feedback
