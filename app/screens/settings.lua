-- Copyright 2017 Jason Tackaberry
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
}

function screen.init()
    screen.widget = rtk.widget:add(rtk.VBox:new())
    screen.toolbar = rtk.HBox:new({spacing=0})

    -- Back button: return to bank list
    local back_button = make_button("arrow_back_white_18x18.png", "Back")
    back_button.onclick = function()
        App.screens.pop()
    end
    screen.toolbar:add(back_button)

    local heading = rtk.Heading:new({label="Settings"})
    screen.widget:add(heading, {
        lpadding=10, tpadding=50, bpadding=20
    })

    local section = screen.widget:add(rtk.VBox:new({spacing=10, lpadding=20, bpadding=20}))
    local row = section:add(rtk.HBox:new({spacing=10}))
    row:add(rtk.Label:new({label='Debug:'}), {valign=rtk.Widget.CENTER})
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    menu:setmenu({'Disabled', 'Enabled'})
    menu:attr('selected', (App.config.debug_level or 0) + 1)
    menu.onchange = function(menu)
        App.set_debug(menu.selected - 1)
    end
    screen.update()
end

function screen.update()
end

return screen
