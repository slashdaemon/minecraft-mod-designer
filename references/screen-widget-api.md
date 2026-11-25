# Screen / widget / layout / container-screen API — MC 1.20.1 → 26.3 (+26.4 preview)

Most of this file was read with `javap -p -constants` from **Mojang-mapped Minecraft client jars**
(1.20.1, 1.20.5, 1.21.1, 1.21.2, 1.21.4, 1.21.6, 1.21.9, 1.21.11, 26.1.2, 26.2, 26.3,
26.4-snapshot-8), plus NeoForge universal/userdev jars, the Forge 47.1.3 sources jar, and Fabric API
module jars. Gaps (1.20.2, 1.20.3, 1.20.4, 1.21.5) were closed against mappings.dev and the NeoForged
primers. Unmarked rows are **★★★ (primary artifact)**; ★★ means primer/blog or single-source;
★ means inferred.

> **Status as of 2026-11-11:** latest release **26.3** (band K); latest snapshot **26.4-snapshot-8**
> (band L, *not a band yet*). Everything tagged "26.4-s8" was read from the snapshot jar and **is
> subject to change before the 26.4 release** — re-diff against the release jar before porting for
> real. NeoForge has no 26.4 build; Fabric API has `0.166.2+26.4` pre-releases.

> **Four widely-repeated claims that are WRONG:**
> 1. The layout package was **not** added in 1.20.2/1.20.3 — `GridLayout`/`LinearLayout`/`FrameLayout`/
>    `LayoutSettings`/`SpacerElement` are **1.19.3** classes (moved into
>    `net.minecraft.client.gui.layouts` in 1.19.4), `HeaderAndFooterLayout` is **1.19.4**. All of it is
>    fully present in 1.20.1.
> 2. `renderBackground` gained `mouseX/mouseY/partialTick` in **1.20.2**, not 1.20.5 or 1.21.
> 3. `mouseScrolled` gained horizontal scroll in **1.20.2**, not 1.21.
> 4. `ForwardingSlider` **is not vanilla at any version** — it's NeoForge `ExtendedSlider` /
>    Forge `ForgeSlider`.

---

## 0. The era boundaries (A–G, plus the 26.4 preview)

| Era | MC | Defining break |
|---|---|---|
| **A — legacy** | 1.20.1 | `renderBackground(GuiGraphics)`, `renderDirtBackground`, `BACKGROUND_LOCATION`, `EditBox#tick()`, `setTooltipDelay(int)`, `AbstractWidget#render` overridable, 3-arg `mouseScrolled`, sheet textures |
| **B — sprite atlas** | 1.20.2–1.20.4 | GUI sprite atlas + `blitSprite`; 4-arg `renderBackground`; 4-arg `mouseScrolled`; `EditBox#tick()` gone; `Checkbox.builder` (1.20.3) |
| **C — UI refresh** | 1.20.5–1.21.1 | menu blur + `MENU_BACKGROUND`; `WidgetTooltipHolder` + `setTooltipDelay(Duration)`; **`AbstractWidget#render` becomes final** |
| **D — RenderType blits** | 1.21.2–1.21.4 | every blit takes `Function<ResourceLocation,RenderType>`; `ToastComponent`→`ToastManager`; `addStandardInventorySlots` |
| **E — GUI render state** | 1.21.5–1.21.11 | `RenderPipeline` blits, `Matrix3x2fStack`, `GuiRenderState`/`submit*`, `setTooltipForNextFrame`, `ScrollableLayout`; **1.21.9** input event objects; **1.21.11** `init(int,int)` |
| **F — extract/add** | 26.1–26.2 | mass rename `render*`→**`extract*`**, `GuiGraphics`→`GuiGraphicsExtractor`, `renderBg` deleted; `Identifier` |
| **G — SDL input** (band K) | 26.3 | GLFW → **SDL3**: key ints are SDL scancodes, SDL modifier masks and mouse-button numbers (all **silent** if hard-coded); `KeyEvent.scancode()`→`keycode()`; text widgets must signal text-input focus; `capturesInput()`/`isInputCaptured()`; tooltip trailing `boolean`; `textWithWordWrap` returns `int`. GUI-drawing API otherwise unchanged (only the `RenderPipeline` package moved) |
| *26.4 preview* (band L, snapshot) | 26.4-snapshot-8 | `extract*` methods **lose `mouseX/mouseY/partialTick`** (read them from the extractor); `Updatable.update(DeltaTracker)`; `GuiPipeline` on every blit/fill; `addRenderableOnly` removed; `isHoveredOrFocused`→`isHighlighted`; container slots become **`SlotWidget`s** with `Slot.Section` (keyboard navigation + narration); `MENU_SCREEN` client registry. ★★★ jar, **subject to change** |

> **The distinction that matters for a multi-band mod:** the **1.21.6 break is behavioral** (you now
> *submit render state* instead of drawing immediately — **names unchanged**, `renderWidget` still
> exists through 1.21.11); the **26.1 break is nominal** (a mass rename on top of the same
> architecture). Two different porting problems: one needs restructuring, the other a shim.
> **26.3 is an input break, not a drawing break** — screens compile almost unchanged but key/mouse
> literals silently change meaning. **26.4 (preview) is a signature break again** — every
> `extract*` override changes shape, and container screens move to a widget-per-slot model.

---

## 1. Screen lifecycle

### 1.1 Version-keyed signature table

| Member | 1.20.1 | 1.20.2–1.20.4 | 1.20.5–1.21.1 | 1.21.2–1.21.6 | 1.21.9 | 1.21.11 | 26.1/26.2 | 26.3 | 26.4-s8 (preview) |
|---|---|---|---|---|---|---|---|---|---|
| ctor | `protected Screen(Component)` | = | = | = | = | `+ (Minecraft, Font, Component)` | = | = | = |
| top-level render | `render(GuiGraphics,int,int,float)` | = | = | = | = | = | **`extractRenderState(GuiGraphicsExtractor,int,int,float)`** | = | **`extractRenderState(GuiGraphicsExtractor)`** |
| per-frame logic | — | — | — | — | — | — | — | — | **`update(DeltaTracker)`** (`Updatable`), called right before extract |
| tooltip wrapper | `final renderWithTooltip(…)` | = | = | = | `final renderWithTooltipAndSubtitles(…)` | = | `final extractRenderStateWithTooltipAndSubtitles(…)` | = | `(GuiGraphicsExtractor)` |
| background | `renderBackground(GuiGraphics)` | **`renderBackground(GuiGraphics,int,int,float)`** | = | = | = | = | **`extractBackground(GuiGraphicsExtractor,int,int,float)`** | = | **`extractBackground(GuiGraphicsExtractor)`** |
| dirt/menu bg | `renderDirtBackground(GuiGraphics)` | = | **`renderMenuBackground(GuiGraphics)`** (+4-int) | = | = | = | `extractMenuBackground(…)` | = | = |
| blur | — | — | `protected renderBlurredBackground(float)` | 1.21.2: `()`; 1.21.6: `(GuiGraphics)` | `(GuiGraphics)` | `(GuiGraphics)` | `extractBlurredBackground(…)` | = | = |
| panorama | — | — | `renderPanorama(GuiGraphics,float)` + `static PanoramaRenderer PANORAMA` (field gone 1.21.6) | = | = | = | `extractPanorama(…)`; class → `Panorama` | = | `extractPanorama(GuiGraphicsExtractor)` |
| transparent bg | — | **`renderTransparentBackground(GuiGraphics)`** | = | = | = | = | `extractTransparentBackground(…)` | = | = |
| bg texture id | `BACKGROUND_LOCATION` = `textures/gui/options_background.png` | = | **`MENU_BACKGROUND`** = `textures/gui/menu_background.png` | = | = | `+ HEADER_SEPARATOR`, `FOOTER_SEPARATOR`, `INWORLD_*`; type is `Identifier` | = | `INWORLD_MENU_LIST_BACKGROUND` public on `AbstractSelectionList` | moved to `Screen`; in-world separators private → `Screen.extractListSeparators(…)` |
| init entry | `final init(Minecraft,int,int)` | = | = | = | = | **`final init(int,int)`** | `init(int,int)` | = | = (+ `isInitialized()`) |
| resize | `resize(Minecraft,int,int)` | = | = | = | = | **`resize(int,int)`** | `resize(int,int)` | = | = |
| `minecraft`/`font` | `protected` (mutable) | = | = | = | = | **`protected final`** | = | = | = |
| keyPressed | `(int,int,int)` | = | = | = | **`(KeyEvent)`** | = | = | = (`KeyEvent` ints are now SDL — §6.5) | = (`KeyEvent` gains `repeat`) |
| input capture | — | — | — | — | — | — | — | **`isInputCaptured()`** | = |
| narrator status | `updateNarratorStatus(boolean)` | = | = | = | = | = | = | **`updateNarratorStatus(boolean, NarrationTrigger)`**; `+ scheduleNarration()` | = |
| `setInitialFocus` | `protected (GuiEventListener)` | = | **+ no-arg `protected setInitialFocus()`** | = | = | = | = | = | = |
| `clearFocus` | private | private | private | private | private | **`public`** | public | public | public |
| `addRenderableOnly` | present | = | = | = | = | = | = | = | **removed** |
| fade | — | — | — | — | — | `protected fadeWidgets(float)`; `FADE_IN_TIME = 2000.0f` | = | = | = |
| misc | — | — | — | — | — | `isInGameUi()`, `canInterruptWithAnotherScreen()`, `panoramaShouldSpin()`, `isAllowedInPortal()`, `fillCrashDetails(CrashReport)` | = | `fillCrashDetails` **removed** | `+ static extractBackgroundScreen(g, Screen)` |

**Stable across the whole range:** `getTitle()`, `getNarrationMessage()`, `protected void init()`,
`protected void rebuildWidgets()`, `tick()`, `removed()`, `added()`, `isPauseScreen()`,
`shouldCloseOnEsc()`, `onClose()`, `repositionElements()`, `children()`, `removeWidget()`,
`clearWidgets()`, `isMouseOver()`, `onFilesDrop(List<Path>)`, `insertText(String,boolean)`,
`protected final Executor screenExecutor`, `getBackgroundMusic()`.

### 1.2 The three add-widget methods — identical 1.20.1 → 26.3

```java
protected <T extends GuiEventListener & Renderable & NarratableEntry> T addRenderableWidget(T widget);
protected <T extends Renderable>                                      T addRenderableOnly(T renderable); // removed 26.4-s8
protected <T extends GuiEventListener & NarratableEntry>              T addWidget(T widget);
```

| Method | rendered | interactable | **narrated** | use |
|---|---|---|---|---|
| `addRenderableWidget` | ✔ | ✔ | ✔ | almost always this |
| `addWidget` | ✘ | ✔ | ✔ | a widget you draw yourself in a custom order |
| `addRenderableOnly` | ✔ | ✘ | **✘** | decorations only — **never for content**. **Gone in 26.4-s8** ★★★ (subject to change) |

All three return their argument, so `Button b = addRenderableWidget(Button.builder(...).build());`.

> **26.4 preview:** with `addRenderableOnly` removed, pure decorations either become real widgets
> (non-interactive recipe in §6.2) or are drawn directly from your screen's `extractRenderState`.
> Writing decorations as non-interactive widgets now is forward-compatible on every band.

### 1.3 `init()` vs `rebuildWidgets()` vs `repositionElements()`

```java
public final void init(Minecraft mc, int width, int height) {   // 1.21.11+: init(int, int)
    this.minecraft = mc; this.width = width; this.height = height;
    if (!this.initialized) { this.init(); this.setInitialFocus(); }
    else                   { this.repositionElements(); }
    this.initialized = true;
    this.triggerImmediateNarration(false);
}
protected void rebuildWidgets() {
    this.clearWidgets(); this.clearFocus(); this.init(); this.setInitialFocus();
}
```

- `init()` runs **once**. On resize vanilla calls `repositionElements()` — whose default on plain
  `Screen` *is* `rebuildWidgets()`, but layout-based screens override it to just `arrangeElements()`,
  which is much cheaper and **preserves widget identity and focus**.
