_, _, _, _, _, _, val = reaper.get_action_context()
reaper.SetExtState("reaticulate", "command", "set_default_channel=" .. tostring(val), false)
