# Java design patterns for mod UI (1.20.1 → 26.4 preview)

How to *structure* GUI code so one source tree survives every band: where state lives, how drawing
stays a pure function of state, how version drift and loader drift are absorbed, which GoF patterns
pay off, which Java features each band may use, how Mixin and threading constrain you, and how to
test. Status as of 2026-11-11 (MC 26.3 release, 26.4-snapshot-8 preview).

This file is about **architecture**. Exact per-band signatures live in `screen-widget-api.md` and
`render-pipeline.md`; loader registration in `loader-hooks.md`; input normalisation at
the seam in §3.6; toolchain and JDK coordinates in
the `minecraft-mod-expert` skill.

Confidence: ★★★ verified against source, primary docs or this machine's repos · ★★ strong secondary
source or memory corroborated once · ★ inference or snapshot-only; check before relying on it.

---

## Contents

0. The ten rules
1. State outside the Screen (unidirectional flow)
2. Render as a function of state (the extract model)
3. Version seam vs loader seam
4. GoF patterns that pay off, and anti-patterns
5. Java language level per band
6. Mixin and Java 25
7. Threading and lifecycle
8. Testing layers
9. Could not verify

---

## 0. The ten rules

1. **State lives outside the `Screen`.** A screen is a disposable view over a model that outlives
   `init()`, resize, tab switches and child screens. `init()` only *reads* state. ★★★
2. **Unidirectional flow:** widgets dispatch `sealed` actions → a pure reducer returns a new
   immutable `record` state plus effects-as-data → the screen rebuilds or simply re-extracts. ★★★
3. **Render/extract is a pure function of (state, layout, input mode).** No mutation, no I/O, no
   per-frame `Component`/`String` building. Good practice before 1.21.6, the contract after it, and
   26.4 says so outright (time and hover logic belong in `update(DeltaTracker)`). ★★★
4. **Two axes, two mechanisms.** MC-version drift is compile-time (adapter files, variants,
   Stonecutter). Loader drift is an interface chosen at startup (`ServiceLoader`, entrypoint `set`,
   `@ExpectPlatform`). Architectury and MultiLoader-Template solve **only** the loader axis. ★★★
5. **Every GUI break goes behind four adapter classes**: drawing facade, widget base, screen base,
   static platform shim. A production kit built this way keeps ~11.7k lines of UI byte-identical
   from 1.20.1 to 26.3. ★★★
6. **Normalize input into your own enums/records at the seam** (`UiKey.ESCAPE`, not `256`). 26.3
   changed every key int to an SDL scancode; 26.4 removes mouse params from extract. ★★★
7. **Shared trees compile at `--release 17`** while 1.20.1 is in scope. Records, sealed types,
   `instanceof` patterns, switch expressions, text blocks: yes. Pattern `switch`, record patterns,
   `getFirst()`, `Math.clamp`: band files only. Preview features: never. ★★★
8. **Never touch game state off the client thread.** I/O on your own executor, hop back with
   `handleAsync(…, Minecraft.getInstance())`, GPU uploads on the render thread, cancel in
   `removed()`. ★★★
9. **Test in layers:** pure JUnit → `fabric-loader-junit` → Fabric client game tests with
   `assertScreenshotEquals` on 1.21.4+. ★★★
10. **Fork the smallest thing, and list its siblings in its header.** The only anti-drift defense
    short of a preprocessor, and cheap to lint (a CI script that diffs every non-adapter file across bands). ★★★

---

## 1. State outside the Screen

### 1.1 Why the Screen is the wrong owner ★★★

| Event | What happens to screen-held state |
|---|---|
| Window resize / GUI-scale change | `init()` re-runs via `rebuildWidgets()` on a plain `Screen` (`screen-widget-api.md` §1.3). `EditBox` text, scroll offset, `CycleButton` index stored only in widgets are rebuilt from scratch |
| Child screen (confirm, file picker) | parent is replaced; it may be re-`init`ed or recreated by the caller |
| Version drift | 26.2 moved screens onto `Minecraft.gui`; 26.4 made `Screen` an `Updatable`. Screen shape keeps changing; a plain-Java model doesn't |

### 1.2 The shape: MVU / unidirectional data flow ★★★

```
 input ─► widget callback ─► store.dispatch(Action)
                                   │
                             Reducer (pure) ──► Effects (HTTP, file, packet)
                                   │                  │ result
                              new State ◄─────────────┘ dispatch(Loaded/Failed)
                                   │ (listeners, client thread)
                  Screen: rebuildWidgets() if structure changed,
                          else nothing; next extract reads store.state()
```

Plain Java 17, no Minecraft imports:

```java
public record HubState(Tab tab, String query, Load<List<ServerRow>> servers, int selected,
                       Optional<Confirm> confirm) {
    public static HubState initial() { return new HubState(Tab.DISCOVER, "", new Load.Idle<>(), -1, Optional.empty()); }
    public HubState withTab(Tab t) { return new HubState(t, query, servers, -1, confirm); }
    public HubState withServers(Load<List<ServerRow>> s) { return new HubState(tab, query, s, selected, confirm); }
    // … one wither per field
}

public sealed interface Load<T> {
    record Idle<T>() implements Load<T> {}
    record Loading<T>(long reqId) implements Load<T> {}        // request id: see §7.2
    record Ready<T>(T value) implements Load<T> {}
    record Failed<T>(String reasonKey) implements Load<T> {}   // a lang key, not a Component
}

public sealed interface HubAction {
    record SelectTab(Tab tab) implements HubAction {}
    record Refresh() implements HubAction {}
    record ServersLoaded(long reqId, List<ServerRow> rows) implements HubAction {}
    record ServersFailed(long reqId, String reasonKey) implements HubAction {}
    record RequestDelete(String id) implements HubAction {}
    record ConfirmResult(boolean yes) implements HubAction {}
}

public sealed interface HubEffect {                            // effects as data: testable
    record FetchServers(long reqId, String query) implements HubEffect {}
    record DeleteServer(String id) implements HubEffect {}
}
public record Next(HubState state, List<HubEffect> effects) {
    static Next of(HubState s, HubEffect... e) { return new Next(s, List.of(e)); }
}
```

