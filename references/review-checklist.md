# Design review rubric

Run this against any mod UI before shipping. Score each item **2 = yes / 1 = partial / 0 = no /
n/a = excluded**. Report as `score / max applicable`.

**Gate items are marked ⛔ — a 0 on any gate item blocks release regardless of total score.**

---

## A. Visual language (max 16)

| # | Criterion | |
|---|---|---|
| A1 | Every GUI texture authored at 1×; no anti-aliasing, no gradients, no rounded corners | |
| A2 | Bevels correct: raised = light top-left / dark bottom-right; recessed = inverted | |
| A3 | Slot pitch is 18px and aligns with the player inventory drawn below | |
| A4 | Panel text is flat `0xFF404040`; text over the world is white with drop shadow | |
| A5 | ⛔ **No text is baked into a background texture** | |
| A6 | ≤1 accent hue, applied consistently across all the mod's screens | |
| A7 | The screen is visually a sibling of the mod's other screens (same chrome, same control positions) | |
| A8 | Vertical rhythm respects the 9px line height; no clipped descenders | |

## B. Layout & scale (max 12)

| # | Criterion | |
|---|---|---|
| B1 | ⛔ Renders correctly at GUI Scale 1, 2, 3 and 4 | |
| B2 | ⛔ Fits a 1280×720 window at GUI Scale 4 (or stretches / scrolls / paginates) | |
| B3 | Correct at 21:9 and 32:9; nothing anchored past the safe zone | |
| B4 | Window resize preserves scroll position, search text and active tab | |
| B5 | All geometry derives from `leftPos`/`topPos` or an anchor+offset — **zero absolute screen coords** | |
| B6 | Correct with **Force Unicode Font** on (measured via `Font#width`, no overflow) | |

## C. Interaction (max 18)

| # | Criterion | |
|---|---|---|
| C1 | ⛔ `quickMoveStack` handles every slot in both directions **and returns `EMPTY` when nothing moved** | |
| C2 | Right-click split, left/right drag-distribute, double-click gather, 1–9, F, Q all behave vanilla | |
| C3 | Ghost slots render at reduced alpha and accept JEI/EMI drag-in | |
| C4 | ⛔ `E` and `Esc` close; `Esc` in a sub-screen goes back one level; a visible Back control exists | |
| C5 | Item-list UIs support JEI search grammar (`@`, `#`, `$`, `-`, `\|`, quotes) | |
| C6 | No keybind collides with vanilla or with **R/U/A/B/M/J**; conflicts use a conflict context | |
| C7 | Every icon-only button has a tooltip naming its action | |
| C8 | `IRecipeTransferHandler` implemented if crafting is ghost-slot or storage-backed | |
| C9 | Sorting does not reorder items under the cursor mid-interaction | |

## D. HUD (max 12 — n/a if no HUD)

| # | Criterion | |
|---|---|---|
| D1 | ⛔ Suppressed on `hideGui` (F1), when a Screen is open, for spectators, and when `player == null` | |
| D2 | Does not overlap hotbar / XP bar / hearts / hunger / boss bar / effect icons / chat by default | |
| D3 | Position user-configurable in-game (anchor + offset at minimum) | |
| D4 | Hides or fades when the information is static or irrelevant | |
| D5 | Legible over both a snow biome at noon and a cave at night | |
| D6 | Ships **off by default** if not essential; passes the five-question HUD test | |

## E. Accessibility (max 28)

| # | Criterion | |
|---|---|---|
| E1 | ⛔ Every interactive control is a real widget via `addRenderableWidget` (or implements `NarratableEntry`) | |
| E2 | ⛔ Fully operable with the mouse unplugged; focus order matches visual order; linear lists wrap | |
| E3 | Screen has a real title `Component`; custom widgets implement `updateWidgetNarration` / `narrationPriority` | |
| E4 | ⛔ **No information conveyed by color alone** (shape/icon/text always present) | |
| E5 | Body text ≥4.5:1 contrast; disabled ≥3:1; measured against the worst-case background | |
| E6 | Honors High Contrast (or uses vanilla widget sprites so packs fix it) | |
| E7 | Honors Text Background Opacity / Text Background for HUD text | |
| E8 | ⛔ Honors Distortion Effects, Damage Tilt, FOV Effects, Darkness Pulsing, Hide Sky Flashes; **no rapid flashing** | |
| E9 | No timing-critical interaction; every hold-to-act has a click alternative | |
| E10 | No modifier-combo or drag is the **only** path to any function | |
| E11 | Tooltips render on keyboard/controller **focus**, not only mouse hover | |
| E12 | Dense reading surfaces (guidebooks, logs) have an independent text-scale option | |
| E13 | (26.3+) Custom text widgets call `onTextInputFocusChange` and return `capturesInput()`; screen hotkeys check `isInputCaptured()` | |
| E14 | (26.4+) Every `Slot` carries an honest `Slot.Section`; special slots override `getNarrationName()`; highlight drawn from `isHighlighted()` | |

