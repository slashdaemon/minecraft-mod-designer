# GUI rendering pipeline — API deltas, MC 1.20.1 → 26.3 (+26.4 preview)

How you actually put pixels on screen, per band. Confidence: ★★★ primary source (primer/javadoc/source,
`javap` of official client jars) · ★★ official blog/changelog/draft primer · ★ community/inferred.

> **Status as of 2026-11-11:** latest release **26.3** (band K); latest snapshot **26.4-snapshot-8**
> (band L, not a band yet). 26.3 and 26.4-s8 rows were read with `javap` from the official client jars
> (★★★). Every 26.4 claim is **subject to change** before the 26.4 release.

Mappings are Mojang official throughout. From **1.21.11** `ResourceLocation` is `Identifier`.
From **26.1** Minecraft ships unobfuscated and `GuiGraphics` is `GuiGraphicsExtractor`.

> **The single most important fact in this file:** almost every "how to draw a GUI in Minecraft"
> article online is 1.21.1-era and is **wrong for anything ≥1.21.5**. Two structural breaks —
> 1.21.5 (GPU abstraction) and 1.21.6 (deferred GUI) — invalidated the entire idiom.

---

## 0. The bands at a glance

| Band | GUI paradigm | `pose()` type | `blit` first arg | Landmine |
|---|---|---|---|---|
| **A · 1.20.1** | immediate | `PoseStack` | `ResourceLocation` | no `blitSprite` yet |
| 1.20.2–1.20.4 | immediate | `PoseStack` | `ResourceLocation` | GUI sprite atlas + `blitSprite` arrive |
| **B · 1.20.5–1.20.6** | immediate | `PoseStack` | `ResourceLocation` | `guiWidth()/guiHeight()`; `renderBackground` splits |
| **C · 1.21–1.21.1** | immediate | `PoseStack` | `ResourceLocation` | `drawStringWithBackdrop` |
| **D · 1.21.2–1.21.3** | immediate | `PoseStack` | `Function<ResourceLocation, RenderType>` | PNG size now mandatory; `setColor` gone |
| **E · 1.21.4** | immediate | `PoseStack` | `Function<…>` | item model rework (`ItemStackRenderState`) |
| **E · 1.21.5** | immediate | `PoseStack` | `Function<…>` | **GPU abstraction lands under you**; shader JSONs deleted |
| **F · 1.21.6–1.21.8** | **deferred / retained** | **`Matrix3x2fStack`** | **`RenderPipeline`** | the big one — see §2 |
| **G · 1.21.9–1.21.10** | deferred + feature submission | `Matrix3x2fStack` | `RenderPipeline` | `submitOutline`, sprite atlases unified |
| **H · 1.21.11** | deferred | `Matrix3x2fStack` | `RenderPipeline` | `ResourceLocation`→`Identifier`, `RenderType`→`RenderTypes` |
| **I · 26.1** | deferred, unobfuscated | `Matrix3x2fStack` | `RenderPipeline` | `GuiGraphics`→`GuiGraphicsExtractor`, `render*`→`extract*` |
| **J · 26.2** | deferred + Vulkan | `Matrix3x2fStack` | `RenderPipeline` | `MultiBufferSource` **deleted**; `Font#draw` deleted; `Gui`/`Hud` split |
| **K · 26.3** | deferred + Vulkan, **SDL3 window** | `Matrix3x2fStack` | `RenderPipeline` (now `com.mojang.renderpearl.api.pipeline`) | package move only; `textWithWordWrap` returns `int`; tooltip trailing `boolean`; text backgrounds through text shaders — see §7.1 |
| *L · 26.4-s8 (preview)* | deferred; Vulkan default | `Matrix3x2fStack` | **`GuiPipeline`** | `extract*` lose mouse/partialTick; `Updatable.update(DeltaTracker)`; `RenderPipelines.GUI_*` constants gone; `DynamicTexture` gone — see §7.2. Subject to change |

---

## 1. The cheat sheet — same operation, every band

Keep this open while porting.

```java
// ============ BACKGROUND BLIT ============
1.20.1–1.21.1 : g.blit(TEX, x, y, 0, 0, w, h);                                        // implies 256x256
1.21.2–1.21.5 : g.blit(RenderType::guiTextured, TEX, x, y, 0f, 0f, w, h, 256, 256);
1.21.6–1.21.11: g.blit(RenderPipelines.GUI_TEXTURED, TEX, x, y, 0f, 0f, w, h, 256, 256);
26.1–26.3     : g.blit(RenderPipelines.GUI_TEXTURED, TEX, x, y, 0f, 0f, w, h, 256, 256);  // TEX is Identifier
26.4-s8       : g.blit(GuiPipeline.TEXTURED, TEX, x, y, 0f, 0f, w, h, 256, 256);          // preview ★ mapping

// ============ SPRITE (from the gui atlas) ============
1.20.1        : (does not exist — use raw blit with u/v math)
1.20.2–1.21.1 : g.blitSprite(SPRITE, x, y, w, h);
1.21.2–1.21.5 : g.blitSprite(RenderType::guiTextured, SPRITE, x, y, w, h);
1.21.6–26.3   : g.blitSprite(RenderPipelines.GUI_TEXTURED, SPRITE, x, y, w, h);
26.4-s8       : g.blitSprite(GuiPipeline.TEXTURED, SPRITE, x, y, w, h);

// ============ TEXT ============
1.20.1–1.21.5 : g.drawString(font, text, x, y, 0x404040, false);        // returns end-X int
1.21.6–1.21.11: g.drawString(font, text, x, y, 0xFF404040, false);      // ALPHA MANDATORY, returns void
26.1–26.4-s8  : g.text(font, text, x, y, 0xFF404040, false);
26.3+         : int nextY = g.textWithWordWrap(font, text, x, y, width, 0xFF404040);  // was void ≤26.2

// ============ FILL / OUTLINE ============
all           : g.fill(x0, y0, x1, y1, 0x80000000);
                //   the explicit-pipeline overload takes RenderPipeline 1.21.6–26.3, GuiPipeline on 26.4-s8
1.20.1–1.21.8 : g.renderOutline(x, y, w, h, 0xFFFFFFFF);
1.21.9–1.21.10: g.submitOutline(x, y, w, h, 0xFFFFFFFF);                // renamed, then un-renamed
1.21.11       : g.renderOutline(x, y, w, h, 0xFFFFFFFF);
26.1–26.4-s8  : g.outline(x, y, w, h, 0xFFFFFFFF);

// ============ ITEM ============
1.20.1–1.21.11: g.renderItem(stack, x, y);   g.renderItemDecorations(font, stack, x, y);
26.1–26.4-s8  : g.item(stack, x, y);         g.itemDecorations(font, stack, x, y);

// ============ TOOLTIP ============
1.20.1–1.21.5 : g.renderTooltip(font, stack, mx, my);
1.21.6–26.4-s8: g.setTooltipForNextFrame(font, stack, mx, my);          // deferred; lands on a new stratum
26.3+         : g.setTooltipForNextFrame(font, lines, Optional.empty(), mx, my, null, true);
                //   trailing boolean = extraSpaceAfterFirstLine (item-style 2px title gap)

// ============ MOUSE / TIME INSIDE extract ============
≤26.3         : parameters of extractRenderState(g, mouseX, mouseY, partialTick)
26.4-s8       : g.mouseX(), g.mouseY(), g.partialTicks(), g.deltaTracker()
                //   mouseX/Y = GuiGraphicsExtractor.MOUSE_OFF_SCREEN (-1) inside g.extractWithoutMouse(Runnable)

// ============ TRANSFORM ============
1.20.1–1.21.5 : g.pose().pushPose();   g.pose().translate(x, y, 0);  … g.pose().popPose();
1.21.6–26.4-s8: g.pose().pushMatrix(); g.pose().translate(x, y);     … g.pose().popMatrix();

// ============ ARBITRARY 3D / CUSTOM MESH INSIDE A GUI ============
1.20.1–1.21.5 : Tesselator/BufferBuilder, g.bufferSource(), or g.drawSpecial(…) (1.21.2+)
1.21.6–26.1   : PictureInPictureRenderState + PictureInPictureRenderer
                → g.submitPictureInPictureRenderState(…)   (26.1: g.pictureInPicture-style renames)
                or a custom GuiElementRenderState → g.submitGuiElementRenderState(…)
26.2–26.3     : same, but renderToTexture(state, PoseStack, SubmitNodeCollector); no MultiBufferSource

// ============ SCREEN SIZE ============
all bands     : Minecraft.getInstance().getWindow().getGuiScaledWidth() / …Height()   // incl. 26.3 SDL
in a Screen   : this.width / this.height              (already gui-space)
1.20.5+       : g.guiWidth() / g.guiHeight()
```