Reducer at `--release 17` (JEP 394 `instanceof` patterns):

```java
public static Next reduce(HubState s, HubAction a, LongSupplier ids) {
    if (a instanceof HubAction.SelectTab t) return Next.of(s.withTab(t.tab()));
    if (a instanceof HubAction.Refresh) {
        long id = ids.getAsLong();
        return Next.of(s.withServers(new Load.Loading<>(id)), new HubEffect.FetchServers(id, s.query()));
    }
    if (a instanceof HubAction.ServersLoaded r)                 // drop stale responses
        return isCurrent(s, r.reqId()) ? Next.of(s.withServers(new Load.Ready<>(r.rows()))) : Next.of(s);
    // … RequestDelete puts a Confirm into state; ConfirmResult emits DeleteServer or clears it
    throw new IllegalArgumentException("unhandled " + a);       // Java 17: no exhaustiveness check
}
static boolean isCurrent(HubState s, long id) { return s.servers() instanceof Load.Loading<?> l && l.reqId() == id; }
```

The same reducer in a Java 21+ band file (JEP 441 + 440): **the compiler proves every action is
handled.** This is the main reason to want Java 21 in UI code.

```java
return switch (a) {
    case HubAction.SelectTab(Tab t) -> Next.of(s.withTab(t));
    case HubAction.ServersLoaded(long id, var rows) when isCurrent(s, id) -> Next.of(s.withServers(new Load.Ready<>(rows)));
    case HubAction.ServersLoaded _, HubAction.ServersFailed _ -> Next.of(s);   // `_`: JEP 456, Java 22+ (26.x bands)
    // …
};  // no default: a new action without a case is a compile error
```

> If the oldest band is ≥1.20.5, compile the shared UI tree at 21 and use the switch. If 1.20.1 is
> in scope, keep the `instanceof` chain and add a unit test that walks
> `HubAction.class.getPermittedSubclasses()` (Java 17, JEP 409) — it restores exhaustiveness at test
> time (§8.1).

The store, the only mutable object, client-thread confined:

```java
public final class Store<S, A, E> {
    public interface Reducer<S, A, E> { Step<S, E> reduce(S s, A a); }
    public record Step<S, E>(S state, List<E> effects) {}

    private S state;
    private final Reducer<S, A, E> reducer; private final Consumer<E> effects;
    private final List<BiConsumer<S, S>> listeners = new ArrayList<>();
    private final Thread owner = Thread.currentThread();       // construct on the client thread

    public S state() { return state; }
    public void dispatch(A action) {
        if (Thread.currentThread() != owner) throw new IllegalStateException("off-thread dispatch: " + action);
        Step<S, E> step = reducer.reduce(state, action);
        S old = state; state = step.state();
        if (!old.equals(state)) for (var l : List.copyOf(listeners)) l.accept(old, state);
        step.effects().forEach(effects);
    }
    public Runnable subscribe(BiConsumer<S, S> l) { listeners.add(l); return () -> listeners.remove(l); }
}
```

The thread assertion turns the #1 async bug (§7) into an immediate, attributable exception.

### 1.3 Wiring it to a Screen ★★★ lifecycle / ★★ shape

```java
public final class HubScreen extends KitScreen {                 // your adapter base (§3.3)
    private final Store<HubState, HubAction, HubEffect> store;   // injected: outlives this instance
    private Runnable unsubscribe = () -> {};

    @Override protected void buildBase() {                       // called from init(); idempotent
        HubState s = store.state();
        HubView v = view();                                      // §2.1
        for (TabChip chip : v.tabs())
            addFree(KitButton.builder(chip.label(), () -> store.dispatch(new HubAction.SelectTab(chip.tab())))
                    .bounds(chip.x(), chip.y(), chip.w(), 20).selected(chip.active()).build());
        unsubscribe.run();
        unsubscribe = store.subscribe((old, now) -> { if (HubView.structureChanged(old, now)) rebuildWidgets(); });
        s.confirm().ifPresent(this::openConfirm);                // pending confirm survives resize
    }
    @Override public void removed() { unsubscribe.run(); super.removed(); }   // no leaked screen
}
```

- Subscribe in the build path, **unsubscribe in `removed()`**: a listener capturing a dead screen
  leaks it, its widgets and their textures. ★★★
- `EditBox.setResponder` fires during `setValue` — set the value **before** the responder. ★★
- Store owner: per-world UI → client singleton cleared on disconnect (Fabric
  `ClientPlayConnectionEvents.DISCONNECT`, NeoForge `ClientPlayerNetworkEvent.LoggingOut`). Block
  GUI → the `AbstractContainerMenu` already *is* the synced model; don't duplicate it. ★★
- **MVVM alternative** (`Property<T>` + two-way bindings, §4.3) is simpler for flat config forms.
  Use MVU for anything with async loading or destructive actions. ★★

---

## 2. Render as a function of state

### 2.1 View-model, memoized on state identity ★★★

The 1.21.6 rewrite made drawing a *prepare/extract* phase that submits immutable element records to
`GuiRenderState` (`render-pipeline.md` §2); 26.1 renamed it to say so; 26.4 strips the mouse and
partial-tick parameters and adds `Updatable.update(DeltaTracker)`. Mirror that split one level up:

```
HubState ──HubView.of()──► HubView (laid out, labels resolved) ──extract──► vanilla render state
 pure, tested             pure, tested, immutable records          per-band adapter only
```

