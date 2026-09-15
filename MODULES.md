# Modules — the build and learning plan

One module per Claude Code session. This file is the project's state: which module is active,
what "done" means for each, and what's gated behind what. Update the status column as you go.

## How sessions work

- **Start every session with:** "Read CLAUDE.md, SESSION-LOG.md, and MODULES.md. We're on
  module N." That's the full handoff — nothing lives in chat history that isn't in these files.
- **End every session by** having Claude update `SESSION-LOG.md` (decisions, dead ends, current
  state) and the status column below, then commit and push.
- **Start a new session when:** you switch modules, a session hits a big dead end (fresh context
  beats polluted context), or Claude starts repeating itself or forgetting earlier decisions.
- **Stay in a session while** iterating on one thing.
- **HA host is moving off the laptop.** From 2026-09-15 (planned) Home Assistant runs bare-metal
  on the J4105 mini PC, wired to the router — see `HAOS-INSTALL.md`. The laptop becomes the panel
  stand-in only. Until that install is done, the VM rules below still apply.
- **Run the VM plugged in.** This laptop hard-freezes on battery, and a freeze mid-write can
  corrupt the disk image. Take a VirtualBox snapshot before anything risky.

## Ground rules for the test phase

1. **Nothing gets bought** until Modules 6 and 7 both pass. Not the server, not the monitor.
2. **Real connections are allowed when they're zero-risk.** Adding a Kasa plug, a Roku, or iCloud
   CalDAV to Home Assistant changes nothing about Alexa or Apple — HA is a second reader, not a
   migration. What stays off-limits: un-pairing anything from Alexa, replacing any device, cutting
   drywall.
3. **This laptop is the panel stand-in.** It's a touchscreen; Module 6 is literally "run the
   dashboard full-screen on it and hand it to Taylor."
4. **Demo entities are for learning the tool, not for judging the result.** Modules 1–3 use them.
   From Module 4 on, real data where it's free to get.

## The modules

| # | Module | Status | Real stuff? |
| --- | --- | --- | --- |
| 0 | Housekeeping | Done | No |
| 1 | Home Assistant fundamentals | **Next** | No — demo |
| 2 | Dashboard build | Not started | No — demo |
| 3 | Automations | Not started | No — demo |
| 4 | Calendar and to-do | **Gate passed 2026-09-13** — calendar and reminders both round-trip via CalDAV; Taylor's phone + Siri still to test | Yes — iCloud CalDAV |
| 5 | Mealie | Not started | No |
| 6 | Panel simulation | Not started | No |
| 7 | Device discovery | Not started | Yes — Kasa, Roku (read-only) |
| 8 | HomeKit Bridge | Not started | Demo entities → Apple Home |
| — | Cameras, voice | Deferred | Hardware-gated |

Modules 1–3 are where the learning curve actually is. Everything after is plumbing on top of
skills you'll already have.

---

### Module 0 — Housekeeping

Goal: a clean, versioned project folder and a VM you can't break.

- [x] Flatten the folder: docs at root, delete `files/` and the zip
- [x] `git init`, `.gitignore` the VDI, point at `LaytonFamilyCommandCenter`, push
- [x] Write this file
- [x] VirtualBox snapshot `clean-demo-hacs-themes`
- [x] Switched VM Adapter 1 from NAT to Bridged (Wi-Fi). HA is at `http://homeassistant.local`
      or `http://192.168.1.212` on the home LAN. `127.0.0.1:8080` no longer works.

Done when: all boxes checked and `git status` is clean.

### Module 1 — Home Assistant fundamentals

Goal: know your way around the tool well enough that the cookbook makes sense.

- Vocabulary in practice: entity vs device vs area vs integration. Create areas (Kitchen,
  Hallway, Living room, Bedroom) and assign demo devices to them.
- Settings tour: Devices & Services, Areas, Entities, System, Add-ons, Backups.
- Developer Tools: States (the lookup table), Template (the sandbox), Actions (run a service
  by hand). Do one of each.
- `configuration.yaml`: where it is, how to edit it (File Editor add-on or Studio Code Server
  add-on), what `demo:` does, how to check config and restart.
- Backups: make one, understand what's in it, restore from the snapshot once on purpose.
- Users and access: create a non-admin user (this is what the panel will log in as).

Done when: you can find any entity's `entity_id`, read its attributes, call a service on it from
Dev Tools, and explain what an area is without looking it up.

### Module 2 — Dashboard build

Goal: the hallway dashboard, looking like a product, full-screen on this laptop.

- Sections view mechanics: `max_columns`, why sections don't stack, heading cards, badges.
- Tile cards with features; `tap_action` / `navigate` between views; conditional cards.
- Multi-view dashboard: Home, Calendar, Lights, Media, Recipes (placeholder). `path:` on each.
- Themes: apply an iOS theme, understand light/dark switching.
- HACS cards: Mushroom, card-mod, kiosk-mode. Install, use each once, decide what to keep.
- Run it full-screen in a browser on this laptop and touch it. Fix what's too small.

Done when: every common action is ≤2 taps and it doesn't look like a config screen.

### Module 3 — Automations

Goal: the panel does things on its own.

