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

Fallback, if Quick Connect fails. Use `add-json` — it takes the blob whole and avoids shell-quoting the command:

```powershell
# Windows — PowerShell, NOT cmd (single quotes are what make this survive)
claude mcp add-json Roblox_Studio '{"type":"stdio","command":"cmd.exe","args":["/c","cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"]}' --scope user
```

```bash
# macOS
claude mcp add Roblox_Studio --scope user -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```

**Take the Windows command from Studio's own panel, not from Roblox's docs.** The docs show `%LOCALAPPDATA%\Roblox\mcp.bat` invoked by absolute path; the panel emits `cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat`. The batch file resolves paths relative to its own directory, so the absolute-path form can spawn and immediately fail — which looks identical to "never connected." Copy whatever the panel gives you.

**3. Verify, in this order:**

1. Quit Claude Code entirely — every window and terminal. stdio servers spawn at session start, so a running session never picks up new config. This is the single most common cause of "enabled but not connected."
2. Studio open, place loaded.
3. Start Claude Code → `claude mcp list` → `Roblox_Studio` reads connected.
4. Studio panel now shows a green indicator with the connected-client count.

Read the indicator correctly: it counts *connected clients*. Enabling the toggle alone shows nothing — that is expected, not a failure.

**Scope is `user`, never committed to `.mcp.json`.** `user` writes to `~/.claude.json` (`%USERPROFILE%\.claude.json`) — machine-wide, private, out of git. `local` also stays out of git but binds to one project directory, so Studio access vanishes the moment you work from anywhere else. Committing to `.mcp.json` is the wrong answer either way: the command is an OS-specific absolute path, so it breaks on the other machine and fails in every cloud session. `.mcp.json` stays empty.

## Working rule — code lives in the repo; building lives in Studio (revised 2026-09-04)

**Split by kind, not by tool.** The line isn't "MCP vs. not MCP" — it's **game logic vs. world content**:

- **Code (Luau scripts implementing game systems) is always repo-authored.** Edit `.luau` under `src/`, let Rojo sync it into Studio. Never hand-write or `execute_luau`/`multi_edit` a system's actual logic directly into the place — that's unversioned, unreviewed, invisible to CI, and (as of 2026-09-04, confirmed) doesn't even survive a Play/Stop cycle in Studio, so it was never a real authoring path for logic anyway.
- **Building (terrain, NPCs, models, materials, decoration, physical placement) is Studio-native work, and that includes doing it through Studio MCP.** PRD §9's "Studio-only assets... documented in a Studio Setup.md runbook" already conceded terrain/placement don't round-trip through Rojo — the 2026-09-04 correction is that the fix isn't "script-generate it from the repo instead," it's "build it by hand in Studio, the way Roblox building normally works," using whatever tool is fastest, MCP included.

| Use it for | Still not for |
|---|---|
| `script_read`, `script_search`, `script_grep`, `search_game_tree`, `inspect_instance` — read the live place | Writing a system's game logic directly into the place — that's still repo + Rojo, always |
| `start_stop_play`, `get_console_output`, `screen_capture` — playtest evidence | Any economy/plate-value logic reaching the client (hard invariant, regardless of where it's authored) |
| `execute_luau`, `multi_edit`, `insert_asset`, `search_asset`, `generate_mesh`, `generate_material`, `generate_procedural_model` — **building**: terrain, NPCs, props, materials, placement | |
| `character_navigation`, `user_keyboard_input`, `user_mouse_input` — drive a playtest, or drive in-Studio building/placement | |
| `http_get`, `skill` — API reference lookups | |

Two payoffs worth having:

- **`reviewer-reality` gets evidence.** Definition of Done demands proof a system is wired end-to-end. Console output and screen captures from a live playtest are exactly that — hand them to the reviewer instead of assertions.
- **World content built in Studio gets documented, not silently left as tribal knowledge.** Terrain, lighting, and physical placement still don't round-trip through Rojo — after building something, note what exists and how it was made in `Studio Setup.md` so it's not only ever known by opening the place.

Game logic surfaced or diagnosed via MCP still gets written back into the repo as a file, by hand — the place file is never the record for *code*. It's fine to be the record for *world content*, same as any other Roblox game's `.rbxl`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| No green indicator, Studio side | Expected until a client connects. Check the client first — `claude mcp list` |
| `Roblox_Studio` absent from `claude mcp list` | Config didn't land in a scope that session reads. Re-add with `--scope user` |
| Listed but "failed" | Wrong command form (see the `cd /d` note above), or Studio wasn't running when the client spawned it |
| Listed as connected, no tools | Restart Studio *and* Claude Code, in that order |
| Launch fails | Verify the path exists; check JSON syntax — a missing comma stops the config loading |
| Wrong place responds | Multiple Studio instances can share one client; the server picks by context. Force it with `list_roblox_studios` → `set_active_studio` |

## Security

Roblox's own warning: *"MCP clients can read and modify content in your open Roblox places. Make sure to only connect clients you trust."*

The MCP has write access to whatever place is open. Connect it against the Sushi Sea dev place, never a published production place.

## Sources

- [Connect to the Roblox Studio MCP server](https://create.roblox.com/docs/studio/mcp) — official, authoritative
- [Roblox/studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server) — legacy standalone server
