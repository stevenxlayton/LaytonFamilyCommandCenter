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
| 0 | Housekeeping | **In progress** | No |
| 1 | Home Assistant fundamentals | Not started | No — demo |
| 2 | Dashboard build | Not started | No — demo |
| 3 | Automations | Not started | No — demo |
| 4 | Calendar and to-do | Not started | Yes — iCloud CalDAV |
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
- [ ] **When home, not on plane/hotel Wi-Fi:** switch VM Adapter 1 from NAT to Bridged so HA is
      on the home LAN. Needed for Modules 4, 7, 8. Until then, HA is at `http://127.0.0.1:8080`.

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

- First with the Local Calendar and Local To-do integrations (mock, no account).
- Then iCloud CalDAV: app-specific password, add the integration, pick calendars and Reminders
  lists. Verify: does Taylor's per-store grocery sectioning survive? (Expected: no — one list
  per store.) Decide with her.
- Calendar card views (`list` vs day/week), merged agenda across calendars, `todo-list` card
  with add/check from the panel.

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