---

## 2. The 1.21.6 deferred-GUI rewrite (the one that breaks everything) ★★★

### 2.1 Two phases

Rendering a GUI is now **prepare** then **render**:

- **Prepare** is what you write — `Gui#render`, `Screen#render`, `AbstractContainerScreen#renderBg`.
  These no longer draw. They **submit** element records into a `GuiRenderState` (held on
  `GameRenderer`, passed to `GuiGraphics`).
- **Render** is `GuiRenderer`, which reads the `GuiRenderState`, **sorts** it, and issues the draws.

`GuiGraphics`'s constructor took a `MultiBufferSource.BufferSource` before; from 1.21.6 it takes a
`GuiRenderState`.

### 2.2 Ordering is no longer call order — this is what silently breaks layouts

Two-level sort:

1. **Strata → linear tree.** `GuiRenderState` is a doubly-linked list of `GuiRenderState$Node`.
   Node placement is **automatic** from the element's `ScreenArea#bounds()`: an element goes one node
   *up* if its bounds intersect any element already on the current node. `GuiGraphics#nextStratum()`
   starts a fresh tree that renders entirely after the previous one. **You cannot navigate back to a
   prior stratum.**
2. **Comparator within a node**, in priority order:
   - `ScreenRectangle scissorArea()` — null first, then min-Y, max-Y, min-X, max-X.
   - `RenderPipeline pipeline()` — **sorted in the order the pipelines were built**, i.e. classload
     order of the `RenderPipelines` constants. `ENTITY_TRANSLUCENT` draws *before* `GUI` on the same
     node/scissor.
   - `TextureSetup#getSortKey()` — currently `hashCode()`, and NeoForged warns this **"may be
     non-deterministic as `GpuTextureView` does not implement `hashCode`"**.
   - **26.4-s8:** the pipeline sort key lives on `GuiPipeline` (`getSortKey()`, static
     `updateSortKeySeed()`) rather than on `RenderPipeline`. Ordering semantics were not decompiled ★.

Rendering starts at Z=0, each element +0.01.

> **Practical consequences.**
> - You can no longer Z-translate to force layering. Depth comes from strata + bounds.
> - If two overlapping elements land on the same node and differ only by texture, **your z-order can
>   flip between runs.** Force order with `nextStratum()` or by separating scissor regions.
> - A custom pipeline that classloads late sorts *after* `GUI` and draws over your widgets.
> - Glyphs bypass the sort entirely and always render after all elements in the current node.

### 2.3 `GuiElementRenderState` — a custom drawable

```java
public interface GuiElementRenderState extends ScreenArea {
    RenderPipeline pipeline();                   // 26.3: renderpearl package; 26.4-s8: returns GuiPipeline
    @Nullable ScreenRectangle scissorArea();
    @Nullable TextureSetup textureSetup();
    ScreenRectangle bounds();                    // from ScreenArea — drives node placement
    void buildVertices(VertexConsumer, float z); // 1.21.9 REMOVED the z parameter
}
```

Vanilla impls: `BlitRenderState`, `ColoredRectangleRenderState`, `GlyphRenderState`,
`GlyphEffectRenderState`; 1.21.9 adds `TiledBlitRenderState` (tiling / nine-slice).
`TextureSetup` is a record of `Sampler0`/`Sampler1`/`Sampler2`; in 1.21.11 it also carries the
`GpuSampler` for each.

```java
graphics.submitGuiElementRenderState(new GuiElementRenderState() {
    private final Matrix3x2f pose = new Matrix3x2f(graphics.pose());
    @Nullable private final ScreenRectangle scissorArea = graphics.peekScissorStack();

    @Override public ScreenRectangle bounds()      { /* your AABB in gui space */ }
    @Override public @Nullable ScreenRectangle scissorArea() { return this.scissorArea; }
    @Override public RenderPipeline pipeline()     { return RenderPipelines.GUI; }
    @Override public @Nullable TextureSetup textureSetup() { return TextureSetup.noTexture(); }
    @Override public void buildVertices(VertexConsumer c, float z) {
        c.addVertexWith2DPose(this.pose, x0, y0, z).setColor(color);   // addVertexWith2DPose: new in 1.21.6
        // …4 verts, QUADS
    }
});
```

Snapshot the pose and scissor **at submit time** — the prepare phase has moved on by the time
`buildVertices` runs.

### 2.4 Picture-in-Picture — the replacement for "Tesselator in the middle of a screen"

This is the sanctioned way to render **anything exotic** into a GUI: 3D models, entities, custom
meshes, render-to-texture effects, minimap-style views. PiP renders your object into an intermediary
`GpuTexture` and submits that as a `BlitRenderState`. Texture pooling is the framework's job.

```java
// 1.21.6 – 26.1
public record ExamplePipState(boolean data, int x0, int x1, int y0, int y1, float scale,
        @Nullable ScreenRectangle scissorArea, @Nullable ScreenRectangle bounds)
    implements PictureInPictureRenderState {}

public class ExamplePipRenderer extends PictureInPictureRenderer<ExamplePipState> {
    public ExamplePipRenderer(MultiBufferSource.BufferSource src) { super(src); }
    @Override public Class<ExamplePipState> getRenderStateClass() { return ExamplePipState.class; }
    @Override protected String getTextureLabel() { return "examplemod/thing"; }
    @Override protected void renderToTexture(ExamplePipState state, PoseStack pose) { /* 3D draw */ }
    @Override protected boolean textureIsReadyToBlit(ExamplePipState s) { return false; }
}

graphics.submitPictureInPictureRenderState(new ExamplePipState(...));
```

