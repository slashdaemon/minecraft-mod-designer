# GUI assets — sprites, nine-slice, fonts, GUI scale, packs, localization

Confidence: ★★★ verified in decompiled vanilla source or a primary Mojang artifact ·
★★ corroborated secondary source · ★ convention/inference.

Status as of **2026-11-11**: re-verified against the 26.2, 26.3 and 26.4-snapshot-8 client jars
(sprites, `.mcmeta`, fonts, `Window`). Sprites, nine-slice values and fonts are unchanged through
26.4-s8; what moved is the draw-call pipeline type (§1.4), F3+T in early 26.4 snapshots (§1.6), the
SDL3 window/scale plumbing (§4.3–4.3a) and pack formats (§6.1).

---

## 1. The GUI sprite system

### 1.1 When it landed

| Event | Version | `pack_format` |
|---|---|---|
| GUI sheets split into `textures/gui/sprites/**`; `gui` `.mcmeta` section with `scaling` | **23w31a** (1.20.2 cycle) | 16 |
| Shipped in a release | **1.20.2** | 18 |
| `stretch_inner` added to `nine_slice` | **24w33a** (1.21.2 cycle) | 35 |
| gui atlas gains 1px padding on all four sides | **25w44a** (1.21.11) | 74.0 |
| Mob-effect icons folded into the gui atlas | **25w19a** (1.21.6) | — |

### 1.2 Layout on disk

```
assets/<ns>/
├── atlases/gui.json                 # usually unnecessary — see §1.5
└── textures/gui/
    ├── sprites/                     # → stitched into the gui atlas
    │   ├── widget/button.png  +  widget/button.png.mcmeta
    │   ├── container/… hud/… icon/… toast/…
    │   └── tooltip/background.png(.mcmeta)
    ├── container/inventory.png      # NOT a sprite — plain 256×256 blit target
    └── menu_background.png          # NOT a sprite — tiled 32×32
```

A sprite's **id** is its path under `textures/gui/sprites/` minus `.png`:
`widget/button.png` → `minecraft:widget/button`.

### 1.3 The `gui` `.mcmeta` schema ★★★

```jsonc
{
  "gui": {
    "scaling": {
      "type": "nine_slice",       // "stretch" (default) | "tile" | "nine_slice"
      "width":  200,              // REQUIRED for tile + nine_slice; ≥1; keep == real PNG size
      "height": 20,
      "border": 3,                // nine_slice only: positive int, OR the 4-field object
      // "border": { "left": 1, "top": 1, "right": 1, "bottom": 1 },   // 0 allowed here
      "stretch_inner": false      // nine_slice only, 1.21.2+; default false
    }
  }
}
```

Codec facts from `net.minecraft.client.renderer.texture.SpriteScaling`:

- `width`/`height` are `POSITIVE_INT` → **must be ≥ 1**.
- Uniform `border` is `POSITIVE_INT` (**≥ 1**); the four-field object form is `NONNEGATIVE_INT`
  (**0 allowed**). So `"border": 0` is a load error but `{"left":0,…}` is legal.
- Load-time validation, verbatim error strings:
  - `Nine-sliced texture has no horizontal center slice: <left> + <right> >= <width>`
  - `Nine-sliced texture has no vertical center slice: <top> + <bottom> >= <height>`
- No `.mcmeta` at all ⇒ `stretch`.

Real vanilla values ★★★:

| Sprite | w | h | border |
|---|---|---|---|
| `widget/button` (+ `_disabled`, `_highlighted`) | 200 | 20 | **3** |
| `widget/slider`, `widget/slider_highlighted` | 200 | 20 | 1 |
| `widget/text_field`, `_highlighted` | 200 | 20 | 1 |
| `tooltip/background` | 100 | 100 | 9 |
| `container/bundle/bundle_progressbar_fill` | 6 | 6 | 2 |
| `widget/slider_handle` | 8 | 20 | {2,2,2,3} |
| `widget/scroller` | 6 | 32 | 1 |
| `widget/tab` | 130 | 24 | {2,2,2,0} |
| `tooltip/frame` | 100 | 100 | 10, `stretch_inner` |
| slot highlight (`SLOT_HIGHLIGHT_BACK/FRONT_SPRITE`) | 24 | 24 | 4 |
| `toast/system` | 160 | 64 | {17,30,4,4} |
| `popup/background` | 236 | 34 | 6 |

