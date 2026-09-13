# Home Assistant Dashboard Cookbook

A task-oriented reference. Ctrl+F for what you're trying to do.

The official docs at **home-assistant.io/dashboards** are the authority for every option on every
card. This document exists to bridge the gap between "I want the screen to do X" and knowing what
X is called so you can look it up.

---

## Part 1 — Vocabulary

You can't search for something you can't name. Learn these eight words and the official docs
become usable.

| Term | What it means |
| --- | --- |
| **Entity** | One controllable or readable thing. A single bulb. A single sensor reading. Not a device — one physical device often creates several entities. |
| **entity_id** | An entity's address, always `domain.name`, e.g. `light.kitchen_lights`. This is what you type in YAML. |
| **Domain** | The prefix before the dot. `light`, `switch`, `sensor`, `climate`, `todo`, `calendar`, `media_player`, `binary_sensor`, `cover`, `lock`, `fan`, `camera`, `person`. Domain determines what a thing can do. |
| **State** | What an entity currently is. `on`, `off`, `72.4`, `home`, `playing`. |
| **Attribute** | Extra data hanging off an entity. A light's `brightness`, a climate's `current_temperature`, a media player's `media_title`. |
| **Card** | One visual block on screen. |
| **View** | One page/tab within a dashboard. Switching views is instant. |
| **Dashboard** | A collection of views with its own URL. You want *one* wall dashboard with *many* views. |

**Service / Action** — a thing you can tell Home Assistant to do: `light.turn_on`,
`todo.add_item`, `media_player.volume_set`. Newer versions call these "actions."

---

## Part 2 — Where everything lives

**Raw configuration editor** — the YAML for an entire dashboard.
Open dashboard → pencil (edit mode) → three-dot menu top right → Raw configuration editor.
This is where you paste anything from this document.

**Single card YAML** — edit one card without touching the rest.
Edit mode → click a card → "Show code editor" at the bottom of the dialog.

**Developer Tools → States** — every entity you have, with current state and all attributes.
This is your lookup table. When a card says "Entity not found," come here and find the real name.

**Developer Tools → Template** — a live sandbox for testing template code before putting it in a
card. Type on the left, see the result instantly on the right. Invaluable once you start
templating.

**Developer Tools → Actions** — run any service by hand to see what it does.

**Settings → Devices & Services → Entities** — rename entities, change their icons, hide them.

---

## Part 3 — YAML survival guide

YAML is whitespace-significant. Almost every error you'll hit is indentation.

- **Spaces only, never tabs.** A tab will break the file with a confusing error.
- **Two spaces per level.** Be consistent.
- A `-` starts a list item. Everything belonging to that item lines up under the letter after
  the dash, not under the dash.
- `key: value` for single values, `key:` on its own line for nested blocks.

```yaml
cards:                        # a list called "cards"
  - type: tile                # first item — note the dash
    entity: light.kitchen     # belongs to that item, aligned with "type"
    features:                 # a nested list inside this item
      - type: light-brightness
  - type: tile                # second item
    entity: light.porch
```

If the editor won't let you save, it's telling you the line number. Look one line above it too —
YAML errors often report late.

---

## Part 4 — Card catalog

The built-in cards worth knowing. Full option lists are in the official docs under each name.

**tile** — the modern default. Icon, name, state, optional inline controls. Use this for most
things.

**heading** — a text header inside a section. Can also hold small entity readouts on the right.

**entities** — a compact vertical list of many entities. Dense, less pretty, great for a
"everything in the garage" view.

**thermostat** — the round climate dial.

**light** — a big brightness dial for one light. Tile with a brightness feature is usually better.

**todo-list** — a checkable list. Works with local lists and any CalDAV to-do list. iCloud Reminders only reach CalDAV from a *secondary* iCloud account — see `CLAUDE.md`, Apple integration.

**calendar** — month/day/list agenda view.

**picture-elements** — an image with controls positioned on top of it. This is how people build
floorplan dashboards.

**markdown** — free text, and it accepts templates. Your escape hatch for anything the other
cards can't display.

**conditional** — wraps another card and only shows it when a condition is met.

**vertical-stack / horizontal-stack** — glue several cards into one block.

**grid** — arranges cards in columns. `square: false` is almost always what you want.

**gauge** — a dial for a numeric sensor.

**history-graph / statistics-graph** — plots over time.

**area** — auto-generates a card for everything in a room. Good for a quick start, less good for
a designed layout.

**iframe** — embeds any web page. This is how Mealie ends up on the wall panel.

---

## Part 5 — Cookbook

### Make a card navigate to another view when tapped

```yaml
- type: tile
  entity: calendar.family
  tap_action:
    action: navigate
    navigation_path: /wall/calendars
```

`/wall` is the dashboard URL, `/calendars` is the view's `path:`. Set a view's path in its
settings, or in YAML with `path: calendars`.

### All the tap actions

Any card supporting `tap_action` also supports `hold_action` and `double_tap_action`.

```yaml
tap_action:
  action: toggle              # flip a switch or light
  action: more-info           # open the detail dialog
  action: navigate            # go to a view (needs navigation_path)
  action: url                 # open an external site (needs url_path)
  action: perform-action      # run any service (see below)
  action: none                # make it non-interactive
```

Running a service on tap:

```yaml
tap_action:
  action: perform-action
  perform_action: light.turn_on
  target:
    entity_id: light.kitchen_lights
  data:
    brightness_pct: 40
```

### Add controls directly onto a tile

```yaml
- type: tile
  entity: light.kitchen_lights
  features:
    - type: light-brightness
    - type: light-color-temp
```

Other useful features by domain: `fan-speed`, `cover-open-close`, `cover-position`,
`climate-hvac-modes`, `target-temperature`, `media-player-volume-slider`, `lock-commands`,
`todo-list-items`.

