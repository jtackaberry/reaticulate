
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


local rtk = require 'lib.rtk'
local rfx = require 'rfx'

local screen = {
    widget = nil
}

function screen.init()
    screen.widget = rtk.widget:add(rtk.VBox:new(), {halign=rtk.Widget.CENTER, valign=rtk.Widget.CENTER})

    screen.label1 = rtk.Label:new({fontsize=24, color={1, 1, 1, 0.5}})
    screen.widget:add(screen.label1, {halign=rtk.Widget.CENTER})

    screen.label2 = rtk.Label:new({fontsize=24, color={1, 1, 1, 0.5}})
    screen.widget:add(screen.label2, {halign=rtk.Widget.CENTER})

    screen.label3 = rtk.Label:new({label="Unbypass FX chain to enable.", color={1, 1, 1, 0.5}})
    screen.widget:add(screen.label3, {halign=rtk.Widget.CENTER, tpadding=20})

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
        local fx = reaper.TrackFX_AddByName(App.track, 'Reaticulate.jsfx', 0, 1)
        for fx = fx, 0, -1 do
            reaper.SNM_MoveOrRemoveTrackFX(App.track, fx, -1)
        end
        reaper.Undo_EndBlock("Add Reaticulate FX", -1)
        reaper.PreventUIRefresh(-1)
        rfx.sync(rfx.track, true)
        screen.update()
    end

    screen.widget:add(screen.button, {halign=rtk.Widget.CENTER, tpadding=20})
end

function screen.update()
    -- Enable the add FX button only if the FX chain isn't bypassed.
    -- If it is bypassed then show the label that says so.
    if App.track then
        screen.label1:attr('label', 'Reaticulate is not')
        screen.label2:attr('label', 'enabled for this track')
        screen.label2:show()
        local enabled = reaper.GetMediaTrackInfo_Value(App.track, "I_FXEN")
        if enabled == 1 then
            screen.label3:hide()
            screen.button:show()
        else
            screen.label3:show()
            screen.button:hide()
        end
    else
        screen.label1:attr('label', 'No track selected')
        screen.label2:hide()
        screen.label3:hide()
        screen.button:hide()
    end
end

return screen