**All core widget sprites and nine-slice values are unchanged 26.2 → 26.3 → 26.4-snapshot-8** ★★★
(jar `.mcmeta` diff, 2026-11-11). The sprite churn is vanilla-specific chrome:
- 26.3 added `widget/realms_button` (200×20, border 3; `_disabled` 1; `_highlighted` 3).
- 26.4-s8 removed `friends/button*`, `friends/loading`, `friends/remove`,
  `pause_menu/player_reporting`, `pause_menu/social_interactions`, `toast/social_interactions`; added
  `friends/tab{,_focused,_highlighted,_selected}` (200×20 nine_slice, borders 3/1/3/1), several 16×16
  `friends/*` icons, `pause_menu/feedback` (20×20), `pause_menu/other_players` (16×16), and
  **`widget/loading`** (5×6, an animated strip: frames 5×2, frametime 6) used by the new
  `LoadingButton`. Don't build on the Friends sprites; they are still moving.

### 1.4 Sprite drawing API per band

| Band | Sprite call | Raw blit |
|---|---|---|
| **1.20.1** | *does not exist* | `blit(rl, x, y, u, v, w, h)` (hard-codes 256×256) + `blitNineSliced` / `blitRepeating` |
| 1.20.2–1.21.1 | `blitSprite(ResourceLocation, x, y, w, h)` | as above |
| 1.21.2–1.21.5 | `blitSprite(RenderType::guiTextured, rl, …)` | `blit(RenderType::guiTextured, rl, x, y, u, v, w, h, 256, 256)` — **size mandatory** |
| 1.21.6–1.21.11 | `blitSprite(RenderPipelines.GUI_TEXTURED, rl, …)` | `blit(RenderPipeline, …)` |
| **26.1–26.2** | `GuiGraphicsExtractor#blitSprite(RenderPipeline, Identifier, …)` | same |
| **26.3** | same shape; `RenderPipeline` is now `com.mojang.renderpearl.api.pipeline.RenderPipeline` (package move only) | same |
| *26.4 snapshots* | `blitSprite(GuiPipeline, Identifier, …)` — e.g. `GuiPipeline.TEXTURED` where 26.3 used `RenderPipelines.GUI_TEXTURED` (mapping ★, from field names) | `blit(GuiPipeline, …)` |

The **4/5-arg** `blitSprite` forms honour the sprite's `scaling`. The **9/10-arg** sub-region forms
**ignore scaling** — vanilla falls back to a plain stretch draw for non-stretch sprites in that path. ★★★

**1.20.1 nine-slice** (verbatim from vanilla `AbstractButton#renderWidget`) ★★★:

```java
guiGraphics.blitNineSliced(WIDGETS_LOCATION,       // textures/gui/widgets.png
        getX(), getY(), getWidth(), getHeight(),
        20,                 // sliceWidth  (left/right cap)
        4,                  // sliceHeight (top/bottom cap)
        200, 20,            // uWidth, vHeight — region in the sheet
        0, getTextureY());  // uOffset, vOffset: 46 disabled / 66 idle / 86 hover+focus
```

### 1.5 `atlases/gui.json` — you almost certainly don't need one ★★★

Vanilla, verbatim:

```json
{ "sources": [ { "type": "minecraft:directory", "prefix": "", "source": "gui/sprites" } ] }
```

Because `source` is `gui/sprites` and `prefix` is empty, **every namespace's**
`textures/gui/sprites/**` is swept in automatically. Dropping PNGs under
`assets/<modid>/textures/gui/sprites/` is enough — nine-slice, atlas stitching, and per-sprite
resource-pack overridability all come for free.

The escape hatch, if you want to keep a legacy sheet on disk but expose named sub-regions:

```json
{ "sources": [{
    "type": "minecraft:unstitch",
    "resource": "mymod:gui/legacy_widgets",
    "divisor_x": 256, "divisor_y": 256,
    "regions": [ { "sprite": "mymod:widget/panel", "x": 0, "y": 0, "width": 64, "height": 64 } ]
}]}
```

Other source types: `minecraft:directory`, `minecraft:single`, `minecraft:filter`,
`minecraft:paletted_permutations`.

### 1.6 Atlas facts ★★★

| Property | Value |
|---|---|
| Dumped name | `gui.png-atlas` (via `-Dminecraft.dumpAtlas`) |
| Typical size | 1024 × 512 |
| Mipmapping | **No** |
| Padding between sprites | **none** pre-1.21.11; **1px on all four sides** from 25w44a |
| Nine-slice `border ≥ 230` | integer overflow → samples unrelated atlas regions |
| Hot reload (F3+T) | re-stitches the gui atlas on 26.3. **Broken in 26.4 snapshots up to s7** (MC-312955 "GUI textures are not reloaded without relaunching the game"); **fixed in 26.4-snapshot-8** ★★ |

### 1.7 What moved into sprites, what stayed ★★

**Moved (1.20.2):** `widgets.png`, `icons.png` (HUD hearts/armor/food/xp/crosshair), `bars.png`,
`spectator_widgets.png`, `recipe_book.png`, `toasts.png`, `stats_icons.png`,
`advancements/widgets.png`, `world_selection.png`, `server_selection.png`, `resource_packs.png`,
`social_interactions.png`, creative-inventory tabs, beacon buttons, and the whole former `realms`
namespace.