- Call `rebuildWidgets()` when your screen's **content** changed (tab switched, list reloaded).
  **Never call `init()` directly.**

### 1.4 Opening and closing

```java
Minecraft.getInstance().setScreen(new MyScreen(...));   // 1.20.1 – 1.21.11
Minecraft.getInstance().setScreen(null);                // close, resume game
Minecraft.getInstance().forceSetScreen(screen);         // loading path, all versions
```

- **26.2:** `setScreen(Screen)` is absent from the public surface; **`setScreenAndShow(Screen)`** is the
  caller-facing entry (`forceSetScreen` survives). ★★ — confirm against your own toolchain.
- **NeoForge patches `Screen#onClose()`** from `minecraft.setScreen(null)` to
  `minecraft.popGuiLayer()`. On NeoForge, `super.onClose()` pops a GUI *layer*.
- Fabric docs for 26.2 show `Minecraft.getInstance().gui.setScreen(...)`. ★★

### 1.5 `isPauseScreen()` / `shouldCloseOnEsc()`

`Screen` returns `true` for `isPauseScreen`; **`AbstractContainerScreen` overrides it to `false`**.
`isPauseScreen() == true` pauses a singleplayer world. **Return `false` for anything HUD-like or
in-world** (a live panel, a webcam overlay, a machine screen you want to keep running). 1.21.11 adds
`isInGameUi()` and `canInterruptWithAnotherScreen()` alongside it.

---

## 2. Widget hierarchy

### 2.1 The four interfaces

```java
public interface Renderable {                       // renamed from `Widget` in 1.19.3
    void render(GuiGraphics g, int mouseX, int mouseY, float partialTick);
    // 26.1–26.3: void extractRenderState(GuiGraphicsExtractor, int, int, float);
    // 26.4-s8:   void extractRenderState(GuiGraphicsExtractor);   // mouse/partialTick via g.mouseX()/mouseY()/partialTicks()
}
// 26.4-s8 (new): public interface Updatable { void update(DeltaTracker); }  // time/hover logic goes here
public interface NarrationSupplier { void updateNarration(NarrationElementOutput out); }
public interface NarratableEntry extends TabOrderedElement, NarrationSupplier {
    NarratableEntry.NarrationPriority narrationPriority();   // NONE < HOVERED < FOCUSED
    default boolean isActive();
}
public interface LayoutElement {
    void setX(int); void setY(int); int getX(); int getY(); int getWidth(); int getHeight();
    default ScreenRectangle getRectangle();
    default void setPosition(int x, int y);
    void visitWidgets(Consumer<AbstractWidget> consumer);
}
```

### 2.2 `AbstractWidget`

```java
public abstract class AbstractWidget
        implements Renderable, GuiEventListener, LayoutElement, NarratableEntry {
    protected int width, height;
    private   int x, y;
    private   Component message;              // 26.2: protected
    protected boolean isHovered;
    public    boolean active = true, visible = true;
    protected float   alpha  = 1.0f;
    public AbstractWidget(int x, int y, int width, int height, Component message);

    protected abstract void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick);
    protected abstract void updateWidgetNarration(NarrationElementOutput out);
}
```

| Change | Version |
|---|---|
| **`render` becomes final** — you must override `renderWidget` | **1.20.5** |
| `setTooltipDelay(int)` → `(java.time.Duration)` | **1.20.5** |
| tooltip fields → `private final WidgetTooltipHolder tooltip` | **1.20.5** |
| `WIDGETS_LOCATION` / `ACCESSIBILITY_TEXTURE` removed (sheet → sprite atlas via `WidgetSprites`) | **1.20.5** |
| `+ setHeight`, `getRight`, `getBottom`, `setSize(int,int)`, `setRectangle(int,int,int,int)` | **1.20.5** |
| `+ static renderScrollingString(GuiGraphics, Font, Component, …)` | **1.20.5** |
| **`AbstractButton#renderWidget` becomes final** → override `renderContents`, call `renderDefaultSprite`; `AbstractButton`/`AbstractSliderButton` extend `AbstractWidget$WithInactiveMessage` | **1.21.11** |
| `render`→`final extractRenderState`; `renderWidget`→`extractWidgetRenderState`; `onClick(MouseButtonEvent, boolean)`; `+ getAlpha()`, `static playButtonClickSound(SoundManager)`, `handleCursor(…)` | **26.1** |
| *No `AbstractWidget` change.* `GuiEventListener` gains `default boolean capturesInput()` (overridden `true` by `EditBox`, `MultiLineEditBox`, `RecipeBookComponent` while its search box is focused) | **26.3** |
| `final extractRenderState(g)`, `abstract extractWidgetRenderState(g)`, `extractTooltipForNextRenderPass(g)` — **mouse/partialTick params dropped**; `AbstractButton#extractContents(g)` likewise | **26.4-s8** ★★★ (subject to change) |
| `public boolean visible` → **`protected`**; use `isVisible()`/`setVisible(boolean)` (moved up from `EditBox`) | **26.4-s8** |
| **`isHoveredOrFocused()` → `isHighlighted()`** = `lastInput.isMouse() ? isHovered() : lastInput.isKeyboard() ? isFocused() : false`; `+ onStopHovering()`, `updateTooltipNarration(NarrationElementOutput)`, `areCoordinatesInRectangle(double,double)` | **26.4-s8** |

Stable through 26.3: `getMessage/setMessage`, `isHovered()`, `isHoveredOrFocused()` (→ `isHighlighted()`
in 26.4-s8), `isActive()`, `setAlpha`, `playDownSound(SoundManager)`, `visitWidgets`,
`getTabOrderGroup()/setTabOrderGroup(int)`, `wrapDefaultNarrationMessage`, `createNarrationMessage()`,
`defaultButtonNarrationText`, `nextFocusPath`, `getRectangle()`.

> **`isHighlighted()` is a semantic change, not a rename.** On ≤26.3 a widget that is focused *and*
> not hovered still draws highlighted. On 26.4-s8 the highlight follows the **last input type**
> (`InputType.KEYBOARD_SELECTION` is new; the cursor hides in keyboard mode and returns after the mouse
> moves `MouseHandler.MOUSE_INPUT_SWITCH_DISTANCE = 7.0` px). A custom widget that draws its own
> highlight should call `isHighlighted()` on 26.4 and `isHoveredOrFocused()` earlier — route it through
> the per-band adapter. Vanilla also draws a grey outline on hovered list entries. ★★★

```java
public abstract class AbstractButton extends AbstractWidget {
    protected static final int TEXT_MARGIN = 2;
    public abstract void onPress();
    @Override public void onClick(double mx, double my);              // -> onPress()
    @Override public boolean keyPressed(int key, int scan, int mods); // Space/Enter -> onPress()
}
```

### 2.3 Widget inventory by version

| Transition | Added | Removed |
|---|---|---|
| 1.20.1 → 1.20.5 | `AbstractContainerWidget`, `FocusableTextWidget`, `LoadingDotsWidget`, `PlayerSkinWidget`, `PopupScreen`, `SpriteIconButton`¹, `WidgetSprites`, `WidgetTooltipHolder` | `AccessibilityOnboardingTextWidget`, `TextAndImageButton`, `CommonButtons` |
| 1.20.5 → 1.21.1 | *(none)* | *(none)* |
| 1.21.1 → 1.21.4 | `AbstractScrollArea`, `AbstractTextAreaWidget` | `AbstractScrollWidget` |
| 1.21.4 → 1.21.9 | `ItemDisplayWidget`, `ScrollableLayout`² | — |
| 1.21.9 → 26.2 | `FriendsButton`, `IMEPreeditOverlay`, `PlayerFaceExtractor`, `PlayerFaceWidget`, `TextCursorUtils` | `PlayerFaceRenderer` |
| 26.2 → 26.3 | `RealmsButton` (sprites `widget/realms_button{,_disabled,_highlighted}`) | — |
| 26.3 → 26.4-s8 *(preview)* | `LoadingButton`, `ScaledWidgetSprites`, `AbstractCycleButton`, `SpriteIconCycleButton`, `SlotWidget`, `SlotGroup`, `CrafterSlotWidget`, `EnchantmentOptionButton`, `IconRadioButton`, `GroupNarration`, `Updatable`, `GuiPipeline` | `SpriteIconButton$CenteredIcon`/`$TextAndIcon` (class made concrete), `TextFieldHelper` |

¹ `SpriteIconButton` actually arrives in **1.20.2**; 1.20.5 only changed it to require
`Button$CreateNarration`. ² `ScrollableLayout` arrives in **1.21.6**.

---

## 3. Widget catalogue and metrics

### 3.1 Buttons

| Class | Constants / metrics | Constructors & builders |
|---|---|---|
| `Button` | `SMALL_WIDTH=120`, `DEFAULT_WIDTH=150`, `DEFAULT_HEIGHT=20`; **1.20.5+:** `BIG_WIDTH=200`, `DEFAULT_SPACING=8` | ctor is `protected`; `static Button.Builder builder(Component, Button.OnPress)` |
| `Button.Builder` | — | `pos(int,int)`, `width(int)`, `size(int,int)`, `bounds(int,int,int,int)`, `tooltip(Tooltip)`, `createNarration(…)`, `build()`. **26.4-s8:** generic `Button.Builder<B extends Builder<B>>` with protected fields and `+ tooltip(Component)`; `Button.builder(..)` returns `Builder<?>` |
| `LoadingButton` | **26.4-s8** — extends `Button`; owns the loading animation (sprite `widget/loading`, 5×6 strip, frames 5×2, frametime 6) | `setLoading(boolean[, Tooltip])`, `builder(..)` |
| `AbstractButton` | `TEXT_MARGIN=2`; sprites `widget/button`, `widget/button_disabled`, `widget/button_highlighted` | `(x, y, w, h, Component)` |
| `Checkbox` | **1.20.1:** `TEXT_COLOR=0xE0E0E0`. **1.20.2+:** the four `CHECKBOX_*_SPRITE` fields. **1.20.3+:** `SPACING=4`, `BOX_PADDING=8` | **1.20.1–1.20.2:** `public Checkbox(x,y,w,h,Component,boolean[,boolean showLabel])`. **1.20.3+:** ctor package-private; `static Checkbox.Builder builder(Component, Font)`; `static int getBoxSize(Font)`. **1.21+:** gains `maxWidth` |
| `Checkbox.Builder` | 1.20.3+ ★★ | `pos`, `onValueChange`, `selected(boolean)`, `selected(OptionInstance<Boolean>)`, `tooltip`, `maxWidth(int)` (1.21+), `build()` |
| `CycleButton<T>` | overrides `mouseScrolled` to cycle | `builder(Function<T,Component>)`, `booleanBuilder(on, off)`, `onOffBuilder()`, `onOffBuilder(boolean)`; **1.20.5+** `CycleButton.create(Component, OnValueChange)` at (0,0) size **150×20**. **26.4-s8:** `extends AbstractCycleButton<Value>`; `withValues`/`withTooltip` live on `AbstractCycleButton$Builder`; `OnValueChange`/`ValueListSupplier` move to `AbstractCycleButton$…`; new `SpriteIconCycleButton` (icon-only) |
| `ImageButton` | — | `(x,y,w,h,WidgetSprites,OnPress[,Component])`, `(x,y,WidgetSprites,OnPress,Component)` — pre-1.20.5 took raw u/v + `ResourceLocation` |
| `SpriteIconButton` | 1.20.2+; `sprite`, `spriteWidth`, `spriteHeight`; 26.2 adds int XY offsets. **26.4-s8:** concrete, `extends LoadingButton`, holds a `ScaledWidgetSprites` (`(WidgetSprites, w, h)` record) and a `DisplayState` (`ICON_ONLY`, `TEXT_ONLY`, `TEXT_AND_OFFSET_ICON`, `TEXT_AND_ICON`), `ICON_MARGIN = 2` | `static Builder builder(Component, OnPress, boolean iconOnly)`; `.width`, `.size`, `.sprite(rl,w,h)`, `.narration(...)`, `.build()`. **26.4-s8:** `+ builder(Component, OnPress, DisplayState)` (the `boolean` form remains), `setDisplayState` |
| `PlainTextButton` | underlines on hover | `(x,y,w,h,Component,OnPress,Font)`; **26.4-s8** adds a public 8-arg ctor with `CreateNarration` |
| `RealmsButton` | **26.3**; sprites `widget/realms_button` (200×20, nine-slice border 3), `_disabled` (border 1), `_highlighted` (border 3) | vanilla-specific |
| `LockIconButton` | fixed **20×20** | `(x,y,OnPress)`; `isLocked()/setLocked(boolean)` |
| `StateSwitchingButton` | raw-texture two-state toggle | `(x,y,w,h,boolean initialState)` + `initTextureValues(xTex,yTex,xDiff,yDiff,rl)` |
| `PageButton` | book page-turn arrows | lives in **`.screens.inventory`**, not `.components` |

