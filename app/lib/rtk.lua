
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


-- RTK - Reaper Toolkit
--
-- A modest UI library for Reaper, inspired by gtk+.
--
local class = require 'lib.middleclass'

-------------------------------------------------------------------------------------------------------------
-- Misc utility functions
function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function table.merge(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
end

function hex2rgb(s)
    local r = tonumber(s:sub(2, 3), 16)
    local g = tonumber(s:sub(4, 5), 16)
    local b = tonumber(s:sub(6, 7), 16)
    local a = tonumber(s:sub(8, 9), 16)
    return r / 255, g / 255, b / 255, a ~= nil and a / 255 or 1.0
end

function rgb2hex(r, g, b)
    return string.format('#%02x%02x%02x', r, g, b)
end

function hex2int(s)
    local r, g, b = hex2rgb(s)
    return (r * 255) + ((g * 255) << 8) + ((b * 255) << 16)
end

function int2hex(d)
    return rgb2hex(d & 0xff, (d >> 8) & 0xff, (d >> 16) & 0xff)
end

function color2rgba(s)
    local r, g, b, a
    if type(s) == 'table' then
        return table.unpack(s)
    else
        return hex2rgb(s)
    end
end

function color2luma(s)
    local r, g, b, a = color2rgba(s)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

-------------------------------------------------------------------------------------------------------------

local rtk = {
    debug = false,
    scale = 1,
    w = gfx.w,
    h = gfx.h,
    dockstate = nil,
    in_window = false,
    widget = nil,
    focused = nil,
    running = true,

    mouse = {
        BUTTON_LEFT = 1,
        BUTTON_MIDDLE = 64,
        BUTTON_RIGHT = 2,
        BUTTON_MASK = (1 | 2 | 64),
        x = 0,
        y = 0,
        cap = 0,
        wheel = 0,
        down = 0,
        cursor = 0,
        cursors = {
            undefined = 0,
            pointer = 32512,
            beam = 32513
        },
    },

    viewport = {
        x = 0,
        y = 0,
        w = 0,
        h = 0
    },

    colors = {
        dark = {
            window_bg = '#252525',
            text = '#ffffff',
            text_faded = '#bbbbbb',
            button = '#666666',
            buttontext = '#ffffff',
            entry_border_hover = '#3a508e',
            entry_border_focused = '#4960b8',
            entry_bg = '#353535',
            entry_label = '#ffffff7f'
        },
        light = {
            window_bg = '#dddddd',
            button = '#888888',
            buttontext = '#ffffff',
            text = '#000000',
            text_faded = '#5555555',
            entry_border_hover = '#3a508e',
            entry_border_focused = '#4960b8',
            entry_bg = '#cccccc',
            entry_label = '#0000007f'
        }
    },

    fonts = {
        BOLD = 98,
        ITALICS = 105,
        -- nil values will use default
        -- FIXME: do something sane for flags
        default = {'Calibri', 18},
        label = nil,
        button = nil,
        entry  = nil,
        heading = {'Calibri', 22, 98},
    },

    keycodes = {
        UP			= 30064,
        DOWN		= 1685026670,
        LEFT		= 1818584692,
        RIGHT		= 1919379572,
        RETURN		= 13,
        ENTER       = 13,
    	SPACE		= 32,
    	BACKSPACE	= 8,
        ESCAPE		= 27,
        TAB         = 9,
    	HOME		= 1752132965,
    	END			= 6647396,
    	INSERT		= 6909555,
    	DELETE		= 6579564,
    },

    onupdate = function() end,
    onreflow = function() end,
    onresize = function() end,
    ondock = function() end,
    onkeypresspre = function(event) end,
    onkeypresspost = function(event) end,
    onmousewheel = function(event) end,

    _event = nil,
    _reflow_queued = false,
    _draw_queued = false,
    -- After drawing, the window contents is blitted to this backing store as an
    -- optimization for subsequent UI updates where no event has occured.
    _backingstore = nil,
    -- The last unique id assigned to a widget object
    _last_widget_serial = 0,
}

rtk.theme = rtk.colors.dark

function log(fmt, ...)
    if rtk.debug then
        local args = {...}
        if not fmt then
            reaper.ShowConsoleMsg(debug.traceback())
        else
            reaper.ShowConsoleMsg(string.format(fmt .. "\n", ...))
            -- for _, part in ipairs(args) do
            --     reaper.ShowConsoleMsg(tostring(part) .. " ")
            -- end
            -- reaper.ShowConsoleMsg("\n")
        end
    end
end


function rtk.viewport.setbounds(w, h)
    rtk.viewport.w = w
    rtk.viewport.h = h
    rtk.viewport.x = math.max(0, math.min(rtk.viewport.x, w - rtk.w))
    rtk.viewport.y = math.max(0, math.min(rtk.viewport.y, h - rtk.h))
end

function rtk.viewport.scrollto(x, y)
    rtk.viewport.x = clamp(x, 0, rtk.viewport.w)
    rtk.viewport.y = clamp(y, 0, rtk.viewport.h)
end

function rtk.viewport.scrollby(xoff, yoff)
    if xoff ~= 0 then
        local limx = math.max(0, rtk.viewport.w - rtk.w)
        rtk.viewport.x = clamp(rtk.viewport.x + xoff, 0, limx)
    end
    if yoff ~= 0 then
        local limy = math.max(0, rtk.viewport.h - rtk.h)
        rtk.viewport.y = clamp(rtk.viewport.y + yoff, 0, limy)
    end
end


function rtk.queue_reflow()
    rtk._reflow_queued = true
end

function rtk.queue_draw()
    rtk._draw_queued = true
end


function rtk.reflow()
    local x, y, w, h = rtk.widget:reflow(0, 0, rtk.w, rtk.h)
    rtk.viewport.setbounds(w, h)
    rtk.onreflow()
end

local function _get_mouse_button_event(bit)
    local type = nil
    -- Determine whether the mouse button (at the given bit position) is either
    -- pressed or released.  We update the rtk.mouse.down bitmap to selectively
    -- toggle that single bit rather than just copying the entire mouse_cap bitmap
    -- in order to ensure that multiple simultaneous mouse up/down events will
    -- be emitted individually (in separate invocations of rtk.update()).
    if rtk.mouse.down & bit == 0 and gfx.mouse_cap & bit ~= 0 then
        rtk.mouse.down = rtk.mouse.down | bit
        type = rtk.Event.MOUSEDOWN
    elseif rtk.mouse.down & bit ~= 0 and gfx.mouse_cap & bit == 0 then
        rtk.mouse.down = rtk.mouse.down & ~bit
        type = rtk.Event.MOUSEUP
    end
    if type then
        local event = rtk._event:reset(type)
        event.x, event.y = gfx.mouse_x, gfx.mouse_y
        event:set_modifiers(gfx.mouse_cap, bit)
        return event
    end
end

function rtk.update()
    local need_draw = rtk._draw_queued
    if rtk.onupdate() == false then
        return true
    end

    if gfx.w ~= rtk.w or gfx.h ~= rtk.h then
        rtk.w, rtk.h = gfx.w, gfx.h
        rtk.viewport.scrollto(0, 0)
        rtk.reflow()
        rtk.onresize()
        need_draw = true
    elseif rtk._reflow_queued then
        rtk.reflow()
        rtk._reflow_queued = false
        need_draw = true
    elseif rtk.w > 2048 or rtk.h > 2048 then
        -- Window dimensions exceed max image size so we can't use backing store.
        need_draw = true
    end

    local event = nil

    if gfx.mouse_wheel ~= 0 then
        event = rtk._event:reset(rtk.Event.MOUSEWHEEL)
        event:set_modifiers(gfx.mouse_cap, 0)
        event.wheel = -gfx.mouse_wheel
        rtk.onmousewheel(event)
        gfx.mouse_wheel = 0
        rtk.viewport.scrollby(0, event.wheel)
        need_draw = true
    end

    if rtk.mouse.down ~= gfx.mouse_cap & rtk.mouse.BUTTON_MASK then
        -- Generate events for mouse button down/up.
        event = _get_mouse_button_event(1)
        if not event then
            event = _get_mouse_button_event(2)
            if not event then
                event = _get_mouse_button_event(64)
            end
        end
    end

    -- Generate key event
    local char = gfx.getchar()
    if char > 0 then
        event = rtk._event:reset(rtk.Event.KEY)
        event.keycode = char
        if char >= 32 and char <= 255 then
            event.char = string.char(char)
        else
            event.char = nil
        end
        rtk.onkeypresspre(event)
    end

    local last_in_window = rtk.in_window
    rtk.in_window = gfx.mouse_x >= 0 and gfx.mouse_y >= 0 and gfx.mouse_x <= gfx.w and gfx.mouse_y <= gfx.h
    if not event then
        -- Generate mousemove event if the mouse actually moved, or simulate one if a
        -- draw has been queued.
        local mouse_moved = rtk.mouse.x ~= gfx.mouse_x or rtk.mouse.y ~= gfx.mouse_y
        -- Ensure we emit the event if draw is forced, or if we're moving within the window, or
        -- if we _were_ in the window but now suddenly aren't (to ensure mouseout cases are drawn)
        if need_draw or (mouse_moved and rtk.in_window) or last_in_window ~= rtk.in_window then
            event = rtk._event:reset(rtk.Event.MOUSEMOVE)
            event.x, event.y = gfx.mouse_x, gfx.mouse_y
            event:set_modifiers(gfx.mouse_cap, 0)
        end
    end

    if event then
        -- rtk.mouse.down = gfx.mouse_cap & rtk.mouse.BUTTON_MASK
        rtk.mouse.x = gfx.mouse_x
        rtk.mouse.y = gfx.mouse_y

        -- Clear mouse cursor before drawing widgets to determine if any widget wants a custom cursor
        local last_cursor = rtk.mouse.cursor
        rtk.mouse.cursor = rtk.mouse.cursors.undefined
        -- Reset draw queued flag before calling _draw() to allow a _draw() method to request a
        -- refresh (e.g. text input blinking cursor)
        rtk._draw_queued = false

        if rtk.widget.visible == true then
            rtk.widget:_handle_event(-rtk.viewport.x, -rtk.viewport.y, event)
            rtk.clear()
            rtk.widget:_draw(-rtk.viewport.x, -rtk.viewport.y, event)
            rtk._backingstore:resize(rtk.w, rtk.h, false)
            rtk._backingstore:drawfrom(-1)
        end

        -- If the current cursor is undefined, it means no widgets requested a custom cursor,
        -- so default to pointer.
        if rtk.mouse.cursor == rtk.mouse.cursors.undefined then
            rtk.mouse.cursor = rtk.mouse.cursors.pointer
        end
        if rtk.mouse.cursor ~= last_cursor then
            gfx.setcursor(rtk. mouse.cursor)
        end

        if not event.handled then
            if rtk.focused and event.type == rtk.Event.MOUSEDOWN then
                rtk.focused:blur()
            end
        end
        if event.type == rtk.Event.KEY then
            rtk.onkeypresspost(event)
        end
    else
        rtk._backingstore:draw(nil, nil, nil, 6)
    end
    local dockstate = gfx.dock(-1)
    if dockstate ~= rtk.dockstate then
        rtk.dockstate = dockstate
        rtk.ondock()
    end
    gfx.update()
end

function rtk.init(title, w, h, dock)
    -- Reusable event object.
    rtk._event = rtk.Event:new()
    rtk._backingstore = rtk.Image:new():create(w, h)
    gfx.clear = hex2int(rtk.theme.window_bg)
    gfx.init(title, w, h, dock)
end

function rtk.clear()
    gfx.set(hex2rgb(rtk.theme.window_bg))
    gfx.rect(0, 0, rtk.w, rtk.h, 1)
end

function rtk.run()
    rtk.update()
    if rtk.running then
        reaper.defer(rtk.run)
    end
end

function rtk.quit()
    rtk.running = false
end


-------------------------------------------------------------------------------------------------------------

rtk.Event = class('rtk.Event')
rtk.Event.static.MOUSEDOWN = 1
rtk.Event.static.MOUSEUP = 2
rtk.Event.static.MOUSEMOVE = 3
rtk.Event.static.MOUSEWHEEL = 4
rtk.Event.static.KEY = 5

function rtk.Event:initialize(type)
    self:reset(type)
end

function rtk.Event:reset(type)
    self.type = type
    -- Widget that handled this event
    self.handled = nil
    -- Widget that the mouse is currently hovering over
    self.hovering = nil
    self.button = 0
    self.buttons = 0
    self.wheel = 0
    return self
end

function rtk.Event:set_widget_hovering(widget)
    if self.hovering == nil then
        self.hovering = {}
    end
    self.hovering[widget.id] = 1
end

function rtk.Event:is_widget_hovering(widget)
    return self.hovering and self.hovering[widget.id] == 1
end

function rtk.Event:set_modifiers(cap, button)
    self.ctrl = cap & 4 ~= 0
    self.shift = cap & 8 ~= 0
    self.alt = cap & 16 ~= 0
    self.meta = cap & 32 ~= 0
    self.buttons = cap & (1 | 2 | 64)
    self.button = button
end

-------------------------------------------------------------------------------------------------------------

rtk.Image = class('rtk.Image')
rtk.Image.static.last_index = -1

function rtk.Image:initialize(src, sx, sy, sw, sh)
    self.sx = 0
    self.sy = 0
    self.width = -1
    self.height = -1

    if sh ~= nil then
        self:viewport(src, sx, sy, sw, sh)
    elseif src ~= nil then
        self:load(src)
    end
end

function rtk.Image:create(w, h)
    rtk.Image.static.last_index = rtk.Image.static.last_index + 1
    self.id = rtk.Image.static.last_index
    if h ~= nil then
        self:resize(w, h)
    end
    return self
end

function rtk.Image:resize(w, h, clear)
    if self.width ~= w or self.height ~= h then
        self.width, self.height = w, h
        gfx.setimgdim(self.id, w, h)
        if clear ~= false then
            self:clear()
        end
    end
    return self
end

function rtk.Image:clear(r, g, b, a)
    gfx.dest = self.id
    gfx.r, gfx.g, gfx.b, gfx.a = r or 0, g or 0, b or 0, a or 0
    gfx.rect(0, 0, self.width, self.height, 1)
    gfx.dest = -1
    return self
end

function rtk.Image:load(path)
    rtk.Image.static.last_index = rtk.Image.static.last_index + 1
    self.id = gfx.loadimg(rtk.Image.last_index, path)
    self.width, self.height = gfx.getimgdim(self.id)
    return self
end

function rtk.Image:viewport(src, sx, sy, sw, sh)
    self.id = src.id
    self.sx = sx
    self.sy = sy
    self.width = sw == -1 and src.width or sw
    self.height = sh == -1 and src.height or sh
    return self
end

function rtk.Image:draw(dx, dy, scale, mode, a)
    gfx.mode = mode or 0
    gfx.blit(self.id, scale or 1.0, 0, self.sx, self.sy, self.width, self.height, dx or 0, dy or 0)
    gfx.mode = 0
    return self
end

function rtk.Image:drawregion(sx, sy, dx, dy, w, h, scale, mode, a)
    gfx.mode = mode or 6
    gfx.a = a or 1.0
    gfx.blit(self.id, scale or 1.0, 0, sx or self.sx, sy or self.sw, w or self.width, h or self.height, dx or 0, dy or 0)
    gfx.mode = 0
    return self
end

function rtk.Image:drawfrom(src, sx, sy, dx, dy, w, h, scale, mode, a)
    gfx.dest = self.id
    gfx.mode = mode or 6
    gfx.a = a or 1.0
    gfx.blit(-1, scale or 1.0, 0, sx or self.sx, sy or self.sy, w or self.width, h or self.height, dx or 0, dy or 0)
    gfx.mode = 0
    gfx.dest = -1
end

-------------------------------------------------------------------------------------------------------------


rtk.Widget = class('Widget')

rtk.Widget.static.LEFT = 0
rtk.Widget.static.TOP = 0
rtk.Widget.static.CENTER = 1
rtk.Widget.static.RIGHT = 2
rtk.Widget.static.BOTTOM = 2

rtk.Widget.static.RELATIVE = 0
rtk.Widget.static.FIXED = 1

function rtk.Widget:initialize()
    self.id = rtk._last_widget_serial
    rtk._last_widget_serial = rtk._last_widget_serial + 1

    -- User defined coords
    self.x = 0
    self.y = 0
    self.w = nil
    self.h = nil

    -- Padding that subclasses *should* implement
    self.lpadding = 0
    self.tpadding = 0
    self.rpadding = 0
    self.bpadding = 0

    self.halign = rtk.Widget.LEFT
    self.valign = rtk.Widget.TOP
    self.position = rtk.Widget.RELATIVE

    self.hovering = false

    -- Computed coordinates relative to widget parent container
    self.cx = nil
    self.cy = nil
    self.cw = nil
    self.ch = nil

    -- Box supplied from parent on last reflow
    self.box = nil
    -- Absolute window x/y offsets that were supplied in last draw
    self.last_offx = nil
    self.last_offy = nil

    -- Indicates whether the widget should be rendered by its parent.
    self.visible = true
    -- True if the widget is ready to be drawn (it is initialized and reflowed)
    self.realized = false

    self.debug_color = {math.random(), math.random(), math.random()}
end

function rtk.Widget:setattrs(attrs)
    if attrs ~= nil then
        table.merge(self, attrs)
    end
end

function rtk.Widget:draw_debug_box(offx, offy)
    if self.cw then
        gfx.set(self.debug_color[1], self.debug_color[2], self.debug_color[3], 0.3)
        gfx.rect(self.cx + offx, self.cy + offy, self.cw, self.ch, 1)
    end
end

function rtk.Widget:_hovering(offx, offy)
    local x, y = self.cx + offx, self.cy + offy
    return rtk.in_window and rtk.mouse.x >= x and rtk.mouse.y >= y and rtk.mouse.x <= x + self.cw and rtk.mouse.y <= y + self.ch
end

function rtk.Widget:_resolvesize(boxw, boxh, w, h, defw, defh)
    local function resolve(coord, box, default)
        if coord and box then
            if coord < -1 then
                return box + coord
            elseif coord <= 1 then
                return math.abs(box * coord)
            end
        end
        return coord or default
    end
    return resolve(w, boxw, defw), resolve(h, boxh, defh)
end


function rtk.Widget:_resolvepos(boxx, boxy, x, y, defx, defy)
    return x + boxx, y + boxy
end

function rtk.Widget:_reflow(boxx, boxy, boxw, boxh, fillw, fillh)
    self.cx, self.cy = self:_resolvepos(boxx, boxy, self.x, self.y, boxx, boxy)
    self.cw, self.ch = self:_resolvesize(boxw, boxh, self.w, self.h, fillw and boxw or nil, fillh and boxh or nill)
end

function rtk.Widget:_draw(offx, offy, event)
    self.last_offx, self.last_offy = offx, offy
    return false
end

-- Process an unhandled event.  It's the caller's responsibility not to
-- invoke this method on a handled event.  It's the implementation's
-- responsibility to determine if the widget _should_ handle this event,
-- and if so, to dispatch to the appropriate on* method and declare
-- the event handled by setting the handled attribute.
--
-- The default widget implementation handles mouse events only
function rtk.Widget:_handle_event(offx, offy, event)
    if self:_hovering(offx, offy) then
        event:set_widget_hovering(self)
        if not event.handled then
            if event.type == rtk.Event.MOUSEMOVE and self.hovering == false then
                self.hovering = true
                self:onhover(event)
            elseif event.type == rtk.Event.MOUSEDOWN then
                self:onmousedown(event)
                event.handled = self
            elseif event.type == rtk.Event.MOUSEUP and self:focused() then
                self:onclick(event)
                event.handled = self
            end
        end
    elseif event.type == rtk.Event.MOUSEMOVE and self.hovering == true then
        self:onblur(event)
        self.hovering = false
    end
end


function rtk.Widget:attr(attr, value)
    self[attr] = value
    self:onattr(attr, value)
    return self
end

function rtk.Widget:setcolor(s)
    local r, g, b, a = color2rgba(s)
    gfx.set(r, g, b, a)
end

function rtk.Widget:move(x, y)
    self.x, self.y = x, y
    return self
end

function rtk.Widget:resize(w, h)
    self.w, self.h = w, h
    return self
end

function rtk.Widget:reflow(boxx, boxy, boxw, boxh, fillw, fillh)
    if not boxx then
        if self.box then
            self:_reflow(table.unpack(self.box))
        end
    else
        self.box = {boxx, boxy, boxw, boxh, fillw, fillh}
        self:_reflow(boxx, boxy, boxw, boxh, fillw, fillh)
    end
    self:onreflow()
    self.realized = true
    return self.cx, self.cy, self.cw, self.ch
end

-- Ensures the widget is fully visible in the viewport, plus the additional
-- padding.
function rtk.Widget:scrolltoview(tpadding, bpadding)
    if not self.visible or not self.box then
        -- Not visible or not reflowed yet.
        return
    end
    local absy = self.last_offy + self.cy
    if absy - tpadding < 0 then
        local delta = tpadding - absy
        rtk.viewport.scrollby(0, -delta)
    elseif absy + self.ch + bpadding > rtk.h then
        local delta = absy + self.ch + bpadding - rtk.h
        rtk.viewport.scrollby(0, delta)
    end
end

function rtk.Widget:hide()
    if self.visible == true then
        self.visible = false
        rtk.queue_reflow()
    end
    return self
end

function rtk.Widget:show()
    if self.visible == false then
        self.visible = true
        rtk.queue_reflow()
        -- Set realized to false in case show() has been called from within a
        -- draw() handler for another widget earlier in the scene graph.  We
        -- need to make sure that this widget isn't drawn until it has a chance
        -- to reflow.
        self.realized = false
    end
    return self
end

function rtk.Widget:toggle()
    if self.visible == true then
        return self:hide()
    else
        return self:show()
    end
end

function rtk.Widget:focus()
    if rtk.focused then
        rtk.focused:blur()
    end
    rtk.focused = self
    return self
end

function rtk.Widget:blur()
    if self:focused() then
        rtk.focused = nil
    end
    return self
end

function rtk.Widget:focused()
    return rtk.focused == self
end

function rtk.Widget:onattr(attr, value)
    self:reflow()
end

function rtk.Widget:ondraw(offx, offy, event)
end

function rtk.Widget:onmousedown(event)
    self:focus()
    return true
end

function rtk.Widget:onmousemove(event)
end

function rtk.Widget:onclick(event) end
function rtk.Widget:onhover(event) end
function rtk.Widget:onblur(event) end

function rtk.Widget:onreflow() end

-------------------------------------------------------------------------------------------------------------

rtk.Container = class('rtk.Container', rtk.Widget)
rtk.Container.static.FLEXSPACE = nil

function rtk.Container:initialize(attrs)
    rtk.Widget.initialize(self)
    self.children = {}
    -- Children from last reflow().  This list is the one that's drawn on next
    -- draw() rather than self.children, in case a child is added or removed
    -- in an event handler invoked from draw()
    self._reflowed_children = {}
    self.spacing = 0
    self.bg = nil
    self:setattrs(attrs)
end

function rtk.Container:clear()
    self.children = {}
    rtk.queue_reflow()
end

function rtk.Container:insert(pos, widget, attrs)
    table.insert(self.children, pos, {widget, attrs or {}})
    rtk.queue_reflow()
    return widget
end

function rtk.Container:add(widget, attrs)
    self.children[#self.children+1] = {widget, attrs or {}}
    rtk.queue_reflow()
    return widget
end

function rtk.Container:remove(widget)
    for n, widgetattrs in ipairs(self.children) do
        local w, _ = table.unpack(widgetattrs)
        if widget == w then
            rtk.queue_reflow()
            table.remove(self.children, n)
            return n
        end
    end
end

function rtk.Container:get_child(idx)
    return self.children[idx][1]
end

function rtk.Container:_handle_event(offx, offy, event)
    local x, y = self.cx + offx, self.cy + offy
    for idx, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        if widget ~= rtk.Container.FLEXSPACE and widget.visible == true and widget.realized then
            if widget.position == rtk.Widget.FIXED then
                widget:_handle_event(x + rtk.viewport.x, y + rtk.viewport.y, event)
            else
                widget:_handle_event(x, y, event)
            end
            if event.handled then
                return
            end
        end
    end
    -- If the event wasn't handled and there's a background defined, then we give the
    -- container the opportunity to handle the event, to e.g. prevent mouseover events
    -- from falling through to lower z-index widgets that are obscured by the container.
    if self.bg then
        rtk.Widget._handle_event(self, offx, offy, event)
    end
end

function rtk.Container:_draw(offx, offy, event)
    self.last_offx, self.last_offy = offx, offy
    local x, y = self.cx + offx, self.cy + offy
    if self.bg then
        self:setcolor(self.bg)
        gfx.rect(x, y, self.cw, self.ch, 1)
    end
    -- Draw widgets in reverse order, so that earlier inserted widgets implicitly
    -- have a higher z-index.
    for idx = #self._reflowed_children, 1, -1 do
        local widget, attrs = table.unpack(self._reflowed_children[idx])
        if widget ~= rtk.Container.FLEXSPACE and widget.realized then
            if widget.position == rtk.Widget.FIXED then
                widget:_draw(x + rtk.viewport.x, y + rtk.viewport.y, event)
            else
                widget:_draw(x, y, event)
            end
        end
    end
    self:ondraw(offx, offy, event)
end

function rtk.Container:_reflow(boxx, boxy, boxw, boxh)
    local x, y = self:_resolvepos(boxx, boxy, self.x, self.y, boxx, boxy)
    local w, h = self:_resolvesize(boxw, boxh, self.w, self.h, boxw, boxh)

    local child_w = w - self.lpadding - self.rpadding
    local child_h = h - self.tpadding - self.bpadding

    local innerw, innerh = 0, 0
    self._reflowed_children = {}
    for _, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        if widget.visible == true then
            local lpadding, rpadding = attrs.lpadding or 0, attrs.rpadding or 0
            local tpadding, bpadding = attrs.tpadding or 0, attrs.bpadding or 0
            local wx, wy, ww, wh = widget:reflow(self.lpadding + lpadding, self.tpadding + tpadding, child_w - lpadding - rpadding, child_h - tpadding - bpadding)
            innerw = math.max(innerw, ww)
            innerh = math.max(innerh, wh)

            if attrs.halign == rtk.Widget.RIGHT then
                widget.cx = wx + (w - ww)
                widget.box[1] = w - ww
            elseif attrs.halign == rtk.Widget.CENTER then
                widget.cx = wx + (w - ww) / 2
                widget.box[1] = (w - ww) / 2
            end
            if attrs.valign == rtk.Widget.BOTTOM then
                widget.cy = wy + (h - wh)
                widget.box[2] = h - wh
            elseif attrs.valign == rtk.Widget.CENTER then
                widget.cy = wy + (h - wh) / 2
                widget.box[2] = (h - wh) / 2
            end

            self._reflowed_children[#self._reflowed_children+1] = widgetattrs
        else
            widget.realized = false
        end
    end

    -- Set our own dimensions, so add self padding to inner dimensions
    outerw = innerw + self.lpadding + self.rpadding
    outerh = innerh + self.tpadding + self.bpadding

    self.cx, self.cy, self.cw, self.ch = x, y, math.max(outerw, self.w or 0), math.max(outerh, self.h or 0)
end


-------------------------------------------------------------------------------------------------------------
rtk.Box = class('rtk.Box', rtk.Container)
rtk.Box.static.HORIZONTAL = 1
rtk.Box.static.VERTICAL = 2

function rtk.Box:initialize(direction, attrs)
    self.direction = direction
    rtk.Container.initialize(self, attrs)
end

function rtk.Box:get_child_index(child)
    for n, widgetattrs in ipairs(self.children) do
        local widget, _ = table.unpack(widgetattrs)
        if widget == child then
            return n
        end
    end
end

function rtk.Box:_reflow(boxx, boxy, boxw, boxh)
    local x, y = self:_resolvepos(boxx, boxy, self.x, self.y, boxx, boxy)
    local w, h = self:_resolvesize(boxw, boxh, self.w, self.h, boxw, boxh)

    local child_w = w - self.lpadding - self.rpadding
    local child_h = h - self.tpadding - self.bpadding

    local innerw, innerh, expand_unit_size = self:_reflow_step1(child_w, child_h)
    local innerw, innerh = self:_reflow_step2(child_w, child_h, innerw, innerh, expand_unit_size)

    -- Set our own dimensions, so add self padding to inner dimensions
    outerw = innerw + self.lpadding + self.rpadding
    outerh = innerh + self.tpadding + self.bpadding

    self.cx, self.cy, self.cw, self.ch = x, y, math.max(outerw, self.w or 0), math.max(outerh, self.h or 0)
end


-- First pass over non-expanded children to compute available width/height
-- remaining to spread between expanded children.
function rtk.Box:_reflow_step1(w, h)
    local expand_units = 0
    local remaining_size = self.direction == 1 and w or h
    local maxw, maxh = 0, 0
    local spacing = 0
    self._reflowed_children = {}
    for n, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        if widget == rtk.Container.FLEXSPACE then
            expand_units = expand_units + (attrs.expand or 1)
            spacing = 0
        elseif widget.visible == true then
            local ww, wh
            local lpadding, rpadding = attrs.lpadding or 0, attrs.rpadding or 0
            local tpadding, bpadding = attrs.tpadding or 0, attrs.bpadding or 0
            -- Reflow at 0,0 coords just to get the native dimensions.  Will adjust position in second pass.
            if not attrs.expand or attrs.expand == 0 then
                if self.direction == 1 then
                    _, _, ww, wh = widget:reflow(0, 0, remaining_size - lpadding - rpadding - spacing, h - tpadding - bpadding)
                else
                    _, _, ww, wh = widget:reflow(0, 0, w - lpadding - rpadding, remaining_size - tpadding - bpadding - spacing)
                end
                maxw = math.max(maxw, ww)
                maxh = math.max(maxh, wh)
                if self.direction == 1 then
                    remaining_size = remaining_size - ww - lpadding - rpadding - spacing
                else
                    remaining_size = remaining_size - wh - tpadding - bpadding - spacing
                end
            else
                expand_units = expand_units + attrs.expand
            end
            spacing = attrs.spacing or self.spacing
            self._reflowed_children[#self._reflowed_children+1] = widgetattrs
        else
            widget.realized = false
        end
    end
    local expand_unit_size = expand_units > 0 and remaining_size / expand_units or 0
    return maxw, maxh, expand_unit_size
end


-------------------------------------------------------------------------------------------------------------
rtk.VBox = class('rtk.VBox', rtk.Box)

function rtk.VBox:initialize(attrs)
    rtk.Box.initialize(self, rtk.Box.VERTICAL, attrs)
end

-- Second pass over all children
function rtk.VBox:_reflow_step2(w, h, maxw, maxh, expand_unit_size)
    local offset = self.tpadding
    spacing = 0
    for n, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        if widget == rtk.Container.FLEXSPACE then
            offset = offset + expand_unit_size * (attrs.expand or 1)
            spacing = 0
        elseif widget.visible == true then
            local wx, wy, ww, wh
            local lpadding, rpadding = attrs.lpadding or 0, attrs.rpadding or 0
            local tpadding, bpadding = attrs.tpadding or 0, attrs.bpadding or 0
            local offx = self.lpadding
            if attrs.halign == rtk.Widget.CENTER then
                offx = (maxw - widget.cw) / 2
            elseif attrs.halign == rtk.Widget.RIGHT then
                offx = maxw - widget.cw - self.rpadding
            end
            if attrs.expand and attrs.expand > 0 then
                -- This is an expanded child which was not reflown in pass 1, so do it now.
                local fillh = (expand_unit_size * attrs.expand) - tpadding - bpadding - spacing
                wx, wy, ww, wh = widget:reflow(offx + lpadding, offset + tpadding + spacing, w - lpadding - rpadding, fillh, nil, attrs.fill)

                if not attrs.fill then
                    if attrs.valign == rtk.Widget.BOTTOM then
                        widget.cy = wy + (fillh - wh)
                        widget.box[2] = fillh - wh
                    elseif attrs.valign == rtk.Widget.CENTER then
                        widget.cy = wy + (fillh - wh) / 2
                        widget.box[2] = (fillh - wh) / 2
                    end
                    wh = fillh
                end
            else
                -- Non-expanded widget with native size, already reflown in pass 1.  Just need
                -- to adjust position.
                widget.cx = widget.cx + offx + lpadding
                widget.cy = widget.cy + offset + tpadding + spacing
                widget.box[1] = offx + lpadding
                widget.box[2] = offset + tpadding + spacing
                ww, wh = widget.cw, widget.ch
            end
            offset = offset + wh + tpadding + spacing + bpadding
            maxw = math.max(maxw, ww)
            maxh = math.max(maxh, offset)
            spacing = attrs.spacing or self.spacing
        end
    end
    return maxw, maxh
end



-------------------------------------------------------------------------------------------------------------

rtk.HBox = class('rtk.HBox', rtk.Box)

function rtk.HBox:initialize(attrs)
    rtk.Box.initialize(self, rtk.Box.HORIZONTAL, attrs)
end

-- TODO: there is too much in common here with VBox:_reflow_step2().  This needs
-- to be refactored better, by using more tables with indexes rather than unpacking
-- to separate variables.
function rtk.HBox:_reflow_step2(w, h, maxw, maxh, expand_unit_size)
    local offset = self.lpadding
    spacing = 0
    for n, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        if widget == rtk.Container.FLEXSPACE then
            offset = offset + expand_unit_size * (attrs.expand or 1)
            spacing = 0
        elseif widget.visible == true then
            local wx, wy, ww, wh
            local lpadding, rpadding = attrs.lpadding or 0, attrs.rpadding or 0
            local tpadding, bpadding = attrs.tpadding or 0, attrs.bpadding or 0
            local offy = self.tpadding
            if attrs.valign == rtk.Widget.CENTER then
                offy = (maxh - widget.ch) / 2
            elseif attrs.valign == rtk.Widget.BOTTOM then
                offy = maxh - widget.ch
            end
            if attrs.expand and attrs.expand > 0 then
                -- This is an expanded child which was not reflown in pass 1, so do it now.
                local fillw = (expand_unit_size * attrs.expand) - lpadding - rpadding - spacing
                wx, wy, ww, wh = widget:reflow(offset + lpadding + spacing, offy + tpadding, fillw, h - tpadding - bpadding, attrs.fill, nil)
                if not attrs.fill then
                    if attrs.halign == rtk.Widget.RIGHT then
                        widget.cx = wx + (fillw - ww)
                        widget.box[1] = fillw - ww
                    elseif attrs.halign == rtk.Widget.CENTER then
                        widget.cx = wx + (fillw - ww) / 2
                        widget.box[1] = (fillw - ww) / 2
                    end
                    ww = fillw
                end
            else
                -- Non-expanded widget with native size, already reflown in pass 1.  Just need
                -- to adjust position.
                widget.cx = widget.cx + offset + lpadding + spacing
                widget.cy = widget.cy + offy + tpadding
                widget.box[1] = offset + lpadding + spacing
                widget.box[2] = offy + tpadding
                ww, wh = widget.cw, widget.ch
            end
            offset = offset + ww + lpadding + spacing + rpadding
            maxw = math.max(maxw, offset)
            maxh = math.max(maxh, wh)
            spacing = attrs.spacing or self.spacing
        end
    end
    return maxw, maxh
end


-------------------------------------------------------------------------------------------------------------

rtk.Button = class('rtk.Button', rtk.Widget)
-- Flags
rtk.Button.static.FULL_SURFACE = 0
rtk.Button.static.FLAT_ICON = 1
rtk.Button.static.FLAT_LABEL = 2
rtk.Button.static.ICON_RIGHT = 4


function rtk.Button:initialize(attrs)
    rtk.Widget.initialize(self)
    self.label = nil
    self.icon = nil
    self.color = rtk.theme.button
    -- Text color when label is drawn over button surface
    self.textcolor = rtk.theme.buttontext
    -- Text color when button surface isn't drawn
    self.textcolor2 = rtk.theme.text
    self.flags = rtk.Button.FULL_SURFACE
    self.lspace = 10
    self.rspace = 5
    self.font, self.fontsize = table.unpack(rtk.fonts.button or rtk.fonts.default)
    self.fontscale = 1.0
    self:setattrs(attrs)
    if self.icon == nil then
        self.flags = self.flags | rtk.Button.FLAT_ICON
    end
    if self.label == nil then
        self.flags = self.flags | rtk.Button.FLAT_LABEL
    end
    -- The (if necessary) truncated label to fit the viewable label area
    self.vlabel = self.label
end


function rtk.Button:_reflow(boxx, boxy, boxw, boxh, fillw, fillh)
    self.cx, self.cy = self:_resolvepos(boxx, boxy, self.x, self.y, boxx, boxy)
    local w, h = self:_resolvesize(boxw, boxh, self.w, self.h)

    if w == nil and fillw then
        -- Requested to fill box width, so set inner width (box width minus internal padding)
        w = boxw - self.lpadding - self.rpadding
    end
    if h == nil and fillh then
        -- Requested to fill box height.
        h = boxh - self.tpadding - self.bpadding
    end

    if self.label ~= nil then
        gfx.setfont(1, self.font, self.fontsize * self.fontscale * rtk.scale, 0)
        self.lw, self.lh = gfx.measurestr(self.label)
        if self.icon ~= nil then
            self.cw = w or ((self.icon.width + self.lpadding + self.rpadding + self.lspace + self.rspace) * rtk.scale + self.lw)
            self.ch = h or (math.max(self.icon.height * rtk.scale, self.lh) + (self.tpadding + self.bpadding) * rtk.scale)
        else
            self.cw = (w and w * rtk.scale or self.lw) + (self.lpadding + self.rpadding) * rtk.scale
            self.ch = (h and h * rtk.scale or self.lh) + (self.tpadding + self.bpadding) * rtk.scale
        end

        -- Calculate the viewable portion of the label
        local lwmax = self.cw - (self.lpadding + self.rpadding) * rtk.scale
        if self.icon then
            lwmax = lwmax - (self.icon.width + self.lspace + self.rspace) * rtk.scale
        end
        if self.lw > lwmax + 1 then
            -- Text width will overflow the max space available for the label.  Truncate
            -- the label to fit.
            for i = 1, self.label:len() do
                local vlabel = self.label:sub(1, i)
                local lw, _ = gfx.measurestr(vlabel)
                if lw > lwmax then
                    break
                end
                self.vlabel = vlabel
            end
        else
            self.vlabel = self.label
        end
    elseif self.icon ~= nil then
        self.cw = w or (self.icon.width + self.lpadding + self.rpadding) * rtk.scale
        self.ch = h or (self.icon.height + self.tpadding + self.bpadding) * rtk.scale
    end
end


function rtk.Button:_draw(offx, offy, event)
    self.last_offx, self.last_offy = offx, offy
    local x, y = self.cx + offx, self.cy + offy
    local sx, sy, sw, sh = x, y, 0, 0

    if y + self.ch < 0 or y > rtk.h then
        -- Widget not viewable on viewport
        return false
    end

    -- TODO: finish support for alignment attributes
    local hover = event:is_widget_hovering(self)
    local lx, ix, sepx = nil, nil, nil
    -- Default label color to surfaceless color and override if label is drawn on surface
    local textcolor = self.textcolor2
    local draw_icon_surface = self.flags & rtk.Button.FLAT_ICON == 0
    local draw_label_surface = self.flags & rtk.Button.FLAT_LABEL == 0
    local draw_separator = false
    -- Button has both icon and label
    if self.icon ~= nil and self.label ~= nil then
        -- Either hovering or both icon and label need to be rendered on button surface
        if hover or (draw_icon_surface and draw_label_surface) then
            sw, sh = self.cw, self.ch
            textcolor = self.textcolor
            draw_separator = true
        -- Icon on surface with flat label
        elseif not draw_label_surface and draw_icon_surface and self.icon ~= nil then
            sw = (self.icon.width + self.lpadding + self.rpadding) * rtk.scale
            sh = self.ch
        end
        local iconwidth = (self.icon.width + self.lpadding) * rtk.scale
        if self.flags & rtk.Button.ICON_RIGHT == 0 then
            lx = sx + iconwidth + (self.lspace * rtk.scale)
            ix = sx + self.lpadding * rtk.scale
            sepx = sx + iconwidth + self.lspace/2
        else
            ix = x + self.cw - iconwidth
            sx = x + self.cw - sw
            lx = x + (self.lpadding + self.lspace) * rtk.scale
            sepx = ix + self.lspace / 2
        end
    -- Label but no icon
    elseif self.label ~= nil and self.icon == nil then
        if hover or draw_label_surface then
            sw, sh = self.cw, self.ch
            textcolor = self.textcolor
        end
        if self.halign == rtk.Widget.LEFT then
            lx = sx + self.lpadding * rtk.scale
        elseif self.halign == rtk.Widget.CENTER then
            lx = sx + (self.cw - self.lw) / 2
        elseif self.halign == rtk.Widget.RIGHT then
            lx = sx + (self.cw - self.lw) - self.rpadding * rtk.scale
        end
    -- Icon but no label
    elseif self.icon ~= nil and self.label == nil then
        ix = sx + self.lpadding * rtk.scale
        if hover or draw_icon_surface then
            sw, sh = self.cw, self.ch
        end
    end

    local r, g, b, a = color2rgba(self.color)
    if sw and sh and sw > 0 and sh > 0 then
        if hover and rtk.mouse.down ~= 0 and self:focused() then
            r, g, b = r*0.8, g*0.8, b*0.8
            gfx.gradrect(sx, sy, sw, sh, r, g, b, a,  0, 0, 0, 0,   -r/50, -g/50, -b/50, 0)
            gfx.set(1, 1, 1, 0.2)
            gfx.rect(sx, sy, sw, sh, 0)
        else
            gfx.gradrect(sx, sy, sw, sh, r, g, b, a,  0, 0, 0, 0,   -r/75, -g/75, -b/75, 0)
            gfx.set(1, 1, 1, 0.1)
            gfx.rect(sx, sy, sw, sh, 0)
        end
        if sepx and draw_separator then
            gfx.set(0, 0, 0, 0.3)
            gfx.line(sepx, sy + 1, sepx, sy + sh - 2)
        end
    end
    gfx.set(1, 1, 1, 1)
    if self.icon then
        self:_draw_icon(ix, sy + (self.ch - self.icon.height * rtk.scale) / 2)
    end
    if self.vlabel then
        gfx.x = lx
        gfx.y = sy + (self.ch - self.lh) / 2
        gfx.setfont(1, self.font, self.fontsize * self.fontscale * rtk.scale, 0)
        self:setcolor(textcolor)
        gfx.drawstr(self.vlabel)
    end
    self:ondraw(offx, offy, event)
end

function rtk.Button:_draw_icon(x, y)
    self.icon:draw(x, y, rtk.scale)
end

function rtk.Button:onclick(event)
end


-------------------------------------------------------------------------------------------------------------

-- TODO: handle text selection with mouse and keyboard
-- TODO: handle ctrl-left/right for word skip
rtk.Entry = class('rtk.Entry', rtk.Widget)
rtk.Entry.static.MAX_WIDTH = 1024
function rtk.Entry:initialize(attrs)
    rtk.Widget.initialize(self)
    -- Width of the text field based on number of characters
    self.textwidth = nil
    -- Maximum number of characters allowed from input
    self.max = nil
    self.value = ''
    self.font, self.fontsize = table.unpack(rtk.fonts.entry or rtk.fonts.default)
    self.lpadding = 5
    self.tpadding = 3
    self.rpadding = 5
    self.bpadding = 3
    self.label = ''

    self.cursor = 1
    self.lpos = 1
    self.rpos = nil
    self.loffset = 0
    self.anchor = -1
    -- Array mapping character index to x offset
    self.positions = {0}
    self.image = rtk.Image:new()
    self.image:create()

    self.lpos = 5

    self:setattrs(attrs)

    self._cursorctr = 0

end

function rtk.Entry:_reflow(boxx, boxy, boxw, boxh, fillw, fillh)
    local maxw, maxh = nil, nil
    if self.textwidth and not self.w then
        -- Compute dimensions based on font and size
        gfx.setfont(1, self.font, self.fontsize * rtk.scale, 0)
        maxw, maxh = gfx.measurestr(string.rep("D", self.textwidth))
    elseif not self.h then
        gfx.setfont(1, self.font, self.fontsize * rtk.scale, 0)
        _, maxh = gfx.measurestr("Dummy!")
    end

    self.cx, self.cy = self:_resolvepos(boxx, boxy, self.x, self.y, boxx, boxy)
    local w, h = self:_resolvesize(boxw, boxh, self.w, self.h,
                                   (not fillw and maxw) or (boxw - self.lpadding - self.rpadding),
                                   (not fillh and maxh) or (boxh - self.tpadding - self.bpadding))
    self.cw, self.ch = w + self.lpadding + self.rpadding, h + self.tpadding + self.bpadding

    self.image:resize(rtk.Entry.MAX_WIDTH, maxh)
    self:calcpositions()
    self:calcview()
    self:rendertext()
end

function rtk.Entry:calcpositions(startfrom)
    -- Ok, this isn't exactly efficient, but it should be fine for sensibly sized strings.
    gfx.setfont(1, self.font, self.fontsize * rtk.scale, 0)
    for i = (startfrom or 1), self.value:len() do
        local w, _ = gfx.measurestr(self.value:sub(1, i))
        self.positions[i + 1] = w
    end
end

function rtk.Entry:calcview()
    local curx = self.positions[self.cursor]
    local curoffset = curx - self.loffset
    local contentw = self.cw - (self.lpadding + self.rpadding)
    if curoffset < 0 then
        self.loffset = curx
    elseif curoffset > contentw then
        self.loffset = curx - contentw
    end
end

function rtk.Entry:rendertext()
    gfx.setfont(1, self.font, self.fontsize * rtk.scale, 0)
    self.image:clear(hex2rgb(rtk.theme.entry_bg))
    gfx.dest = self.image.id
    self:setcolor(rtk.theme.text)
    gfx.x, gfx.y = 0, 0
    gfx.drawstr(self.value)
    gfx.dest = -1
end

function rtk.Entry:_draw(offx, offy, event)
    self.last_offx, self.last_offy = offx, offy
    local x, y = self.cx + offx, self.cy + offy
    local focused = self:focused()

    if (y + self.ch < 0 or y > rtk.h) and not focused then
        -- Widget not viewable on viewport
        return false
    end

    local hover = event:is_widget_hovering(self)

    self:setcolor(rtk.theme.entry_bg)
    gfx.rect(x, y, self.cw, self.ch, 1)

    self.image:drawregion(
        self.loffset, 0, x + self.lpadding, y + self.tpadding,
        self.cw - self.lpadding - self.rpadding, self.ch - self.tpadding - self.bpadding
    )

    if self.label and #self.value == 0 then
        gfx.setfont(1, self.font, self.fontsize * rtk.scale, rtk.fonts.ITALICS)
        gfx.x, gfx.y = x + self.lpadding, y + self.tpadding
        self:setcolor(rtk.theme.entry_label)
        gfx.drawstr(self.label)
    end

    if hover then
        rtk.mouse.cursor = rtk.mouse.cursors.beam
        if not focused then
            -- Draw border
            self:setcolor(rtk.theme.entry_border_hover)
            gfx.rect(x, y, self.cw, self.ch, 0)
        end
        if event.type == rtk.Event.MOUSEMOVE then
            event.handled = self
        end
    end
    if hover and event and event.type == rtk.Event.MOUSEDOWN then
        self.cursor = self:_get_cursor_from_mousedown(x, y, event)
    end
    if focused then
        local ctr = self._cursorctr % 24
        self._cursorctr = self._cursorctr + 1
        -- Draw border
        self:setcolor(rtk.theme.entry_border_focused)
        gfx.rect(x, y, self.cw, self.ch, 0)
        -- Draw cursor
        if ctr < 12 then
            local curx = x + self.positions[self.cursor] + self.lpadding - self.loffset
            self:setcolor(rtk.theme.text)
            gfx.line(curx, y + self.tpadding, curx, y + self.ch - self.bpadding, 0)
        end
        -- Request a redraw to keep the cursor blinking while focused.
        rtk.queue_draw()
    end
    self:ondraw(offx, offy, event)
end

-- Given absolute coords of the text area, determine the cursor position from
-- the mouse down event.
function rtk.Entry:_get_cursor_from_mousedown(x, y, event)
    local relx = self.loffset + event.x - x
    for i = 1, self.value:len() + 1 do
        if relx < self.positions[i] then
            return i - 1
        end
    end
    return self.value:len() + 1
end

function rtk.Entry:_handle_event(offx, offy, event)
    if event.handled then
        return
    end
    rtk.Widget._handle_event(self, offx, offy, event)
    if event.type == rtk.Event.KEY and self:focused() then
        if self:onkeypress(event) == false then
            return
        end
        event.handled = self
        local len = self.value:len()
        if event.keycode == rtk.keycodes.LEFT then
            self.cursor = math.max(1, self.cursor - 1)
        elseif event.keycode == rtk.keycodes.RIGHT then
            self.cursor = math.min(self.cursor + 1, len + 1)
        elseif event.keycode == rtk.keycodes.HOME then
            self.cursor = 1
        elseif event.keycode == rtk.keycodes.END then
            self.cursor = self.value:len() + 1
        elseif event.keycode == rtk.keycodes.DELETE then
            self.value = self.value:sub(1, self.cursor - 1) .. self.value:sub(self.cursor + 1)
            self:calcpositions(self.cursor)
            self:onchange()
        elseif event.keycode == rtk.keycodes.BACKSPACE and self.cursor > 1 then
            self.value = self.value:sub(1, self.cursor - 2) .. self.value:sub(self.cursor)
            self.cursor = math.max(1, self.cursor - 1)
            self:calcpositions(self.cursor)
            self:onchange()
        elseif event.char and (len == 0 or self.positions[len] < rtk.Entry.MAX_WIDTH) then
            if not self.max or len < self.max then
                self.value = self.value:sub(0, self.cursor - 1) .. event.char .. self.value:sub(self.cursor)
                self:calcpositions(self.cursor)
                self.cursor = self.cursor + 1
                self:onchange()
            end
        else
            return
        end
        -- Reset cursor
        self._cursorctr = 0
        self:calcview()
        self:rendertext()
    end
end

function rtk.Entry:onattr(attr, value)
    rtk.Widget.onattr(self, value)
    if attr == 'value' then
        -- After setting value, ensure cursor does not extend past end of value.
        if self.cursor >= value:len() then
            self.cursor = value:len() + 1
        end
        self:onchange()
    end
end

function rtk.Entry:onclick(event)
    rtk.Widget.focus(self)
end

function rtk.Entry:onchange() end

function rtk.Entry:onkeypress()
    return true
end


-------------------------------------------------------------------------------------------------------------


rtk.Label = class('rtk.Label', rtk.Widget)

function rtk.Label:initialize(attrs)
    rtk.Widget.initialize(self)
    self.label = 'Label'
    self.color = rtk.theme.text
    self.font, self.fontsize, self.fontflags = table.unpack(rtk.fonts.label or rtk.fonts.default)
    self:setattrs(attrs)
end

function rtk.Label:_reflow(boxx, boxy, boxw, boxh, fillw, fillh)
    self.cx, self.cy = self:_resolvepos(boxx, boxy, self.x, self.y, boxx, boxy)
    local w, h = self:_resolvesize(boxw, boxh, self.w, self.h, fillw and boxw or nil, fillh and boxh or nil)

    if not w or not h then
        gfx.setfont(1, self.font, self.fontsize * rtk.scale, self.fontflags or 0)
        local lw, lh = gfx.measurestr(self.label)
        if not w then
            w = lw + (self.lpadding + self.rpadding) * rtk.scale
        end
        if not h then
            h = lh + (self.tpadding + self.bpadding) * rtk.scale
        end
        self.lw, self.lh = lw, lh
    end
    self.cw, self.ch = w, h
end

function rtk.Label:_draw(offx, offy, event)
    self.last_offx, self.last_offy = offx, offy
    local x, y = self.cx + offx, self.cy + offy

    if y + self.ch < 0 or y > rtk.h then
        -- Widget not viewable on viewport
        return
    end

    if self.halign == rtk.Widget.LEFT then
        gfx.x = x + self.lpadding
    elseif self.halign == rtk.Widget.CENTER then
        gfx.x = x + (self.cw - self.lw) / 2
    elseif self.halign == rtk.Widget.RIGHT then
        gfx.x = x + (self.cw - self.lw) - self.rpadding
    end
    -- TODO: support vertical alignment options.  Defaults to center.
    gfx.y = y + (self.ch - self.lh) / 2
    self:setcolor(self.color)
    gfx.setfont(1, self.font, self.fontsize * rtk.scale, self.fontflags or 0)
    gfx.drawstr(self.label)
    self:ondraw(offx, offy, event)
end

-------------------------------------------------------------------------------------------------------------


rtk.ImageBox = class('rtk.ImageBox', rtk.Widget)

function rtk.ImageBox:initialize(attrs)
    rtk.Widget.initialize(self)
    self.image = nil
    self:setattrs(attrs)
end

function rtk.ImageBox:_reflow(boxx, boxy, boxw, boxh, fillw, fillh)
    self.cx, self.cy = self:_resolvepos(boxx, boxy, self.x, self.y, boxx, boxy)
    local w, h = self:_resolvesize(boxw, boxh, self.w, self.h, fillw and boxw or nil, fillh and boxh or nil)

    if not w or not h then
        if self.image then
            w, h = self.image.width, self.image.height
        else
            w, h = 0, 0
        end
    end
    self.cw, self.ch = w, h
end

function rtk.ImageBox:_draw(offx, offy, event)
    self.last_offx, self.last_offy = offx, offy
    local x, y = self.cx + offx, self.cy + offy

    if not self.image or y + self.ch < 0 or y > rtk.h then
        -- Widget not viewable on viewport
        return
    end

    if self.halign == rtk.Widget.LEFT then
        x = x + self.lpadding
    elseif self.halign == rtk.Widget.CENTER then
        x = x + self.cw / 2
    elseif self.halign == rtk.Widget.RIGHT then
        x = x + self.cw - self.rpadding
    end

    if self.valign == rtk.Widget.TOP then
        y = y + self.tpadding
    elseif self.valign == rtk.Widget.CENTER then
        y = y + self.ch / 2
    elseif self.valign == rtk.Widget.BOTTOM then
        y = y + self.ch - self.bpadding
    end

    self.image:draw(x, y, rtk.scale)
    self:ondraw(offx, offy, event)
end


-------------------------------------------------------------------------------------------------------------

rtk.Heading = class('rtk.Heading', rtk.Label)

function rtk.Heading:initialize(attrs)
    rtk.Label.initialize(self)
    self.font, self.fontsize, self.fontflags = table.unpack(rtk.fonts.heading or rtk.fonts.default)
    self:setattrs(attrs)
end

-------------------------------------------------------------------------------------------------------------

rtk.OptionMenu = class('rtk.OptionMenu', rtk.Button)
rtk.OptionMenu.static._icon = nil
rtk.OptionMenu.static.SEPARATOR = 0
rtk.OptionMenu.static.ITEM_CHECKED = 1
rtk.OptionMenu.static.ITEM_DISABLED = 2
rtk.OptionMenu.static.HIDE_LABEL = 32768

function rtk.OptionMenu:initialize(attrs)
    self.menu = {}
    self.selected = nil
    self.selected_id = nil
    rtk.Button.initialize(self, attrs)

    self._menustr = nil
    self._suppress_onchange = false

    if not self.icon then
        if not rtk.OptionMenu._icon then
            -- Generate a new simple triangle icon for the button.
            local icon = rtk.Image:new():create(24, 18)
            self:setcolor(rtk.theme.text)
            gfx.dest = icon.id
            gfx.triangle(10, 6,  18, 6,  14, 10)
            gfx.dest = -1
            rtk.OptionMenu.static._icon = icon
        end
        self.icon = rtk.OptionMenu.static._icon
        self.flags = rtk.Button.ICON_RIGHT
    end
end

function rtk.OptionMenu:setmenu(menu)
    return self:attr('menu', menu)
end

function rtk.OptionMenu:select(value, trigger)
    self._suppress_onchange = not trigger or false
    return self:attr('selected', value)
end


function rtk.OptionMenu:onattr(attr, value)
    if attr == 'menu' then
        self._item_by_idx = {}
        self._idx_by_id = {}
        self._menustr = self:_build_submenu(self.menu)
    elseif attr == 'selected' then
        -- First lookup by user id.
        local idx = self._idx_by_id[value]
        if idx then
            -- Index exists by id.
            value = idx
        end
        local item = self._item_by_idx[value]
        if item then
            if self.flags & rtk.OptionMenu.HIDE_LABEL == 0 then
                self.label = item.buttonlabel or item.label
            end
            self.selected_id = item.id
            rtk.Button.onattr(self, attr, value)
            if not self._suppress_onchange then
                self:onchange()
            end
        end
        self._suppress_onchange = false
    else
        rtk.Button.onattr(self, attr, value)
    end
end

function rtk.OptionMenu:_build_submenu(submenu)
    local menustr = ''
    for n, menuitem in ipairs(submenu) do
        local label, id, flags, buttonlabel = nil, nil, nil, nil
        if type(menuitem) ~= 'table' then
            label = menuitem
        else
            label, id, flags, buttonlabel = table.unpack(menuitem)
        end
        if type(id) == 'table' then
            -- Append a special marker '#|' as a sentinel to indicate the end of the submenu.
            -- See onattr() above for rationale.
            menustr = menustr .. '>' .. label .. '|' .. self:_build_submenu(id) .. '<|'
        elseif label == rtk.OptionMenu.SEPARATOR then
            menustr = menustr .. '|'
        else
            self._item_by_idx[#self._item_by_idx + 1] = {label=label, id=id, flags=flags, buttonlabel=buttonlabel}
            -- Map this index to the user id (or a stringified version of the
            -- index if no user id is given)
            self._idx_by_id[id or #self._item_by_idx] = #self._item_by_idx
            if flags then
                if flags & rtk.OptionMenu.ITEM_CHECKED ~= 0 then
                    label = '!' .. label
                end
                if flags & rtk.OptionMenu.ITEM_DISABLED ~= 0 then
                    label = '#' .. label
                end
            end
            -- menustr = menustr .. (n == #submenu and '<' or '') .. label .. '|'
            menustr = menustr .. label .. '|'
        end
    end
    return menustr
end

function rtk.OptionMenu:onmousedown(event)
    local function popup()
        gfx.x, gfx.y = self.cx + self.last_offx, self.cy + self.last_offy + self.ch
        local choice = gfx.showmenu(self._menustr)
        if choice > 0 then
            self:attr('selected', choice)
        end
    end
    -- Force a redraw and then defer opening the popup menu so we get a UI refresh with the
    -- button pressed before pening the menu, which is modal and blocks further redraws.
    rtk.Button.onmousedown(self, event)
    self:_draw(self.last_offx, self.last_offy, event)
    self:ondraw(self.last_offx, self.last_offy, event)
    if self._menustr ~= nil then
        reaper.defer(popup)
    end
end

function rtk.OptionMenu:onchange() end

-------------------------------------------------------------------------------------------------------------
-- TODO!
--
rtk.Checkbox = class('rtk.Checkbox', rtk.Widget)

function rtk.Checkbox:initialize(attrs)
    rtk.Widget.initialize(self, attrs)
end

-------------------------------------------------------------------------------------------------------------

return rtk