**Stayed as single PNGs:** everything in `textures/gui/container/*.png` (anvil, beacon, furnace,
**inventory**, generic_54, hopper, loom, smithing, stonecutter, villager, …), sign edit backgrounds,
advancement background tiles, `title/*` panoramas + logo, `menu_background.png`,
`menu_list_background.png`, `book.png`, `demo_background.png`.

> **Practical rule:** *container backgrounds are still raw blits; chrome and widgets are sprites.*
> A modded container screen on 1.20.2+ still ships a 256×256 `textures/gui/container/foo.png` and
> calls `blit`, exactly as on 1.20.1.

### 1.8 What a 1.20.1 modder does instead

- One PNG, canonically **256×256** so the 6-arg `blit` works (it hard-codes `256, 256`).
- UV math by hand. Non-256 sheets need the 9-arg `blit(rl, x, y, u, v, w, h, texW, texH)`.
- Scalable panels: `blitNineSliced` / `blitRepeating` (both exist in 1.20.1).
- Resource packs targeting your mod must replace the **whole sheet** — no per-sprite override.

---

## 2. Nine-slice math

### 2.1 Exactly what MC does ★★★

Let `SW,SH` = declared size; `L,T,R,B` = border sides; `W,H` = requested draw size.

1. `W == SW && H == SH` → single 1:1 draw, no slicing.
2. `H == SH` → left cap `L×H`, **tiled** middle `(W−L−R)×H`, right cap `R×H`.
3. `W == SW` → top cap `W×T`, **tiled** middle `W×(H−T−B)`, bottom cap `W×B`.
4. Both differ → 4 corners 1:1, 4 edges **tiled** along their axis, center **tiled** both ways.

> **The edges and the center TILE, they do not stretch** — unlike CSS `border-image`, which stretches
> by default. This is the single most common authoring surprise. `stretch_inner: true` (1.21.2+)
> flips edges+center to stretch.

The tiler walks in `tileWidth`/`tileHeight` steps and **clips the final partial tile**
(`min(tile, remaining)`), so a non-multiple size cuts the last tile rather than squashing it.

### 2.2 Authoring mistakes, ranked by frequency

| Mistake | Symptom | Fix |
|---|---|---|
| Assuming edges stretch | repeating/stuttering seams when scaled | design edges as **tileable**, or `stretch_inner: true` |
| `width`/`height` ≠ real PNG size | wrong sub-rect; neighbouring atlas art bleeds in | keep them equal to the PNG's pixel size |
| `left + right >= width` | pack fails to load | leave ≥1px of centre on each axis |
| `"border": 0` | codec error | use the four-field object form |
| Drawing smaller than `L+R` / `T+B` | corners overlap and clip | enforce a widget minimum size in code |
| `border ≥ 230` | random atlas garbage | keep borders ≤ ~16 |
| Gradient/AA in the tiled centre | visible tiling banding | centre must be flat or a perfect tile |
| Nine-slice on a fixed-size icon | wasted atlas, added risk | use `stretch` / no `.mcmeta` |

### 2.3 Border values that work

| Element | Size | Border |
|---|---|---|
| Vanilla button | 200×20 | **3** (1px outline + 2px bevel) |
| Slider / text field | 200×20 | **1** |
| Tooltip background | 100×100 | **9** |
| **Mod panel** | 24×24 or 32×32 | **4–6** |
| **Mod inset / well** | 16×16 | **3** (matches vanilla slot depth) |
| **Mod button** | 200×20 | **3** (copy vanilla) |

Rule of thumb: **border = outline px + bevel px, and `2·border + 2 ≤ min(width, height)`.**

---

## 3. Fonts

### 3.1 Files and ids ★★★

```
assets/<ns>/font/<name>.json         # { "providers": [ … ] }
assets/<ns>/textures/font/<x>.png    # bitmap sheets
assets/<ns>/font/<x>.zip             # unihex .hex archives
```

`minecraft:default` = the UI font. `minecraft:uniform` = fallback / Force-Unicode font.
**`assets/minecraft/font/**` and `textures/font/**` are byte-identical on 26.2, 26.3 and
26.4-snapshot-8** ★★★, so everything in this section carries forward. The 26.3 text path change is
render-side: `Font#prepareBackground(...)` was added and the separate `text_background` shaders were
removed (text backgrounds render through the text shaders). NeoForge 26.3 deprecated its
`Font#enableTextTextureLinearFiltering` for removal.
`minecraft:alt` = Standard Galactic Alphabet. `minecraft:illageralt` = command-only.

```json
// vanilla default.json
{ "providers": [
  { "type": "reference", "id": "minecraft:include/space"   },
  { "type": "reference", "id": "minecraft:include/default" },
  { "type": "reference", "id": "minecraft:include/unifont" }
]}
```

