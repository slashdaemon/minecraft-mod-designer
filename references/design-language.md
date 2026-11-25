# The vanilla design language — grammar and hard numbers

What makes a UI *look* like Minecraft, and every metric you need to hit it.
Confidence: ★★★ verified in decompiled vanilla source or a primary Mojang artifact ·
★★ corroborated secondary source · ★ convention/inference.

## 0. Version stability — 26.2 → 26.3 → 26.4-snapshot-8 ★★★

*Status as of 2026-11-11: latest release 26.3 (band K), latest snapshot 26.4-snapshot-8 (band L
preview).* Verified with `javap -p -constants` over the official 26.2, 26.3 and 26.4-snapshot-8
client jars plus a diff of every GUI sprite `.mcmeta` and the font assets:

**The core visual language did not change.** Every metric, color and sprite in this file holds on
26.3 and on 26.4-snapshot-8:

- **Metrics unchanged:** `Button` 120/150/200 × 20, spacing 8; slider 20 high, handle 8; checkbox
  spacing 4 / box padding 8; `SCROLLBAR_WIDTH` 6 (min thumb 32); tooltip padding 3, `MOUSE_OFFSET` 12,
  `MARGIN` 9, `MAX_WIDTH` 170; toast 160 × 32, 5 slots; header/footer 33, content top margin 30;
  container 176 × 166 on a 256² sheet; `Font.lineHeight` 9; `EditBox` text 0xFFE0E0E0.
- **Colors unchanged:** every `CommonColors` constant (`GRAY 0xFF808080`, `DARK_GRAY 0xFF404040`,
  `LIGHT_GRAY 0xFFA0A0A0`, `LIGHTER_GRAY 0xFFBABABA`, `SOFT_RED 0xFFDF5050`, `SOFT_YELLOW 0xFFFFFF55`,
  `TEXT_GRAY 0xFFE0E0E0`, …) and the tooltip colors. 26.4-s8 only *adds* `CommonColors.TEXTURE_TINT_COLORS`.
- **Sprites and nine-slice values unchanged** for button, slider, slider handle, text field, scroller,
  tab, tooltip background/frame, slot highlight, toasts and popup background. Sprite churn is limited
  to vanilla's Realms/Friends/pause-menu art (26.3 `widget/realms_button*`; 26.4-s8 `friends/tab*`,
  `widget/loading`, new pause-menu icons) — nothing a mod reuses.
- **Fonts byte-identical** across all three versions.
- **No new accessibility options** for contrast, text background, blur or GUI scale in 26.3 or
  26.4-s8.

What *did* change visually (each covered below): the **tooltip first-line gap** (26.3, §10), the
**minimum window** of 320 × 240 under SDL (26.3, §13), and on 26.4-s8 **input-mode-aware highlight**
plus keyboard-focusable slots (§6, §5). The main-menu panorama was replaced in 26.3 and again in
26.4-snapshot-7 — irrelevant to mod screens.

---

## 1. The non-negotiable constraints

Break any of these and the UI reads as "not Minecraft" no matter how good the art is.

| Constraint | Rule | Why |
|---|---|---|
| **Pixel grid** | Every edge lands on an integer GUI pixel. No sub-pixel positioning. | GUI scale is an **integer** multiplier. A half-pixel at scale 1 is a visible 2px seam at scale 4. |
| **1× pixel art** | Author GUI textures at 1 texture pixel = 1 GUI unit. Never author at 2×/4× and downscale. | The GUI atlas has **no mipmaps** and samples nearest-neighbour. A 2× texture in a 1× rect drops every other row — aliased, not smooth. See `assets-and-fonts.md` §6. |
| **No anti-aliasing** | Hard edges only. Pencil / fill / eraser, no soft brush, no blur, no drop-shadow filter. | Mojang's own style guide restricts the toolset to exactly that. Noise "adds no information to the texture." |
| **No gradients** | 2–4 flat tones per surface; ramps step, they don't blend. | The two exceptions in vanilla (tooltip border, screen dim) are 1px lines and full-screen washes, not surface shading. |
| **No rounded corners** | Square, or beveled by exactly 1px. | Vanilla has zero rounded corners in container UI. A 4px radius is instantly foreign. |
| **No mixels** | Never mix texture densities inside one screen. | A 16px item icon beside a 32px-detail custom icon is the same crime at UI scale. |

