#!/usr/bin/env python3
"""
Build Silverfury.mpackage — a self-contained Mudlet package.
All Lua modules are inlined as Script elements with CDATA blocks, in dependency order.
Run from the ProjectSilverfury/ directory.
"""

import zipfile
import os

BASE    = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Silverfury")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Load order (matches init.lua loadAll) ─────────────────────────────────────
# Each path is relative to Silverfury/.

LOAD_ORDER = [
    "util/log.lua",
    "util/time.lua",
    "util/table.lua",
    "util/files.lua",
    "config.lua",
    "logging/formats.lua",
    "logging/logger.lua",
    "state/me.lua",
    "state/target.lua",
    "state/room.lua",
    "engine/queue.lua",
    "engine/safety.lua",
    "engine/planner.lua",
    "data/afflictions.lua",
    "offense/venoms.lua",
    "offense/attacks.lua",
    "runelore/runes.lua",
    "runelore/core.lua",
    "dragon/core.lua",
    "dragon/commands.lua",
    "dragon/devour.lua",
    "dragon/matchups.lua",
    "scenarios/base.lua",
    "scenarios/venomlock.lua",
    "scenarios/runelore_kill.lua",
    "scenarios/dragon_devour.lua",
    "retaliate.lua",
    "parser/incoming.lua",
    "parser/outgoing.lua",
    "bridge/gmcp.lua",
    "bridge/legacy.lua",
    "bridge/ak.lua",
    "ui/components.lua",
    "ui/window.lua",
    "ui/bindings.lua",
]

# ── Bootstrap code ────────────────────────────────────────────────────────────
# Runs after all module scripts are loaded by Mudlet's XML executor.

BOOTSTRAP_CODE = r"""
-- Silverfury Bootstrap — runs after all module scripts are loaded.

Silverfury         = Silverfury or {}
Silverfury.VERSION = "1.0.0"

-- State flags (must exist before any module function is called at runtime).
Silverfury.state       = Silverfury.state or {}
Silverfury.state.flags = Silverfury.state.flags or {
  armed          = false,
  auto_tick      = true,
  attack_enabled = false,
}

-- Shutdown (called on package uninstall or manual sf shutdown).
function Silverfury.shutdown()
  Silverfury.safety.disarm()
  Silverfury.safety.shutdown()
  Silverfury.retaliate.shutdown()
  Silverfury.parser.incoming.shutdown()
  Silverfury.parser.outgoing.shutdown()
  Silverfury.bridge.gmcp.shutdown()
  Silverfury.bridge.legacy.shutdown()
  Silverfury.bridge.ak.shutdown()
  Silverfury.runelore.core.shutdown()
  Silverfury.dragon.core.shutdown()
  Silverfury.ui.window.shutdown()
  Silverfury.logging.logger.shutdown()
  Silverfury.log.info("Silverfury shut down.")
end

-- Core tick — the single decision boundary fired on every prompt.
Silverfury.core = Silverfury.core or {}
function Silverfury.core.tick(source)
  Silverfury.safety.heartbeat()
  Silverfury.retaliate.update()
  local action = Silverfury.engine.planner.choose()
  if action and action.type ~= "idle" then
    Silverfury.engine.planner.execute(action)
  end
  Silverfury.logging.logger.write("PROMPT_SNAPSHOT", { source = source })
end

-- Initialise config FIRST; overlay persisted values if the file exists.
Silverfury.config.init()
if Silverfury.config.get("persistence.auto_load") and Silverfury.config.exists() then
  Silverfury.config.load()
end

-- Bring all subsystems online.
Silverfury.logging.logger.init()
Silverfury.runelore.core.init()
Silverfury.runelore.core.registerHandlers()
Silverfury.dragon.core.registerHandlers()
Silverfury.parser.incoming.registerHandlers()
Silverfury.parser.outgoing.registerHandlers()
Silverfury.bridge.gmcp.registerHandlers()
Silverfury.bridge.legacy.registerHandlers()
Silverfury.bridge.ak.registerHandlers()
Silverfury.safety.registerHandlers()
Silverfury.retaliate.registerHandlers()
Silverfury.ui.window.registerHandlers()

if Silverfury.config.get("ui.open_on_start") then
  Silverfury.ui.window.open()
end

Silverfury.log.info("Silverfury v1.0.0 ready. Type 'sf help' to get started.")
""".strip()

