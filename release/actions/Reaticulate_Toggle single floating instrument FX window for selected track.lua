_, _, section_id, cmd_id, _, _, val = reaper.get_action_context()
cmd = string.format('set_toggle_option=single_floating_instrument_fx_window,-1,%s,%s', section_id, cmd_id)
reaper.SetExtState("reaticulate", "command", cmd, false)