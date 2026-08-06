# Sushi Sea

Roblox fishing/restaurant hybrid — *Dave the Diver* × *RuneScape* × *Fisch*. Fish the open seas, process the catch, run a sushi restaurant. The supply chain is the game.

Developed by Claude agent teams under Giahy's direction.

- `HANDOFF.md` — start here every session: mission, decisions, protocols
- `docs/PRD.md` — design source of truth
- `ROADMAP.md` — full development plan: phases, waves, gates
- `TASKS.md` — live module status · `BUILD_LOG.md` — session log
- `.claude/agents/` — the six-agent team (3 dev, 2 review, 1 Opus advisor)
- mem0 (durable decision memory, `user_id: giahy`, `app_id: sushi-sea`) — via the Claude Code mem0 plugin, installed per-environment; needs `MEM0_API_KEY` + `mcp.mem0.ai` network access
- `docs/runbooks/` — Giahy-action runbooks (Roblox Studio MCP; more as modules land)

Branches: `claude/sushi-<feature>` → PR to `dev` → Giahy gates `main`.
