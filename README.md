# Layton Family Command Center

Self-hosted Home Assistant wall panel replacing an Echo Show 21. Everything is in the **test
phase** on a VirtualBox VM — nothing is purchased and no real device is connected until the
purchase gate in `MODULES.md` is passed.

## Start here

| File | What it is |
| --- | --- |
| `CLAUDE.md` | Project spec: goals, architecture, settled decisions, constraints. Read first. |
| `MODULES.md` | The learning/build plan, one module per Claude Code session. Where we are. |
| `SESSION-LOG.md` | Chronological record of decisions, reversals, dead ends. Updated at the end of every session. |
| `PRIMER.md` | Plain-language explainer of how the whole system works. |
| `DASHBOARD-COOKBOOK.md` | Task-oriented Home Assistant dashboard reference. |
| `hallway-dashboard-demo.yaml` | Current dashboard YAML (demo entities). |
| `ios-themes.yaml` | HACS iOS Themes file, kept for reference. |

The VM disk (`haos_ova-18.2.vdi`) lives alongside these files locally but is git-ignored.

## Starting a session

Open Claude Code in this folder and say:

> Read CLAUDE.md, SESSION-LOG.md, and MODULES.md. We're on module N.
