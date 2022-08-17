_, _, _, _, _, res, val = reaper.get_action_context()

--Simple check if the message is 14-bit or 7-bit
if res == 16383 then val = 16384-val end

reaper.defer(function()
    reaper.SetExtState("reaticulate", "command", "activate_articulation=0," .. tostring(val), false)
end)
