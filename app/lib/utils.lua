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


-- Miscellaneous utility functions

Path = {
    sep = package.config:sub(1, 1),
    resourcedir = reaper.GetResourcePath()
}

local notes = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'}

function Path.init(basedir)
    Path.basedir = basedir
end

Path.join = function(first, ...)
    local args = {...}
    local joined = first
    local prev = first
    for _, part in ipairs(args) do
        if prev:sub(-1) ~= Path.sep then
            joined = joined .. Path.sep .. part
        else
            joined = joined .. part
        end
        prev = part
    end
    return joined
end


function string.starts(s, start)
   return s:sub(1, string.len(start)) == start
end

function string.split(s, delim)
    local words = {}
    for word in s:gmatch('[^' .. (delim or '%s') .. ']+') do
        words[#words+1] = word
    end
    return words
end

function string.strip(s)
    return s:match('^%s*(.-)%s*$')
 end

function read_file(fname)
    local f, err = io.open(fname)
    if f then
        local contents = f:read("*all")
        f:close()
        return contents, nil
    else
        return nil, err
    end
end

function write_file(fname, contents)
    local f, err = io.open(fname, "w")
    if f then
        f:write(contents)
        f:close()
    else
        return err
    end
end

function file_size(fname)
    local f, err = io.open(fname)
    if f then
        local size = f:seek("end")
        f:close()
        return size, nil
    else
        return nil, err
    end
end

function table.val_to_str(v)
    if "string" == type(v) then
        v = string.gsub(v, "\n", "\\n")
        if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v, '"', '\\"') .. '"'
    else
        return "table" == type(v) and table.tostring(v) or tostring(v)
    end
end

function table.key_to_str ( k )
    if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. table.val_to_str(k) .. "]"
    end
end

function table.tostring(tbl)
    local result, done = {}, {}
    for k, v in ipairs(tbl ) do
        table.insert(result, table.val_to_str(v))
        done[k] = true
    end
    for k, v in pairs(tbl) do
        if not done[k] then
            table.insert(result, table.key_to_str(k) .. "=" .. table.val_to_str(v))
        end
    end
    return "{" .. table.concat( result, "," ) .. "}"
end


--- XXX: not safe for untrusted data!
function table.fromstring(str)
    return load('return ' .. str)()
end

function note_to_name(note)
    return string.format('%s%d', notes[(note % 12) + 1], math.floor(note / 12) - 2)
end
