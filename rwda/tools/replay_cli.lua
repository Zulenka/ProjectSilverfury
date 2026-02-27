-- Usage:
-- lua tools\replay_cli.lua <path-to-log> [target]

local scriptFile = debug.getinfo(1, "S").source:sub(2)
local root = scriptFile:match("^(.*)[/\\]tools[/\\][^/\\]+$") or "."

rwda = { _autoboot_disabled = true }
dofile(root .. "\\init.lua")
rwda.bootstrap({ load_files = true, base_path = root })
rwda.enable()

local logPath = arg and arg[1]
local target = arg and arg[2]

if not logPath then
  io.stderr:write("Missing log path.\n")
  os.exit(1)
end

if target and target ~= "" then
  rwda.setTarget(target)
else
  rwda.setTarget("target")
end

local result, err = rwda.engine.replay.runFile(logPath, {
  auto_tick = true,
  prompt_pattern = rwda.config.replay.prompt_pattern,
})

if not result then
  io.stderr:write("Replay failed: " .. tostring(err) .. "\n")
  os.exit(1)
end

io.write(string.format("Replay complete: lines=%d prompts=%d actions=%d last=%s\n", result.lines, result.prompts, result.actions, tostring(result.last_action)))