## 2. The bevel rule — the one thing people get wrong

A **raised** element is light on the **top-left**, dark on the **bottom-right**.
A **recessed** element (slot, text field, progress track, well) is exactly **inverted**.

This single inversion is how a Minecraft player knows, without a label, whether a rectangle is a
button or a hole. Lighting comes from the top-left, matching item textures. **If your custom widget's
bevel direction is wrong, everything else you do is wasted.**

The conventional panel palette (★★ — derived from vanilla art, not from a source constant):

| Role | Hex | Use |
|---|---|---|
| Panel highlight | `#FFFFFF` | 1px top + left edge of a raised panel |
| Panel face | `#C6C6C6` | body of a container background |
| Panel shadow | `#555555` | 1px bottom + right edge of a raised panel |
| Slot well / recessed face | `#8B8B8B` | inside of a slot, recessed groove |
| Deep shadow / outline | `#373737` | outer 1px border, recessed top-left bevel |
| Near-black | `#212121` | deepest outline |

## 3. Source-verified color constants ★★★

These are read out of decompiled vanilla. Prefer them over any palette guide.

| Purpose | Source int | Hex ARGB | Where |
|---|---|---|---|
| Container label text | `4210752` | **`0x404040`**, `dropShadow = false` | `AbstractContainerScreen#renderLabels` |
| Widget text, enabled | `16777215` | `0xFFFFFF` | `AbstractButton` |
| Widget text, disabled | `10526880` | **`0xA0A0A0`** | `AbstractButton` |
| Slot hover highlight (≤1.21.1) | `-2130706433` | **`0x80FFFFFF`** | `AbstractContainerScreen#renderSlotHighlight` |
| Tooltip background | `-267386864` | **`0xF0100010`** | `TooltipRenderUtil.BACKGROUND_COLOR` |
| Tooltip border, top | `1347420415` | **`0x505000FF`** | `START_Y_BORDER_COLOR` |
| Tooltip border, bottom | `1344798847` | **`0x5028007F`** | `END_Y_BORDER_COLOR` |
| In-game screen dim, top | `-1072689136` | **`0xC0101010`** | `Screen#renderInGameBackground` |
| In-game screen dim, bottom | `-804253680` | **`0xD0101010`** | same `fillGradient` |
| List row selected, focused | `-1` | `0xFFFFFFFF` | `AbstractSelectionList` |
| List row selected, unfocused | `-8355712` | `0xFF808080` | same |
| List row selected, fill | `-16777216` | `0xFF000000` | `renderSelection` |

> 1.21.2 replaced the flat slot-highlight fill with sprites `container/slot_highlight_back` +
> `container/slot_highlight_front` "so that item texture has better visibility"; the old fill moved
> to the Programmer Art pack. ★★★

> **House rule:** write every UI color literal as 8-digit `0xAARRGGBB` on **every** band. From 1.21.6
> a color without alpha renders *nothing* (silently), and 26.1 is strict. Writing `0xFF404040`
> everywhere makes one source file correct from 1.20.1 to 26.3 (and 26.4-snapshot-8).

### The two text modes

| Mode | Where vanilla uses it | When you use it |
|---|---|---|
| **Shadowed white** `0xFFFFFFFF` + shadow | HUD, tooltips, buttons, chat — anything over the **world** | Any text over a background you don't control |
| **Flat dark gray** `0xFF404040`, no shadow | container-screen labels: the title, "Inventory" | Any text on your own light panel |

Getting this backwards — shadowed white on a light panel — is the most common "this GUI looks wrong"
symptom, *and* a contrast failure (white on `#C6C6C6` is ≈1.4:1, far under the 4.5:1 floor).

## 4. Color restraint

Vanilla's chroma budget is tiny, and color in vanilla is almost always **redundant**: the heart is red
*and* heart-shaped; the advancement frame is a different **shape** per tier, not just a tint.

**Budget yourself one accent hue for the whole mod**, used only for state and identity, never
decoration. Create uses brass/copper; Botania a green-to-pink flower spectrum; AE2 the terminal's
cable color. One idea, applied consistently.

---

## 5. Container screens — the numbers ★★★

From decompiled `AbstractContainerScreen` and `InventoryMenu`.

