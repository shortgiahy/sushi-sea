# Sushi Sea

Roblox fishing/restaurant hybrid — *Dave the Diver* × *RuneScape* × *Fisch*. Fish the open seas, process the catch, run a sushi restaurant. The supply chain is the game.

Developed by Claude agent teams under Giahy's direction.

- `HANDOFF.md` — start here every session: mission, decisions, protocols
- `docs/PRD.md` — design source of truth
- `ROADMAP.md` — full development plan: phases, waves, gates
- `TASKS.md` — live module status · `BUILD_LOG.md` — session log
- `.claude/agents/` — the six-agent team (3 dev, 2 review, 1 Opus advisor)
- `.mcp.json` — mem0 (durable decision memory, `user_id: giahy`); needs `MEM0_API_KEY`
- `scripts/sync-prd.sh` — pull `docs/PRD.md` from the vault; `--check` detects drift

Branches: `claude/sushi-<feature>` → PR to `dev` → Giahy gates `main`.
