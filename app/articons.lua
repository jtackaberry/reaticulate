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

local articons = {
}

-- Articulation icons that have either been renamed or removed, with mappings to preserve
-- some sort of reasonable backward compatibility.

-- old names -> new names
local remap = {
    -- Renamed (free)
    ['tremolo-measured'] = 'tremolo-measured-sixteenth',
    ['tremolo-150'] = 'tremolo-measured-sixteenth',
    ['tremolo-180'] = 'tremolo-measured-sixteenth',
    ['tremolo-150-con-sord'] = 'tremolo-measured-sixteenth-con-sord',
    ['tremolo-180-con-sord'] = 'tremolo-measured-sixteenth-con-sord',
    ['marcato'] = 'marcato-half',
    ['riccochet'] = 'ricochet',
    ['rip-downward'] = 'plop',
    ['staccato-overblown'] = 'staccato-stopped',
    ['vibrato-rachmaninoff'] = 'vibrato-molto',
    ['legato-slurred'] = 'note-tied',
    -- Renamed (non-free)
    ['phrase-tremolo'] = 'phrase-multitongued',
    ['phrase-tremolo-cresc'] = 'phrase-multitongued-cresc',
    -- Removed
    ['esp-half'] = 'note-half',
    ['cresc-m-half'] = 'cresc-mf-half',
    ['pizz-a'] = 'pizz',
    ['pizz-b'] = 'pizz',
    ['frozen'] = 'note-whole',
    ['frozen-eighth'] = 'note-eighth',
    ['frozen-half'] = 'note-half',
    ['col-legno-loose'] = 'col-legno',
    ['no-rosin'] = 'note-whole-feathered',
}

function articons.init()
    local img = rtk.ImagePack()
    local strips = {}
    for _, density in ipairs{1, 1.5, 2} do
        for _, row in ipairs(articons.rows) do
            strips[#strips+1] = {
                w=32*density,
                h=28*density,
                names=row,
                density=density,
            }
        end
    end
    img:add{src='articulations.png', style='light', strips=strips}
    articons.img = img
end

function articons.get(name, dark, default)
    local style = dark and 'dark' or 'light'
    -- Use default if supplied name is nil
    local icon = articons.img:get(remap[name] or name or default, style)
    if not icon and default then
        -- The name was given but wasn't found. Explicitly return default.
        icon = articons.img:get(default, style)
    end
    return icon
end


function articons.get_for_bg(name, color)
    local luma = rtk.color.luma(color)
    return articons.get(name, luma > 0.6)
end

-- Table auto-generated from source-images/articulations/generate.py
articons.rows = {
    {
        'accented-half',
        'accented-quarter',
        'acciaccatura-quarter',
        'alt-circle',
        'blend',
        'bow-down',
        'bow-up',
        'col-legno',
        'col-legno-whole',
        'con-sord',
        'con-sord-blend',
        'con-sord-bow-down',
        'con-sord-bow-up',
    },
    {
        'con-sord-sul-pont',
        'con-sord-sul-pont-bow-up',
        'cresc-f-half',
        'cresc-half',
        'cresc-m-half',
        'cresc-mf-half',
        'cresc-mp-half',
        'cresc-p-half',
        'cresc-quarter',
        'crescendo',
        'cuivre',
        'dblstop-5th',
        'dblstop-5th-eighth',
    },
    {
        'decrescendo',
        'fall',
        'fanfare',
        'flautando',
        'flautando-con-sord',
        'flautando-con-sord-eighth',
        'fx',
        'ghost-eighth',
        'harmonics',
        'harmonics-natural',
        'harmonics-natural-eighth',
        'harp-pdlt2',
        'legato',
    },
    {
        'legato-blend-generic',
        'legato-bowed',
        'legato-bowed2',
        'legato-con-sord',
        'legato-fast',
        'legato-flautando',
        'legato-gliss',
        'legato-portamento',
        'legato-portamento-con-sord',
        'legato-portamento-flautando',
        'legato-runs',
        'legato-slow',
        'legato-slow-blend',
    },
    {
        'note-tied',
        'legato-sul-c',
        'legato-sul-g',
        'legato-sul-pont',
        'legato-tremolo',
        'legato-vibrato',
        'list',
        'marcato-half',
        'marcato-quarter',
        'note-acciaccatura',
        'light',
        'note-eighth',
        'note-half',
    },
    {
        'note-quarter',
        'note-sixteenth',
        'note-whole',
        'phrase2',
        'pizz',
        'pizz-bartok',
        'pizz-con-sord',
        'pizz-mix',
        'pizz-sul-pont',
        'rest-quarter',
        'ricochet',
        'rip',
        'plop',
    },
    {
        'run-major',
        'run-minor',
        'sfz',
        'spiccato',
        'spiccato-breath',
        'spiccato-brushed',
        'spiccato-brushed-con-sord',
        'spiccato-brushed-con-sord-sul-pont',
        'spiccato-feathered',
        'staccatissimo-stopped',
        'staccato',
        'staccato-breath',
        'staccato-con-sord',
    },
    {
        'staccato-dig',
        'staccato-harmonics',
        'staccato-harmonics-half',
        'staccato-stopped',
        'staccato-sfz',
        'stopped',
        'sul-c',
        'sul-g',
        'sul-pont',
        'sul-tasto',
        'tenuto-eighth',
        'tenuto-half',
        'tenuto-quarter',
    },
    {
        'tremolo',
        'tremolo-con-sord',
        'tremolo-con-sord-sul-pont',
        'tremolo-sul-pont',
        'tremolo-ghost',
        'tremolo-harmonics',
        'tremolo-fingered',
        'tremolo-measured-eighth',
        'tremolo-measured-sixteenth',
        'tremolo-measured-eighth-con-sord',
        'tremolo-measured-sixteenth-con-sord',
        'trill',
        'trill-maj2',
    },
    {
        'trill-maj3',
        'trill-min2',
        'trill-min3',
        'trill-perf4',
        'vibrato',
        'vibrato-con-sord',
        'vibrato-molto',
        'portato',
        'scoop',
        'bend-up',
        'bend-down',
        'fortepiano',
        'multitongued',
    },
    {
        'alt-gypsy',
        'alt-gypsy-eighth',
        'alt-gypsy-harmonics',
        'alt-tremolo-gypsy-harmonics',
        'alt-wave',
        'alt-wave-double',
        'alt-wave-double-stopped',
        'alt-wave-double-tr',
        'alt-x',
        'harp-pdlt',
        'phrase',
        'phrase-multitongued',
        'phrase-multitongued-cresc',
    },
    {
        'sul-tasto-super',
        'sul-tasto-super-eighth',
        'tremolo-harmonics-a',
        'tremolo-harmonics-b',
        'tremolo-slurred',
    },
}

return articons