> **`CycleButton` porting trap (band H).** At **1.21.11** the fluent `withInitialValue` setter was
> removed and the initial value became **positional**: `CycleButton.builder(formatter, initialValue)`.
> Worse, on **≤1.21.9** `withInitialValue` computes the starting *index* immediately by `indexOf`
> against the value list — which is still empty at that point, so the index stays 0 while the button
> *displays* the right value. Net effect: the button shows the saved value but its first click
> advances from item 0. Re-apply the initial value **after** `withValues(...)`: subclass
> `CycleButton.Builder` and override the non-final `withValues` overloads (`withValues(T...)` is final
> but delegates to the `Collection` overload). On 1.21.11+ use the positional builder.

### 3.2 Text and input

| Class | Constants | Constructors |
|---|---|---|
| `EditBox` | `DEFAULT_TEXT_COLOR=0xE0E0E0`, `CURSOR_INSERT_WIDTH=1`, `CURSOR_INSERT_COLOR=0xFFD0D0D0`, `CURSOR_APPEND_CHARACTER="_"`, `CURSOR_BLINK_INTERVAL_MS=300` | `(Font,x,y,w,h,Component)`, `(Font,w,h,Component)`, `(Font,x,y,w,h,EditBox prior,Component)`. API: `setResponder`, `setFilter`, `setFormatter`, `setMaxLength`, `setHint`, `setSuggestion`, `setBordered`, `setEditable`, `setCanLoseFocus`, `getInnerWidth()` |
| `MultiLineEditBox` | `TEXT_COLOR=-2039584`, `PLACEHOLDER_TEXT_COLOR=-857677600`, `CURSOR_BLINK_INTERVAL_MS=300` | `(Font,x,y,w,h,Component placeholder,Component message)`; `setCharacterLimit`, `setValueListener` |
| `StringWidget` | — | `(Component,Font)`, `(w,h,Component,Font)`, `(x,y,w,h,Component,Font)`; fluent `setColor`, `alignLeft/Center/Right` |
| `MultiLineTextWidget` | — | `(Component,Font)`, `(x,y,Component,Font)`; `setMaxWidth`, `setMaxRows`, `setCentered`, `setColor` |
| `FocusableTextWidget` | `DEFAULT_PADDING=4` | 1.20.5+; `(w,Component,Font[,padding][,alwaysShowBorder,padding])`; `containWithin(int)` |
| `ImageWidget` | — | abstract; `ImageWidget.texture(w,h,rl,texW,texH)`, `ImageWidget.sprite(w,h,rl)` |
| `LogoRenderer` | `LOGO_WIDTH=256`, `LOGO_HEIGHT=44`, `LOGO_TEXTURE_WIDTH=256`, `LOGO_TEXTURE_HEIGHT=64`, `EDITION_WIDTH=128`, `EDITION_HEIGHT=14`, `DEFAULT_HEIGHT_OFFSET=30`, `EDITION_LOGO_OVERLAP=7` | **not a widget** — a helper you call from `render` |
| `PlayerSkinWidget` | `DEFAULT_ROTATION_X=-5f`, `DEFAULT_ROTATION_Y=30f`, `ROTATION_X_LIMIT=50f`, `MODEL_HEIGHT=2.125f`, `Z_OFFSET=100f` | 1.20.5+; `(w,h,EntityModelSet,Supplier<PlayerSkin>)` |

> **`EditBox#tick()` was removed in 1.20.2.** Cursor blink became time-based. Porting off 1.20.1 means
> deleting your `editBox.tick()` call from `Screen#tick`.

**`EditBox` on 26.3 / 26.4-s8.**
- **26.3:** the only change is `capturesInput()` → `true` (also on `MultiLineEditBox`). Vanilla
  `EditBox` already signals SDL text-input focus, so a *subclass* works unchanged; a hand-rolled text
  widget does not — see §6.5. ★★★
- **26.4-s8:** `isVisible`/`setVisible` move up to `AbstractWidget`; `+ setMaxWidth(int)`,
  `setCanChangeValue(boolean)`, `nextFocusPath(FocusNavigationEvent)`. Behaviour (s7 patch notes):
  **Tab** focuses *and* makes it editable; **arrow** navigation only highlights it; Enter/Space then
  enters edit mode. ★★★ (subject to change)
- `TextFieldHelper` (used by the old sign/book editors) is removed in 26.4-s8; sign screens gain a
  `$SignLineEditBox` widget. ★★★

### 3.3 Sliders

```java
public abstract class AbstractSliderButton extends AbstractWidget {
    protected static final int TEXT_MARGIN = 2;
    private   static final int HANDLE_WIDTH = 8, HANDLE_HALF_WIDTH = 4;
    protected double value;                        // normalised 0.0 – 1.0
    // sprites: widget/slider, widget/slider_highlighted, widget/slider_handle, widget/slider_handle_highlighted
    public AbstractSliderButton(int x, int y, int w, int h, Component msg, double value);
    protected abstract void updateMessage();
    protected abstract void applyValue();
}
```

- **Volume sliders are not a distinct class** — they're `OptionInstance$OptionInstanceSliderButton`
  from `Options#getSoundSourceOptionInstance(SoundSource)`; the widget comes from
  `OptionInstance#createButton(Options)` (**1.20.5+**, 150×20 at (0,0)).
- **`ForwardingSlider` is not vanilla.** NeoForge: `ExtendedSlider extends AbstractSliderButton`
  — `(x,y,w,h,Component prefix,Component suffix,double min,double max,double current,double step,int precision,boolean drawString)`
  plus a 10-arg overload; `getValue()/getValueLong()/getValueInt()/getValueString()`, `setValue(double)`.
  Forge 1.20.1: `ForgeSlider`, same shape.

### 3.4 Lists

```java
public abstract class AbstractSelectionList<E extends AbstractSelectionList.Entry<E>>
        extends AbstractContainerWidget {                    // 1.20.5+
    protected static final int SCROLLBAR_WIDTH = 6;          // 1.20.5+
    protected final int itemHeight;

    // 1.20.1:  (Minecraft, int width, int height, int y0, int y1, int itemHeight)   // 6 args
    // 1.20.5+: (Minecraft, int width, int height, int y,  int itemHeight)           // 5 args

    public    int  getRowWidth();            // default 220 in vanilla subclasses — OVERRIDE THIS
    public    int  getRowLeft(); getRowRight();
    protected int  getRowTop(int index); getRowBottom(int index);
    protected int  addEntry(E); clearEntries(); replaceEntries(Collection<E>);
    public    void setSelected(E); public E getSelected();
    protected void ensureVisible(E); centerScrollOn(E);
    public    double getScrollAmount(); void setScrollAmount(double); int getMaxScroll();
    protected int  getScrollbarPosition(); getDefaultScrollbarPosition();   // 1.20.5+
    public    void updateSize(int width, HeaderAndFooterLayout layout);     // 1.20.5+
    public    void updateSizeAndPosition(int width, int height, int y);     // 1.20.5+

    public abstract static class Entry<E extends Entry<E>> implements GuiEventListener {
        public abstract void render(GuiGraphics g, int index, int top, int left, int width, int height,
                                    int mouseX, int mouseY, boolean hovering, float partialTick);
        public void renderBack(GuiGraphics g, int index, int top, int left, int width, int height,
                               int mouseX, int mouseY, boolean hovering, float partialTick);
    }
}
```

**1.20.5 list changes:** `renderList` → `renderListItems`; `setRenderBackground` removed; added
`updateSize`, `updateSizeAndPosition`, `getDefaultScrollbarPosition`, `getListOutlinePadding`,
`getRealRowLeft/Right`; `getMouseOver` returns `Optional<GuiEventListener>`.
**1.21.9** reworked it further: `itemHeight`→`defaultEntryHeight`, no header height,
`render`/`renderBack`→`renderContent`, `$Entry implements LayoutElement`.
**26.4-s8** (★★★, subject to change): `AbstractSelectionList implements Updatable`;
`extractListItems(g)`, `extractItem(g, E)`; **`$Entry#extractContent(g, int mouseX, int mouseY, boolean hovered, float a)`
→ `extractContent(g, boolean hovered)`**; `AbstractScrollArea#extractScrollbar(g)`. Vanilla now
ignores non-left clicks for list selection (`MouseButtonEvent.isLeftMouse()`), and hovered entries
get a grey outline.

| Subclass | Entry contract |
|---|---|
| `ObjectSelectionList<E>` | `Entry implements NarrationSupplier`; must implement `public abstract Component getNarration()`. **1.20.5:** `Entry#mouseClicked` returns `true` by default |
| `ContainerObjectSelectionList<E>` | `Entry implements ContainerEventHandler`; must implement **`narratables()` and `children()`**. **Use this whenever list rows contain focusable widgets** — you get focus traversal and narration for free |
| `OptionsList extends ContainerObjectSelectionList` | `BIG_BUTTON_WIDTH=310`, `DEFAULT_ITEM_HEIGHT=25`; **1.20.5+** ctor `(Minecraft, int width, OptionsSubScreen)`; `addBig(OptionInstance)`, `addSmall(OptionInstance...)`, `addSmall(AbstractWidget, AbstractWidget)`, `findOption`, `applyUnsavedChanges()`. `getRowWidth()` → **310** |

### 3.5 Tabs — `net.minecraft.client.gui.components.tabs`, all **1.19.4**

```java
public interface Tab {
    Component getTabTitle();
    void visitChildren(Consumer<AbstractWidget> consumer);
    void doLayout(ScreenRectangle area);
}
public class GridLayoutTab implements Tab { protected final GridLayout layout; public GridLayoutTab(Component); }
public class TabManager {
    public TabManager(Consumer<AbstractWidget> addWidget, Consumer<AbstractWidget> removeWidget);
    public void setTabArea(ScreenRectangle);
    public void setCurrentTab(Tab tab, boolean playSound);
    public Tab  getCurrentTab();
}
public class TabNavigationBar extends AbstractContainerEventHandler
        implements Renderable, NarratableEntry {
    private static final int NO_TAB = -1, MAX_WIDTH = 400, HEIGHT = 24, MARGIN = 14;
    public static Builder builder(TabManager tabManager, int width);   // .addTabs(Tab...).build()
    public void setWidth(int); public void arrangeElements();
    public void selectTab(int index, boolean playSound);
    public boolean keyPressed(int keyCode);   // Ctrl+Tab / Ctrl+Shift+Tab
}
```

| Tabs change | Version |
|---|---|
| `TabNavigationBar` declared as plain `extends AbstractContainerWidget` (the `NarratableEntry`/`Renderable` interfaces are inherited, not re-declared) — source-compatible | 26.3 |
| **`Tab.getTabTitle()` removed**; `TabButton` / `MenuTabBar$MenuTabButton` ctors gain a `Component` title; `GridLayoutTab()` and `LoadingTab(Font, Component)` lose the title arg; `MenuTabBar$Builder.addTab(Component, Tab)` | **26.4-s8** ★★★ (subject to change) |

**`ScrollableLayout`** — **1.21.6**, and it lives in `.components`, *not* `.layouts`:

```java
public class ScrollableLayout implements Layout {
    private static final int SCROLLBAR_SPACING = 4, SCROLLBAR_RESERVE = 10;
    public ScrollableLayout(Minecraft mc, Layout content, int maxHeight);
    public void setMinWidth(int); public void setMaxHeight(int);
}
// 26.2 adds ScrollableLayout$ReserveStrategy
// 26.3 adds getScrollAmount()
// 26.4-s8: ctor → (Minecraft, Layout, int, AbstractScrollArea$ScrollbarSettings, int, ReserveStrategy, GroupNarration);
//          + alignVertically(float)/Top/Middle/Bottom, setScrollAmount, setTabGroup(int), allowTabNavigationInside(boolean)
```

