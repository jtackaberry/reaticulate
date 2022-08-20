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
local log = rtk.log
local json = require 'lib.json'
local metadata = require 'metadata'
require 'lib.utils'

local BaseApp = rtk.class('BaseApp', rtk.Application)
-- Global variable to BaseApp instance.
app = nil

function BaseApp:initialize(appid, title, basedir)
    if not rtk.has_sws_extension then
        -- Sunk before we started.
        reaper.MB("Reaticulate requires the SWS extensions (www.sws-extension.org).\n\nAborting!",
                  "SWS extension missing", 0)
        return false
    end
    -- Latest supported version is 5.975 due to support for P_EXT with GetSetTrackSendInfo_String().
    --
    -- See https://www.landoleet.org/old/whatsnew5.txt
    if not rtk.check_reaper_version(5, 975) then
        reaper.MB('Sorry, Reaticulate requires REAPER v5.975 or later.', 'REAPER version too old', 0)
        return false
    end
    app = self
    Path.init(basedir)
    Path.imagedir = Path.join(Path.basedir, 'img')

    self.cmdserial = 0
    -- Callbacks indexed by cmd serial
    self.cmdcallbacks = {}
    -- Keep track of the number of in-flight requests, because Lua is retarded and
    -- #self.cmdcallbacks doesn't work.
    self.cmdpending = 0

    self.appid = appid

    if not self.config then
        -- Subclass didn't initialize config table, so do that now.
        self.config = {}
    end
    table.merge(self.config, {
        -- Initial dimensions
        x = 0,
        y = 0,
        w = 640,
        h = 480,
        -- deprecated
        dockstate = nil,
        -- nil values of dock/docked will parse from dockstate for transition purposes
        dock = nil,
        docked = nil,
        scale = 1.0,
        bg = nil,
        borderless = false,
        touchscroll = false,
        smoothscroll = true,
    })
    self.config = self:get_config()
    rtk.scale.user = self.config.scale

    -- Check to see if we should warn about being a prerelease.
    if metadata._VERSION:find('pre') then
        if not self.config.showed_prerelease_warning then
            local response = reaper.MB(
                'WARNING! You are using a pre-release version of Reaticulate.\n\n' ..
                'Projects saved with this version of Reaticulate WILL NOT WORK if you downgrade to the stable ' ..
                'release, and you will only be able to move forward to later versions of Reaticulate. Please only ' ..
                'use pre-releases if you can tolerate and are willing to report bugs. Be sure to backup your ' ..
                'projects before re-saving.\n\n' ..
                'Continue using this pre-release version?\n\n' ..
                'If you answer OK, Reaticulate will continue on and this warning will not be displayed again.\n\n' ..
                'If you Cancel, Reaticulate will abort and you can downgrade to a stable version via ReaPack.',
                'UNSTABLE Reaticulate pre-release version in use',
                1)
            if response == 2 then
                return false
            end
            self.config.showed_prerelease_warning = true
        end
    else
        -- Not running a prerelease.  Reset the warning flag for the next time a
        -- prerelease is installed.
        self.config.showed_prerelease_warning = false
    end

    -- Migration from boolean debug used in 0.3.x to logging level introduced in 0.4.x
    if self.config.debug_level == true or self.config.debug_level == 1 then
        self.config.debug_level = log.DEBUG
        self:save_config()
    elseif self.config.debug_level == false or self.config.debug_level == 0 then
        self.config.debug_level = log.ERROR
        self:save_config()
    end

    rtk.touchscroll = app.config.touchscroll
    rtk.smoothscroll = app.config.smoothscroll
    self:set_theme()

    -- Ensure we set theme before calling to superclass.
    rtk.Application.initialize(self)

    self.window = rtk.Window{
        title=title,
        x=self.config.x,
        y=self.config.y,
        w=rtk.clamp(self.config.w, 0, 4096),
        h=rtk.clamp(self.config.h, 0, 4096),
        -- Default to a right docker, if one exists.
        dock=self.config.dock or 'right',
        docked=self.config.docked,
        borderless=self.config.borderless,
        pinned=self.config.pinned,

        ondock = function() self:handle_ondock() end,
        onattr = function(_, attr, value) self:handle_onattr(attr, value) end,
        onmove = function() self:handle_onmove() end,
        onresize = function() self:handle_onresize() end,
        onupdate = function() self:handle_onupdate() end,
        onmousewheel = function(_, event) self:handle_onmousewheel(event) end,
        onclose = function() self:handle_onclose() end,
        onkeypresspost = function(_, event) self:handle_onkeypresspost(event) end,
        ondropfile = function(_, event) self:handle_ondropfiles(event) end,
        onclick = function(_, event) self:handle_onclick(event) end,
    }
    self:build_frame()
