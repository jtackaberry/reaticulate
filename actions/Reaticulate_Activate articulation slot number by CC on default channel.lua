_, _, _, _, _, _, val = reaper.get_action_context()
reaper.SetExtState("reaticulate", "command", "activate_articulation_by_slot=0," .. tostring(val), false)
