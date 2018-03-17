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
local feedback = require 'feedback'


local screen = {
    widget = nil,
    midi_device_menu = nil
}

local function make_section(title)
    local heading = rtk.Heading:new({label=title})
    screen.widget:add(heading, {
        lpadding=10, tpadding=50, bpadding=20
    })
    return screen.widget:add(rtk.VBox:new({spacing=10, lpadding=20, bpadding=0}))
end

local function add_row(section, label, w, spacing)
    local row = section:add(rtk.HBox:new({spacing=10}), {spacing=spacing})
    row:add(
        rtk.Label:new({label=label, w=w, halign=rtk.Widget.RIGHT}),
        {valign=rtk.Widget.CENTER}
    )
    return row
end

function screen.init()
    screen.widget = rtk.widget:add(rtk.VBox:new())
    screen.toolbar = rtk.HBox:new({spacing=0})

    -- Back button: return to bank list
    local back_button = make_button("arrow_back_white_18x18.png", "Back")
    back_button.onclick = function()
        App.screens.pop()
    end
    screen.toolbar:add(back_button)

    local section = make_section("CC Feedback to Control Surface")
    local row = add_row(section, "MIDI Device:", 75, 2)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}), {expand=1, fill=true, rpadding=10})
    menu.onchange = function(menu)
        log("Changed MIDI CC feedback device: %s", menu.selected_id)
        last_device = App.config.cc_feedback_device
        App.config.cc_feedback_device = tonumber(menu.selected_id)
        App.save_config()
        -- Remove output device if we disabled feedback and the current output device is set
        -- to the previously configured feedback device.
        if App.config.cc_feedback_device == -1 then
            feedback.destroy_feedback_track()
        else
            feedback.ensure_feedback_track()
            feedback.update_feedback_track_settings()
            feedback.ontrackchange(nil, App.track)
        end
    end
    screen.midi_device_menu = menu

    local row = add_row(section, "", 75)
    local info = row:add(rtk.Label:new(), {valign=rtk.Widget.CENTER, spacing=20})
    info:attr('label', 'Device must be enabled for output.')
    info.onclick = function()
        -- If the label is clicked open the Prefs dialog.
        reaper.Main_OnCommandEx(40016, 0, 0)
    end

    local row = add_row(section, "MIDI Bus:", 75)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    menu:setmenu({'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'})
    menu:select(App.config.cc_feedback_bus or 1)
    menu.onchange = function(menu)
        log("Changed MIDI CC feedback bus: %s", menu.selected)
        App.config.cc_feedback_bus = menu.selected
        App.save_config()
        feedback.update_feedback_track_settings()
        feedback.ontrackchange(nil, App.track)
    end


    local section = make_section("Misc Settings")
    local row = add_row(section, "Debug:", 75)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    menu:setmenu({'Disabled', 'Enabled'})
    menu:select((App.config.debug_level or 0) + 1)
    menu.onchange = function(menu)
        App.set_debug(menu.selected - 1)
    end
end

function screen.update()
    local menu = {{"Disabled", '-1'}}
    for output = 0, reaper.GetNumMIDIOutputs() - 1 do
        retval, name = reaper.GetMIDIOutputName(output, "")
        if retval then
            menu[#menu+1] = {name, tostring(output)}
        end
    end
    screen.midi_device_menu:setmenu(menu)
    screen.midi_device_menu:select(tostring(App.config.cc_feedback_device) or 1)
end

return screen
