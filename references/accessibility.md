# Accessibility for Minecraft mod UI

Concrete, Minecraft-specific. Most of this is cheap if done from the start and painful to retrofit.

Contrast and encoding targets below come from the Xbox Accessibility Guidelines (XAG 101/102/103/112)
and the Game Accessibility Guidelines — the two references the games industry actually uses.

---

## 1. Respect the settings the player already chose

These are vanilla options. **Ignoring them is worse than not offering the feature**, because the
player has already told the game what they need.

| Vanilla option | Default | What your mod must do |
|---|---|---|
| **Narrator** (All / Chat / System / Off) + hotkey Ctrl+B | Off | make every screen narrate — §2 |
| **Text Background Opacity** | 50% | use it for your HUD text plates instead of a hardcoded alpha |
| **Text Background** (Chat / Everywhere) | Chat | if set to Everywhere, your HUD text should get a plate too |
| **Chat Text Opacity**, **Line Spacing**, **Chat Delay** | 100% / 0% / None | if you write to chat, respect delay; don't spam |
| **High Contrast** | Off | if on, switch to a high-contrast sprite set — §4 |
| **High Contrast Block Outlines** | Off | relevant if you draw world-space selection boxes |
| **Distortion Effects** | 100% | **scale any screen-warp/wobble you add by this.** At 0% it must be fully off |
| **FOV Effects** | 100% | same, for any FOV punch |
| **Damage Tilt** | 100% | scale any camera shake you add |
| **View Bobbing** | On | if off, don't add your own bob |
| **Darkness Pulsing** | 100% | scale any pulsing darkness/vignette |
| **Glint Speed / Glint Strength** | 50% / 75% | honor both if you render custom glints |
| **Hide Sky Flashes** | Off | if on, **never** full-screen flash |
| **Notification Time** | 1.0× | multiply your toast durations by it |
| **Menu Background Blur** | 50% | `Options#getMenuBackgroundBlurriness()` — **never on `Minecraft`** |
| **GUI Scale** (Auto, 1–4+) | Auto | §5 |
| **Force Unicode Font** | Off | §5 |
| **Closed Captions** | Off | if you add sounds, add subtitle entries so they caption |
| **Ctrl-click = right-click** (macOS, 26.3+) | platform default | if you hand-roll click handling, honor `Options#ctrlClickEmulatesRightClick()` — vanilla widgets already do ★★★ |
| **Quit Shortcuts** (26.3+) | On | don't bind Cmd+Q / Alt+F4-style combos in your screens; `InputQuirks.isQuitShortcutDown()` owns them ★★★ |
| **Debug GUI Scale** (26.3+) | Auto | F3 has its own scale now; don't size HUD elements relative to the F3 overlay ★★★ |

> **The design lesson embedded in that list:** Mojang made most of these **sliders, not toggles**, so
> distortion, damage tilt, glint speed and darkness pulsing can be dialled to a personal tolerance
> instead of all-or-nothing. **Copy that.** A motion effect you add should have a 0–100% slider.

---

## 2. Narrator support — what "supported" actually means

Vanilla ships a narrator; modded Minecraft is largely unnarrated. The existence of *minecraft-access*
— a mod whose job is to narrate the game interface and add spatial sound cues — is the evidence that
the baseline is inadequate.

**Concrete obligations:**

1. **Use real widgets.** Every vanilla widget is a `NarratableEntry` and narrates for free. Every
   hand-drawn `blit` + `mouseClicked` control narrates **nothing**. This is the whole ballgame.
2. Implement `narrationPriority()`, `isActive()`, and `updateNarration(NarrationElementOutput)` on any
   custom `NarratableEntry`. Provide the element name (title), a usage hint, and position for list items.
3. **Give the `Screen` a real `title` Component** — it's the first thing spoken.
4. **Never use a Unicode glyph as an icon.** XAG 103 is unusually direct: don't use Unicode glyphs
   with the desired appearance but a different meaning, because the screen reader speaks the Unicode
   *name*. In Minecraft modding this bites constantly — `⚡` narrates as "high voltage sign", `❤` as
   "heavy black heart", `⛏` as "pick". Use a sprite plus a translated text label. (If you want icons
   inline with text, use a custom **font provider** with PUA codepoints — see `assets-and-fonts.md`
   §3.3 — but the *narrated* string must still be words.)
