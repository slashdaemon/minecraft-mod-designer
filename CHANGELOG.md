# Changelog

Dated entries; newest first. Each entry records what was verified and against which source.

## 2026-11-24 — Public release

- Removed the organisation-specific `house-patterns.md` and every pointer to private source trees.
  Its general content moved into the public references: semantic input at the seam
  (`java-patterns.md` §3.6), the 26.2 black-frame details (`render-pipeline.md` §7) and the
  `CycleButton` order-safe builder fix (`screen-widget-api.md` §3).
- History squashed to a single commit for publication.

## 2026-11-11 — 26.3 + 26.4-snapshot preview, library re-pin, Java patterns

**Sources:** `javap -p -constants` / `-protected` / bytecode over the official 26.2, 26.3 and
26.4-snapshot-8 client jars (GUI, input, render-state, sprite-metadata packages; ~900–965 classes
each) plus a diff of every GUI sprite `.mcmeta` and font asset (★★★); Mojang's patch notes JSON for 26.3
and 26.4-snapshot-1…8 (★★★); the merged NeoForge 26.3 primer and the draft 26.4 primer (PR #51, ★★);
Fabric's 26.3 blog (★★); maven metadata for Fabric/NeoForge/Forge and library mavens, the Modrinth
versions API, and loader source diffs (★★★); openjdk.org JEP pages (★★★).

**New era and preview**
- Era **G — SDL3 input** (26.3, band K) and **H — 26.4 preview** (band L, snapshot) in `SKILL.md`.
- 26.3: silent key/modifier/mouse-int changes, `InputConstants.REPEAT` 2 → −1, the text-input focus
  contract (`onTextInputFocusChange(GuiEventListener, boolean)` + `capturesInput()`; the 1-arg form
  was 26.2-only), `isInputCaptured`, `NarrationTrigger`, `textWithWordWrap` returns `int`, tooltip
  first-line gap now item-only (non-item tooltips 4 px shorter), `RenderPipeline` → `renderpearl`.
- 26.4 (snapshot-8): `extract*` lose mouse/partialTick, `Updatable.update(DeltaTracker)`, `GuiPipeline`,
  `addRenderableOnly` removed, `isHighlighted()` input-mode highlight, `SlotWidget` + `Slot.Section`
  keyboard navigation and slot narration, `MENU_SCREEN` client registry, `DynamicTexture` removed,
  F3 redesign, Vulkan default (random backend per launch in s7, not reverted in s8).
- Verified **unchanged** 26.2 → 26.4-s8: widget metrics, `CommonColors`, container geometry, core
  nine-slice values, fonts, GUI-scale math (SDL3 uses framebuffer pixels; never multiply by
  `getPixelDensity()`).

**Loaders and libraries**
- NeoForge 26.3: config types `LOCAL`/`SYNCED` (was `COMMON`/`SERVER`), mods-list `iconFile`/
  `iconBlur`/`bannerFile`, `ScreenEvent` key-getter renames, pin ≥ 26.3.0.90 for modifier keybinds;
  no NeoForge 26.4 build. Fabric API 26.4: `HudElement#update(DeltaTracker)`, `ScreenEvents` without
  mouse/tick, `fabric-screen-api-v1` 6.0.x, info-bar / status-bar / title hooks. MinecraftForge 26.x
  HUD API documented and not recommended.
- Every library pin in `libraries.md` re-verified; lagging libs flagged; Fzzy Config, MezzConfigGUI
  and a controller-support section (Controlify) added; Iris/Sodium/Sulkan/Vitrail status on Vulkan.
- **Correction:** Fabric API has a client-screen test harness (`fabric-client-gametest-api-v1`).

**New content**
- `references/java-patterns.md`: state outside the `Screen`, render-as-function-of-state, version
  seam vs loader seam (and which adapter absorbs each GUI break), GoF patterns and anti-patterns,
  Java 17/21/25 per band (JEP status checked), Mixin + Java 25, threading, testing layers.
- Accessibility, UX and review rubric updated for keyboard-navigable containers, input capture and
  SDL3 (rubric E13–E14, H6–H8).

**Repo**
- Added `CLAUDE.md`, this changelog, `.gitignore`, and `scripts/skill.{ps1,sh}` (install/link/diff/pull).

## 2026-09-09 — Initial skill

- MC 1.20.1 → 26.2, verified with `javap` over 1.20.1, 1.20.5, 1.21.1, 1.21.2, 1.21.4, 1.21.6,
  1.21.9, 1.21.11, 26.1.2 and 26.2 client jars.