```java
public record HubView(List<TabChip> tabs, List<RowView> rows, Optional<Banner> banner, Rect listArea) {
    public static HubView of(HubState s, Layout l) { /* positions, label keys, ARGB colors */ }
    public static boolean structureChanged(HubState a, HubState b) { return a.tab() != b.tab() || !sameShape(a, b); }
}
public record Rect(int x, int y, int w, int h) {
    public boolean contains(double px, double py) { return px >= x && py >= y && px < x + w && py < y + h; }
}

private HubState viewFor; private HubView view;
private HubView view() {                                         // states are immutable: == is a valid key
    HubState s = store.state();
    if (s != viewFor || layoutDirty) { view = HubView.of(s, layout); viewFor = s; layoutDirty = false; }
    return view;
}
```

Hover, focus and animation stay out of the view: compute them per frame from
`(isHighlighted(), Util.getMillis())`. On 26.4 use `isHighlighted()` (mouse mode → hovered, keyboard
mode → focused), not `isHovered() || isFocused()` (`screen-widget-api.md` §2.2).

### 2.2 Optional: a retained display list (`DrawOp`) ★★

The strongest form: the view emits drawing as data, and one per-band interpreter plays it.

```java
public sealed interface DrawOp {
    record Fill(int x0, int y0, int x1, int y1, int argb) implements DrawOp {}
    record Text(Component text, int x, int y, int argb, boolean shadow) implements DrawOp {}
    record Sprite(String spriteId, int x, int y, int w, int h) implements DrawOp {}
    record Clip(int x0, int y0, int x1, int y1, List<DrawOp> children) implements DrawOp {}
    record Overlay(List<DrawOp> children) implements DrawOp {}          // = nextStratum()
}

// per-band interpreter (Java 21+ copy can switch exhaustively)
void play(List<DrawOp> ops) {
    for (DrawOp op : ops) switch (op) {
        case DrawOp.Fill(int x0, int y0, int x1, int y1, int c) -> fill(x0, y0, x1, y1, c);
        case DrawOp.Text(Component t, int x, int y, int c, boolean sh) -> text(t, x, y, c, sh);
        case DrawOp.Sprite(String id, int x, int y, int w, int h) -> sprite(id, x, y, w, h);
        case DrawOp.Clip(int x0, int y0, int x1, int y1, List<DrawOp> k) -> { pushClip(x0, y0, x1, y1); play(k); popClip(); }
        case DrawOp.Overlay(List<DrawOp> k) -> { beginOverlay(); play(k); endOverlay(); }
    }
}
```

- The interpreter is the only code that knows `GuiGraphics` vs `GuiGraphicsExtractor`, Z-translate
  vs `nextStratum()`, `RenderType` vs `RenderPipeline` vs 26.4 `GuiPipeline`.
- Rebuild the list only when the view changes; replay allocates nothing. Layer a small per-frame
  dynamic list (hover, caret, animation) on top.
- Snapshot-testable as text without a GPU (§8.2); assert `(argb >>> 24) != 0` on every op (law 1).
- Worth it for dashboard screens. A three-button config screen needs vanilla widgets +
  `GridLayout`, nothing more.

---

## 3. Version seam vs loader seam

### 3.1 Two axes ★★★

| Axis | Varies | Mechanism | Examples |
|---|---|---|---|
| **MC version** (GUI API drift) | per jar | **compile-time**: file substitution, variants, rename pass, preprocessor | `renderBg` deleted 26.1, input records 1.21.9, SDL 26.3, `GuiPipeline` 26.4 |
| **Loader** | per jar, but vanilla GUI classes are identical across loaders at one MC version | **interface + startup selection** | HUD layers, keybinds, config-screen factory, config dir, networking registration |

Almost all GUI drift is on the version axis, which is why loader-axis tools don't help with the hard
part (`libraries.md` §4).

### 3.2 The options ★★★ unless marked

| Approach | How | Use when |
|---|---|---|
| **Adapter-file fork** | `versions/<band>/` holds a same-FQN copy of a few files; build excludes the shared copy | ≤ ~5 small adapter files. Fails when whole screens get forked (a full per-band copy of the shared tree is the failure mode) |
| **Axis-variant composition** | `compat/<axis>-<variant>/` dirs hold only the differing calls; a band = a list of variants; duplicates fail the build; regex rename sets for pure renames | many bands × loaders (28 jars from ~40 small variants). Variants named by *what* changed, not by band |
| **Single static seam** (`Compat`) | one `final class Compat` of statics, two copies | a small mod with few divergences |
| **Stonecutter** (Codeberg, 0.10) | one file, comment directives: `//? if >=1.21 <26.1 {`, `//? if fabric {…//?} else if neoforge {`, replacements `//~ if >=26.1 'GuiGraphics' -> 'GuiGraphicsExtractor'`, swaps `/*$ mc_version*/` | a new mod with moderate drift. Still keep the conditionals inside the four adapters |
| **Architectury** | `common/` + loader subprojects, `@ExpectPlatform`, optional runtime API | loader axis only; architectury-loom without the API avoids the user dependency |
| **MultiLoader-Template** (jaredlll08, branch `26.3`, Java 25) | `common/` (vanilla only) + `fabric/` + `neoforge/`; `Services.load(IPlatformHelper.class)` via `ServiceLoader` | zero-dependency loader skeleton; pair with Stonecutter or adapters for versions |
| **`ServiceLoader` version adapter** (`VersionAdapter`) | interface in shared code, `…Impl` per band | non-hot-path seams you want to fake in tests. Use static substitution for drawing |

- **Load `ServiceLoader` with the interface's own classloader** (`X.class.getClassLoader()`), not
  the TCCL: under Knot / `fabric-loader-junit` the TCCL can differ and every provider becomes "not a
  subtype". MultiLoader-Template does the same. ★★★
- **No `Object`-typed seam parameters.** Move the whole call that names the version-specific type
  into the band file so shared code never names it.

### 3.3 The four GUI adapters ★★★