| Field | Default | Note |
|---|---|---|
| `imageWidth` | **176** | `DEFAULT_IMAGE_WIDTH`; **final** and ctor-supplied from 26.1 |
| `imageHeight` | **166** | `DEFAULT_IMAGE_HEIGHT` |
| `leftPos` | `(width - imageWidth) / 2` | set in `init()` |
| `topPos` | `(height - imageHeight) / 2` | |
| `titleLabelX` / `titleLabelY` | **8** / **6** | |
| `inventoryLabelX` | **8** | |
| `inventoryLabelY` | **`imageHeight - 94`** → 72 at 166 | **computed in the ctor from the default 166** — if you set `imageHeight` afterwards you must recompute this yourself |

`renderLabels` runs inside a pose already translated by `(leftPos, topPos)`. **Do not add them again.**

### Player-inventory slot geometry (verbatim from `InventoryMenu`)

```java
// 3×9 main inventory
addSlot(new Slot(inv, col + (row + 1) * 9, 8 + col * 18, 84 + row * 18));
// hotbar
addSlot(new Slot(inv, i, 8 + i * 18, 142));
// armor column (top-left)
addSlot(new ArmorSlot(..., 8, 8 + i * 18, ...));
// 2×2 crafting grid + result + offhand
addSlot(new Slot(craftInput, j + i * 2, 98 + j * 18, 18 + i * 18));
addSlot(new CraftingResultSlot(..., 154, 28));
addSlot(new Slot(inv, 40, 77, 62));
```

| Constant | Value |
|---|---|
| Slot pitch | **18** |
| Slot item area | **16 × 16** (frame is 1px on each side; `slot.x/y` is the **item** top-left, frame at `x−1,y−1`) |
| Main-inventory origin | `x = 8`, `y = 84` in a 166-tall GUI |
| Hotbar row | `y = 142` |
| Gap main-inv → hotbar | **22** (one 18px row + 4) |
| Generic, GUI of height `H` | main rows at `H − 82`, hotbar at `H − 24` ★★ derived |

Slot render seed is `slot.x + slot.y * imageWidth`.

> **26.4 preview (26.4-snapshot-8, ★★★ jar, subject to change).** Each slot is drawn by a `SlotWidget`
> of exactly the same geometry — **18 × 18 with a 1 px border**, quick-craft tint `0x80FFFFFF` — so the
> pitch, origins and frame math above are unchanged. What is new is that a slot can be **keyboard
> focused**: give every slot a meaningful `Slot.Section` (`EQUIPMENT`, `CONTAINER`, `INPUT`,
> `SECOND_INPUT`, `FUEL`, `RESULT`, `INVENTORY`, `HOTBAR`) so Tab moves between groups in the vanilla
> order and the narrator can name the group. In keyboard mode the carried item is drawn offset by
> 2 px (`KEYBOARD_CARRIED_ITEM_OFFSET`). See `screen-widget-api.md` §5.6.1.

## 6. Buttons and widgets ★★★

```java
public static final int DEFAULT_WIDTH_SMALL = 120;
public static final int DEFAULT_WIDTH       = 150;   // builder default
public static final int BIG_WIDTH           = 200;   // menu width
public static final int DEFAULT_HEIGHT      = 20;    // builder default
```

| State | 1.20.2+ sprite | 1.20.1 `widgets.png` v-offset | Text color |
|---|---|---|---|
| Disabled (`!active`) | `widget/button_disabled` | **46** | `0xA0A0A0` |
| Idle | `widget/button` | **66** | `0xFFFFFF` |
| Hovered **or focused** | `widget/button_highlighted` | **86** | `0xFFFFFF` |

> **There is no separate focus sprite in vanilla.** `isSelected() = isHovered() || isFocused()`, so
> hover and keyboard focus share one texture. Focus is otherwise communicated by the narrator and,
> in some subclasses, `AbstractWidget#renderFocusBorder`. If your UI must be keyboard-navigable and
> legible (it must — see `accessibility.md`), **add a distinct focus ring yourself.**
>
> **26.4 preview (26.4-snapshot-8, ★★★, subject to change):** the highlight condition becomes
> `isHighlighted()` — *hovered* when the last input was the mouse, *focused* when it was the keyboard
> (`InputType.KEYBOARD_SELECTION`), never both. The cursor hides in keyboard mode and returns after
> 7 px of mouse movement, and hovered list entries get a grey outline. Still one shared sprite, but a
> keyboard user now sees exactly one highlighted control. Match it: drive your custom highlight from
> `isHighlighted()` on 26.4 and keep a distinct focus ring on earlier bands.

