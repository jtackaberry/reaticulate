-- Load Reaticulate if it's not already running.
local now = tostring(os.clock())

reaper.SetExtState("reaticulate", "command", "ping=" .. now, false)

local attempts = 2
function check()
    val = reaper.GetExtState("reaticulate", "pong")
    if val >= now then
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
        if cmd == '' or not cmd or not reaper.ReverseNamedCommandLookup(tonumber(cmd)) then
            -- cmd id not stored, so try to discover it by registering the main script
            local self = debug.getinfo(1, 'S').source:sub(2)
            local basedir = self:match("(.*)[/\\][^/\\]+")
            local script = string.format("%s/Reaticulate_Main.lua", basedir)
            cmd = reaper.AddRemoveReaScript(true, 0, script, true)
            if cmd == 0 then
                -- We're out of self-discovery options.  This is the command id for the default
                -- script location.  Hope for the best.
                cmd = reaper.NamedCommandLookup('_RSbe259504561f6a52557d2d1c64e52ef13527bf17')
            end
        end
        if cmd == '' or not cmd or cmd == 0 then
            reaper.ShowMessageBox(
                "Couldn't open Reaticulate.  This is due to a REAPER limitation.\n\n" ..
                "Workaround: open REAPER's actions list and manually run Reaticulate_Main.\n\n" ..
                "You will only need to do this once.",
                "Reaticulate: Error", 0
            )
        else
            reaper.Main_OnCommandEx(tonumber(cmd), 0, 0)
        end
    end
end

reaper.defer(check)