| Adapter | Pattern | Hides |
|---|---|---|
| `UiCanvas` | **Facade**, one shared instance per frame | `GuiGraphics` vs `GuiGraphicsExtractor`; `drawString` vs `text`; Z-translate vs `nextStratum()`; scissor; drawing children. 26.4: `GuiPipeline` |
| `KitWidget extends AbstractWidget` | **Template method**: `final` overrides forward to stable hooks (`draw`, `onPress`, `onKey`, `onChar`, `onScroll`, `narrate`) | `renderWidget` vs `extractWidgetRenderState`; raw ints vs `MouseButtonEvent`/`KeyEvent`/`CharacterEvent`; GLFW vs SDL keys; 26.3 `capturesInput()` + text-input focus |
| `KitScreenBase extends Screen` | Template method | `render` vs `extractRenderState`; `renderBackground` arity; mouse-event shape; `mouseScrolled` arity; 26.4 `update(DeltaTracker)` |
| `KitPlatform` | **Static facade** | `setScreen` vs `gui.setScreen` (26.2); `hideGui` vs `gui.hud.isHidden()`; `Util` package move (1.21.11); `Blaze3D.openUri` (26.3); narrator; clipboard; modifiers |

- Widgets stay **real `AbstractWidget`s** (law 3) but subclasses never override vanilla methods.
- Hooks **keep mouse and partial-tick parameters**: a 26.4 adapter reads `g.mouseX()/mouseY()/
  partialTicks()` from the extractor and passes them in, so content code is untouched. ★ (26.4 is
  snapshot-only)
- Scroll is routed by the screen to `onScroll`, so no adapter copy overrides `mouseScrolled`.
- Normalize input at the seam (rule 6) — sketch and rationale in §3.6.

### 3.4 Where each GUI break lands

| Break | MC | Absorbed by |
|---|---|---|
| `renderBackground` + `mouseScrolled` gain args; `blitSprite` + sprite atlas | 1.20.2 | `KitScreenBase`, `UiCanvas.sprite()` |
| `AbstractWidget#render` final; menu blur | 1.20.5 | `KitWidget` (hook already) |
| blits take `Function<Id, RenderType>` + PNG size; `setColor` gone; `ToastManager` | 1.21.2 | `UiCanvas`; toast shim |
| **deferred GUI**: no Z, ARGB mandatory, `Matrix3x2fStack`, deferred tooltips, PiP | 1.21.6 | `UiCanvas.beginOverlay` → `nextStratum()`, `pushTransform`; Strategy for previews (§4.5) |
| input event records; `Window#handle()`; static `Screen.hasShiftDown` gone | 1.21.9 | `KitWidget`, `KitScreenBase`, `KitPlatform` |
| `Identifier`; `Util` move; `AbstractButton#renderWidget` final; positional `CycleButton.builder` | 1.21.11 | rename set / `//~`; `KitPlatform` |
| `render*`→`extract*`; `GuiGraphicsExtractor`; `renderBg` deleted | 26.1 | all four adapters; container base |
| `gui.setScreen`/`gui.screen()`; `Gui`/`Hud` split; `MultiBufferSource` gone; black-frame defect | 26.2 | `KitPlatform`, `KitScreenBase` (mitigation: `render-pipeline.md` §7); HUD registration (loader axis) |
| **GLFW → SDL3**: key ints = SDL scancodes, SDL mod masks, `scancode()`→`keycode()`, `capturesInput()` + `onTextInputFocusChange(this, focused)`, `Blaze3D.openUri`, `InputConstants.REPEAT` −1; `RenderPipeline` → `com.mojang.renderpearl.api.pipeline` | 26.3 | `KitWidget` key mapper + text-input hooks; `KitPlatform`; `UiCanvas` imports |
| `GuiPipeline` in every blit/fill; no mouse/partial on any `extract*`; `Updatable.update(DeltaTracker)`; `addRenderableOnly` removed; `AbstractWidget.visible` protected (`setVisible`); `isHighlighted()`; `CycleButton extends AbstractCycleButton`; generic `Button.Builder<B>`; `SlotWidget` + `Slot.Section` containers; `KeyEvent.repeat()`; `DynamicTexture` removed; `MenuScreens` → client registry | 26.4-s8 ★★ | `UiCanvas`, `KitWidget`, `KitScreenBase`, texture strategy (§7.3), container base. **Never write `w.visible = …` in shared code** |

Sources for 26.3/26.4: the 26.2→26.3→26.4-s8 javap diff (`screen-widget-api.md`,
`render-pipeline.md`) and `minecraft-mod-expert` `api-migration-deltas.md`.

### 3.5 Loader-axis sketch (Java 17, no runtime deps) ★★★

```java
public interface ClientPlatform {
    void registerHudLayer(String id, HudLayer layer, HudOrder order);
    void registerKey(KeyMapping key);
    Path configDir();
    boolean isModLoaded(String id);
    ClientPlatform INSTANCE = ServiceLoader.load(ClientPlatform.class, ClientPlatform.class.getClassLoader())
            .findFirst().orElseThrow(() -> new IllegalStateException("no ClientPlatform"));
}
@FunctionalInterface public interface HudLayer { void draw(UiCanvas c); }   // band-neutral: no DeltaTracker
public enum HudOrder { BELOW_ALL, ABOVE_ALL }
```

Fabric maps to `HudElementRegistry.addFirst/addLast`, NeoForge to
`RegisterGuiLayersEvent.registerBelowAll/registerAboveAll` (`loader-hooks.md` §1). Because
`HudLayer` takes your canvas and no `DeltaTracker`, Fabric 26.4's `HudElement` change
(`extractRenderState(g)` + `update(DeltaTracker)`) touches only the Fabric impl. A
`Platform.set(...)` call from each entrypoint is an equally good alternative (no services file to forget).

### 3.6 Semantic input at the seam ★★★

