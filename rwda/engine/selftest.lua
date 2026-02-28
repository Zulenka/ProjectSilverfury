rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.selftest = rwda.engine.selftest or {}

local selftest = rwda.engine.selftest

local function choose()
  if not rwda.engine or not rwda.engine.planner or not rwda.engine.planner.choose then
    return nil
  end
  return rwda.engine.planner.choose(rwda.state)
end

local function resetBaseline()
  rwda.state.reset()
  rwda.state.setEnabled(true)
  rwda.state.setStopped(false)
  rwda.state.setTarget("Bainz")
  rwda.state.setTargetAvailable(true, "selftest", "seen")
  rwda.state.me.bal = true
  rwda.state.me.eq = true
  rwda.state.me.balances.balance = true
  rwda.state.me.balances.equilibrium = true
  rwda.state.flags.mode = "auto"
  rwda.state.flags.goal = "limbprep"
end

local function resultRow(name, ok, detail)
  return {
    name = name,
    ok = not not ok,
    detail = detail or "",
  }
end

local function expectAction(testName, expected)
  local action = choose()
  if not action then
    return resultRow(testName, false, "no_action")
  end
  if action.name ~= expected then
    return resultRow(testName, false, string.format("expected=%s got=%s", tostring(expected), tostring(action.name)))
  end
  return resultRow(testName, true, expected)
end

function selftest.run()
  local rows = {}
  local passed = 0

  resetBaseline()
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  rows[#rows + 1] = expectAction("human strips shield first", "razeslash")

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = false
  rows[#rows + 1] = expectAction("dragon summons breath first", "summon")

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = false
  rows[#rows + 1] = expectAction("dragon forces prone before devour", "gust")

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.flags.goal = "dragon_devour"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = true
  rwda.state.updateTargetLimb("torso", { broken = true, damage_pct = 100, confidence = 1.0 })
  rwda.state.updateTargetLimb("left_leg", { broken = true, damage_pct = 100, confidence = 1.0 })
  rwda.state.updateTargetLimb("right_leg", { broken = true, damage_pct = 100, confidence = 1.0 })
  rows[#rows + 1] = expectAction("dragon devours in fast window", "devour")

  resetBaseline()
  rwda.state.setTargetAvailable(false, "selftest", "gmcp_not_in_room")
  local unavailableAction = choose()
  local reasonCode = rwda.state.runtime.last_reason and rwda.state.runtime.last_reason.code or "none"
  if unavailableAction == nil and reasonCode == "target_unavailable" then
    rows[#rows + 1] = resultRow("holds offense when target unavailable", true, reasonCode)
  else
    rows[#rows + 1] = resultRow("holds offense when target unavailable", false, "expected target_unavailable")
  end

  for _, row in ipairs(rows) do
    if row.ok then
      passed = passed + 1
    end
  end

  return {
    total = #rows,
    passed = passed,
    failed = #rows - passed,
    rows = rows,
  }
end
