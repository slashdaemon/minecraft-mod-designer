# Per-loader client UI hooks — Fabric, Quilt, NeoForge, MinecraftForge 1.20.1

How your UI attaches to the game, not what it looks like. Confidence: ★★★ read from primary source
(API source / javadoc / official docs) · ★★ official release notes or docs prose · ★ secondary.

Status as of **2026-11-11**: covers 26.3 (band K, stable) and a 26.4-snapshot-8 preview (L, not a
band). Pins: Fabric API **0.166.2+26.3** / **0.166.2+26.4** (pre-release) · NeoForge **26.3.0.102**
(the expert skill pins 26.3.0.101; either is fine, but stay **≥ 26.3.0.90**, see §3.3) · **no
NeoForge 26.4 build or branch exists** · MinecraftForge 26.3 = 66.1.5 (see §1.5, and don't target it). ★★★

## 0. Ground truth to fix first

| Fact | Detail | Conf |
|---|---|---|
| **NeoForge does not exist for 1.20.1** | NeoForge branches start at 1.20.2. On Band A the only Forge-family loader is MinecraftForge (LexForge) 47.x | ★★★ |
| **26.1 is unobfuscated** | Fabric API renamed everything to Mojang names; Yarn-era names (`DrawContext`, `MinecraftClient`, `KeyBinding`) are gone from Fabric API too | ★★ |
| **`GuiGraphics` → `GuiGraphicsExtractor` (26.1)** | Part of the extract/submit split. `Screen#render`→`extractRenderState`, `renderBackground`→`extractBackground`, `AbstractContainerScreen#renderBg`→`extractBackground`, `renderLabels`→`extractLabels` | ★★★ |
| **`KeyMapping.Category` is a 1.21.9 vanilla change** | Categories went from `String` to a registered record, on both loader families | ★★★ |
| **`mods.toml` → `neoforge.mods.toml`** | NeoForge 1.20.5. Forge 1.20.1 keeps `META-INF/mods.toml` | ★★ |
| **Quilt: ship the Fabric jar** | QSL/QFAPI retired for 26.1+; last stable QFAPI is 7.7.0 (MC 1.20.1). See §7 | ★★★ |
| **NeoForge 26.3 renamed config types** | `ModConfig.Type.COMMON` → **`LOCAL`**, `SERVER` → **`SYNCED`**. Every `registerConfig(COMMON/SERVER, …)` breaks on 26.3. See §4.5 | ★★★ |
| **NeoForge 26.3 renamed key getters** | `ScreenEvent.KeyPressed/KeyReleased`, `InputEvent.Key`: `getKeyCode()` → `getKey()`, `getScanCode()` → `getKeycode()`. See §2.3 | ★★★ |
| **26.3 has no GLFW** | Vanilla moved to SDL3. Every `GLFW.*` constant in key/mouse code becomes `InputConstants.*`; `InputConstants.Type.KEYSYM` → `KEYBOARD`. See §3 | ★★★ |
| **Fabric API 26.4 breaks HUD + screen callbacks** | `HudElement.extractRenderState(GuiGraphicsExtractor)` loses `DeltaTracker` (moved to `update(DeltaTracker)`); `ScreenEvents` extract callbacks lose mouse + tick progress. `fabric-screen-api-v1` → **6.0.x** | ★★★ |

---

## 1. HUD / overlay rendering

### 1.1 Decision table — "I want to draw on the HUD"

| MC band | Fabric | Quilt | NeoForge | MinecraftForge |
|---|---|---|---|---|
| **A · 1.20.1** | `HudRenderCallback.EVENT` `(GuiGraphics, float partialTick)` | Fabric jar; QFAPI 7.7.0 exists here | *n/a* | `RegisterGuiOverlaysEvent` + `IGuiOverlay` |
| 1.20.2–1.20.4 | `HudRenderCallback` | Fabric jar | `RegisterGuiOverlaysEvent` + `IGuiOverlay` | *EOL band* |
| **B–E · 1.20.5–1.21.4** | `HudRenderCallback` `(GuiGraphics, DeltaTracker)` | Fabric jar (QFAPI alpha only) | `RegisterGuiLayersEvent` + `GuiLayer` | — |
| **1.21.5 only** | `HudLayerRegistrationCallback` (added fabric-api 0.116.0+1.21.5; `HudRenderCallback` deprecated) | Fabric jar | `RegisterGuiLayersEvent` | — |
| **F–H · 1.21.6–1.21.11** | **`HudElementRegistry`** | Fabric jar | `RegisterGuiLayersEvent` (+`replaceLayer`/`wrapLayer`) | — |
| **I–J · 26.1 / 26.2** | **`HudElementRegistry`** (`HudRenderCallback` **removed**), `GuiGraphicsExtractor` | Fabric jar; QSL retired | `RegisterGuiLayersEvent`, `GuiGraphicsExtractor` | *(exists, don't target: §1.5)* |
| **K · 26.3** | `HudElementRegistry` unchanged; adds `INFO_BAR_FOREGROUND`, status-bar `replaceLeft/Right` | Fabric jar | `RegisterGuiLayersEvent` unchanged | `AddGuiOverlayLayersEvent` (§1.5, don't target) |
| *L · 26.4 snapshot (preview)* | `HudElementRegistry`; **`HudElement` loses `DeltaTracker`, gains `update(DeltaTracker)`**; hotbar draw order moves | Fabric jar | **no NeoForge 26.4 build** | — |

### 1.2 Fabric — five distinct eras ★★★

```java
// A (1.20.1)
HudRenderCallback.EVENT.register((graphics, partialTick) -> { ... });
// B–E (1.20.5–1.21.4): second arg becomes DeltaTracker
HudRenderCallback.EVENT.register((graphics, deltaTracker) -> { ... });
// 1.21.5 only: LayeredDrawerWrapper
HudLayerRegistrationCallback.EVENT.register(drawer ->
    drawer.attachLayerAfter(IdentifiedLayer.MISC_OVERLAYS, id, layer));
// F–K (1.21.6 → 26.3): HudElementRegistry
HudElementRegistry.addLast(id, (graphics, deltaTracker) -> { ... });
// L (26.4 snapshots, fabric-rendering-v1 29.x): extract is a pure state getter
HudElementRegistry.addLast(id, graphics -> { ... });   // mouse/partial tick: graphics.deltaTracker() etc.
```

**`HudElementRegistry`** (`net.fabricmc.fabric.api.client.rendering.v1.hud`):

```java
static void addFirst(Identifier id, HudElement element);
static void addLast (Identifier id, HudElement element);
static void attachElementBefore(Identifier beforeThis, Identifier id, HudElement element);
static void attachElementAfter (Identifier afterThis,  Identifier id, HudElement element);
static void removeElement (Identifier id);
static void replaceElement(Identifier id, Function<HudElement, HudElement> replacer);
```

`HudElement` on 26.1–26.3 is `void extractRenderState(GuiGraphicsExtractor, DeltaTracker)`; on
1.21.6–1.21.11 it is `void render(GuiGraphics, DeltaTracker)`. Method references bind either way.

**26.4 (Fabric API 0.166.2+26.4)** ★★★: `@FunctionalInterface interface HudElement extends Updatable`
with `void extractRenderState(GuiGraphicsExtractor)` plus `default void update(DeltaTracker)`, called
**once per frame, even while the element is hidden**. Put time/animation state in `update`; read
mouse or partial tick from the extractor (`mouseX()`, `mouseY()`, `partialTicks()`, `deltaTracker()`).
This mirrors vanilla 26.4's `Renderable`/`Updatable` split. A lambda written for 26.3 no longer
compiles: keep it behind a per-band adapter.

> **Render-condition inheritance — the trap.** `attachElementBefore/After` and `replaceElement`
> **inherit the anchor element's render condition**. Every vanilla element except
> `VanillaHudElements.SLEEP` is gated on "HUD hidden" (F1). Only `addFirst`/`addLast` inherit **no**
> condition — meaning they keep drawing when the player has hidden the HUD. If you use
> `addFirst`/`addLast`, **check F1 yourself**. ★★★

**`VanillaHudElements` (26.2), bottom→top draw order** — all `minecraft:` namespace:
`MISC_OVERLAYS, CROSSHAIR, SPECTATOR_MENU, HOTBAR, ARMOR_BAR, HEALTH_BAR, FOOD_BAR, AIR_BAR,
MOUNT_HEALTH, INFO_BAR, EXPERIENCE_LEVEL, HELD_ITEM_TOOLTIP, SPECTATOR_TOOLTIP, MOB_EFFECTS,
BOSS_BAR, SLEEP, DEMO_TIMER, SCOREBOARD, OVERLAY_MESSAGE, TITLE_AND_SUBTITLE, CHAT, PLAYER_LIST,
SUBTITLES`. `INFO_BAR` = experience **or** locator **or** jump bar. `SUBTITLES` = *sound* subtitles;
`TITLE_AND_SUBTITLE` is the title text. ★★★

**26.3** adds **`INFO_BAR_FOREGROUND`** (Fabric API 0.165.0) directly after `EXPERIENCE_LEVEL`, for
drawing on top of the info bar. Order otherwise as 26.2. ★★★

**26.4 reorders the hotbar** ★★★: `MISC_OVERLAYS, CROSSHAIR, ARMOR_BAR, HEALTH_BAR, FOOD_BAR, AIR_BAR,
MOUNT_HEALTH, INFO_BAR, EXPERIENCE_LEVEL, INFO_BAR_FOREGROUND, SPECTATOR_MENU, HOTBAR, HELD_ITEM_TOOLTIP, …`
(rest unchanged). `SPECTATOR_MENU` and `HOTBAR` now draw **after** the status bars instead of before
`ARMOR_BAR`, so anything attached before/after `HOTBAR` changes its z-order relative to the bars.
Whether this is vanilla-driven or a Fabric choice was not traced. Re-check overlap on 26.4.

**Status-bar height (`HudStatusBarHeightRegistry`, since 2025-08; extended 0.163.0)** ★★★:
`addLeft/addRight/getHeight` register how tall your bar is so stacked bars don't overlap (the Fabric
equivalent of Forge 1.20.1's `leftHeight`/`rightHeight`, §1.4). 26.3 adds `replaceLeft`,
`replaceRight` and `getElementHeight`; 0.160.4 fixed bars whose height isn't 10.

**Other UI hooks worth knowing (26.3+)** ★★★: title/subtitle receive events on
`ClientReceiveMessageEvents` (0.166.0: `ALLOW_TITLE`, `MODIFY_TITLE`, `TITLE`, `TITLE_CANCELED`,
`ALLOW_SUBTITLE`, `MODIFY_SUBTITLE`, `SUBTITLE`, …) for restyling or suppressing titles without a
mixin; `ItemComponentTooltipProviderRegistry` add* methods gain `TooltipProvider.Getter` overloads
(0.160.6); `AdvancementRenderer.registerIcon/Frame/Background` (since 26.1);
`PictureInPictureRendererRegistry` public ctor deprecated for removal, and PiP init fixed for secondary
`GuiRenderer`s (0.166.0). No UI module was added, removed or renamed: the 47-module set is identical on
the 26.2, 26.3 and 26.4 branches.

### 1.3 NeoForge ★★★

| MC band | Register | Intercept |
|---|---|---|
| 1.20.2–1.20.4 | `RegisterGuiOverlaysEvent` + `IGuiOverlay` + `VanillaGuiOverlay` | `RenderGuiOverlayEvent.Pre/Post` |
| **1.20.5 → 26.3** | **`RegisterGuiLayersEvent`** + **`GuiLayer`** + **`VanillaGuiLayers`** | **`RenderGuiLayerEvent.Pre/Post`** |
| 26.4 | **no NeoForge build** (releases maven has no `26.4*`; primer is draft PR neoforged/.github #51) | — |

There is **no** `RegisterGuiElementsEvent` — verified against NeoForge branches `1.21.11`,
`26.2.x` and `26.3.x`. Do not invent it. On 26.3 `RegisterGuiLayersEvent`, `GuiLayer` and the
`VanillaGuiLayers` file are **unchanged from 26.2** (branch read 2026-11-11). ★★★

```java
// RegisterGuiLayersEvent (26.2.x) — MOD bus, client only, not cancellable
public void registerBelowAll(Identifier id, GuiLayer layer);
public void registerBelow  (Identifier other, Identifier id, GuiLayer layer);
public void registerAbove  (Identifier other, Identifier id, GuiLayer layer);
public void registerAboveAll(Identifier id, GuiLayer layer);
public void replaceLayer(Identifier id, GuiLayer replacement);            // throws if absent
public void wrapLayer   (Identifier id, UnaryOperator<GuiLayer> wrapper); // e.g. pose transforms
```

`replaceLayer`/`wrapLayer` landed **after 1.21.5** (exact version unpinned).
`GuiLayer` is `render(GuiGraphicsExtractor, DeltaTracker)` on 26.x,
`render(GuiGraphics, DeltaTracker)` on 1.20.5–1.21.11.

`RenderGuiLayerEvent` (game bus): `getGuiGraphics()`, `getPartialTick()`, `getName()` → `Identifier`,
`getLayer()`. `Pre implements ICancellableEvent`; cancelling skips the layer **and** suppresses `Post`.
You cannot force an inactive layer to render. `RenderGuiEvent.Pre/Post` brackets the whole HUD;
cancelling `Pre` removes the HUD entirely.

`CustomizeGuiOverlayEvent` survives in 26.2 and 26.3 with `BossEventProgress` (cancellable) and `Chat`
(non-cancellable; `get|setPosX/PosY`).

> **`VanillaGuiLayers` drifts with vanilla.** 1.21.1 has `JUMP_METER, EXPERIENCE_BAR, DEBUG_OVERLAY,
> SAVING_INDICATOR`; 1.21.11 drops those and adds `AFTER_CAMERA_DECORATIONS,
> CONTEXTUAL_INFO_BAR_BACKGROUND, CONTEXTUAL_INFO_BAR, EFFECTS, SPECTATOR_TOOLTIP`. **Never hardcode
> a constant list across bands** — read the file on your target branch. ★★★

```java
@EventBusSubscriber(modid = MOD_ID, bus = Bus.MOD, value = Dist.CLIENT)
public final class ClientGui {
    private static final Identifier MY = Identifier.fromNamespaceAndPath(MOD_ID, "my_layer");
    @SubscribeEvent static void layers(RegisterGuiLayersEvent e) {
        e.registerBelow(VanillaGuiLayers.CHAT, MY, (g, dt) -> g.fill(10, 10, 60, 40, 0xFF00FF00));
    }
}
@SubscribeEvent static void hide(RenderGuiLayerEvent.Pre e) {      // game bus
    if (e.getName().equals(VanillaGuiLayers.CROSSHAIR)) e.setCanceled(true);
}
```

### 1.4 MinecraftForge 1.20.1 ★★★

All four classes live only on branch `1.20.1` (deleted at 1.20.5 — "Mojang created a layered
rendering system that should make this all obsolete finally").

```java
// net.minecraftforge.client.event.RegisterGuiOverlaysEvent — MOD bus, client only
public void registerBelowAll(@NotNull String id, @NotNull IGuiOverlay overlay);
public void registerBelow  (@NotNull ResourceLocation other, @NotNull String id, @NotNull IGuiOverlay o);
public void registerAbove  (@NotNull ResourceLocation other, @NotNull String id, @NotNull IGuiOverlay o);
public void registerAboveAll(@NotNull String id, @NotNull IGuiOverlay overlay);

// net.minecraftforge.client.gui.overlay.IGuiOverlay
void render(ForgeGui gui, GuiGraphics graphics, float partialTick, int screenWidth, int screenHeight);
```

Note the asymmetry: **your** id is a bare `String` (auto-namespaced to your modid), the **anchor** is
a `ResourceLocation` from `VanillaGuiOverlay.<X>.id()`.

**`VanillaGuiOverlay` (27 constants):** `VIGNETTE, SPYGLASS, HELMET, FROSTBITE, PORTAL, HOTBAR,
CROSSHAIR, BOSS_EVENT_PROGRESS, PLAYER_HEALTH, ARMOR_LEVEL, FOOD_LEVEL, AIR_LEVEL, MOUNT_HEALTH,
JUMP_BAR, EXPERIENCE_BAR, ITEM_NAME, SLEEP_FADE, POTION_ICONS, DEBUG_TEXT, FPS_GRAPH, NETWORK_GRAPH,
RECORD_OVERLAY, TITLE_TEXT, SUBTITLES, SCOREBOARD, CHAT_PANEL, PLAYER_LIST`.

```java
@SubscribeEvent // game bus — compare with .type(), NOT .id()
public static void hide(RenderGuiOverlayEvent.Pre e) {
    if (e.getOverlay() == VanillaGuiOverlay.CROSSHAIR.type()) e.setCanceled(true);
}
```

**`ForgeGui extends Gui`** — the `gui` param. Public mutable `int leftHeight` / `int rightHeight`,
**both initialised to 39**, tracking stacked HUD height on each side above the hotbar. *Increment them
when you draw a bar* so vanilla and other mods stack instead of overlapping — this is the Band-A
equivalent of good HUD citizenship. Also `setupOverlayRenderState(boolean blend, boolean depthTest)`,
`shouldDrawSurvivalElements()`.

### 1.5 MinecraftForge on 26.x — a third HUD API; don't target it ★★★

Forge (LexForge) ships 26.x builds (26.3 = **66.1.5**, also the recommended build; 26.2 = 65.1.6;
26.1.2 = 64.1.6), with a HUD API that is neither Fabric's nor NeoForge's:

| Concern | Forge 26.3 |
|---|---|
| HUD | `AddGuiOverlayLayersEvent(ForgeLayeredDraw getLayeredDraw)`, a record event on `AddGuiOverlayLayersEvent.BUS`. `ForgeLayeredDraw`: `add`, `addAbove/addBelow`, `addWithCondition`, `addConditionTo`, `putAbove/putBelow/move`, `replace`, `locateStack`, `getChild`. Layer = `ForgeLayer.extract(GuiGraphicsExtractor, DeltaTracker)`. Named stacks/layers include `HOTBAR_AND_DECOS`, `ITEM_HOTBAR`, `HEALTH_BAR`, `EXPERIENCE_LEVEL`, `CONTEXTUAL_INFO`, `CHAT_OVERLAY`, `TAB_LIST`, … |
| Legacy | `RegisterGuiOverlaysEvent` source is wholly commented out |
| Event bus | **EventBus 7**: per-event `public static final EventBus<X> BUS` / `CancellableEventBus` |
| Screens | `ScreenEvent.Init.Pre/Post`, `BackgroundRendered` (old name kept), `Opening`, `Closing`, mouse/key Pre/Post |
| Keys | `RegisterKeyMappingsEvent.BUS` → `register(KeyMapping)`; `KeyConflictContext`, `KeyModifier` present |
| Config screen | `ConfigScreenHandler.ConfigScreenFactory` (`BiFunction<Minecraft, Screen, Screen>` or `Function<Screen, Screen>`), unchanged in shape |
| PiP / tooltips | `RegisterPictureInPictureRendererEvent.register(PictureInPictureRenderer<?>)` (an instance, not a supplier); `RegisterClientTooltipComponentFactoriesEvent.BUS` |

**Recommendation: do not support it** (★, judgement on ★★★ data). It is a full extra platform layer
(third HUD API, separate event bus) for little reach, and most UI libraries have no Forge 26.x build:
YACL, Cloth Config, JEI, REI, Sodium, Iris, ImmediatelyFast, Controlify, Architectury API, Catalogue
Resourceful Config and MidnightLib have **no Forge 26.x build** (Modrinth tags for 26.3: forge
2,816 vs neoforge 5,625 vs fabric 10,005, inflated by multi-loader uploads). Keep the rule: **Forge on 1.20.1 only.**

---

## 2. Screen events (injecting into vanilla screens)

### 2.1 Cross-map

| Intent | Fabric ≤1.21.11 | Fabric 26.x | NeoForge / Forge |
|---|---|---|---|
| add widget after screen builds | `ScreenEvents.AFTER_INIT` + `Screens.getButtons` | `AFTER_INIT` + `Screens.getWidgets` | `ScreenEvent.Init.Post` + `addListener` |
| veto screen construction | *(none)* | *(none)* | `ScreenEvent.Init.Pre` (cancel) |
| swap the screen being opened | *(mixin)* | *(mixin)* | `ScreenEvent.Opening` (`setNewScreen`, cancel) |
| draw under the widgets | *(none)* | `afterBackground` | `BackgroundRendered` / `Render.Background` |
| draw over everything | `afterRender` | `afterExtract` (26.4: no mouse/tick params) | `Render.Post` |
| eat a click | `ScreenMouseEvents.allowMouseClick` → `false` | same | `MouseButtonPressed.Pre` (cancel) |
| screen closed | `ScreenEvents.remove(screen)` | same | `ScreenEvent.Closing` |

### 2.2 Fabric — `fabric-screen-api-v1` ★★★

```java
// ≤1.21.11
Event<BeforeInit> BEFORE_INIT;  // (Minecraft, Screen, int scaledW, int scaledH)
Event<AfterInit>  AFTER_INIT;
static Event<Remove>       remove(Screen);
static Event<BeforeRender> beforeRender(Screen);  // (Screen, GuiGraphics, int mX, int mY, float tickDelta)
static Event<AfterRender>  afterRender(Screen);
static Event<BeforeTick>/<AfterTick> beforeTick/afterTick(Screen);
```

**26.1/26.2 renamed and expanded** — `beforeRender`→`beforeExtract`, `afterRender`→`afterExtract`,
plus two genuinely new mid-render hooks:

```java
static Event<BeforeExtract>   beforeExtract(Screen);    // (Screen, GuiGraphicsExtractor, int, int, float)
static Event<AfterBackground> afterBackground(Screen);  // NEW — between background and content
static Event<AfterForeground> afterForeground(Screen);  // NEW — after content, before tooltips
static Event<AfterExtract>    afterExtract(Screen);
```

**26.3** (fabric-screen-api-v1 5.2.4): same signatures as 26.2. **26.4** (fabric-screen-api-v1
**6.0.x**, a breaking major) ★★★: `beforeExtract`, `afterBackground`, `afterForeground` and
`afterExtract` become `(Screen, GuiGraphicsExtractor)`; mouse position and tick progress come from
the extractor (`mouseX()`, `mouseY()`, `partialTicks()`), mirroring vanilla 26.4 dropping those
params from `Renderable`. `before/afterTick`, `BEFORE_INIT/AFTER_INIT` and `remove` are unchanged.

**`Screens` helper — renamed in 26.1:**

| ≤1.21.11 | 26.1+ |
|---|---|
| `List<AbstractWidget> getButtons(Screen)` | `List<AbstractWidget> getWidgets(Screen)` |
| `Font getTextRenderer(Screen)` *(deprecated)* | `Font getFont(Screen)` *(deprecated — use `Screen#getFont()`)* |
| `Minecraft getClient(Screen)` | `Minecraft getMinecraft(Screen)` |

The returned list is **live** and is the supported mutation point — preferred over adding to the
screen's children directly.

```java
ScreenEvents.AFTER_INIT.register((mc, screen, w, h) -> {
    if (screen instanceof TitleScreen) {
        Screens.getWidgets(screen).add(Button.builder(Component.literal("Hi"), b -> {})
            .bounds(w / 2 - 100, h / 4 + 96, 200, 20).build());
    }
});
```

Caveat from the javadoc: adding a **non-button** element does not auto-render it — you must also draw
it from `afterRender`/`afterExtract`. Use `BEFORE_INIT` only to register the per-screen sub-events;
the font may not exist yet.

**`ScreenMouseEvents`** — 12 accessors, `allow/before/after × Click/Release/Drag/Scroll`. Order is
**Allow → Before → After**; `false` from Allow suppresses both. 1.21.9 folded loose params into event
objects and made mouse callbacks return `boolean`:

```java
boolean allowMouseClick (Screen, MouseButtonEvent);          // 1.21.9+
void    beforeMouseClick(Screen, MouseButtonEvent);
boolean afterMouseClick (Screen, MouseButtonEvent, boolean handled);
boolean allowMouseScroll(Screen, double mX, double mY, double dx, double dy);
```

**`ScreenKeyboardEvents`** (26.2) — 9 accessors: `allow/before/afterKeyPress`, `…KeyRelease` with
`KeyEvent`, plus **new** `allow/before/afterCharType` with `CharacterEvent`. Signatures unchanged on
26.3 and 26.4; on 26.3 the javadoc moved from `GLFW.GLFW_KEY_Q` / `GLFW_MOUSE_BUTTON_1` to
`InputConstants.KEY_Q` / `MOD_SHIFT` / `MOUSE_BUTTON_LEFT`, because the `KeyEvent` now carries SDL
scancode, keycode and modifiers. Compare against `InputConstants.*`, never against GLFW ints. ★★★

### 2.3 NeoForge — `ScreenEvent` (game bus, client only) ★★★

**1.20.2–1.21.11 shape:**

```
Init.Pre (cancellable) / Init.Post
    List<GuiEventListener> getListenersList(); void addListener(GuiEventListener); void removeListener(…);
Render.Pre (cancellable) / Render.Post     (Screen, GuiGraphics, int mX, int mY, float partialTick)
BackgroundRendered                          (Screen, GuiGraphics)   // top-level nested, NOT under Render
RenderInventoryMobEffects (cancellable)
MouseButtonPressed.Pre(Screen,double,double,int) / .Post(…, boolean handled) → wasHandled()
MouseButtonReleased.Pre/.Post · MouseDragged.Pre/.Post · MouseScrolled.Pre/.Post
KeyPressed.Pre/.Post(Screen,int keyCode,int scanCode,int modifiers)  (both cancellable)
KeyReleased.Pre/.Post · CharacterTyped.Pre/.Post(Screen,char,int)
Opening (cancellable; getCurrentScreen/getNewScreen/setNewScreen) · Closing
```

**26.2 deltas:** `BackgroundRendered` → **`ScreenEvent.Render.Background`**, plus new
**`Render.Foreground`** (after contents, before deferred tooltips), both taking
`(Screen, GuiGraphicsExtractor, int, int, float)`. Input events take event objects
(`MouseButtonPressed.Pre(Screen, MouseButtonEvent, boolean doubleClick)`, `KeyPressed.Pre(Screen,
KeyEvent)`, `CharacterTyped.Pre(Screen, CharacterEvent)`), plus new `Preedit.Pre/.Post` for IME
composition. `MouseButtonPressed.Post`/`MouseButtonReleased.Post` gained a tri-state
`Result { FORCE_HANDLED, DEFAULT, FORCE_UNHANDLED }`. `MouseScrolled` carries
`getScrollDeltaX()/getScrollDeltaY()`. Source moved to `src/client/java`.

`ScreenEvent.Preedit.Pre/.Post` (added on 26.2.x, PR #3410) exists so overlay text fields, such as a
recipe viewer's search box, can take IME composition text without a `KeyboardHandler` mixin. ★★★ (★★
for the stated purpose)

**26.3 deltas (SDL3 fallout)** ★★★:

| 26.2 | 26.3 |
|---|---|
| `KeyPressed/KeyReleased.getKeyCode()` | **`getKey()`** (SDL scancode, physical, what `KeyMapping` binds) |
| `KeyPressed/KeyReleased.getScanCode()` | **`getKeycode()`** (SDL keycode, layout-dependent) |
| `InputEvent.Key.getScanCode()` | **`getKeycode()`** |
| `AbstractWidget#getFGColor()` (NeoForge patch) | **`getLabelTextColor()`**, `TextColor`-based (PR #3063); touches `ExtendedButton`, `UnicodeGlyphButton` |
| `ConfigurationScreen` server-config gating | gates on `ModConfig.Type.SYNCED` |

The names swap meaning, so a mechanical rename compiles but reads the wrong value: `getKey()` is the
old *key code* slot. Also on 26.3: `KeyBindsList` fixes (presses ignored after mouse selection, #3466;
ignore next release on a new selection, #3446); deprecated for removal: `CreativeModeTab` `tabsImage`
(#3467), `Font#enableTextTextureLinearFiltering` (#3468).

```java
@SubscribeEvent // game bus
public static void onInit(ScreenEvent.Init.Post e) {
    if (e.getScreen() instanceof PauseScreen ps) {
        e.addListener(Button.builder(Component.translatable("gui.mymod.open"),
                b -> Minecraft.getInstance().setScreen(new MyScreen(ps)))
            .bounds(ps.width - 110, 6, 100, 20).build());
    }
}
```

Use `addListener`, not `getListenersList().add(...)` — the list is a view; the consumer is the
supported mutator.

### 2.4 MinecraftForge 1.20.1

Identical shape to the NeoForge 1.21.1 list above (NeoForge inherited it). Differences: `@Cancelable`
annotation instead of `ICancellableEvent`, and `MinecraftForge.EVENT_BUS` instead of
`NeoForge.EVENT_BUS`.

---

## 3. Keybindings

### 3.1 Cross-map

| Concern | Fabric ≤1.21.11 | Fabric 26.x | NeoForge / Forge |
|---|---|---|---|
| register | `KeyBindingHelper.registerKeyBinding` | `KeyMappingHelper.registerKeyMapping` | `RegisterKeyMappingsEvent#register` (mod bus) |
| module | `fabric-key-binding-api-v1` | **`fabric-key-mapping-api-v1`** | — |
| category | `String` → `KeyMapping.Category` at 1.21.9 | `KeyMapping.Category.register(Identifier)` | same vanilla change; `registerCategory()` @21.9+ |
| category lang key | `key.categories.<modid>` (old) / `key.category.<ns>.<path>` (1.21.9+) | `key.category.<ns>.<path>` | identical |
| tick poll | `ClientTickEvents.END_CLIENT_TICK` | same | `ClientTickEvent.Post` |
| conflict context | **none** | **none** | `KeyConflictContext` |
| modifiers | **none** (roll your own) | **none** | `KeyModifier` |
| unbound default | `InputUtil.UNKNOWN_KEY` | `InputConstants.UNKNOWN` | `InputConstants#UNKNOWN` |
| input type (26.3+) | — | `InputConstants.Type.KEYBOARD` (`KEYSYM` renamed, `SCANCODE` removed) | same |
| key constant (26.3+) | — | `InputConstants.KEY_*` (SDL scancodes); `GLFW.*` gone | same |

`fabric-keybindings-v0` (the ancient module) was removed in 1.21.6. ★★★
`KeyMappingHelper` (fabric-key-mapping-api-v1 2.0.8 on 26.3, 2.0.9 on 26.4) is signature-unchanged
through 26.4; only its javadoc example moved to `Type.KEYBOARD, InputConstants.KEY_P`. ★★★

> **Keybind registration under SDL3 (26.3+)** ★★★. The registration calls are unchanged; the
> *values* are not. Key ints are now SDL scancodes (e.g. Escape 256 → 41, Space 32 → 44), so a
> hard-coded GLFW int still compiles and silently binds a different key. Always pass
> `InputConstants.KEY_*` (or `InputConstants.UNKNOWN`), and route the constant through a per-band
> adapter if one source tree targets both GLFW (≤26.2) and SDL (26.3+) bands. Modifier masks also
> changed (SDL `MOD_SHIFT=3, MOD_CONTROL=192, MOD_ALT=768`): test with `KeyEvent.hasShiftDown()` etc.
> or `InputConstants.MOD_*`, never with GLFW bit values. Full key-code table: `minecraft-mod-expert`
> `api-migration-deltas.md` (Input / windowing).

### 3.2 Fabric ★★★

```java
private static final KeyMapping.Category CATEGORY =                       // 1.21.9+
    KeyMapping.Category.register(Identifier.fromNamespaceAndPath(MOD_ID, "main"));

OPEN = KeyMappingHelper.registerKeyMapping(new KeyMapping(
    "key." + MOD_ID + ".open",
    InputConstants.Type.KEYSYM,           // 26.3+: InputConstants.Type.KEYBOARD
    InputConstants.KEY_J,                 // or InputConstants.UNKNOWN.getValue() for "no default"
    CATEGORY));

ClientTickEvents.END_CLIENT_TICK.register(client -> {
    while (OPEN.consumeClick()) { ... }   // ALWAYS a while loop, never an if
});
```

`consumeClick()` decrements a queued-press counter and returns `true` once per press. `if` instead of
`while` makes presses accumulate and fire late. `isDown()` is the held-state boolean and does not
consume.

**Modifier keys on Fabric: there is no API.** `KeyMappingHelper` has exactly two methods and vanilla
`KeyMapping` has no modifier concept. Test `Screen.hasShiftDown()/hasControlDown()/hasAltDown()`
inside your handler, or accept the conflict. `KeyConflictContext`/`KeyModifier` are
NeoForge/Forge-only. ★★

### 3.3 NeoForge / Forge — same API surface, mod bus, physical client only ★★★

```java
public void register(KeyMapping key);
public void registerCategory(KeyMapping.Category category);   // 1.21.9+ only

// Forge 1.20.1 / NeoForge ≤21.8 — String category
new KeyMapping("key.examplemod.open", KeyConflictContext.IN_GAME, KeyModifier.SHIFT,
    InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_G, "key.categories.examplemod");
// NeoForge 21.9 → 26.2 — Category record
new KeyMapping("key.examplemod.open", KeyConflictContext.UNIVERSAL, KeyModifier.SHIFT,
    InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_G, KeyMapping.Category.MISC);
// NeoForge 26.3+ — no GLFW; SDL scancode constants
new KeyMapping("key.examplemod.open", KeyConflictContext.UNIVERSAL, KeyModifier.SHIFT,
    InputConstants.Type.KEYBOARD, InputConstants.KEY_G, KeyMapping.Category.MISC);
```

**NeoForge 26.3 internals** ★★★: `KeyModifier`/`KeyMappingLookup` now use
`InputConstants.Type.KEYBOARD.getOrCreate(InputConstants.KEY_LCONTROL …)`, `KEY_LGUI/RGUI` (was
SUPER) and `InputConstants.isKeyDown(int)`. **Pin NeoForge ≥ 26.3.0.90**: rebound keys with a modifier
(saved as `key.keyboard.s:SHIFT`) failed to load until after 26.3.0.86 (issue #3661). On older 26.3
builds a user's modifier rebinding of your key would not survive a restart (★, inferred symptom).

- `KeyConflictContext`: `UNIVERSAL` (default), `GUI` (only while a Screen is open), `IN_GAME` (only
  when none is). Custom via `IKeyConflictContext`.
- `KeyModifier`: `CONTROL`, `SHIFT`, `ALT`, `NONE`.
- Input types ≤26.2: `KEYSYM` (GLFW tokens — recommended), `SCANCODE` (layout-specific), `MOUSE`.
  **KEYSYM token names assume a US layout** — an AZERTY user sees a different physical key.
  26.3+: `KEYBOARD` (SDL scancode = physical position) and `MOUSE`; `SCANCODE` is gone. Bind labels
  in the Controls screen now follow the user's keyboard layout (vanilla `KeyBindsScreen`).
- In a GUI, use `IForgeKeyMapping#isActiveAndMatches(InputConstants.getKey(key, scancode))` — it is
  the one that honours conflict context and modifier.

**Design rule:** bind a default key only for your mod's single core action. Everything else ships
**unbound** (`InputConstants#UNKNOWN`) — an unbound mapping can never conflict, and users who want it
will bind it.

---

## 4. Config screens — how the user reaches your settings

### 4.1 Cross-map

| | Fabric / Quilt | NeoForge 21.0+ | Forge 1.20.1 |
|---|---|---|---|
| Mods list in vanilla UI? | **No** — needs Mod Menu | Yes (built-in) | Yes (built-in) |
| Registration | `modmenu` entrypoint → `ModMenuApi#getModConfigScreenFactory` | `container.registerExtensionPoint(IConfigScreenFactory.class, …)` | `ModLoadingContext.get().registerExtensionPoint(ConfigScreenHandler.ConfigScreenFactory.class, …)` |
| Screen auto-generated from spec? | No | **Yes** (`ConfigurationScreen`), opt-in | No — 3rd-party (Configured / Catalogue / Cloth) |
| Factory signature | `Screen create(Screen parent)` | `Screen createScreen(ModContainer, Screen modListScreen)` | `BiFunction<Minecraft, Screen, Screen>` |

### 4.2 Fabric — Mod Menu is the only route ★★★

Vanilla Fabric has **no mods list at all**; without Mod Menu there is no pause-menu entry point.
Mod Menu **20.0.3** (26.2), **21.0.0** (26.3), **22.0.0-alpha.4** (26.4-snapshot-8), Fabric & Quilt.
The `custom.modmenu` keys and `ModMenuApi` are identical on the 26.2, 26.3 and 26.4 branches. ★★★

```json
"entrypoints": { "modmenu": [ "com.example.mod.ExampleModMenuApiImpl" ] },
"custom": {
  "modmenu": {
    "badges": [ "library" ],                       // only "library" and "deprecated" exist
    "links": { "modmenu.example_mod.discord": "https://discord.gg/..." },
    "parent": "example-mod-core",
    "update_checker": true
  }
}
```

```java
public class ExampleModMenuApiImpl implements ModMenuApi {
    @Override public ConfigScreenFactory<?> getModConfigScreenFactory() {
        return parent -> new MyConfigScreen(parent);
    }
}
```

Mod name/description are translatable **only through Mod Menu**:
`modmenu.nameTranslation.<modid>`, `modmenu.summaryTranslation.<modid>` (list row),
`modmenu.descriptionTranslation.<modid>` (detail pane). ★★

### 4.3 NeoForge ★★★

```java
@Mod(value = "examplemod", dist = Dist.CLIENT)
public class ExampleModClient {
    public ExampleModClient(ModContainer container) {
        container.registerExtensionPoint(IConfigScreenFactory.class, ConfigurationScreen::new);
    }
}
```

**The nuance usually gotten wrong:** NeoForge auto-*generates the screen contents* from your
registered `ModConfigSpec`s, but does **not** auto-register the extension point. It is opt-in; there
is nothing to opt out of. Introduced in NeoForge 21.0 (MC 1.21).

Customisation ladder (26.2 constructors):

```java
ConfigurationScreen(ModContainer mod, Screen parent)
ConfigurationScreen(ModContainer mod, Screen parent, ConfigurationSectionScreen.Filter filter)
ConfigurationScreen(ModContainer mod, Screen parent,
    Function4<ConfigurationScreen, ModConfig.Type, ModConfig, Component, Screen> sectionScreen)
```

STARTUP/COMMON/CLIENT always editable; **SERVER configs editable only when playing locally**.
On **26.3+** read that as STARTUP/**LOCAL**/CLIENT always editable, **SYNCED** only when local: the
screen's gating now tests `ModConfig.Type.SYNCED`. Constructors are unchanged on 26.3, and
`IConfigScreenFactory` is still `Screen createScreen(ModContainer, Screen modListScreen)`. The
`/config` command was **removed** on 26.3 (PR #3547), so the mods-list button is the only built-in
route to the screen. ★★★
Untranslated keys are printed to console after you visit every section — a free lint pass.

### 4.4 Forge 1.20.1 ★★★

```java
ModLoadingContext.get().registerExtensionPoint(
    ConfigScreenHandler.ConfigScreenFactory.class,
    () -> new ConfigScreenHandler.ConfigScreenFactory(
        (mc, prevScreen) -> new MyConfigScreen(prevScreen)));
```

Your close button must call `Minecraft#setScreen(prevScreen)`. Forge 1.20.1 has **no built-in config
UI** — write the `Screen` yourself or depend on Configured / Catalogue / Cloth Config. ★

### 4.5 Config file formats

| Loader / band | Spec class | Types | Suffix |
|---|---|---|---|
| Forge 1.20.1 | `ForgeConfigSpec` via `ModLoadingContext#registerConfig` | CLIENT / COMMON / SERVER | `-client` `-common` `-server` |
| NeoForge 1.20.2 → 26.2 | `ModConfigSpec` via `container.registerConfig` | **STARTUP** / CLIENT / COMMON / SERVER | `-startup` `-client` `-common` `-server` |
| **NeoForge 26.3+** (FML 12) | `ModConfigSpec` via `container.registerConfig` | **STARTUP / CLIENT / LOCAL / SYNCED** | `-startup` `-client` **`-local`** **`-synced`** |
| Fabric / Quilt | **none — no built-in config system at all** | — | by convention `config/<modid>.json` |

> **26.3 rename** ★★★ (FML PR #436 / NeoForge PR #3384, merged during the 26.3 beta, before stable
> 26.3.0.76): `ModConfig.Type.COMMON` → **`LOCAL`**, `SERVER` → **`SYNCED`**; CLIENT and STARTUP
> unchanged. The suffix is the lowercase type name, so files become `<modid>-local.toml` /
> `<modid>-synced.toml`, and the per-world override directory is **`syncedconfig`** (was
> `serverconfig`). `ModConfigSpec` uses `GAME(ModConfig.Type.SYNCED)`; NeoForge's config-section
> translation keys were updated to match (#3574). Every `registerConfig(ModConfig.Type.COMMON/SERVER,
> …)` is a compile break on 26.3. Existing users' `-common`/`-server` files are not picked up under
> the new names unless you migrate them (★, inference). Whether Forge Config API Port 26.3.1 maps
> COMMON/SERVER onto LOCAL/SYNCED cleanly was **not verified**.

TOML on both Forge families, in `.minecraft/config/`. SERVER (26.3+: SYNCED) configs sync to clients
and are overridable per-world at `saves/<world>/serverconfig` (26.3+: `syncedconfig`). STARTUP is NeoForge-only, loads immediately on
both sides, and the docs warn it can desync client/server if used to toggle content. Values are cached
— `ConfigValue#get()` does not re-read the file. Lifecycle events
(`ModConfigEvent.Loading/.Reloading/.Unloading`) are on the **mod bus** and fire for every config the
mod owns, so branch on the passed `ModConfig`.

NeoForge 21.0 added a **required new parameter to `defineList()`** supplying the default for a newly
added entry — a silent compile break when porting from Forge.

---

## 5. Client-only vs common code

| Mechanism | Fabric / Quilt | NeoForge | Forge 1.20.1 |
|---|---|---|---|
| Declare side | `"environment": "client"` in `fabric.mod.json` | `side = "CLIENT"` dep + `@Mod(dist = Dist.CLIENT)` | `side` in `mods.toml` |
| Client entrypoint | `"entrypoints": {"client": [...]}` → `ClientModInitializer` | separate `@Mod(dist = Dist.CLIENT)` class | separate class + `DistExecutor` |
| Physical side check | `FabricLoader.getInstance().getEnvironmentType()` | `FMLEnvironment.dist` (≤21.8) → `FMLEnvironment.getDist()` / `FMLLoader.getCurrent().getDist()` (21.9+) | `FMLEnvironment.dist` |
| Logical side check | `level.isClientSide` | `Level#isClientSide()` | `Level#isClientSide()` |
| Class stripping | mixin `"environment": "client"`; `src/client/java` source set | `@OnlyIn(Dist.CLIENT)` (discouraged) | `@OnlyIn` (discouraged) |
| `DistExecutor` | n/a | **removed in NeoForge 21.0, no replacement** | present, and the recommended tool here |

### Dedicated-server safety checklist

1. **Two entrypoints, two classes.** Listing the same class as both `main` and `client` on Fabric
   means it is **loaded on a dedicated server** even though the client entrypoint never runs — and its
   field types reach `Minecraft`, crashing.
2. **Use split source sets** (`src/client/java`) so the compiler catches leaks, not the server.
3. **Never reference `Minecraft`, `Screen`, `GuiGraphics(Extractor)`, `KeyMapping`, `RenderSystem`
   from a common class** — not in a field type, not in a method signature. Signature-level references
   resolve at verification time.
4. **Split mixin configs by environment.**
5. **Register client hooks only from client code.** `RegisterGuiLayersEvent`,
   `RegisterKeyMappingsEvent`, `IConfigScreenFactory`, `HudElementRegistry` are all physical-client
   only. A common `@EventBusSubscriber` without `value = Dist.CLIENT` is the classic crash.
6. **`displayTest`**: a client-only UI mod should set `IGNORE_ALL_VERSION` so servers don't red-X it in
   the server browser. `IGNORE_SERVER_VERSION` for server-only; `MATCH_VERSION` (default) for
   both-sides mods.
7. **Watch static fields.** `static final KeyMapping` on a class touched from common code loads
   `KeyMapping` on the server. No compile warning.
8. **Actually boot a dedicated server in CI.** Singleplayer runs a logical server inside a physical
   client and will never reproduce this class of bug.

---

## 6. Mod-list metadata that affects UX

**Icon.** Fabric/Quilt: `"icon": "assets/<modid>/icon.png"` or a `{"64": …, "128": …}` map; square PNG,
128×128 typical. Forge 1.20.1 and NeoForge ≤ 26.1: `logoFile = "logo.png"` relative to jar root, plus
`logoBlur = true|false` (GL_LINEAR vs GL_NEAREST — set **false** for pixel art or your logo gets
smeared).

**NeoForge 26.2+ mods screen (overhauled, PR #3073, merged to 26.2.x 2026-08-07)** ★★★. The new
screen reads these `[[mods]]` keys (falling back to file-level):

| Key | Use |
|---|---|
| `iconFile` | square list icon (`"<packId>#<path>"` form allowed) |
| `iconBlur` (bool, default false) | linear filtering for the icon. Leave false for pixel art |
| `bannerFile` → falls back to `logoFile` | info-panel banner, aspect kept, bounded by panel width × banner height |
| `authors`, `credits` | shown when non-empty |
| `displayURL` → falls back to `modUrl` | homepage button (disabled when absent) |
| `issueTrackerURL` | issues button |
| `licenseURL` | makes the license clickable |

**`logoBlur` is no longer read anywhere in the NeoForge 26.2+/26.3 client** — use `iconBlur`. Ship
both `iconFile` (square) and `bannerFile` (wide); a mod with only `logoFile` gets a banner but no list
icon. Programmatic override: `container.registerExtensionPoint(ModDisplayInfo.class, …)` (`id,
displayName, version, authors, credits, description, license, banner, icon, iconBlur, displayUrl,
issuesUrl`; components may carry click/hover events, except `displayName`). The screen also adds a
changelog view and an update indicator. The config button still resolves `IConfigScreenFactory`.

**Translating the mod name / description:** Fabric + Mod Menu yes (§4.2). NeoForge 26.2+: the
**description** is translatable via `neoforge.screen.mods.info.description.<modid>` (falls back to the
TOML `description`). The 26.2 fallback key `fml.menu.mods.info.description.<modid>` was **removed in
26.3**, so rename it if you used it. ★★★ `displayName` stays a literal string. Forge: **no** —
`displayName`/`description` in the TOML are literal strings.

**`pack_format` for resource packs shipped inside your mod** ★★★:

| MC | format | MC | format |
|---|---|---|---|
| 1.20–1.20.1 | **15** | 1.21.6 | 63 |
| 1.20.2 | 18 | 1.21.7–1.21.8 | 64 |
| 1.20.3–1.20.4 | 22 | 1.21.9–1.21.10 | **69.0** |
| 1.20.5–1.20.6 | 32 | 1.21.11 | **75.0** |
| 1.21–1.21.1 | **34** | 26.1–26.1.2 | **84.0** |
| 1.21.2–1.21.3 | 42 | 26.2 | **88.0** |
| 1.21.4 | 46 | 26.3 snapshots | 89.0 – 97.x |
| 1.21.5 | 55 | 26.3 release | *not re-verified: read `pack_version.resource` in the client jar's `version.json`* |
| | | 26.4-snapshot-8 | **103.0** (data pack 127.0; snapshot, will move) |

**From 1.21.9 the single `pack_format` int is replaced by `min_format`/`max_format` for data packs**,
and formats gained a minor component (`88.0`, `88.1`; minor bumps = non-breaking). Resource packs kept
`pack_format` + `supported_formats`.

Fabric API 0.162 renamed its resource-pack overlay metadata `OverlayConditionsMetadata` →
**`FabricOverlayMetadataSection`** (moved to api). ★★

---

## 7. Quilt — the honest answer

Status as of 2026-11-11 ★★★: Quilt Loader stable **0.30.2**, beta **0.31.0-beta.6**, and actively
developed; Quilt meta lists 26.4 snapshots. QSL/QFAPI still end at **7.7.0+0.92.2-1.20.1**. The Quilt
blog's last post is the 2026-02-03 retirement notice. On 26.3, Sodium, Iris, YACL, Resourceful
Config 6.x and Fzzy Config dropped the `quilt` tag; Mod Menu, MidnightLib, Puzzle, ImmediatelyFast
still co-tag it. Recommendation unchanged.

- **Quilt Loader is alive** and is the project's stated focus.
- **QSL is discontinued** (December 2025). QSL/QFAPI/CHASM/Quilt Mappings **officially retired for
  26.1+** (announced 2026-02-03).
- **Last stable QFAPI is 7.7.0 / QSL 6.3.0, for MC 1.20.1** (providing Fabric API 0.92.2). MC 1.21
  reached only `11.0.0-alpha.3`. **There is no QFAPI for 1.21.1+.**
- Quilt Loader loads most Fabric mods unchanged. QFAPI reimplements Fabric's `api` packages, **not**
  its `impl` packages — a mod that reaches into `net.fabricmc.fabric.impl.*`, or mixins into Fabric
  API internals, works on Fabric and breaks on Quilt.

> **Recommendation: do not produce a separate Quilt artifact.** Ship the Fabric jar and tag both
> loaders on the same Modrinth/CurseForge file. Depend on `fabric-api` (never `quilted_fabric_api`),
> stay out of `net.fabricmc.fabric.impl.*`, keep the Mod Menu block under `custom.modmenu`. On
> **1.20.1 only**, Quilt users have working QFAPI 7.7.0 so a Fabric-API-dependent mod genuinely works.
> On **1.21.1+ there is no QFAPI** — treat Quilt as best-effort and untested, and say so in the
> description rather than claiming support you cannot test.

Also: **Fabric API dropped the `fabric` mod ID in 26.1** — depend on `fabric-api`. A stale
`"fabric": "*"` dependency hard-fails.

---

## Appendix — master version-change ledger

| Change | Version | Conf |
|---|---|---|
| Forge `RegisterGuiOverlaysEvent`/`IGuiOverlay`/`VanillaGuiOverlay`/`ForgeGui` removed | 1.20.5 | ★★★ |
| NeoForge `RegisterGuiOverlaysEvent`→`RegisterGuiLayersEvent`, `VanillaGuiOverlay`→`VanillaGuiLayers` | NF 20.5 | ★★ |
| `mods.toml` → `neoforge.mods.toml` | 1.20.5 | ★★ |
| `DistExecutor` removed from NeoForge | NF 21.0 | ★★ |
| NeoForge built-in `ConfigurationScreen` + `IConfigScreenFactory` | NF 21.0 | ★★ |
| `defineList()` gains required new-entry default param | NF 21.0 | ★★ |
| Fabric `HudLayerRegistrationCallback` added; `HudRenderCallback` deprecated | fabric-api 0.116.0+1.21.5 | ★★★ |
| Fabric HUD API rewritten → `HudElementRegistry` | 1.21.6 | ★★★ |
| `fabric-keybindings-v0` removed | 1.21.6 | ★★ |
| Vanilla `KeyMapping.Category` replaces `String`; lang key `key.categories.*`→`key.category.<ns>.<path>` | 1.21.9 | ★★★ |
| Screen key events fold into `KeyEvent`; mouse events return `boolean` | 1.21.9 | ★★ |
| `pack_format` → `min_format`/`max_format` + minor versions (data packs) | 1.21.9 | ★★★ |
| `FMLEnvironment.dist`→`getDist()` | NF 21.9 | ★★ |
| Fabric API → Mojang mappings; `HudRenderCallback` removed; `fabric` mod ID dropped; `KeyBindingHelper`→`KeyMappingHelper`; `Screens.getButtons`→`getWidgets`; render→extract hooks | 26.1 | ★★★ |
| `GuiGraphics`→`GuiGraphicsExtractor`; `Screen#render`→`extractRenderState` | 26.1 | ★★★ |
| QSL/QFAPI/Quilt Mappings retired for 26.1+ | 2026-02-03 | ★★★ |
| NeoForge mods-screen overhaul: `iconFile`/`iconBlur`/`bannerFile`, `ModDisplayInfo`; `logoBlur` unused; `ScreenEvent.Preedit` | NF 26.2.x | ★★★ |
| Fabric `HudStatusBarHeightRegistry.replaceLeft/replaceRight/getElementHeight` | fabric-api 0.163.0 | ★★★ |
| Fabric `VanillaHudElements.INFO_BAR_FOREGROUND` | fabric-api 0.165.0 | ★★★ |
| Fabric title/subtitle events in `ClientReceiveMessageEvents` | fabric-api 0.166.0 | ★★★ |
| Vanilla GLFW → SDL3; `InputConstants.Type.KEYSYM` → `KEYBOARD`, key ints = SDL scancodes | 26.3 | ★★★ |
| NeoForge `ModConfig.Type` COMMON→LOCAL, SERVER→SYNCED; `-local`/`-synced`; `syncedconfig`; `/config` removed | NF 26.3 (FML 12) | ★★★ |
| NeoForge `getKeyCode()`→`getKey()`, `getScanCode()`→`getKeycode()`; `getFGColor`→`getLabelTextColor`; `fml.menu.mods.info.description.*` fallback removed | NF 26.3 | ★★★ |
| NeoForge modifier-keybind load fix (#3661) | after NF 26.3.0.86 (pin ≥ 26.3.0.90) | ★★★ |
| Fabric `HudElement` drops `DeltaTracker` + `update(DeltaTracker)`; `ScreenEvents` extract callbacks drop mouse/tick; `fabric-screen-api-v1` 6.0; `HOTBAR`/`SPECTATOR_MENU` draw after status bars | 26.4 snapshots (fabric-api 0.166.x+26.4) | ★★★ |

## Unverified / check before relying on

1. Exact MC version where Fabric's `HudRenderCallback` second param changed `float` → `DeltaTracker`
   (confirmed `float` at 1.20.1, `DeltaTracker` at 1.21.7; almost certainly 1.20.5).
2. Exact NeoForge version where `BackgroundRendered` became `Render.Background` (present as
   `BackgroundRendered` at 1.21.1, as `Render.Background` at 26.2; candidates 21.9 or 26.1).
3. Exact version where `RegisterGuiLayersEvent.replaceLayer`/`wrapLayer` landed (after 1.21.5).
4. Whether `HudLayerRegistrationCallback` was hard-removed at 1.21.6 or deprecated first. Treat
   1.21.6 as the last usable version either way.
5. `VanillaGuiLayers` / `VanillaHudElements` constant lists for bands not read directly — they differ
   materially between 1.21.1 and 1.21.11. **Read the file on your exact target branch.**
6. Forge 1.20.1 config-screen helper mods (Configured, Catalogue, Cloth) — version support not
   verified against their repos.
7. Whether the 26.4 `VanillaHudElements` reorder is vanilla-driven (vanilla `Hud` draw order) or a
   Fabric choice. The Fabric diff is certain; the cause was not traced.
8. NeoForge 26.4: only the draft primer (PR #51) exists. Its HUD, screen-event and menu-screen hooks
   against vanilla 26.4's `MENU_SCREEN` client registry and `Updatable` split are unknown.
9. Whether Forge Config API Port 26.3.1 maps `COMMON`/`SERVER` onto NeoForge's `LOCAL`/`SYNCED`
   cleanly — not read in source.