Forwarding **raw ints** through the widget base (hooks take `(key, scancode, modifiers)`, shared code
compares against per-band `KEY_*`/`MOD_*` constants) works only because shared code is recompiled
against each band's copy, so `case KEY_ESCAPE ->` picks up that band's value (`KEY_ESCAPE` is 256 on
≤26.2 and the SDL scancode on 26.3). The encoding still leaks: a hard-coded `256`, a `mods & 1` shift
test, or a constant one band's copy lacks (keypad-minus has to come from `SDLScancode` on 26.3
because `InputConstants` has none) breaks silently on one band. SDL modifier masks are multi-bit
(shift = 3, control = 192, alt = 768), so bit tests copied from GLFW code are wrong.

Translate once, in the widget and screen adapters, into types that never change:

```java
// shared, Java 17
public enum UiKey { ESCAPE, ENTER, TAB, LEFT, RIGHT, UP, DOWN, PAGE_UP, PAGE_DOWN, HOME, END,
                    BACKSPACE, DELETE, SPACE, PASTE, OTHER }
public record KeyInput(UiKey key, int rawKey, int mods, boolean repeat) {   // mods: YOUR bit encoding
    public boolean shift() { return (mods & UiMods.SHIFT) != 0; }
}
public enum UiButton { LEFT, RIGHT, MIDDLE, OTHER }
public record PointerInput(double x, double y, UiButton button, int mods) {}

// 26.3 adapter copy: the only place SDL numbers exist
static UiKey map(int key) {
    if (key == InputConstants.KEY_ESCAPE) return UiKey.ESCAPE;
    if (key == InputConstants.KEY_RETURN || key == InputConstants.KEY_NUMPADENTER) return UiKey.ENTER;
    // …
    return UiKey.OTHER;
}
static int mods(KeyEvent e) {
    int m = 0;
    if (e.hasShiftDown()) m |= UiMods.SHIFT;            // never compare raw SDL masks
    if (e.hasControlDown()) m |= UiMods.CONTROL;
    if (e.hasAltDown()) m |= UiMods.ALT;
    return m;
}
```

- Keep `rawKey` for keybind-capture screens only.
- Map paste semantically (`UiKey.PASTE` = Ctrl+V, Cmd+V on macOS) in the adapter.
- 26.3 changed `InputConstants.REPEAT` to −1 and 26.4 adds `KeyEvent.repeat()`: carry `repeat` in
  the record so held-key behaviour never depends on action ints.
- 26.4 adds `MouseButtonEvent.isLeftMouse()` and friends, and vanilla now ignores non-left clicks for
  list selection and links. Map once to `UiButton` and apply the same rule.
- Text entry is separate from keys on SDL: a widget that wants characters must return
  `capturesInput() = true` while focused **and** call `Minecraft.onTextInputFocusChange(this,
  focused)`. Put both behind one `wantsTextInput()` hook in the 26.3 widget adapter; without it no
  `charTyped` arrives.

---

## 4. GoF patterns that pay off

### 4.1 Summary ★★★ unless marked

| Pattern | GUI use | Note |
|---|---|---|
| **Builder** | `KitButton.builder(label, onPress).bounds(…).tooltip(…).build()` mirrors vanilla `Button.builder` | compute derived state in `build()`, never in setters (the `CycleButton.withInitialValue` trap, `screen-widget-api.md` §3) |
| **Composite** | vanilla `Layout`/`GridLayout`/`LinearLayout`/`FrameLayout` (stable from 1.20.1); your own `Node.measure/place` tree | do layout math in pure Java and unit-test it |
| **Observer** | `Property<T>` for config binding | equality guard stops widget→property→widget ping-pong |
| **Command** | undo stack; confirm-as-state | prefer undo + toast over confirm for reversible local edits (`ux-principles.md` §4) |
| **Strategy** | per-band preview renderer; Iris-active vs not; Vulkan vs GL | chosen at compile time for bands, at runtime for environment |
| **Flyweight / cache** | `Font#split` / width results keyed by `(string, maxWidth)` | invalidate on reload, Force Unicode, resize (§7.4) |
| **State machine** | `sealed Route` + one `Navigator` that alone calls `KitPlatform.setScreen` | uniform Esc-goes-back; wizard steps as an enum |
| **Decorator** | "why disabled" tooltip lines; a `DebugCanvas` outlining every widget's bounds | ~30 lines when everything draws through the facade ★★ |
| **Facade / Template method** | the four adapters (§3.3) | the load-bearing pair |

### 4.2 Builder ★★★

```java
public static final class Builder {
    private final Component label; private final Runnable onPress;
    private int x, y, w = 150, h = 20; private @Nullable Component tooltip; private boolean primary;
    public Builder bounds(int x, int y, int w, int h) { this.x = x; this.y = y; this.w = w; this.h = h; return this; }
    public Builder tooltip(Component t) { this.tooltip = t; return this; }
    public Builder primary() { this.primary = true; return this; }
    public KitButton build() { return new KitButton(this); }    // derive here, not in setters
}
```

26.4 made vanilla `Button.Builder<B extends Builder<B>>` generic and `Button.builder(..)` return
`Builder<?>`: keep vanilla builder calls inside adapters or chain them without naming the type. ★★

### 4.3 Observer ★★★

```java
public final class Property<T> {
    private T value; private final List<Consumer<T>> listeners = new ArrayList<>();
    public T get() { return value; }
    public void set(T v) { if (Objects.equals(v, value)) return; value = v; for (var l : List.copyOf(listeners)) l.accept(v); }
    public AutoCloseable observe(Consumer<T> l) { listeners.add(l); l.accept(value); return () -> listeners.remove(l); }
}
```

Close handles in `removed()`. No `WeakReference` listeners for lambdas (the lambda is the only strong
ref). Persist config on `removed()` or a debounce, never on every slider drag.

### 4.4 Command ★★★

