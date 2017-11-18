_, _, _, _, _, _, val = reaper.get_action_context()
reaper.SetProjExtState(0, "reaticulate", "command", "set_default_channel=" .. tostring(val))
