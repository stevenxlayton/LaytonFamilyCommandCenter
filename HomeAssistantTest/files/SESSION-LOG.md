# Session Log — Wall Panel Project

Chronological record of the conversation that produced `CLAUDE.md`, `PRIMER.md`, and
`DASHBOARD-COOKBOOK.md`. Not verbatim — this captures decisions, reversals, dead ends, and
current state.

**Session dates:** September 6–10, 2026. Steven was on vacation for most of it, away from the
house and its devices.

---

## How Steven wants to be worked with

Stated explicitly and reinforced throughout:

- Stress-test ideas before agreeing. Lead with what's wrong or missing.
- No filler affirmations, no "great question," no echoing his framing back.
- Direct and concise. If the answer is no, say no in the first sentence.
- Casual and profane is fine.
- Concede cleanly when wrong, then move on without over-apologizing.

He is technically capable — builds single-file PWAs, uses Claude Code — but is a **complete
beginner at home automation**. Explain domain concepts; don't explain software concepts.

---

## Phase 1 — Origin and framing

Started with "I hate my Echo Show 21, does Apple have anything similar?"

- **Apple:** no smart display exists. A 7" model (J490) is rumored for late 2026 / early 2027.
  Not a replacement for a 21" panel. Rejected.
- **Google:** Nest Hub Max discontinued from direct sales May 2025, hardware from 2019–2021,
  no shipped replacement. Rejected.
- Complaints were ads, poor software, and Alexa Plus being bad — not hardware failure.
- **Conclusion:** leave the appliance model entirely. Self-hosted wall panel.

## Phase 2 — Scoping the physical install

Established across several exchanges:

- Location: hallway wall just outside the kitchen. One panel.
- Flush mounted. In-wall power already installed: **standard receptacle in a recessed box**.
- No cutout yet; opening can be sized freely. Can add ventilation. Can mount inside the wall.
- Screen size: **15"–24"**.

## Phase 3 — The scope kept expanding

Each answer changed the project:

1. Initially appeared to be an information panel with no smart home behind it.
2. Then: 10–30 Alexa-connected devices exist.
3. Then: household wants to migrate voice from Alexa to HomePod mini.
4. Then: Ring cameras, recipes, and Apple calendar/reminders all in scope.

**Device inventory as established:**

| Device | Detail |
| --- | --- |
| Smart plugs | Mostly Kasa (TP-Link, local integration — best case). A few Amazon-branded (Alexa-only, replace them) |
| TVs | 3× Vizio, staying long-term (replacement too expensive). 1 Roku stick, adding 2 more |
| Ceiling fans | 2, brands unknown, described as "kind of random." **Deferred** — requires physical inspection |
| Echo speakers | 3 Echo Dots, plus the Echo Show being removed |
| Cameras | Ring |

## Phase 4 — Key technical findings

- **Amazon has no public API for controlling Alexa-attached devices.** Third-party access
  impersonates the Alexa app and can be cut off. Architecture is therefore: Home Assistant talks
  *directly* to the same devices Alexa talks to, in parallel. Not through Alexa.
- **Home Assistant's HomeKit Bridge** exposes any HA entity to Apple Home. This is what makes the
  Alexa→HomePod migration possible without replacing the Kasa fleet. It is the single strongest
  argument for Home Assistant in this project.
- **Apple Calendar and Reminders** work via iCloud CalDAV with an app-specific password.
- **Apple Notes has no API.** Cannot be integrated. Only bridge would be an iOS Shortcut pushing
  to a webhook. Treated as out of scope.
- **HomePod mini gen 2** widely reported for fall 2026 tied to revamped Siri in iOS 27. Current
  model is 2020 hardware, price raised to $129 in June 2026. **Advice: do not buy until the new
  model ships.**
- **Ring** has no local video access, broke for many users in July 2026, and keeps an Amazon
  dependency. Recommended switch to **Reolink PoE** (local, HA-certified). Explicitly warned
  against HomeKit Secure Video cameras — HKSV streams are encrypted such that HA cannot read
  them, making them invisible to the wall panel.
- **Recipes: use Mealie**, don't build. Taylor's grocery list uses per-store sections inside one
  Reminders list; **those sections likely won't survive CalDAV sync** — expect one list per store.

## Phase 5 — Reversals (important)

Three recommendations were made and then reversed as facts emerged. The later position is correct.

1. **Home Assistant Green → N100/N-class mini PC → Intel 12th-gen+ Core.** Green was recommended
   before recipes, cameras, and possible local recording were in scope. Final reasoning: Intel
   **Quick Sync** is the spec that matters, because Frigate depends on hardware video decode and
   AMD's VAAPI path is poorly documented.