5. **Slots are the hard part — and 26.4 changes the baseline.**
   - **≤ 26.3:** vanilla slots aren't narrated meaningfully. If your mod's core interaction is a grid,
     at minimum narrate the hovered/focused slot's item name and count on focus change. This is above
     the community baseline and the single highest-leverage accessibility thing a container mod can do.
     [opinion]
   - **26.4 (snapshot-7+, ★★★ javap + patch notes, snapshot — subject to change):** every slot is a
     focusable, narrated `SlotWidget`. Vanilla narrates contents, tooltip, the special-slot name
     (`Slot#getNarrationName()`, falling back to the `SlotGroup` name) and position ("3 out of 9", or
     row/column via `GroupNarration`). **Container screens built on `AbstractContainerScreen` get this
     for free if every `Slot` is constructed with a meaningful `Slot.Section`.** A custom container that
     hand-draws its own slots instead of using `Slot`s is now *below* vanilla, not merely at baseline.
     Override `getNarrationName()` for special slots (upgrade, filter, fuel-like inputs).
6. **Report the narration trigger (26.3+).** `NarrationElementOutput#narrationTrigger()` is now
   `MOUSE` / `KEYBOARD` / `SYSTEM`, and `Screen#updateNarratorStatus` takes a `NarrationTrigger`. Custom
   `NarratableEntry` code that narrates on hover should narrate less eagerly on `MOUSE` than on
   `KEYBOARD` focus, matching vanilla. ★★★ signatures / ★ guidance

---

## 3. Keyboard and controller operability

**XAG 112: the UI must be fully navigable by keyboard and controller *digital* input alone.**
Test by unplugging your mouse. If any control is unreachable, that's a defect.

- Register controls with **`addRenderableWidget`**, not `addRenderableOnly` + hand-rolled
  `mouseClicked`. The second pattern removes the control from Tab order, from the narrator, **and from
  every controller mod** — MidnightControls and Controllable both drive navigation off vanilla's
  widget focus graph. Custom-drawn click regions that aren't widgets are invisible to all three.
- **Tab order follows registration order.** Register in reading order — left-to-right, top-to-bottom.
- **Add a visible focus ring (≤ 26.3).** Vanilla has **no separate focus sprite** — `isSelected() =
  isHovered() || isFocused()`, so hover and focus share one texture. For a keyboard user that is not
  enough feedback; draw your own 1–2px outline when `isFocused()`.
- **Follow the input mode (26.4+).** `isHoveredOrFocused()` becomes **`isHighlighted()`**, which is
  *hovered* in mouse mode and *focused* in keyboard mode (`InputType.KEYBOARD_SELECTION` is new). The
  cursor is hidden while navigating by keyboard and returns after 7 px of mouse movement; hovered list
  entries get a grey outline. Draw highlight state from `isHighlighted()`, never `isHovered() ||
  isFocused()` — the old expression shows two highlighted controls at once when the hidden cursor rests
  over one. ★★★ javap (26.4-snapshot-8)
- **Text fields must claim text input (26.3+, SDL3).** A custom text widget must call
  `Minecraft.getInstance().onTextInputFocusChange(this, focused)` from `setFocused` and return
  `capturesInput() = true` while editing, or `charTyped` never fires and IME composition never starts.
  Vanilla `EditBox` already does both. 26.4 adds a two-step pattern: **Tab** focuses and edits, **arrow
  keys** only highlight, then **Enter/Space** enters edit mode (`EditBox#setCanChangeValue`). ★★★
- **Accept only the left button for primary actions (26.4 pattern).** Vanilla now ignores non-left
  buttons in lists, links and suggestions; use `MouseButtonEvent#isLeftMouse()`. Under SDL3 (26.3+)
  button numbers changed (left 1, right 3) — never compare raw ints. ★★★
- **Render tooltips on `focused`, not only on `isHovered()`.** Hover-only information is invisible to
  keyboard and controller users.
- **Don't require simultaneous inputs.** Ctrl+Shift+click as the *only* path to a function excludes
  one-handed players. Every modifier-click accelerator needs a plain-click path somewhere.
- **Don't require drag.** Drag-to-reorder needs a move-up / move-down alternative.
- **Focus wrapping:** in a linear list, wrap last→first; in a 2D grid, don't.
- **If the visual layout changes** (UI scaling, resolution change), the navigation order must update to
  match the new visual layout.

---

## 4. Contrast and colorblind-safe encoding

### Targets (XAG 102)

