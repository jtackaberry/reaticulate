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


local rtk = require 'rtk'
local rfx = require 'rfx'

local screen = {
    widget = nil,
    last_fx_enabled = nil,
    last_track = nil,
}

function screen.init()
    screen.widget = rtk.Container()
    local box = screen.widget:add(rtk.VBox(), {halign='center', valign='center', expand=1})

    screen.icon = rtk.ImageBox{image='huge-alert_circle_outline', alpha=0.5, scale=1}
    box:add(screen.icon, {halign='center'})

    screen.message = rtk.Text{fontsize=24, alpha=0.5, wrap=true, padding=5, textalign='center'}
    box:add(screen.message, {halign='center', tpadding=10})
    -- box.debug=true

    screen.button = rtk.Button{'Add Reaticulate FX', icon='med-add_circle_outline', alpha=0.8}
    screen.button.onclick = function()
        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock()
        -- First clear any existing track data that might exist from a previous instance
        reaper.GetSetMediaTrackInfo_String(app.track, 'P_EXT:reaticulate', '', true)
        local fx = reaper.TrackFX_AddByName(app.track, 'Reaticulate.jsfx', 0, 1)
        -- Hide window if floating
        reaper.TrackFX_Show(app.track, fx, 2)
        -- Move FX to first slot
        reaper.TrackFX_CopyToTrack(app.track, fx, app.track, 0, true)
        reaper.Undo_EndBlock("Add Reaticulate FX", UNDO_STATE_FX)
        reaper.PreventUIRefresh(-1)
        rfx.current:sync(app.track, true)
        -- Trigger the track changed callback to ensure any actions dependend on the RFX are
        -- triggered now that we've instantiated it.
        app:ontrackchange(nil, app.track)
        screen.update()
    end

    box:add(screen.button, {halign='center', tpadding=20})
end

function screen.update()
    -- Enable the add FX button only if the FX chain isn't bypassed.
    -- If it is bypassed then show the label that says so.
    local text = 'No track selected'
    if app.track then
        local enabled = reaper.GetMediaTrackInfo_Value(app.track, "I_FXEN")
        if app.track == screen.last_track and enabled == screen.last_fx_enabled then
            return
        end
        screen.last_fx_enabled = enabled
        if enabled == 1 then
            local err = rfx.current.error
            if err and err ~= rfx.ERROR_MISSING_RFX then
                if err == rfx.ERROR_RFX_BYPASSED then
                    text = 'The Reaticulate FX on this track is bypassed'
                elseif err == rfx.ERROR_UNSUPPORTED_VERSION then
                    text = 'The version of the Reaticulate FX on this track is not supported.\nTry restarting Reaper to ensure the latest versions of all scripts are running.'
                elseif err == rfx.ERROR_BAD_MAGIC then
                    text = 'The Reaticulate FX on this track is not recognized.'
                else
                    text = string.format('An unknown error has occurred with the Reaticulate FX (%s)', err)
                end
                screen.icon:show()
                screen.button:hide()
            else
                text = 'Reaticulate is not enabled for this track'
                screen.icon:hide()
                screen.button:show()
            end
        else
            text = 'Unbypass FX chain to enable'
            screen.icon:show()
            screen.button:hide()
        end
    else
        screen.icon:hide()
        screen.button:hide()
    end
    if text ~= screen.message.label then
        screen.message:attr('text', text)
    end
    screen.last_track = app.track
end

return screen