2. **Wall tablet → touchscreen monitor.** The 15–24" requirement killed the tablet plan entirely.
   Battery swelling concerns became moot.
3. **"Don't integrate the Vizios" → standardize on Roku.** Was based on the TVs being replaced
   soon; they aren't. Control all three through Roku's local HA integration rather than SmartCast.

## Phase 6 — Hardware sourcing

- Steven initially picked a **GMKtec NucBox G10** (Ryzen 5 3500U, 16GB, 512GB, 2.5GbE, two full
  M.2 2280 slots, ~$150). Not a bad box; the CPU is a 2019 architecture and the weakness is AMD
  video transcoding.
- **Recommended instead: GEEKOM IT13 (i5-13600H)**, ~$450–550. Iris Xe with Quick Sync, 2.5GbE,
  64GB RAM ceiling, three storage slots, 3-year warranty, stocked at Best Buy.
- **Correction made:** an earlier spec of "two M.2 2280 NVMe slots" was over-specified. A second
  drive for backups or recordings is sequential-write work; a SATA slot is fine.
- Warned against "upgrading" to an N100/N150 — cheaper, but a CPU downgrade from the G10 and
  capped at 16GB RAM.

## Phase 7 — VirtualBox test environment

Steven set up a trial instance while traveling. This was painful and most of it is not relevant
to the real deployment, but two things are worth carrying forward:

### The port 80 problem (cost roughly an hour)

**Home Assistant OS in this VM serves on port 80, not 8123.** The console printed
`http://homeassistant.local` with no port, which was visible in the first screenshot and missed.
Every suggested URL used `:8123` and nothing was ever listening there.

Compounding factors: hotel Wi-Fi blocked device-to-device traffic, so bridged networking failed;
and `Test-NetConnection` reported success on the forwarded port because VirtualBox NAT completes
the host-side handshake before reaching the guest.

**Working configuration:**

- VM network: NAT
- Port forward: `HA80, tcp, (blank host IP), 8080, (blank guest IP), 80`
- Access at `http://127.0.0.1:8080`
- Confirmed with `ha core info` in the VM console, which prints `port: 80`

Switch Adapter 1 back to **Bridged** when home, or HA won't see the Kasa plugs.

### Environment state

- Home Assistant OS 18.2, Core 2026.9.1
- `demo:` added to `configuration.yaml` for fake entities (remove before adding real devices)
- HACS installed
- iOS Themes (basnijholt/lovelace-ios-themes) downloaded via HACS. **Use the non-`-alternative`
  themes** — HACS only pulls `ios-themes.yaml`, and the alternative variants need seven jpgs that
  were never downloaded. Default themes load backgrounds from GitHub.
- Local to-do lists created to demo Taylor's grocery list without connecting a real account
- Dashboard experiments in a `sections` view. Note: **sections cannot stack vertically in one
  column.** Either lower `max_columns` so they wrap, or merge sections and use multiple `heading`
  cards inside one.

## Phase 8 — Dead ends, don't retry

- **Demo integration cannot be added from the UI.** It's YAML-only: add `demo:` to
  `configuration.yaml`.
- **DAKboard** was evaluated at Taylor's suggestion and rejected by Steven. It is not an
  alternative to Home Assistant — its smart home controls work *through* HA. The one real argument
  for it was that Taylor could edit the layout herself; Steven is comfortable making changes for
  her.
- **Apple Notes integration.** No API. Stop looking.

---

## Current state

Working Home Assistant instance in a VM with demo entities, HACS, and themes. No real devices
connected — Steven is away from home. Server hardware not yet purchased.

## Next steps

1. Buy the mini PC (Intel 12th-gen+ Core, Quick Sync).
2. Install Home Assistant OS on it directly — skip the VM entirely, the USB install is simpler
   than what was fought through here.
3. Add real devices: Kasa plugs and Rokus should auto-discover.
4. Connect iCloud Calendar and Reminders via CalDAV.
5. Install Mealie, import Taylor's recipes.
6. Build the dashboard against real entities.
7. Buy the monitor and panel PC, test-fit on a table, **then** cut drywall.
8. Voice migration when HomePod mini gen 2 ships — buy one, run it alongside the Dots.

## Open questions

- Ceiling fan controller brands (deferred, requires physical inspection)
- Music service in use — Amazon Music doesn't run natively on HomePod
- Whether to switch cameras off Ring, and to what

## Reference documents

- `CLAUDE.md` — project spec, decisions, constraints
- `PRIMER.md` — plain-language explainer of how the whole system works
- `DASHBOARD-COOKBOOK.md` — task-oriented Home Assistant dashboard reference