**`SwitchGrid`** exists since 1.19.4 but is **package-private in `…screens.worldselection`** — it is
world-creation UI, not a public widget API.

---

## 4. The layout system

### 4.1 Package inventory

| Class | 1.19.3 | 1.19.4 | 1.20.1 | 1.20.2+ | 1.21.6+ |
|---|---|---|---|---|---|
| `GridLayout`, `LinearLayout`, `FrameLayout`, `LayoutSettings`, `SpacerElement`, `AbstractLayout` | ✔ (as `.components.*Widget`) | moved+renamed into `.layouts` | ✔ | ✔ | ✔ |
| `Layout`, `LayoutElement`, `HeaderAndFooterLayout` | ✘ | **new** | ✔ | ✔ | ✔ |
| `EqualSpacingLayout`, `CommonLayouts` | ✘ | ✘ | ✘ | **1.20.2** | ✔ |

> **Signatures were stable 1.20.1 → 26.3**, and 26.4-s8 only *adds* to them
> (`HeaderAndFooterLayout`: private `CONTENT_MARGIN_TOP` → `public DEFAULT_CONTENT_MARGIN_TOP = 30` +
> `setContentMarginTop(int)`; `ScreenRectangle.expandInAllDirections(int)`;
> `AbstractContainerWidget.allowTabNavigationInside(boolean)`). Layout code is by far the most
> portable part of the GUI API — even 26.1's `extract*` rename does not touch it. **Prefer layouts
> over manual coordinates on every band**, including 1.20.1.

### 4.2 Signatures

```java
public interface Layout extends LayoutElement {
    void visitChildren(Consumer<LayoutElement> visitor);
    default void visitWidgets(Consumer<AbstractWidget> visitor);   // recurses to leaf AbstractWidgets
    default void arrangeElements();                                 // one-shot; no reflow on change
}

public interface LayoutSettings {
    LayoutSettings padding(int all); padding(int h, int v); padding(int l, int t, int r, int b);
    LayoutSettings paddingLeft/Top/Right/Bottom(int); paddingHorizontal/Vertical(int);
    LayoutSettings align(float x, float y);        // 0.0 start · 0.5 center · 1.0 end
    LayoutSettings alignHorizontally(float); alignVertically(float);
    default LayoutSettings alignHorizontallyLeft/Center/Right();
    default LayoutSettings alignVerticallyTop/Middle/Bottom();
    LayoutSettings copy();  static LayoutSettings defaults();
}

public class GridLayout extends AbstractLayout {
    public GridLayout();  public GridLayout(int x, int y);
    public <T extends LayoutElement> T addChild(T child, int row, int col
        [, int rowSpan, int colSpan][, LayoutSettings | Consumer<LayoutSettings>]);
    public GridLayout columnSpacing(int); rowSpacing(int); spacing(int);
    public LayoutSettings newCellSettings();      // fresh, independent
    public LayoutSettings defaultCellSetting();   // mutates the grid default for later children
    public GridLayout.RowHelper createRowHelper(int columns);

    public static final class RowHelper {         // auto-advancing cursor over a fixed column count
        public <T extends LayoutElement> T addChild(T[, int occupiedColumns][, LayoutSettings]);
        public GridLayout getGrid();
    }
}

public class LinearLayout implements Layout {     // thin wrapper over a 1×N / N×1 GridLayout
    public static LinearLayout vertical();  public static LinearLayout horizontal();
    public LinearLayout spacing(int);
    public <T extends LayoutElement> T addChild(T[, LayoutSettings | Consumer<LayoutSettings>]);
}

public class FrameLayout extends AbstractLayout { // z-stack / centering frame
    public FrameLayout setMinDimensions(int w, int h); setMinWidth(int); setMinHeight(int);
    public static void centerInRectangle(LayoutElement e, int x, int y, int w, int h);
    public static void centerInRectangle(LayoutElement e, ScreenRectangle r);
    public static void alignInRectangle(LayoutElement e, ScreenRectangle r, float alignX, float alignY);
    public static void alignInDimension(int start, int size, int elemSize, Consumer<Integer> setter, float align);
}

public class HeaderAndFooterLayout implements Layout {
    public static final int DEFAULT_HEADER_AND_FOOTER_HEIGHT = 33;
    private static final int CONTENT_MARGIN_TOP = 30;
    public HeaderAndFooterLayout(Screen[, int headerAndFooterHeight | int headerH, int footerH]);
    public <T extends LayoutElement> T addToHeader/addToContents/addToFooter(T[, Consumer<LayoutSettings>]);
    public void addTitleHeader(Component title, Font font);   // 1.20.5+
    public int  getContentHeight();                           // 1.20.5+
    public int  getHeaderHeight(); setHeaderHeight(int); getFooterHeight(); setFooterHeight(int);
}

public class SpacerElement implements LayoutElement {
    public SpacerElement(int w, int h);  public SpacerElement(int x, int y, int w, int h);
    public static SpacerElement width(int);  public static SpacerElement height(int);
}
```

### 4.3 The canonical `init()` — works unchanged 1.20.1 → 1.21.11 (and 26.x with the `extract*`/`Identifier` renames; the layout calls themselves never change)

This four-step shape is exactly what vanilla's own `OptionsSubScreen#init` does.

```java
public class MyScreen extends Screen {
    private final Screen lastScreen;
    private final HeaderAndFooterLayout layout = new HeaderAndFooterLayout(this);

    public MyScreen(Screen lastScreen) {
        super(Component.translatable("screen.examplemod.my"));
        this.lastScreen = lastScreen;
    }

    @Override
    protected void init() {
        // 1) header
        this.layout.addTitleHeader(this.title, this.font);        // 1.20.5+
        // pre-1.20.5: this.layout.addToHeader(new StringWidget(this.title, this.font));

        // 2) contents
        LinearLayout contents = this.layout.addToContents(LinearLayout.vertical().spacing(8));
        contents.addChild(new StringWidget(Component.literal("Hello"), this.font),
                          s -> s.alignHorizontallyCenter());
        contents.addChild(Button.builder(CommonComponents.GUI_PROCEED, b -> doThing())
                                .width(Button.DEFAULT_WIDTH)       // 150
                                .tooltip(Tooltip.create(Component.translatable("…tip")))
                                .build());
        contents.addChild(SpacerElement.height(4));

        // 3) footer — two buttons side by side
        LinearLayout footer = this.layout.addToFooter(LinearLayout.horizontal().spacing(8));
        footer.addChild(Button.builder(CommonComponents.GUI_DONE,   b -> this.onClose()).width(200).build());
        footer.addChild(Button.builder(CommonComponents.GUI_CANCEL, b -> this.onClose()).width(200).build());

        // 4) register every widget the layout owns, then place them
        this.layout.visitWidgets(this::addRenderableWidget);
        this.repositionElements();
    }

    @Override
    protected void repositionElements() {   // called on resize instead of init()
        this.layout.arrangeElements();      // cheap; preserves widget identity + focus
    }

    @Override public void onClose() { this.minecraft.setScreen(this.lastScreen); }
}
```

### 4.4 Manual positioning (if you must)

Layouts exist in 1.20.1, so this is a stylistic choice, not a necessity.

```java
@Override
protected void init() {
    final int cx = this.width / 2;
    final int BTN_W = 200, BTN_H = 20, GAP = 4, STRIDE = BTN_H + GAP;   // 24px stride
    int y = this.height / 4 + 48;                                       // vanilla's first-row anchor

    this.addRenderableWidget(Button.builder(Component.translatable("…proceed"), b -> doThing())
        .bounds(cx - BTN_W / 2, y, BTN_W, BTN_H).build());
    y += STRIDE;

    // two-column row: 150-wide buttons with an 8px gutter (Button.DEFAULT_SPACING)
    this.addRenderableWidget(Button.builder(Component.literal("A"), b -> {})
        .bounds(cx - 154, y, 150, 20).build());
    this.addRenderableWidget(Button.builder(Component.literal("B"), b -> {})
        .bounds(cx + 4,   y, 150, 20).build());
}
```
Because `init()` re-runs on resize, the manual version needs no reposition code — at the cost of
destroying and rebuilding every widget (and **losing focus**) on every resize.

---

## 5. Container screens

### 5.1 `AbstractContainerMenu`

```java
public abstract class AbstractContainerMenu {
    public static final int SLOT_CLICKED_OUTSIDE = -999;
    public static final int QUICKCRAFT_TYPE_CHARITABLE = 0, QUICKCRAFT_TYPE_GREEDY = 1, QUICKCRAFT_TYPE_CLONE = 2;
    public final NonNullList<Slot> slots;
    public final int containerId;

    protected Slot     addSlot(Slot slot);
    protected DataSlot addDataSlot(DataSlot slot);
    protected void     addDataSlots(ContainerData data);
    protected boolean  moveItemStackTo(ItemStack stack, int start, int end, boolean reverse);
    protected static boolean stillValid(ContainerLevelAccess access, Player player, Block block);
    protected static void    checkContainerSize(Container c, int minSize);
    protected static void    checkContainerDataCount(ContainerData d, int minCount);
    public void broadcastChanges(); public void broadcastFullState();
    public ItemStack getCarried(); public void setCarried(ItemStack);

    public abstract ItemStack quickMoveStack(Player player, int index);
    public abstract boolean   stillValid(Player player);

    // ---- 1.21.2+ ONLY ----
    protected void addInventoryHotbarSlots(Container inv, int x, int y);
    protected void addInventoryExtendedSlots(Container inv, int x, int y);
    protected void addStandardInventorySlots(Container inv, int x, int y);
}
```

### 5.2 The canonical player inventory

```java
// 3 rows x 9 cols of main inventory   (inventory indices 9..35)
for (int row = 0; row < 3; ++row)
    for (int col = 0; col < 9; ++col)
        this.addSlot(new Slot(playerInventory, col + row * 9 + 9, 8 + col * 18, 84 + row * 18));

// hotbar                              (inventory indices 0..8)
for (int col = 0; col < 9; ++col)
    this.addSlot(new Slot(playerInventory, col, 8 + col * 18, 142));
```

| Fact | Value |
|---|---|
| Slot pitch | **18** |
| Main-inventory origin | **(8, 84)** → rows at y = 84, 102, 120 |
| Hotbar y | **142** (= 84 + 58) |
| Slot texture cell | 18×18 (16×16 item + 1px border) |
| Furnace reference offsets (1.21.1) | input **(56, 17)**, fuel **(56, 53)**, result **(116, 35)** |

`addStandardInventorySlots(inv, x, y)` is literally
`addInventoryExtendedSlots(inv, x, y); addInventoryHotbarSlots(inv, x, y + 58);` — so
`addStandardInventorySlots(playerInventory, 8, 84)` reproduces the block above exactly.
**1.21.2+ only**; on 1.20.1–1.21.1 write the loops.

### 5.3 `Slot`, `MenuType`, `MenuProvider`, data sync

```java
public class Slot {
    public final Container container; public int index; public final int x, y;
    public Slot(Container container, int slotIndex, int x, int y);              // ≤26.3
    public Slot(Container container, int slotIndex, int x, int y, Slot.Section); // 26.4-s8 — see §5.6.1
    public boolean mayPlace(ItemStack); public boolean mayPickup(Player);
    public int  getMaxStackSize(); public int getMaxStackSize(ItemStack);
    public void setByPlayer(ItemStack); public void set(ItemStack); public void setChanged();
    public void onTake(Player, ItemStack); public void onQuickCraft(ItemStack, ItemStack);
    public boolean isActive(); isHighlightable(); isFake();
    public Pair<ResourceLocation, ResourceLocation> getNoItemIcon();   // empty-slot ghost sprite
}
public interface ContainerData { int get(int i); void set(int i, int v); int getCount(); }
public abstract class DataSlot {
    public static DataSlot forContainer(ContainerData d, int i);
    public static DataSlot shared(int[] arr, int i);
    public static DataSlot standalone();
}
```

