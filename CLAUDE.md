# Wall Dashboard Project

## Goal

Replace an Echo Show 21 with a self-hosted, wall-mounted panel. The Echo is being removed as a
*screen* — ads, upsells, poor software — not as a control system. Alexa itself stays.

The household splits cleanly: **Alexa runs the devices, Apple runs the schedule.** The panel's job
is to surface both in one place without breaking either.

## Architecture (revised — read this before anything else)

**Home Assistant is the backend, running alongside Alexa, not replacing it and not talking through
it.**

The instinct to have the panel "communicate with Alexa" is the wrong model, because Amazon has no
public API for controlling the devices attached to an Alexa account. Third-party access relies on
an unofficial API that mimics the Alexa app, and Amazon can cut it off without warning. Anything
built on that is built on sand.

The working model instead:

- Home Assistant talks **directly to the same devices Alexa talks to**, using each device's own
  integration. Most "Alexa compatible" gear — smart plugs, TVs, fan controllers — has a native
  Home Assistant integration, frequently a local one that doesn't touch the cloud at all.
- Alexa keeps working, untouched. Both systems control the same devices in parallel. Nobody has to
  relearn a voice command, and no device gets un-paired from Alexa.
- The panel is a Home Assistant dashboard. Custom code in this project is **frontend only**:
  layout, custom cards, CSS, view-switching. If a task starts to look like "write an integration
  for device X," stop and check whether one already exists.

### Where this breaks

Devices that only speak Alexa and have no independent API — Amazon-branded smart plugs are the
main offender — cannot be reached this way. For those, two options:

