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

local BaseApp = require 'lib.baseapp'
local rtk = require 'lib.rtk'
local reabank = require 'reabank'
local articons = require 'articons'
require 'lib.utils'

App = class('App', BaseApp)

function App:initialize(basedir)
    BaseApp.initialize(self, 'reaticulate.cfgui', basedir)
    self:set_debug(1)
    articons.init(Path.imagedir)
    reabank.init()
    -- log("")
    log("\n\n\n\n\n\n-------------------------------------------------\napp init")
    buf = reaper.CF_GetClipboard("")
    log("CLIP: %s", buf)

    -- self:add_screen('test', 'cfgui.screens.test')
    self:add_screen('bankedit', 'cfgui.screens.bankedit')
    self:replace_screen('bankedit')

    function foo()
        gfx.setcursor(1, 'ruler_scroll')
        gfx.update()
        reaper.defer(foo)
    end
    -- rtk.init("Reaticulate", self.config.w, self.config.h, self.config.dockstate, self.config.x, self.config.y)
    -- reaper.defer(foo)
    self:run()
end

function App:build_frame()
    BaseApp.build_frame(self)
    self.toolbar.bg = '#4c4c4c'
    self.toolbar.bpadding = 1
    self.toolbar.bborder = {'#101010', 1, -1}
    self.statusbar:hide()
    return self.frame
end

function App:handle_onupdate()
    BaseApp.handle_onupdate(self)
end

function BaseApp:handle_onkeypresspost(event)
    log("keypress: keycode=%d  char=%s handled=%s", event.keycode, event.char, event.handled)
    if event.char == 'w' and event.ctrl and not event.alt then
        rtk.quit()
    end
end

return App