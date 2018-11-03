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
local articons = require 'articons'
local reabank = require 'reabank'

require 'cfgui.screens.test'


local screen = {
    widget = nil,
    toolbar = nil,
    selected = nil,
    -- Table of checked items, keyed by row widget id.  If nil it means nothing is
    -- checked.
    checked = nil,
    num_checked = 0,
    num_articulations = 0,
}

function screen.select_row(row)
    if row == screen.bank_row then
        screen.bank_row.hint:hide()
    else
        screen.bank_row.hint:show()
    end
    row:scrolltoview(15, 15)
    screen.selected = row
end



local ArrowRow = class('ArrowRow', rtk.HBox)

function ArrowRow:initialize(attrs)
    -- attrs.bg = '#0000ff'
    attrs.focusable = true
    rtk.HBox.initialize(self, attrs)
end

function ArrowRow:onmousedown(event)
    if event.button == 1 and self ~= screen.bank_row and screen.selected ~= screen.bank_row then
        if event.shift then
            log("SPAN SELECT")
        elseif event.ctrl then
            log("single multiselect")
        end
    end
    if event.modifiers == 0 then
        return rtk.HBox.onmousedown(self, event)
    end
end

function ArrowRow:focus()
    rtk.HBox.focus(self)
    screen.select_row(self)
    return true
end

function ArrowRow:_draw_bg(offx, offy, event)
    local x, y = self.cx + offx, self.cy + offy
    local color
    if screen.selected == self then
        color = '#2c83b7'
    elseif event:is_widget_hovering(self) then
        color = '#2c83b77f'
    else
        return
    end
    local tsz = self.ch/2
    local tx = x + self.cw - tsz

    local r, g, b, a = color2rgba(color)
    local tdx = 0.3
    local dx = tdx / (self.cw - tsz)
    local dy = 0
    gfx.gradrect(x, y, self.cw - tsz, self.ch,   r - tdx, g - tdx, b - tdx, a,  dx,dx,dx, 0,   dy, dy, dy, 0)
    self:setcolor(color)
    gfx.triangle(
        tx, y,
        tx + tsz - 1, y + (self.ch / 2),
        tx - 1, y + self.ch - 1
    )

    -- gfx.triangle() does not do antialiasing, so we fake it by drawing lines over top, because
    -- gfx.line() *does* do AA.

    -- Delta for the outline
    local delta = -0.3
    self:setcolor({r + delta, g + delta, b + delta, 1.0})
    gfx.line(
        tx, y,
        tx + tsz - 1 , y + (self.ch / 2)
    )
    gfx.line(
        tx + tsz - 1, y + (self.ch / 2),
        tx, y + self.ch - 1
    )
    self:setcolor({r + delta, g + delta, b + delta, 0.85})
    gfx.line(x, y, x + self.cw - tsz - 1, y)
    gfx.line(x, y + self.ch, x + self.cw - tsz - 1, y + self.ch)
    gfx.line(x, y + 1, x, y + self.ch - 1)
end





local function handle_row_checked(row, state)
    if state == rtk.CheckBox.STATE_CHECKED then
        if not screen.checked then
            screen.checked = {}
        end
        if not screen.checked[row.id] then
            screen.checked[row.id] = row
            screen.num_checked = screen.num_checked + 1
        end
    elseif state == rtk.CheckBox.STATE_UNCHECKED then
        if screen.checked[row.id] then
            screen.checked[row.id] = nil
            screen.num_checked = screen.num_checked - 1
        end
    end
    if screen.num_checked == 0 then
        screen.checked = nil
    end
end

local function update_artheader_checkbox()
    if screen.num_checked == 0 then
        screen.artheader.checkbox:attr('value', rtk.CheckBox.STATE_UNCHECKED, false)
    elseif screen.num_checked == screen.num_articulations then
        screen.artheader.checkbox:attr('value', rtk.CheckBox.STATE_CHECKED, false)
    else
        screen.artheader.checkbox:attr('value', rtk.CheckBox.STATE_INDETERMINATE, false)
    end
    log("checkbox %s %s - num=%s", row, state, screen.num_checked)
end