```java
// 26.2 – 26.3 — no MultiBufferSource; submit through the feature system
// 26.3 adds static PictureInPictureRenderState.getBounds(int,int,int,int, Matrix3x2fc, ScreenRectangle)
public class ExamplePipRenderer extends PictureInPictureRenderer<ExamplePipState> {
    @Override
    protected void renderToTexture(ExamplePipState state, PoseStack pose, SubmitNodeCollector out) {
        out.submitModel(...);           // no direct vertex uploads
    }
}
```

**Registration.** The vanilla map is immutable, so you need loader help:

```java
// NeoForge — mod event bus, client only     ★★★
@SubscribeEvent
static void registerPip(RegisterPictureInPictureRenderersEvent event) {
    event.register(ExamplePipState.class, ExamplePipRenderer::new);
}
// Fabric — access-widen and poke the map, or use PictureInPictureRendererRegistry
// (the 26.1 Fabric rename of SpecialGuiElementRegistry)
```

Both hooks are **unchanged on 26.3** (NeoForge 26.3.x; Fabric API 0.166.x, whose
`PictureInPictureRendererRegistry` public ctor is now `@Deprecated(forRemoval = true)` — use the
static methods) ★★★. Fabric's `+26.4` branch keeps the registry; NeoForge has no 26.4 build ★★★.

Vanilla PiP implementations worth copying: `GuiEntityRenderer`, `GuiSkinRenderer`,
`GuiBannerResultRenderer`, `GuiBookModelRenderer`, `GuiSignRenderer`, `GuiProfilerChartRenderer`,
`OversizedItemRenderer`.

### 2.5 Tooltips became deferred

`render*Tooltip` → **`set*TooltipForNextFrame`**, which queues rather than submitting;
`renderDeferredTooltip()` then adds them **on a new stratum** so they land above everything without
you managing z. Renamed `renderDeferredElements` at 1.21.9. Related 1.21.6 changes:
`ClientTooltipComponent#renderText` takes `GuiGraphics` (not pose+buffer);
`TooltipRenderUtil#renderTooltipBackground` lost its Z offset; `Screen#*TooltipForNextRenderPass`
moved onto `GuiGraphics`.

### 2.6 Blur

`GuiGraphics#blurBeforeThisStratum()` applies the vanilla pause-menu blur between this stratum and
all previously-rendered ones. **Once per frame, maximum** — exceeding it throws.

### 2.7 `LayeredDraw` removed → contextual bars

1.21.6 deleted `LayeredDraw`. HUD layering is strata plus the contextual-bar system
(`ExperienceBarRenderer`, `JumpableVehicleBarRenderer`, `LocatorBarRenderer`; `LocatorBar` in 26.2).
Register into `Gui#contextualInfoBarRenderers` (immutable map — loader help needed) and override
`Gui#nextContextualInfoState`. For mod HUD elements, use the loader HUD API instead — see
`loader-hooks.md` §1.

### 2.8 The 1.21.5 → 1.21.6 port checklist

1. `pose()` → `Matrix3x2fStack`: `pushPose/popPose` → `pushMatrix/popMatrix`; **drop every Z translate**.
2. Every `blit`/`blitSprite`/`fill`: `RenderType::guiTextured` → `RenderPipelines.GUI_TEXTURED`
   (`RenderPipelines.GUI` for untextured).
3. Every `drawString`: **OR the color with `0xFF000000`** or it renders nothing. Stop using the return value.
4. `bufferSource()` / `drawSpecial(...)` / `flush()` are **gone**. Mid-screen `Tesselator`/`BufferBuilder`
   → PiP renderer or a custom `GuiElementRenderState`.
5. `renderTooltip` → `setTooltipForNextFrame`.
6. `renderItem(stack, x, y, seed, guiOffset)` → gone (the guiOffset Z-hack no longer exists).
7. `LayeredDraw` HUD layers → loader HUD API / contextual bars.
8. Anything that relied on **draw order** for layering → `nextStratum()` or correct `bounds()`.

---

## 3. `GuiGraphics` evolution, version by version ★★★

### 3.1 Introduction (1.20)

`GuiComponent` was removed entirely; `GuiGraphics` replaced it. `drawTexturedModalRect` →
`blit`; `drawGradientRect` → `fillGradient`; `Font#draw`/`#drawShadow`/`#drawWordWrap` removed
(go through `GuiGraphics`). GUI Z bounded to `[-10000, 10000]`. `Screen#render(PoseStack,…)` →
`render(GuiGraphics,…)`.

### 3.2 Change ledger

| Version | Change |
|---|---|
| **1.20.2** | GUI **sprite atlas** (`textures/gui/sprites`) + `blitSprite`; `.mcmeta` `gui` scaling (`stretch`/`tile`/`nine_slice`) |
| **1.20.2** | `Screen#renderBackground` becomes 4-arg `(GuiGraphics,int,int,float)`; `renderTransparentBackground` added; `GuiEventListener#mouseScrolled` gains horizontal → 4 doubles `(mouseX, mouseY, horizontalAmount, verticalAmount)`; `EditBox#tick()` removed |
| **1.20.5** | `containsPointInScissor`; `fillRenderType`; **`guiWidth()`/`guiHeight()`**; menu **blur** lands (24w09a) — `renderBlurredBackground(float)`, `renderDirtBackground`→`renderMenuBackground`, `BACKGROUND_LOCATION`→`MENU_BACKGROUND` |
| **1.21** | `drawStringWithBackdrop(Font, Component, x, y, width, color)` |
| **1.21.2** | **`Function<ResourceLocation,RenderType>` becomes the first `blit`/`blitSprite` arg; PNG size mandatory.** `drawManaged` removed; **`setColor` removed** (color is now a blit param); `TextureAtlasSprite` blit overloads removed; `bufferSource()` → `drawSpecial(Consumer<MultiBufferSource>)` (not 1:1 — it also ends the batch); tooltips gain a nullable background-texture param |
| **1.21.4** | `drawWordWrap` gains a `boolean dropShadow`; **default now enables shadow** (was off) |
| **1.21.5** | *No `GuiGraphics` signature change* — the GPU rewrite lands underneath. 1.21.5 is a **plumbing** break; 1.21.6 is the **API** break |
| **1.21.6** | See §2. Plus: `drawString` **requires alpha** and returns void; `pose()` → `Matrix3x2fStack`; `peekScissorStack()` added |
| **1.21.7** | `textHighlight(x0,y0,x1,y1)` added |
| **1.21.9** | `renderOutline`→`submitOutline`; `renderDeferredTooltip`→`renderDeferredElements` (not 1:1); `requestCursor(CursorType)`/`applyCursor(Window)`; `getSprite(Material)`; **`GuiSpriteManager` removed** → unified `Sheets#GUI_SHEET` / `MAP_DECORATIONS_SHEET` / `PAINTINGS_SHEET` |
| **1.21.11** | ctor now takes mouse XY; `ActiveTextCollector` replaces `textRenderer*()`; `$HoveredTextEffects` enum; `submitOutline` → **`renderOutline`** again; `textHighlight` gains a background-rect boolean |
| **26.1** | **`GuiGraphics` → `GuiGraphicsExtractor`** + wholesale renames (§6) |
| **26.2** | `entity(...)` takes `Vector3fc`/`Quaternionfc`; `skin(...)` takes `Model$Simple`; `$ScissorStack#push/pop` return `void`; **`sign(...)` removed** |
| **26.3** | `blit/blitSprite/fill(RenderPipeline, …)` and `blit(GpuTextureView, GpuSampler, …)` keep their shapes but the types move to **`com.mojang.renderpearl.api.pipeline`/`.textures`** (also `TextureSetup`, `BlitRenderState`, `ColoredRectangleRenderState`, `TiledBlitRenderState`, `GlyphRenderState`); **`textWithWordWrap(…)` returns `int`** (next free y); `tooltip(…)` **+ `boolean extraSpaceAfterFirstLine`**; new `setTooltipForNextFrame(Font, List<Component>, Optional<TooltipComponent>, int, int, Identifier, boolean)` ★★★ |
| **26.4-s8** *(preview)* | **`GuiPipeline`** replaces `RenderPipeline` in `blit/blitSprite/fill` and every GUI render state; `extractDeferredElements()` loses its args; **`+ mouseX()`, `mouseY()`, `partialTicks()`, `deltaTracker()`, `extractWithoutMouse(Runnable)`** (`MOUSE_OFF_SCREEN = -1`) ★★★ (subject to change) |