### 3.2 Provider types ★★★

**`bitmap`**
```json
{ "type": "bitmap", "file": "mymod:font/icons.png",
  "height": 8,       // OPTIONAL, default 8 — the RENDERED px height
  "ascent": 7,       // REQUIRED — px above baseline; error if ascent > height
  "chars": [ "", "" ] }
```
The PNG is cut into an even grid (`cellW = imgW / rowLength`); non-divisible sizes are a load error.
`height` is the *drawn* height and the glyph is scaled by `height / cellH` — **this is the correct
way to ship crisp HD glyphs**: `height: 8` on a 16×16 cell renders a 2× source at 1× size.
Advance = `(int)(0.5 + measuredWidth × scale) + 1`; trailing transparent columns are trimmed.
` ` marks an unused cell.

**`space`** — pure advance table, draws nothing. **Negative advances are legal**, which is the
standard trick for backing the cursor up so a bitmap glyph can be layered over text.
```json
{ "type": "space", "advances": { " ": 4, "‌": 0, "": -1 } }
```

**`ttf`** — `file`, `size` (em divisor), `oversample`, `shift: [x,y]`, `skip`. Kerning and ligatures
are stripped on load. `.otf` accepted. ★★

**`unihex`** — `hex_file` (a ZIP of GNU Unifont `.hex`), `size_overrides` (force a codepoint range to
fixed `left`/`right` columns instead of auto-trimming).

**`reference`** — splices another font definition's providers in; loads once even if referenced twice.

**`filter`** (1.20.5) — an optional object on **any** provider gating it on a client option:
`{"uniform": true}` (only when Force Unicode Font is on), `{"jp": true}` (Japanese Glyph Variants).

**`legacy_unicode`** — removed as a provider in 23w17a / 1.20.

### 3.3 Custom icon fonts — a genuinely good UI technique ★★

The pattern used by *Icons*, *Symbol Chat*, and most modern packs:

1. Draw icons into a PNG grid at 1× (8×8 or 9×9 cells), or 2× with a matching `height`.
2. Assign **Private Use Area** codepoints (`U+E000`–`U+F8FF`).
3. Ship `assets/<modid>/font/icons.json` with a `bitmap` provider + a `space` provider for kerning.
4. Render:
```java
static final ResourceLocation ICON_FONT = ResourceLocation.fromNamespaceAndPath("mymod", "icons");
Component icon = Component.literal("").withStyle(s -> s.withFont(ICON_FONT));
Component label = Component.empty().append(icon).append(" ")
                           .append(Component.translatable("gui.mymod.power"));
```
5. Or add the provider to `minecraft:default` and icons work **inside translation strings with zero
   Java**: `"gui.mymod.power": " Power"`.

**26.x:** `Style#withFont` takes a `FontDescription`, e.g. `withFont(new FontDescription.Resource(loc))`. ★★

Gotchas ★:
- PUA codepoints collide between mods — pick a distinct block and document it.
- Icons are invisible to anything that re-styles the component (chat filters, some HUD mods).
- `Component#getString()` leaks PUA squares into logs and command output.
- **Never use a real Unicode glyph as an icon** (`⚡`, `❤`, `⛏`) — the narrator reads it as "high
  voltage sign" / "heavy black heart", and it renders differently under Force Unicode. See
  `accessibility.md`.

### 3.4 `default` vs `uniform`, and why Force Unicode breaks layouts ★★★

| | `default` (Mojangles) | `uniform` (GNU Unifont) |
|---|---|---|
| Source | `ascii.png` (ascent 7), `accented.png` (height 12, ascent 10), `nonlatin_european.png` (ascent 7) | `unifont.zip` / `unifont_jp.zip` |
| Advance | variable, `measured + 1` | `width/2 + 1` — **half-pixel** |
| Shadow / bold offset | 1.0 px | **0.5 px** |
| Coverage | Latin + Greek/Cyrillic/Hebrew/Armenian/Georgian | full BMP |

Why it breaks layouts:
- Half-integer advances mean a string measured at scale 1 renders at a **different pixel width** —
  every hand-tuned `x` offset drifts.
- Uniform is generally **wider** for Latin, so labels that just fit will overflow.
- **`Window#calculateScale` rounds the GUI scale UP to the next even number** when Force Unicode is
  on: `if (forceUnicodeFont && i % 2 != 0) i++;`. Scale 1→2, scale 3→4. The bump happens *after* the
  ≥320×240 loop, so it can push the logical viewport **below** the design floor: at 1280×720, auto
  gives 3 → bumped to 4 → logical **320×180**. Screens assuming 240 rows clip.

**Design rule:** measure with `font.width(...)` at draw time, never with a constant; size containers
from the measurement; test with Force Unicode ON at scale 2 and 4.

