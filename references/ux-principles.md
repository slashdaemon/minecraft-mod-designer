# UX principles — interaction conventions, HUD, information architecture

Taste and judgment, not API. Rules with reasons. Facts are cited where they're factual;
judgment calls are marked **[opinion]**.

---

## 0. The one-paragraph thesis

Minecraft's UI is a **18px-slot-grid, 1× pixel-art, low-chroma, slot-based visual language** whose job
is to disappear so the world stays the subject. A mod UI is good when a player who has never seen it
can predict what a click does *before* clicking — at GUI Scale 1 and 4, in German, on a Steam Deck,
with a snow biome glaring behind it. Nearly every mod-UI failure is one of four things: **it fights
the grid** (HD textures, gradients, rounded corners), **it fights the scale** (hardcoded pixel
layouts), **it fights the player's attention** (HUD clutter, 40 undifferentiated slots), or **it
fights the conventions** (nonstandard shift-click, stolen keybinds, no `E`-to-close).

---

## 1. Inventory / slot semantics — contracts you inherit

Players execute these without looking. Breaking one is worse than having no UI.

| Input | Vanilla meaning | Your obligation |
|---|---|---|
| Left click | pick up / place whole stack | never repurpose on a real item slot |
| Right click | split stack in half (odd → smaller half left behind); or place **one** from held | never repurpose |
| **Shift + click** | quick-move to "the other" inventory | implement `quickMoveStack` correctly — see below |
| Left-drag across slots | distribute held stack **equally** | free if your slots are real `Slot`s |
| Right-drag across slots | place **one** per dragged slot | free |
| Double click | gather up to a full stack from the whole inventory | free |
| Number keys 1–9 | swap hovered slot with that hotbar slot | free |
| `F` | swap hovered slot with off-hand | free |
| `Q` / `Ctrl+Q` | drop one / drop whole stack | free |
| Middle click | clone full stack (creative) | don't repurpose in survival either — muscle memory |
| **Scroll over a slot** | *nothing* in vanilla — but **Mouse Tweaks** makes it move items one at a time, and it is near-universal in packs | **never bind scroll-over-slot to a mod action** — you will collide with the most-installed inventory QoL mod |

### Keyboard slot contracts (26.4 snapshot-7+, ★★★ javap + patch notes — snapshot, subject to change)

26.4 makes every container screen keyboard-operable. Every slot is a focusable `SlotWidget` (18×18,
1 px border) and slots are grouped into tab-order **sections** by the new `Slot.Section` constructor
argument (`EQUIPMENT, CONTAINER, INPUT, SECOND_INPUT, FUEL, RESULT, INVENTORY, HOTBAR`).

| Input | Vanilla meaning (26.4) | Your obligation |
|---|---|---|
| `Tab` / `Shift+Tab` | move between slot groups, in `*_TAB_GROUP` order (equipment 1 → hotbar 10) | give every `Slot` the honest `Slot.Section`; a mod "input" slot tagged `CONTAINER` lands in the wrong tab stop |
| Arrow keys | move within a group (grid-aware) | lay slots out on the 18 px grid so arrow geometry matches what players see |
| `Enter` / `Space` | left-click the focused slot | free for real `Slot`s |
| `Ctrl` + `Enter`/`Space` | right-click | free |
| `Shift` + `Enter`/`Space` | shift-click (`quickMoveStack`) | the `quickMoveStack` rule below applies unchanged |
| double press within 250 ms | collect (double-click gather) | free |
| arrow while holding the select key | spread (drag-distribute) | free |
| hotbar / drop keys | act on the focused slot | free |

Custom widgets inside a container screen (mode buttons, tabs, scroll lists) must be real focusable
`AbstractWidget`s, or the keyboard user's Tab cycle skips them. Screens whose visible slot set changes
(tabs, recipe book) override/call `updateSlotWidgets()`. The cursor hides while navigating by
keyboard — don't draw hover-only affordances; draw from `isHighlighted()`.

### The `quickMoveStack` rule

The #1 crash/hang source in modded container screens. Requirements:

1. It **must return `ItemStack.EMPTY` when nothing moved**, or the client loops forever.
2. It must respect `Slot#mayPlace` on the destination.
3. Shift-clicking an upgrade must land in the *upgrade* slot, not slot 0.

