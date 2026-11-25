---
name: minecraft-mod-designer
description: >-
  Authoritative UI/UX design-and-implementation reference for Minecraft Java mods
  across MC 1.20.1 → 26.3 (SDL3 input) plus a 26.4-snapshot preview (GuiPipeline,
  keyboard-navigable SlotWidget containers), on Fabric, Quilt, NeoForge, and
  MinecraftForge (LexForge) 1.20.1. Covers both halves: the *design* half —
  vanilla visual grammar, hard pixel metrics, slot/inventory interaction
  conventions, HUD placement and safe zones, accessibility (narrator, contrast,
  colorblind encoding, GUI scale, controller), information architecture,
  microcopy, and a scored design-review rubric — and the *implementation* half —
  Screen lifecycle, the widget catalogue with default metrics, the layout system
  (GridLayout/LinearLayout/FrameLayout/HeaderAndFooterLayout), container screens
  and Slot math, GuiGraphics/GuiGraphicsExtractor blit-and-text deltas per band,
  the 1.21.6 deferred GUI render-state rewrite, Picture-in-Picture, per-loader
  HUD/screen/keybind/config-screen hooks, the GUI sprite atlas and nine-slice
  .mcmeta schema, fonts and custom icon fonts, localization, GUI-scale math, the
  Vulkan-safety rules, GUI performance, the JEI/REI/EMI exclusion-zone
  contract, and Java design patterns for mod UI (state outside the Screen,
  version/loader adapter seams, Java 17/21/25 language level per band, Mixin
  limits, threading, client game tests). Trigger whenever the task involves designing, building, reviewing, or
  porting a mod's screen, HUD, overlay, tooltip, toast, config screen, widget, or
  GUI texture — or when the user names a symbol (Screen, GuiGraphics,
  GuiGraphicsExtractor, AbstractContainerScreen, renderBg, extractRenderState,
  blitSprite, nine_slice, HudElementRegistry, RegisterGuiLayersEvent,
  PictureInPictureRenderer, GuiRenderState, Matrix3x2fStack, quickMoveStack,
  NarratableEntry, Tooltip, ToastManager, ModMenuApi, ConfigurationScreen,
  GuiPipeline, SlotWidget, Slot.Section, Updatable, DeltaTracker, isHighlighted,
  capturesInput, isInputCaptured, onTextInputFocusChange, KeyEvent, InputConstants,
  MENU_SCREEN, HudElement, ModConfig.Type.SYNCED) or
  says "GUI", "HUD", "screen", "widget", "tooltip", "overlay", "why is my text
  invisible", "why is my GUI off-centre", "GUI scale", "config screen", "my text
  box stopped typing", "keybind broke on 26.3", "keyboard navigation", "make
  this look vanilla", or asks how to structure/architect mod UI code in Java. Not for build/toolchain coordinates, mappings, mixin
  refmaps, or jar packaging — that is minecraft-mod-expert.
---

# Minecraft Mod Designer (UI/UX)

The design-and-implementation counterpart to **`minecraft-mod-expert`** (which owns build
coordinates, mappings, packaging and porting mechanics). This skill answers four questions:

1. **What should this look like?** — vanilla's visual grammar and the hard numbers behind it.
2. **How should it behave?** — the interaction contracts players already know, and the ones they'll
   punish you for breaking.
3. **How do I actually draw it on band X, loader Y?** — exact signatures, per band, per loader.
4. **Is it good enough to ship?** — a scored rubric with hard gates.

Optimize for **precision of metrics and signatures**, and for **design decisions with reasons
attached**. Where a fact is version-volatile or single-source, it is marked; say so rather than
inventing a patch number.

---

## How to use this skill