end

function BaseApp:run()
    self:handle_onupdate()
    rtk.window:open{constrain=true}
end

function BaseApp:add_screen(name, package)
    local screen = require(package)
    rtk.Application.add_screen(self, screen, name)
end

-- App-wide utility functions
local function _swallow_event(self, event)
    event:set_handled(self)
    return false
end

function BaseApp:make_button(icon, label, textured, attrs)
    local defaults = {
        icon=icon,
        label=label,
        flat=true,
        touch_activate_delay=0
    }
    attrs = table.merge(defaults, attrs or {})
    local button = rtk.Button(attrs)
    -- Set a custom drag handler that prevents lower-zindex widgets from
    -- handling drags. So if the user drags the button, it prevents drag
    -- handlers for widgets underneath from triggering (e.g. for drag-moving
    -- borderless windows).
    button.ondragstart = _swallow_event
    return button
end

function BaseApp:get_icon_path(name)

end

function BaseApp:fatal_error(msg)
    msg = msg ..
          '\n\nThis is an unrecoverable error and Reaticulate must now exit. ' ..
          '\n\nPlease visit https://reaticulate.com/ for support contact details.'
    reaper.ShowMessageBox(msg, "Reaticulate fatal error", 0)
    rtk.quit()
end

function BaseApp:get_ext_state(key)
    if not reaper.HasExtState(self.appid, key) then
        return
    end
    local encoded = reaper.GetExtState(self.appid, key)
    local ok, decoded = pcall(json.decode, encoded)
    return ok and decoded, encoded
end