### 3.3 `pose()` — `PoseStack` → `Matrix3x2fStack` (1.21.6)

It is **JOML's** `Matrix3x2fStack`, not a Mojang type.

| ≤1.21.5 (`PoseStack`) | ≥1.21.6 (`Matrix3x2fStack`) |
|---|---|
| `pushPose()` / `popPose()` | `pushMatrix()` / `popMatrix()` |
| `translate(float,float,float)` | `translate(float,float)` — **no Z** |
| `scale(float,float,float)` | `scale(float,float)` — **no Z** |
| `mulPose(Quaternionf)` | `rotate(float radians)` / `rotateAbout(float,float,float)` |
| `last().pose()` (`Matrix4f`) | the `Matrix3x2f` itself |

### 3.4 The ARGB trap (1.21.6+)

> "any color string without an alpha specified **will not be rendered**."

```java
graphics.drawString(font, text, x, y, 0xFF404040, false);   // explicit alpha
graphics.drawString(font, text, x, y, ARGB.opaque(0x404040), false);
```

This is a *silent* failure — text just disappears. It is the single most common 1.21.5→1.21.6 port bug.
House rule: **write every color literal in a UI as 8-digit `0xAARRGGBB` on every band**, so the same
source compiles and renders identically from 1.20.1 to 26.3 (and 26.4-s8).

### 3.5 Scissor

`enableScissor(x0,y0,x1,y1)` / `disableScissor()` / `containsPointInScissor` (1.20.5+) are stable
across the whole range. 1.21.6 added `peekScissorStack()` (needed when building custom render states);
26.2 made `$ScissorStack#push/pop` return `void`. **Each distinct scissor rect is a sort-partition
boundary** post-1.21.6 — use it to clip scroll lists, don't wrap every widget.

---

## 4. 1.21.5 — `GpuDevice` / `RenderPass` / `RenderPipeline` ★★★

Core-shader JSONs were **eliminated**. `CoreShaders` → `RenderPipelines`. All GPU access flows
through `RenderSystem.getDevice()`. For GUI call sites nothing changed in 1.21.5 — this is the
plumbing that makes 1.21.6 and Vulkan possible.

```java
public static final RenderPipeline EXAMPLE = RenderPipelines.register(
    RenderPipeline.builder()
        .withLocation(ResourceLocation.fromNamespaceAndPath("examplemod", "pipeline/example"))
        .withVertexShader(ResourceLocation.fromNamespaceAndPath("examplemod", "example"))   // shaders/example.vsh
        .withFragmentShader(ResourceLocation.fromNamespaceAndPath("examplemod", "example")) // .fsh
        .withVertexFormat(DefaultVertexFormat.POSITION_TEX_COLOR, VertexFormat.Mode.QUADS)
        .withShaderDefines("ALPHA_CUTOUT", 0.5)
        .withSampler("Sampler0")
        .withUniform("ModelOffset", UniformType.VEC3)
        .withBlend(BlendFunction.TRANSLUCENT)
        .withCull(false)
        .build());
```

`buildSnippet()` produces reusable partial pipelines. `RenderPipelines#register` is **not public** in
vanilla: access-widen on Fabric, or use NeoForge's **`RegisterRenderPipelinesEvent`** (★★★ — also
`RegisterRenderBuffersEvent`, `RegisterPictureInPictureRenderersEvent`).

### GUI-relevant `RenderPipelines` constants

| Constant | Exists | Note |
|---|---|---|
| `GUI` | 1.21.5+ | untextured colored quads (`fill`, lines, outline) |
| `GUI_TEXTURED` | 1.21.5+ | the general blit pipeline |
| `GUI_TEXTURED_PREMULTIPLIED_ALPHA` | 1.21.6+ | used by every `GuiItemRenderState` blit |
| `GUI_OPAQUE_TEXTURED_BACKGROUND` | 1.21.5+ | menu backgrounds |
| `GUI_NAUSEA_OVERLAY` | 1.21.5+ | |
| `GUI_TEXT_HIGHLIGHT` | 1.21.5+ | 1.21.7: `ADDITIVE` blend replaces `OR_REVERSE` color logic |
| `GUI_INVERT` | 1.21.7+ | |
| `GUI_TEXT`, `GUI_TEXT_INTENSITY` | 1.21.9+ | `GUI_TEXT_INTENSITY` → **`GUI_TEXT_GRAYSCALE`** in 26.2 |
| `GUI_OVERLAY`, `GUI_GHOST_RECIPE_OVERLAY`, `GUI_TEXTURED_OVERLAY` | **removed 1.21.6** | |

**26.3:** constants unchanged; `RenderPipeline` itself moves to `com.mojang.renderpearl.api.pipeline`. ★★★
**26.4-s8 (preview):** `RenderPipelines` moves to `net.minecraft.client.renderer.pipeline` and the
`GUI_*` constants are **removed** in favour of factories (`gui(...)`, `text(...)`, …) over parameter
records; `RenderPipeline` moves *back* to `com.mojang.blaze3d.pipeline`. GUI code does not touch
either — it passes a **`GuiPipeline`**:

```
net.minecraft.client.gui.GuiPipeline  (26.4-snapshot-8, ★★★ javap)
  DEFAULT, INVERT, TEXT_HIGHLIGHT, TEXTURED, TEXTURED_PREMULTIPLIED_ALPHA,
  OPAQUE_TEXTURED_BACKGROUND, NAUSEA_OVERLAY, VIGNETTE, CROSSHAIR, MOJANG_LOGO,
  TEXT, TEXT_GRAYSCALE, END_PORTAL
  static of(GuiRenderPipelineVariant); static of(Supplier<RenderPipeline>)   // custom pipelines
  RenderPipeline pipeline(); int getSortKey(); static updateSortKeySeed()
```