```java
public sealed interface EditCommand permits Rename, DeleteRow, MoveRow {
    void apply(Model m);
    EditCommand inverse(Model before);    // captured before apply
    Component describe();                 // "Undo: Delete 'Spawn'"
}
```

Irreversible server-side actions go through confirm **as state** (`HubState.confirm`, §1.2) and
vanilla `ConfirmScreen(BooleanConsumer, Component, Component)`; a resize then re-shows the confirm
instead of dropping it.

### 4.5 Strategy ★★★ / ★ for 26.4

```java
public interface PreviewRenderer { void draw(UiCanvas c, Rect area, PreviewSource src); }
// ≤1.21.5: immediate quad · 1.21.6+: PictureInPictureRenderer · 26.4: TextureHandle (DynamicTexture removed) ★
```

### 4.6 Anti-patterns ★★★

| Anti-pattern | Why it hurts | Instead |
|---|---|---|
| `static final Minecraft MC = Minecraft.getInstance()` reachable from common code | loads client classes on a dedicated server; null in early init | call at use site in client-only classes |
| Common signature naming `Screen`, `GuiGraphics(Extractor)`, `KeyMapping` | verification-time crash on the server | split source sets; `loader-hooks.md` §5 |
| Static caches holding `Level`, `Player`, `Screen`, textures | leaks a world across disconnects; dangling GPU resources | hold ids; clear on disconnect |
| Allocating in `render`/`extract` (`String.format`, `font.split`, lambdas) | GC churn at 60–240 fps on top of the deferred GUI's own records | precompute in the view (§2.1); cache (§4.1) |
| State in widgets (`EditBox` as source of truth) | lost on `init()` re-run | widget is a projection of the model |
| `addRenderableOnly` + hand-rolled clicks | not focusable/narrated; **removed in 26.4**; invisible to 26.4 keyboard navigation | real `KitWidget`s |
| Z-translate to layer | no Z since 1.21.6 | `nextStratum()` via `UiCanvas.beginOverlay` |
| Raw int key/mod/button literals in shared code | silently wrong on 26.3 SDL | semantic enums at the seam |
| `w.visible = false` | field protected in 26.4 | `setVisible`-style kit method |
| `@Redirect`/`@Overwrite` into vanilla screens | exclusive; conflicts | events, then MixinExtras (`libraries.md` §5) |
| Logic inside mixin bodies | merged into targets; hard to test; old-Mixin edge cases (§6) | one-line call to a static hook |

---

## 5. Java language level per band

### 5.1 Runtime and `--release` ★★★

| Bands | MC | Player's minimum JDK | Shared-tree `--release` |
|---|---|---|---|
| A | 1.20.1–1.20.4 | **17** | 17 |
| B–H | 1.20.5–1.21.11 | **21** | 21 |
| I–K, + 26.4 preview | 26.1–26.3, 26.4 snapshots | **25** | 25 |

`--release` (not `-source/-target`) also restricts the **API**: `--release 17` rejects
`List.getFirst()`. Set `options.release` per source set; a shared tree is limited by the **oldest**
band it feeds. Toolchain coordinates: `minecraft-mod-expert`.

### 5.2 Feature table

| Feature | JEP | Final in | Usable at | UI use |
|---|---|---|---|---|
| Switch expressions | 361 | 14 | 17 | enum → label/color; exhaustive over enums even on 17 |
| Text blocks | 378 | 15 | 17 | fixtures, debug dumps |
| `instanceof` patterns | 394 | 16 | 17 | reducer dispatch on 17 |
| Records | 395 | 16 | 17 | state, views, actions, `DrawOp`, `Rect` |
| Sealed types | 409 | 17 | 17 | action/effect/route hierarchies; `getPermittedSubclasses()` |
| Sequenced collections | 431 | 21 | 21 | `getFirst/getLast/reversed` for back/undo stacks |
| Record patterns | 440 | 21 | 21 | destructuring cases |
| Pattern `switch` | 441 | 21 | 21 | exhaustive reducers and interpreters |
| Virtual threads | 444 | 21 | 21 | blocking HTTP; never touch MC state; `synchronized` pins on 21–23 (fixed 24, JEP 491) |
| `Math.clamp`, `StringBuilder.repeat` | — | 21 | 21 | — |
| Unnamed `_` | 456 | 22 | 25 | `case X _ ->`, `(_, now) ->` |
| FFM API | 454 | 22 | 25 | natives without JNI (not UI) |
| Markdown doc comments `///` | 467 | 23 | 25 | — |
| Stream gatherers / Class-File API | 485 / 484 | 24 | 25 | — |

**Java 25 (LTS) — status per openjdk.org/projects/jdk/25** ★★★

| JEP | Feature | Status in 25 | Verdict |
|---|---|---|---|
| 513 | Flexible Constructor Bodies | **Final** | **Useful**: compute width/label before `super(x, y, w, h, msg)` in widget subclasses (26.x band files only) |
| 511 | Module Import Declarations | **Final** | skip: `import module` invites name ambiguity next to MC classes |
| 512 | Compact Source Files & Instance Main | **Final** | irrelevant to mods |
| 506 | Scoped Values | **Final** | possible per-frame context; a static on the single render thread is simpler |
| 519 | Compact Object Headers | **Product** (opt-in `-XX:+UseCompactObjectHeaders`) | a player JVM flag, no code impact |
| 502 | Stable Values | **Preview** | **do not use** |
| 507 | Primitive Types in Patterns | **Preview** (third) | **do not use** |
| 505 / 508 | Structured Concurrency / Vector API | preview / incubator | do not use |

**Never compile with `--enable-preview`.** Such class files carry a minor-version mark that a JVM
started without the flag refuses to load, and launchers don't pass it. ★★★

```java
// JEP 513, 26.x band file only
public StatusChip(int x, int y, Font font, Status status) {
    Component label = Component.translatable(status.key());
    int w = Math.min(font.width(label) + 2 * PAD, MAX_W);
    super(x, y, w, 12, label);
}
// Java 17/21 shared code: super(x, y, widthFor(font, status), 12, labelFor(status));
```