| Task | Read |
|---|---|
| "Make this look/feel like Minecraft"; picking colors, spacing, bevels, slot geometry, whether to brand or match vanilla | `references/design-language.md` |
| Designing interactions, HUD placement, config vs screen vs block-GUI, error/empty states, microcopy; diagnosing a UI "smell"; case studies | `references/ux-principles.md` |
| Narrator, contrast, colorblind encoding, GUI scale extremes, Force Unicode, motion/flashing, controller/keyboard operability | `references/accessibility.md` |
| Writing a `Screen`, a widget, a layout, or a container screen; anything about `init()`, widget metrics, `Slot` math, focus, tooltips, toasts | `references/screen-widget-api.md` |
| "How do I blit/draw text on band X"; the 1.21.6 deferred-GUI rewrite; PiP; item/entity rendering in a GUI; 26.1 `extract*` renames | `references/render-pipeline.md` |
| HUD layers, screen events, keybinds, config-screen entry points, client-only safety, mod metadata — **per loader** | `references/loader-hooks.md` |
| GUI sprites, nine-slice `.mcmeta`, the atlas, fonts and icon fonts, GUI-scale math, texture authoring, `pack_format`, localization | `references/assets-and-fonts.md` |
| Vulkan safety, GPU abstraction, GUI performance, Sodium/Iris/shader compatibility, profiling, frame pacing | `references/vulkan-and-performance.md` |
| "Which config/UI library should I use"; JEI/REI/EMI integration and the exclusion-zone contract; multi-loader code sharing; mixing into vanilla screens | `references/libraries.md` |
| Reviewing a UI before shipping | `references/review-checklist.md` |
| Structuring UI code: state vs `Screen`, per-band adapter seams, Java 17/21/25 features, Mixin limits, threading, testing | `references/java-patterns.md` |

Read only the file(s) the task needs — they are large lookup tables.

---

## The UI eras (memorize this)

The band letters match `minecraft-mod-expert`. The **UI** boundaries do not line up with the
toolchain boundaries — these are the ones that matter here.

| Era | Bands | MC | Defining UI break |
|---|---|---|---|
| **A — legacy** | A | 1.20.1 | `renderBackground(GuiGraphics)`; sheet textures (`widgets.png`); `EditBox#tick()`; 3-arg `mouseScrolled`; no `blitSprite` |
| **B — sprite atlas** | (1.20.2–1.20.4) | 1.20.2–1.20.4 | **GUI sprite atlas + nine-slice `.mcmeta`**; 4-arg `renderBackground`; 4-arg `mouseScrolled` |
| **C — UI refresh** | B, C | 1.20.5–1.21.1 | menu **blur** + `MENU_BACKGROUND`; `setTooltipDelay(Duration)`; **`AbstractWidget#render` becomes final** |
| **D — RenderType blits** | D, E | 1.21.2–1.21.4 | every blit takes `Function<ResourceLocation, RenderType>` + explicit PNG size; `setColor` removed; `ToastManager`; `addStandardInventorySlots` |
| **E — GUI render state** | E–H | **1.21.5**: GPU abstraction lands underneath · **1.21.6**: the rewrite | **deferred/retained GUI**; `RenderPipeline` blits; `pose()` → **`Matrix3x2fStack`** (no Z); `drawString` needs alpha; PiP. **1.21.9** input event objects. **1.21.11** `Identifier`, `init(int,int)` |
| **F — extract / Vulkan** | I, J | 26.1 / 26.2 | mass rename `render*` → **`extract*`**, `GuiGraphics` → **`GuiGraphicsExtractor`**; `renderBg` deleted. **26.2**: Vulkan backend, `MultiBufferSource` deleted, `Font#draw` deleted, `Gui`/`Hud` split |
| **G — SDL3 input** | K | 26.3 | **GLFW → SDL3**: key/modifier/mouse ints change silently; text widgets must call `onTextInputFocusChange` + `capturesInput()`; `isInputCaptured`; `NarrationTrigger`; non-item tooltips lose the first-line gap; `RenderPipeline` moves to `renderpearl`. Visual metrics unchanged. NeoForge config `COMMON/SERVER` → `LOCAL/SYNCED` |
| **H — preview** (snapshot, not a band) | L | 26.4-snapshot-8 | `extract*` methods **lose mouse/partialTick** (read from the extractor) + `Updatable.update(DeltaTracker)`; **`GuiPipeline`** in every blit/fill; `addRenderableOnly` deleted; `isHighlighted()`; containers on **`SlotWidget`** + `Slot.Section` (keyboard nav + narration); `MENU_SCREEN` client registry; `DynamicTexture` gone; **Vulkan default** |

> **The distinction that decides your porting strategy:** the **1.21.6 break is behavioral** — you now
> *submit render state* instead of drawing, but the **names are unchanged** (`renderWidget` still
> exists through 1.21.11). The **26.1 break is nominal** — a mass rename on top of the same
> architecture. One needs restructuring; the other needs a shim. **26.3 is an input break** (silent
> constant changes — grep for raw ints). **26.4 is a signature break on every widget** — the reason to
> already have your GUI behind a per-band adapter (`java-patterns.md`).

---

## The ten laws

1. **Write every color literal as 8-digit `0xAARRGGBB`, on every band.** From 1.21.6 a color without
   an alpha channel renders **nothing**, silently. One convention makes one source file correct from
   1.20.1 to 26.2.
