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

local log = require 'lib.log'
local rtk = require 'lib.rtk'
local feedback = require 'feedback'


local screen = {
    widget = nil,
    midi_device_menu = nil,
    warning_icon = nil,
}


local startup_script = [[
-- Begin Reaticulate startup stanza (don't edit this line)
local sep = package.config:sub(1, 1)
local script = debug.getinfo(1, 'S').source:sub(2)
local basedir = script:gsub('(.*)' .. sep .. '.*$', '%1')
dofile(basedir .. sep .. 'Reaticulate' .. sep .. 'actions' .. sep .. 'Reaticulate_Start.lua')
-- End Reaticulate startup stanza (don't edit this line)
]]

local function update_startup_action(start)
    local scriptfile = Path.join(reaper.GetResourcePath(), 'Scripts', '__startup.lua')
    local script = read_file(scriptfile) or ''
    name = name:gsub("%^a", "")
    script = script:gsub('-- Begin Reaticulate.*-- End Reaticulate[^\n]*\n*', '')
    if start then
        script = script .. '\n\n' .. startup_script
    end
    write_file(scriptfile, script)
end


local function make_section(title)
    local heading = rtk.Heading:new({label=title})
    screen.vbox:add(heading, {
        lpadding=10, tpadding=20, bpadding=15
    })
    return screen.vbox:add(rtk.VBox:new({spacing=10, lpadding=20, bpadding=20}))
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
    screen.warning_icon = app:get_image("warning_amber_24x24.png")
    screen.vbox = rtk.VBox({rpadding=10})
    screen.widget = rtk.Viewport({child=screen.vbox})
    screen.toolbar = rtk.HBox:new({spacing=0})

    -- Back button: return to bank list
    local back_button = app:make_button("arrow_back_white_18x18.png", "Back")
    back_button.onclick = function()
        app:pop_screen()
    end
    screen.toolbar:add(back_button)



    --
    -- Section: Behavior
    --
    local section = make_section("Behavior")
    screen.cb_track_follows_midi_editor = rtk.CheckBox({
        wrap=true,
        ivalign=rtk.Widget.TOP,
        label="Track selection follows MIDI editor target item"
    })
    screen.cb_track_follows_midi_editor.onchange = function(cb)
        app:set_toggle_option('track_selection_follows_midi_editor', cb.value, true)
    end
    section:add(screen.cb_track_follows_midi_editor)

    screen.cb_track_follows_fx_focus = rtk.CheckBox({
        wrap=true,
        ivalign=rtk.Widget.TOP,
        label="Track selection follows FX focus"
    })
    screen.cb_track_follows_fx_focus.onchange = function(cb)
        app:set_toggle_option('track_selection_follows_fx_focus', cb.value, true)
    end

    if rtk.has_js_reascript_api then
        section:add(screen.cb_track_follows_fx_focus)
    end

    --
    -- Section: Feedback to Control Surface
    --
    local section = make_section("Feedback to Control Surface")
    local row = add_row(section, "MIDI Device:", 75, 2)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    menu.onchange = function(menu)
        log.info("settings: changed MIDI CC feedback device: %s", menu.selected_id)
        last_device = app.config.cc_feedback_device
        app.config.cc_feedback_device = tonumber(menu.selected_id)
        app:save_config()
        -- Remove output device if we disabled feedback and the current output device is set
        -- to the previously configured feedback device.
        if app.config.cc_feedback_device == -1 then
            feedback.destroy_feedback_track()
        else
            feedback.ensure_feedback_track()
            feedback.update_feedback_track_settings(true)
        end
        -- If we enabled/disabled feedback, re-check for bus 16 conflicts.
        app:check_banks_for_errors()
    end
    screen.midi_device_menu = menu

    local row = add_row(section, "", 75)
    local info = row:add(rtk.Label:new({focusable=true, wrap=true}), {valign=rtk.Widget.CENTER, spacing=20})
    info:attr('label', 'Device must be enabled for output.')
    info.onmouseenter = function() return true end
    info.onclick = function()
        -- If the label is clicked open the Prefs dialog.
        reaper.Main_OnCommandEx(40016, 0, 0)
    end

    local row = add_row(section, "MIDI Bus:", 75)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    menu:setmenu({'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'})
    menu:select(app.config.cc_feedback_bus or 1)
    menu.onchange = function(menu)
        log.info("settings: changed MIDI CC feedback bus: %s", menu.selected)
        app.config.cc_feedback_bus = menu.selected
        app:save_config()
        feedback.update_feedback_track_settings(true)
    end

    local row = add_row(section, "Articulations:", 75)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    menu:setmenu({"Program Changes", "CC values"})

    local row = add_row(section, "CC #:", 75)
    local text = row:add(rtk.Entry:new({label="CC number", w=75}))
    text.onchange = function(text)
        -- TODO: validate value is a number
        app.config.cc_feedback_articulations_cc = tonumber(text.value)
        app:save_config()
        feedback.update_feedback_track_settings(true)
    end
    menu.onchange = function(menu)
        app.config.cc_feedback_articulations = menu.selected
        if menu.selected == 1 then
            row:hide()
        else
            if app.config.cc_feedback_articulations_cc > 0 then
                text:attr('value', tostring(app.config.cc_feedback_articulations_cc))
            end
            row:show()
        end
        feedback.update_feedback_track_settings(true)
        app:save_config()
    end
    menu:select(app.config.cc_feedback_articulations or 2)



    --
    -- Section: Misc Settings
    --
    local section = make_section("Misc Settings")
    local row = add_row(section, "Autostart:", 75)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    menu:setmenu({'Never', 'When REAPER starts'})
    menu:select((app.config.autostart or 0) + 1)
    menu.onchange = function(menu)
        update_startup_action(menu.selected == 2)
        app.config.autostart = menu.selected - 1
        app:save_config()
    end

    local row = add_row(section, "Log Level:", 75)
    local menu = row:add(rtk.OptionMenu:new({tpadding=3, bpadding=3}))
    -- Populate optionmenu with title-cased log levels
    local options = {}
    for level, name in pairs(log.levels) do
        name = name:sub(1, 1):upper() .. name:sub(2):lower()
        options[#options+1] = {name, level}
    end
    table.sort(options, function(a, b) return a[2] > b[2] end)
    menu:setmenu(options)
    menu:select(app.config.debug_level or log.ERROR)
    menu.onchange = function(menu)
        app:set_debug(tonumber(menu.selected_id))
    end


    -- Show a warning if the js_ReaScriptAPI isn't installed.
    if not rtk.has_js_reascript_api then
        local hbox = screen.vbox:add(rtk.HBox:new({spacing=10}), {tpadding=50, lpadding=20, rpadding=20})
        hbox:add(rtk.ImageBox:new({image=screen.warning_icon}), {valign=rtk.Widget.TOP})
        local vbox = hbox:add(rtk.VBox())
        local label = vbox:add(rtk.Label({wrap=true}), {valign=rtk.Widget.CENTER})
        label:attr(
            'label',
            "Reaticulate runs best when the js_ReaScriptAPI extension is installed."
        )
        local button = vbox:add(
            rtk.Button({label="Download", tpadding=5, bpadding=5, lpadding=5, rpadding=5}),
            {tpadding=10}
        )
        button.onclick = function()
            open_url('https://forum.cockos.com/showthread.php?t=212174')
        end
    end

    local button = screen.vbox:add(
        rtk.Button({
            label="Reaticulate Website",
            icon=app:get_image("link_18x18.png"),
            color=rtk.theme.accent_subtle,
            cursor=rtk.mouse.cursors.hand,
            flags=rtk.Button.FLAT,
            tpadding=7, bpadding=7, lpadding=10, rpadding=10,
            alpha=0.6
        }),
        {tpadding=40, halign='center'}
    )
    button.onclick = function()
        open_url('https://reaticulate.com')
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
    screen.midi_device_menu:select(tostring(app.config.cc_feedback_device) or 1)
    screen.cb_track_follows_fx_focus:attr('value', app:get_toggle_option('track_selection_follows_fx_focus'), false)
    screen.cb_track_follows_midi_editor:attr('value', app:get_toggle_option('track_selection_follows_midi_editor'), false)
end

return screen
