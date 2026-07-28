# Runbook — Roblox Studio MCP

Connects a local Claude Code session to a running Roblox Studio instance. **Giahy action, local machine only.**

## Which server

| | |
|---|---|
| Use | **Studio's built-in MCP server** — ships inside Roblox Studio, no install, no Rust toolchain |
| Do not use | `Roblox/studio-rust-mcp-server` (the standalone plugin+binary). Roblox has moved engineering investment to the built-in server; the repo stands for reference/legacy only |
| Transport | stdio, local process. The client launches a Studio-provided binary on the same machine |

**Consequence: this cannot run in a Sushi Sea cloud session.** No port to forward, no remote endpoint — the binary and Studio must be on the same box. Cloud agents keep working file-first via Rojo; Studio verification happens on Giahy's machine.

## Prerequisites

- Latest Roblox Studio (Windows or macOS)
- Claude Code installed on the same machine
- The place open in Studio before connecting

## Setup

**1. Enable in Studio:** Assistant → **⋯** → **Manage MCP Servers** → turn on **Enable Studio as MCP server**.

**2. Connect Claude Code.** Claude Code is a supported Quick Connect client — select it in that same panel and Studio writes the client config itself. Use Quick Connect first.

Fallback, if Quick Connect fails or the config needs to live somewhere specific:

```bash
# macOS
claude mcp add Roblox_Studio --scope local -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP

# Windows
claude mcp add Roblox_Studio --scope local -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
```

JSON equivalent, for clients that take a config file:

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
    }
  }
}
```

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    }
  }
}
```

**3. Verify:** green indicator under Manage MCP Servers = client connected. `/mcp` in Claude Code lists the tools.

**Scope is `local` on purpose — do not commit this to `.mcp.json`.** The command is OS- and machine-specific, so one committed entry breaks on the other machine and fails outright in every cloud session. `.mcp.json` stays empty (same reasoning that moved mem0 to the plugin).

## Working rule — Studio MCP is an instrument, not an author

PRD §10: **the repo is the source of truth; Studio is a view.** Rojo syncs one way, `src/` → Studio. Anything the MCP writes into the place is unversioned, unreviewed, invisible to CI, and destroyed at the next sync.

| Use it for | Not for |
|---|---|
| `script_read`, `script_search`, `script_grep` — read the live place | `multi_edit` — authoring game code. Edit `.luau` in the repo, let Rojo sync |
| `search_game_tree`, `inspect_instance` — inspect the data model | `execute_luau` as a way to *ship* logic |
| `start_stop_play`, `get_console_output`, `screen_capture` — playtest evidence | `generate_mesh`, `generate_material`, `generate_procedural_model` — M18 art is Blender + Giahy |
| `character_navigation`, `user_keyboard_input`, `user_mouse_input` — drive a playtest | `insert_asset` / `search_asset` — Creator Store models are not the authored pipeline |
| `execute_luau` for throwaway probes and one-shot diagnostics | Any economy/plate-value logic reaching the client (hard invariant) |
| `http_get`, `skill` — API reference lookups | |

Two payoffs worth having:

- **`reviewer-reality` gets evidence.** Definition of Done demands proof a system is wired end-to-end. Console output and screen captures from a live playtest are exactly that — hand them to the reviewer instead of assertions.
- **Studio-only state gets captured.** Terrain, lighting, and physical placement don't round-trip through Rojo. Inspect them via MCP, then write them into `Studio Setup.md` (PRD §10, M20) rather than leaving them as tribal knowledge in one `.rbxl`.

Anything the MCP surfaces that should persist gets written back into the repo as a file, by hand. The place file is never the record.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Server absent / no tools | Restart Studio *and* Claude Code, in that order |
| Launch fails | Verify the binary path exists; check JSON syntax |
| Wrong place responds | Multiple Studio instances can share one client; the server picks by context. Force it with `list_roblox_studios` → `set_active_studio` |

## Security

Roblox's own warning: *"MCP clients can read and modify content in your open Roblox places. Make sure to only connect clients you trust."*

The MCP has write access to whatever place is open. Connect it against the Sushi Sea dev place, never a published production place.

## Sources

- [Connect to the Roblox Studio MCP server](https://create.roblox.com/docs/studio/mcp) — official, authoritative
- [Roblox/studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server) — legacy standalone server