2. **Anchor, never hardcode.** All geometry derives from `leftPos`/`topPos`, `this.width`/`height`, or
   a nine-point anchor + offset. Assume a **320 × 240 logical** worst case; a 176-wide container fits,
   a 220-tall one does not.
3. **Every interactive control is a real widget** registered with `addRenderableWidget`.
   `addRenderableOnly` + a hand-rolled `mouseClicked` is the single most common way a mod screen
   becomes mouse-only — it removes the control from Tab order, from the narrator, **and from every
   controller mod**.
4. **The bevel direction is the grammar.** Raised = light top-left / dark bottom-right; recessed =
   inverted. Get it wrong and nothing else you do matters.
5. **Two text modes, and don't mix them up.** Flat `0xFF404040` **without** shadow on your own light
   panel; white **with** shadow over the world. The reverse is both wrong-looking and a contrast bug.
6. **Color is always the second channel, never the only one.** Add shape, icon, or text.
7. **Check `hideGui` (F1) in every HUD renderer** — plus screen-open, spectator, and `player == null`.
   On Fabric, `HudElementRegistry.addFirst`/`addLast` inherit **no** render condition, so F1 is your
   job.
8. **Animate UI on `Util.getMillis()`**, not on tick counts and not on a screen's `partialTick`
   (which freezes while the game is paused — exactly when your screen is open).
9. **Never import `org.lwjgl.opengl.*` / `org.lwjgl.glfw.*` or call `GlStateManager`.** GL compiles
   and works on your dev machine and is dead for every Vulkan user (Vulkan is the 26.4 default). GLFW
   is gone at 26.3; a raw key int like `256` still compiles and now means a different key. Use
   `InputConstants.KEY_*` and the `KeyEvent`/`MouseButtonEvent` helpers.
10. **Declare exclusion zones to JEI, REI and EMI.** A mod with side-tabs that skips this gets them
    covered by the item list. Keep the rectangle math in one shared helper — the three APIs differ
    only in the rectangle type.

---

## Cross-cutting gotchas worth memorizing

- **`quickMoveStack` must return `ItemStack.EMPTY` when nothing moved**, or the client loops forever.
- **`inventoryLabelY` is computed in the constructor as `imageHeight - 94`** from the *default* 166.
  If you set `imageHeight` afterwards, recompute it yourself.
- **`renderTooltip` must be called after `super.render(...)`**, not before.
- **`Screen#init()` re-runs on window resize.** Persist scroll position, search text and active tab —
  or override `repositionElements()` to just `arrangeElements()` and keep widget identity and focus.
- **The layout package is 1.19.3/1.19.4, not 1.20.2.** `GridLayout`/`LinearLayout`/`FrameLayout`/
  `HeaderAndFooterLayout` are fully available on **1.20.1**. Use them on every band — layout code is
  the most portable part of the GUI API and 26.1's rename doesn't touch it.
- **`mouseScrolled` gained horizontal scroll at 1.20.2**, not 1.21. **`renderBackground` gained
  `mouseX/mouseY/partialTick` at 1.20.2** too.
- **`EditBox#tick()` was removed at 1.20.2** — delete the call when porting off Band A.
- **1.21.9 folded input into event objects** (`MouseButtonEvent`, `KeyEvent`, `CharacterEvent`), and
  `Window#getWindow()` became `Window#handle()`.
- **1.21.11 made `AbstractButton#renderWidget` final** — move to `renderContents` +
  `renderDefaultSprite`. And `CycleButton.builder` took the initial value **positionally**.
- **Nine-slice edges and centers TILE, they do not stretch** (unlike CSS `border-image`).
  `stretch_inner: true` from 1.21.2 flips that.
- **Force Unicode Font rounds the GUI scale up to the next even number** — 1280×720 goes 3→4 and the
  logical viewport becomes 320×**180**, below the 240 design floor.
- **`ForwardingSlider` is not vanilla.** It's NeoForge `ExtendedSlider` / Forge `ForgeSlider`.
- **NeoForge does not exist for 1.20.1** — the only Forge-family loader on Band A is LexForge 47.x.
- **Quilt: ship the Fabric jar.** QSL/QFAPI were retired at 26.1; the last stable QFAPI is for
  MC 1.20.1. Depend on `fabric-api`, stay out of `net.fabricmc.fabric.impl.*`, and don't claim
  support you can't test.
