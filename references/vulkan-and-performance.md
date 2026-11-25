# Vulkan, GPU abstraction, GUI performance, and rendering-mod compatibility

Confidence: ★★★ primary source · ★★ official blog/vendor statement · ★ community/inference.
Verified 2026-09-09; **re-verified 2026-11-11** for 26.3 (band K) and 26.4-snapshot-8 (L, preview):
§2.1, §5.5 and §6 updated. This area moves fast — re-check anything version-pinned.

> **The 2026-11 headline:** on 26.3 Vulkan is still opt-in, but **26.4 snapshots make Vulkan the
> default** (s1), and **s7+ picks OpenGL or Vulkan at random per launch** (s8 notes don't revert it).
> Any GL-only code path in GUI code now fails for most snapshot testers, not a minority. **Iris
> still has no Vulkan support.** ★★

---

## 1. The correct mental model

**The rendering break for mods did not happen "at Vulkan."** It happened in three earlier steps, and
Vulkan is just the payoff:

| Step | Version | What it was |
|---|---|---|
| Shader groundwork | **1.21.2** | `ShaderProgram`/`CompiledShaderProgram`; `GpuBuffer`, `GpuFence`, `ProjectionType`; post-effect JSON restructured |
| **The GPU abstraction** | **1.21.5** | `GpuDevice` / `CommandEncoder` / `RenderPass` / `RenderPipeline`. **Core-shader JSONs eliminated.** `RenderTarget#framebufferId`/`bindWrite`/`unbindWrite`/`checkStatus`/`setClearColor` removed. Designed to be backend-swappable — but OpenGL is still the only backend |
| **The deferred GUI** | **1.21.6** | submission/render split; `Matrix3x2fStack`; PiP |
| **Vulkan plugs in behind it** | **26.2** (released **2026-06-16**) | a parallel `com.mojang.blaze3d.vulkan.*` behind the same `GpuDevice` interface |
| Render types move package | **26.3** | GUI `blit/blitSprite/fill` take `com.mojang.renderpearl.api.pipeline.RenderPipeline`; textures under `renderpearl.api.textures`. Package only, same shapes ★★★ |
| **Vulkan by default; GUI pipelines wrapped** | **26.4 snapshots** | Default backend = Vulkan (random per launch from s7). GUI calls take **`GuiPipeline`** (`DEFAULT`, `TEXTURED`, …) instead of a `RenderPipeline`; `RenderPipeline` moves back to `com.mojang.blaze3d.pipeline` ★★★ — see `render-pipeline.md` |

So: a mod already correct on 1.21.11 is *mostly* correct on 26.2. A mod still on 1.21.4 or earlier
faces three stacked breaks.

---

## 2. What the 26.2 Vulkan backend actually is ★★★

| Question | Answer |
|---|---|
| **Opt-in?** | Yes on 26.2 and 26.3. Experimental, off by default. **Not on 26.4 snapshots** — see §2.1 |
| **How enabled?** | Video Settings → **Graphics API** dropdown: **Default** / **Prefer Vulkan (Experimental)** / **Prefer OpenGL**. At release, "Default" is equivalent to "Prefer OpenGL" |
| **A launch flag?** | **No** — a settings toggle. (`--tracy` is separate, for profiling, and now includes GPU timings) |
| **Does OpenGL remain?** | **Yes.** Each option falls back to the other if unavailable. A startup crash under "Prefer Vulkan" auto-switches to "Default"; a crash under "Default" auto-switches to "Prefer OpenGL". **26.4-snapshot-1 removed this crash auto-switch** |
| **Minimum** | **Vulkan 1.2 with `VK_KHR_dynamic_rendering` and push descriptors** — "this requirement may increase or decrease over time." These are **driver-level** features: a capable GPU on an old driver still falls back |
| **Platforms** | Windows and Linux natively; **macOS via MoltenVK** (Vulkan→Metal) |
| **GPU selection** | Under Vulkan the **dedicated GPU is preferred over integrated** — a behavioral change vs OpenGL |
| **How to tell which is live** | F3 debug overlay, `system_specs` section. **Check this first on every bug report.** |
| **Depth** | **Reversed depth buffer** ("helps with Z-fighting on most hardware"). In `RenderPipelines`, `DepthStencilState` values are **inverted**: compare op is `GREATER_THAN_OR_EQUAL` instead of `LESS_THAN_OR_EQUAL`, and the depth-bias ints are their additive inverses |
| **Is it faster?** | **Not universally.** Mojang: "may not be as performant or stable." One independent benchmark measured RTX 5090 **+21–31%** but RX 9070 XT **−39% to −58%** and Arc B580 **−32% to −48%** ★ |
| **Will OpenGL be removed?** | Mojang stated (2026-02-18) yes, "once it's happy with the performance and stability." **No date.** ★★ |

### 2.1 What changed after 26.2 (Mojang launcher patch notes) ★★

| Version | Backend behaviour |
|---|---|
| **26.3** (stable) | Vulkan still opt-in, as in 26.2 (★★★ per the expert skill). OpenGL is the default |
| **26.4-snapshot-1** | **"Default" = "Prefer Vulkan".** The game **no longer auto-switches API after a startup crash** — the 26.2 crash-fallback row above no longer holds |
| **26.4-snapshot-5** | New Windows-only, experimental **"Prefer DXGI Present"** video setting (IME, VRR, faster fullscreen alt-tab). No known GUI impact; note it in bug triage next to the F3 backend line ★ |
| **26.4-snapshot-7** | **"Default" picks OpenGL or Vulkan at random per launch** (notes say this "will be reverted") |
| **26.4-snapshot-8** | Random default **not reverted** in the s8 notes (treat it as still random). Terrain vertex data from a texel buffer; OIT via subpasses. Fixes **MC-312955** (GUI textures not reloaded on F3+T in earlier 26.4 snapshots) and MC-313046 (tooltips positioned too low/high). RP format 103.0 |

Consequences for GUI authors:
1. **Assume Vulkan.** On 26.4 snapshots a GL-only path breaks for most testers, and with random
   selection a bug can appear on alternate launches of the *same* machine — always ask for the F3
   `system_specs` backend line. The §4 rules are unchanged; their priority rises.
2. **No crash fallback.** A GUI mod that crashes the Vulkan backend at startup now leaves the user on
   Vulkan, crashing, until they change the setting by hand (★, inferred from the s1 note).
3. **Test both backends every release**, and keep separate screenshot templates per backend if you
   do screenshot tests (`libraries.md` §6).

**Mojang's own message to modders (2026-02-18):** switching to Vulkan will affect mods that use
OpenGL directly; **start transitioning away from direct OpenGL and reuse the internal rendering APIs.** ★★

### As a modder sees the implementation ★★★

Every class in `com.mojang.blaze3d.opengl` has a parallel in `com.mojang.blaze3d.vulkan`:
`VulkanBackend`, `VulkanDevice`, `VulkanInstance`, `VulkanPhysicalDevice`, `VulkanCommandEncoder`,
plus `com.mojang.blaze3d.vulkan.glsl.GlslCompiler` ("compiles the GLSL shaders into SPIR-V bytecode")
and the SPIR-V plumbing (`IntermediaryShaderModule`, `SpvcUtil`, `SpvSampler`, `SpvUniformBuffer`).

> **You still author GLSL.** Minecraft cross-compiles your `.vsh`/`.fsh` to SPIR-V at runtime when the
> Vulkan backend is active. **Do not ship SPIR-V.**

Backend selection goes through `GpuBackend#createDevice`, which takes a `Runnable` for the shaders
that must load at startup and can throw `BackendCreationException`.

---

## 3. What breaks

### 3.1 Direct GL and legacy state

| Pattern | Status | Replacement |
|---|---|---|
| `org.lwjgl.opengl.GL11.*` / `GL20.*` etc. | **Dead under Vulkan.** Still "works" while GL is active — so it compiles, and works on your dev machine. **That is the trap.** | everything below |
| `GlStateManager.*` | `public` in 26.2 but GL-only by construction | `RenderPipeline` state baked at build time |
| Raw GL enum ints | removed from object references in 1.21.5 (`GlConst#toGl` only) | `BlendFactor`/`BlendOp`, `CompareOp`, `PolygonMode`, `LogicOp`, `AddressMode`, `FilterMode`, `GpuFormat` |
| `RenderTarget#framebufferId`, `bindWrite`, `unbindWrite`, `checkStatus`, `setClearColor` | **removed 1.21.5** | `CommandEncoder#createRenderPass(...)` in try-with-resources |
| `RenderTarget#blitToScreen` | **removed 26.2** | `GpuSurface#blitFromTexture`; `GpuSurface#configure` replaces vsync; `GpuSurface#present` replaces `presentFrame` |
| `MultiBufferSource` | **removed entirely in 26.2** | `FeatureRenderDispatcher` over `SubmitNodeStorage`; closest single replacement is `RenderTypeFeatureRenderer` |
| `Font#draw(...)` | **removed 26.2** | `Font#prepareText` → `PreparedText` → `GlyphVisitor` → `acceptRenderable` |
| `RenderSystem.enableBlend/disableDepthTest/setShaderTexture/setShaderColor/...` | mass-removed **1.21.5**, gone by 26.1 | pipeline state; `RenderPass#bindTexture` |
| `GraphicsWorkarounds` | renamed 26.2 (not 1:1) | `GlHeuristics`, `HintsAndWorkarounds` |

`RenderSystem` survives as the entry point: `initRenderThread`, `isOnRenderThread`,
`assertOnRenderThread`, `getDevice`, `tryGetDevice`, `getDynamicUniforms`, `bindDefaultUniforms`,
`setProjectionMatrix(GpuBufferSlice, ProjectionType)`, `getModelViewStack`, `setShaderFog`,
`setShaderLights`, `enableScissorForRenderTypeDraws`, and the public
`outputColorTextureOverride`/`outputDepthTextureOverride`.

### 3.2 Custom shaders

**Dead:** `.json` core-shader definitions in `assets/<ns>/shaders/core/` — eliminated 1.21.5.
**Alive:** GLSL `.vsh`/`.fsh` at `assets/<ns>/shaders/<path>`, referenced by identifier;
`#moj_import` still works; `withShaderDefines(...)` is how variants are selected.

Registration: see `render-pipeline.md` §4 for the `RenderPipeline.builder()` form.
`RenderPipelines#register` is not public in vanilla — access-widen on Fabric, or use NeoForge's
**`RegisterRenderPipelinesEvent`** (★★★, alongside `RegisterRenderBuffersEvent` and
`RegisterPictureInPictureRenderersEvent`).

> **Ordering hazard that bites GUI mods specifically:** *"Pipelines are sorted in the order they are
> built… `RenderPipelines#ENTITY_TRANSLUCENT` will be rendered before `RenderPipelines#GUI` if on the
> same layer and scissor rectangle."* It relies on classloading constants, so a late-classloaded
> custom pipeline sorts after `GUI` and draws **over** your widgets. Prefer a loader with dynamic
> pipeline ordering. ★★★

**Overriding vanilla core shaders via resource pack is unsupported** (Mojang's own 25w16a note) and
has caused crashes under Vulkan. Don't rely on it.

### 3.3 Framebuffers and render-to-texture in a GUI

The old pattern (bind an FBO, render, unbind, blit) is gone — there is no `framebufferId` to bind, and
under Vulkan there is no GL context at all. The low-level replacement is a scoped render pass:

```java
try (RenderPass pass = RenderSystem.getDevice().createCommandEncoder()
        .createRenderPass(() -> MOD_ID + " example pass",
                          colorTextureView, Optional.empty(),
                          mainTarget.getDepthTextureView(), OptionalDouble.empty())) {
    pass.setPipeline(pipeline);
    RenderSystem.bindDefaultUniforms(pass);
    pass.setUniform("DynamicTransforms", dynamicTransforms);
    pass.setVertexBuffer(0, info.vertexBuffer().slice());
    pass.setIndexBuffer(info.indexBuffer(), info.indexType());
    pass.drawIndexed(info.indexCount(), 1, info.firstIndex(), info.baseVertex(), 0);
}
```

Note **`RenderPass#bindTexture` gained a mandatory sampler argument in 1.21.11** — pull samplers from
`RenderSystem#getSamplerCache()` (all 32 combinations are pre-cached), never `createSampler()` per frame.

> **For GUI, do not hand-roll any of that. Use Picture-in-Picture** (`render-pipeline.md` §2.4) — it
> pools the intermediary texture for you and submits the result as a `BlitRenderState`. This covers
> 3D models, entities, custom meshes, and minimap-style continuous render-to-texture. NeoForge
> specifically fixed a bug preventing multiple instances of a PiP state per frame.

**Blur** is `GuiGraphics#blurBeforeThisStratum()` — **once per frame maximum**; exceeding it throws.

### 3.4 Pixel readback / screenshots

The primitives exist: `CommandEncoder#copyTextureToBuffer` (offsets became `long` in 1.21.11),
`GpuFence` (since 1.21.2), `RenderTarget#getColorTexture()`/`getColorTextureView()`,
`CommandEncoder#writeToTexture` for uploads. The shape of a modern readback is copy → fence → map →
`NativeImage`. **`glReadPixels` against a bound FBO is dead.** The ergonomic wrapper for 26.x was not
verified — see §8.

---

## 4. Vulkan-safety checklist

**Hard rules — a violation is a crash or corruption for Vulkan users:**

- [ ] **Never import `org.lwjgl.opengl.*`.** It compiles, and works on your dev machine. That's the trap.
- [ ] **Never call `GlStateManager`.**
- [ ] **Never assume `RenderSystem.getDevice()` is a `GlDevice`.** Don't cast, don't `instanceof`-branch,
      don't reach for a GL texture id. Query capability via `GpuDevice#getDeviceInfo()` /
      `DeviceFeatures` / `DeviceLimits`.
- [ ] **Don't hardcode GL enum ints.** Use the enum objects.
- [ ] **Don't assume depth conventions.** 26.2 is reversed-Z; any hand-written depth comparison or
      depth-bias number from a 1.21.x mod is now backwards.
- [ ] **All GPU work on the render thread.** Guard with `RenderSystem.isOnRenderThread()`.
      `assertOnRenderThread()` throws `IllegalStateException("Rendersystem called from wrong thread")`.
      Resource-reload listeners, config watchers, network handlers and async I/O are the usual offenders.
- [ ] **Bake state into pipelines, not ambient global state.** There is no "current blend mode" to save
      and restore. If you're writing a save/restore pair, you're writing GL.
- [ ] **`close()` everything you create** — `GpuBuffer`, `GpuTexture`, `RenderTarget`. `close()` became
      abstract in 1.21.5, and the resource is considered deleted afterward. Free on `removed()` /
      shutdown, not on GC.
- [ ] **Scope every `RenderPass` in try-with-resources.**
- [ ] **Bind a sampler explicitly** (1.21.11+), from the sampler cache.
- [ ] **26.3+: never touch `org.lwjgl.glfw.*`** (or `tinyfd`). Vanilla ships `lwjgl-sdl` and no longer
      ships `lwjgl-glfw`/`lwjgl-tinyfd`, so this is a class-not-found on every backend, not only Vulkan.
      Use `InputConstants.*` for keys and `Blaze3D.openUri/openPath` for links ★★★ (expert skill).

**Soft rules — correctness, perf, and saving yourself the next port:**

- [ ] **No per-frame allocation** in render: no `new Matrix4f()`, no `ResourceLocation`/`Identifier`
      construction, no `Component.literal(...)`, no `String.format(...)`, no capturing lambdas.
      Hoist to fields; build in `init()`.
- [ ] **Never write to a `GuiRenderState` outside the submission phase** — the whole point of the split
      is that another thread may be drawing frame *N* while you extract *N+1*.
- [ ] **Prefer PiP over any hand-rolled render-to-texture in GUI code.**
- [ ] **Prefer `RenderTypes`/`RenderPipelines` constants over custom pipelines** when you don't need
      custom uniforms — the batcher can't batch across custom-uniform pipelines.
- [ ] **Ship GLSL, not SPIR-V.** Avoid GL-only GLSL extensions and legacy `gl_` builtins.
- [ ] **Test with "Prefer Vulkan" selected, on at least one AMD or Intel GPU, before every release.**
      Vendor behaviour diverges wildly right now. On 26.4 snapshots also test with **"Prefer OpenGL"**
      explicitly: "Default" is Vulkan (s1) or random per launch (s7+), so neither backend is the
      quiet one any more.

---

## 5. GUI performance

### 5.1 What a draw call costs now

Since 1.21.6 a `fill`/`blit`/`text` call is **not a draw call** — it appends a `GuiElementRenderState`
that is then sorted and batched. Consequences:

- **Cost moved from GPU submission to CPU state construction + sorting.** Thousands of tiny `fill()`
  calls are thousands of objects allocated and sorted **per frame**. Batching does not make them free.
- **The sort's third tier is explicitly non-deterministic** (`TextureSetup#getSortKey()` is a
  `hashCode()`, and `GpuTextureView` doesn't implement `hashCode`). If overlapping elements share a
  node and differ only by texture, **z-order can flip between runs**. Force order with `nextStratum()`
  or by separating scissor regions.
- The system is optimized "for reducing pipeline and texture switches over determinism." Mixing many
  pipelines/textures in one node defeats it.
- **Glyphs bypass the sort** and always render after all elements in the current node.

### 5.2 The real hotspots, in order

1. **`Font#split(Component, int)` called per frame.** It performs full text shaping and allocates a
   `List<FormattedCharSequence>`. This is the classic tooltip / description-panel mistake and it
   dominates GUI CPU time. **Compute in `init()`/`resize()`, cache, invalidate on text or width change.**
2. **`Component.literal(...)`/`.translatable(...)` built inside `render()`** — an allocation plus a
   language-table lookup.
3. **`String.format` / number formatting per frame** — cache the string, rebuild only when the value
   changes.
4. **Gratuitous scissoring.** Each distinct scissor rect is a sort-partition boundary. Use it to clip
   scroll lists; don't wrap every widget.
5. **Item rendering.** Call `ItemStackRenderState$LayerRenderState#ensureCapacity(n)` **before** a
   `newLayer()` loop. Since 1.21.11 items are on their own atlas (`AtlasIds#ITEMS`).
6. **Layout recomputation in `render()`.** `tick()` is 20 Hz, `render()` is framerate. Recompute layout
   in `init()`/`resize()` only.

### 5.3 Text batching by band

| Band | How |
|---|---|
| ≤1.21.5 | `Font#drawInBatch(..., MultiBufferSource.BufferSource, ...)` then one `endBatch()`. Repeated `Font#draw` = one flush each |
| 1.21.6–1.21.11 | automatic via `GuiTextRenderState` → glyph states. Just call `drawString` |
| 26.1+ | `GuiGraphicsExtractor#text(...)` |
| 26.2+ | `Font#draw` removed; manual text goes `prepareText` → `PreparedText` → `GlyphVisitor`. Prefer `OrderedSubmitNodeCollector#submitText` |

### 5.4 Tooltips

Prefer `set*TooltipForNextFrame(...)` over `renderTooltip(...)` from 1.21.6 — the deferred form is
submitted after the screen render into a **new stratum**, so it lands on top without you managing z.
The immediate form makes ordering your problem.

### 5.5 Profiling

| Tool | How |
|---|---|
| **Built-in profiler** | `Profiler.get()` returns the `ProfilerFiller` (**not** `Minecraft.getInstance().getProfiler()`, which is the old form). `Profiler.get().push("section"); … pop();`. **F3 + L** starts a 10-second session; results land in `debug/profiling` ★★★ |
| **Tracy** | launch with `--tracy`. **As of 26.2 this includes GPU timings.** Best tool for frame pacing and GPU-side GUI cost ★★★ |
| **spark** | sampling profiler with `spark-fabric-client` / `spark-forge-client` builds; flame graphs; ~1% overhead. Best for finding CPU hotspots in submission-phase code (e.g. a `Font#split` in `render()`) ★★ |
| **F3 `system_specs`** | reports the active graphics backend ★★★ |
| **ImmediatelyFast** | **`1.17.1+26.3`** (F/N/Q; 1.17.0 = 26.3 support, 1.17.1 NeoForge crash fix); the 1.21.1 line is still updated (1.6.15, incl. Forge). **No 26.4 build.** Optimizes immediate-mode rendering, text, HUD/GUI and maps (`hud_batching`, `fast_text_lookup`, `font_atlas_resizing`). Incompatible with OptiFabric/OptiFine ★★★ |

---

## 6. Rendering-mod compatibility (status as of 2026-11-11)

**None of Sodium, Iris, Sulkan, Vitrail, VulkanMod or ImmediatelyFast has a 26.4 build.** ★★★

| Mod | 26.3 | Status |
|---|---|---|
| **Sodium** (Polyform Shield) | release **`mc26.3-0.9.2`**; beta **`mc26.3-0.9.3-beta.4`** (F+N) | 0.9.0 (26.2) "moved all rendering to Mojang's Blaze3D API", **first release with experimental Vulkan support**, async graph culling; 0.9.1 fixed a crash "rendering very many sections on Vulkan". 0.9.2 also covers 26.1.2/26.2; 0.8.x on 1.21.11/1.21.1. **0.9.3** ★★: SDL message box instead of TinyFD, video-settings options sourced from vanilla, a `VideoSettingsScreen` `onClose` fix for Iris, and **"compatibility metadata … to prevent usage in broken configurations"** — `breaks` entries for known-bad mods. **Mixins into Sodium's options/video screen are the likely casualties** (★; the exact list was not extracted). No 26.4 branch. ★★★ **Requires NVIDIA driver 536.23+** or the game won't launch — put that in your troubleshooting docs, because your users will blame you ★★★ |
| **Iris** (LGPL-3.0) | **`1.11.7+26.3`** (F+N) | 1.11.5 = 26.3 port, 1.11.6 macOS load fix, 1.11.7 "fixes a lot of 26.3 bugs". **Still OpenGL-only**: `1.11.0+26.2` changelog said "Note that Vulkan is not supported", and feature request Iris #3416 ("Add Support for Minecraft's Native Vulkan Graphics Backend") is open. No maintainer statement on Vulkan found ★. Iris's own site: OptiFine, Canvas or Vulkan mods are "incompatible, and will crash the game." Iris↔Sodium versions are **tightly pinned** ★★★ |
| **Sulkan** (GPL-3.0) | **`0.6.0`** (Fabric) | **Native shader support on Minecraft's Vulkan renderer**, built on Sodium. 0.5.0 = 26.3 port. 0.6.0: on-disk Vulkan pipeline cache, GPU feature detection (fp16, subgroups, MoltenVK), shader folder moved `shaders/` → **`shaderpacks/`** (auto-migrated), **Iris/OptiFine packs hidden** in its screen. Own pack format via a `sulkan.json` manifest. Pauses effects if MC falls back to OpenGL ★★★ |
| **Vitrail Shaders** (new) | ✓ F+N (26.2, 26.3) | "OptiFine-format shader packs, on Minecraft's native Vulkan renderer"; ~70k downloads. Reported to run Complementary ★ (one issue comment). Internals not examined |
| **VulkanMod** | none | Stops at `0.6.8` (1.21.11 / 26.1.2). Superseded by vanilla Vulkan ★★★ |
| **Embeddium** | none | newest observed `1.0.15+mc1.21.1` (Jan 2025). Legacy-band only ★ |
| **OptiFine** | none | **no evidence of 26.x support.** Report as unsupported; don't spend compatibility budget ★ |

> **The headline compatibility fact: Iris shaders and the vanilla Vulkan backend are mutually
> exclusive.** Iris is OpenGL-only, so Iris users force "Prefer OpenGL". With 26.4 snapshots
> defaulting to Vulkan, **shader users split three ways** ★★: **Iris** (OpenGL), **Sulkan** (Vulkan,
> own format) and **Vitrail** (Vulkan, OptiFine format). Test GUI, PiP and entity-in-GUI rendering
> under each where feasible.
>
> Practical fallout on 26.2: **MC-308825** — users forced onto "Prefer OpenGL" to keep Iris shaders saw
> 180 fps → 30–45 fps (resolved after an Iris-side fix). **The OpenGL path is now the less-exercised
> one, and Iris users are stuck on it.** ★★★

### What GUI mods commonly do wrong here

1. **Leaving GL state dirty** — historically the #1 Sodium/Iris incompatibility. Under the pipeline
   model there's no ambient state to leak, but any mod still calling `GlStateManager` or LWJGL
   reintroduces it — and now does it **only on the OpenGL backend**, making it unreproducible for half
   the userbase.
2. **Rendering entities into a GUI by hand.** `renderEntityInInventory`-style code interacts badly with
   Iris's batched entity rendering; crashes opening inventories with shaders active are a recurring
   Iris issue class. **Use PiP / `GuiEntityRenderer`** instead of driving entity renderers from screen code.
3. **Mixing custom pipelines into GUI strata without accounting for classload order.**
4. **Depending on the `TextureSetup` hash ordering.**
5. **Assuming `Minecraft.getInstance().screen` exists** — 26.2 moved it to `.gui.screen()`.
6. **Calling into rendering off-thread.**
7. **Patching Sodium's video-settings screen.** Sodium 0.9.3 sources its options from vanilla and
   ships `breaks` metadata against known-broken mods; a mixin into its options screen is the most
   likely way to land on that list. Add options through your own config screen instead. ★★
8. **Assuming one backend per machine.** On 26.4-snapshot-7+ "Default" is random per launch: a
   "can't reproduce" bug report is often the other backend. Ask for the F3 `system_specs` line. ★★

---

## 7. Frame pacing

`DeltaTracker` (added ~1.20.5) "keeps track of the delta ticks, both ingame and real time, and holds
the current partial tick," replacing most passing-around of partial ticks. Key API:
`getGameTimeDeltaPartialTick(boolean ignoreTickFreeze)`.

| Animating… | Use |
|---|---|
| Tick-synced simulation (progress bar from a BE field, entity interpolation in a PiP) | `DeltaTracker#getGameTimeDeltaPartialTick(false)` |
| **Any UI animation** | **`Util.getMillis()`** — wall clock, framerate-independent, **and it keeps running while the game is paused** |
| Something that must ignore `/tick freeze` | `getGameTimeDeltaPartialTick(true)` |

> Documented NeoForge issue #1117: a `Screen`'s `partialTick` **does not advance while the game is
> paused**, so screen animation driven from it freezes. Another reason UI animation belongs on the
> wall clock. ★★★

**Never drive UI animation from a frame counter** — it makes speed a function of framerate.

---

## 8. Could not verify

1. **Exact MC version `DeltaTracker` was introduced** — strongly associated with 1.20.5/1.21; no
   changelog line read.
2. **Whether `CoreShaderRegistrationCallback` still exists in Fabric API for 1.21.5+/26.x.** The modern
   path is plainly `RenderPipelines.register(...)` from a classloaded constant; the callback's
   deprecation/removal wasn't confirmed.
3. **`RegisterShadersEvent`'s current status on NeoForge** — presumably gone with the shader JSONs in
   1.21.5, but not confirmed. `RegisterRenderPipelinesEvent` **is** confirmed.
4. **Screenshot / pixel-readback ergonomics for 26.x** — the primitives are confirmed; a wrapper is not.
5. **System-requirement conflict:** the wiki/changelog says **Vulkan 1.2** + dynamic rendering + push
   descriptors; secondary press summarizing minecraft.net's requirements page says **Vulkan 1.3** and
   2 GB VRAM minimum. **Trust 1.2 for backend capability**; treat 1.3/VRAM as the marketing
   "supported configuration."
6. **"26.2 renders on its own thread"** — press describes the Vulkan renderer as multi-threaded and
   Mojang states a dedicated render thread as a *goal*; no Mojang statement confirms it ships today.
   **Treat as unconfirmed.**
7. **Vibrant Visuals for Java** — "currently planned… at some point in the future." It has not appeared
   in any development version. **The Vulkan work is the prerequisite, not the delivery. No date.**
8. **Whether the F3 debug pie chart still exists in 26.x** — absent from current NeoForge profiler docs.
   (26.4 redesigned F3 into groups/facts/columns; the profiler chart's fate there was not checked.)
9. **Whether Mojang reverts the s7 random-backend default.** The s7 notes say it "will be reverted";
   the s8 notes are silent. Treat it as random until a note says otherwise. (2026-11-11)
10. **Iris plans for Vulkan** — only the open feature request #3416 and an issue-thread mention (★); no
    maintainer statement or roadmap found.
11. **Vitrail Shaders internals and compatibility** beyond its Modrinth summary and one issue comment.
12. **Sodium 0.9.3's exact `breaks` list** — not extracted from the jar.
13. **26.4 builds of the rendering mods** — none exist as of 2026-11-11; Controlify's are Patreon-gated.