---

## 6. Mixin and Java 25

| Engine | Bundled | Highest `compatibilityLevel` | ★ |
|---|---|---|---|
| Fabric `sponge-mixin` fork | 0.16.0+mixin.0.8.7 **added `JAVA_23/24/25`** (0.15.x stops at `JAVA_22`); `JAVA_25` needs ASM ≥ 9.8. Fabric Loader 0.20.1 bundles 0.17.5+mixin.0.8.7, ASM 9.10.1 | `JAVA_25` | ★★★ |
| NeoForge 26.2/26.3 | sponge-mixin 0.17.4+mixin.0.8.7, MixinExtras 0.5.5 | `JAVA_25` | ★★★ |
| Forge 1.20.1 (47.x) | **Mixin 0.8.5**, ASM 9.9.1, **no MixinExtras** | `JAVA_17` | ★★★ |

- Set `"compatibilityLevel"` per band (`JAVA_17`/`JAVA_21`/`JAVA_25`). A level the loader's Mixin
  doesn't know fails at startup. ★★★
- **Keep mixin bodies to one line** that calls a static hook in an ordinary class:

```java
@Mixin(ChatScreen.class)
abstract class ChatScreenMixin {
    @Inject(method = "init", at = @At("TAIL"))
    private void mymod$init(CallbackInfo ci) { ChatHooks.afterInit((ChatScreen) (Object) this); }
}
```

  Write the logic, with whatever Java the band allows, in `ChatHooks`. This sidesteps every
  language-level caveat below.
