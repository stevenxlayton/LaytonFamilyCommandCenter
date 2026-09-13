# How This Actually Works — A Plain-Language Primer

You are not behind. You asked good questions in a confusing order, which is normal. This document
answers them in a sane order and assumes zero prior knowledge.

---

## 1. The single most important thing to understand

**The brain and the screen are two different computers.**

Almost all your confusion comes from these being blurred together. Separate them and everything
else gets easier:

| | The brain (server) | The screen (panel) |
| --- | --- | --- |
| What it is | A small computer running Home Assistant | A touchscreen showing a web page |
| Where it lives | A closet or shelf near your router | Flush-mounted in the hallway wall |
| What it does | Talks to every device, runs automations, stores everything | Displays the dashboard. That's it |
| If it dies | Nothing in the house works | You lose a screen. Everything still works |

The Echo Show was one object doing both jobs. That's why it felt simple, and also why you couldn't
change anything about it. Splitting them is what buys you control.

The panel is a **thin client** — it opens a browser, loads one web page full-screen, and never does
anything else. That web page is served by the brain.

---

## 2. What Home Assistant actually is

It is a piece of **software** — free, open source — that runs on a small computer you own. Think
of it as a universal translator and switchboard sitting in the middle of your house.

**What it does:**

- Talks to your devices directly on your own network. Kasa plugs, Rokus, cameras, fans, thermostats.
- Presents all of them in one place, with one consistent interface.
- Runs automations ("when the doorbell rings, switch the hallway panel to the camera view").
- Serves the dashboard web page that your wall panel displays.
- **Bridges to other ecosystems.** This is the part that matters most for you: Home Assistant can
  present all your devices to Apple Home as if they were native Apple accessories. That's how your
  non-Apple Kasa plugs end up controllable by Siri on a HomePod.

**What it is not:**

- It is not a voice assistant. It doesn't listen and it doesn't talk back.
- It is not a cloud service. It runs in your house on your hardware.
- It is not an app you install on a tablet. It's a server.

---

## 3. "I won't be able to talk to it?"

You will — but not to Home Assistant. You'll talk to **HomePod minis**, exactly like you talk to
Echo Dots today. Here's the chain:

> You say "Hey Siri, turn off the kitchen light"
> → HomePod hears it
> → Apple Home looks up "kitchen light"
> → Apple Home sees it because Home Assistant published it there
> → Home Assistant sends the command to the actual Kasa plug

You never say the words "Home Assistant" out loud. It's plumbing. The HomePods are the voice, the
wall panel is the screen, Home Assistant is the thing connecting them to your actual devices.

The wall panel itself has no microphone and doesn't need one. It's a screen.

---

## 4. "Will I have a dashboard like the Show, but better?"

Yes, and it isn't close. But be clear about what "better" means here.

**What you get for free:** no ads, no upsells, no Amazon account nagging, nothing changing because
a company shipped an update you didn't ask for. Every pixel is yours permanently.

**What you have to earn:** it looks like whatever you make it look like. Out of the box, Home
Assistant's dashboard looks like a control panel — functional, a bit ugly. Getting it to look like
a polished product is real work, and it's the part you'll enjoy.

**What "making cards" actually means:** a dashboard is built from cards — a weather card, a light
card, a camera card, a calendar card. Most of them already exist. You arrange them in a layout,
and you write configuration describing what goes where. It looks like this:

```yaml
type: thermostat
entity: climate.hallway
```

That's the whole thing for one card. It's structured configuration, not programming.

---

## 5. "Are we coding this from scratch?"

No. Rough breakdown of where your effort goes:

- **~70% clicking through setup screens.** Adding devices, entering passwords, naming things.
  Genuinely boring, no code.
- **~20% writing configuration.** YAML like the example above. Fussy about indentation, not hard.
- **~10% actual custom work.** Custom cards, CSS, unusual layouts, animations. This is the part
  where Claude Code is genuinely valuable, and it's a small slice.

