-- Load Reaticulate if it's not already running.
local now = tostring(os.clock())

reaper.SetExtState("reaticulate", "command", "ping=" .. now, false)

local attempts = 2
function check()
    val = reaper.GetExtState("reaticulate", "pong")
    if val == now then
        -- Reaticulate is running.
        return
    end
    attempts = attempts - 1
    if attempts > 0 then
        -- Waiting for pong
        reaper.defer(check)
    else
        -- Lookup cmd id saved from previous invocation of Reaticulate_Main.
        cmd = reaper.GetExtState("reaticulate", "main_command_id")
        if not cmd or not reaper.ReverseNamedCommandLookup(tonumber(cmd)) then
            -- This is the command id for the default script location
            cmd = reaper.NamedCommandLookup('_RSbe259504561f6a52557d2d1c64e52ef13527bf17')
        end
        reaper.Main_OnCommandEx(tonumber(cmd), 0, 0)
    end
end

reaper.defer(check)