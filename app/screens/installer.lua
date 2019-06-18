
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
    screen.widget = rtk.Container:new()
    local box = screen.widget:add(rtk.VBox:new(), {halign=rtk.Widget.CENTER, valign=rtk.Widget.CENTER, expand=1})

    screen.message = rtk.Label:new({fontsize=24, color={1, 1, 1, 0.5}, wrap=true, textalign=rtk.Widget.CENTER})
    box:add(screen.message, {halign=rtk.Widget.CENTER})

    icon = rtk.Image:new(Path.join(Path.imagedir, "add_circle_outline_white_18x18.png"))
    screen.button = rtk.Button:new({
        icon=icon, label="Add Reaticulate FX", space=10,
        color={0.3, 0.3, 0.3, 1},
        tpadding=5, bpadding=5, lpadding=5, rpadding=10
    })
    screen.button.onclick = function()
        -- This is infuriating and much lamer than it should be just to install an FX
        -- at the top of the chain.  I pine for mature APIs.
        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock()
        local fx = reaper.TrackFX_AddByName(app.track, 'Reaticulate.jsfx', 0, 1)
        reaper.TrackFX_CopyToTrack(app.track, fx, app.track, 0, true)
        reaper.Undo_EndBlock("Add Reaticulate FX", -1)
        reaper.PreventUIRefresh(-1)
        rfx.sync(rfx.track, true)
        -- Trigger the track changed callback to ensure any actions dependend on the RFX are
        -- triggered now that we've instantiated it.
        app:ontrackchange(nil, rfx.track)
        screen.update()
    end

    box:add(screen.button, {halign=rtk.Widget.CENTER, tpadding=20})
end

function screen.update()
    -- Enable the add FX button only if the FX chain isn't bypassed.
    -- If it is bypassed then show the label that says so.
    local label = 'No track selected'
    if app.track then
        local enabled = reaper.GetMediaTrackInfo_Value(app.track, "I_FXEN")
        if enabled == 1 then
            label = 'Reaticulate is not enabled for this track'
            screen.button:show()
        else
            label = 'Unbypass FX chain to enable'
            screen.button:hide()
        end
    else
        screen.button:hide()
    end
    if label ~= screen.message.label then
        screen.message:attr('label', label)
    end
end

return screen