local function make_articulation_row(art)
    local row = ArrowRow({tpadding=8, bpadding=8, lpadding=10, spacing=0, cursor=rtk.mouse.cursors.hand})
    local drag_handle = rtk.ImageBox:new({
        image=app:get_image('drag_vertical_18x18.png'),
        cursor='ruler_scroll',
        ghost=true,
        w=6,
        halign=rtk.Widget.CENTER
    })
    -- Acknowledge mouseenter event to ensure cursor is changed
    drag_handle.onmouseenter = function() return true end

    row.ondragstart = function(event)
        log("Drag start")
        return true
    end
    row.ondragend = function(event)
        log("DRAGEND")
        if not drag_handle.hovering then
            drag_handle:attr('ghost', true)
        end
    end
    row.ondropfocus = function(self, event, src, arg) return true end
    row.ondropmousemove = function(self, event, src, dragarg)
        if self ~= src then
            local srcidx = screen.artlist:get_child_index(src)
            local rowidx = screen.artlist:get_child_index(row)
            if srcidx > rowidx then
                screen.artlist:reorder_before(src, row)
            else
                screen.artlist:reorder_after(src, row)
            end
        end
    end



    row:add(drag_handle, {rpadding=5, valign=rtk.Widget.CENTER})
    row.checkbox = row:add(rtk.CheckBox:new({alpha=0.2}), {valign=rtk.Widget.CENTER})
    row.checkbox.ondrawpre = function(self, offx, offy, event)
        -- if not rtk.dragging and (event:is_widget_hovering(row) or self.value ~= rtk.CheckBox.STATE_UNCHECKED) then
        if event:is_widget_hovering(self) or self.value ~= rtk.CheckBox.STATE_UNCHECKED then
            self.alpha = 1.0
        else
            self.alpha = 0.2
        end
    end
    row.checkbox.ondragstart = function(self, event)
        -- TODO: checkbox drag
        event:set_handled(self)
        return false
    end

    row.checkbox.onchange = function()
        handle_row_checked(row, row.checkbox.value)
        update_artheader_checkbox()
    end

    row.onmouseenter = function()
        drag_handle:attr('ghost', false)
        return true
    end
    row.onmouseleave = function()
        if rtk.dragging ~= row then
            drag_handle:attr('ghost', true)
        end
    end

    local color = art.color or reabank.colors.default
    if not color:starts('#') then
        color = reabank.colors[color] or reabank.colors.default
    end
    local icon = articons.get(art.iconname) or articons.get('note-eighth')
    local button = rtk.Button:new({label=(art.shortname or art.name), icon=icon,
                                color=color, focusable=false,
                                tpadding=1, rpadding=1, bpadding=1, lpadding=1,
                                flags=rtk.Button.FLAT_LABEL}
    )
    -- Button is already set unfocusable, but also prevent it from reacting to mouseover.
    button.onmouseenter = function() return nil end
    row:add(button, {valign=rtk.Widget.CENTER, lpadding=10})
    row:add(rtk.Container.FLEXSPACE)
    return row
end



local function handle_artheader_checkbox(checkbox)
    if checkbox.value == rtk.CheckBox.STATE_UNCHECKED and screen.checked then
        for _, row in pairs(screen.checked) do
            row.checkbox:attr('value', checkbox.value, false)
            screen.checked = nil
            screen.num_checked = 0
        end
    elseif checkbox.value == rtk.CheckBox.STATE_CHECKED then
        for i = 1, #screen.artlist.children do
            local row = screen.artlist:get_child(i)
            row.checkbox:attr('value', checkbox.value, false)
            handle_row_checked(row, checkbox.value)
        end
    end
    log("arthead cb %s", checkbox.value)
end


function screen.init()
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
        app:push_screen('test')
    end
    screen.toolbar:add(rtk.HBox.FLEXSPACE)


    screen.widget = rtk.HBox:new()
    log("screen hbox is %s", screen.widget.id)

    -- FIXME: tpadding=5 here causes app viewport to scroll
    screen.lpane = rtk.VBox({lpadding=0, spacing=5, z=2})
    screen.widget:add(screen.lpane, {expand=1, fillw=true, tpadding=5, rpadding=-25})

    -- Bank row
    local row = ArrowRow({tpadding=8, bpadding=8, lpadding=10, spacing=0})
    row.name = rtk.Label:new({label='Your Bank Name Here', fontscale=1.3})
    row.hint = rtk.Label:new({label='Click to edit', fontscale=0.8, alpha=0.6})

    screen.lpane:add(row)
    row:add(row.name, {valign=rtk.Widget.CENTER, lpadding=10})
    row:add(rtk.Container.FLEXSPACE)
    row:add(row.hint, {rpadding=30, valign=rtk.Widget.CENTER})

    screen.bank_row = row
    row:focus()

    -- Articulation list header
    screen.artheader = rtk.HBox({spacing=10, tpadding=2, bpadding=2, bg='#272727', bborder = {'#777777'}})
    screen.artheader.checkbox = rtk.CheckBox:new()
    screen.artheader:add(screen.artheader.checkbox, {valign=rtk.Widget.CENTER, lpadding=20})
    screen.artheader.name = screen.artheader:add(rtk.Label:new({label="Articulations"}), {valign=rtk.Widget.CENTER})
    screen.artheader:add(rtk.Container.FLEXSPACE)
    screen.artheader.add_button = screen.artheader:add(app:make_button("add_circle_outline_white_18x18.png", "Add"))
    screen.artheader.cog_button = screen.artheader:add(app:make_button("settings_white_18x18.png"), {rpadding=0})
    screen.artheader.checkbox.onchange = handle_artheader_checkbox
    -- screen.artheader.cog_button.icon = screen.artheader.cog_button.icon:accent('#ffff00')

    screen.lpane:add(screen.artheader, {lpadding=0, tpadding=20, rpadding=15})

    screen.artlist = rtk.VBox({tpadding=0, spacing=1})
    screen.lpane:add(rtk.Viewport({child=screen.artlist, bpadding=10}), {expand=1, fillw=true, fillh=true})

    local c = rtk.Container({tpadding=8, lpadding=30})
    -- screen.rpane = rtk.VBox({tpadding=8, lpadding=30})
    screen.rpane = c:add(rtk.VBox())
    screen.update()

    screen.widget:add(rtk.Viewport({child=c, bg='#2e2e2e', tpadding=5, bpadding=10, lborder={'#000000'}}), {expand=1.5, fillw=true, fillh=true})
    screen.rpane:add(rtk.Heading{label="Bank Settings", fontscale=1.1})
    fill(screen.rpane, 101, 220)
end

function screen.make_bank_edit_pane()
end

function screen.update()
    screen.bank = reabank.get_bank(64, 2)
    screen.bank_row.name.label = screen.bank.name

    screen.num_checked = 0
    screen.checked = nil
    screen.artlist:clear()
    screen.num_articulations = #screen.bank.articulations
    for n, art in ipairs(screen.bank.articulations) do
        local row = make_articulation_row(art)
        screen.artlist:add(row)
    end
end

return screen
