# Build Log

Append-only. One entry per session, newest last. Format:

```
## YYYY-MM-DD — <session focus>
- Done: <what shipped, with branch/PR>
- Decisions: <anything locked, with why>
- Blocked/Open: <blockers, escalations, questions for Giahy>
- Next: <the single most important next action>
```

## 2026-07-05 — Infrastructure bootstrap (Fable 5 + Giahy)
- Done: repo created; HANDOFF.md, CLAUDE.md, TASKS.md, agent roster (6 agents, agency-agents base + Sushi Sea Protocol); PRD copied to docs/; `dev` branch created
- Decisions: dedicated repo (PRD §13 Q1 = B) · PRD §6 sequencing honored · Sonnet orchestrator/workers, Haiku for mechanical tasks, Opus advisor escalation-only · comments stay PRD §8 (reasoning in PRs/commits) · merge gate: auto to dev on CI+2 reviews, Giahy gates main · Figma is the UI tool
- Blocked/Open: M0 cook verb (Giahy grill-me, blocks vertical slice) · branch protection = Giahy manual step · mem0 MCP not connected in bootstrap session — decisions logged here instead
- Next: Wave 1 — M1 toolchain skeleton (`dev-systems`)

## 2026-07-28 — Vault→repo migration (Opus 5 + Giahy)
- Done: staged scaffold moved out of the MIMIR vault into this repo (`HANDOFF`, `CLAUDE`, `ROADMAP`, `TASKS`, `BUILD_LOG`, `README`, 6 agents, `docs/PRD.md`); `.mcp.json` declaring mem0; mem0 protocol bullet added to all 6 agents; `scripts/sync-prd.sh` + `.gitignore`; vault `repo-staging/` deleted
- Decisions: `docs/PRD.md` is a one-way mirror of the vault PRD, enforced by a sync script rather than by discipline — the staged copy had already drifted (it still claimed the repo-layout question was open after §10/§13 Q1 were resolved on 2026-07-05) · mem0 declared at repo root so subagents inherit it, not per-agent
- Blocked/Open: `MEM0_API_KEY` unset in the migration environment, so mem0 tools were unavailable and no memories were written — Giahy must set it as an environment secret · `dev` branch does not exist yet
- Next: Giahy setup checklist (dev branch, MEM0_API_KEY, branch protection), then M0 cook-verb grill-me — still the only thing blocking the vertical slice

## 2026-07-28 — mem0 plugin migration (Sonnet 5 + Giahy)
- Done: verified mem0 works cross-session (two independent agents, one wrote a marker fact, the other retrieved it cold — confirmed via the Claude Code mem0 plugin, not this repo's `.mcp.json`); migrated mem0 wiring from a per-repo `.mcp.json` HTTP entry to the account/environment-level mem0 plugin (`/plugin install mem0@mem0-plugins`) — `.mcp.json`'s mem0 block removed to avoid duplicate tool registration; updated `CLAUDE.md`, `HANDOFF.md` (locked-decisions table + setup checklist), `TASKS.md`, `README.md`, and all 6 agent protocol blocks to match; branch `claude/sushi-mem0-plugin-migration` off `dev`
- Decisions: keep the existing `user_id: "giahy"` scoping convention, add explicit `app_id: "sushi-sea"` on every call — this machine has a global `MEM0_PROJECT_ID=GitHub` env var that pins mem0's auto-detected project scope to `"GitHub"` regardless of repo, so relying on auto-detection would silently mix Sushi Sea memories with unrelated ones. `MEM0_API_KEY` + `mcp.mem0.ai` network access requirements are unchanged — only *where* the MCP server is declared changed
- Blocked/Open: this was verified locally, not in the actual Sushi Sea cloud environment — that environment still needs the mem0 plugin installed (new checklist item) before an agent session there can be trusted · no `gh` CLI or GitHub token available in this environment, so branch protection on `main` is still unset and must be done via the GitHub UI · this branch has not been pushed or opened as a PR yet — pending Giahy confirmation
- Next: Giahy pushes/reviews this branch, completes the updated cloud-environment checklist in `HANDOFF.md`, sets branch protection, then Wave 1 (M1 toolchain skeleton) can start

## 2026-07-29 — M0 cook & serve verb lock (Opus 5 + Giahy, grill-me)
- Done: Open Thread #1 resolved across 18 decision branches; full spec written to `docs/design/cook-verb.md`; `TASKS.md` updated (M0 → review, prep-doc task superseded, vault-edit task added for Giahy)
- Decisions: **two-stage manual verb** — trace the seam (per fish → yield), then one decisive stroke per loin (per loin → grade), outputs deliberately orthogonal so each stage teaches one lesson · **camera-locked 3D board**, not a 2D panel: the lock is what makes the world-space raycast deterministic across devices, and a gray-box `Part` + `Beam` satisfies it so §6's no-fish-models-before-M18 rule still holds · **grades are authored, not multiplied** — `species_base` widens to `cut_base[species][grade]`, keeping Pillar 4 intact and adding no term to §5's chain · **grade is pure slice execution**, loin anatomy does not cap it · **yield floors at a fraction of species max, and the floor rises with Cooking level while `maxYield` does not** — bounded convergence, so level buys consistency and hands buy peak · **cutting resets the clock**: per-portion lifetime = `grade_lifetime[grade] × fish_freshness_at_cut`; the freshness scaling closes a stale-fish laundering loophole, and per-portion (not budget-split) timing avoids making a deliberately bad cut correct before logout · **premium downgrades rather than spoils** (otoro→chutoro→akami→tossed) — grade-accelerated destruction would have put a total-loss state on top of the skill reward, violating Pillar 1, and would have made sandbagging the verb a valid strategy · **staff are tier-capped, not player-capped** — rare staff may equal or beat the player, floors are high so staff never botch, and performance is deterministic because §7.4 requires the offline bank to stay closed-form · **omakase counter dropped**; the player's late-game presence is a quality-and-speed aura on staff, so the late game is management and absence is never punished · **serving is pure delivery**, no order matching · `ConversionModule.cook(fish, performance)` with `performance = {traceAccuracy, strokeQuality[]}` is the one seam §7.6 needs — player and staff fill the same struct
- Blocked/Open: `docs/PRD.md` is a mirror and was deliberately NOT edited — the canonical §4/§5/§6/§12 edits are listed in `docs/design/cook-verb.md` §9 and must be applied vault-side by Giahy, then synced · **mem0 tools absent in this session** (plugin not installed in this environment), so none of the above reached durable memory — this log entry is the only record · carried tuning risks: `cooking_extraction` needs a floor (~`[0.3, 1.0]`) or level-1 plates are worth ~1–5% of base and the tutorial boat earns nothing; value now decays on two axes (continuous freshness + stepwise grade); presence-aura invites idling in the restaurant instead of fishing (M17)
- Next: M0 → done once the vault PRD edits land; M3/M4 are unblocked on the design side, so Wave 1 proceeds with M1 toolchain skeleton

