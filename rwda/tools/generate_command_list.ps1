param(
  [string]$CommandsFile = "rwda/ui/commands.lua",
  [string]$OutputFile = "RWDA Command List.md"
)

if (-not (Test-Path $CommandsFile)) {
  throw "Commands file not found: $CommandsFile"
}

$raw = Get-Content $CommandsFile -Raw

$helpMatch = [regex]::Match($raw, 'tell\("Commands:\s*([^"]+)"\)')
if (-not $helpMatch.Success) {
  throw "Could not find commands help string in $CommandsFile"
}

function Split-CommandsPreservingAngles {
  param([string]$Text)
  $items = @()
  $buf = ""
  $depth = 0

  foreach ($ch in $Text.ToCharArray()) {
    if ($ch -eq '<') {
      $depth++
      $buf += $ch
      continue
    }
    if ($ch -eq '>') {
      if ($depth -gt 0) { $depth-- }
      $buf += $ch
      continue
    }
    if ($ch -eq '|' -and $depth -eq 0) {
      $trimmed = $buf.Trim()
      if ($trimmed -ne "") { $items += $trimmed }
      $buf = ""
      continue
    }
    $buf += $ch
  }

  $tail = $buf.Trim()
  if ($tail -ne "") { $items += $tail }
  return $items
}

$commandList = Split-CommandsPreservingAngles $helpMatch.Groups[1].Value | ForEach-Object {
  ($_ -replace '^\s*rwda\s+', '').Trim()
} | Where-Object { $_ -ne "" }

if ($raw -match 'if sub == "queue" and \(words\[2\] or ""\):lower\(\) == "clear"') {
  if (-not ($commandList -contains "queue clear")) {
    $commandList += "queue clear"
  }
}

$descriptions = @{
  "on" = "Enable RWDA offense engine."
  "off" = "Disable RWDA offense engine."
  "stop" = "Emergency stop; halts planner/executor and can clear queue."
  "resume" = "Resume execution after stop."
  "reload" = "Reload RWDA modules from disk."
  "status" = "Print current runtime state snapshot."
  "doctor" = "Run Legacy/backend/handler diagnostics."
  "explain" = "Show reason/code for last planned action."
  "tick" = "Run one planning/execution cycle immediately."
  "selftest" = "Run built-in offline planner regression tests."
  "target <name>" = "Set combat target name."
  "mode <auto|human|dragon>" = "Force or auto-select combat mode."
  "goal <pressure|limbprep|impale_kill|dragon_devour>" = "Set planner goal."
  "profile <duel|group>" = "Apply profile presets for mode/goal."
  "debug <on|off>" = "Toggle verbose trace logging."
  "set breath <type>" = "Set dragon summon breath type."
  "set venoms <main> <off>" = "Set primary DSL venom pair."
  "set autostart <on|off>" = "Toggle auto-enable with LegacyLoaded."
  "set prompttick <on|off>" = "Toggle automatic tick on prompt."
  "set capture <on|off>" = "Toggle unmatched-line capture logging."
  "set captureprompts <on|off>" = "Include prompt lines in unmatched capture log."
  "set capturepath <path>" = "Set unmatched capture log file path."
  "show config" = "Print current live RWDA config highlights."
  "save config" = "Persist current RWDA config to disk."
  "load config" = "Load persisted RWDA config from disk."
  "line <text>" = "Feed one raw combat line into parser."
  "replay <file>" = "Replay a combat log file through parser/planner."
  "replayassert <file> <expected_last_action> [min_actions]" = "Replay with assertions and fail details."
  "clear target" = "Clear target state and availability locks."
  "reset" = "Reset RWDA state to defaults."
  "queue clear" = "Clear all queued server commands."
}

$notes = @{
  "tick" = "Equivalent alias: rwda attack."
  "queue clear" = "Clears Achaea server queue (clearqueue all)."
}

$rows = @()
foreach ($cmd in $commandList) {
  $description = $descriptions[$cmd]
  if (-not $description) {
    $description = "Description pending (new command detected)."
  }

  $note = $notes[$cmd]
  if (-not $note) {
    $note = "-"
  }

  $rows += "| rwda $cmd | $description | $note |"
}

$extras = @()
if ($raw -match 'if sub == "tick" or sub == "attack"') {
  $extras += "| rwda attack | Alias for rwda tick. | Hidden alias (not shown in help string). |"
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"

$header = @(
  "# RWDA Command List",
  "",
  "Auto-generated from $CommandsFile.",
  "",
  "Last generated: $timestamp",
  "",
  "## Runtime Commands",
  "",
  "| Command | What It Does | Notes |",
  "|---|---|---|"
)

$footer = @(
  "",
  "## Regenerate",
  "",
  "Run:",
  "",
  "~~~powershell",
  "pwsh -File rwda/tools/generate_command_list.ps1",
  "~~~",
  "",
  "## Policy",
  "",
  "- Supported alias prefix is rwda only.",
  '- If a new command appears with "Description pending", add its description in rwda/tools/generate_command_list.ps1.'
)

$content = @()
$content += $header
$content += $rows
if ($extras.Count -gt 0) {
  $content += ""
  $content += "## Extra Aliases"
  $content += ""
  $content += "| Command | What It Does | Notes |"
  $content += "|---|---|---|"
  $content += $extras
}
$content += $footer

$content -join "`r`n" | Set-Content -Path $OutputFile -Encoding UTF8
Write-Host "Generated $OutputFile"