function BaseApp:set_ext_state(key, obj, persist)
    local serialized = json.encode(obj)
    reaper.SetExtState(self.appid, key, serialized, persist or false)
    log.debug('baseapp: wrote ext state "%s" (size=%s persist=%s)', key, #serialized, persist)
    return serialized
end

function BaseApp:get_config(appid, target)
    local config, encoded = self:get_ext_state('config')
    if not config and encoded then
        -- There was data but failed to decode as JSON.  Assume this is pre 0.5.0 which
        -- used table.tostring/fromstring for config.  We fall back to the
        -- unsafe table.fromstring() in order to migrate.
        local ok
        log.info('baseapp: config failed to parse as JSON: %s', encoded)
        ok, config = pcall(table.fromstring, encoded)
        if not ok then
            reaper.MB(
                "Reaticulate wasn't able to parse its saved configuration. This may be because " ..
                "you downgraded Reaticulate and it doesn't understand the format used by a future " ..
                "version.\n\nAll Reaticulate settings will need to be reset to defaults.",
                'Unrecognized Reaticulate configuration',
                0
            )
            config = nil
        else
            -- Config was migrated to JSON. Force resave using the new format
            self:save_config(config)
        end
    end
    if config then
        -- Merge stored config into runtime config
        table.merge(self.config, config)
    end
    self:set_debug(self.config.debug_level or log.ERROR)
    if not self.config.dock and self.config.dockstate then
        -- Convert deprecated dockstate field to dock/docker values
        self.config.dock = (self.config.dockstate >> 8) & 0xff
        self.config.docked = (self.config.dockstate & 0x01) ~= 0
    end
    return self.config

end

function BaseApp:save_config(config)
    self:_do_save_config(config, true)
end

function BaseApp:queue_save_config(config)
    if not self._save_config_queued then
        rtk.callafter(0.25, self._do_save_config, self, config)
        self._save_config_queued = true
    end
end

function BaseApp:_do_save_config(config, force)
    if not self._save_config_queued and not force then
        return
    end
    local cfg = self:set_ext_state('config', config or self.config, true)
    self._save_config_queued = false
end

function BaseApp:set_debug(level)
    self.config.debug_level = level
    self:save_config()
    log.level = level or log.ERROR
    log.info("baseapp: Reaticulate log level is %s", log.level_name())
end

function BaseApp:zoom(increment)
    if increment == 0 then
        rtk.scale.user = 1.0
    else
        rtk.scale.user = rtk.clamp(rtk.scale.user + increment, 0.5, 4.0)
    end
    log.info('zoom %.02f', rtk.scale.user)
    self:set_statusbar(string.format('Zoom UI to %.02fx', rtk.scale.user))
    self.config.scale = rtk.scale.user
    self:save_config()
end

function BaseApp:handle_onattr(attr, value)
    if attr == 'pinned' or attr == 'docked' or attr == 'dock' then
        self:handle_ondock()
    end
end

function BaseApp:handle_ondock()
    self.config.pinned = self.window.pinned
    self.config.docked = self.window.docked
    self.config.dock = self.window.dock
    if rtk.has_js_reascript_api then
        if self.window.docked then
            self.toolbar.pin:hide()
            self.toolbar.unpin:hide()
        else
            self:_set_window_pinned(self.config.pinned)
        end
    end
    self:save_config()
end

function BaseApp:handle_onresize()
    -- Only save dimensions when not docked.
    if not self.window.docked then
        self.config.w = self.window.w
        self.config.h = self.window.h
        self:queue_save_config()
    end
end

function BaseApp:handle_onmove()
    -- Only save position when not docked.
    if not self.window.docked then
        self.config.x = self.window.x
        self.config.y = self.window.y
        self:queue_save_config()
    end
end

function BaseApp:handle_onmousewheel(event)
    if event.ctrl and not rtk.is_modal() then
        -- ctrl-wheel scaling
        self:zoom(event.wheel < 0 and 0.10 or -0.10)
        event:set_handled()
    end
end

function BaseApp:set_theme()
    local bg = self.config.bg
    if not bg or type(bg) ~= 'string' or #bg <= 1 then
        bg = rtk.color.get_reaper_theme_bg()
    end
    rtk.set_theme_by_bgcolor(bg)
    rtk.add_image_search_path(Path.imagedir)

    local icons = {
        medium={
            'add_circle_outline',
            'arrow_back',
            'auto_fix',
            'delete',
            'dock_window',
            'drag_vertical',
            'edit',
            'eraser',
            'info_outline',
            'link',
            'pin_off',
            'pin_on',
            'search',
            'settings',
            'sync',
            'undo',
            'undock_window',
            'view_list',
        },
        large={
            'alert_circle_outline',
            'drag_vertical',
            'info_outline',
            'plus',
            'warning_amber',
        },
        huge={
            'alert_circle_outline',
        },
    }

    local img = rtk.ImagePack():add{
        src='icons.png', style='light',
        {w=18, size='medium', names=icons.medium, density=1},
        {w=24, size='large', names=icons.large, density=1},
        {w=96, size='huge', names=icons.huge, density=1},
        {w=28, size='medium', names=icons.medium, density=1.5},
        {w=36, size='large', names=icons.large, density=1.5},
        {w=144, size='huge', names=icons.huge, density=1.5},
        {w=36, size='medium', names=icons.medium, density=2},
        {w=48, size='large', names=icons.large, density=2},
        {w=192, size='huge', names=icons.huge, density=2},
    }
    img:register_as_icons()
end

function BaseApp:set_statusbar(label)
    self:attr('status', label)
end

function BaseApp:build_frame()
    self.window:add(self)
    if rtk.has_js_reascript_api then
        local pin = rtk.Button{icon='pin_off', flat=true, tooltip='Pin window to top'}
        local unpin = rtk.Button{icon='pin_on', flat=true, tooltip='Unpin window from top'}
        self.toolbar.pin = self.toolbar:add(pin, {rpadding=15})
        self.toolbar.unpin = self.toolbar:add(unpin, {rpadding=15})
        self.toolbar.pin.onclick = function() self:_set_window_pinned(true) end
        self.toolbar.unpin.onclick = function() self:_set_window_pinned(false) end
    end
end

function BaseApp:_set_window_pinned(pinned)
    if rtk.has_js_reascript_api then
        self.window:attr('pinned', pinned)
        self.toolbar.pin:attr('visible', not pinned)
        self.toolbar.unpin:attr('visible', pinned)
    end
end

function BaseApp:handle_onupdate()
    self:check_commands()
end

function BaseApp:timeout_command_callbacks()
    local now = reaper.time_precise()
    for serial in pairs(self.cmdcallbacks) do
        local expires, cb = table.unpack(self.cmdcallbacks[serial])
        if now > expires then
            cb(nil)
            self.cmdcallbacks[serial] = nil
            self.cmdpending = self.cmdpending - 1
        end
    end
end

-- Sends a command to the given appid.  The command can take arbitrarily
-- many arguments.
--
-- If the last argument is a function and a passed is a function, then it
-- the remote command will request a response and the function will be
-- invoked upon reply.  The callback will be passed an argument containing
-- the remote response.  If the argument is nil, it means the remote end
-- did not respond before the timeout.
--
-- The timeout defaults to 2 seconds, but it can be overriden by passing
-- another argument after the callback.
function BaseApp:send_command(appid, cmd, ...)
    local cmdlist = reaper.GetExtState(appid, "command")
    if cmdlist then
        if cmdlist:len() > 200 then
            -- Too many queued commands.  Target appid not responding.  Truncate the existing
            -- list.
            log.warning("baseapp: %s not responding", appid)
            cmdlist = ''
        else
            cmdlist = cmdlist .. ' '
        end
    else
        cmdlist = ''
    end
    local args = {...}
    local callback = nil
    local timeout = 2

    if #args >= 1 and type(args[#args]) == 'function' then
        callback = table.remove(args, #args)
    elseif #args >= 2 and type(args[#args - 1]) == 'function' then
        timeout = table.remove(args, #args)
        callback = table.remove(args, #args)
    end
    if #args == 0 then
        -- Protocol requires _some_ argument, so just make a dummy one
        args = {0}
    end
    if callback then
        self.cmdserial = self.cmdserial + 1
        local serial = tostring(self.cmdserial)
        self.cmdcallbacks[serial] = {reaper.time_precise() + timeout, callback}
        self.cmdpending = self.cmdpending + 1
        cmd = string.format('?%s:%s,%s', cmd, self.appid, serial)
    end
    local joined = table.concat(args, ',')
    reaper.SetExtState(appid, "command", cmdlist .. cmd .. '=' .. joined, false)
end

function BaseApp:handle_command(cmd, arg)
    if cmd == 'ping' then
        reaper.SetExtState(self.appid, "pong", arg, false)
        return arg
    elseif cmd == 'quit' then
        self.window:close()
    end
end


function BaseApp:check_commands()
    if self.cmdpending  > 0 then
        -- We have pending requests.  Clean up those that have timed out.
        self:timeout_command_callbacks()
    end
    if reaper.HasExtState(self.appid, "command") then
        local val = reaper.GetExtState(self.appid, "command")
        reaper.DeleteExtState(self.appid, "command", false)
        for cmd, arg in val:gmatch('(%S+)=([^"]%S*)') do
            if cmd:startswith('?') then
                -- This request expects an async reply.  Command will be in the form:
                -- ?cmd:appid,serial
                local cmd, return_appid, serial = cmd:match("%?([^:]+):([^,]+),(.*)")
                local response = self:handle_command(cmd, arg)
                self:send_command(return_appid, '!' .. serial, tostring(response))
            elseif cmd:startswith('!') then
                -- This is an async reply.  Command is in the form: !serial
                local serial = cmd:match("!(.*)")
                local cbinfo = self.cmdcallbacks[serial]
                if cbinfo then
                    self.cmdcallbacks[serial][2](arg)
                    self.cmdcallbacks[serial] = nil
                    self.cmdpending = self.cmdpending - 1
                else
                    log.error("baseapp: %s received reply to unknown request %s", self.appid, serial)
                end
            else
                self:handle_command(cmd, arg)
            end
        end
    end

end

function BaseApp:handle_onclose()
end

function BaseApp:handle_onkeypresspost(event)
    if event.handled then
        return
    end
    if event.char == '=' and event.ctrl then
        self:zoom(0.10)
        event:set_handled()
    elseif event.char == '-' and event.ctrl then
        self:zoom(-0.10)
        event:set_handled()
    elseif event.char == '0' and event.ctrl then
        self:zoom(0)
        event:set_handled()
    end
end

function BaseApp:handle_ondropfiles(event)
end

function BaseApp:handle_onclick(event)
    if event.ctrl and event.button == rtk.mouse.BUTTON_MIDDLE then
        self:zoom(0)
        event:set_handled()
    end
end

return BaseApp
