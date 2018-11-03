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
        local w = vbox:add(rtk.Label:new({label=string.format("Foobar %d", i)}))
        if i == 4446 then
            w:attr('position', rtk.Widget.FIXED)
            w.onhover2 = function(self)
                reaper.ShowMessageBox('HOVER', 'foo', 0)
                return true
                -- log("vp? %s", self.viewport.viewport.ch)
            end
        end
    end
    return vbox
end

function makebox()
    local b = rtk.VBox:new()
    b:add(rtk.CheckBox:new({label="Checkbox!"})).onchange= function(self)
        log("check changed: %s", self.value)
    end
    -- fill(b, 1, 100)
    local subbox = rtk.VBox:new({w=nil})
    log("Red box %s", subbox.id)
    subbox.bg = '#ff0000'
    fill(subbox, 4444, 4470)
    b:add(rtk.Viewport({child=subbox, h=100}))

    -- It's hideously broken with fill=0.  Because with expand=1, fill=1, boxh goes negative.
    -- b:add(subbox, {expandx=1, fill=0, fillx=1})
    -- b:resize(0.9, nil)
    return fill(b, 101, 200)
end

function screen.init()
    log("init test screen")

    screen.toolbar = rtk.HBox:new({spacing=0})
    -- Back button: return to bank list
    local back_button = app:make_button("arrow_back_white_18x18.png", "Back")
    back_button.onclick = function()
        app:pop_screen()
    end
    screen.toolbar:add(back_button)

    local track_button = app:make_button("view_list_white_18x18.png")
    screen.toolbar:add(track_button, {rpadding=0})
    track_button.onclick = function()
        app:push_screen('test2')
    end
    screen.toolbar:add(rtk.HBox.FLEXSPACE)

    screen.widget = rtk.Container:new()
    -- local img = rtk.ImageBox:new({image=app:get_image('room.jpg'), z=0})
    -- screen.widget:add(img)
    screen.widget:add(rtk.Label:new({label="TESTING!", color='#ff5050', fontsize=76, y=50, x=50, z=50}))
    -- screen.widget:add(rtk.CheckBox:new())

    local vbox = screen.widget:add(rtk.HBox:new(), {fillx=1})
    -- vbox = screen.widget
    log("Green box is %s", vbox.id)
    vbox.bg = '#00ff00'

    local b1 = makebox()
    b1.bg = '#ff00ff'
    log("Purple box is %s", b1.id)
    local vp = vbox:add(rtk.Viewport({child=b1}), {expand=0, fillw=true, lpadding=0})
    log("b1 vp is %s", vp.id)
    -- vbox:add(b1, {expand=1})

    local b2 = makebox()
    log("Blue box is %s", b2.id)
    b2.bg = '#0000ff'
    local vp = vbox:add(rtk.Viewport({child=b2}), {expand=1, fillw=false, lpadding=0})
    log("b2 vp is %s", vp.id)
    -- vbox:add(b2)
    -- vbox:add(b2, {expand=1, fillx=true, lpadding=0})
    -- vp:scrollto(0, 1500)
    -- app.viewport:scrollto(0, 1500)

end

function screen.update()
end     

return screen
