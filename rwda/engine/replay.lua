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

local function loadSuite(path)
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, err
  end

  local ok, suite = pcall(chunk)
  if not ok then
    return nil, suite
  end

  if type(suite) ~= "table" then
    return nil, "suite_not_table"
  end

  if type(suite.cases) == "table" then
    return suite.cases
  end

  return suite
end

function replay.runSuite(path, opts)
  opts = opts or {}
  local cases, err = loadSuite(path)
  if not cases then
    return nil, err
  end

  local summary = {
    total = 0,
    passed = 0,
    failed = 0,
    cases = {},
  }

  for i, case in ipairs(cases) do
    summary.total = summary.total + 1

    if rwda.state and rwda.state.reset then
      rwda.state.reset()
      if rwda.applyConfigToState then
        rwda.applyConfigToState()
      end
      if rwda.enable then
        rwda.enable()
      end
    end

    if case.target and case.target ~= "" and rwda.setTarget then
      rwda.setTarget(case.target)
    end

    if type(case.pre_state) == "table" then
      local ps = case.pre_state
      if ps.goal and rwda.state and rwda.state.setGoal then
        rwda.state.setGoal(ps.goal)
      end
      if ps.mode and rwda.state and rwda.state.setMode then
        rwda.state.setMode(ps.mode)
      end
      if ps.retaliate ~= nil then
        rwda.config.retaliation = rwda.config.retaliation or {}
        rwda.config.retaliation.enabled = ps.retaliate
        if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.setEnabled then
          rwda.engine.retaliation.setEnabled(ps.retaliate)
        end
      end
      if ps.execute ~= nil then
        rwda.config.finisher = rwda.config.finisher or {}
        rwda.config.finisher.enabled = ps.execute
        if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.setEnabled then
          rwda.engine.finisher.setEnabled(ps.execute)
        end
      end
    end

    local runOpts = {
      auto_tick = case.auto_tick,
      prompt_pattern = case.prompt_pattern,
      assertions = case.assertions,
    }

    if runOpts.auto_tick == nil then
      runOpts.auto_tick = rwda.config.replay and rwda.config.replay.auto_tick
    end

    if not runOpts.prompt_pattern then
      runOpts.prompt_pattern = rwda.config.replay and rwda.config.replay.prompt_pattern
    end

    -- Resolve relative log paths against rwda.base_path so suite files can use
    -- short paths like "tools/foo.log" regardless of Mudlet's working directory.
    local logPath = case.log or ""
    if logPath ~= "" and not logPath:match("^[A-Za-z]:[/\\]") and not logPath:match("^/") then
      local base = rwda and rwda.base_path or ""
      if base ~= "" then
        local sep = base:match("[/\\]") or "\\"
        logPath = base:gsub("[/\\]$", "") .. sep .. logPath
      end
    end

    local result, runErr = replay.runFileWithAssertions(logPath, runOpts)
    local passed = false
    local detail = ""
    if not result then
      detail = tostring(runErr)
    else
      if type(case.assertions) == "table" then
        passed = not not result.assertions_ok
        detail = passed and "assertions_ok" or table.concat(result.assertion_failures or {}, "; ")
      else
        passed = true
        detail = "no_assertions"
      end
    end

    summary.cases[#summary.cases + 1] = {
      name = case.name or ("case_" .. tostring(i)),
      passed = passed,
      detail = detail,
      result = result,
    }

    if passed then
      summary.passed = summary.passed + 1
    else
      summary.failed = summary.failed + 1
    end
  end

  return summary
end
