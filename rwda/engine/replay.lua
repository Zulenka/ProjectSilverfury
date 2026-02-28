rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.replay = rwda.engine.replay or {}

local replay = rwda.engine.replay

local function readAll(path)
  local f, err = io.open(path, "r")
  if not f then
    return nil, err
  end

  local data = f:read("*a")
  f:close()
  return data
end

local function splitLines(blob)
  local out = {}
  for line in tostring(blob or ""):gmatch("([^\r\n]+)") do
    out[#out + 1] = line
  end
  return out
end

local function isPromptLine(line, pattern)
  if type(line) ~= "string" then
    return false
  end

  pattern = pattern or (rwda.config.replay and rwda.config.replay.prompt_pattern)
  if not pattern or pattern == "" then
    return false
  end

  local ok, match = pcall(string.match, line, pattern)
  return ok and match ~= nil
end

function replay.runLines(lines, opts)
  opts = opts or {}
  lines = lines or {}

  local total = 0
  local prompts = 0
  local actions = 0

  for _, line in ipairs(lines) do
    total = total + 1

    rwda.engine.parser.handleLine(line)

    if opts.auto_tick and isPromptLine(line, opts.prompt_pattern) then
      prompts = prompts + 1
      local action = rwda.tick("replay")
      if action then
        actions = actions + 1
      end
    end
  end

  return {
    lines = total,
    prompts = prompts,
    actions = actions,
    last_action = rwda.state.runtime.last_action and rwda.state.runtime.last_action.name or nil,
  }
end

function replay.runFile(path, opts)
  local blob, err = readAll(path)
  if not blob then
    return nil, err
  end

  return replay.runLines(splitLines(blob), opts)
end

function replay.assertResult(result, assertions)
  assertions = assertions or {}
  local failures = {}

  local function fail(msg)
    failures[#failures + 1] = msg
  end

  if assertions.expected_last_action and result.last_action ~= assertions.expected_last_action then
    fail(string.format("expected_last_action=%s actual=%s", tostring(assertions.expected_last_action), tostring(result.last_action)))
  end

  if assertions.min_actions and result.actions < assertions.min_actions then
    fail(string.format("min_actions=%d actual=%d", tonumber(assertions.min_actions), tonumber(result.actions)))
  end

  if assertions.max_actions and result.actions > assertions.max_actions then
    fail(string.format("max_actions=%d actual=%d", tonumber(assertions.max_actions), tonumber(result.actions)))
  end

  if assertions.min_prompts and result.prompts < assertions.min_prompts then
    fail(string.format("min_prompts=%d actual=%d", tonumber(assertions.min_prompts), tonumber(result.prompts)))
  end

  if assertions.max_prompts and result.prompts > assertions.max_prompts then
    fail(string.format("max_prompts=%d actual=%d", tonumber(assertions.max_prompts), tonumber(result.prompts)))
  end

  if assertions.min_lines and result.lines < assertions.min_lines then
    fail(string.format("min_lines=%d actual=%d", tonumber(assertions.min_lines), tonumber(result.lines)))
  end

  return #failures == 0, failures
end

function replay.runFileWithAssertions(path, opts)
  opts = opts or {}
  local result, err = replay.runFile(path, opts)
  if not result then
    return nil, err
  end

  if type(opts.assertions) == "table" then
    local ok, failures = replay.assertResult(result, opts.assertions)
    result.assertions_ok = ok
    result.assertion_failures = failures
  end

  return result
end
