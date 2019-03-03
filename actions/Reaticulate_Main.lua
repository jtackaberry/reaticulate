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


-- This file bootstraps either source or binary (precompiled) installations of
-- Reaticulate, depending on what's present.
--
-- More information, including source code, can be found at http://reaticulate.com/

-- Find base directory of application
local sep = package.config:sub(1, 1)
local script = debug.getinfo(1, 'S').source:sub(2)
local pattern = "(.*" .. sep .. ")[^" .. sep .. "]+" .. sep
local basedir = script:match(pattern)


-- Remember command id for this script (because Reaper's API actually provides no means
-- of *reliably* resolving it).
_, _, _, cmd, _, _, _ = reaper.get_action_context()
reaper.SetExtState("reaticulate", "main_command_id", tostring(cmd), true)

-- Source code will be in this subdirectory.
local appdir = basedir .. sep .. 'app' .. sep
if reaper.file_exists(appdir .. 'main.lua') then
    -- Source based installation
    package.path = package.path .. ";" .. appdir .. '?.lua'
    local main = require 'main'
    main(basedir)
else
    -- Binary installation.  NB: this isn't actually used currently.  At least at this stage
    -- there are no detectable performance benefits to precompiling.  As a result, Reaticulate
    -- is distributed in source form.
    local os = reaper.GetOS()
    local arch = 'x32'
    if os == 'Win32' or os == 'OSX32' then
        arch = 'x32'
    end
    dofile(basedir .. 'reaticulate-' .. arch .. '.luac')
    main(basedir)
end