| ≤26.3 `RenderPipelines.` | 26.4-s8 `GuiPipeline.` (★ mapping inferred from names) |
|---|---|
| `GUI` | `DEFAULT` |
| `GUI_TEXTURED` | `TEXTURED` |
| `GUI_TEXTURED_PREMULTIPLIED_ALPHA` | `TEXTURED_PREMULTIPLIED_ALPHA` |
| `GUI_OPAQUE_TEXTURED_BACKGROUND` | `OPAQUE_TEXTURED_BACKGROUND` |
| `GUI_NAUSEA_OVERLAY` / `GUI_TEXT_HIGHLIGHT` / `GUI_INVERT` | `NAUSEA_OVERLAY` / `TEXT_HIGHLIGHT` / `INVERT` |
| `GUI_TEXT` / `GUI_TEXT_GRAYSCALE` | `TEXT` / `TEXT_GRAYSCALE` |
| custom `RenderPipeline` | `GuiPipeline.of(() -> MY_PIPELINE)` |

Correspondingly **1.21.6 removed** from `RenderType`: `gui`, `guiOverlay`, `guiTexturedOverlay`,
`guiOpaqueTexturedBackground`, `guiNauseaOverlay`, `guiTextHighlight`, `guiGhostRecipeOverlay`,
`guiTextured`, plus `vignette`, `crosshair`, `mojangLogo`, `debugLine`.

### Custom `RenderType` per band

```java
// ≤1.21.4 — RenderStateShard composite
RenderType T = RenderType.create("mymod:thing", DefaultVertexFormat.POSITION_TEX_COLOR,
    VertexFormat.Mode.QUADS, 256, false, true,
    RenderType.CompositeState.builder()
        .setShaderState(new RenderStateShard.ShaderStateShard(CoreShaders.POSITION_TEX_COLOR))
        .setTextureState(new RenderStateShard.TextureStateShard(TEX, false, false))
        .setTransparencyState(RenderStateShard.TRANSLUCENT_TRANSPARENCY)
        .createCompositeState(false));

// 1.21.5 – 1.21.10 — the pipeline carries shader/blend/cull
RenderType T = RenderType.create("mymod:thing", 256, false, true, MY_PIPELINE,
    RenderType.CompositeState.builder()
        .setTextureState(new RenderStateShard.TextureStateShard(TEX, false))
        .createCompositeState(false));

// 1.21.11+ — RenderSetup replaces RenderStateShard; statics move to RenderTypes
public static final RenderSetup SETUP = RenderSetup.builder(RenderPipelines.ITEM_ENTITY_TRANSLUCENT_CULL)
    .withTexture("Sampler0", Identifier.withDefaultNamespace("textures/…png"),
                 () -> RenderSystem.getSamplerCache().getClampToEdge(FilterMode.NEAREST))
    .useLightmap().useOverlay().sortOnUpload().bufferSize(786432)
    .setOutputTarget(OutputTarget.MAIN_TARGET)
    .createRenderSetup();
public static final RenderType T = RenderType.create("mymod:thing", SETUP);
```

---

## 5. Items, entities, and text inside GUIs

### 5.1 `renderItem`

`renderItem(ItemStack,int,int)` / `(…,int seed)` / `(LivingEntity,ItemStack,…)`, `renderFakeItem`,
`renderItemDecorations` are stable 1.20.1 → 1.21.11. **1.21.6 removed** the
`renderItem(stack,x,y,seed,guiOffset)` Z-offset overload. **26.1 renames** them to `item`,
`fakeItem`, `itemDecorations`.

### 5.2 The 1.21.4 item-model rework

`BakedModel`-for-items is gone; `ItemStackRenderState` + `ItemModelResolver` replace it, and client
items are declared in `assets/<ns>/items/<path>.json`. Removed: `BlockEntityWithoutLevelRenderer`
(→ `SpecialModelRenderer`), `ItemModelShaper` (→ `ModelManager`), `ItemProperties`, `BakedOverrides`.

```java
// 1.21.4+ — drawing an item into a non-GuiGraphics surface
ItemStackRenderState state = new ItemStackRenderState();
Minecraft.getInstance().getItemModelResolver()
    .updateForTopItem(state, stack, ItemDisplayContext.GUI, false, level, null, 0);
state.render(poseStack, bufferSource, LightTexture.FULL_BRIGHT, OverlayTexture.NO_OVERLAY);
```

1.21.6 adds `setAnimated`, `getModelBoundingBox()`, `setOversizedInGui()` +
`ClientItem$Properties#oversizedInGui` (true → GUI bounds come from the model bbox instead of being
clipped to 16×16) and an `OversizedItemRenderState` PiP. **1.21.11** gives items their own atlas
(`AtlasIds#ITEMS`). **Perf:** call `ItemStackRenderState$LayerRenderState#ensureCapacity(n)` before a
`newLayer()` loop.

### 5.3 `InventoryScreen.renderEntityInInventory*`

| Version | Change |
|---|---|
| 1.20.5 | scale param `int` → **`float`** |
| 1.21.1 | `renderEntityInInventoryFollowsMouse(GuiGraphics,int,int,int,int,int,float,float,float,LivingEntity)` |
| **1.21.6** | no longer takes an XY offset — takes **four ints for the target region** `(x0,y0,x1,y1)`; internally submits a `GuiEntityRenderState` PiP |
| **1.21.11** | **`renderEntityInInventory` removed** (the `FollowsMouse` variant survives) |
| **26.1** | → `extractEntityInInventoryFollowsMouse` |

```java
// 1.21.6+ direct submission
graphics.submitEntityRenderState(state, scale, translation, rotation, overrideCameraAngle, x0,y0,x1,y1);
// 26.1 rename → graphics.entity(...);  26.2 takes Vector3fc / Quaternionfc
```

### 5.4 Text / `Font`

| Version | Change |
|---|---|
| 1.20 | `Font#draw`/`#drawShadow`/`#drawWordWrap` removed — go through `GuiGraphics` |
| 1.20.1–1.21.5 | `drawInBatch(text, x, y, color, dropShadow, Matrix4f, MultiBufferSource, Font.DisplayMode, bgColor, packedLight)`; `drawInBatch8xOutline(...)` |
| **1.21.6** | `drawInBatch` **returns void**; new `Font#prepareText(...)` → `Font$PreparedText`, `Font$GlyphVisitor`, `splitIgnoringLanguage`; `ALPHA_CUTOFF` removed; `$StringRenderOutput` → `$PreparedTextBuilder` |
| **1.21.9** | glyph pipeline rework: `UnbakedGlyph#bake`, `BakedGlyph#createGlyph()` → `TextRenderable`, `FontDescription` → `GlyphSource`; `RenderPipelines#GUI_TEXT` added |
| **1.21.11** | `Font#NO_SHADOW` → `Style#NO_SHADOW`; `wordWrapHeight(String,int)` removed; new `ActiveTextCollector` path |
| **26.1** | `Matrix4f` → `Matrix4fc` throughout |
| **26.2** | **`Font#drawInBatch` removed entirely.** `drawInBatch8xOutline` → `prepare8xTextOutline`. `GlyphRenderTypes#createForIntensityTexture` → `createForGrayscaleTexture` |
| **26.3** | `+ TextRenderable prepareBackground(float, float, float, float, int)`; the `text_background` shaders are removed — text backgrounds render through the text shaders. Font assets byte-identical ★★★ |
| **26.4-s8** | `TextRenderable.guiPipeline()` / `GlyphRenderTypes` return `GuiPipeline`; `TextFieldHelper` removed. Font assets still byte-identical ★★★ (subject to change) |