- Enum `switch` inside a mixin method emits a synthetic `$SwitchMap` class; pattern `switch` emits
  `invokedynamic` to `SwitchBootstraps`; string concat emits indy `StringConcatFactory`. Modern
  Mixin handles these; an older bundled Mixin (Forge 1.20.1's 0.8.5) is where such things break. ★
- Targeting vanilla **records** (26.x: `KeyEvent`, `MouseButtonEvent`, render states): `@Inject` into
  their methods works; added fields are not record components (`equals`/`toString` ignore them).
  Use accessor methods, not the private final fields. ★★

---

## 7. Threading and lifecycle

### 7.1 Threads ★★★

| Thread | Runs | You may |
|---|---|---|
| Client main = render thread | client tick (20 Hz), frames (`render`/`extract`, 26.4 `update`), input, `setScreen` | everything client-side |
| Netty I/O | packet decode | nothing with game state. Fabric ≥1.20.5 / NeoForge ≥20.6 run payload handlers on main by default ★★; **Fabric 1.20.1 handlers run on Netty** → `client.execute(…)`; Forge 1.20.1 `ctx.get().enqueueWork(…)` |
| Integrated server | server tick | never reach in from GUI code; send a packet even in SP |
| `Util.backgroundExecutor()`/`ioPool()` | vanilla pools | prefer your own (`Util` moved at 1.21.11; don't starve chunk work) |
| Your executor / virtual threads | HTTP, file I/O, image decode, JSON | pure work only |

### 7.2 Async → GUI ★★★

```java
private static final ExecutorService IO = Executors.newFixedThreadPool(2, r -> {
    Thread t = new Thread(r, "mymod-io"); t.setDaemon(true); return t; });   // Java 17-safe

@Override public void accept(HubEffect e) {
    if (e instanceof HubEffect.FetchServers f) {
        CompletableFuture.supplyAsync(() -> api.servers(f.query()), IO)
            .orTimeout(10, TimeUnit.SECONDS)
            .handleAsync((rows, err) -> {                       // Minecraft is a BlockableEventLoop = Executor
                store.dispatch(err == null ? new HubAction.ServersLoaded(f.reqId(), rows)
                                           : new HubAction.ServersFailed(f.reqId(), "hub.error.network"));
                return null;
            }, Minecraft.getInstance());
    }
}
```

- **Request ids in state** make late responses harmless after refresh, tab switch or close;
  `future.cancel` is best-effort, the id check is the guarantee.
- **Never `join()`/`get()` on the render thread** — a network stall becomes "not responding".
- Errors carry a **lang key**; build `Component`s on the client thread.

### 7.3 Textures from async data ★★★ rules / ★ 26.4 shape

1. Off-thread: download, decode to `NativeImage` (CPU memory), resize.
2. Hop to the client thread; create/upload the GPU texture there. Since 1.21.5 `GpuDevice`/
   `CommandEncoder` calls are render-thread-only; under 26.2+ Vulkan an off-thread call is undefined
   behaviour, not "works on my machine".
3. Register the new texture, then close the old one; close the `NativeImage` once uploaded
   (`DynamicTexture` takes ownership on ≤26.3).
4. Release in `removed()` or on cache eviction, never in a finalizer.
5. Put creation behind a band seam (`TextureSink.upload(id, NativeImage)`): 26.4 removes
   `DynamicTexture`/`AbstractTexture` for `TextureHandle` + `TextureManager.register(Identifier,
   TextureResources)`. ★
6. Per-frame streams: drain decoded frames at the **start** of the HUD pass (`addFirst` /
   `registerBelowAll`, `loader-hooks.md` §1) so every later sampler sees the same frame.

### 7.4 Lifecycle hooks ★★★

| Hook | Use |
|---|---|
| `init()` / your `buildBase()` | build widgets from state; subscribe |
| `repositionElements()` | layout-only resize, keeps widget identity and focus |
| `tick()` (20 Hz) | timers, cursor blink. 26.4 adds `update(DeltaTracker)` before every extract: per-frame time/hover logic goes there ★★ |
| `removed()` | unsubscribe, cancel futures, release textures, persist dirty config. Fires on close **and** on replacement |
| `onClose()` | navigation only (NeoForge patches it to `popGuiLayer()`); not the only cleanup point |
| disconnect event | clear per-world stores and caches |
| client reload listener | bump cache generations (fonts, sprites, language). Fabric `ResourceManagerHelper…registerReloadListener` on older bands; NeoForge `RegisterClientReloadListenersEvent` / `AddClientReloadListenersEvent` (name varies by version) ★ |

---

## 8. Testing layers

| Layer | Tool | What goes here | Bands | ★ |
|---|---|---|---|---|
| 1 | plain JUnit 5 | reducers, view builders, layout math, scroll/popover models, text fitting (with a `TextMeasure` stub), undo stacks, routes | all | ★★★ |
| 1½ | golden-text `DrawOp` snapshots | layout regressions, missing alpha | all | ★★ |
| 2 | `fabric-loader-junit` | `Component` building, codec round-trips, anything needing MC classes (call `SharedConstants.tryDetectVersion(); Bootstrap.bootStrap();` in `@BeforeAll`) | Fabric, all | ★★★ |
| 2 (NeoForge) | MDG `neoForge { unitTest { enable(); testedMod = mods.<id> } }` (junit-fml) | same, in an FML environment | NeoForge | ★ |
| 3 | **Fabric client game tests** (`fabric-client-gametest-api-v1`) | real screens, clicks, screenshots | 1.21.4+ | ★★★ |
| 3 (fallback) | scripted dev client + `Screenshot.grab` + CI diff | the same, by hand | pre-1.21.4, NeoForge | ★★★ |
| server | vanilla GameTest | menu / `quickMoveStack` logic | all | ★★ |

(`libraries.md` §6 covers preview/hot-reload tooling.)

### 8.1 Pure JUnit ★★★

```java
@Test void staleResponseIsDropped() {
    Next r1 = step(HubState.initial(), new HubAction.Refresh());          // req 1
    Next r2 = step(r1.state(), new HubAction.Refresh());                  // req 2
    Next late = step(r2.state(), new HubAction.ServersLoaded(1, List.of(ROW)));
    assertInstanceOf(Load.Loading.class, late.state().servers());        // req 1 ignored
}
@Test void everyActionIsHandled() {                                      // Java 17 exhaustiveness backstop
    for (Class<?> c : HubAction.class.getPermittedSubclasses())
        assertDoesNotThrow(() -> step(HubState.initial(), sample(c)), c.getSimpleName());
}
```

### 8.2 Fabric client game tests ★★★

- Entrypoint `fabric-client-gametest` (in `src/gametest/resources/fabric.mod.json`); class implements
  `FabricClientGameTest#runTest(ClientGameTestContext)`.
- Gradle: `fabricApi { configureTests { createSourceSet = true; modId = "…"; enableClientGameTests =
  true; eula = true } }`; run `runClientGameTest`; CI `runProductionClientGameTest` (remapped jar,
  catches refmap bugs).
- `ClientGameTestContext`: `waitTick(s)`, `waitFor`, `waitForScreen`, `setScreen`,
  `clickScreenButton(key)`, `takeScreenshot`, **`assertScreenshotEquals`**, `assertScreenshotContains`,
  `getInput()`, `worldBuilder()`, `restoreDefaultGameOptions()`, `runOnClient`/`computeOnClient`.

```java
public final class HubScreenClientTest implements FabricClientGameTest {
    @Override public void runTest(ClientGameTestContext ctx) {
        ctx.restoreDefaultGameOptions();
        ctx.computeOnClient(mc -> { mc.options.guiScale().set(2); return null; });
        ctx.setScreen(() -> new HubScreen(null, TestStores.hubWith(FIXTURE)));
        ctx.waitForScreen(HubScreen.class);
        ctx.assertScreenshotEquals(TestScreenshotComparisonOptions.of("hub_discover").withSize(854, 480));
        ctx.clickScreenButton("hub.tab.friends");
        ctx.waitTicks(2);
        ctx.assertScreenshotContains("friends_empty_state");
    }
}
```

Determinism: fixed GUI scale and window size, default options, no network (fake store/effects),
an injectable clock (a `KitClock`), and **one template set per band group** — 1.21.6's
renderer, 26.2's Vulkan backend and 26.3's tooltip-gap change all differ pixel-wise. On 26.x test
both Vulkan and OpenGL. CI: Xvfb on Linux; the known GitHub Actions flake needs
`-Dfabric.client.gametest.disableNetworkSynchronizer=true`; upload
`build/run/clientGameTest/screenshots`.

---

## 9. Could not verify

- **NeoForge ModDevGradle `unitTest { … }` block** (name, `testedMod` property, junit-fml artifact)
  — recalled, not checked against a current MDG release. ★
- **Client reload-listener registration names per band**: Fabric's resource-loader API surface on
  26.x, and NeoForge `RegisterClientReloadListenersEvent` vs `AddClientReloadListenersEvent` — which
  version renamed which. ★
- **Mixin and javac synthetics**: whether Forge 1.20.1's Mixin 0.8.5 actually mis-handles enum
  `$SwitchMap` classes, `SwitchBootstraps` indy or `StringConcatFactory` indy inside mixin method
  bodies. Recalled as a risk class, not reproduced. The one-line-hook rule (§6) makes it moot.
- **Netty vs main-thread payload handling defaults** per loader version (§7.1 ★★ rows).
- **26.4 shapes** (`GuiPipeline` mapping from `RenderPipelines`, `TextureHandle`/`TextureResources`,
  `MenuScreens` client registry, Fabric/NeoForge 26.4 hooks): read from the s7/s8 jars and draft
  primers; no 26.4 release, NeoForge 26.4 build or Fabric 26.4 post exists yet.
- **Stonecutter 0.10 directive edge cases** (nested conditions, replacement ordering) — syntax read
  from the README only.
- **JDK 26 "Lazy Constants"** as the continuation of JEP 502 — still preview; not re-checked.
