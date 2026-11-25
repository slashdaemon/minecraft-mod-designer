# UI library & overlay ecosystem — decision table

Versions re-verified **2026-11-11** against Modrinth API, Maven metadata and GitHub source (★★★
unless marked). Coverage: through 26.3 (band K) plus 26.4-snapshot-8 (L, preview). Library
versions move; **re-verify from Maven, not from documentation** — several of these projects have
badly stale docs and dead GitHub Releases pages while the artifacts themselves are current.

**26.4 reality check:** of the libraries below, only **Mod Menu** (22.0.0-alpha.4, s8) and **YACL**
(3.9.10, s7, Fabric only) have 26.4 builds, plus GuideME (alpha, NeoForge-tagged). No NeoForge 26.4
exists, and none of Sodium, Iris, JEI, REI or ImmediatelyFast has a 26.4 build. Modrinth had **86**
mods tagged `26.4-snapshot-8`. Plan 26.4 work as Fabric-only, vanilla-widget-based, preview.

---

## 0. Decision table

| Need | Use | Bands / loaders | Dependency weight |
|---|---|---|---|
| **Config screen, Fabric+NeoForge, one codebase, modern bands** | **YACL 3.9.7** (26.1/26.2/26.3, F+N) / **3.8.2** (1.21.x) / 3.9.10 (26.4 snapshots, **Fabric only**) | 1.20.1→26.3 (+26.4 preview); fabric + neoforge; **forge 1.20.1 only** | hard dep, **do not JiJ** (author's explicit advice) |
| **Config screen, NeoForge-only, zero deps** | **NeoForge built-in `ConfigurationScreen`** | NeoForge **21.0+** (MC 1.21+), all bands; 26.3 gates on `Type.SYNCED` | **zero** — in-loader |
| **Config screen, Forge 1.20.1** | **Cloth Config 11.1.136+forge**, or `ModConfigSpec` + Configured | 1.20.1 forge/fabric | hard dep; LGPL-3.0 |
| **Config, widest historical reach** | **Cloth Config** (26.3.159 / 26.2.155 / 21.11.153 / 15.0.140 / 11.1.136) | 1.14→26.3; fabric+forge+neoforge; no 26.4 | hard dep, **LGPL-3.0-only** |
| **Config, tiny footprint** | **MidnightLib 1.10.0** (1.21.1→26.3, same version everywhere) / 1.9.3 (1.20.1) | 1.20.1→26.3; fabric/neoforge/quilt (+forge 1.20.1); **MIT** | tiny, JiJ-able |
| **Config, annotation/class-based, all loaders** | **Fzzy Config 0.7.7** (26.3: 0.7.7+fix3) | 1.20.1→26.3; fabric + neoforge (+forge 1.20.1); TDL-M licence | hard dep; now mainstream (44M downloads) |
| **Forge-style `ModConfigSpec` on Fabric** | **Forge Config API Port 26.3.1 / 26.2.1 / 26.1.5 / 21.11.1** | 1.20.1→26.3; fabric+forge+neoforge; MPL-2.0 | JiJ-able. ⚠ LOCAL/SYNCED mapping on 26.3 unverified |
| **Rich declarative/custom UI** | **owo-ui** (owo-lib 0.13.1) | ⚠ **no 26.3 build** (stops at 26.2); Fabric/Quilt on 1.21.11–26.2 | MIT → JiJ-able, or `owo-sentinel` |
| **Vanilla-styled widget/option screens** | **SpruceUI 12.0.0+26.3** | 1.21.8→26.3; Fabric | JiJ via `include()`; pulls `yumi-mc-foundation` |
| **Container GUIs without pixel-aligning textures** | **LibGui 18.0.1+26.3-rc-2** (no final-tag 26.3 build) / 17.0.0+26.2 | 1.21.5→26.3; **Fabric only**; MIT | bundle it (`modImplementation include(...)`) |
| **Mods-list entry (Fabric)** | **Mod Menu 21.0.0** (26.3) / 20.0.3 (26.2) / 22.0.0-alpha.4 (26.4-s8) | Fabric/Quilt only, 1.14→26.3 (+26.4 preview) | optional dep + `modmenu` entrypoint |
| **Mods-list entry (NeoForge/Forge)** | NeoForge 26.2+ built-in screen (`iconFile`/`bannerFile`, see `loader-hooks.md` §6); **Catalogue 1.12.3** (26.3 back to 1.20.1; no Forge since 26.1.2) + **Configured 2.7.6** (≤26.2) | 26.3 back to 1.20.1 | end-user mods — nothing to link against |
| **Client-side config screen library (new)** | **MezzConfigGUI** (new, by mezz, MIT) `mc26.3-0.6.3` [beta] / 0.5.x older bands | 1.20.1→26.3; fabric + neoforge (+forge 1.20.1/1.21.1) | young (first published 2026-09-16); watch, don't depend yet ★ |
| **Multi-loader abstraction** | **Architectury API 22.0.5** (26.3) / 21.1.12 (26.2) | 1.20.1→26.3; fabric+neoforge (+forge ≤1.20.1); LGPL-3.0 | hard runtime dep — see §4 |
| **Recipe-viewer integration, all modern bands** | **JEI** 31.17.0.109 (26.3) | 1.20.1→26.3; fabric+neoforge (+forge on 1.20.1/1.21.1); MIT; no 26.4 published | `compileOnly` api artifact |
| **Recipe viewer, Fabric-first** | **REI 26.3.824** | 1.20.1→26.3; **NeoForge builds are beta-channel**; no 26.4 | `compileOnly` api artifact |
| **EMI integration** | **only if targeting ≤1.21.1** | ⚠ **frozen at 1.1.24 / MC 1.21.1** | see §3 |
| **In-game guidebook, modern bands** | **Modonomicon 26.3-2.20.1** | 1.21→26.3; all three loaders; MIT | hard dep |
| **In-game guidebook, NeoForge tech mods** | **GuideME** 26.3.7-alpha (AE2's guidebook lib) | NeoForge/Forge only; 1.20.1→26.3 (+26.4 alpha) | rising (3.3M dl); alpha on 26.x |
| **In-game guidebook, 1.20.1/1.21.1** | **Patchouli** (1.20.1-85 / 1.21.1-93) | ⚠ **gap: no 1.21.2–1.21.11, no 26.2/26.3**; CC-BY-NC-SA | hard dep; NC license |
| **Controller support in custom screens** | **Controlify 3.5.3+mc26.3** (LGPL-3.0+, F+N) — see §3 "Controller support"; Controllable 0.26.2+26.3; MidnightControls 1.12.1 (≤26.2) | Controlify current through 26.3; 26.4 only as Patreon builds | optional soft-dep |
| **Zero-dep vanilla screens** | vanilla `Screen` + `GuiGraphics(Extractor)` + `GridLayout`/`LinearLayout` | all bands, all loaders | **zero** |

**Rule of thumb for a 1.20.1 → 26.x multi-loader mod:** YACL for the config screen everywhere, with
NeoForge's built-in `ConfigurationScreen` as the zero-dep fallback on NeoForge; Cloth Config only if
you must also serve Forge 1.20.1 users who already have it. On NeoForge 26.3, remember the config
types are now `LOCAL`/`SYNCED` (see `loader-hooks.md` §4.5). Avoid making a lagging library
(owo-lib, Configured, Patchouli, EMI; §7) a hard dependency on any band you plan to carry forward.

---

## 1. The exclusion-zone contract — the top UX bug

**API stability (2026-11-11)** ★★★: JEI's `mezz.jei.api.gui.handlers` (`IGuiContainerHandler`,
`IGlobalGuiHandler`, `IScreenHandler`) and `IGuiHandlerRegistration` are byte-identical on the 26.2,
26.3 and 26.4 branches; REI's `ExclusionZones`, `ExclusionZonesProvider`, `ScreenRegistry`,
`DefaultPotionEffectExclusionZones` and `DefaultRecipeBookExclusionZones` are identical on 26.2 and
26.3. The code below ports unchanged.

**This is the most important section in this file.** A mod with side-tabs that doesn't declare
exclusion zones gets its tabs covered by the recipe viewer's item list. Implement all three, guard
each behind a mod-loaded check, and keep the rectangle math in **one shared helper** — the APIs differ
only in the rectangle type and the registration call.

**JEI** — per-screen or global:

```java
@JeiPlugin
public class MyJeiPlugin implements IModPlugin {
    @Override public ResourceLocation getPluginUid() {
        return ResourceLocation.fromNamespaceAndPath("mymod", "jei");
    }
    @Override public void registerGuiHandlers(IGuiHandlerRegistration reg) {
        reg.addGuiContainerHandler(MyScreen.class, new IGuiContainerHandler<MyScreen>() {
            @Override public List<Rect2i> getGuiExtraAreas(MyScreen s) {
                return List.of(new Rect2i(s.getGuiLeft() - 28, s.getGuiTop(), 28, 100)); // side tabs
            }
        });
        reg.addGlobalGuiHandler(myGlobalHandler);   // for non-container screens JEI would ignore
    }
}
```
Use `addGenericGuiContainerHandler` when your screen class uses Java generics — the plain method hits
type-inference problems. Multiple handlers per screen class are allowed.

**REI** — note `me.shedaniel.math.Rectangle`, not `Rect2i`:

```java
public class MyREIPlugin implements REIClientPlugin {
    @Override public void registerExclusionZones(ExclusionZones zones) {
        zones.register(MyScreen.class, screen -> List.of(
            new Rectangle(screen.getXOffset() - 28, screen.getYOffset(), 28, 100)));
    }
}
```

**EMI**:

```java
public class MyEmiPlugin implements EmiPlugin {
    @Override public void register(EmiRegistry registry) {
        registry.addExclusionArea(MyScreen.class, (screen, consumer) ->
            consumer.accept(new Bounds(x, y, w, h)));
        // registry.addGenericExclusionArea(...) for all screens
    }
}
```
Entrypoint: `"emi"` in `fabric.mod.json` on Fabric/Quilt; `@EmiEntrypoint` on Forge/NeoForge.

> Also register a screen-bounds provider (`addScreenBoundsProvider` / `addGuiScreenHandler`) if your
> screen is **not** an `AbstractContainerScreen`, or the viewers won't know where your GUI is at all.

---

## 2. Config UI libraries

### YACL (YetAnotherConfigLib) — the current community default

`3.9.7+26.3` / `+26.2` / `+26.1` (Fabric + NeoForge; 3.9.7 = "Port to 26.3, fix reset button being
small") · `3.9.10+26.4-fabric` (26.4-snapshot-7, **Fabric only** — no NeoForge 26.4 exists) ·
`3.8.2+1.21.11` / `+1.21.6` / `+1.21.4` / `+1.21.1` · `3.6.6+1.20.1` (Fabric/Forge). 120M downloads.
**LGPL-3.0-or-later.** Dropped the `quilt` tag on 26.3.

Forge (LexForge) is **frozen at 1.20.1 by policy** — the README says it will not be supported past
that; port to NeoForge. The docs explicitly discourage jar-in-jar ("it is likely already in the user's
mod folder and will significantly increase the size of your JAR") — treat it as a hard, user-installed
dependency.

```groovy
repositories { maven { name = "Xander Maven"; url = "https://maven.isxander.dev/releases" } }
dependencies {
    modImplementation "dev.isxander:yet-another-config-lib:3.9.7+26.3-fabric"
    modImplementation "dev.isxander:yet-another-config-lib:3.9.7+26.3-neoforge"
    compileOnly fg.deobf("dev.isxander:yet-another-config-lib:3.6.6+1.20.1-forge")
}
```
One artifact id; the loader lives in the **version string**. For Architectury projects use the
**fabric** artifact in `common` — there is no dedicated common artifact.

```java
YetAnotherConfigLib.createBuilder()
    .title(Component.literal("My Mod"))
    .category(ConfigCategory.createBuilder()
        .name(Component.literal("Settings"))
        .group(OptionGroup.createBuilder()
            .name(Component.literal("General"))
            .option(Option.<Boolean>createBuilder()
                .name(Component.literal("Enable Feature"))
                .binding(true, () -> config.enabled, v -> config.enabled = v)
                .controller(TickBoxControllerBuilder::create)
                .build())
            .build())
        .build())
    .build()
    .generateScreen(parentScreen);
```

### NeoForge built-in `ConfigurationScreen` — yes, it largely obsoletes Cloth/YACL on NeoForge

Introduced **NeoForge 21.0 (MC 1.21)**; present in every band since. One line, zero dependencies:

```java
modContainer.registerExtensionPoint(IConfigScreenFactory.class, ConfigurationScreen::new);
```

It parses your registered `ModConfigSpec`s and populates the screen automatically. Requirements and
quirks: `defineList()` needs the extra "new element default" parameter so the GUI can add entries;
translation keys via `ModConfigSpec.Builder#translation`, convention `<modid>.configuration.<path>`;
**walking every config page then backing out prints all untranslated entries to console** — a free
QA pass. Server configs (26.3+: `SYNCED`) are only editable in a local single-player world; on
26.3 the gating tests `ModConfig.Type.SYNCED`, and the `/config` command is gone.

**Verdict:** if you're NeoForge-only, use it. NeoForge's own docs concede it "isn't quite as capable
or pretty" as the libraries, "but it is built-in and available for all mods all the time." Reach for
YACL when you need custom controllers, images, search, or a designed layout.

### Cloth Config

`26.3.159` (26.3, F+N) / `26.2.155` / `26.1.154` / `21.11.153` / `15.0.140` (1.21.1) / `11.1.136`
(1.20.1). No 26.4 build. 165M downloads. **LGPL-3.0-only** — the practical blocker on jar-in-jar for a closed-source or commercial
mod. No NeoForge build for 1.20.1.

```groovy
repositories { maven { url "https://maven.shedaniel.me/" } }
dependencies {
    modApi("me.shedaniel.cloth:cloth-config-fabric:26.3.159") { exclude group: "net.fabricmc.fabric-api" }
    implementation "me.shedaniel.cloth:cloth-config-neoforge:26.3.159"
    api fg.deobf("me.shedaniel.cloth:cloth-config-forge:11.1.136")   // Forge 1.20.1
}
```

⚠ **The GitBook docs are stale** — the version table stops at "v11 — supports 1.20.x" and the NeoForge
setup page 404s. The mod is current; only the documentation is stalled. Get versions from Maven.

### Others

| Library | Status |
|---|---|
| **owo-lib / owo-ui** | ⚠ **no 26.3 build**: Modrinth and maven.wispforest.io stop at `0.13.1+26.2` (Fabric/Quilt); issue #503 "Update to Minecraft 26.3" open. NeoForge: `0.12.15.6-beta.1+1.21` for 1.21.1 appeared 2026-10-16; otherwise stalled at 0.12.28 / 1.21.10 — Modrinth's project-level `neoforge` tag is misleading; verify per-version. A `braid-ui` branch (new UI layer, KDL widgets) exists; its release plans are unknown. MIT. `owo-sentinel` exists so you needn't bundle it |
| **Forge Config API Port** | `26.3.1` / `26.2.1` / `26.1.5` / `21.11.1` / `8.0.3` (1.20.1), published for **fabric, forge AND neoforge**. MPL-2.0. This is what makes "write `ModConfigSpec` once, render with NeoForge's `ConfigurationScreen` on NeoForge and Configured/Cloth on Fabric" viable. ⚠ Whether 26.3.1 maps COMMON/SERVER onto NeoForge's renamed LOCAL/SYNCED was not verified — check before relying on it |
| **MidnightLib** | `1.10.0`, released for every band 1.21.1 → 26.3 the same day (F/N/Q); `1.9.3` F / `1.9.2` Forge on 1.20.1. MIT; smallest option. ⚠ GitHub **Releases are abandoned** (last tag 2023) — releases go to Modrinth/CurseForge only |
| **Fzzy Config** (new to this file) | `0.7.7` across 1.20.1 → 26.3 (`0.7.7+fix3` on 26.3, F+N; Forge on 1.20.1). TDL-M licence, 44M downloads: a mainstream all-loader config option now (★ judgement). Dropped the `quilt` tag on 26.3 |
| **Resourceful Config** | `6.0.2` (26.3, F+N); a major version per MC version (`5.0.1` 26.2, `3.0.11` 1.21.1). MIT. Maven artifact `resourcefulconfig-fabric-26.3` |
| **Puzzle** | `2.3.1` (26.3, F/N/Q). MIT |
| **MezzConfigGUI** (new, by mezz) | "Client-side config screen for Minecraft mods". `mc26.3-0.6.3` F+N [beta]; `0.5.x` on 26.2 back to 1.20.1 (+Forge). MIT. First published 2026-09-16, ~70k downloads. Young: watch rather than depend ★ |
| **Configured / Catalogue** (MrCrayfish) | Configured **`2.7.6+26.2`** (GitHub), **no 26.3 build** and no `multiloader/26.3` branch. Catalogue **`1.12.3+26.3`** (F+N); no Forge artifacts from 26.1.2 on. **End-user mods, not compile-time deps** — Configured auto-generates a menu from any `ModConfigSpec` with no code from you. ⚠ **Neither is on Modrinth**: the Modrinth slug `configured` is an unrelated mod by another author. Get them from GitHub/CurseForge. NeoForge 26.2+ ships its own overhauled mods screen, which reduces Catalogue's role there |
| **SpruceUI** | `12.0.0+26.3` / `11.0.1+26.2`; Fabric; vanilla-looking option screens. ⚠ GitHub Releases dead (last tag 2020) and branch READMEs stale — **Maven (`maven.gegy.dev`) is the source of truth**. Pulls `yumi-mc-foundation` as a second dep |
| **LibGui** | `18.0.1+26.3-rc-2` (no build against the final 26.3 tag) / `17.0.0+26.2`; **Fabric only**; MIT; 18px-grid synced container GUIs with layout instead of background-texture alignment. ⚠ README maven badge points at the dead `server.bbkr.space`; live maven is `https://staging.alexiil.uk/maven/` |
| **MaLiLib** | `0.30.2` (26.3), `0.29.6` (26.2), extremely active, **Fabric only** on modern bands, LGPL-3.0. Realistically masa's own framework for Litematica/MiniHUD/tweakeroo — **no third-party dev docs. Don't adopt it** unless you're writing a masa-adjacent utility mod |
| **Quilt Config / QSL** | ⚠ **QSL, QKL and Quilted Fabric API officially retired at MC 26.1** (2026-02-03). Quilt Loader continues (0.30.2 stable). Keep the `quilt` loader tag only if tested; don't build new UI on QSL |
| **ModernUI-MC** | `3.13.0.5`, MC 26.1–26.1.2, all three loaders, LGPL. **No 26.2 or 26.3 build** on Modrinth. A genuine UI framework + text/font engine — but heavy, with its own render stack, and now lagging. Niche |
| **Lavender** (owo docs) | `0.1.15` (1.21.1) max; effectively stale |
| **MineGui** (imgui-java) | **dev-tool grade** — inspectors and live tweakers, not shippable UI |
| **WebGUI** | loads React/Vue/Svelte inside Minecraft. Novel, unproven — don't bet a product on it |

**Nothing has displaced owo-ui / LibGui / SpruceUI, and there is no 2026 breakout UI framework, but owo-ui and ModernUI now lag (no 26.3). For config screens, Fzzy Config joined YACL/Cloth as a mainstream choice.**

---

## 3. Recipe viewers and overlays

| Mod | Current | Notes |
|---|---|---|
| **JEI** | `31.17.0.109` (26.3, F+N) · `30.48.0.244` (26.2) · `29.53.0.115` (26.1.x) · `27.54.0.116` (1.21.11) · `24.2.0.6` (1.21.8) · `19.70.0.469` (1.21.1, F/Fg/N) · `15.74.0.234` (1.20.1, F/Fg). **26.4: none published** (a `26.4` branch targets snapshot-6). MIT | fabric + neoforge on modern bands; **forge** only on 1.20.1 and 1.21.1. All Modrinth channels are `beta` — normal for JEI, not a warning. ⚠ Modrinth's version filter returns nothing for `1.21.8 + fabric` but `mezz.jei:jei-1.21.8-fabric:24.2.0.6` **does** exist — **trust Maven over the Modrinth tags**. ⚠ **No `jei-26.3-core` artifact** (26.2 had `jei-26.2-core`) |
| **REI** | `26.3.824` (Fabric `release` / NeoForge `beta`) · `26.2.820` (Modrinth) / `.821` (maven) · `26.1.819` · `21.11.816` · `16.0.799` (1.21.1) · `12.1.785` (1.20.1). No 26.4 branch. MIT | ⚠ **NeoForge builds ship on the `beta` channel** across every band; Fabric ships `release`. REI is Fabric-first — **on NeoForge, JEI is the safer bet**. 1.21.1 untouched since 2025-02, 1.20.1 since 2024-10 |
| **EMI** | ⚠ **`1.1.24`, 2026-05-13, MC 1.21.1 max.** No 1.21.4+; repo branches stop at `1.21`, though commits continue (JEMI tag-category hiding, `neoforge:compostables`, locales). Port issue #1111 ("Port to 1.21.11") is **closed** (2026-02-13) without a port. Its documented maven (`repo.sleeping.town`) is stalled even further at `1.1.0+1.20.4` — **you cannot compile against current EMI from the README** | An unofficial MIT fork exists for 26.1/26.2 but is ~2.2k downloads and self-labelled *unstable*. **Decision:** on 1.20.1/1.21.1 write an `EmiPlugin` — cheap, and EMI users are loyal. On 1.21.4+ don't, and don't advertise EMI support |

```groovy
repositories { maven { url "https://maven.blamejared.com" } }
dependencies {
    compileOnly "mezz.jei:jei-26.3-common-api:31.17.0.109"
    compileOnly "mezz.jei:jei-26.3-neoforge-api:31.17.0.109"
    runtimeOnly "mezz.jei:jei-26.3-neoforge:31.17.0.109"
}
```
Published 26.3 artifacts: `jei-26.3-{common-api,fabric-api,neoforge-api,common,fabric,neoforge,gui,lib}`.

**JEI features worth knowing:**
- **26.4 branch: context-aware ingredient tooltips** ★★★ (commit "Require context-aware tooltips…",
  2026-11-03, unreleased). `IIngredientRenderer.getTooltip(T, Item.TooltipContext, @Nullable Player,
  TooltipFlag)` becomes the abstract method and the old `(T, TooltipFlag)` overload becomes the
  default. A custom ingredient renderer must implement the context-aware form on 26.4. The 26.2 → 26.3
  API diffs are in recipe layout/widgets/config, plus an `IModPlugin` method re-tagged
  `@Deprecated(since="31.1.0", forRemoval=true)`; the gui-handler API is unchanged.
- **Ghost-slot drag-and-drop** — `IGhostIngredientHandler<T extends Screen>` via `addGhostIngredientHandler`.
  `getTargetsTyped(gui, ingredient, doStart)` is called **twice** (hover with `doStart=false`, pickup
  with `true`); `Target` = `Rect2i getArea()` + `accept(I)`. **New in 29.1.0:** `quickMove(gui, ing)`
  for shift-click ghost moves.
- **Clickable areas** — `IGuiClickableArea` (gui-relative coords) or the one-liner
  `addRecipeClickArea(screenClass, x, y, w, h, recipeTypes...)`.
- Recent `IModPlugin` additions: `configureJei(IJeiFeatures)` (30.14.0, incl. `disableJeiGui()`),
  `registerSlotDisplayInterpreters` (30.20.0), `registerAdvancedSearch` (30.10.0),
  `registerIngredientAliases` (19.10.0).

**Why EMI's UX is praised** (still worth copying even though you may not integrate): recipe **trees**
rather than one recipe at a time; a crafting-tree flow that resolves what you can actually make from
inventory; sidebars exclusion-aware by default; strong keyboard behaviour; and **JEI-plugin
compatibility**, so mods that only wrote a JEI plugin still appear. Its `EmiStack`/`EmiIngredient`
model is a cleaner abstraction than JEI's `ITypedIngredient` for "any of these, in this amount."

### Mod Menu metadata (Fabric/Quilt only)

`21.0.0` (26.3) · `22.0.0-alpha.4` (26.4-snapshot-8; alphas on maven `com.terraformersmc:modmenu`) ·
`20.0.3` (26.2) · `18.0.2` (26.1.x) · `17.0.1` (1.21.11) · `11.0.5` (1.21.1) · `7.2.2` (1.20.1). MIT.
**No Forge/NeoForge build has ever existed** — the equivalent there is Catalogue, or NeoForge 26.2+'s
built-in mods screen. ★★★ The `custom.modmenu` keys and `ModMenuApi` (`getModConfigScreenFactory`,
`getUpdateChecker`, `getProvidedConfigScreenFactories`, `getProvidedUpdateCheckers`,
`attachModpackBadges`, `createModsScreen`, `createModsButtonText`) are **identical on the 26.2, 26.3
and 26.4 branches**; 21.0.0 → 22.0.0-alpha.4 notes are ports, translations, "reset config when
malformed", contributor homepage links and longer versions in the compact list.

```json
"custom": { "modmenu": {
  "links": { "modmenu.discord": "https://discord.gg/..." },
  "badges": ["library", "deprecated"],
  "parent": { "id": "example-api", "name": "Example API", "icon": "assets/.../parent_icon.png" },
  "update_checker": true
}},
"entrypoints": { "modmenu": ["com.example.mod.ExampleModMenuApiImpl"] }
```
**Valid badges are `library` and `deprecated` only** (`Client` is added automatically); anything else
is ignored and custom badges are unsupported. Any key in `links` is used as a translation key.
There is also a translation API needing **no Java at all**: `modmenu.nameTranslation.<modid>`,
`.summaryTranslation.`, `.descriptionTranslation.`.

### Coexistence with HUD mods

- **Xaero's Minimap** `26.6.2` (26.3; fabric/forge/neoforge) and **JourneyMap** `26.3-6.0.10` are both
  **All-Rights-Reserved** — no vendoring, no forking. Neither has a 26.4 build. There is **no
  exclusion-zone equivalent for minimaps**; configurable anchoring is the whole answer. Keep out of the
  corners they occupy by default (Xaero top-left, JourneyMap top-right) and make your anchor
  configurable to all four corners plus offsets.
- **BetterF3** `20.0.0` (26.3, F/N/Q, MIT) replaces the F3 overlay wholesale — any mixin into
  `DebugScreenOverlay` will collide with it. Use the loader HUD events instead. Vanilla 26.4 also
  redesigned F3 into groups/facts/columns with a client registry of entries, so F3 mixins break there
  regardless.

### Controller support

**Vanilla has no gamepad support** on 26.3 or 26.4-snapshot-8 ★★★: SDL3 is initialised with VIDEO
only, and neither jar references SDL's Gamepad/Joystick/Haptic APIs. Vanilla 26.4-snapshot-7's
keyboard navigation of container screens is Mojang's stated "first step" towards accessibility, not
controller support. Controller play remains a mod's job:

| Mod | Status (2026-11-11) |
|---|---|
| **Controlify** (LGPL-3.0+) | `3.5.3+mc26.3` F+N; 26.4 only as Patreon-gated snapshot builds (`port/26.4` branch). The de facto choice on 26.x |
| **Controllable** (MrCrayfish) | `0.26.2+26.3` (GitHub; not on Modrinth) |
| **MidnightControls** (MIT) | `1.12.1+26.2` max — **no 26.3** |

**Controlify and SDL3** ★★★ (source): on MC ≥ 26.3 Controlify can use **vanilla's bundled `lwjgl-sdl`**
(load order: its own downloaded natives → LWJGL's SDL → natives-in-jar → system SDL3), logging "SDL3
NATIVE LIBRARY VERSION MISMATCH" when bindings and native disagree. Its docs still describe a GLFW
gamepad fallback; on 26.3 there is no GLFW, so that path cannot apply (★ inference).

**Controlify 3.5.0 replaced the button-guide and adaptive-trigger APIs** ★★ (changelog) with a
"contextual" API: **rule-based domains**, definable by resource packs under
`assets/<namespace>/contextual/`, with mods contributing state and domains. A mod GUI that registered
button guides against Controlify ≤ 3.4 must port. 3.4.1 re-added the old code-based radial API as
deprecated; 3.5.1 added hotbar-slot binds and the 26.3 port. The practical design rule is unchanged:
make every custom widget a focusable `AbstractWidget` reachable by Tab/arrows, so both vanilla 26.4
keyboard navigation and controller mods (which drive the same focus path) work without an
integration. (★ for the "same focus path" claim.)

---

## 4. Multi-loader UI code sharing

**Genuinely portable:** layout math, state, `Component`/text building, widget composition against
vanilla `AbstractWidget`/`GridLayout`/`LinearLayout`, `GuiGraphics` draw calls, your own component
tree. Vanilla's screen classes are identical across loaders at the same MC version — that's most of a UI.

**Must be per-loader:** screen-open / HUD-render event registration · config-screen factory
registration · key mappings · anything touching `Screen.addRenderableWidget` from *outside* a subclass
(it's protected — needs an access widener/transformer) · mixins (refmaps/SRG differ, Forge 1.20.1
especially).

**Three structures, honestly compared:**

1. **Architectury (subproject model)** — `common/` + `fabric/` + `neoforge/`, architectury-loom,
   `@ExpectPlatform`. *Pro:* mature, and it ships the access widener exposing
   `addRenderableWidget`/`addRenderableOnly`/`narratables`/`renderables` to common code — the real UI
   value. *Con:* **Architectury API becomes a hard runtime dependency for your users.** You can use
   architectury-**loom** (the Gradle plugin) without architectury-**API** (the runtime mod); that's the
   usual compromise and what you want if your UI needs are modest.
2. **Common source set + thin per-loader clients** — no runtime dependency; you write the ~5 platform
   shims yourself. **This is what JEI does** (`CommonApi/` holds the entire loader-agnostic API
   surface, with `jei-<mc>-fabric` / `-neoforge` / `-api` published off it). **For a UI-heavy mod with
   few loader touchpoints, this is the better default.**
3. **Multisource** (lukebemishprojects) — models loaders as source sets/feature variants. Newer, less
   common, avoids subproject sprawl.

**Recommendation for a 1.20.1→26.x mod: common source set + per-loader thin clients**, architectury-loom
optional. Reserve Architectury API for when you'd otherwise reimplement 20+ of its ~90 event hooks.

---

## 5. Mixing into vanilla screens

**Prefer events over mixins.** Both loader families give you a supported, conflict-free way to add
widgets (`ScreenEvents.AFTER_INIT` + `Screens.getWidgets`, or `ScreenEvent.Init.Post` + `addListener`
— see `loader-hooks.md` §2).

When you must mixin — e.g. shifting `leftPos` for a side panel:

- Target `AbstractContainerScreen#init` with `@Inject(at = @At("TAIL"))`. **Never `@Overwrite`**, never
  `@At("HEAD")` cancellable.
- **The `leftPos` shift is the classic multi-mod collision.** Two mods each shifting by −30 push the
  GUI 60px off-centre, and JEI/REI/EMI compute exclusion zones from the *final* value, so whoever runs
  last wins. Mitigations: shift in `init` TAIL so you read the post-vanilla value; **never cache
  `leftPos` across frames**; recompute exclusion rectangles from live `getGuiLeft()` on every call
  rather than from a stored offset; expose a config to disable your shift.
- Use `@Inject`/`@ModifyVariable` over `@Redirect`/`@Overwrite` — `@Redirect` is exclusive, only one
  mod can hold it per target. **MixinExtras** (`@WrapOperation`, `@ModifyExpressionValue`) is the
  compatibility-friendly replacement; it's bundled in NeoForge and available on Fabric.
- Keep screen mixins in a **client-only** mixin config.
- Name **Mixin Conflict Helper** in your issue template — it turns mixin collisions into readable
  errors for your users.

---

## 6. UI testing and preview tooling — thin, be realistic

| Tool | Reality |
|---|---|
| **owo-ui XML hot-reload** | the only first-class GUI hot-reload in the ecosystem — in dev mode the `.xml` UI model reloads **every time you open the screen**. If iteration speed dominates, this alone is an argument for owo-ui (accepting Fabric-only) |
| **F3+T** | reloads resource packs → picks up **textures, GUI sprites, sprite/atlas definitions and lang keys** with no restart. Does **not** reload Java layout code. Structuring your screen so positions/sizes come from a resource JSON buys most of a hot-reload loop for free. ⚠ True on 26.3; **broken for GUI sprites in 26.4 snapshots up to s7** (MC-312955 "GUI textures are not reloaded without relaunching the game"), **fixed in 26.4-snapshot-8** ★★ |
| **JVM HotSwap / DCEVM + JetBrains Runtime** | change method bodies (not signatures) live and reopen the screen. The standard practical loop; no Minecraft-specific tooling needed |
| **Client game tests (Fabric)** | **Yes, on Fabric 1.21.4+.** Fabric API ships **`fabric-client-gametest-api-v1`** (present from the `1.21.4` branch onward) ★★★: a `fabric-client-gametest` entrypoint implementing `FabricClientGameTest#runTest(ClientGameTestContext)`, which can `setScreen`, `waitForScreen`, `clickScreenButton(translationKey)`, drive input, and **`assertScreenshotEquals` / `assertScreenshotContains`** against template images (`TestScreenshotComparisonOptions` with region, grayscale, size). Gradle: `fabricApi { configureTests { enableClientGameTests = true … } }`, run `runClientGameTest` (or `runProductionClientGameTest` in CI, Xvfb on Linux). Patterns, determinism rules and a worked example: **`java-patterns.md` (Testing)** |
| **Vanilla GameTest** | server/world-side only. Useful for container-menu logic (`quickMoveStack`), not for screens |
| **Screenshot-diff on NeoForge / pre-1.21.4** | no loader-provided client harness. Roll your own: a scripted dev-client task that opens screens with a fixed resource pack + fixed GUI scale and calls `Screenshot.grab`, then compare PNGs in CI |

**The cheapest high-value practice, given all that:** test at **GUI scale 1–4 and Auto**, at 1280×720
and an ultrawide, **with and without JEI/REI installed**, and with a long-string locale (German).
Most reported UI bugs are one of those five. On 26.x add a sixth axis: **OpenGL and Vulkan** (26.4
snapshots default to Vulkan, and s7+ picks the backend at random per launch; see
`vulkan-and-performance.md`). Keep separate screenshot templates per band group and per backend.

---

## 7. Flagged — abandoned or version-stalled

| Project | Status |
|---|---|
| **EMI** | ⚠ frozen at **1.1.24 / MC 1.21.1**; maven stalled at 1.20.4; port issue #1111 closed without a port |
| **owo-lib** | ⚠ **no 26.3 build** (0.13.1+26.2 is the last, issue #503 open); NeoForge line stalled at 0.12.28 / MC 1.21.10 apart from a 1.21.1 beta |
| **Configured** (MrCrayfish) | ⚠ **no 26.3 build** (2.7.6+26.2 latest on GitHub) |
| **ModernUI-MC** | ⚠ nothing past 26.1.x on Modrinth |
| **MidnightControls** | ⚠ stops at 26.2 (1.12.1); use Controlify on 26.3 |
| **VulkanMod** | ⚠ stops at 0.6.8 (1.21.11/26.1.2); superseded by vanilla Vulkan |
| **Lavender** | ⚠ 1.21.1 max, last release 2025-01 |
| **Quilt QSL / QFAPI / QKL** | ⚠ **officially retired at MC 26.1**; Quilt Loader continues |
| **Patchouli** | ⚠ no 1.21.2–1.21.11, no 26.2/26.3; 26.1 build is beta. Prefer Modonomicon (or GuideME on NeoForge) on modern bands |
| **LibGui on 26.3** | ⚠ only an `-rc-2` build (`18.0.1+26.3-rc-2`) |
| **Everything on 26.4** | ⚠ only Mod Menu and YACL (Fabric) among UI libraries; no NeoForge 26.4 at all |
| **REI on NeoForge** | ⚠ beta channel on every band; older bands frozen |
| **Cloth Config docs** | ⚠ GitBook stale; NeoForge setup page 404s. Mod itself current |
| **SpruceUI / MidnightLib GitHub Releases** | ⚠ years-stale tags; real releases on Modrinth/CurseForge and Maven |
| **LibGui README maven badge** | ⚠ dead host; use `https://staging.alexiil.uk/maven/` |
| **"Configured" on Modrinth** | ⚠ the Modrinth slug `configured` is a **different, unrelated mod**; MrCrayfish's Configured and Catalogue are GitHub/CurseForge only |

## 8. Could not verify

- **Blur** — no canonical current project resolved (`blur` and `blur-fabric` both 404 on the Modrinth
  API). Assume unmaintained on modern bands. Note only that background-blur mods mixin
  `Screen#renderBackground`/`renderBlurredBackground` — that's the collision surface.
- **"ConfigLib"** is an ambiguous name — the dominant hit is a Bukkit/Paper YAML library, not a
  client-UI mod library. Treat as a false lead.
- **Cloth Config's official NeoForge Gradle snippet** — the doc page 404s; the coordinates above come
  from Maven metadata.
- **Controllable's developer API surface** (class/event names) — existence documented, wiki not reached.
- **Xaero's / JourneyMap addon APIs** — both ARR, no public docs fetched; coexistence guidance above is
  convention-based, not contract-based.
- **NeoForge `ConfigurationScreen`'s per-type widget mapping** — documented only as "automatically
  parse and populate."
- **CurseForge-only release states** (2026-11-11): whether Configured has a 26.3 build on CurseForge
  (GitHub has none), CurseForge versions of Controllable/Catalogue beyond GitHub tags, and ModernUI on
  CurseForge for 26.2/26.3. CurseForge pages were not queried.
- **Forge Config API Port 26.3.1 vs NeoForge `LOCAL`/`SYNCED`** — mapping not read in source.
- **Controlify 26.4 builds** — Patreon-gated, not inspectable; `port/26.4` branch not read.
- **owo-lib `braid-ui`** — branch exists (KDL widgets); release plans and relation to owo-ui unknown.
- **Mod Menu `modular-refactor` branch** — purpose not read.
- **MezzConfigGUI API surface** — only the Modrinth summary was read; not evaluated as a dependency.
- **Accessibility libraries** — no prominent accessibility-framework mod found for 26.x (only small
  narrator toggles). Absence is ★ (search-based).