### Text placement inside a widget

```java
int j = (startY + endY - 9) / 2 + 1;   // baseline-top y
```
For a 20px-tall button: `j = 6`. **Text top sits 6px below the widget top.** Buttons draw *with*
shadow. Default horizontal margin is 2. **Over-long labels marquee-scroll, they do not ellipsize** —
`AbstractWidget#renderScrollingString` is `protected static`, so you can call it directly.

| Widget | Facts |
|---|---|
| Slider | handle **8px** wide, inset 4px; sprites `widget/slider{,_highlighted}`, `widget/slider_handle{,_highlighted}` |
| Text field | nine-slice, border 1; `widget/text_field{,_highlighted}` |
| Scrollbar | **6px** wide; `widget/scroller`, `widget/scroller_background` |
| List selection | outline `0xFFFFFFFF` focused / `0xFF808080` not; inner `0xFF000000`; extends 2px above and below the row |
| Header/footer band | `HeaderAndFooterLayout.DEFAULT_HEADER_AND_FOOTER_HEIGHT = 33`; `MAGIC_PADDING = 13`; content top margin **30** (`CONTENT_MARGIN_TOP`, private ≤26.3; `public DEFAULT_CONTENT_MARGIN_TOP` + `setContentMarginTop(int)` on 26.4-s8) |

## 7. Spacing conventions ★★★

| Convention | Value |
|---|---|
| Main-menu button block | `x = width/2 − 100`, 200 × 20 |
| Main-menu first button y | **`height / 4 + 48`** |
| Main-menu vertical pitch | **24** (20 button + **4** gap) |
| Title-screen bottom row | two 98-wide buttons at `width/2 − 100` and `width/2 + 2` → **4px gutter** |
| Two-button confirm row | `width/2 − 155` and `width/2 + 5`, 150 × 20 each → **10px gutter**, 310 total |
| Options list row | content width **310**, row height **25** |
| Options two-column grid | `WIDGET_X_SPACING = 160`, first column at `width/2 − 155`, widgets 150 wide |
| Confirm-screen title bottom margin | **20** |

**The real vanilla grid:** 20px control height, **4px** inter-control gap in vertical stacks,
**8–10px** gutters in horizontal pairs, canonical widths **120 / 150 / 200 / 310**, everything centred
on `width/2`. The commonly-cited "4/8px grid" is accurate; 18 (slot pitch) and 20 (button) are the two
odd ones out.

## 8. Z / layering ★★★

| Layer | z |
|---|---|
| Screen background / widgets | 0 |
| Container item **model** | **150** |
| Item **decorations** (count, durability, cooldown) | **200** |
| Dragged/held stack | 100 / 200 / 500 constants in `AbstractContainerScreen` |
| **Tooltip** | **400** |

```java
// ≤1.21.5 idiom — ALWAYS restore
graphics.pose().pushPose();
graphics.pose().translate(0, 0, 300);
…
graphics.pose().popPose();
```

**From 1.21.6 this idiom is gone.** `pose()` is a 2D `Matrix3x2fStack` with no z at all. Ordering is
strata + bounds + sort key; use `nextStratum()` and `setTooltipForNextFrame(...)`. See
`render-pipeline.md` §2.2.

## 9. Text metrics ★★★

| Fact | Value |
|---|---|
| `Font.lineHeight` | **9** (`public final int lineHeight = 9`) |
| Wrapped-text height | `9 × lines` — no extra leading |
| Drop shadow offset, default font | **+1 px right, +1 px down** |
| Drop shadow offset, unihex/uniform | **0.5 px** |
| Shadow color | RGB × **0.25** |
| `drawString` return (≤1.21.5) | `x + (shadow ? 1 : 0)` — the shadow adds 1 to reported width |
| Character widths | **variable, not monospace** |
| Built-in letter spacing | **+1 px** baked into every bitmap glyph's advance |
| Space advance | **4 px** |
| Uniform (unihex) advance | `width/2 + 1` — **half-pixel** |

