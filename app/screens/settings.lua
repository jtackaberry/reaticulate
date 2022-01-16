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
local feedback = require 'feedback'
local articons = require 'articons'
local reabank = require 'reabank'
local rfx = require 'rfx'
local metadata = require 'metadata'
local log = rtk.log

local screen = {
    minw = 200,
    widget = nil,

    -- If true, handle chase CC updates when Back button is pressed
    chase_ccs_dirty = false,

    art_colors = {
        {'Default', 'default', 'note-whole'},
        {'Short', 'short', 'note-eighth'},
        {'Short Light', 'short-light', 'staccato-con-sord'},
        {'Short Dark', 'short-dark', 'pizz-bartok'},
        {'Legato', 'legato', 'legato'},
        {'Legato Light', 'legato-light', 'legato-flautando'},
        {'Legato Dark', 'legato-dark', 'legato-sul-pont'},
        {'Long', 'long', 'note-whole'},
        {'Long Light', 'long-light', 'sul-tasto'},
        {'Long Dark', 'long-dark', 'sul-pont'},
        {'Textured', 'textured', 'frozen'},
        {'FX', 'fx', 'fx'}
    },
    art_color_entries = {}
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
    local script = rtk.file.read(scriptfile) or ''
    script = script:gsub('\n*-- Begin Reaticulate.*-- End Reaticulate[^\n]*', '')
    if start then
        script = script .. '\n\n' .. startup_script
    end
    rtk.file.write(scriptfile, script)
end


local function make_section(parent, title)
    local vbox = rtk.VBox{spacing=10, lpadding=20, bpadding=30}
    local heading = rtk.Heading{title}
    vbox:add(heading, {lpadding=-10, tpadding=20, bpadding=5})
    return parent:add(vbox)
end

local function add_row(section, label, w, spacing)
    local row = section:add(rtk.HBox{spacing=10}, {spacing=spacing})
    row.label = row:add(
        rtk.Text{label, w=w, halign=rtk.Widget.RIGHT, wrap=false},
        {valign=rtk.Widget.CENTER}
    )
    return row
end

local function add_tip(section, lpadding, text)
    local label = rtk.Text{text, wrap=true}
    return section:add(label, {lpadding=lpadding, valign='center'})
end

local function add_color_input(row, initial, default, icon, pad, onset)
    local text = row:add(rtk.Entry{placeholder=default, textwidth=7}, {valign='center', fillw=false})
    local attrs = {
        icon=icon,
        color=(initial and initial ~= '') and initial or default,
    }
    if not pad then
        attrs.padding = 2
    else
        attrs.gradient = 0
    end
    local button = row:add(rtk.Button(attrs), {valign='center', spacing=5})
    -- Spacing for the row hbox is 10, so compensate slightly with negative padding.
    local undo = row:add(rtk.Button{icon=screen.icon_undo, flat=true, lpadding=5, rpadding=5})
    undo:attr('disabled', initial == nil or initial == default or initial == '')
    undo.onclick = function()
        text:attr('value', default)
    end
    button.onclick = function()
        local bg = (text.value and #text.value > 0) and text.value or default or ''
        local hwnd = reaper.BR_Win32_HwndToString(app.window.hwnd)
        hwnd = reaper.BR_Win32_StringToHwnd(hwnd)
        local ok, color = reaper.GR_SelectColor(hwnd, rtk.color.int(bg, true))
        if ok ~= 0 then
            text:push_undo()
            text:attr('value', rtk.color.int2hex(color, true))
        end
    end
    text.onchange = function(text)
        if text.value == default then
            text:attr('value', '', false)
        end
        local bg = (text.value and #text.value > 0) and text.value or default or ''
        undo:attr('disabled', bg == default or bg == '')
        button:attr('color', bg)
        -- Only execute callback after first
        if onset then
            onset(text, button, bg)
        end
    end
    text:attr('value', initial)
    return text
end

function screen.init()
    screen.icon_undo = rtk.Image.make_icon('med-undo')

    screen.vbox = rtk.VBox{rpadding=20}
    screen.widget = rtk.Viewport{screen.vbox}
    screen.toolbar = rtk.HBox{spacing=0}

    -- Back button: return to bank list
    local back_button = rtk.Button{'Back', icon='med-arrow_back', flat=true}
    back_button.onclick = function()
        if screen.chase_ccs_dirty then
            reabank.clear_chase_cc_list_cache()
            -- Technically we should call rfx.all_tracks_sync_banks_if_hash_changed(), but
            -- it's quite slow on large projects.  We compromise by syncing the current
            -- track only, and rely on the fact that banks will automatically resync when
            -- a track is selected.
            rfx.current:sync_banks_if_hash_changed()
            screen.chase_ccs_dirty = false
        end
        app:pop_screen()
    end
    screen.toolbar:add(back_button)


    -- Show a warning if the js_ReaScriptAPI isn't installed.
    if not rtk.has_js_reascript_api then
        local hbox = screen.vbox:add(rtk.HBox{spacing=10}, {tpadding=20, bpadding=20, lpadding=20, rpadding=20})
        hbox:add(rtk.ImageBox{image='lg-warning_amber'}, {valign=rtk.Widget.TOP})
        local vbox = hbox:add(rtk.VBox())
        local text = vbox:add(rtk.Text{wrap=true}, {valign=rtk.Widget.CENTER})
        text:attr(
            'text',
            "Reaticulate runs best when the js_ReaScriptAPI extension is installed. " ..
            "Several features and user experience enhancements are disabled without it."
        )
        local button = vbox:add(rtk.Button{label="Download", tmargin=10})
        button.onclick = function()
            rtk.open_url('https://forum.cockos.com/showthread.php?t=212174')
        end
    end

    --
    -- Section: Behavior
    --
    local section = make_section(screen.vbox, "Behavior")

    -- Resize window doesn't flow properly.  vbox width is too big
    local cb = rtk.CheckBox{'Autostart Reaticulate when Reaper starts'}
    cb.onchange = function(cb)
        app.config.autostart = cb.value
        update_startup_action(app.config.autostart)
        app:save_config()
    end
    section:add(cb)
    cb:attr('value', app.config.autostart == true or app.config.autostart == 1)

    screen.cb_insert_at_note_selection = rtk.CheckBox{'Insert articulations based on selected notes when MIDI editor is open'}
    screen.cb_insert_at_note_selection.onchange = function(cb)
        app.config.art_insert_at_selected_notes = cb.value
        app:save_config()
    end
    section:add(screen.cb_insert_at_note_selection)


    screen.cb_track_follows_midi_editor = rtk.CheckBox{'Track selection follows MIDI editor target item'}
    screen.cb_track_follows_midi_editor.onchange = function(cb)
        app:set_toggle_option('track_selection_follows_midi_editor', cb.value, true)
    end
    section:add(screen.cb_track_follows_midi_editor)

    screen.cb_track_follows_fx_focus = rtk.CheckBox{'Track selection follows FX focus'}
    screen.cb_track_follows_fx_focus.onchange = function(cb)
        app:set_toggle_option('track_selection_follows_fx_focus', cb.value, true)
    end

    screen.cb_sloppy_focus = rtk.CheckBox{'Keyboard focus follows mouse within REAPER (EXPERIMENTAL)'}
    screen.cb_sloppy_focus.onchange = function(cb)
        app:set_toggle_option('keyboard_focus_follows_mouse', cb.value, true)
    end
    -- Disabled: not baked enough yet (even for experimental)
    screen.cb_sloppy_focus:hide()

    screen.cb_single_fx_instrument = rtk.CheckBox{'Single floating instrument FX window follows selected track (EXPERIMENTAL)'}
    screen.cb_single_fx_instrument.onchange = function(cb)
        app:set_toggle_option('single_floating_instrument_fx_window', cb.value, true)
        app:do_single_floating_fx()
    end

    -- These options depend on availability of js_ReaScriptAPI.
    if rtk.has_js_reascript_api then
        section:add(screen.cb_track_follows_fx_focus)
        section:add(screen.cb_sloppy_focus)
        section:add(screen.cb_single_fx_instrument)
    end

    local row = add_row(section, "Recall MIDI Channel:", 140)
    row:attr('tooltip', 'How Reaticulate should remember the default MIDI channel and sync with the MIDI editor')
    local menu = row:add(rtk.OptionMenu{
        menu={'Globally', 'Per Track', 'Per Item'},
        selected=app.config.default_channel_behavior,
    })
    menu.onchange = function(menu)
        app.config.default_channel_behavior = menu.selected_index
        app:save_config()
    end
    screen.default_channel_menu = menu

    local row = add_row(section, "Default Chase CCs:", 140)
    row:attr('tooltip', 'When not explicitly specified in banks, chase these CCs. Comma delimited with optional ranges.')
    local entry = row:add(rtk.Entry{value=app.config.chase_ccs, placeholder=reabank.DEFAULT_CHASE_CCS})
    entry.onchange = function()
        app.config.chase_ccs = entry.value
        app:save_config()
        screen.chase_ccs_dirty = true
    end

    --
    -- Section: User Interface
    --
    local section = make_section(screen.vbox, "User Interface")
    screen.cb_undocked_borderless = rtk.CheckBox{'Use borderless window when undocked'}
    screen.cb_undocked_borderless.onchange = function(cb)
        app.config.borderless = cb.value
        app.window:attr('borderless', app.config.borderless)
        app:save_config()
    end
    if rtk.has_js_reascript_api then
        section:add(screen.cb_undocked_borderless)
    end

    screen.cb_touchscroll = rtk.CheckBox{'Enable touch-scrolling for touchscreen displays'}
    screen.cb_touchscroll.onchange = function(cb)
        app.config.touchscroll = cb.value
        rtk.touchscroll = cb.value
        app:save_config()
    end
    section:add(screen.cb_touchscroll)

    screen.cb_smoothscroll = rtk.CheckBox{'Enable smoooth scrolling (in Reaticulate only)'}
    screen.cb_smoothscroll.onchange = function(cb)
        app.config.smoothscroll = cb.value
        rtk.smoothscroll = cb.value
        app:save_config()
    end
    section:add(screen.cb_smoothscroll)

    local row = add_row(section, "UI Scale:", 85, 2)
    row:attr('tooltip', "Adjusts the scale of Reaticulate's UI. You can also use ctrl-mousewheel.")
    local menu = row:add(rtk.OptionMenu{
        menu={
            {'50%', id=0.5},
            {'70%', id=0.7},
            {'80%', id=0.8},
            {'90%', id=0.9},
            {'100%', id=1.0},
            {'110%', id=1.1},
            {'120%', id=1.2},
            {'130%', id=1.3},
            {'150%', id=1.5},
            {'170%', id=1.7},
            {'200%', id=2.0},
            {'250%', id=2.5},
            {'300%', id=2.7},
        },
        selected=rtk.scale.user,
    })
    menu.onchange = function(menu, item)
        if item and item.id ~= rtk.scale.user then
            rtk.scale.user = tonumber(item.id)
            app.config.scale = rtk.scale.user
            app:save_config()
            rtk.defer(function()
                menu:scrolltoview(50, nil, nil, false)
            end)
        end
    end
    screen.ui_scale_menu = menu

    local row = add_row(section, "Background:", 85)
    add_color_input(row, app.config.bg, rtk.color.get_reaper_theme_bg(), 'med-edit', true,
        function(text, button)
            local cfgval = text.value
            if text.value ~= app.config.bg then
                app.config.bg = text.value
                app:save_config()
            end
        end
    )
    add_tip(section, 95, 'Leave blank to detect from theme. Restart required.')


    --
    -- Section: Feedback to Control Surface
    --
    local section = make_section(screen.vbox, "Feedback to Control Surface")
    local row = section:add(rtk.HBox{spacing=5, alpha=0.6, bpadding=10})
    row:add(rtk.ImageBox{'med-info_outline'})
    row:add(rtk.Text{
        wrap=true,
        'Transmit articulation changes and all CC values on the default ' ..
        'channel to the selected device. Control surfaces with motorized ' ..
        'faders will move in realtime during playback.'
    })
    local row = add_row(section, "MIDI Device:", 85, 2)
    local menu = row:add(rtk.OptionMenu())
    menu.onchange = function(menu)
        local device = tonumber(menu.selected_id)
        if app.config.cc_feedback_device == device then
            -- Nothing changed
            return
        end
        log.info('settings: new MIDI feedback device: %s', device)
        log.time_start()
        app.config.cc_feedback_device = device
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
        log.time_end('settings: finished changing MIDI feedback device')
    end
    screen.midi_device_menu = menu

    local box = section:add(rtk.HBox{tpadding=5, bpadding=0})
    local s = box:add(rtk.Spacer{w=85, h=10}, {spacing=0})
    local prefs = box:add(rtk.Button{icon='med-settings', flat=true}, {valign='center', lpadding=5})
    local info = add_tip(box, 0, 'Device must be enabled for output')
    prefs.onclick = function()
        -- FIXME: need some way to detect changes after the user enables (or disables)
        -- a device for output and update the menu.
        -- Opens Preferences to MIDI Devices page
        reaper.ViewPrefs(153, '')
    end

    local row = add_row(section, "MIDI Bus:", 85)
    local menu = row:add(rtk.OptionMenu())
    menu:attr('menu', {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'})
    menu:select(app.config.cc_feedback_bus or 1)
    menu.onchange = function(menu)
        if app.config.cc_feedback_bus == menu.selected_index then
            -- Nothing changed.
            return
        end
        log.info("settings: changed MIDI CC feedback bus: %s", menu.selected_index)
        app.config.cc_feedback_bus = menu.selected_index
        app:save_config()
        feedback.update_feedback_track_settings(true)
    end

    local row = add_row(section, "Articulations:", 85)
    local menu = row:add(rtk.OptionMenu())
    menu:attr('menu', {"Program Changes", "CC values"})

    local row = add_row(section, "CC #:", 85)
    local text = row:add(rtk.Entry{placeholder="CC number"})
    text.onchange = function(text)
        local cc = tonumber(text.value)
        if app.config.cc_feedback_articulations_cc == cc then
            -- Nothing changed
            return
        end
        -- TODO: provide feedback if value isn't a number.  This will just quietly convert to nil.
        app.config.cc_feedback_articulations_cc = tonumber(text.value)
        app:save_config()
        feedback.update_feedback_track_settings(true)
    end
    menu.onchange = function(menu)
        local changed = app.config.cc_feedback_articulations ~= menu.selected_index
        app.config.cc_feedback_articulations = menu.selected_index
        if menu.selected_index == 1 then
            row:hide()
        else
            if app.config.cc_feedback_articulations_cc > 0 then
                text:attr('value', tostring(app.config.cc_feedback_articulations_cc))
            end
            row:show()
        end
        if changed then
            feedback.update_feedback_track_settings(true)
            app:save_config()
        end
    end
    screen.cc_feedback_articulations_menu = menu


    --
    -- Section: Articulation Colors
    --
    local section = make_section(screen.vbox, "Default Articulation Colors")
    local box = section:add(rtk.FlowBox{vspacing=5, hspacing=20})
    for _, record in ipairs(screen.art_colors) do
        local name, color, iconname = table.unpack(record)
        local row = add_row(box, name .. ":", 80)
        local default = reabank.default_colors[color]
        local initial = app.config.art_colors[color]
        local icon = articons.get_for_bg(iconname, initial or default)
        local text = add_color_input(row, initial, default, icon, false, function(text, button)
            local cfgval = text.value
            if cfgval == default or cfgval == '' then
                -- Store nil to config if the configured color is the default
                cfgval = nil
            end
            if cfgval ~= app.config.art_colors[color] then
                app.config.art_colors[color] = cfgval
                app:save_config()
                app.screens.banklist.clear_cache()
            end
            -- Refresh icon based on luma of newly selected color.
            local icon = articons.get_for_bg(iconname, cfgval or default)
            button:attr('icon', icon)
        end)
        screen.art_color_entries[color] = text
    end

    --
    -- Section: Misc Settings
    --
    local section = make_section(screen.vbox, "Misc Settings")
    local row = add_row(section, "Log Level:", 85)
    local menu = row:add(rtk.OptionMenu())
    -- Populate optionmenu with title-cased log levels
    local options = {}
    for level, name in pairs(log.levels) do
        name = name:sub(1, 1):upper() .. name:sub(2):lower()
        options[#options+1] = {name, id=level}
    end
    table.sort(options, function(a, b) return a.id > b.id end)
    menu:attr('menu', options)
    menu:select(app.config.debug_level or log.ERROR)
    menu.onchange = function(menu)
        app:set_debug(tonumber(menu.selected_id))
    end


    --
    -- Footer
    --
    screen.vbox:add(
        rtk.Text{string.format("Reaticulate %s", metadata._VERSION), alpha=0.6},
        {halign='center', tpadding=20}
    )
    local button = screen.vbox:add(
        rtk.Button{
            icon='med-link', label="Visit Website",
            truncate=false,
            color=rtk.theme.accent_subtle, alpha=0.6,
            cursor=rtk.mouse.cursors.HAND,
            flat=true,
            padding={7, 10},
        },
        {tpadding=2, halign='center', stretch=true}
    )
    button.onclick = function()
        rtk.open_url('https://reaticulate.com')
    end
end

-- Apart from being called by screen.update(), this is also called by App:zoom() in case
-- the user adjusts the scale through external means.
function screen.update_ui_scale_menu()
    screen.ui_scale_menu:select(rtk.scale.user)
    if not screen.ui_scale_menu.selected_id then
        screen.ui_scale_menu:attr('label', 'Custom')
    end
end

function screen.update()
    -- There's no API to determine which MIDI devices are enabled for output, so
    -- read the config file directly.  The 'midiouts' parameter is a bitmap by
    -- output number.
    local ini = rtk.file.read(reaper.get_ini_file())
    local bitmap = tonumber(ini and ini:match("midiouts=([^\n]*)")) or 0
    -- Build feedback device menu based on enabled output devices.
    local menu = {{"Disabled", id='-1'}}
    for output = 0, reaper.GetNumMIDIOutputs() - 1 do
        local retval, name = reaper.GetMIDIOutputName(output, "")
        if retval and bitmap & (1 << output) ~= 0 then
            menu[#menu+1] = {name, id=tostring(output)}
        end
    end

    screen.update_ui_scale_menu()
    screen.midi_device_menu:attr('menu', menu)
    screen.midi_device_menu:select(tostring(app.config.cc_feedback_device) or 1)
    screen.cb_insert_at_note_selection:attr('value', app.config.art_insert_at_selected_notes, false)
    screen.cb_track_follows_midi_editor:attr('value', app:get_toggle_option('track_selection_follows_midi_editor'), false)
    screen.cb_track_follows_fx_focus:attr('value', app:get_toggle_option('track_selection_follows_fx_focus'), false)
    screen.cb_sloppy_focus:attr('value', app:get_toggle_option('keyboard_focus_follows_mouse'), false)
    screen.cb_single_fx_instrument:attr('value', app:get_toggle_option('single_floating_instrument_fx_window'), false)
    screen.cb_undocked_borderless:attr('value', app.config.borderless, false)
    screen.cb_touchscroll:attr('value', app.config.touchscroll, false)
    screen.cb_smoothscroll:attr('value', app.config.smoothscroll, false)
    screen.default_channel_menu:select(app.config.default_channel_behavior)

    for color, text in pairs(screen.art_color_entries) do
        text:attr('value', app:get_articulation_color(color), true)
    end
    screen.cc_feedback_articulations_menu:select(app.config.cc_feedback_articulations or 2)
end

return screen
