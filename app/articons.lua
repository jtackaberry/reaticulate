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


require 'lib.utils'
local rtk = require 'lib.rtk'

local articons = {
}

function articons.init(imagedir)
    articons.icons = {}
    local img = rtk.Image:new(Path.join(imagedir, "articulations.png"))
    for n = 1, img.width / 32 do
        local name = articons.names[n]
        articons.icons[name] = rtk.Image:new(img, 32 * (n - 1), 0, 32, -1)
    end
end

function articons.get(name)
    return articons.icons[name]
end

articons.names = {
    "accented-half",
    "accented-quarter",
    "acciaccatura-quarter",
    "alt-circle",
    "alt-gypsy",
    "alt-gypsy-eighth",
    "alt-gypsy-harmonics",
    "alt-tremolo-gypsy-harmonics",
    "alt-wave",
    "alt-wave-double",
    "alt-wave-double-stopped",
    "alt-wave-double-tr",
    "alt-x",
    "blend",
    "bow-down",
    "bow-up",
    "col-legno",
    "col-legno-loose",
    "col-legno-whole",
    "con-sord",
    "con-sord-blend",
    "con-sord-bow-down",
    "con-sord-bow-up",
    "con-sord-sul-pont",
    "con-sord-sul-pont-bow-up",
    "cresc-f-half",
    "cresc-half",
    "cresc-m-half",
    "cresc-mf-half",
    "cresc-mp-half",
    "cresc-p-half",
    "cresc-quarter",
    "crescendo",
    "cuivre",
    "dblstop-5th",
    "dblstop-5th-eighth",
    "decrescendo",
    "esp-half",
    "fall",
    "fanfare",
    "flautando",
    "flautando-con-sord",
    "flautando-con-sord-eighth",
    "frozen",
    "frozen-eighth",
    "fx",
    "ghost-eighth",
    "harmonics",
    "harmonics-natural",
    "harmonics-natural-eighth",
    "harp-pdlt",
    "harp-pdlt2",
    "legato",
    "legato-blend-generic",
    "legato-bowed",
    "legato-bowed2",
    "legato-con-sord",
    "legato-fast",
    "legato-flautando",
    "legato-gliss",
    "legato-portamento",
    "legato-portamento-con-sord",
    "legato-portamento-flautando",
    "legato-runs",
    "legato-slow",
    "legato-slow-blend",
    "legato-slurred",
    "legato-sul-c",
    "legato-sul-g",
    "legato-sul-pont",
    "legato-tremolo",
    "legato-vibrato",
    "list",
    "marcato",
    "marcato-half",
    "marcato-quarter",
    "multitongued",
    "no-rosin",
    "note-eighth",
    "note-half",
    "note-quarter",
    "note-sixteenth",
    "note-whole",
    "phrase",
    "phrase-tremolo",
    "phrase-tremolo-cresc",
    "pizz",
    "pizz-b",
    "pizz-bartok",
    "pizz-c",
    "pizz-con-sord",
    "pizz-mix",
    "pizz-sul-pont",
    "rest-quarter",
    "riccochet",
    "rip",
    "rip-downward",
    "run-major",
    "run-minor",
    "sfz",
    "spiccato",
    "spiccato-breath",
    "spiccato-brushed",
    "spiccato-brushed-con-sord",
    "spiccato-brushed-con-sord-sul-pont",
    "spiccato-feathered",
    "staccatissimo-stopped",
    "staccato",
    "staccato-breath",
    "staccato-con-sord",
    "staccato-dig",
    "staccato-harmonics",
    "staccato-harmonics-half",
    "staccato-overblown",
    "staccato-sfz",
    "stopped",
    "sul-c",
    "sul-g",
    "sul-pont",
    "sul-tasto",
    "sul-tasto-super",
    "sul-tasto-super-eighth",
    "tenuto-eighth",
    "tenuto-half",
    "tenuto-quarter",
    "tremolo",
    "tremolo-150",
    "tremolo-150-con-sord",
    "tremolo-180",
    "tremolo-con-sord",
    "tremolo-con-sord-sul-pont",
    "tremolo-ghost",
    "tremolo-harmonics",
    "tremolo-harmonics-a",
    "tremolo-harmonics-b",
    "tremolo-measured",
    "tremolo-slurred",
    "tremolo-sul-pont",
    "trill",
    "trill-maj2",
    "trill-maj3",
    "trill-min2",
    "trill-min3",
    "trill-perf4",
    "vibrato",
    "vibrato-con-sord",
    "vibrato-molto",
    "vibrato-rachmaninoff"
}

return articons