> `DataSlot` values travel as **shorts** (−32768..32767) on the wire in vanilla; **NeoForge patches
> this to full ints.** For >1 int use `new SimpleContainerData(n)` + `addDataSlots(data)`, and
> `checkContainerDataCount(data, n)` in the server ctor.

`MenuType`'s constructor is **private in vanilla** — hence the loader-specific creation paths in §5.7.

### 5.4 `AbstractContainerScreen<T>`

```java
public abstract class AbstractContainerScreen<T extends AbstractContainerMenu>
        extends Screen implements MenuAccess<T> {
    public  static final ResourceLocation INVENTORY_LOCATION = "textures/gui/container/inventory.png";
    public  static final int SLOT_ITEM_BLIT_OFFSET  = 100;
    private static final int HOVER_ITEM_BLIT_OFFSET = 200;
    private static final float SNAPBACK_SPEED = 100.0f;
    private static final int   QUICKDROP_DELAY = 500;
    protected int imageWidth, imageHeight;              // 176, 166
    protected int titleLabelX, titleLabelY;             // 8, 6
    protected int inventoryLabelX, inventoryLabelY;     // 8, imageHeight - 94  (= 72 at 166)
    protected int leftPos, topPos;                      // set in init()
    protected final T menu;
    protected Slot hoveredSlot;

    protected void init();      // leftPos = (width - imageWidth)/2;  topPos = (height - imageHeight)/2;
    protected abstract void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY);
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY);
    protected void renderTooltip(GuiGraphics g, int mouseX, int mouseY);
    protected void containerTick();                     // tick() is FINAL and delegates here
    protected void slotClicked(Slot slot, int slotId, int button, ClickType type);
    protected boolean hasClickedOutside(double mx, double my, int left, int top, int button);
    protected boolean isHovering(int x, int y, int w, int h, double mx, double my);
    public boolean isPauseScreen();                     // false
}
```

Defaults are set **in the constructor**. From 26.1 they're named constants: `DEFAULT_IMAGE_WIDTH=176`,
`DEFAULT_IMAGE_HEIGHT=166`, `BACKGROUND_TEXTURE_WIDTH=256`, `BACKGROUND_TEXTURE_HEIGHT=256` — the
canonical "176×166 GUI drawn from a 256×256 PNG" is explicit in the source.

```java
public class MyScreen extends AbstractContainerScreen<MyMenu> {
    private static final ResourceLocation TEXTURE =
        ResourceLocation.fromNamespaceAndPath("examplemod", "textures/gui/container/my.png"); // 1.21+

    public MyScreen(MyMenu menu, Inventory inv, Component title) {
        super(menu, inv, title);
        this.imageWidth = 176; this.imageHeight = 166;
        this.inventoryLabelY = this.imageHeight - 94;   // MUST recompute if you changed imageHeight
    }

    @Override public void render(GuiGraphics g, int mx, int my, float pt) {
        this.renderBackground(g, mx, my, pt);     // 1.20.1: renderBackground(g)
        super.render(g, mx, my, pt);
        this.renderTooltip(g, mx, my);            // MUST be after super.render
    }

    @Override protected void renderBg(GuiGraphics g, float pt, int mx, int my) {
        g.blit(TEXTURE, leftPos, topPos, 0, 0, imageWidth, imageHeight);                     // ≤1.21.1
        // 1.21.2–1.21.4: g.blit(RenderType::guiTextured, TEXTURE, …, 256, 256);
        // 1.21.6+:       g.blit(RenderPipelines.GUI_TEXTURED, TEXTURE, …, 256, 256);
    }
}
```

### 5.5 Canonical `quickMoveStack`

Layout assumed: data slot 0 = result, 1–4 = inputs, player inventory 5–31, hotbar 32–40.

```java
@Override
public ItemStack quickMoveStack(Player player, int index) {
    ItemStack result = ItemStack.EMPTY;
    Slot slot = this.slots.get(index);
    if (slot != null && slot.hasItem()) {
        ItemStack raw = slot.getItem();
        result = raw.copy();
        if (index == 0) {                                       // out of the result slot
            if (!this.moveItemStackTo(raw, 5, 41, true)) return ItemStack.EMPTY;
            slot.onQuickCraft(raw, result);
        } else if (index >= 5 && index < 41) {                  // out of the player inventory
            if (!this.moveItemStackTo(raw, 1, 5, false)) {
                if (index < 32) { if (!this.moveItemStackTo(raw, 32, 41, false)) return ItemStack.EMPTY; }
                else            { if (!this.moveItemStackTo(raw,  5, 32, false)) return ItemStack.EMPTY; }
            }
        } else if (!this.moveItemStackTo(raw, 5, 41, false)) {   // out of a data slot
            return ItemStack.EMPTY;
        }
        if (raw.isEmpty()) slot.setByPlayer(ItemStack.EMPTY); else slot.setChanged();
        slot.onTake(player, raw);
    }
    return result;
}
```

> **Returning `ItemStack.EMPTY` when nothing moved is what terminates the client's shift-click loop.**
> Omit it and you get an infinite loop / client hang.

### 5.6 The 26.x container-screen rewrite

| Pre-26 | 26.1 / 26.2 |
|---|---|
| `render(GuiGraphics,int,int,float)` | `extractRenderState(GuiGraphicsExtractor,int,int,float)` |
| `protected abstract renderBg(GuiGraphics,float,int,int)` | **gone — override `extractBackground(GuiGraphicsExtractor,int,int,float)` inherited from `Screen`** |
| `renderLabels(…)` | `extractLabels(…)` |
| `renderTooltip(…)` | `extractTooltip(…)` |
| — | `+ extractContents`, `extractSlots`, `extractSlot`, `extractCarriedItem`, `extractFloatingItem` |
| `protected int imageWidth/imageHeight` | **`protected final`** — use `AbstractContainerScreen(T, Inventory, Component, int imageWidth, int imageHeight)` |
| `slotClicked(Slot,int,int,ClickType)` | `slotClicked(Slot,int,int,ContainerInput)` |
| `hasClickedOutside(double,double,int,int,int)` | `hasClickedOutside(double,double,int,int)` |
| `checkHotbarKeyPressed(int,int)` | `checkHotbarKeyPressed(KeyEvent)` |
| snapback/quickdrop fields | removed |
| — | `+ addItemSlotMouseAction(ItemSlotMouseAction)`, `onMouseClickAction(Slot, ContainerInput)` |

**26.3** changes nothing here except input: `AbstractContainerScreen.keyPressed` checks
`isInputCaptured()` before treating the inventory key as "close", so a container screen with a
search box must make that box report `capturesInput()` (§6.5). `AbstractRecipeBookScreen`,
`AbstractSignEditScreen` and `CreativeModeInventoryScreen` override `isInputCaptured()`. ★★★

### 5.6.1 26.4 preview — `SlotWidget` and `Slot.Section` (26.4-snapshot-8, ★★★ jar, subject to change)

Every slot becomes a focusable, narrated **`SlotWidget`** (`extends AbstractWidget`, `WIDTH = HEIGHT = 18`,
`BORDER = 1`, `QUICK_CRAFT_TINT_COLOR = 0x80FFFFFF`). Slots are grouped by **`Slot.Section`** into
`SlotGroup`s (`extends AbstractContainerWidget`) with a fixed tab order. This is what gives vanilla
container screens keyboard navigation and slot narration in 26.4-snapshot-7+.

| 26.3 | 26.4-s8 |
|---|---|
| `Slot(Container, int, int, int)` | **`Slot(Container, int, int, int, Slot.Section)`**; `+ getSection()`, `Component getNarrationName()` (nullable → falls back to the `SlotGroup` name, then contents) |
| — | `Slot.Section` = `EQUIPMENT, CONTAINER, INPUT, SECOND_INPUT, FUEL, RESULT, INVENTORY, HOTBAR` |
| `protected Slot hoveredSlot` | **`getHoveredSlot()` → `SlotWidget`** |
| `Set<Slot> quickCraftSlots` | `Set<SlotWidget> quickCraftSlots` |
| `extractSlots(g,int,int)`, `extractLabels(g,int,int)` | `extractSlots(g)`, `extractLabels(g)`, `extractCarriedItem(g)` |
| `extractSlot(g, Slot, int, int)`, `extractTooltip(g,int,int)`, `getTooltipFromContainerItem(ItemStack)`, `addItemSlotMouseAction(…)` | **removed** |
| `slotClicked(Slot, int, int, ContainerInput)` | **`slotClicked(SlotWidget, int, int, ContainerInput)`** |
| `hasClickedOutside(double,double,int,int)` | `hasClickedOutside(double,double)` |
| — | `updateSlotWidgets()` (override/call when the visible slot set changes — tabs, recipe book), `setSlotWidgets(List<SlotWidget>)`, `getTabOrderGroup(Slot.Section)`, `updateScreenPositions()`, `updateLastQuickMoved(Slot)`, `keyReleased(KeyEvent)` |
| — | tab-group constants `EQUIPMENT 1, CONTAINER 2, BEFORE_INPUT 3, INPUT 4, SECOND_INPUT 5, FUEL 6, BETWEEN_INPUT_OUTPUT 7, RESULT 8, INVENTORY 9, HOTBAR 10` (`*_TAB_GROUP`) |
| — | keyboard tuning: `DOUBLE_KEY_PRESS_THRESHOLD_MS = 250`, `KEYBOARD_CARRIED_ITEM_OFFSET = 2`, `KEYBOARD_CARRIED_ITEM_SMOOTHING_MS = 50f` |
| `RecipeBookComponent.slotClicked(Slot)` | `SlotWidget`; `RecipeBookComponent` is `Updatable`, `+ isActive()` |

Vanilla keyboard contract to match (s7 notes ★★★): Tab between slot groups, arrows within a group,
Enter/Space = left-click, Ctrl+ = right-click, Shift+ = shift-click, double press within 250 ms =
collect, arrow while holding = spread; hotbar/drop keys act on the focused slot. Stonecutter, loom,
enchanting and merchant moved from custom `mouseClicked/Scrolled/Dragged` to real widgets
(`IconRadioButton`, `EnchantmentOptionButton`, `MerchantScreen$TradeOfferButton(screen, MerchantOffer, OnPress)`)
plus `repositionElements()`; stonecutter `RECIPES_START_Y` 14 → **15**.

> **Design consequence.** A custom container screen inherits navigation + narration **only if** its
> slots are real `Slot`s carrying a meaningful `Section`, and every other control is a real focusable
> `AbstractWidget`. Hand-drawn "slots" and click-region hit-testing are invisible to the keyboard and
> the narrator. Per the draft NeoForge primer (★★), a screen that doesn't change its slot set needs
> no further changes. Fabric API `0.165.4+26.4` already fixed its own slot click/drag handling for
> slot groups (★★★).

### 5.7 Per-loader screen registration

`MenuScreens.register` is **`private static` in vanilla at every version 1.20.1 → 26.3**:

```java
private static <M extends AbstractContainerMenu, U extends Screen & MenuAccess<M>>
    void register(MenuType<? extends M> type, MenuScreens.ScreenConstructor<M, U> ctor);
// ScreenConstructor<M,U> = U create(M menu, Inventory inv, Component title)  → MyScreen::new matches
```

| Loader | MC | How |
|---|---|---|
| **Forge** | 1.20.1 | `MenuScreens.register(...)` inside `event.enqueueWork(...)` in `FMLClientSetupEvent` — **not thread-safe otherwise** |
| **NeoForge** | 1.20.2+ | `RegisterMenuScreensEvent` on the **mod** bus |
| **Fabric** | all | call `MenuScreens.register(...)` directly in `ClientModInitializer#onInitializeClient` |

```java
// Forge 1.20.1
@SubscribeEvent  // MOD bus
public static void clientSetup(FMLClientSetupEvent event) {
    event.enqueueWork(() -> MenuScreens.register(MY_MENU.get(), MyScreen::new));
}
// NeoForge 1.20.2+
@SubscribeEvent  // MOD bus
public static void onRegisterScreens(RegisterMenuScreensEvent event) {
    event.register(MY_MENU.get(), MyScreen::new);
}
// Fabric — legal because of the transitive access widener
@Override public void onInitializeClient() { MenuScreens.register(ModMenus.MY_MENU, MyScreen::new); }
```

