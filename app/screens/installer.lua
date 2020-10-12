
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


local rtk = require 'lib.rtk'
local rfx = require 'rfx'

local screen = {
    widget = nil
}

function screen.init()
    screen.widget = rtk.Container()
    local box = screen.widget:add(rtk.VBox(), {halign='center', valign='center', expand=1})

    screen.icon = rtk.ImageBox{image='96-alert_circle_outline', alpha=0.5}
    box:add(screen.icon, {halign='center', bpadding=20})

    screen.message = rtk.Label{fontsize=24, alpha=0.5, wrap=true, textalign='center'}
    box:add(screen.message, {halign='center', lpadding=10, rpadding=10})

    screen.button = rtk.Button{
        icon='18-add_circle_outline', label="Add Reaticulate FX",
        space=10, alpha=0.8,
        tpadding=5, bpadding=5, lpadding=5, rpadding=10
    }
    screen.button.onclick = function()
        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock()
        local fx = reaper.TrackFX_AddByName(app.track, 'Reaticulate.jsfx', 0, 1)
        reaper.TrackFX_Show(app.track, fx, 2)
        reaper.TrackFX_CopyToTrack(app.track, fx, app.track, 0, true)
        reaper.Undo_EndBlock("Add Reaticulate FX", UNDO_STATE_FX)
        reaper.PreventUIRefresh(-1)
        rfx.sync(rfx.track, true)
        -- Trigger the track changed callback to ensure any actions dependend on the RFX are
        -- triggered now that we've instantiated it.
        app:ontrackchange(nil, rfx.track)
        screen.update()
    end

    box:add(screen.button, {halign='center', tpadding=20})
end

function screen.update()
    -- Enable the add FX button only if the FX chain isn't bypassed.
    -- If it is bypassed then show the label that says so.
    local label = 'No track selected'
    if app.track then
        local enabled = reaper.GetMediaTrackInfo_Value(app.track, "I_FXEN")
        if enabled == 1 then
            if rfx.error and rfx.error ~= rfx.ERROR_MISSING_RFX then
                if rfx.error == rfx.ERROR_RFX_BYPASSED then
                    label = 'The Reaticulate FX on this track is bypassed'
                elseif rfx.error == rfx.ERROR_UNSUPPORTED_VERSION then
                    label = 'The version of the Reaticulate FX on this track is not supported.\nTry restarting Reaper to ensure the latest versions of all scripts are running.'
                elseif rfx.error == rfx.ERROR_BAD_MAGIC then
                    label = 'The Reaticulate FX on this track is not recognized.'
                else
                    label = string.format('An unknown error has occurred with the Reaticulate FX (%s)', rfx.error)
                end
                screen.icon:show()
                screen.button:hide()
            else
                label = 'Reaticulate is not enabled for this track'
                screen.icon:hide()
                screen.button:show()
            end
        else
            label = 'Unbypass FX chain to enable'
            screen.icon:show()
            screen.button:hide()
        end
    else
        screen.icon:hide()
        screen.button:hide()
    end
    if label ~= screen.message.label then
        screen.message:attr('label', label)
    end
end

return screen