**Measure, never assume.** `Font#width(...)`; trim with `plainSubstrByWidth` / `trimToWidth`; wrap with
`Font#split(text, maxWidth)` or `GuiGraphics#drawWordWrap` (26.x `textWithWordWrap`, which returns the
next free y from 26.3 — stack paragraphs with it instead of re-measuring). For rough capacity planning only, assume
**~6 px/char** in the default font (★).

## 10. Tooltip box geometry ★★★

```java
int i = x - 3, j = y - 3;                 // 3px padding on every side
int k = width + 6, l = height + 6;
// + a 1px background lip on each of the four sides (total 4px text→outer edge)
renderBorder(ctx, i, j + 1, k, l, z, 0x505000FF, 0x5028007F);   // 1px vertical-gradient border
```
**The first-line gap — changed at 26.3** ★★★ (bytecode):

| Band | Multi-line tooltip | Single-line tooltip |
|---|---|---|
| ≤26.2 | **2 px** gap between line 1 and line 2, always | height − 2 |
| 26.3+ | 2 px gap **only when `extraSpaceAfterFirstLine` is true** — i.e. item tooltips; text/widget tooltips get no gap and the −2 trim, so they are **4 px shorter** than on 26.2 | height − 2 |

Design rule: on 26.3+ the title gap *means* "this is an item". For a non-item tooltip that should read
as title + body (a machine readout, a slot preview), pass `extraSpaceAfterFirstLine = true`; for plain
help text leave it off and let it be compact. Bug MC-313103 (gap misplaced when an item name wraps) is
open on 26.4-snapshot-8, so expect further tweaks.

## 11. Screen backgrounds — changed materially at 1.20.5 ★★★

```java
// 1.21.1
public void renderBackground(GuiGraphics g, int mx, int my, float dt) {
    if (mc.level == null) renderPanorama(g, dt);
    applyBlur(dt);            // the "frosted glass" pass
    renderMenuBackground(g);  // tiles menu_background.png at 32×32
}
public void renderInGameBackground(GuiGraphics g) {          // container-style screens
    g.fillGradient(0, 0, width, height, 0xC0101010, 0xD0101010);
}
```

- **Pre-1.20.5:** the dirt tile `options_background.png` (32×32) out of world, or the
  `0xC0101010 → 0xD0101010` gradient in world.
- **1.20.5+:** dirt replaced by semi-transparent `menu_background.png` / `inworld_menu_background.png`
  (still 32×32 tiles) plus a blur. Blur strength is the **Menu Background Blur** accessibility slider
  (`MenuBlurRadius` uniform, 0–10). **In-game screens — containers, book — are explicitly not blurred.**
- List backgrounds: `menu_list_background.png` / `inworld_menu_list_background.png`, also 32×32.

---

## 12. Match vanilla, or brand? The actual argument

Three legitimate positions. **Pick one per mod and never mix them within a screen.**

**A. Vanilla-identical.** Reuse vanilla widget sprites and container conventions verbatim; your
screen is a chest with different slot semantics.
*Right when:* the mod is small, utility-flavored, or destined for kitchen-sink packs.
*Cost:* zero recognition. *Benefit:* **free correctness** — resource packs that retexture vanilla GUI
retexture yours too, **including the built-in High Contrast pack** and its community extensions. That
is a real accessibility argument and it is badly underrated.

**B. Vanilla-grammar, mod-vocabulary.** Same bevels, same 18px slot pitch, same 9px type, same
flatness — your own palette and frame motif. *This is the default correct answer for a flagship mod.*
Create does it (brass/copper, coherent enough that fans ship packs converting *vanilla* to it);
Mekanism does it (dark industrial panels, a fixed vertical energy meter on the right, side-config
button always upper-left on **every** machine).

**C. Diegetic — no GUI at all.** Put the interface in the world. Botania is the extreme case: mana
beams arc visibly between spreaders and pools; automation is droppers and timing, not screens.
Immersive Engineering does it at industrial scale (hanging powerlines, a 5×3×3 crusher with rotating
wheels). Create's Engineer's Goggles are the hybrid: a *contextual* overlay showing rotation direction
by particle motion and speed by color.

Diegetic is the most Minecraft-native answer and the highest-skill one. It fails hardest when the
information genuinely is numeric ("how much RF is buffered?"), and its known trap is smuggling the
clutter back in as floating world labels. **Use it for relations and flow; use a screen for values and
configuration.**

### Where deviating from vanilla is *right*