### 3.5 RTL / bidi ★★★

`Font#isBidirectional()` reflects the active `Language`. `Language#getVisualOrder(...)` runs bidi +
Arabic shaping and produces `FormattedCharSequence`s.

> **`Component` order ≠ glyph order.** Anything that measures or slices must operate on
> `FormattedCharSequence`, not on the raw `String`. `Font#split` already reorders.
> Right-aligning by `x - font.width(s)` is safe; slicing a `String` by index is not.

---

## 4. GUI scale

### 4.1 The algorithm (verbatim, `Window#calculateScale`) ★★★

```java
public int calculateScale(int guiScale, boolean forceUnicodeFont) {
    int i = 1;
    while (i != guiScale
        && i < this.framebufferWidth && i < this.framebufferHeight
        && this.framebufferWidth  / (i + 1) >= 320
        && this.framebufferHeight / (i + 1) >= 240) { i++; }
    if (forceUnicodeFont && i % 2 != 0) i++;
    return i;
}
```

- `guiScale == 0` is **Auto** → the loop runs to the cap.
- Closed form for Auto: **`max(1, min(⌊w/320⌋, ⌊h/240⌋))`**.
- Scale *n* needs at least **320n × 240n** framebuffer pixels, else it silently clamps down.

```java
// logical size is CEIL, not floor
this.guiScaledWidth  = ceil(framebufferWidth  / scale);
this.guiScaledHeight = ceil(framebufferHeight / scale);
```
**Never assume `guiWidth() * scale == framebufferWidth`** — the rightmost logical column and bottom row
can be partially off-screen.

### 4.2 Scale table ★★★

| Framebuffer | Auto | Logical | Max selectable |
|---|---|---|---|
| 854 × 480 (MC default window) | 2 | 427 × 240 | 2 |
| 1280 × 720 | **3** | 427 × 240 | **3** — scale 4 clamps to 3 |
| 1366 × 768 | 3 | 456 × 256 | 3 |
| 1920 × 1080 | **4** | 480 × 270 | 4 |
| 2560 × 1440 | 6 | 427 × 240 | 6 |
| 3440 × 1440 (ultrawide) | 6 | 574 × 240 | 6 |
| 3840 × 2160 | **9** | 427 × 240 | 9 |
| 3840 × 2160 at scale 1 | — | 3840 × 2160 | a 176px container is 4.6% of screen width |
| 1280 × 720 + Force Unicode | 3 → **4** | **320 × 180** | below the 240 design floor |

### 4.3 Minimum window size ★★★

**≤ 26.2 (GLFW):** vanilla calls `glfwSetWindowSizeLimits(handle, -1, -1, maxTex, maxTex)` — it sets
a **maximum**; `-1, -1` means **no minimum**, so 320×240 is only the per-scale-step reference there.
**26.3+ (SDL3):** `Window.MIN_WINDOW_WIDTH = 320` / `MIN_WINDOW_HEIGHT = 240` are **enforced on the
window** (new in 26.3) ★★★. Either way, treat **320 × 240 logical** as the design floor because it is
the smallest viewport any supported scale produces (Force Unicode can still push below it, §3.4).

### 4.3a GUI scale on SDL3 (26.3 / 26.4) ★★★

`calculateScale` is **byte-identical** on 26.3 and 26.4-snapshot-8, still computed from physical
framebuffer pixels with the 320 × 240 floor; `setGuiScale` uses `ceil(fbW / scale)` (same result).
What changed is where the numbers come from:

| Aspect | ≤ 26.2 (GLFW) | 26.3+ (SDL3) |
|---|---|---|
| Window flags | GLFW defaults | `SDL_WINDOW_RESIZABLE \| SDL_WINDOW_HIGH_PIXEL_DENSITY` |
| Framebuffer size | `glfwGetFramebufferSize` | `SDL_GetWindowSizeInPixels` (physical pixels) |
| Mouse → GUI coords | `x * guiScaledWidth / screenWidth` | same formula; SDL mouse positions are floats in window points |
| `Window.getPixelDensity()` | n/a | used **only** for the IME rectangle and F3 system specs |

- **Do not multiply by `getPixelDensity()` in GUI code** — density is already in the framebuffer.
  Use it only to convert GUI rectangles to OS window points (as the IME rectangle does).
- HiDPI/Retina screens still get a larger *auto* scale, as before. On Linux 26.3 prefers native
  Wayland; fractional-scale compositors should give a full-resolution framebuffer and so a higher auto
  scale than under XWayland (★, not tested).
- 26.3 added a separate **`debugGuiScale`** option (default Auto) for the F3 overlay only. Your HUD
  uses the normal GUI scale.

### 4.4 Designing for every scale