**Write a test that shift-clicks every slot type in both directions.** A shift-click that silently
does nothing is a bug report you will receive 200 times.

### Ghost slots (filters, previews)

A ghost slot holds a *rendered* item that isn't really there.

- **Render at reduced alpha (~50%)** so it is visibly not a real item. Never render a ghost at full
  opacity — players will shift-click it and be confused. **[opinion, but universal in practice]**
- Left click with a held stack = set the filter, **without consuming it**. Left click empty = clear.
  Right click = commonly cycles count/NBT-match mode.
- **Support drag-in from JEI/EMI.** A ghost slot that doesn't accept a JEI drag reads as broken.
- If your crafting area is ghost slots or storage-backed, implement **`IRecipeTransferHandler`** —
  without it JEI's `[+]` button is dead and players assume you're JEI-incompatible.

### Scroll-to-adjust

Legitimate on a *value widget* (Create's scrollable value boxes are canonical), **never on a slot**.
Requirements: shift = coarse step, ctrl = fine step, live value shown as text, clamped with a visible
min/max so scrolling never silently saturates.

### Cycle button vs list

Vanilla uses cycle buttons throughout Options for good reasons: one click switches, no popup, no
focus trap, clean narration. The cost is many clicks for many values.

**≤4 values → cycle button. 5–12 → cycle button with right-click to go backwards. >12 → a scrollable
list with a search field, never a floating dropdown.** Floating dropdowns are the worst option in
Minecraft specifically: they overflow the 176px panel, clip at the screen edge, and break controller
focus order. **[opinion]**

---

## 2. Machine / config screen patterns

### Side configuration

Mekanism is the reference implementation and worth copying wholesale: a **fixed upper-left** button
opens side config; inside, one button per relative side (Top/Bottom/Front/Back/Left/Right) shows the
assigned data type **and its color**; clicking cycles; there's an auto-eject toggle and an
"apply to all sides" with shift-click to clear. Transmission types (energy / fluid / gas) are **tabs**,
not a mode dropdown.

Two transferable rules:

1. **Side config must be relative to the block's facing** — Front/Back/Left/Right, not north/south.
   Absolute compass directions force mental rotation at the machine.
2. **Color-coding sides is only acceptable because the type name is shown too.** Color alone fails
   colorblind players (see `accessibility.md`).

### Tabs

Vanilla's idiom is the creative-inventory strip: tabs sit *outside* the panel edge, the active tab is
visually attached to the panel, inactive tabs are pushed back. **Keep tabs ≤6** — past that you need
a scroll or a second row, and both are worse than splitting the machine. **[opinion]**

### Upgrade slots

Put them in a visually distinct, separated cluster. Give each a **background sprite** hinting what
goes there. An empty unlabeled slot next to 27 storage slots teaches the player nothing.

### Energy / fluid / gas bars

- Vertical bar on the right edge for energy; vertical for fluids/gas. Bars fill **bottom-up**;
  progress arrows fill **left-to-right in the direction of item flow**.
- **The tooltip must show absolute value, unit, and capacity**: `12,400 / 100,000 FE`. A bare
  percentage is useless for debugging a base; a bare absolute is useless for reading fullness at a
  glance. Show both.
- **Never encode a fault state as bar color alone.** "Bar turns red = no power" fails colorblind
  players *and* is invisible when the bar is empty anyway. Use an explicit message (§5).

### Progress arrows

The vanilla furnace arrow is the template: a dark track sprite plus a bright fill sprite clipped to
`progress/total` width. Two rules: **clip in integer pixels** (a sub-pixel-clipped arrow shimmers),
and **animate against the right clock** (§6).

---

## 3. Search, filter, keyboard

### JEI's search grammar is the lingua franca — adopt it verbatim

In any item-list UI you build (storage terminals, backpack search, pickers):

| Token | Means | Default mode |
|---|---|---|
| `@mod` | mod name | `REQUIRE_PREFIX` |
| `#text` | tooltip text | `ENABLED` (no prefix needed) |
| `$tag` | tag name | `REQUIRE_PREFIX` |
| *space* | AND | — |
| `\|` | OR | — |
| `-term` | exclude | — |
| `"two words"` | phrase | — |

### Reserved keys

**`R` = show recipe, `U` = show uses, `A` = bookmark.** These three are reserved by JEI/EMI/REI —
do not bind a mod action to them that fires while a container screen is open. Also spoken for by
convention: `B` (Sophisticated Backpacks), `M` (Xaero's world map), `J` (JourneyMap), and all of
vanilla's WASD / space / shift / ctrl / E / Q / F / F1–F5 / F11 / T / `/` / Tab / Esc / 1–9.

### `E` and `Esc`

Both must close a container screen; `Esc` must close **any** screen. In a sub-screen (side config,
upgrade detail) `Esc` should go **back one level**, not all the way out, and there must be a visible
Back affordance. In a *linear* list, focus should wrap last→first; in a 2D grid it should not.

### Search-field focus

If your screen's primary job is finding an item, focus the search box on open — **but only if `E`
still closes**. A search field that eats `E` and forces two Esc presses is a small, permanent
irritation. Standard resolution: the box is focused, but the inventory-close key still closes the
screen unless the box has text in it. **[opinion]**

### Keyboard-first is not optional

Register controls with `addRenderableWidget` (interactable + narrated + rendered), not
`addRenderableOnly` + a hand-rolled `mouseClicked`. That second pattern is **the most common way mod
screens become mouse-only** — it silently removes the control from Tab order, from the narrator, and
from every controller mod. Tab order follows registration order; **register in reading order**.
26.4 deletes `addRenderableOnly` outright, and vanilla screens are now fully keyboard-navigable — a
mouse-only mod screen stands out next to them.

### Typing must not trigger hotkeys (26.3+)

Under SDL3, a screen-level hotkey that fires while the player is typing in a search box is a bug
vanilla has a contract for: text widgets return `capturesInput() = true` while focused and the screen
checks `Screen#isInputCaptured()` before acting on single-key shortcuts (vanilla container screens
check it before treating the inventory key as "close"). Gate your own screen hotkeys the same way.

---

## 4. Destructive actions in a game with no undo

An item deleted in your GUI is gone from the save. Vanilla is conservative here — world deletion
demands a typed confirmation — and the community shipped Confirm Disconnect and QuitConfirm because
even *disconnecting* is felt as destructive.

In priority order:

1. **Prefer designs where nothing is destroyed.** A "clear filter" that returns the item beats one
   that deletes it.
2. **Never put a destructive control adjacent to a frequent one.** A "Void contents" button 18px from
   "Sort" *will* be misclicked. Separate by ≥18px, or put it behind a tab.
3. **Confirm only when you cannot make it reversible.** Confirmation dialogs are cheap to add and
   expensive to live with; a confirm on every action trains players to click through them. Reserve
   `ConfirmScreen` for irreversible, high-magnitude, low-frequency actions.
4. **Never require a *hold* as the only confirmation** — holding is a documented motor-accessibility
   barrier. Hold-to-confirm is fine as an accelerator beside a click path.
5. **Voiding upgrades / trash slots must be unmistakable** — distinct sprite, distinct color, distinct
   position, and a tooltip that uses the word "destroyed."
6. **Server-side authority.** Client UI must never be the only guard on a destructive action.

---

## 5. HUD design

### 5.1 The occupied-region map

Coordinates are in GUI units where `W = guiWidth()`, `H = guiHeight()`. **Sprite sizes are verified;
positions marked ⚠ are from the vanilla `Gui` class and should be re-derived against your target
version** — Mojang moved HUD sprites into `gui/sprites` in 1.20.2, refactored HUD layering at 1.21.6,
and split `Gui`/`Hud` at 26.2. Assume drift. On Fabric API for 26.4 the hotbar and spectator menu
draw **after** the status bars (draw-order change; geometry unchanged), and Fabric added an
info-bar HUD element slot (0.165) and status-bar replace/height hooks (0.163) — see `loader-hooks.md`.

| Region | Occupant | Geometry |
|---|---|---|
| Bottom center | **Hotbar** | sprite **182×22**; `x = W/2 − 91`, `y = H − 22` ⚠ |
| Bottom center | Hotbar selection | **24×24**; `x = W/2 − 92 + 20·slot`, `y = H − 23` ⚠ |
| Left of hotbar | Offhand slot | ~29px left of the hotbar origin — **mirrored for left-handed players** ⚠ |
| Above hotbar | **XP bar** | 182×5, `x = W/2 − 91`, `y = H − 32`; level number just above ⚠ |
| Above XP, left half | **Health** | 9×9 hearts, 10/row, ~8px pitch, baseline `y ≈ H − 39`; **grows upward** with absorption ⚠ |
| Above hearts | **Armor** | 9×9 row at `y ≈ H − 49` ⚠ |
| Above XP, right half | **Hunger** | 9×9, right-aligned to `W/2 + 91`, `y ≈ H − 39` ⚠ |
| Above hunger | **Air bubbles** | 9×9, only when air < 300 |
| Above hunger (replaces air) | **Mount health / jump bar** | when riding |
| Top center | **Boss bars** | 182 wide, stacked — **can be many rows deep during a raid** |
| Top right | **Effect icons** | 24×24 tiles; beneficial row first, harmful below |
| Right, centered | **Scoreboard sidebar** | width is content-driven — **unbounded** |
| Bottom left | **Chat** | stacks upward from ~40px above the bottom ⚠ |
| Top left + top right | **F3 debug** | two full text columns |
| Whole screen | vignette, portal/nausea distortion, damage flash |

### 5.2 The safe zones

- **Left edge, vertically centered** (above chat, below the F3 column) — best default for a persistent
  mod HUD.
- **Right edge, upper-middle**, *below* the effect rows — but this fights the scoreboard on servers.
- **Top-left below the F3 column** — free unless F3 is open.
- **Bottom-center is never free.** Neither is top-center (boss bars) or top-right (effects).

### 5.3 Hard rules

1. **Anchor, never absolute.** Compute from a nine-point anchor + offset. A HUD element at literal
   `(1500, 900)` is broken on every window that isn't yours.
2. **Make position user-configurable in-game**, ideally with a drag mode. This is table stakes now —
   Giacomo's HUD Overlays Configurator exists purely because mods don't do it. Jade and The One Probe
   ship configurable position, scale and theme, which is why they're the two everyone tolerates.
3. **Assume other mods took your spot.** Botania ships a configurable height for its mana bar
   specifically because other mods move the XP bar. Expose a Y-offset.
4. **Register relative to a named vanilla layer**, not at an arbitrary depth — `registerAbove`/
   `registerBelow` (NeoForge) or `attachElementBefore`/`After` (Fabric). Above `HOTBAR` vs above
   `CHAT` is a meaningful design decision; make it deliberately. See `loader-hooks.md` §1.

### 5.4 The "does this need to be a HUD element at all?" test

1. **Does it change?** Static text is a tooltip, not a HUD element.
2. **Does the player act on it within ~5 seconds of seeing it?** If not, it belongs in a screen.
3. **Would a sound or a particle carry it better?** Create's goggles convey rotation *direction by
   motion* and *speed by color*, with no numbers on screen.
4. **Could it live on the block?** Jade/TOP already give you a look-at surface — and TOP's
   "probe in hand" mode is the strongest form: *no HUD unless you're holding the tool*.
5. **Would a modpack author disable it?** If yes, it's clutter — ship it **off by default**.

**Hide when irrelevant, and fade rather than pop.** An instant appear at the edge of vision reads as
a threat cue.

### 5.5 Mandatory suppression checks

Return early when:

| Condition | Why |
|---|---|
| **`Options#hideGui` (F1)** | builders and content creators use F1 for screenshots. A mod HUD that survives F1 is a bug report from every one of them. |
| A `Screen` is open | unless your element is *about* the screen |
| The player is sleeping / spectating | most gameplay HUD is meaningless there |
| `Minecraft#player == null` or level is null | title-screen / world-unload crashes |
| Your own "enabled" config is false | **ship an off switch, always** |

> **Fabric trap:** `HudElementRegistry.addFirst`/`addLast` inherit **no** render condition — they draw
> even when the HUD is hidden. `attachElementBefore`/`After` inherit the anchor element's condition
> (every vanilla element except `SLEEP` is F1-gated). If you use `addFirst`/`addLast`, **check F1
> yourself**. ★★★

If your HUD is genuinely wanted in screenshots (a photo-mode readout), give it its own toggle rather
than ignoring `hideGui`.

### 5.6 Contrast over arbitrary worlds

Your HUD is drawn over snow at noon and over the Deep Dark. Neither white nor black works alone.

- **Use the player's setting**: vanilla exposes **Text Background Opacity** (default 50%) and
  **Text Background** (Chat-only vs Everywhere). Read them; don't invent your own alpha.
- **Or outline.** The robust version is a 1px full outline (black *and* white, so the glyph survives
  both backdrops); the cheap version is the standard drop shadow.
- **Measure against the worst case** — for a HUD, "snow biome at noon" for white and "cave at night"
  for black.

---

## 6. Animation and frame pacing

| Animating… | Use | Why |
|---|---|---|
| Something synced to a 20 Hz tick (progress bar backed by a BE field, entity interpolation in a PiP) | `DeltaTracker#getGameTimeDeltaPartialTick(false)` | matches the simulation; correctly freezes when the game freezes |
| **Any UI animation** — hover fades, slide-ins, spinners, scroll easing | **`Util.getMillis()`** | wall clock; framerate-independent, **and it keeps running while the game is paused** — which is exactly when your screen is open |
| Something that must ignore `/tick freeze` | `getGameTimeDeltaPartialTick(true)` | |

**Never drive UI animation from a frame counter** (`ticks++` in `render()`) — it makes animation speed
a function of framerate. This is the single most common UI-smoothness bug in Minecraft mods.

Note a documented NeoForge issue: a `Screen`'s `partialTick` **does not advance while the game is
paused**, so any screen animation driven from it freezes. Another reason UI animation belongs on the
wall clock.

```java
private long animStartMs;                     // set in init(), never in render()

@Override protected void init() {
    this.animStartMs = Util.getMillis();
    // …precompute layout, Font#split results, cached Components here…
}

// in render/extract — no allocation, no Font#split, no new Component
float t = Mth.clamp((Util.getMillis() - animStartMs) / 250f, 0f, 1f);
float eased = t * t * (3f - 2f * t);          // smoothstep
```

Keep UI transitions **≤200 ms** and ship an off switch. **[opinion]**

---

## 7. Information architecture

### 7.1 Where a setting belongs

| Kind of setting | Goes in | Why |
|---|---|---|
| Server-authoritative balance (recipe costs, machine speed, feature on/off) | **config file, server-side, not editable in-game** | must be identical for all clients; pack authors edit it with a text editor |
| Client-only presentation (HUD position, colors, animation, tooltip verbosity) | **in-game config screen** reachable from the mods list | the player must be able to fix a broken HUD without alt-tabbing |
| Per-block behavior (side config, filter, redstone mode, auto-eject) | **a GUI on the block** | per-instance state, and part of the puzzle |
| Per-player preference varying by context (sort order, list stretch) | **in the screen, persisted client-side** | Refined Storage does exactly this |

**Anti-pattern: the 200-flat-option config screen.** Use a config library (see `libraries.md`), give
every option a **one-sentence tooltip**, and name categories with **nouns players use**, not your
package names.

### 7.2 Progressive disclosure

Show the minimum required to take the next action; unlock the next layer when the player has earned
the context. The Minecraft-native ladder, cheapest first:

1. **Default screen shows only** input, output, progress, power. Nothing else.
2. **Advanced controls behind a tab or a toggle button.** AE2's own tracker carries requests to *hide*
   view-cell and upgrade slots by default — a mature mod asking for less.
3. **Side config, filters, redstone modes behind a secondary screen.**
4. **Tuning behind a config file.**

Corollary: **the presence of a control implies it's relevant now.** An upgrade slot that can't accept
anything at tier 1 should be visibly **locked** (lock glyph + tooltip), not present and inert.

### 7.3 Onboarding — four surfaces, ranked by cost/benefit

| Surface | Cost | Good for |
|---|---|---|
| **JEI/EMI/REI integration** | lowest | *every* recipe you add. Documentation with zero writing. |
| **Tooltips** | low | per-item "what is this / what next" |
| **Advancements** | low–medium | sequencing and challenge |
| **Guidebook** (Patchouli / Modonomicon) | medium | reference and explanation; data-driven, and other mods can add entries to your book |
| **Ponder-style animated scenes** | highest | mechanisms you cannot explain in text — rotation, contraption assembly, multiblock formation |

**Copy AE2's pattern for a machine-heavy mod:** most of its UIs carry a **help button that opens the
guide page for *that screen***. That is the highest-value 16×16 pixels in the entire mod — it turns
"I'm stuck in this screen" into "I'm reading about this screen" in one click, and it puts the
documentation at the point of confusion instead of behind a wiki tab.

### 7.4 Error and empty states

Every one is a free teaching moment, and most mods waste it by rendering nothing.

| State | Bad | Good |
|---|---|---|
| No recipe matches | blank output slot, no feedback | grayed output + `No recipe for these inputs` |
| Not enough power | frozen progress arrow | **`Needs 240 FE (has 0)`** — say the number and the gap |
| Missing upgrade | inert control | locked slot + lock glyph + `Requires a Speed Upgrade` |
| Output full | frozen progress | `Output blocked` |
| Empty inventory / list | blank void | one line of centered gray text: what would appear here, and how to get it |
| Search returns nothing | blank grid | `No items match "diamond ore"` + a hint if a filter is active |
| Wrong-side connection | nothing | highlight the side in side-config with the reason |

**Three rules:** state the **cause**, not the symptom; state the **remedy**; state the **number** when
there is one. "Not enough energy" is a symptom. "Needs 240 FE, has 0 — connect a generator" is a
diagnosis.

### 7.5 Tooltips are the primary teaching surface

- **Structure:** line 1 = item name (given). Line 2 = one sentence on *what it does*. Blank line. Live
  state (durability, stored energy, filter contents). Last: `Hold Shift for details`.
- **Never dump NBT.** Format it.
- **Never let a tooltip exceed the screen.** This is a real and constant bug — vanilla clamps the
  *bottom* to the screen edge, which means the player reads the *less important* bottom of a long
  tooltip. **Wrap at a max width (½–¾ screen width is the community norm) and clamp so the TOP stays
  visible.**
- **Everything in a tooltip comes from a lang key.** The existence of *Localizator* — a mod whose
  entire job is retrofitting lang keys onto mods that hardcoded English — is the indictment.
- Cap line length at **~35–45 characters**. Long measure is the biggest legibility lever you have and
  it costs nothing.

### 7.6 Microcopy in Minecraft's voice

Plain, concrete, second-person, slightly dry, occasionally punning, never corporate and never epic.
Advancement copy is the reference sample: names read as actions, descriptions are literal one-liners.

**Do:** `Place the drill on bedrock.` · `Needs redstone power.` · `This chest is full.`
Name things after what they do. Sentence case. No trailing periods on labels; periods on sentences.
One joke per ten strings, max, and **never in an error message**.

**Don't:** `ERROR: INVALID_RECIPE_STATE` (jargon leaking from your code) · `Uh oh! Something went
wrong! :(` (cute and useless) · `The Aetheric Resonator requires attunement to a Ley Node of matching
valence.` (lore where instructions belong — lore goes in the guidebook) · `You forgot to…` (scolding).

---

## 8. Failure modes — the smells list

| # | Smell | Fix |
|---|---|---|
| 1 | HD / upscaled GUI textures | author at 1×; add pixels of *shape*, not resolution |
| 2 | Gradients, soft shadows, rounded corners | flat tones, 1px bevels, square corners |
| 3 | **Text baked into a background PNG** | untranslatable, un-narratable, uncontrollable contrast. Draw all text as `Component`s at runtime |
| 4 | Fixed pixel layouts (hardcoded 1920×1080, `W/2 + 400`) | anchor + offset; recompute in `init()`; run the scale matrix |
| 5 | Panel wider than ~180 GUI units with no stretch/scroll | doesn't fit at GUI Scale 4. Scroll, paginate, or stretch-with-cap |
| 6 | Unlocalized hardcoded English | `Component.translatable` + complete `en_us.json` |
| 7 | Text overflow off the panel | measure with `Font#width`; truncate with `…` **and** a tooltip carrying the full string |
| 8 | Tooltips clipped off-screen | wrap at max width; clamp so the **top** stays visible |
| 9 | Low-contrast text (white-shadowed on `#C6C6C6`) | `0xFF404040` flat on panels, `0xFFFFFFFF` shadowed over the world |
| 10 | A 40-slot undifferentiated wall | group with 4–6px gutters; per-role slot background sprites; a separating bevel |
| 11 | HUD clutter | §5.4 test; off by default; configurable position; fade when static |
| 12 | Wrong `isPauseScreen` | container screens **don't** pause (match vanilla chests); full-screen menus/guidebooks **do**. Decide deliberately and document it |
| 13 | Stolen keybinds | default to **unbound**, or use a conflict context so your key only fires in your context |
| 14 | 200 flat config options, no categories/search/tooltips | use a config library; categorize; one sentence per option |
| 15 | Mouse-only screens | `addRenderableWidget`; test with the mouse unplugged |
| 16 | Animations on raw tick count | `Util.getMillis()` for UI, partial tick for simulation |
| 17 | Unicode glyphs as icons (`⚡`, `❤`, `⛏`) | narrates as "high voltage sign"; renders differently under Force Unicode. Use sprites + labels |
| 18 | Color-only state encoding | add shape/icon/text |
| 19 | **Recipe-viewer collision** | declare exclusion zones to JEI/REI/EMI; test with all three installed |
| 20 | No `IRecipeTransferHandler` for a ghost-slot crafting area | the `[+]` button silently does nothing |
| 21 | HUD survives F1 | check `hideGui` |
| 22 | Icon buttons with no tooltip and no label | a 16×16 wrench means nothing to a new player |
| 23 | Screen state lost on window resize | `init()` re-runs on resize — persist scroll position, search text, active tab |
| 24 | Destructive action beside a frequent one | separate or gate |
| 25 | Guide text unreadable at the player's GUI scale | per-screen text-scale option on dense reading surfaces |

---

## 9. Case studies

**Create — the branded-but-native benchmark.** A brass/copper panel language that follows every
vanilla grammar rule while being instantly recognizable — coherent enough that fans ship packs
converting *vanilla* to it. **Ponder** is the strongest onboarding surface in modded Minecraft: an
animated in-world scene, built explicitly as "an in-game alternative to external wikis and lengthy
tooltips." Engineer's Goggles are contextual, diegetic, opt-in information.
*Weaknesses:* Ponder scenes are tightly coupled to the blocks they depict, so they rot when blocks
change; goggle overlays are on-or-off with no position control; speed/stress coding leans on hue.
**Lesson:** branding is legitimate when built on vanilla grammar — and the best documentation is the
kind you can't skip because it's attached to the item.

**AE2 vs Refined Storage — same problem, two philosophies.** AE2 has an in-game guide since 1.20 with
a **help button in most UIs**, and terminals inherit the color of the cable they attach to. But the
terminal **does not grow at GUI Scale 4** — filed as an accessibility complaint, with RS cited as
prior art — and its tracker carries a long queue of clutter complaints. RS stretches the Grid to fill
vertical space with a `maxRowsStretch` cap, **suppresses sorting while SHIFT is held** so items don't
jump under your cursor mid-transfer, and persists size preferences per player client-side.
**Lesson:** when two mods do the same job, the one that adapts to the player's screen wins the UX
argument regardless of who has the better simulation. *"Don't re-sort under the user's cursor"* is
worth stealing outright.

**Mekanism — config-heavy done right.** One consistent chrome across dozens of machines. Side config
always upper-left. Sides labeled relative to the block. Transmission types as tabs. Energy always a
vertical right-hand meter. An "apply to all sides" accelerator that doesn't hide the basic path.
*Weakness:* density — a fully-upgraded machine has side config, upgrades, energy, redstone mode,
auto-eject and factory sorting all competing.
**Lesson:** **consistency across your own screens is worth more than optimizing any one of them.**
A player who learns one Mekanism machine has learned all of them — the highest-value property a mod
UI can have.

**JEI / EMI / REI — the accidental standards body.** JEI's search grammar is now a *literacy* players
carry between mods; R/U/A are muscle memory. EMI adds recipe *trees*, tag-aware display ("Planks"
instead of cycling every plank), and crafting from favorites.
*Weakness:* they eat screen space aggressively enough that Distraction Free Recipes exists to hide
the item list until you search.
**Lesson:** adopt the ecosystem's conventions rather than inventing yours — and declare your exclusion
zones so the viewer can get out of your way.

**Botania & Immersive Engineering — the diegetic school.** Botania has essentially no GUIs; mana beams
visibly arc between spreaders and pools. The Lexica Botania was good enough that Patchouli's feature
set was derived from what people liked about it. IE puts hanging powerlines and a 5×3×3 crusher in the
world instead of a black-box block.
*Weaknesses:* Botania's mana HUD still needed a configurable Y offset because other mods move the XP
bar — the diegetic school can't escape HUD collision. IE's manual drew an unreadability complaint:
too small at normal GUI scale, Auto overcorrects, no per-screen option.
**Lesson:** diegetic UI is the most native answer for **relationships and flow**. It does not exempt
you from HUD-collision config or from text legibility on your reading surfaces.

**Jade / The One Probe — the well-behaved HUD.** Every plugin module has an individual toggle;
position, scale and theme are adjustable. TOP's probe-in-hand mode is the purest "hide when
irrelevant."
**Lesson:** per-module toggles + position/scale config are what make a HUD mod installable in a
200-mod pack. Build them from day one; retrofitting is painful.

**Sophisticated Backpacks — the configurable container.** Distinct upgrade-slot column; per-tier slot
counts configurable so pack authors can rebalance; sorting with slot memory; main+accent color
customization so players tell backpacks apart at a glance.
*Weakness:* its custom sorting collides with Inventory Profiles Next, the most-installed sorter.
**Lesson:** if you implement a behavior a ubiquitous QoL mod already owns (sorting, scroll-transfer,
drag-transfer), either integrate with it or make yours **disableable**. Owning the interaction is not
the same as owning the player.

**Iron Chests — the slot-wall problem.** A Diamond Chest is 108 undifferentiated slots: no hierarchy,
no search, no grouping. Successors (Upgraded Iron Chests) added a **search box inside the chest GUI**
and a **compact button** that removes empty slots and floats items to the top.
**Lesson:** **past roughly 54 slots, capacity stops being a UI feature and becomes a UI problem.** The
fix is not scrolling — it's search plus compaction. Any container above one double-chest needs a
search field.

---

## 10. Numbers to design against

| Thing | Value |
|---|---|
| Default container screen | 176 × 166 GUI units |
| Slot cell / item / pitch | 18×18 / 16×16 / 18 |
| Font glyph / line height | 8×8 variable-width, ascent 7 / **9 px** |
| Text shadow offset | 1px SE, RGB ÷ 4 |
| Force-Unicode glyph | 16×16, half-pixel advances |
| Hotbar sprite | 182 × 22 |
| Hotbar selection | 24 × 24 |
| Heart / armor / food / air icon | 9 × 9 |
| Effect icon tile | 24 × 24 |
| Button heights | 20, always |
| Canonical button widths | 120 / 150 / 200 / 310 |
| Vertical gap between stacked controls | 4 |
| Horizontal gutter between paired buttons | 8–10 |
| Contrast: standard text / large / high-contrast mode | ≥4.5:1 / ≥3:1 / ≥7:1 |
| Tooltip max width (community norm) | ½–¾ screen width |
| Tooltip line length | 35–45 chars **[opinion]** |
| Container size past which you need search | ~54 slots **[opinion]** |
| Max tabs before splitting the screen | 6 **[opinion]** |
| Max values before a cycle button becomes a list | ~12 **[opinion]** |
| UI transition duration | ≤200 ms **[opinion]** |

---

## 11. Unverified

- **Exact screen-space HUD coordinates** (§5.1, rows marked ⚠). The wiki documents which elements
  exist and their sprite sizes, not their draw positions. Re-derive from `net.minecraft.client.gui.Gui`
  (or `Hud` on 26.2+) for your exact version before shipping a layout that depends on them.
- **26.4 keyboard slot contracts** (§1) are from 26.4-snapshot-7/8 jars and patch notes. Creative
  inventory and the recipe book are not keyboard-navigable yet in those snapshots; behavior can change
  before release.
- **Player-complaint evidence** in §8 and §9 is drawn from mod pages, issue trackers, and the existence
  of fix-mods (ToolTipFix, Adaptive Tooltips, Distraction Free Recipes, Auto HUD, Giacomo's HUD
  Configurator, Localizator, Controlling, Config Search), not from direct forum threads. Each fix-mod
  is a complaint that got compiled — strong circumstantial evidence, not quotes.
- **No first-party Create GUI design writeup exists.** The §9 reading of Create's visual language is
  inferred from its assets and wiki, not from a designer statement.
- **`isPauseScreen` guidance** is inference from vanilla behavior plus Menu Pause's per-screen
  compatibility list, not documented guidance.
- **Minecraft has no "dark mode"** as a distinct option. The closest things are the High Contrast
  built-in pack, Menu Background Blur, and the Text Background settings. Do not design assuming a
  light/dark theme token exists.