Fabric's `fabric-transitive-access-wideners-v1.classtweaker`, verbatim:

```
transitive-accessible class  net/minecraft/world/inventory/MenuType$MenuSupplier
transitive-accessible method net/minecraft/world/inventory/MenuType <init> (…)V
transitive-accessible class  net/minecraft/client/gui/screens/MenuScreens$ScreenConstructor
transitive-accessible method net/minecraft/client/gui/screens/MenuScreens register (…)V
```
This is also why the `MenuType` constructor is callable on Fabric — no registry helper needed.

**26.4 preview — `MENU_SCREEN` client registry** (26.4-snapshot-8, ★★★ jar, subject to change).
`MenuScreens` is now backed by a **client registry** (`BuiltInClientRegistries.MENU_SCREEN`,
`bootstrap(WritableRegistry)`) instead of a private static map, and `ScreenConstructor` is `public`.
Per the draft 26.4 NeoForge primer (★★):

```java
// 26.4-s8 — vanilla path; the id must equal the MenuType's registry id
Registry.register(BuiltInClientRegistries.MENU_SCREEN, MY_MENU_ID, MyScreen::new);
```

Loader wrappers on 26.4 are **not established**: NeoForge has no 26.4 build, so whether
`RegisterMenuScreensEvent` survives or becomes a registry event is unknown; the Fabric transitive
access-widener entry for `MenuScreens.register` was not checked against the 26.4 branch.

### 5.8 Extra open-time data — the loader split

**NeoForge / Forge:** `IMenuTypeExtension.create(IContainerFactory<T>)` where the factory is
`(int containerId, Inventory inv, RegistryFriendlyByteBuf extraData) -> T`; open with
`serverPlayer.openMenu(provider, buf -> { /* write */ })`.

**Fabric — `ExtendedScreenHandlerType`, changed at 1.20.5:**

```java
// OLD (pre-1.20.5)
public class ExtendedScreenHandlerType<T extends AbstractContainerMenu> extends MenuType<T> {
    public ExtendedScreenHandlerType(ExtendedFactory<T> factory);
    public T create(int syncId, Inventory inv, FriendlyByteBuf buf);
}
public interface ExtendedScreenHandlerFactory extends MenuProvider {
    void writeScreenOpeningData(ServerPlayer player, FriendlyByteBuf buf);
}

// NEW (1.20.5+)
public class ExtendedScreenHandlerType<T extends AbstractContainerMenu, D> extends MenuType<T> {
    public ExtendedScreenHandlerType(ExtendedFactory<T, D> factory,
                                     StreamCodec<? super RegistryFriendlyByteBuf, D> packetCodec);
    public T create(int syncId, Inventory inv, D data);
}
public interface ExtendedScreenHandlerFactory<D> extends MenuProvider {
    D getScreenOpeningData(ServerPlayer player);
}
```
Same `FriendlyByteBuf` → `StreamCodec` migration that hit networking generally at 1.20.5.
`ScreenRegistry` and `ScreenHandlerRegistry` were **removed** — use `MenuScreens.register` plus the
plain `MenuType` constructor.

---

## 6. Input and focus

### 6.1 `GuiEventListener` per band

```java
// 1.20.1
public interface GuiEventListener extends TabOrderedElement {
    long DOUBLE_CLICK_THRESHOLD_MS = 250L;
    default void    mouseMoved(double mouseX, double mouseY);
    default boolean mouseClicked(double mouseX, double mouseY, int button);
    default boolean mouseReleased(double mouseX, double mouseY, int button);
    default boolean mouseDragged(double mouseX, double mouseY, int button, double dragX, double dragY);
    default boolean mouseScrolled(double mouseX, double mouseY, double delta);        // 3 doubles
    default boolean keyPressed(int keyCode, int scanCode, int modifiers);
    default boolean keyReleased(int keyCode, int scanCode, int modifiers);
    default boolean charTyped(char codePoint, int modifiers);
    default ComponentPath nextFocusPath(FocusNavigationEvent event);
    default boolean isMouseOver(double mouseX, double mouseY);
    void setFocused(boolean focused); boolean isFocused();
    default ComponentPath getCurrentFocusPath();
    default ScreenRectangle getRectangle();
}
```

| Change | Version |
|---|---|
| **horizontal scroll** — `mouseScrolled(mouseX, mouseY, horizontalAmount, verticalAmount)` | **1.20.2** (not 1.21) |
| `+ getBorderForArrowNavigation(ScreenDirection)` | **1.21.4** |
| **event objects** — `mouseClicked(MouseButtonEvent, boolean doubleClick)`, `mouseReleased(MouseButtonEvent)`, `mouseDragged(MouseButtonEvent, double, double)`, `keyPressed(KeyEvent)`, `keyReleased(KeyEvent)`, `charTyped(CharacterEvent)`; `DOUBLE_CLICK_THRESHOLD_MS` **removed**; `+ shouldTakeFocusAfterInteraction()` | **1.21.9** |
| `+ preeditUpdated(PreeditEvent)` (IME) | **26.1** |
| `+ default boolean capturesInput()`; event ints become **SDL** values (scancodes, `SDL_KMOD_*`, SDL mouse buttons) — §6.5 | **26.3** |
| `KeyEvent(int key, int keycode, int modifiers)` → **`+ boolean repeat`** (`repeat()`); `MouseButtonEvent`/`MouseButtonInfo` `+ isLeftMouse()`, `isMiddleMouse()`, `isRightMouse()`, `isMouse4()`, `isMouse5()`; `InputType + KEYBOARD_SELECTION`, `isMouse()`/`isKeyboard()` | **26.4-s8** ★★★ (subject to change) |
| `mouseScrolled` | **unchanged since 1.20.2** — still 4 raw doubles through 26.4-s8 |

### 6.2 Dispatch and the click contract

`ContainerEventHandler#mouseClicked` walks `children()` in order and gives the event to the first child
whose `isMouseOver` is true; a `true` return sets `setDragging(true)` and `setFocused(child)`.
**Registration order via `addRenderableWidget`/`addWidget` is z-order for input.**

```java
public boolean mouseClicked(double mx, double my, int button) {
    if (this.active && this.visible && this.isValidClickButton(button) && this.clicked(mx, my)) {
        this.playDownSound(Minecraft.getInstance().getSoundManager());
        this.onClick(mx, my);
        return true;
    }
    return false;
}
protected boolean isValidClickButton(int button);   // default: left button only (1.21.9+: takes MouseButtonInfo)
// ⚠ 26.3: SDL numbers left = 1, middle = 2, right = 3 — never compare against a literal 0/1;
//   use InputConstants.MOUSE_BUTTON_LEFT (≤26.3) or event.isLeftMouse() (26.4-s8)
public    void    onClick(double mx, double my);    // <- OVERRIDE THIS
public    void    onRelease(double mx, double my);
protected void    onDrag(double mx, double my, double dragX, double dragY);
public    void    playDownSound(SoundManager sm);   // SoundEvents.UI_BUTTON_CLICK @ 1.0f
```

- **Override `onClick`/`onRelease`/`onDrag`, not the `mouse*` methods** — you get the click sound, the
  `active`/`visible` guard and the button filter for free.
- `playDownSound` fires on **press**, before `onClick`.
- `AbstractButton#keyPressed` maps Space/Enter to `onPress()` — keyboard activation is free.
- **The vanilla recipe for a non-interactive widget** (used by `ImageWidget`, `StringWidget`,
  `LoadingDotsWidget`, `PlayerSkinWidget`, `FocusableTextWidget`): override `isActive()` → `false`,
  `nextFocusPath(...)` → `null`, `playDownSound(...)` → `{}`.

### 6.3 Double-click and slot drag

- **≤1.21.6:** `DOUBLE_CLICK_THRESHOLD_MS = 250L`; consumers time it themselves.
- **1.21.9+:** the constant is gone — the `boolean doubleClick` flag is handed to you.
- Slot drag / quick-craft / stack-splitting lives entirely in `AbstractContainerScreen` +
  `AbstractContainerMenu` (`quickCraftSlots`, `isQuickCrafting`, `quickCraftingType`
  `CHARITABLE`/`GREEDY`/`CLONE`, and the statics `getQuickcraftType`, `getQuickcraftHeader`,
  `getQuickcraftMask`, `canItemQuickReplace`, `getQuickCraftPlaceCount`, `canDragTo`).
  **You get all of it free by using real `Slot`s.**
- Snapback fields (`SNAPBACK_SPEED=100.0f`, `QUICKDROP_DELAY=500`) exist 1.20.1–1.21.11, **removed in 26.x**.

### 6.4 Focus and tab order

- `FocusNavigationEvent` has two record subtypes: `TabNavigation(boolean forward)` and
  `ArrowNavigation(ScreenDirection direction)`; `Screen` builds them in `createTabEvent()` /
  `createArrowEvent(ScreenDirection)`.
- `ComponentPath` is a linked path screen → focused leaf (`ComponentPath.leaf(...)`,
  `ComponentPath.path(...)`), applied via `Screen#changeFocus(ComponentPath)`.
- **Tab order** = `TabOrderedElement#getTabOrderGroup()` (default `0`) — lower groups first; within a
  group, `children()` order. Set with `AbstractWidget#setTabOrderGroup(int)`.
- `getRectangle()` and `getBorderForArrowNavigation` (1.21.4+) drive spatial arrow navigation.
- `ContainerEventHandler#magicalSpecialHackyFocus` was **removed in 1.20.5**.
- **26.4-s8:** `AbstractContainerWidget.allowTabNavigationInside(boolean)` and
  `ScrollableLayout.setTabGroup(int)` control whether Tab enters a container widget; highlight follows
  the last input type (`isHighlighted()`, §2.2); `MouseHandler` hides the cursor in keyboard mode
  (`onInputTypeChanged(InputType)`, `MOUSE_INPUT_SWITCH_DISTANCE = 7.0`). `MouseHandler.xpos()/ypos()`
  and `isLeft/Middle/RightPressed()` are **removed** — read the mouse from `GuiGraphicsExtractor.mouseX()/mouseY()`
  during extract, or from the event objects. ★★★ (subject to change)

### 6.5 26.3 SDL input in screens (era G, band K) ★★★

26.3 replaced GLFW with SDL3. Nothing in the screen *drawing* API moved, but every input integer
changed meaning — and most of these break **silently** (they still compile). Full key/modifier
tables live in `minecraft-mod-expert` → `api-migration-deltas.md` "Input / windowing (26.3 SDL3)".