1. Anchor to `width`/`height`, never to constants: `x = this.width / 2 - w / 2`.
2. Assume **320 × 240 logical** worst case. 176×166 fits; 176×220 does not.
3. Use integer arithmetic for centring — `(width - imageWidth) / 2` truncates, exactly like vanilla.
   Matching it keeps your art pixel-aligned with vanilla's.
4. Never blit at fractional coordinates — nearest sampling gives a torn edge.
5. Content that must grow → nine-slice panels + `LinearLayout`/`GridLayout`, not a fixed background PNG.
6. `Screen#resize` re-runs `init()` — rebuild widgets; don't cache absolute positions across resizes.
7. **Test matrix:** scale 1 @ 4K · scale 2 @ 854×480 · scale 3 @ 1280×720 · scale 4 @ 1920×1080 ·
   Auto @ 2560×1440 · ultrawide · **each of those with Force Unicode ON**.

---

## 5. Texture authoring practicalities

| Topic | Rule |
|---|---|
| Power-of-two | **Not required** for sprites — the stitcher packs arbitrary sizes. Raw blit targets are 256×256 by convention because the 6-arg `blit` hard-codes it. ★★★ |
| Mipmaps | The gui atlas does **not** mip. Don't author for it. ★★★ |
| Filtering | Nearest. `blur` defaults `false`; set it only for deliberately soft art via `<file>.png.mcmeta` `{"texture":{"blur":false,"clamp":false}}`. ★★★ |
| PNG format | 32-bit RGBA8. Author straight (**non-premultiplied**) alpha; export with "no premultiply". ★★ |
| Transparent pixels | Must still carry sane RGB matching their neighbours, or atlas operations pull black/white halos. ★ |
| Atlas bleeding | Zero padding pre-1.21.11; 1px from 25w44a. Never rely on sampling outside the declared rect. ★★★ |
| Non-integer scale | GUI scale is always an integer, so nearest is exact and pixels stay crisp — **unless you scale in your own pose**. Avoid `pose().scale(1.5f, 1.5f)`. ★★★ |
| HiDPI | macOS Retina reports a 2× framebuffer; MC's scale math uses framebuffer pixels. Don't compute from `getWidth()` (window units) when you meant `getFramebufferWidth()`. ★★ |

### Source resolution: 1× vs "HD" ★★

**Author GUI art at 1×.** Why HD GUI packs look wrong:

1. GUI scale is an integer multiplier on the *logical* grid. A 2× texture drawn into a 1×-sized rect
   is downsampled **nearest-neighbour with no mipmaps** — it drops every other row/column. There is no
   `gui_scale`-aware LOD for GUI sprites.
2. The atlas has no mip chain, so there is no correctly-filtered smaller copy to fall back to.
3. Vanilla's layout constants (18 slot, 20 button, 9 line height, 6 scrollbar) are logical pixels. HD
   art has to land on those boundaries anyway, so the resolution buys nothing structural.
4. Nine-slice borders are in the sprite's declared space: a 4× sprite needs `border: 12` to look like
   vanilla's `3`, and the *tiled* edges then repeat at 4× the frequency.

**The one correct way to ship HD art** is a `bitmap` font provider with a large cell and a small
`height` — the font pipeline does the downscale properly. For sprites there is no equivalent.
If you must ship HD, do it as a **separate opt-in resource pack** at exactly 2× or 4× (never 3× or
1.5×), keeping 1× as the mod's built-in default.

---

## 6. `pack_format` and mod assets

### 6.1 Format table, 1.20.1 → 26.4-snapshot-8 ★★★

| Format | Versions |
|---|---|
| **15** | 23w17a – **1.20.1** |
| 16 | 23w31a *(GUI sprite split)* |
| **18** | **1.20.2** |
| **22** | **1.20.3 / 1.20.4** |
| 26 | 24w06a *(font `filter` added)* |
| 28 | 24w09a *(menu background + blur)* |
| **32** | **1.20.5 / 1.20.6** |
| **34** | **1.21 / 1.21.1** |
| 35 | 24w33a *(`stretch_inner` added)* |
| **42** | **1.21.2 / 1.21.3** |
| **46** | **1.21.4** |
| **55** | **1.21.5** |
| **63** | **1.21.6 / 1.21.7** |
| **64** | **1.21.8** |
| **69.0** | **1.21.9 / 1.21.10** |
| 74.0 | 25w44a *(gui atlas padding)* |
| **75.0** | **1.21.11** |
| **84.0** | **26.1 / 26.1.1 / 26.1.2** |
| **88.0** | **26.2** |
| 89.0 – 97.x | 26.3 snapshots |
| *(not re-verified)* | **26.3** release — read `pack_version.resource` in the client jar's `version.json` |
| **103.0** | **26.4-snapshot-8** (data pack 127.0) — preview, will move ★★ (patch notes) |