Stable everywhere: `int width(...)`, `List<FormattedCharSequence> split(FormattedText, int maxWidth)`,
`int lineHeight` (**9**), `getSplitter()`, `plainSubstrByWidth`, `substrByWidth`, `wordWrapHeight(FormattedText,int)`.

```java
// 26.2 — drawInBatch is gone; prepare + visit is mandatory
Font.PreparedText t = font.prepareText("Hello", 0, 0, 0xFF00FF00, false, 0);
t.visit(renderable -> { /* … */ });
// preferred in 26.2: OrderedSubmitNodeCollector#submitText
```

**There is no `Font` scale API on any band** — scale the pose around the draw call. Post-1.21.6 that
is `graphics.pose().scale(sx, sy)`.

---

## 6. 26.1 — unobfuscation and the "extractor" rename ★★★

26.1 ships fully unobfuscated: **drop Parchment**, JDK **25**, Gradle **≥9.1**. Default heap 2 GB→4 GB,
G1GC→ZGC. *"The game no longer runs on GPUs with 512 MB or less of RAM."*

GUI methods were renamed to signal that they **extract** render state rather than draw:
`draw*`/`render*` → `extract*`, often suffixed `*RenderState`. And on `GuiGraphicsExtractor` itself,
the `draw*`/`render*`/`submit*` prefixes and `*RenderState` suffixes are **stripped**.

### `GuiGraphics` → `GuiGraphicsExtractor`

| ≤1.21.11 | 26.1+ |
|---|---|
| `hLine` / `vLine` | `horizontalLine` / `verticalLine` |
| `renderOutline` | `outline` |
| `drawString` | **`text`** |
| `drawCenteredString` | `centeredText` |
| `drawWordWrap` | `textWithWordWrap` |
| `drawStringWithBackdrop` | `textWithBackdrop` |
| `renderItem` / `renderFakeItem` / `renderItemDecorations` | `item` / `fakeItem` / `itemDecorations` |
| `renderTooltip` | `tooltip` |
| `submitMapRenderState` | `map` |
| `submitEntityRenderState` | `entity` |
| `submitSkinRenderState` | `skin` |
| `submitBookModelRenderState` | `book` |
| `submitBannerPatternRenderState` | `bannerPattern` |
| `submitSignRenderState` | `sign` — **removed in 26.2** |
| `submitProfilerChartRenderState` | `profilerChart` |
| *unchanged* | `fill`, `fillGradient`, `blit`, `blitSprite`, `enableScissor`, `disableScissor`, `pose`, `guiWidth`, `guiHeight`, `nextStratum`, `blurBeforeThisStratum`, `setTooltipForNextFrame` |