# ── Helpers ───────────────────────────────────────────────────────────────────

def read_lua(rel_path):
    full = os.path.join(BASE, rel_path.replace("/", os.sep))
    with open(full, "r", encoding="utf-8") as f:
        return f.read()


def script_display_name(rel_path):
    return "SF: " + rel_path.replace("\\", "/")[:-4]  # strip .lua


def xml_attr_escape(s):
    return s.replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;")


def cdata_safe(code):
    # "]]>" inside CDATA would end the block prematurely — split it.
    return code.replace("]]>", "]] >")


# ── XML builder ───────────────────────────────────────────────────────────────

def build_xml():
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE MudletPackage>',
        '<MudletPackage version="1.001">',
        '  <ScriptPackage>',
        '    <ScriptGroup isActive="yes" isFolder="yes">',
        '      <name>Silverfury</name>',
        '      <packageName>Silverfury</packageName>',
        '      <script></script>',
        '      <eventHandlerList/>',
    ]

    def add_script(display_name, code):
        safe   = cdata_safe(code)
        esc_nm = xml_attr_escape(display_name)
        lines.append('      <Script isActive="yes" isFolder="no">')
        lines.append(f'        <name>{esc_nm}</name>')
        lines.append('        <packageName>Silverfury</packageName>')
        lines.append(f'        <script><![CDATA[{safe}]]></script>')
        lines.append('        <eventHandlerList/>')
        lines.append('      </Script>')

    for rel in LOAD_ORDER:
        add_script(script_display_name(rel), read_lua(rel))

    add_script("SF: Bootstrap", BOOTSTRAP_CODE)

    lines += [
        '    </ScriptGroup>',
        '  </ScriptPackage>',
        '  <AliasPackage>',
        '    <AliasGroup isActive="yes" isFolder="yes">',
        '      <name>Silverfury</name>',
        '      <packageName>Silverfury</packageName>',
        '      <Alias isActive="yes" isFolder="no">',
        '        <name>sf</name>',
        '        <packageName>Silverfury</packageName>',
        '        <script><![CDATA[Silverfury.ui.bindings.handle(matches[2])]]></script>',
        '        <command></command>',
        '        <regex>^sf(.*)</regex>',
        '      </Alias>',
        '    </AliasGroup>',
        '  </AliasPackage>',
        '</MudletPackage>',
    ]

    return "\n".join(lines)


def config_lua():
    return b'mpackage = [[Silverfury]]\ncreated = "2026-03-05"\n'


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    print("Reading Lua modules...")
    xml_str  = build_xml()
    xml_data = xml_str.encode("utf-8")

    out_path = os.path.join(OUT_DIR, "Silverfury.mpackage")
    print(f"Writing {out_path} ...")

    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("Silverfury.xml", xml_data)
        zf.writestr("config.lua",     config_lua())

    size = os.path.getsize(out_path)
    print(f"Done. Package size: {size:,} bytes ({size // 1024} KB)")
    print()
    print("Verify:")
    with zipfile.ZipFile(out_path) as zf:
        for name in zf.namelist():
            info = zf.getinfo(name)
            print(f"  {name}  ({info.file_size:,} bytes)")
        xml_check = zf.read("Silverfury.xml").decode("utf-8")
        cdata_count  = xml_check.count("<![CDATA[")
        script_count = xml_check.count('<Script isActive')
        print(f"  Script elements: {script_count}")
        print(f"  CDATA blocks: {cdata_count}")
    print()
    print("Install in Mudlet: Package Manager -> Install -> Silverfury.mpackage")


if __name__ == "__main__":
    main()