| Element | Minimum contrast |
|---|---|
| Standard-size text / visual elements carrying information | **4.5:1** |
| Large-scale text and visual elements | **3:1** |
| Text on inactive/disabled elements | **3:1** |
| Placeholder / input-field text | 4.5:1 (3:1 if large) |
| Everything, when a high-contrast mode is on | **7:1** |
| Logos, purely decorative elements | no requirement |

For text over a non-solid background, measure against the **lowest-contrasting area** of that
background — for a HUD, that's "snow biome at noon" for white and "cave at night" for black.

> **XAG 102 also says: images shouldn't contain text except for logotypes.** Text baked into a GUI
> background PNG cannot be translated, recolored by a resource pack, contrast-adjusted, or narrated.
> **Draw all text as text.** This is the most common structural mistake in mod GUI textures.

### High Contrast

Minecraft's built-in **High Contrast** pack originally only affected the main menu; the community
extended it to all GUIs (High Contrast Extended, Higher Contrast).

> **Practical consequence: if you use vanilla widget sprites, high-contrast packs fix your mod for
> free. If you ship bespoke widget textures, you have opted your mod out of the ecosystem's
> accessibility layer** unless you ship a high-contrast variant yourself. This is a genuine, and badly
> underrated, argument for the vanilla-identical style posture (`design-language.md` §12).

### Color is always the second channel, never the only one

XAG 103: anything critical expressed through color also needs **shape, pattern, iconography, or a text
label**. And if graying is used to signal an unavailable control, add another signifier — the
Sea of Thieves pattern is grayed **plus a lock icon**.

Minecraft-specific applications:

- **Machine side-config colors** must carry the type name too.
- **Fluid/gas bars** distinguished only by tint are a failure — add the fluid icon and name in the
  tooltip, and consider a pattern overlay.
- **"Can't craft" states**: don't just tint the item red. Red + a caution glyph + `×0 Available`.
- **Mana/energy/stress bars in the same corner** differing only by hue — add a 9×9 icon per bar.
- Avoid **red/green** as the sole opposition (the most common CVD axis). Prefer blue/orange, add shape.
- If color genuinely *is* the primary channel, let the player pick the colors — a hex field in config.
  Cheap, and it also serves the "match my resource pack" crowd.

---

## 5. Text size — GUI Scale and Force Unicode

Minecraft's "text size" control **is** GUI Scale plus Force Unicode Font. There is no independent
font-size slider — which is exactly why Immersive Engineering's manual drew the complaint "I can not
read the manual's text", with the only workaround being Auto scale, which "makes everything too big."

> **For any dense reading surface — guidebooks, logs, long tooltips — ship a per-screen text-scale
> option.** [opinion, strongly held]

### Non-negotiable test matrix

| Case | What breaks |
|---|---|
| **GUI Scale 1 @ 3840×2160** | text unreadably small; your screen is tiny relative to the window — centre it, don't top-left it |
| **GUI Scale 4 @ 1280×720** | your 176px panel is 704 effective px on a 720p window. **Anything wider than ~180 GUI units will not fit.** This is a real, filed accessibility complaint against AE2 |
| **Force Unicode ON** | glyphs become 16×16 with **half-pixel advances**; every string gets wider; and the GUI scale is **rounded up to the next even number**, so 1280×720 goes 3→4 and the logical viewport becomes **320×180** — below the 240 design floor. Screens assuming 240 rows clip |
| **German / Russian / Finnish locale** | +20–40% string length |
| **Ultrawide (21:9, 32:9)** | anything centred on `W/2` drifts far from the player's focus; anything right-anchored is in peripheral vision |
| **Window resize mid-screen** | `init()` re-runs on resize — recompute layout there, never in the constructor, and persist scroll/search/tab state |

**Measure with `Font#width`, never with `text.length()`.** XAG 112 adds: text/UI scaling must not
force scrolling in two directions.

---

## 6. Motion, flashing, timing

- **No rapid flashing, ever.** "Avoid flickering images and repetitive patterns" is a *Basic*
  Game Accessibility Guideline. Vanilla has a **Hide Sky Flashes** option — if your mod flashes
  anything, ship a slider and honor that setting.
- **No screen shake or distortion without honoring Distortion Effects / Damage Tilt / FOV Effects.**
  A mod that shakes the camera through a player's 0% Damage Tilt setting is actively harmful, not
  merely rude.