**Customization ceiling: extremely high.** People build dashboards indistinguishable from
commercial products. There is a large ecosystem of pre-built card libraries — Mushroom for clean
minimal cards, Bubble Card for a phone-app feel, card-mod for arbitrary CSS. You can also write a
completely custom card in plain HTML/CSS/JavaScript and drop it in, which given your background is
probably where you'll end up for the hero elements.

---

## 6. Hardware — I need to correct myself

You said 15" to 24". That kills the tablet plan I laid out earlier, and it revives the option I'd
written off. A 24" wall-mounted panel is not a tablet, it's a monitor.

**Revised recommendation: two mini PCs.**

**The brain** — an Intel N100-class mini PC in a closet near your router, wired by Ethernet. Not
the Home Assistant Green I suggested before. The Green is a fine appliance but it runs Home
Assistant and nothing else, and you've since added requirements — a recipe server, camera video
processing, possibly local camera recording later — that want more storage and more CPU than it
has. The Pi has the same problem plus assembly work. An N100 mini PC costs about the same, handles
all of it, and can run other things you'll inevitably want.

**The panel** — a 15–24" touchscreen monitor, flush-mounted, driven by a second small mini PC
mounted in the wall behind it running a browser in kiosk mode.

Given you can build into the wall and add ventilation, this is very achievable. Notes:

- **Ventilate it.** You're putting a computer and a monitor power supply in a sealed cavity. A
  fanless N100 plus a small intake/exhaust vent is the clean approach.
- **No battery.** A major upside over the tablet plan — nothing to swell, nothing to degrade.
  Wall power, permanently on.
- **Touchscreen monitors in the 15–22" range** are mostly commercial/POS or portable-monitor
  products. Look for one with a matte finish; glossy is unreadable in a hallway with any light.
- **Size honestly.** 24" in a hallway is large. Consider standing in the hallway and taping out
  15", 19", and 24" rectangles on the wall before buying. This is free and prevents an expensive
  regret.
- **Don't put Home Assistant on the wall computer.** Keep the brain in the closet. If the panel
  computer is also your smart home server, then pulling the panel out of the wall to fix something
  takes the whole house down.

---

## 7. Cameras — Ring is the weak link

Honest assessment: **Ring is the worst-supported major camera brand for what you're building.**

Ring cameras have no local video access at all. Everything goes through Amazon's cloud, and Home
Assistant can only integrate by pretending to be the Ring app. Access tokens expire, Amazon has
been shortening that window, and the integration broke outright for many users in July 2026. You'd
also be keeping an Amazon dependency in a project whose whole premise is leaving Amazon.

Since you're open to switching, there's a real fork here, and it depends on who's watching:

**Option A — Local cameras (Reolink PoE).** Cameras that stream directly to your own network with
no cloud and no subscription. Reolink is officially certified to work with Home Assistant and their
PoE line runs fully locally. Best possible experience on the wall panel: fast, reliable, no monthly
fee, and you can add local recording later. These also get published to Apple Home through Home
Assistant's bridge, so they appear on everyone's iPhone too.

**Option B — Apple-first cameras (Aqara with HomeKit Secure Video).** Excellent experience inside
the Apple Home app on everyone's phones, encrypted end-to-end, footage stored in iCloud.
**Important catch:** HomeKit Secure Video streams are encrypted in a way Home Assistant cannot
read. Cameras set up this way work beautifully on iPhones and are largely invisible to your wall
panel — the opposite of what you want.

**Recommendation: Option A.** Local cameras give you both — great on the panel, and still visible
in Apple Home via the bridge. Option B gives you one and blocks the other.

This does not need deciding now. Your Rings will keep working in the Ring app regardless.

---

## 8. Recipes — do not build this

Taylor's recipes are a solved problem, and building a recipe app from scratch would be the single
biggest waste of effort in this project.

**Use Mealie.** It's free, self-hosted, and runs on the same brain computer. What it does:

- Stores unlimited recipes with photos, on your hardware. Storage is a non-issue on a mini PC.
- **Imports a recipe by pasting a URL.** It scrapes the site and strips the life story before the
  ingredients. This alone will sell Taylor on it.
