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

local screen = {
    widget = nil,
    toolbar = nil
}

function fill(vbox, t1, t2)
    for i = t1, t2 do
        vbox:add(rtk.Label:new({label=string.format("Foobar %d", i)}))
    end
    return vbox
end

function makebox()
    local b = fill(rtk.VBox:new(), 1, 100)
    local subbox = rtk.VBox:new()
    fill(subbox, 4444, 4470)
    b:add(rtk.Viewport({child=subbox, h=100}))
    return fill(b, 101, 200)
end

function screen.init()
    screen.toolbar = rtk.HBox:new({spacing=0})
    local track_button = app:make_button("edit_white_18x18.png")
    screen.toolbar:add(track_button, {rpadding=0})
    track_button.onclick = function()
        app:push_screen('test')
    end
    screen.toolbar:add(rtk.HBox.FLEXSPACE)

    screen.widget = rtk.Container()
    local img = rtk.ImageBox:new({image=app:get_image('room.jpg'), halign=rtk.Widget.CENTER})
    screen.widget:add(img)
end

function screen.update()
end

return screen