| Concern | ≤26.2 (GLFW) | 26.3 (SDL3) | Do this |
|---|---|---|---|
| Key ints | GLFW key codes (ESC 256, Enter 257, Space 32, arrows 262–265) | **SDL scancodes** (ESC 41, Enter 40, Space 44, arrows 79–82); old 32 is now the "3" key | Compare against **`InputConstants.KEY_*`**, never literals |
| `KeyEvent` | `key()`, `scancode()` | **`key()`** = physical SDL scancode (layout-independent, what `KeyMapping` binds); **`keycode()`** = logical SDL keycode (layout-dependent); `+ shortcutKey()` (on `InputWithModifiers`, replacing `getDigit()`/`NOT_DIGIT`) | Use `key()` for game controls; `keycode()` for "the key labelled Z" text shortcuts |
| Modifier masks | `SHIFT 1`, `CONTROL 2`, `ALT 4` | `MOD_SHIFT 3`, `MOD_CONTROL 192`, `MOD_ALT 768` (`SDL_KMOD_*`); old `0x2` = Right Shift | `KeyEvent.hasShiftDown()/hasControlDown()/hasAltDown()` |
| Mouse buttons | left 0, right 1, middle 2 | **left 1, middle 2, right 3** | `InputConstants.MOUSE_BUTTON_*` |
| `InputConstants.REPEAT` | **2** | **−1** (SDL has no repeat action) | Don't compare the action int; 26.4-s8 adds `KeyEvent.repeat()` |
| `InputConstants` renames | `KEY_LSUPER/RSUPER`, `isKeyDown(Window,int)` | `KEY_LGUI/RGUI`, `isKeyDown(int)`, `$Type.KEYSYM`→`KEYBOARD` | per-band adapter |
| Text-input focus | GLFW delivered chars to any focused widget | SDL only delivers text while text input is **started**. Vanilla `EditBox` does it. A custom text widget must call **`Minecraft.getInstance().onTextInputFocusChange(GuiEventListener, boolean)`** from `setFocused` (or `textInputManager().onTextInputFocusChange(Object owner, boolean)`), else `charTyped` never fires | Call it from `setFocused`; also return `capturesInput() = true` while editing |
| Hotkey suppression | ad hoc | **`GuiEventListener.capturesInput()`** + **`Screen.isInputCaptured()`** — vanilla's gate that stops screen hotkeys (inventory-key-closes, etc.) while typing | Override `capturesInput()` on any typing widget |
| Narrator toggle | `updateNarratorStatus(boolean)` | `updateNarratorStatus(boolean, NarrationTrigger)` | — |
| macOS Ctrl-click | long-left-click quirk | `Options.ctrlClickEmulatesRightClick()` / `InputQuirks.EMULATE_RIGHT_CLICK_WITH_CTRL_KEY` | Respect it if you hand-roll click handling |
| IME | `PreeditEvent.createFromCallback(…)` | `PreeditEvent.fromSdlTextEditing(String,int,int)`; SDL hint `SDL_IME_IMPLEMENTED_UI=composition` (the game draws preedit itself via `IMEPreeditOverlay`); candidate rect via `SDL_SetTextInputArea`, scaled by `Window.getPixelDensity()` | — |

> **`onTextInputFocusChange` versions.** `TextInputManager.onTextInputFocusChange(boolean)` (1-arg)
> **existed in 26.2 and was removed in 26.3**; the Fabric 26.3 blog's 1-arg example is the 26.2
> signature. On 26.3 use `Minecraft#onTextInputFocusChange(GuiEventListener, boolean)` (which also
> manages preedit) or `TextInputManager#onTextInputFocusChange(Object, boolean)` /
> `startTextInput(Object)` / `stopTextInput(Object)`. ★★★

```java
// 26.3 custom text widget — minimal contract
@Override public void setFocused(boolean focused) {
    super.setFocused(focused);
    Minecraft.getInstance().onTextInputFocusChange(this, focused);   // SDL start/stop text input
}
@Override public boolean capturesInput() { return this.isFocused(); }   // suppress screen hotkeys
```

**Portable key handling:** keep key, modifier and mouse-button constants behind the per-band version
adapter rather than a shared `static final int` — the same symbol name (`InputConstants.KEY_ESCAPE`)
compiles on both GLFW and SDL bands, but a literal baked into shared code does not mean the same key.

**Controllers:** none. SDL is initialised with VIDEO only; no Gamepad/Joystick/Haptic API in 26.3 or
26.4-s8. Keyboard navigation is Mojang's stated first step. ★★★

---

## 7. Narration

```java
public interface NarrationElementOutput {
    default void add(NarratedElementType type, Component msg);
    default void add(NarratedElementType type, String msg);
    default void add(NarratedElementType type, Component... msgs);
    void         add(NarratedElementType type, NarrationThunk<?> thunk);
    NarrationElementOutput nest();
}
public enum NarratedElementType { TITLE, POSITION, HINT, USAGE }
```

`AbstractWidget` supplies the plumbing, so you fill in exactly one method:

```java
public final void updateNarration(NarrationElementOutput out) {      // final since 1.20.1
    this.updateWidgetNarration(out);
    this.tooltip.updateNarration(out);                                // 1.20.5+ — tooltip text narrates free
}
protected abstract void updateWidgetNarration(NarrationElementOutput out);

protected void defaultButtonNarrationText(NarrationElementOutput out) {
    out.add(NarratedElementType.TITLE, this.createNarrationMessage());
    if (this.active) {
        out.add(NarratedElementType.USAGE, Component.translatable(
            this.isFocused() ? "narration.button.usage.focused" : "narration.button.usage.hovered"));
    }
}
public NarratableEntry.NarrationPriority narrationPriority() {
    return this.isFocused() ? FOCUSED : (this.isHovered ? HOVERED : NONE);
}
```

**What a well-behaved custom widget must do:**

1. **Extend `AbstractWidget`** (or `AbstractButton`) — that satisfies
   `Renderable + GuiEventListener + LayoutElement + NarratableEntry` in one move.
2. **Implement `updateWidgetNarration`.** Minimum: `this.defaultButtonNarrationText(out);`. Add `HINT`
   for context, `USAGE` for interaction instructions, `POSITION` for list rows.
3. **Register with `addRenderableWidget`**, never `addRenderableOnly`.
4. **If non-interactive:** `isActive()` → `false`, `nextFocusPath(...)` → `null`,
   `playDownSound(...)` → `{}`, and emit only a `TITLE`.
5. **Attach a `Tooltip`** — from 1.20.5 its narration merges automatically.
6. **If it's a list row with children:** extend `ContainerObjectSelectionList.Entry` and implement
   both `narratables()` and `children()`.

Screen-level: `updateNarrationState`, `updateNarratedWidget` (override to control which widget is
described; helper `Screen.findNarratableWidget(...)`), `getUsageNarration()` (defaults
`narrator.screen.usage`), `shouldNarrateNavigation()`, `triggerImmediateNarration(boolean)`,
`handleDelayedNarration()`. Pacing constants: `NARRATE_DELAY_MOUSE_MOVE = 750L`,
`NARRATE_DELAY_MOUSE_ACTION = 200L`, `NARRATE_DELAY_KEYBOARD_ACTION = 200L`.

| Narration change | Version |
|---|---|
| New enum **`NarrationTrigger { MOUSE, KEYBOARD, SYSTEM }`**; `NarrationElementOutput` gains `abstract NarrationTrigger narrationTrigger()` (only matters if you *implement* the output); `ScreenNarrationCollector.update(Consumer, NarrationTrigger)`; `Screen.updateNarratorStatus(boolean, NarrationTrigger)`, `+ scheduleNarration()` | **26.3** ★★★ |
| **`GroupNarration`** (`LIST`, `list(key)`, `list(key, usageKey, ScreenAxis)`, `grid(cols, key)`, `position(i, n)`, `usage(n)`, key `narrator.position.list` → "3 out of 9"); `NarratableEntry$NarrationPriority.of(focused, hovered)`; `AbstractContainerWidget.getNarratedChild(NarrationTrigger, T, T)`; `AbstractWidget.updateTooltipNarration(out)`; slot narration via `Slot.getNarrationName()` (override to name special slots) | **26.4-s8** ★★★ (subject to change) |

---

## 8. Tooltips

```java
public class Tooltip implements NarrationSupplier {
    private static final int MAX_WIDTH = 170;                 // wrap width in px
    public static Tooltip create(Component message);
    public static Tooltip create(Component message, @Nullable Component narration);
    public static List<FormattedCharSequence> splitTooltip(Minecraft mc, Component msg);
}
```

```java
widget.setTooltip(Tooltip.create(Component.translatable("tooltip.examplemod.thing")));
Button.builder(msg, onPress).tooltip(Tooltip.create(msg2)).build();
```

| Version | Delay signature |
|---|---|
| 1.20.1–1.20.4 | `setTooltipDelay(int ticks)` |
| **1.20.5+** | `setTooltipDelay(java.time.Duration)` — e.g. `Duration.ofMillis(700)` |

1.20.5 moved the machinery into `WidgetTooltipHolder` (`setDelay`, `set`, `get`,
`refreshTooltipForNextRenderPass`, `createTooltipPositioner`, `updateNarration`).