> **From 65.0 (25w31a) pack formats are `major.minor` floats, not plain ints.** Write them as numbers
> (`"pack_format": 88.0`) and expect int-assuming tooling to break.
>
> **From 1.21.9 data packs** use `min_format` / `max_format` instead of `pack_format`. Resource packs
> kept `pack_format` + `supported_formats`.

### 6.2 `supported_formats` and overlays ★★

```json
{
  "pack": {
    "pack_format": 34,
    "supported_formats": { "min_inclusive": 18, "max_inclusive": 46 },
    "description": [{ "text": "My Mod GUI", "color": "gold" }]
  },
  "overlays": { "entries": [
    { "formats": { "min_inclusive": 42, "max_inclusive": 46 }, "directory": "post_1_21_2" }
  ]}
}
```
`supported_formats` accepts a bare int, a two-element array `[18, 46]`, or the object form.
`pack_format` stays required and must fall inside the range. Overlay directories sit beside the root
`assets/` and carry per-version variants.

### 6.3 Mod built-in assets vs a resource pack

| | Mod jar | Resource pack |
|---|---|---|
| Location | `src/main/resources/assets/<modid>/…` | `<pack>/assets/<ns>/…` |
| `pack.mcmeta` | **required in the jar root** on NeoForge/Forge; Fabric synthesises one but ship it anyway | required |
| Version gating | loader-enforced; a mismatched number in a mod jar is generally tolerated | strict — wrong number ⇒ "Incompatible" |
| Load order | **below** user packs — any enabled pack overrides you | above mods, user-ordered |
| Atlas participation | **identical** — `textures/gui/sprites/**` in a mod jar is swept in by vanilla's `atlases/gui.json` | identical |
| `pack.png` | ignored (the loader uses the mod icon) | shown in the pack list |

---

## 7. Localization

### 7.1 File and fallback ★★★

`assets/<modid>/lang/en_us.json` — a **flat** JSON map, no nesting.
Fallback: selected language → `en_us` → **the raw key is displayed**. Always ship a complete `en_us.json`.

### 7.2 Key naming

**Enforced by the game** ★★★: `block.<modid>.<name>`, `item.`, `entity.`, `enchantment.`, `effect.`,
`biome.`, `attribute.`, `subtitles.`, `death.attack.<modid>.<id>`,
`advancements.<modid>.<path>.title`/`.description`, `stat.`.

**Conventional but expected by translators** ★:

| Kind | Key |
|---|---|
| Creative tab | `itemGroup.<modid>.<name>` |
| Key binding | `key.<modid>.<name>` |
| Key category | `key.categories.<modid>` (≤1.21.8) / `key.category.<ns>.<path>` (**1.21.9+**) |
| Screen / GUI strings | `gui.<modid>.<screen>.<element>` |
| Screen titles | `screen.<modid>.<name>` or `container.<modid>.<name>` |
| Tooltips | `tooltip.<modid>.<name>` or `<full item key>.desc` |
| Config | `config.<modid>.<path>`; NeoForge's config UI uses `<modid>.configuration.<path>`; Cloth uses `text.autoconfig.<modid>.option.<x>`. NeoForge 26.3 renamed its section types to LOCAL/SYNCED and updated its own section lang keys to match (#3574) ★★★ |
| Mod description (NeoForge 26.2+ mods screen) | `neoforge.screen.mods.info.description.<modid>`; the `fml.menu.mods.info.description.<modid>` fallback was **removed in 26.3** ★★★ |
| Commands / messages | `commands.<modid>.<cmd>.<result>`, `message.<modid>.<id>` |

**Reuse vanilla strings** for free translations in 100+ languages ★★: `gui.done`, `gui.cancel`,
`gui.back`, `gui.yes`, `gui.no`, `gui.ok`, `gui.proceed`, `gui.none`, `gui.toTitle`, `gui.all`,
`options.on`, `options.off`, `container.inventory`, `selectWorld.search`. Reuse the vanilla key
**categories** too (`key.categories.movement`, `.inventory`, `.gameplay`, `.ui`, `.misc`) before
inventing one.

### 7.3 Arguments — `%s` vs `%1$s` ★★

`Component.translatable(key, Object... args)` formats with `%s` semantics. **There is no `%d`/`%f`** —
non-`Component` args go through `toString()`.

- One argument → `%s` is fine.
- **Two or more → always positional (`%1$s`, `%2$s`).** `%s` consumes left-to-right and cannot be
  reordered; German and Japanese frequently need a different order, and a translator who reorders an
  `%s`-only string silently swaps the values. Positional args can also be **repeated**, which bare
  `%s` cannot.
- `%%` is a literal `%`. An index beyond the supplied args throws `TranslatableFormatException` **at
  resolve time on the client** — validate lang files in CI.

### 7.4 Pluralization ★★