- **26.2 has an open vanilla bug**: a minimal custom `Screen` subclass shows one black frame on every
  open, under both backends. No confirmed mod-side fix; a partial mitigation (`isInGameUi()` → `true`,
  no-op blurred background) is in `render-pipeline.md` §7. Not re-reproduced on 26.3/26.4.
- **GUI scale is unchanged under SDL3.** Same integer formula from framebuffer pixels with a 320×240
  floor; **never multiply by `Window#getPixelDensity()`** — it's already in the framebuffer (vanilla
  uses it only for the IME rectangle). 26.3 also enforces a 320×240 minimum window.
- **26.3 tooltips:** the 2 px gap under the first line now applies only to item tooltips; multi-line
  text/widget tooltips are 4 px shorter. Pass `extraSpaceAfterFirstLine = true` to mimic item styling.
- **`InputConstants.REPEAT` is −1 on 26.3** (was 2). In 26.4 use `KeyEvent#repeat()`.
- **26.4 (snapshot): `extractRenderState` should be a pure getter** — hover/time logic moves to
  `update(DeltaTracker)`. Read the mouse from `GuiGraphicsExtractor#mouseX()/mouseY()`.
- **NeoForge has no 26.4 build yet; MinecraftForge 26.x has a third HUD API** (`AddGuiOverlayLayersEvent`)
  and almost no library support — don't target it. See `loader-hooks.md`.
- **Keep shared UI source at `--release 17`** if 1.20.1 is in scope; pattern `switch`/record patterns
  belong in band files only. See `java-patterns.md`.

---

## Reference files

| File | Contents |
|---|---|
| `references/design-language.md` | Vanilla visual grammar; source-verified color constants; container/slot/button/spacing/Z/text metrics; tooltip geometry; screen backgrounds; the match-vs-brand-vs-diegetic argument |
| `references/ux-principles.md` | Slot-interaction contracts; machine/config patterns; search grammar and reserved keys; destructive actions; HUD occupied-region map, safe zones and suppression rules; animation clocks; information architecture; error/empty states; microcopy; a 25-item smells list; eight case studies |
| `references/accessibility.md` | Vanilla options you must respect; narrator obligations; keyboard/controller operability; contrast targets; colorblind encoding; GUI-scale and Force-Unicode test matrix; motion/flashing/timing; the accessibility gate |
| `references/screen-widget-api.md` | Screen lifecycle per band; the three add-widget methods; full widget catalogue with default metrics; the layout system + canonical `init()`; container screens, `Slot` math and `quickMoveStack`; input and focus; narration; tooltips; toasts; a per-band migration cheat-sheet |
| `references/render-pipeline.md` | The per-band cheat sheet (blit/text/fill/item/tooltip/transform); the 1.21.6 deferred-GUI rewrite in full; `GuiElementRenderState` and Picture-in-Picture; 1.21.5 `RenderPipeline`; item/entity/text deltas; the 26.1 rename tables; GUI scale and resize APIs |
| `references/loader-hooks.md` | HUD rendering per loader per band (decision table); screen events; keybindings; config screens; client-only safety checklist; mod metadata and `pack_format`; the honest Quilt answer |
| `references/assets-and-fonts.md` | GUI sprite system and `.mcmeta` schema; nine-slice math and authoring mistakes; the atlas; font providers and custom icon fonts; GUI-scale algorithm and scale table; texture authoring (why HD GUIs look wrong); `pack_format` table; localization, `%1$s`, pluralization, overflow, pseudolocalization |
| `references/vulkan-and-performance.md` | The rewrite timeline; what the 26.2 Vulkan backend actually is; what breaks; the Vulkan-safety checklist; GUI performance hotspots; profiling; Sodium/Iris/Sulkan status; frame pacing |
| `references/libraries.md` | Decision table for config/UI libraries with 2026-verified versions; **the JEI/REI/EMI exclusion-zone contract**; Mod Menu metadata; multi-loader code-sharing strategies; mixing into vanilla screens; UI testing tooling; what's abandoned |
| `references/review-checklist.md` | The scored rubric (8 sections, gate items) plus the five tests that catch most real bugs |
| `references/java-patterns.md` | Java design patterns for mod UI: unidirectional state outside the `Screen`; render-as-function-of-state for the extract model; version seam vs loader seam (adapters, Stonecutter, Architectury, MultiLoader-Template, ServiceLoader) and which adapter absorbs each GUI break; GoF patterns and anti-patterns; Java 17/21/25 per band; Mixin + Java 25; threading; testing layers |