### Show a card only sometimes

```yaml
- type: conditional
  conditions:
    - condition: state
      entity: binary_sensor.front_door_motion
      state: "on"
  card:
    type: picture-entity
    entity: camera.front_door
```

Other condition types: `numeric_state` (above/below), `screen` (breakpoint — useful for making a
layout behave differently on the wall panel vs a phone), `user`, and `and`/`or` for combining.

### Change a card's name or icon

```yaml
- type: tile
  entity: light.bed_light
  name: Nightstand
  icon: mdi:lamp
```

Icon names come from **pictogrammers.com/library/mdi** — search there, prefix with `mdi:`.

To change it everywhere instead of on one card, rename the entity itself in
Settings → Devices & Services → Entities.

### Color a tile by state

```yaml
- type: tile
  entity: lock.front_door
  color: red
```

Named colors: red, orange, yellow, green, teal, blue, indigo, purple, pink, grey, and more.
Colors only apply when the entity is "active."

### Display arbitrary text or computed values

The markdown card accepts templates:

```yaml
- type: markdown
  content: >
    It is currently {{ states('sensor.outside_temperature') }}°F outside.
    {% if is_state('binary_sensor.garage_door', 'on') %}
    **The garage is open.**
    {% endif %}
```

Test template code in Developer Tools → Template before pasting it into a card.

### Merge several calendars into one agenda

```yaml
- type: calendar
  view: list
  entities:
    - calendar.family
    - calendar.steven_work
    - calendar.taylor_work
```

`view:` accepts `list`, `dayGridDay`, `dayGridWeek`, `dayGridMonth`.

### Put a website on the dashboard

```yaml
- type: iframe
  url: http://homeassistant.local:8080
  aspect_ratio: 100%
```

Some sites refuse to be embedded — that's the site's decision, not something you can override.

### Add badges to the top of a view

Badges are the small pills across the top of a sections view.

```yaml
views:
  - title: Home
    type: sections
    badges:
      - type: entity
        entity: sensor.outside_temperature
      - type: entity
        entity: person.taylor
    sections:
      - ...
```

### Hide the sidebar and header for a wall panel

```yaml
views:
  - title: Wall
    subview: true
```

For a true kiosk look you'll want the `kiosk-mode` custom plugin from HACS, which strips the
header and sidebar entirely.

### Stack cards together

```yaml
- type: vertical-stack
  cards:
    - type: heading
      heading: Front door
    - type: picture-entity
      entity: camera.front_door
    - type: tile
      entity: lock.front_door
```

---

## Part 6 — Beyond the built-ins: HACS

**HACS** (Home Assistant Community Store) installs community-built cards. It's the single biggest
unlock and everything below requires it.

The ones that matter:

- **Mushroom** — clean, minimal, consistent card set. The most common answer to "how do I make it
  look good."
- **Bubble Card** — phone-app aesthetic with slide-up popups.
- **card-mod** — inject arbitrary CSS into any card, built-in or custom. This is what takes a
  dashboard from "Home Assistant" to "designed product."
- **kiosk-mode** — strips header and sidebar for wall panels.
- **auto-entities** — build card contents dynamically from a filter instead of listing entities
  by hand.
- **browser-mod** — control the browser from Home Assistant: popups, navigation, screen wake.
  Essential for wall panels.
- **button-card** — fully templatable custom button. Where you go when tile cards run out.

### Writing your own card

Custom cards are plain JavaScript. Drop a `.js` file in `/config/www/`, register it as a
dashboard resource, and reference it with `type: custom:your-card`. Full DOM access, no framework
required. Given your background, this is where you'll end up for hero elements.

---

## Part 7 — Automations

Dashboards display and control. **Automations** make things happen on their own — this is the
"when the doorbell rings, switch the panel to the camera" half.

Settings → Automations & Scenes → Create Automation. Every automation is three parts:

- **Trigger** — what starts it. A state change, a time, a device action, a webhook.
- **Condition** — optional gate. Only run if it's after sunset, only if someone's home.
- **Action** — what happens. Turn something on, navigate the panel, send a notification.

Build them in the visual editor first, then use the three-dot menu → "Edit in YAML" to see what
you built. That's the fastest way to learn the syntax.

---

## Part 8 — Troubleshooting

**"Entity not found"** — the entity_id is wrong. Developer Tools → States, search for it, copy
the exact name. They're case-sensitive and use underscores, never spaces.

**Card won't save / YAML error** — indentation. Check the reported line and the one above it.
Confirm you have no tabs.

**Custom card shows "Custom element doesn't exist"** — the resource didn't load. Hard refresh
with Ctrl+Shift+R. If it persists, check Settings → Dashboards → three-dot → Resources.

**Changes don't appear** — hard refresh. The frontend caches aggressively.

**Layout looks different on another screen** — sections views reflow by viewport width. Use
`max_columns`, or switch the view to `type: masonry` for fixed columns.

**Everything broke after an edit** — the raw configuration editor has undo (Ctrl+Z) while open.
Once closed, restore from Settings → System → Backups.

---

## Part 9 — Finding answers on your own

1. **Developer Tools → States** answers "what is this thing called."
2. **home-assistant.io/dashboards** — pick the card name, read its options table. Now that you
   know the vocabulary, this is fast.
3. **community.home-assistant.io** — search your exact error message. Someone has hit it.
4. **r/homeassistant** — better for "how do people usually do X" than for errors.
5. YouTube: Everything Smart Home, Smart Home Junkie, BeardedTinker. Good for seeing what's
   possible before you know what to search for.

The single best habit: when you see a dashboard you like online, ask for its YAML. The community
shares it freely, and reading someone else's config teaches faster than any tutorial.