- **Motion-sensitivity default:** animations on, with an off switch, durations ≤200 ms. [opinion]
- **Timing-dependent interactions are an accessibility failure by default.** The Advanced guideline is
  explicit: don't make precise timing essential — offer alternatives, actions that work while paused,
  or a skip. Any UI requiring a click within N ticks, a rhythm, or a double-click faster than the OS
  default is excluding people.
  - Create's Ponder and AE2's guide both use **hold-`W`-to-activate**. That's acceptable because it's
    *optional* and *non-punishing* — but it still fails "avoid requiring buttons to be held", so pair
    it with a clickable alternative.

---

## 7. Controller / Steam Deck / one-handed

- **Vanilla has no controller support, even on SDL3** (26.3/26.4 initialise SDL with VIDEO only; no
  gamepad/joystick API is referenced — ★★★ javap). Mojang calls 26.4's keyboard navigation a "first
  step". Controller play is still entirely mod-provided.
- Modded screens get navigated by **Controlify** (Fabric + NeoForge, 3.5.3; since 3.5.0 it can use the game's bundled
  SDL3 on 26.3+ and replaced its button-guide API with a rule-based system), **MidnightControls** (MIT,
  Fabric/Quilt + NeoForge, still 26.2 max as of 2026-11-11) and **Controllable** (MrCrayfish,
  0.26.2+26.3). See `libraries.md` for pins. All of them drive navigation off vanilla's widget focus
  graph and pick up modded keybinds.
- **What neither can do is navigate a screen with no focusable widgets.** Everything in §3 is what
  makes your screen controller-playable. There is no controller-specific work to do beyond that.
- Give every interactive element a real `AbstractWidget` in the children list, correct tab order, and
  `setFocused` handling — and you get controller support, narrator support, and keyboard support from
  the same work.

---

## 8. Text density and dyslexia-friendliness

The vanilla font is an 8px bitmap with no dyslexia-friendly alternative built in. What you control is
**density**:

- Cap tooltip and guidebook line length at **~35–45 characters**. Long measure is the biggest
  legibility lever available and it costs nothing.
- Break tooltips into short lines with blank lines between logical groups, not one 12-line wall.
- **"Hold Shift for details"** is the correct Minecraft idiom for depth — it keeps the default tooltip
  short and gives power users everything. Make sure the hint line itself is present, or the detail is
  undiscoverable.
- Prefer **numbers with units and separators** (`12,400 FE`) over bare digits.
- Short declaratives. See `ux-principles.md` §7.6.

---

## 9. The accessibility gate — fail any of these and don't ship

- [ ] Every interactive control is a real widget registered via `addRenderableWidget` (or implements
      `NarratableEntry`).
- [ ] Fully operable with the mouse unplugged; focus order matches visual order.
- [ ] A visible focus indicator distinct from hover.
- [ ] **No information conveyed by color alone.**
- [ ] Body text ≥4.5:1 contrast measured against the worst-case background.
- [ ] Honors Distortion Effects / Damage Tilt / FOV Effects / Darkness Pulsing / Hide Sky Flashes for
      any effect you add; **no rapid flashing**.
- [ ] No text baked into a background texture.
- [ ] Renders correctly at GUI Scale 1–4 and with Force Unicode ON.
- [ ] Tooltips render on **focus**, not only hover.
- [ ] (26.3+) Custom text widgets call `onTextInputFocusChange` and return `capturesInput()` while editing.
- [ ] (26.4+) Every `Slot` has a meaningful `Slot.Section`; special slots override `getNarrationName()`;
      highlight is drawn from `isHighlighted()`.
- [ ] No timing-critical interaction; every hold-to-act has a click alternative; no modifier-combo or
      drag is the only path to any function.

---

## 10. Unverified

- The Xbox Accessibility Guidelines and Game Accessibility Guidelines are industry references, not
  Mojang policy. Minecraft itself does not meet all of them.
- **Minecraft has no "dark mode."** The closest things are the High Contrast pack, Menu Background
  Blur, and Text Background settings. Do not design assuming a light/dark theme token exists.
- Exact narration behavior for slots ≤ 26.3 was not verified per-band; the ≤ 26.3 recommendation in
  §2.5 is a design position, not a description of vanilla. The 26.4 behavior is from snapshot jars
  (through 26.4-snapshot-8) and patch notes; nothing was rendered or listened to, and the snapshot API
  can still change before release.
- Whether Controlify / MidnightControls / Controllable drive 26.4's `SlotWidget` focus graph directly
  (instead of their own slot-snapping) is not established.
- HiDPI behavior per OS under SDL3 (Wayland fractional scale, Windows per-monitor DPI) is inferred
  from SDL defaults, not tested on hardware. GUI-scale math itself is unchanged (`render-pipeline.md`).