- Trigger / condition / action model. Build in the UI, read the YAML.
- Time-based: switch theme to dark at sunset, back at sunrise.
- State-based: when demo motion sensor fires, navigate the panel to the camera view, then back.
- browser_mod: register this laptop's browser as a device HA can command (navigate, popup,
  screen on/off). This is the mechanism behind presence wake later.
- Scripts vs automations vs scenes — when each.

Done when: the dashboard changes view and theme without you touching it.

### Module 4 — Calendar and to-do

Goal: today's schedule and the grocery list on the panel, from the real iCloud account.

**Pulled forward on 2026-09-13** because this is the household's primary use and had never been
tested. `tools/icloud-caldav-probe.ps1` talks to iCloud exactly as HA's CalDAV integration does,
with HA out of the loop. Result: **calendar works in full; Reminders through a primary iCloud
account does not and cannot** — Apple moved upgraded Reminders off CalDAV in 2019 and leaves only
a `Reminders ⚠️` placeholder behind. Full reasoning and the two viable paths are in `CLAUDE.md`
under *Apple integration*.

- [x] Probe Steven's account: 3 calendars, events with times, recurring series, writable. Good.
- [x] Probe Reminders: stub only. Dead end — do not retry against Taylor's account, same result.
- [x] **Gate test for the secondary-account path — PASSED 2026-09-13.** Household Apple ID
      created on Steven's phone, attached as a second iCloud account with only Reminders on.
      Probe against that account: no `Reminders ⚠️` stub, 2 default calendars (Home, Work) and
      **6 Reminders lists (Aldi, Publix, Reminders, Sam's, Target, Walmart), all writable.**
      Write test: item created over CalDAV appeared in the Reminders app on the phone, DELETE
      removed it again. The household login lives in `HA Important Info.txt` (gitignored — the
      repo is public); the app-specific password goes into HA's CalDAV integration and nowhere else.
- [ ] Taylor adds the same account on her phone (Settings → Apps → Reminders → Reminders Accounts
      → Add Account → iCloud → sign in → only Reminders on → rename description "Household").
- [ ] Siri test from either phone: "Add bread to the Walmart list." Pass = lands in Household →
      Walmart. If Siri asks which list or picks the personal account, note it and plan around it.
- [ ] Taylor decides whether the real grocery lists move to the household account. Cost: no
      sections/tags on those lists; items re-entered once. Her call, not a migration done to her.
- [ ] Self-hosted CalDAV (Nextcloud/Radicale/Baïkal, trusted HTTPS cert + Tailscale) is the
      fallback only if Apple ever breaks the secondary-account path. Not needed now.
- [ ] Then in HA: Local Calendar / Local To-do first (mock), then CalDAV integration with the
      chosen account. Calendar card views (`list` vs day/week), merged agenda across calendars,
      `todo-list` card with add/check from the panel.
- [ ] HA's CalDAV integration polls every **15 minutes**. Add an automation that calls
      `homeassistant.update_entity` on the calendar and todo entities every 2–5 minutes so a
      reminder added on a phone reaches the panel in a reasonable time.

Done when: you add a reminder on the panel and it shows up on Taylor's phone.

### Module 5 — Mealie

Goal: recipes at one tap.

- Install the Mealie add-on. Import three recipes by URL. Try the meal planner once.
- `iframe` card on a Recipes view; fix any embed-refusal issue.
- Decide with Taylor: meal planner replaces the Notes menu, or panel just shows the library.

Done when: a Recipes tap opens Mealie full-screen and a recipe is readable at arm's length.

### Module 6 — Panel simulation (purchase gate 1)

Goal: prove the household likes it before spending anything.

- Kiosk browser on this laptop (Fully Kiosk isn't on Windows; use a Chromium `--kiosk` shortcut
  or equivalent). Auto-login as the panel user. Hide everything but the dashboard.
- Night dimming and screen wake via browser_mod / automations from Module 3.
- Prop it in the hallway for a week. **Success metric: Taylor walks up, sees today's schedule,
  turns off a light, without asking.** Log every "how do I…" as a design defect.

Done when: a week of use produces no open "how do I" items.

### Module 7 — Device discovery (purchase gate 2)

Goal: confirm HA sees the real fleet. Read-only, Alexa untouched. Requires Bridged networking.

- Kasa plugs: should auto-discover. Count found vs. owned. Anything missing is Amazon-branded
  → on the replace list.
- Roku: auto-discover, test app launch and **HDMI-CEC power-on** on the Vizio. This decides
  whether the TV cards get a power button.
- Ceiling fans: physically inspect, identify brand/model, determine path (Bond / Tuya / other).
- Replace the demo entities on the dashboard with real ones.

Done when: every non-Amazon device is in HA and controllable from the panel, and the fan path
is known.

### Module 8 — HomeKit Bridge

Goal: Siri on your phone controls a Kasa plug via HA. This is what makes the Alexa → HomePod
migration possible, so prove it early.

- Add the HomeKit Bridge integration, expose a few entities, pair from an iPhone's Home app.
- Control a plug from Home app and from Siri. Check state sync both directions.

Done when: "Hey Siri, turn off the porch plug" works, and Alexa still does too.

---

## After the gates

Only once 6 and 7 pass: buy the server mini PC (Intel 12th-gen+ with Quick Sync — see
`CLAUDE.md`), install HAOS bare-metal, restore the VM's backup onto it, then panel hardware,
test-fit, and only then drywall. Voice migration waits for HomePod mini gen 2.