> **Open conflict — verify against your own 26.x toolchain.** The 26.1 primer's stated rule is that
> `draw*`/`render*`/**`submit*`** prefixes and `*RenderState` suffixes are all stripped, which would
> make `submitGuiElementRenderState` → `guiElement` and `submitPictureInPictureRenderState` →
> `pictureInPicture`. A second independent pass instead reported `submit*` → **`add*`**. The
> *specialised* submits in the table above (`entity`, `skin`, `map`, …) are confirmed; the two
> **generic** submit methods are not. Check `GuiGraphicsExtractor` on your target before writing
> either form.

> **1.21.6 and 26.1 are two different porting problems — do not conflate them.**
> **1.21.6** is a *behavioral* break: you now submit render state instead of drawing. It **kept** the
> `render` / `renderWidget` names — `AbstractWidget#renderWidget` exists verbatim in 1.21.6, 1.21.9
> **and** 1.21.11. **26.1** is a *nominal* break: the mass `extract*` rename on top of the same
> architecture. For a multi-band mod that distinction decides whether you can shim with a rename or
> must restructure. ★★★

### `Screen` / container screens

| ≤1.21.11 | 26.1+ |
|---|---|
| `Renderable#render` | `extractRenderState` |
| `Screen#render` | `extractRenderState` |
| `Screen#renderBackground` | `extractBackground` |
| `Screen#renderBlurredBackground` / `renderPanorama` / `renderMenuBackground` / `renderTransparentBackground` | `extractBlurredBackground` / `extractPanorama` / `extractMenuBackground` / `extractTransparentBackground` |
| `AbstractContainerScreen#renderBg` | **replaced by `Screen#extractBackground`** |
| `AbstractContainerScreen#renderLabels` | `extractLabels` |
| `…#renderContents/renderCarriedItem/renderSlots/renderTooltip/renderSlot` | `extractContents/extractCarriedItem/extractSlots/extractTooltip/extractSlot` |
| `AbstractWidget#renderWidget` | `extractWidgetRenderState` |
| `PlayerFaceRenderer#draw` | `PlayerFaceExtractor#extractRenderState` |
| `Toast#render` / `ToastManager#render` | `extractRenderState` |
| `ClientTooltipComponent#renderText/renderImage` | `extractText/extractImage` |
| `InventoryScreen#renderEntityInInventoryFollowsMouse` | `extractEntityInInventoryFollowsMouse` |
| `StringWidget#clipText` | `ComponentRenderUtils#clipText` |

Package moves: `net.minecraft.client.gui.render.state.*` → `net.minecraft.client.renderer.state.gui.*`;
`RenderType`/`RenderTypes` in `net.minecraft.client.renderer.rendertype`.

**26.1 `AbstractContainerScreen`:** `imageWidth`/`imageHeight` are now **final**, passed to the
constructor (`DEFAULT_IMAGE_WIDTH`/`DEFAULT_IMAGE_HEIGHT` = 176/166). `render` now calls
`renderTooltip` at the end — *"in most cases, you should not override `render` in subtypes."*
`slotClicked` takes **`ContainerInput`** instead of `ClickType`.

```java
// 26.1 container screen
public class ExampleScreen extends AbstractContainerScreen<ExampleMenu> {
    public ExampleScreen(ExampleMenu menu, Inventory inv, Component title) {
        super(menu, inv, title, 256, 256);              // image size via ctor now
    }
    @Override protected void extractLabels(GuiGraphicsExtractor g, int mx, int my) { … }
}
```

---

## 7. 26.2 — what else moved besides Vulkan ★★★

See `vulkan-and-performance.md` for the backend story. GUI-relevant 26.2 deltas:

- **`MultiBufferSource` interface removed.** Replaced by `SubmitNode` → `FeatureRenderPhase` →
  `FeatureRenderer`, driven by `FeatureRenderDispatcher` over a `SubmitNodeStorage`. Closest
  replacement for the old buffer source is `RenderTypeFeatureRenderer`.
- **`Gui`/`Hud` split**:
  ```diff
  - Minecraft.getInstance().screen
  + Minecraft.getInstance().gui.screen()
  - Minecraft.getInstance().gui.setOverlayMessage(...)
  + Minecraft.getInstance().gui.hud.setOverlayMessage(...)
  ```
  Moved to `Hud`: `setTitle`, `setSubtitle`, `setTimes`, `clearTitles`, `setOverlayMessage`,
  `getChat`, `getFont`, `getGuiTicks`, `getTabList`, `getBossOverlay`, `getDebugOverlay`, …
  `Minecraft#hideGui` → `Hud#isHidden` / `GuiRenderState#isHudHidden`.
- `TextureFormat` → **`GpuFormat`**; `VertexFormat$Mode` → **`PrimitiveTopology`**; samplers/uniforms
  move off the pipeline into **`BindGroupLayout`**; depth compare inverted
  (`GREATER_THAN_OR_EQUAL`) because of the **reversed depth buffer**.
- `GuiTextRenderState` fields go private; `BlitRenderState` pose is `Matrix3x2fc`;
  `PictureInPictureRenderState#pose()` returns `Matrix3x2fc`.
- `ShapeRenderer` → `OrderedSubmitNodeCollector#submitShapeOutline(...)`.

### Known 26.2 defect to be aware of (author-verified)

A **minimal, do-nothing custom `Screen` subclass shows one black frame on every open** in 26.2
(reproduced on 26.2-snapshot-7, Fabric Loader 0.19.2 / Fabric API 0.149.0+26.2, under **both** Vulkan
and OpenGL, with zero widgets, zero overrides and no HUD callbacks: a `Screen` subclass and a keybind
are enough). Vanilla screens are unaffected; 26.1 and every earlier band are clean. Overriding
`extractBackground`/`extractRenderState` to mimic vanilla does **not** fix it. No confirmed mod-side
fix. A partial mitigation: return `true` from `isInGameUi()` (the transparent-background path the
inventory uses) and make `extractBlurredBackground` a no-op. In-game it showed the panel over the
live world with no black frame, but whether it removes the flash on every open is unsettled; side
effect, `isInGameUi` is also read by the HUD subtitle overlay. Both APIs still exist in 26.3 and
26.4-snapshot-8, so it ports forward. Keep the count down by drawing modals and popovers inside one
screen rather than opening a screen per dialog. Also note 26.2 uses
`Minecraft.getInstance().setScreenAndShow(screen)`. Not re-tested on 26.3 or 26.4 snapshots.

### 7.1 26.3 (band K, UI era G) — small drawing delta, big input delta ★★★

The GUI drawing surface barely moved; 75 GUI classes changed, most of them the package move.

- **Package move only:** `RenderPipeline` → `com.mojang.renderpearl.api.pipeline.RenderPipeline`;
  `GpuTextureView`/`GpuSampler` → `com.mojang.renderpearl.api.textures.*`. Same parameter shapes on
  `blit`/`blitSprite`/`fill`, `TextureSetup`, and every GUI render state. Fix imports, nothing else.
- `GuiGraphicsExtractor.textWithWordWrap(…)` returns **`int`** (next free y) — lets you stack wrapped
  paragraphs without measuring.
- Tooltips: trailing **`boolean extraSpaceAfterFirstLine`**; the 2 px title gap is now item-only (see
  `design-language.md` §10).
- `Font.prepareBackground(...)`; `text_background` shaders gone (text backgrounds use the text shaders).
- `PictureInPictureRenderState.getBounds(…)` static helper; `GuiProfilerChartRenderState` takes a pose.
- `ARGB` gains `Vector3fc`/`Vector4fc` helpers (`multiply`, `addRgb`, `scaleRGB`, `greyscale`,
  `alphaBlend`, `srgbLerp`, …); `subtractRgb(int,int)` now returns boxed `Integer`.
- Debug overlay gets its own GUI scale: `Options.debugGuiScale()` (`DEBUG_GUI_SCALE_UNCHANGED = -1`,
  default *Auto*). The Auto algorithm was not decompiled.
- **Window/input is the real break** (SDL3): see §8 for GUI scale and `screen-widget-api.md` §6.5
  for keys, modifiers, mouse buttons and text-input focus.

### 7.2 26.4 preview (band L, 26.4-snapshot-8) — signature break ★★★, subject to change

264 GUI classes changed (78 added, 18 removed). Most of the churn is one rule:

> **`extractRenderState` becomes a pure state getter.** It loses `mouseX`, `mouseY` and `partialTick`;
> read them from the extractor (`g.mouseX()`, `g.mouseY()`, `g.partialTicks()`, `g.deltaTracker()`).
> Time- and hover-driven logic moves to **`Updatable.update(DeltaTracker)`**, called once right before
> extract. (Rule stated by the draft 26.4 NeoForge primer ★★; signatures ★★★.)

| 26.3 | 26.4-s8 |
|---|---|
| `Renderable.extractRenderState(g, int, int, float)` | `extractRenderState(g)` |
| `AbstractWidget.extractWidgetRenderState(g, int, int, float)` | `extractWidgetRenderState(g)` |
| `Screen.extractBackground/extractRenderState/extractPanorama/…(g, …)` | `(g)` |
| `GuiGraphicsExtractor.extractDeferredElements(int, int, float)` | `extractDeferredElements()` |
| `Gui.update()` | `Gui.update(DeltaTracker)` |
| `Hud.extractRenderState(g, DeltaTracker)` | `Hud implements Renderable, Updatable`: `update(DeltaTracker)` + `extractRenderState(g)` |
| — | `Updatable` implemented by `Screen`, `Overlay`, `LoadingOverlay`, `PopupScreen`, `Hud`, `AbstractSelectionList`, `RecipeBookComponent` |
| — | newly `Renderable`: `ToastManager`, `BossHealthOverlay`, `PlayerTabOverlay`, `SubtitleOverlay`, `SpectatorGui`, `DebugScreenOverlay`, `EffectsInInventory`, `ContextualBar`, `CommandSuggestions` |
| `ChatComponent.extractRenderState(g, Font, int tick, int mx, int my, DisplayMode, boolean)` | `(g, Font, int, DisplayMode, boolean)` |
| `blit/blitSprite/fill(RenderPipeline, …)` | **`(GuiPipeline, …)`** (§4) |
| `RenderPipelines.GUI_TEXTURED` etc. | removed → `GuiPipeline.TEXTURED` etc. |
| `AbstractTexture`, **`DynamicTexture`**, `SimpleTexture`, `ReloadableTexture` | **removed**. `TextureManager.getTexture` returns `TextureHandle`; register runtime textures with `TextureManager.register(Identifier, TextureResources)` or `registerAndLoad(Identifier, TextureProvider)` |

**Runtime GUI textures (webcam frames, generated maps, player heads).** The ≤26.3 idiom
`new DynamicTexture(...)` + `textureManager.register(id, tex)` + `blit(id, …)` does not compile on
26.4-s8. Route texture creation/upload through the per-band adapter; on 26.4 register through
`TextureResources`/`TextureProvider` and keep blitting by `Identifier`. The upload path itself
(`CommandEncoder.writeToTexture(NativeImage…)` was removed) is in `minecraft-mod-expert`
`api-migration-deltas.md` "26.4 snapshot preview". ★★★ signatures; replacement idiom ★.

**F3 debug overlay redesign** (26.4-snapshot-2+). Entries are a client registry keyed by
`ResourceKey<DebugScreenEntry>` (`DEBUG_SCREEN_ENTRY`); output goes through groups, facts and columns:
`DebugScreenDisplayer.addToGroup(DebugGroup, String|Collection)`, `addFactToGroup(DebugGroup, String, Consumer<DebugFact>)`,
`addToGroup(DebugGroup, DebugCustomRenderer)`; `DebugColumn$Side`. `addLine(String)`, `Identifier`-keyed
`addToGroup`, `allEntries()`/`getEntry()` and `MARGIN_LEFT/RIGHT/TOP = 2` are gone. Mods that add F3
lines need a per-band adapter here. ★★★

**HUD order (Fabric `+26.4`):** `VanillaHudElements.SPECTATOR_MENU` and `HOTBAR` now draw *after* the
status bars and `INFO_BAR_FOREGROUND`; Fabric `HudElement` becomes `extends Updatable` with
`extractRenderState(g)` + `default update(DeltaTracker)`, and `ScreenEvents` extract callbacks become
`(Screen, GuiGraphicsExtractor)`. ★★★ (Fabric 26.4 branch; see `loader-hooks.md`).

**Backend:** Vulkan is the "Default" graphics API from 26.4-snapshot-1; s7 picks OpenGL or Vulkan at
random per launch (Mojang: temporary). Test both. ★★★ patch notes.

---

## 8. GUI scale, window, resize

| API | Availability |
|---|---|
| `Window#getGuiScaledWidth()` / `getGuiScaledHeight()` | **1.20.1 → 26.4-s8, unchanged** |
| `Window#getWidth()`/`getHeight()` (framebuffer px), `getScreenWidth()`/`getScreenHeight()` | unchanged (26.3: framebuffer from `SDL_GetWindowSizeInPixels`) |
| `Window#getGuiScale()` / `setGuiScale(...)` | **`double` ≤1.21.5; `int` from 1.21.6** |
| `Window#calculateScale(int maxScale, boolean enforceUnicode)` | unchanged — **byte-identical on 26.3 SDL** |
| `Window.MIN_WINDOW_WIDTH 320` / `MIN_WINDOW_HEIGHT 240` (enforced on the window) | **26.3** |
| `Window#getPixelDensity()` | **26.3** — `SDL_GetWindowPixelDensity`; **not** used for GUI scale |
| `Window` `isFullscreen`/`isMinimized`/`toggleFullScreen`/`getRefreshRate` removed; `setFullscreen(boolean)`, `setExclusiveFullscreen` added | **26.3** |
| 7-arg public `Window` ctor removed (8-arg remains); `+ show()`, `isWayland()`, `setNeedsBorderlessFullscreenPadding(boolean)` | **26.4-s8** |
| `GuiGraphics#guiWidth()` / `guiHeight()` | added 1.20.5 |
| `Screen#width` / `height`, `Screen#resize(int,int)`, `init()`, `rebuildWidgets()` | unchanged all bands |
| `Window#getWindow()` → **`Window#handle()`** | **1.21.9** |
| `Window#selectCursor` / `setAllowCursorChanges` | added 1.21.9 |
| `Window#isMinimized()` | added 1.21.4 |
| `Window#isFocused()` replaces `setWindowActive` | 26.1 |

`ScaledResolution` has not existed since 1.13 — it is not part of this range.

**GUI scale under SDL (26.3+) ★★★.** The window is created `SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY`
and the framebuffer is read in **physical pixels**. `calculateScale` is byte-identical to 26.2: scale
grows while `fbW/(scale+1) ≥ 320 && fbH/(scale+1) ≥ 240`, capped at the requested scale (forced
Unicode rounds up to even); `guiScaled = ceil(fb/scale)`. Mouse → GUI coords is still
`x * guiScaledWidth / screenWidth`. So:

- **Never multiply by `getPixelDensity()` in GUI code** — density is already in the framebuffer and
  the integer GUI scale. Vanilla uses it only to convert GUI rects to OS window points (the IME
  candidate rect) and in F3 system specs. Do the same.
- The GUI minimum stays **320 × 240** GUI pixels at scale 1, now also the **minimum window size**.
  Design every screen to fit 320 × 240 at the player's chosen scale (see `accessibility.md`).
- HiDPI/Retina screens get a larger *auto* scale, as under GLFW on macOS. Native Wayland (preferred
  on Linux from 26.3) with fractional scaling should yield a full-resolution framebuffer and a higher
  auto scale than XWayland ★ (not tested).
- No `SDL_*DPI*` hints or display-scale calls are used; borderless-fullscreen padding subtracts 1 px
  from the framebuffer width on Windows (`BORDERLESS_FULLSCREEN_PADDING = 1`).

```java
@Override public void resize(int width, int height) {
    super.resize(width, height);   // → init(width, height) → rebuildWidgets()
}
```

---

## 9. Unverified / check before relying on

1. **`GuiRenderer#MIN_GUI_Z` visibility** flip-flops (private at 1.21.7, public at 1.21.9). Don't depend on it.
2. **1.20.1's exact `renderEntityInInventory*` overloads** — the 1.20.5 (`int`→`float` scale), 1.21.1,
   1.21.6, 1.21.11 and 26.1 changes are verified; the literal 1.20.1 signatures are not.
3. **`Font$DisplayMode` constant list** (`NORMAL`, `SEE_THROUGH`, `POLYGON_OFFSET`) — only `NORMAL`
   is source-confirmed.
4. **26.x package path for PiP *renderers*** — primers give conflicting paths
   (`net.minecraft.client.gui.renderer.pip` vs `…gui.render.pip`). The *states* are confirmed at
   `net.minecraft.client.renderer.state.gui`.
5. **Per-overload exhaustiveness of `GuiGraphics` for 1.21.6/1.21.8/1.21.11** — shapes are verified
   three ways, but no live Mojmap javadoc exists for exactly those versions.
6. **The exact version each legacy `RenderSystem` state setter was removed** (`enableBlend`,
   `setShaderColor`, …). They are absent by 26.1; the 1.21.5 mass-removal list is verified.
7. **`RenderPipelines.GUI_*` → `GuiPipeline.*` mapping** on 26.4-s8 is inferred from constant names ★;
   `GuiPipeline` sort-key ordering semantics were not decompiled.
8. **26.4 rows are snapshot-8 only**; the s7 jar was not diffed separately and any 26.4 signature can
   change before release. The draft 26.4 NeoForge primer (PR #51) is open and covers up to s7.
9. **26.4 runtime-texture replacement idiom** (`TextureResources`/`TextureProvider` for a per-frame
   dynamic texture) — signatures read, no working example built. ★
10. **Runtime appearance on 26.3/26.4** — nothing was rendered: the F3 redesign, the 26.4 grey list
    outline, the debug-GUI-scale *Auto* value, and HiDPI behaviour per OS are unverified.
11. **The 26.2 custom-screen black frame (§7)** has not been re-tested on 26.3 or 26.4 snapshots.
12. **The generic `submit*` naming conflict in §6** (`guiElement`/`pictureInPicture` vs `add*`) was not
    re-checked in the 26.3/26.4-s8 refresh — still verify against your toolchain.