- **Density-driven layouts.** A storage terminal genuinely needs more than 176px. Refined Storage lets
  the Grid stretch with a `maxRowsStretch` cap; AE2 does not, and has an open accessibility complaint
  about GUI scale 4 as a result. Stretching is not a style violation — it's the correct deviation.
- **Reading surfaces.** Guidebooks legitimately use a parchment two-page frame; they're a different
  kind of object.
- **Animated teaching surfaces.** Create's Ponder renders a live 3D scene in a screen. Nothing in
  vanilla looks like it. It's right anyway, because it does something vanilla never attempts.

---

## 13. GUI scale and the smallest canvas (26.3 SDL) ★★★

The GUI-scale formula is **byte-identical** from 26.2 to 26.4-snapshot-8: an integer scale computed
from physical framebuffer pixels with a **320 × 240** floor. 26.3 (SDL3) additionally enforces
`Window.MIN_WINDOW_WIDTH/HEIGHT = 320 × 240` on the window itself.

- **Your smallest canvas is 320 × 240 GUI pixels.** A 176 × 166 container fits; a 310-wide options
  row fits with 5 px to spare. Anything wider must scroll, stretch or wrap (see `accessibility.md`).
- **Do not scale by pixel density.** `Window.getPixelDensity()` exists on 26.3 but vanilla uses it
  only for the IME rectangle and F3 specs; density is already folded into the framebuffer and the
  integer GUI scale. Multiplying by it double-scales your UI on Retina/HiDPI.
- HiDPI screens get a higher *auto* scale (as under GLFW on macOS); native Wayland with fractional
  scaling should too ★ (not tested on hardware).
- 26.3 also gives the F3 overlay its own scale (`debugGuiScale`, default *Auto*) — don't assume F3 text
  is drawn at the player's GUI scale.

---

## Quick-reference card

```
Container:  176×166 on a 256×256 sheet · leftPos=(w-176)/2 · topPos=(h-166)/2
Labels:     title (8,6) 0xFF404040 no-shadow · inv label (8, imageHeight-94) same
Slots:      pitch 18 · item 16×16 · 1px frame · main inv (8, H-82) · hotbar (8, H-24)
Buttons:    200×20 menu / 150×20 options / 120×20 small · text top = y+6, shadowed
            idle 0xFFFFFF · disabled 0xA0A0A0 · hover == focus (no separate sprite!)
Menu:       first button y = height/4 + 48 · pitch 24 · x = width/2 - 100
Confirm:    x = w/2-155 and w/2+5 · 150×20 each · gutter 10
Colors:     tooltip bg F0100010 · border 505000FF→5028007F · pad 3 + 1px lip
            slot hover 80FFFFFF · in-game dim C0101010→D0101010
Tooltip:    title gap 2px — always ≤26.2 · item tooltips only 26.3+ (extraSpaceAfterFirstLine)
Z:          item 150 · item overlay 200 · tooltip 400      (≤1.21.5 ONLY)
Text:       lineHeight 9 · shadow +1px (unihex +0.5) · space 4 · advance = glyph+1
Bevel:      raised = light TL / dark BR · recessed = inverted
Canvas:     min 320×240 GUI px · integer GUI scale · never × pixelDensity (26.3 SDL)
Highlight:  hover == focus ≤26.3 · 26.4-s8 isHighlighted() follows last input type
Stability:  all metrics/colors/sprites/fonts above unchanged 26.2 → 26.3 → 26.4-snapshot-8
```

---

## Could not verify

1. **The panel palette in §2** is derived from vanilla art, not a source constant (★★); not re-derived
   for 26.3/26.4.
2. **26.4 rows are snapshot-8 only** and can change before the 26.4 release; the s7 jar was not diffed
   separately.
3. **Runtime appearance** — nothing was rendered for the 26.3/26.4 refresh: the 26.4 grey hover
   outline color on list entries, the keyboard-mode carried-item look, and the F3 *Auto* debug scale
   value were read from constants/patch notes, not screenshots.
4. **HiDPI auto-scale per OS under SDL** (Wayland fractional scaling, Windows per-monitor DPI, macOS
   Retina) is inferred from SDL defaults ★.
5. **Visual intent of the 26.3/26.4 shader edits** (`box_blur.fsh`, GUI/text shaders gaining
   `layout(location)`) — no visual change is stated by Mojang; none was measured.