| Version | `GuiGraphics` tooltip API |
|---|---|
| 1.20.1–1.21.1 | `renderTooltip(Font, ItemStack\|Component\|List, …)`, `renderComponentTooltip(…)` |
| **1.21.2–1.21.4** | every variant gains a trailing `ResourceLocation` background-sprite parameter |
| **1.21.6+** | `Screen#setTooltipForNextRenderPass*` **removed** → `GuiGraphics#setTooltipForNextFrame(…)` (11 overloads); immediate `renderTooltip(Font, List<ClientTooltipComponent>, int, int, ClientTooltipPositioner, ResourceLocation)` retained; `renderDeferredTooltip()` |
| **1.21.9** | `renderDeferredTooltip` → `renderDeferredElements` |
| **26.1/26.2** | `GuiGraphicsExtractor`; `renderTooltip`→`tooltip`; `AbstractContainerScreen#extractTooltip` |
| **26.3** | `tooltip(Font, List<ClientTooltipComponent>, int, int, ClientTooltipPositioner, Identifier)` **+ trailing `boolean extraSpaceAfterFirstLine`**; new overload `setTooltipForNextFrame(Font, List<Component>, Optional<TooltipComponent>, int, int, Identifier, boolean extraSpaceAfterFirstLine)` |
| **26.4-s8** | `Tooltip.createForItem(List<Component>, ItemStack)`, `Tooltip.extraSpaceAfterFirstLine()`, `besideCursor()`; `Button.Builder.tooltip(Component)`; `AbstractContainerScreen#extractTooltip`/`getTooltipFromContainerItem` **removed** (tooltips come from `SlotWidget`'s `Supplier<Tooltip>`/`Function<Slot, Tooltip>`) ★★★ (subject to change) |

> **26.3 visible change — the first-line gap is now item-only.** ★★★ (bytecode)
> - **26.2:** every multi-line tooltip got a **2 px** gap under line 1; a single-line tooltip shrank by 2.
> - **26.3:** the gap is added only when `extraSpaceAfterFirstLine == true`
>   (`heightOffset = (!extra || lines == 1) ? -2 : 0`; gap `extra ? 2 : 0`).
>   `setTooltipForNextFrame(Font, ItemStack, x, y)` passes `true`; every `Component`,
>   `FormattedCharSequence` and widget-`Tooltip` path passes `false`.
> - Result: **item tooltips look the same; multi-line text/widget tooltips are 4 px shorter** and lose
>   the title gap. Pass `true` when a non-item tooltip should read as "title + body" like an item.
> - 26.4-snapshot-8 still has open bugs here (MC-313103: gap misplaced when an item name wraps;
>   MC-313046: item-tooltip y fixed in s8) — expect further adjustment.

**`TooltipRenderUtil` constants** (unchanged 26.2 → 26.4-s8, plus `MARGIN = 9`; `Tooltip.MAX_WIDTH = 170`): `MOUSE_OFFSET = 12`; `PADDING_LEFT/RIGHT/TOP/BOTTOM = 3`;
`BACKGROUND_COLOR = 0xF0100010`; `BORDER_COLOR_TOP = 0x505000FF`; `BORDER_COLOR_BOTTOM = 0x5028007F`.

**Positioning:** `ClientTooltipPositioner#positionTooltip(screenW, screenH, mouseX, mouseY, tipW, tipH)`.
Implementations: `DefaultTooltipPositioner` (mouse-follow), `BelowOrAboveWidgetTooltipPositioner`,
`MenuTooltipPositioner`.

**Custom tooltip content:** `TooltipComponent` (common half, `net.minecraft.world.inventory.tooltip`) +
`ClientTooltipComponent` (client half). Registering the mapping is loader-specific:

- **NeoForge / Forge 1.20.1:** `RegisterClientTooltipComponentFactoriesEvent` on the mod bus —
  `event.register(MyTooltipComponent.class, MyClientTooltipComponent::new)`.
- **Fabric:** `TooltipComponentCallback.EVENT` (fabric-rendering-v1). ★★ — verified ≤1.21.x only.
  On 26.3/26.4 Fabric API exposes `ClientTooltipComponentCallback` (unchanged 26.2 → 26.4 branch) ★★★.
- NeoForge `RegisterClientTooltipComponentFactoriesEvent` is unchanged on 26.3.x ★★★.

---

## 9. Toasts

```java
// 1.20.1 – 1.21.1
public interface Toast {
    ResourceLocation TEXTURE;          // removed 1.21.2 (sprite atlas)
    Object NO_TOKEN = new Object();
    int SLOT_HEIGHT = 32;
    Toast.Visibility render(GuiGraphics g, ToastComponent tc, long timeSinceShown);
    default int width()  { return 160; }
    default int height() { return 32; }
    enum Visibility { SHOW, HIDE }     // ★★ names inferred from usage
}
```

| Change | Version |
|---|---|
| **`ToastComponent` → `ToastManager`; `Minecraft#getToasts` → `getToastManager`** | **1.21.2** |
| `Toast` reshapes: single `render(...)` splits into `getWantedVisibility()` + `update(ToastManager, long)` + `render(GuiGraphics, Font, long)`; `slotCount()` → `occcupiedSlotCount()` *(Mojang's typo)*; `DEFAULT_WIDTH = 160` explicit; `Toast.TEXTURE` removed | **1.21.2** |
| `+ xPos(int,float)`, `yPos(int)`, `getSoundEvent()`, `onFinishedRendering()` | 1.21.9–1.21.11 |
| `NowPlayingToast`; `ToastManager(Minecraft, Options)` | **1.21.11** |
| `Toast#render` → `extractRenderState(GuiGraphicsExtractor, Font, long)` | **26.1** |
| `FriendToast` added | 26.2 |
| *No toast change*; `Toast.DEFAULT_WIDTH 160`, `SLOT_HEIGHT 32`, `ToastManager.SLOT_COUNT 5` unchanged | 26.3 |
| `ToastManager` becomes `Renderable` (follows the 26.4 extract shape); toast metrics unchanged; `toast/social_interactions` sprite removed | 26.4-s8 ★★★ (subject to change) |

Also note the **Band A quirk**: `SystemToast.SystemToastIds` (plural) on 1.20.1 became
`SystemToast.SystemToastId` from 1.20.5.

```java
// 1.21.2+ custom toast
public class MyToast implements Toast {
    private static final ResourceLocation BG = ResourceLocation.withDefaultNamespace("toast/advancement");
    private Toast.Visibility visibility = Toast.Visibility.HIDE;

    @Override public Toast.Visibility getWantedVisibility() { return this.visibility; }
    @Override public void update(ToastManager mgr, long timeSinceShown) {
        this.visibility = timeSinceShown < 5000L * mgr.getNotificationDisplayTimeMultiplier()
                        ? Toast.Visibility.SHOW : Toast.Visibility.HIDE;
    }
    @Override public void render(GuiGraphics g, Font font, long timeSinceShown) {
        g.blitSprite(RenderType::guiTextured, BG, 0, 0, this.width(), this.height());
        g.drawString(font, this.title,   18,  7, 0xFFFF8800, false);
        g.drawString(font, this.message, 18, 18, 0xFFFFFFFF, false);
    }
}
Minecraft.getInstance().getToastManager().addToast(new MyToast(title, message));   // 1.21.2+
Minecraft.getInstance().getToasts().addToast(new MyToast(title, message));         // 1.20.1 – 1.21.1
```

**Built-ins:** `SystemToast` (`MAX_LINE_SIZE=200`, `LINE_SPACING=12`, `MARGIN=10`; statics `add`,
`addOrUpdate`, `multiline`, `forceHide`), `TutorialToast` (`PROGRESS_BAR_WIDTH=154`,
`PROGRESS_BAR_HEIGHT=1`, `PROGRESS_BAR_X=3`, `PROGRESS_BAR_Y=28`; `updateProgress(float)`, `hide()`),
`AdvancementToast`, `RecipeToast`.

> **Respect the player's Notification Time setting**: multiply your duration by
> `ToastManager#getNotificationDisplayTimeMultiplier()`, as the snippet above does.

---

## 10. Migration cheat-sheet

| From → To | Must change |
|---|---|
| **1.20.1 → 1.20.2** | `renderBackground(g)` → `(g, mx, my, pt)`; `mouseScrolled` gains a 4th double; **delete `editBox.tick()`**; sheet textures → sprite atlas (`blitSprite`, `WidgetSprites`) |
| **1.20.2 → 1.20.3** | `new Checkbox(...)` → `Checkbox.builder(msg, font).pos(x,y).selected(sel).build()` ★★ |
| **1.20.4 → 1.20.5** | `renderDirtBackground`→`renderMenuBackground`; `BACKGROUND_LOCATION`→`MENU_BACKGROUND`; **stop overriding `AbstractWidget#render`** (now final) → `renderWidget`; `setTooltipDelay(int)`→`(Duration)`; `AbstractSelectionList` ctor loses one int; `renderList`→`renderListItems`; `TextAndImageButton`/`CommonButtons` gone; blur appears |
| **1.21.1 → 1.21.2** | every blit gains a leading `Function<ResourceLocation,RenderType>` + explicit PNG size; `setColor`/`drawManaged` removed; `bufferSource`→`drawSpecial`; **`ToastComponent`→`ToastManager` + whole `Toast` interface reshapes**; tooltips gain a trailing `ResourceLocation`; **new: `addStandardInventorySlots(inv, 8, 84)`** |
| **1.21.2 → 1.21.4** | `AbstractScrollWidget`→`AbstractScrollArea`/`AbstractTextAreaWidget`; `getBorderForArrowNavigation` appears |
| **1.21.4 → 1.21.6** | blit first arg → **`RenderPipeline`**; `pose()` returns `Matrix3x2fStack` (no z); `drawString` returns `void` **and requires alpha**; `Screen#setTooltipForNextRenderPass*` removed → `GuiGraphics#setTooltipForNextFrame`; **the submit/render two-phase architecture arrives — names unchanged**; `ScrollableLayout` available |
| **1.21.6 → 1.21.9** | all input methods take event objects; `DOUBLE_CLICK_THRESHOLD_MS` gone; `renderWithTooltip`→`renderWithTooltipAndSubtitles`; **`GuiSpriteManager` deleted** (sprites via `Sheets#GUI_SHEET` + `MaterialSet`) |
| **1.21.9 → 1.21.11** | `init(Minecraft,int,int)`→`init(int,int)`; `resize(Minecraft,int,int)`→`resize(int,int)`; `minecraft`/`font` become `final`; `clearFocus()` public; **`AbstractButton#renderWidget` final → move to `renderContents` + `renderDefaultSprite`**; `ResourceLocation`→`Identifier`; `CycleButton.builder(fmt, initial)` positional |
| **1.21.11 → 26.1/26.2** | mass rename to `extract*`; `GuiGraphics`→`GuiGraphicsExtractor`; **`AbstractContainerScreen#renderBg` deleted — override `extractBackground`**; `imageWidth/imageHeight` final (5-arg ctor); `ClickType`→`ContainerInput`; `Minecraft#setScreen`→`setScreenAndShow`; `GuiGraphicsExtractor` shortening (`drawString`→`text`, `renderItem`→`item`, …). **Layout code is untouched.** |
| **26.2 → 26.3** | **input, not drawing:** replace every GLFW key/modifier/mouse literal and `org.lwjgl.glfw` import with `InputConstants.*` / `KeyEvent.has*Down()`; `KeyEvent.scancode()`→`keycode()`; custom text widgets call `Minecraft#onTextInputFocusChange(this, focused)` and override `capturesInput()`; `updateNarratorStatus(boolean)`→`(boolean, NarrationTrigger)`; drop `fillCrashDetails` overrides; `textWithWordWrap` now returns next-y `int`; tooltips take a trailing `extraSpaceAfterFirstLine` (multi-line text tooltips lose the 2 px title gap); `RenderPipeline`/`GpuTextureView` imports move to `com.mojang.renderpearl.api.*`; `ConfirmLinkScreen` String-URL ctors gone (use `URI`); `AbstractSignEditScreen(SignBlockEntity, SignTextSlot, boolean)` |
| **26.3 → 26.4-s8** *(preview, subject to change)* | drop `mouseX/mouseY/partialTick` from **every** `extract*` override (read `g.mouseX()/mouseY()/partialTicks()/deltaTracker()`); move time/hover logic into `update(DeltaTracker)`; `blit`/`blitSprite`/`fill` take **`GuiPipeline`** (`TEXTURED`, `DEFAULT`, …); `addRenderableOnly` gone; `widget.visible` → `setVisible()`; `isHoveredOrFocused()`→`isHighlighted()`; `Slot` ctor gains `Slot.Section`; `hoveredSlot`→`getHoveredSlot()` (`SlotWidget`); `slotClicked(SlotWidget, …)`; `extractSlot`/`extractTooltip` removed; register container screens via the `MENU_SCREEN` client registry; `Tab.getTabTitle()` gone (title passed to `TabButton`); `CycleButton` builder methods moved to `AbstractCycleButton$Builder`; `DynamicTexture` gone (`TextureManager.register(Identifier, TextureResources)`) |

---

## 11. Third-party wrappers, one line each

- **Cloth Config** reimplements the list (`DynamicEntryListWidget`) for variable-height rows + smooth
  scrolling.
- **owo-lib** is a parallel flex/percent component tree bridged by `OwoUIAdapter`, which itself
  implements `Renderable + GuiEventListener + NarratableEntry` so it drops into any vanilla screen.
- **SpruceUI** keeps vanilla shapes but adds anchored `Position` and a deferred static tooltip queue
  (`Tooltip.queue()` / `Tooltip.renderAll(g)`) that fixes vanilla's tooltip z-order.
- **LibGui** is the only container-GUI-focused one: an 18px-grid `WGridPanel` and `WItemSlot`
  generating `ValidatedSlot` peers onto the menu.
- **YACL** is the only config lib built on vanilla `ContainerObjectSelectionList` + `TabNavigationBar`
  — so it inherits narration and focus for free.

---

## 12. Could not verify

1. **`Minecraft#setScreen(Screen)` in 26.2/26.3.** `javap` shows only `setScreenAndShow(Screen)` and
   `forceSetScreen` on 26.2; the 26.3 and 26.4-s8 surface was not re-checked for this member. Treat
   `setScreenAndShow` as the entry point but confirm on your toolchain. ★★
2. **`Checkbox.builder`: 1.20.3 vs 1.20.4** — attributed to 1.20.3; no primer exists for 1.20.3. ★★
3. **Snapshot-level precision** exists for only two items — **23w31a** (GUI sprite atlas) and
   **24w09a** (menu blur + `menu_background`). Everything else is release-granularity.
4. **26.1/26.2 rows** rest on primers plus local jars; anything primer-only (e.g. the `GuiRenderState`
   package move) is single-source.
5. **Is `GameRenderer#processBlurEffect()` dead code in 1.21.6?** It still exists in mappings despite
   blur re-plumbing through `blurBeforeThisStratum`. **Do not state "blur was removed" for any 1.21.x**
   — it was re-plumbed, not deleted.
6. **Fabric `TooltipComponentCallback`** verified ≤1.21.x only. ★★
7. **`Toast.Visibility` constant names** (`SHOW`/`HIDE`) inferred from usage. ★★
8. **Exact snapshot for each 1.20.5 widget addition** — confirmed absent in 1.20.4 and present in
   1.20.5, but not pinned.
9. **26.4 rows are snapshot-8 only.** The 26.4-snapshot-7 jar was not diffed separately, so which
   26.4 signature changes landed in s8 vs earlier is not pinned; all of them can change before the
   26.4 release. ★
10. **26.4 loader hooks** — `RegisterMenuScreensEvent`, Fabric's `MenuScreens.register` access-widener
    and NeoForge `ScreenEvent` shapes against the `MENU_SCREEN` registry and the parameterless
    `extract*` are unknown (no NeoForge 26.4 build; the 26.4 primer is a draft PR). ★
11. **26.4 behavioural semantics** not read from bytecode: `SlotWidget` hit-box vs the old slot hover
    area, `updateSlotWidgets()` call timing, and exact keyboard-mode carried-item rendering. ★
12. **26.3 HiDPI per OS** (Wayland fractional scale, Windows per-monitor DPI, macOS Retina) — inferred
    from SDL defaults, not tested on hardware. ★
13. **Whether the 26.2 custom-screen black-frame defect persists on 26.3/26.4** — not re-tested (see
    `render-pipeline.md` §7).