- Has a built-in **weekly meal planner**.
- Generates a shopping list from the meal plan.
- Has a clean mobile interface, so Taylor uses it from her phone, not just the wall.
- Displays on the wall panel — either embedded in the dashboard or as a full-screen button.

"Recipes at the click of a button" is a solved requirement: a button on the dashboard opens Mealie
full screen on the panel.

**On linking to your weekly menu note:** this is where I have to be straight with you. Apple Notes
has no API — nothing can read from or write to it programmatically. So a literal link between
Mealie and an Apple Note isn't possible.

Mealie's meal planner would *replace* the menu note rather than sync with it. That's a Taylor
decision, not a technical one, and it should be presented to her as an option rather than a
migration. Her systems work. If she'd rather keep the note, the panel can simply show the Mealie
recipe library and she keeps planning where she plans.

---

## 9. What the process actually looks like

Five phases. Each one ends with something working. Do not start phase 3 before phase 2 works.

**Phase 1 — Get the brain running (a weekend)**
Buy the mini PC. Install Home Assistant OS. Connect it to your network. Add your Kasa plugs and
Rokus — these are mostly automatic; Home Assistant will find them and ask for a password. At the
end of this you have a working, if ugly, dashboard in a browser on your laptop, controlling your
real lights.

*This is the phase that proves the whole thing works. It's also mostly clicking.*

**Phase 2 — Add the services (a few evenings)**
Install Mealie. Connect iCloud Calendar via app-specific password, and Reminders through the
household secondary account (see `CLAUDE.md` for why the primary account can't). Get Taylor's
recipes imported. Nothing touches a wall yet.

**Phase 3 — Build the dashboard (this is the fun part, and it's open-ended)**
Design the actual panel layout. Cards, colors, typography, what's visible at a glance versus one
tap away. Do this on a laptop, at full panel size in a browser window. This is where you and Claude
Code do real work together, and where the thing starts feeling like yours.

**Phase 4 — Physical install (a weekend, plus shopping)**
Buy the monitor and panel computer. Test-fit everything on a table, running for a full day. Then
cut the wall, run ventilation, mount, and wire it.

**Phase 5 — Voice migration (whenever the new HomePod ships)**
Turn on Home Assistant's Apple Home bridge so Siri can see everything. Buy one HomePod mini. Live
with it. Then decide about the other three.

---

## 10. What this will roughly cost

Prices are unusually volatile right now, so treat these as ranges, not quotes.

| Item | Rough cost |
| --- | --- |
| Mini PC (brain) | $150–250 |
| Touchscreen monitor, 15–24" | $150–400 |
| Mini PC (panel) | $120–200 |
| Presence sensor, mount, cabling, vents | $100–150 |
| **Core project subtotal** | **~$550–1000** |
| HomePod minis, 3–4, later | $400–550 |
| Local cameras, if you switch, later | $60–120 each |

Software is free. There are no subscriptions anywhere in this stack.

---

## 11. What can actually go wrong

- **You stall in phase 3 forever.** The dashboard is infinitely tweakable. Set a "good enough,
  mount it" bar in advance.
- **The fans turn out to be annoying.** Two devices. Worst case they stay dumb, or you add a
  bridge later.
- **Taylor doesn't like it.** The real risk in the whole project. She should see phase 3 on a
  laptop and have opinions *before* anything gets mounted.
- **You over-buy early.** Don't buy the monitor, the mini PCs, the cameras, and the HomePods at
  once. Buy the brain first. If phase 1 bores you rather than delights you, you've spent $200
  finding that out instead of $1500.

---

## 12. The only decision you need to make right now

**Buy one N100-class mini PC and get Home Assistant running on it.**

Nothing else is urgent. Not the monitor, not the cameras, not the HomePods, not the fans. Phase 1
costs a couple hundred dollars and one weekend, and it tells you whether you enjoy this enough to
do the rest.
