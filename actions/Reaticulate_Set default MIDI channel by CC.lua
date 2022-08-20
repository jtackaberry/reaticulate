_, _, _, _, _, res, val = reaper.get_action_context()

--Simple check if the message is 14-bit or 7-bit
if res == 16383 then val = 16384-val end

reaper.SetExtState("reaticulate", "command", "set_default_channel=" .. tostring(val), false)
