-- Copyright 2019 Jason Tackaberry
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

local log = {
    levels = {
        [50] = 'CRITICAL',
        [40] = 'ERROR',
        [30] = 'WARNING',
        [20] = 'INFO',
        [10] = 'DEBUG',
        [9] = 'DEBUG2'
    },
    FATAL = 50,
    CRITICAL = 50,
    ERROR = 40,
    WARN = 30,
    INFO = 20,
    DEBUG = 10,
    DEBUG2 = 9,

    level = 40,

    timers = {},
    queue = {},
    t0 = nil,
    tl = nil,
}

local function flush_queue()
    reaper.ShowConsoleMsg(table.concat(log.queue))
    log.queue = {}
end


local function enqueue(msg)
    -- Handle the actual display of log messages asynchronously so as not to include any
    -- logging overhead in timing measurements and also lets us coalesce multiple log messages
    -- into a single ShowConsoleMsg() call which significantly improves performance.
    local qlen = #log.queue
    if qlen == 0 then
        reaper.defer(flush_queue)
    end
    log.queue[qlen + 1] = msg
end


function log.log(level, tail, fmt, ...)
    if level < log.level then
        return
    end
    local r, err = pcall(string.format, fmt, ...)
    if not r then
        log.exception("exception formatting log string '%s': %s", fmt, err)
        return
    end

    local now = os.clock()
    local msecs = string.sub(now - math.floor(now), 3, 5)
    local label = log.level_name(level)
    local prefix = string.format('%s.%s [%s]  ', os.date('%H:%M:%S'), msecs, label)
    if #log.timers > 0 then
        local timer = log.timers[#log.timers]
        local total = (now - timer[1]) * 1000
        local last = (now - timer[2]) * 1000
        prefix = prefix .. string.format('(%.0f / %.0f ms)  ', last, total)
        timer[2] = now
    end

    local msg = prefix .. err .. '\n'
    if tail then
        msg = msg .. tail .. '\n'
    end
    enqueue(msg)
end

function log.level_name(level)
    return log.levels[level or log.level] or 'UNKNOWN'
end

function log.clear()
    if log.level <= log.INFO then
        reaper.ShowConsoleMsg("")
        log.queue = {}
    end
end

function log.exception(fmt, ...)
    log.log(log.ERROR, debug.traceback(), fmt, ...)
end

function log.trace(level)
    if log.level <= (level or log.DEBUG) then
        enqueue(debug.traceback() .. '\n')
    end
end

function log.time_start()
    if log.level <= log.INFO then
        enqueue("\n")
    end
    local now = os.clock()
    table.insert(log.timers, {now, now})
    log.t0 = now
    log.tl = now
end

function log.time_end()
    if log.level <= log.INFO then
        enqueue("\n")
    end
    table.remove(log.timers)
    log.t0 = nil
    log.tl = nil
end

function log.critical(fmt, ...) log.log(log.CRITICAL, nil, fmt, ...) end
function log.error(fmt, ...)    log.log(log.ERROR, nil, fmt, ...) end
function log.warn(fmt, ...)     log.log(log.WARN, nil, fmt, ...) end
function log.info(fmt, ...)     log.log(log.INFO, nil, fmt, ...) end
function log.debug(fmt, ...)    log.log(log.DEBUG, nil, fmt, ...) end
function log.debug2(fmt, ...)   log.log(log.DEBUG2, nil, fmt, ...) end
log.fatal = log.critical


return log