## F. Content & IA (max 14)

| # | Criterion | |
|---|---|---|
| F1 | ⛔ 100% of user-visible strings come from lang keys; `en_us.json` complete | |
| F2 | Tooltips wrap at a max width and clamp so the **top** stays on-screen | |
| F3 | Every failure state names the cause, the remedy, and the number | |
| F4 | Every empty state says what would be here and how to get it | |
| F5 | Every recipe the mod adds appears in JEI/EMI/REI | |
| F6 | The screen exposes a help affordance to the guidebook/wiki page for **this** screen | |
| F7 | Config is categorized, searchable, and every option has a one-sentence tooltip | |

## G. Behavior & performance (max 8)

| # | Criterion | |
|---|---|---|
| G1 | `isPauseScreen` is a deliberate decision matching player expectation for this screen type | |
| G2 | Animations use `Util.getMillis()` (UI) or partial tick (simulation) — **never raw tick counts** | |
| G3 | GUI exclusion areas declared to JEI/REI/EMI; tested with all three installed | |
| G4 | No per-frame allocation, `Font#split`, string formatting, or `Component` construction in `render` | |

## H. Cross-band correctness (max 16 — for a multi-version mod)

| # | Criterion | |
|---|---|---|
| H1 | ⛔ Every color literal is 8-digit `0xAARRGGBB` (a color without alpha renders **nothing** from 1.21.6) | |
| H2 | Blit call form matches the target band (`ResourceLocation` / `Function<…,RenderType>` / `RenderPipeline`) | |
| H3 | No Z-translate for layering on 1.21.6+ (`pose()` is 2D there) — uses `nextStratum()`/bounds | |
| H4 | No mid-screen `Tesselator`/`BufferBuilder` on 1.21.6+ — uses PiP or a `GuiElementRenderState` | |
| H5 | ⛔ **No `org.lwjgl.opengl.*` or `GlStateManager` anywhere** (silently dead under Vulkan) | |
| H6 | ⛔ **No `org.lwjgl.glfw.*` and no raw key/modifier/mouse-button ints** — `InputConstants.KEY_*` / `KeyEvent#has*Down()` / `MouseButtonEvent` helpers only (GLFW is gone at 26.3; old ints silently mean other keys) | |
| H7 | Version-volatile GUI calls live behind a per-band adapter seam, not scattered `if` checks (see `java-patterns.md`) | |
| H8 | Tested under **both** graphics backends on 26.4 snapshots (Vulkan is default; snapshot-7+ picks a backend at random) | |

---

## Interpretation

- **Any ⛔ at 0 → do not ship.**
- **<60%** — the UI is a liability; redesign rather than patch.
- **60–79%** — shippable to an audience that already wants your mod; expect support load.
- **80–92%** — good. This is the tier Jade, Create and Refined Storage live in.
- **>92%** — better than any mod for which evidence was found.

---

## The five tests that catch most real bugs

If you only have time for five things, do these:

1. **GUI scale 1 at 4K, and GUI scale 4 at 1280×720.**
2. **Force Unicode Font on**, at scale 2 and 4.
3. **German (or a pseudolocalized lang file)** — brackets, accents, +40% length.
4. **Unplug the mouse** and try to operate every control.
5. **Install JEI, REI and EMI** and check nothing overlaps (EMI only exists up to 1.21.1; on later
   bands test JEI + REI).

Automate the first two with Fabric's client game tests (`fabric-client-gametest-api-v1`,
`assertScreenshotEquals`) — see `java-patterns.md` §8.