1. Replace them with equivalents that have a real integration (preferred; they're cheap).
2. Fall back to the Alexa Devices integration's `voice_command`, which sends text to an Echo as if
   it were spoken aloud. This works for control but gives no reliable state feedback, and state
   polling through the Alexa API runs on the order of minutes, not seconds. Acceptable for a
   rarely-used device, unacceptable for anything on the main dashboard.

### Purchasing rule change

Stop buying on "works with Alexa." Buy **Matter** where the option exists. Matter devices work
with Alexa *and* Home Assistant locally, so this problem stops recurring. "Alexa compatible" is
the criterion that produced the devices that will be hardest to bring in.

## Apple integration

- **Calendar — verified 2026-09-13.** iCloud Calendar over CalDAV using an app-specific password.
  Tested with `tools/icloud-caldav-probe.ps1` against Steven's account: all three calendars,
  timed and all-day events, recurring series, all writable. Worth knowing that Apple has never
  officially documented iCloud CalDAV support, so it is a stable-but-unpromised path.
- **Reminders — does NOT work through a primary iCloud account.** Tested the same day: the only
  to-do collection iCloud exposes over CalDAV is a stub named `Reminders ⚠️` containing Apple's
  placeholder text ("The creator of this list has upgraded these reminders"). Every real list
  lives in CloudKit since the iOS 13 "upgrade" and is invisible to CalDAV. Not a config issue;
  Taylor's account will show the identical stub. Do not retry.

  Apple's own doc (support.apple.com/102457, June 2026) says the upgrade "affects existing
  reminders in your primary iCloud account only. Reminders in all other accounts, such as
  secondary iCloud accounts and CalDAV and Exchange accounts, aren't changed." That leaves two
  workable paths, both of which keep Taylor in the Reminders app she already uses:

  1. **Secondary iCloud account — VERIFIED 2026-09-13. This is the path.** A household Apple ID
     is added on each phone as a *second* iCloud account with only Reminders enabled. Lists in
     that account stay in the legacy CalDAV format, appear in the Reminders app under a
     "Household" heading alongside the personal ones, and HA reads/writes them via CalDAV
     exactly like the calendar. Probe result: six per-store lists (Aldi, Publix, Sam's, Target,
     Walmart, plus the default "Reminders"), all writable; an item written over CalDAV appeared
     on the phone and a DELETE removed it. No self-hosting, reachable from anywhere. The login
     is in `HA Important Info.txt`, which is gitignored because this repo is public. Costs: the
     shared lists lose upgraded features (sections, tags, smart lists), the existing grocery
     list gets re-entered once, and Siri targeting a list in the second account is still untested.
  2. **Self-hosted CalDAV server** (Nextcloud / Radicale / Baïkal add-on). Confirmed working with
     the iOS Reminders app as of June 2026, but the server **must be HTTPS with a certificate
     iOS trusts** or Reminders silently refuses to sync, and phones need to reach it away from
     home (Tailscale). More plumbing; fallback if path 1 fails.

  Rejected: iOS Shortcuts pushing lists to a webhook (one-way, panel can't write back), and
  switching the household to Bring!/Todoist/Google Tasks (native HA integrations, but that is a
  migration performed on Taylor, not offered to her).
- **Notes — no supported path.** Apple publishes no API for Notes, and it does not sync over CalDAV.
  Nothing pulls Apple Notes into a web dashboard cleanly. The only realistic bridge is an iOS
  Shortcut pushing note content to a Home Assistant webhook on a schedule or on demand — the same
  Shortcuts-as-glue pattern already used elsewhere in this household. Treat this as one-way,
  best-effort, and do not make anything important depend on it.

## Location (confirmed)

**One panel, hallway wall just outside the kitchen.**

- **Short viewing distance.** A hallway is read from 2–3 feet. A 10–11" tablet is sized correctly;
  a 21"-class panel is oversized and will dominate the space.
- **High-traffic path.** Presence-based wake must distinguish *approach* from *pass-through*, or
  the panel strobes on every time someone walks to the bathroom.
- **Night use.** Aggressive night dimming is mandatory, not a nice-to-have.
- **Power.** A standard receptacle in a recessed box is already installed, and the panel will be
  **flush mounted**. Electrically this is the simplest case: any USB-C charger, no PoE splitter, no
  low-voltage conversion. The cost is depth and heat — the charger brick now lives in the same
  sealed cavity as the tablet. Use a low-profile GaN charger and a right-angle USB-C cable, and
  confirm the box is a recessed/media type that lets the plug sit flush rather than a standard
  old-work box that pushes a brick several inches into the cavity.

### Consequences of flush mounting

- **Device selection must be finalized before any cutout work.** No cutout exists yet and the
  opening can be sized freely, so the device drives the hole rather than the reverse — but do not
  cut until the device is physically in hand and test-fitted. Verify cavity depth and stud spacing
  before committing to a position.
- **Heat has nowhere to go.** Heat plus constant charging is what swells tablet batteries, and a
  swollen battery in a flush mount can crack the screen and is miserable to extract. Charge
  limiting is mandatory; the cavity should have some airflow.
- **Physical access is gone.** No ports, no buttons, no reset. Remote management (Fully Kiosk's
  admin interface) becomes the only way in.
- **Longevity matters more than price.** This device is not getting casually swapped. Favor a long
  OS/security support window over saving $80.

## Hardware (revised)

Panel size is 15–24", which rules out the tablet approach entirely. In-wall mounting and custom
ventilation are both available.

**Two separate machines. Do not combine them.**

- **Server ("the brain")** — Intel N100-class mini PC, wired Ethernet, in a closet near the router.
  Runs Home Assistant OS plus Mealie. Chosen over Home Assistant Green and Raspberry Pi because the
  project now includes a recipe server, camera video handling, and possibly local recording later.
- **Panel** — 15–24" touchscreen monitor, flush mounted, driven by a second small fanless mini PC
  in the wall running a browser in kiosk mode.

If the panel machine also ran Home Assistant, pulling the panel for service would take the whole
house down. Keep them separate.

Constraints:

- **Matte finish, not glossy.** A hallway panel with glare is unreadable.
- **Ventilation required.** A computer and a monitor PSU in a sealed cavity need intake/exhaust.
- **No battery anywhere.** Major advantage over the tablet plan — nothing to swell or degrade.
- Tape out 15", 19", and 24" rectangles on the actual wall before buying. 24" in a hallway is large.

## Hard requirements

- **Presence-based wake**, zone- or dwell-filtered so hallway traffic doesn't trigger it.
- **Calendar and reminders visible at a glance** — this is the primary daily use, not device control.
- **Ambient dimming** at night.
- **Alexa continues to work unchanged** throughout. No device gets un-paired to serve this project.
- **No ads, no account prompts, no vendor home screen.** Ever.

## Voice

**Under consideration: migrating from Alexa to HomePod mini.** Steven and Taylor want to move voice
to Apple. This is coherent with the household's Apple-centric calendar/reminders/notes usage, and
it is achievable — but with two hard conditions.

### Condition 1: do not buy HomePod minis right now

The current HomePod mini launched in October 2020 and still runs the 2019-era S5 chip. A
second-generation model is widely reported for fall 2026 — September or October — tied to the
revamped Siri shipping in iOS 27, with a much faster chip, Thread support, and better connectivity.
Apple also raised the current mini's price to $129 in June 2026.

Buying today means paying a raised price for six-year-old hardware, weeks before its replacement,
and getting old Siri — which is worse than Alexa at exactly the things this household would notice.
The entire case for switching rests on the new Siri. Wait for the announcement.

### Condition 2: Home Assistant goes in first

Most existing Kasa plugs are not HomeKit-compatible, so Apple Home cannot see them natively.
Home Assistant's HomeKit Bridge solves this: it exposes any Home Assistant entity to Apple Home as
a native accessory, which means Siri can control the Kasa plugs, the Rokus, and eventually the
ceiling fans without any of those devices needing HomeKit support of their own.

This inverts the earlier reasoning. Home Assistant is no longer just the dashboard backend — it is
the thing that makes an Alexa-to-Apple migration possible without replacing the device fleet.
Build it first, then migrate voice on top of it.

### Migration approach

**Three Echo Dots, plus the Echo Show being removed — four voice points total.** At this scale cost
is not a serious objection, which makes this a cheap, staged experiment rather than a commitment.

Buy **one** HomePod mini when the new model ships. Put it in the most-used room. Live with it for
two weeks with the Echo Dots still running — Alexa and Apple Home can control the same devices
simultaneously through Home Assistant, so nothing has to be unplugged. If Siri holds up for Taylor
in daily use, buy the rest. If it doesn't, the loss is one speaker.

Note that removing the Echo Show also removes a voice point wherever it currently sits. If that
spot needs voice, the replacement count is four, not three.

### Known regressions

- Apple's Intercom is weaker than Alexa's Drop In for room-to-room announcements.
- Anything not in Home Assistant becomes unreachable by voice after the switch. This is the point
  at which the ceiling fan question stops being deferrable.
- Amazon Music does not run natively on HomePod.

## Cameras

Ring is currently in use but is the weakest link in this stack. Ring cameras expose no local video
access at all; Home Assistant can only reach them by impersonating the Ring app against Amazon's
cloud, tokens expire on a shortening window, and the integration broke outright for many users in
July 2026. It also keeps an Amazon dependency in a project premised on leaving Amazon.

The household is open to switching. The fork:

- **Local cameras (Reolink PoE) — recommended.** Officially certified to work with Home Assistant,
  fully local, no subscription, fast on the panel, and still publishable to Apple Home through the
  HomeKit bridge. Satisfies both surfaces.
- **HomeKit Secure Video cameras (Aqara G410 etc.).** Excellent in the Apple Home app, but HKSV
  streams are encrypted such that Home Assistant cannot read them — they would be effectively
  invisible to the wall panel. Wrong choice for this project.

Not urgent. Existing Rings keep working in the Ring app regardless.

## Recipes

**Use Mealie. Do not build a recipe app.** Self-hosted on the server box: unlimited recipes with
photos, URL import that scrapes and strips the preamble, built-in weekly meal planner, shopping
list generation, and a clean mobile interface. "Recipes at the click of a button" is satisfied by a
dashboard button that opens Mealie full screen.

**On the weekly menu note:** Apple Notes has no API, so a literal link between Mealie and the note
is impossible. Mealie's meal planner would replace the note, not sync with it. That is Taylor's
decision to make, presented as an option — not a migration to be performed on her. If she prefers
the note, the panel shows the recipe library and she plans where she plans.

## DAKboard — open question raised by Taylor

DAKboard is a cloud-hosted dashboard service: you design a layout in their browser editor and any
screen displays it. Free tier exists; Essential is about $5/mo billed annually. Their own hardware
is overpriced (CPU v5 ~$180, 22" touch display ~$600) — if this path is taken, run their software
on the mini PC and monitor already planned.

It is no longer a passive photo/calendar frame. Their 2026 "TouchHub" release added interactive
calendar editing, tasks, timers, and **Home Assistant controls**, available on every plan including
Free. A meal planner with recipes was announced in July 2026 but described as upcoming — do not
buy on that promise.

**It is not an alternative to Home Assistant.** It has no way to talk to Kasa plugs or Rokus
directly; its smart-home controls work *through* Home Assistant. Either path needs the server box
built first, which is why this changes nothing about Phase 1.

**The real argument for it:** Taylor can edit a DAKboard layout herself in a drag-and-drop browser
editor. A Home Assistant dashboard is YAML, which means every change routes through Steven. For a
household where Taylor owns the calendar and the menu, that difference matters more than aesthetics.

**The real argument against it:** a subscription and a cloud dependency for the presentation layer,
in a project whose premise is not being subject to a vendor's decisions. Milder than Amazon, but
the same shape.

**Decision: defer.** The wall panel is a browser pointed at a URL. Which URL it loads is the most
reversible decision in the entire project and can be changed in thirty seconds after everything is
mounted. Build Home Assistant first, then try both.

## Aesthetics

Default Lovelace looks like a config screen. Target is product-grade. Tools: Mushroom cards, Bubble
Card, card-mod, and hand-written custom cards where those fall short. Typography, spacing, and
dark-mode behavior matter more than usual because this screen sits in peripheral vision all day.

## Success metric

**Someone who did not build it can walk up, see today's schedule, and turn off a light without
asking for help.** Any common action taking more than two taps is a design failure.

## Sequencing

The project is now larger than a dashboard build. Order of operations:

1. Inventory every smart device by brand and model; determine which have Home Assistant
   integrations and which are Alexa-only.
2. Stand up Home Assistant and get devices in. This is the long pole, not the panel.
3. Wire up iCloud Calendar via CalDAV (verified). Reminders need the secondary-account approach
   above — prove it before building anything that depends on the to-do entities.
4. Build the dashboard against a real instance with real entities.
5. Choose hardware, test-fit, **then** cut drywall.

Do not cut the wall until step 4 is working on a tablet sitting on a counter.

## Non-goals

- Replacing or automating against the household's Apple Notes budgeting system. It works, it is
  Taylor's system, and Notes has no API anyway. Leave it alone.
- Rebuilding any Home Assistant integration from scratch.
- Netflix / YouTube / DRM video playback in kiosk mode.
- Portability. This is a fixed wall panel.

## Device inventory (partial)

| Device | Count | Home Assistant path | Action |
| --- | --- | --- | --- |
| Kasa smart plugs (TP-Link) | most | Native integration, local control | None — best case, these just work |
| Amazon-branded smart plugs | a few | None. Alexa-only, no independent API | Replace. They're cheap and few |
| Vizio TVs | 3 | SmartCast integration, but control via Roku instead | Staying long-term. Add Roku sticks to the other two |
| Roku sticks | 1, going to 3 | Native integration, local | Standardize on this as the TV control layer |
| Ceiling fan / light controllers | 2 | Unknown | **Main unknown.** See below |

### Ceiling fans

Described as "kind of random," which usually means RF remote-controlled units (Hampton Bay, King of
Fans, Harbor Breeze) with no network connectivity of their own — they're only "smart" because an
Alexa-linked bridge or a smart switch sits in front of them. If they're RF, a Bond Bridge is the
standard solution and has a Home Assistant integration. If they're Wi-Fi units on a Tuya-based
platform, expect either a cloud-dependent integration or local key extraction. Identify the actual
brand before assuming either.

### TVs — standardize on Roku as the control layer

TV replacement is expensive and has no timeline, so the Vizios stay for the foreseeable future.
The plan is to add Roku sticks to the remaining two so all three sets run Roku.

This is a good outcome for the dashboard. Home Assistant's Roku integration is local and
well-supported, gives power, app launch, and remote functions, and standardizing all three TVs on
one integration means one set of entities and one card pattern instead of three special cases.
Prefer the Roku entities over the Vizio SmartCast integration for anything the Roku can do.

The one thing to test early: powering the TV on through the Roku depends on HDMI-CEC, which is
inconsistent across Vizio models. If CEC doesn't work, the dashboard can launch apps and control
playback but can't wake a TV that's fully off. Verify before designing a card around a power button.

Ad exposure on the Roku home screen is a known and accepted tradeoff here — a TV home screen is
seen for a few seconds before launching an app, which is a different problem from an always-on
panel in a hallway.



- **Deferred:** ceiling fan controller brands. Requires physical inspection, not possible for at
  least a week. This is not blocking — it's 2 devices out of roughly 20, and the fans can be added
  after the panel is working. Do not let this gate the rest of the project.
- Where will Home Assistant run — a mini PC, a Raspberry Pi, or Home Assistant Green?
- Which music service is in use? Spotify and Apple Music both work natively on HomePod. Amazon
  Music does not, and would be reduced to AirPlay from a phone — a real regression if anyone
  uses it daily.