Minecraft's lang format has **no ICU plural support** — no `{count, plural, …}`, no `_one`/`_other`.
Options, best first:

1. **Avoid grammatical number.** `"Items: %s"` not `"%s item(s)"`. This is what vanilla does almost
   everywhere.
2. Key per form, selected in Java — works for 2-form languages, breaks for Russian/Polish (3) and
   Arabic (6).
3. Full CLDR category selection in Java, with `.one`/`.few`/`.many`/`.other` keys and a `.other`
   fallback. Correct but heavyweight.
4. **Icon + `"×%s"`** — sidestep the noun entirely. The vanilla item-count pattern.

### 7.5 Overflow and truncation

Expansion budget ★★: **German ~30–40% longer than English; Russian ~20–35%;** Finnish and Hungarian
worse; CJK ~50% shorter but taller.

In order of preference:

1. **Measure and size.** Compute the widest label in `init()` and size the container to it.
   ```java
   int w = 0;
   for (Component c : labels) w = Math.max(w, font.width(c));
   this.panelWidth = Math.max(MIN_W, w + 2 * PADDING);
   ```
2. **Marquee-scroll like vanilla.** `AbstractWidget#renderScrollingString` is `protected static` —
   call it. It scissors and oscillates, so nothing is permanently hidden.
3. **Wrap.** `font.split(component, maxWidth)` or `GuiGraphics#drawWordWrap`; grow the panel by
   `9 × lines.size()`.
4. **Ellipsize + tooltip.** No built-in helper; write one, and **always** pair truncation with
   `setTooltip(Tooltip.create(full))` so the full text stays reachable.
   ```java
   static FormattedCharSequence ellipsize(Font font, Component c, int max) {
       if (font.width(c) <= max) return c.getVisualOrderText();
       int e = font.width("...");
       return Component.literal(font.plainSubstrByWidth(c.getString(), max - e) + "...")
                       .setStyle(c.getStyle()).getVisualOrderText();
   }
   ```
5. **Never shrink the font.** There is no sub-9px font; scaling the pose gives blurred,
   non-pixel-aligned text.

### 7.6 Testing with long strings

1. **Actually switch language:** German, Russian, Finnish, **Turkish** (catches the dotted-ı
   `toLowerCase` bug), Japanese, and an RTL language for bidi.
2. **Pseudolocalization — the highest-value l10n test.** Ship a dev-only lang file generated from
   `en_us.json`: `"Reactor Control"` → `"[!!! Ŗèäçţöŕ Çöñţŕöļ ~~~~~~~~ !!!]"`. Brackets catch
   clipping, accents catch font-coverage gaps, the +40% tail catches overflow, and any *unbracketed*
   on-screen text is a hard-coded string you forgot to translate.
3. **Matrix it with GUI scale.** Long-German × scale 4 × 1280×720 is the worst realistic case;
   long-German × Force Unicode is worse.
4. **CI validation:** keys used in code ⊆ `en_us.json`; format-specifier count and indices match
   between `en_us` and every translation; no `%` that isn't `%s` / `%n$s` / `%%`.

---

## 8. Unverified / check before relying on

1. **Font provider precedence direction.** Vanilla lists `include/unifont` last in `default.json`,
   which under naive "last wins" would make unifont override Mojangles — it visibly does not. Either
   precedence is first-wins for `reference`-spliced providers, or unifont's `.hex` lacks ASCII in
   practice. **Test in-game before relying on it** when overriding a vanilla glyph.
2. **The full 1.20.1 `widgets.png` sub-region map.** Button v-offsets 46/66/86 at u=0, 200×20 are
   source-verified. The commonly-cited hotbar `(0,0,182,22)` and selection `(0,22,24,24)` rects are not.
3. **`blitNineSliced` overload list for 1.20.1.** Only the 11-arg form is verified verbatim.
4. **1.20.1 scrollbar fill colors** (pre-sprite).
5. **Premultiplied alpha for general GUI sprites.** `GUI_TEXTURED_PREMULTIPLIED_ALPHA` is confirmed as
   the *item*-blit pipeline in 1.21.6+; whether general sprites are ever sampled through it is not.
6. **PNG bit-depth normalisation** through `NativeImage` is inferred, not source-read.
7. **26.3 release resource-pack format** was not re-read for this refresh (only the 26.3 snapshot
   range and 26.4-snapshot-8's 103.0 are recorded). Read `pack_version.resource` from the client
   jar's `version.json`. 26.4 snapshot formats will keep moving.
8. **HiDPI behaviour by OS under SDL3** (Wayland fractional scaling, Windows per-monitor DPI, macOS
   Retina) is inferred from SDL defaults and bytecode, not tested on hardware.
9. **The 26.4 debug-overlay "Auto" GUI scale** (`debugGuiScale`) algorithm was not decompiled.
