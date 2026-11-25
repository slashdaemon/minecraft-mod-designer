# minecraft-mod-designer

A [Claude Code](https://claude.com/claude-code) skill: an authoritative UI/UX design-and-implementation
reference for **Minecraft Java mods**, covering **MC 1.20.1 → 26.3** (plus a **26.4-snapshot
preview**) on **Fabric, Quilt, NeoForge, and MinecraftForge (LexForge) 1.20.1**.

It is the design counterpart to `minecraft-mod-expert`, which owns build coordinates, mappings,
packaging and porting mechanics. This skill answers four questions:

1. **What should this look like?** — vanilla's visual grammar and the hard numbers behind it.
2. **How should it behave?** — the interaction contracts players already know.
3. **How do I draw it on band X, loader Y?** — exact signatures, per band, per loader.
4. **Is it good enough to ship?** — a scored rubric with hard gates.

## Contents

| File | Covers |
|---|---|
| `SKILL.md` | Routing, the UI eras (A–G plus the 26.4 preview), the ten laws, cross-cutting gotchas |
| `references/design-language.md` | Visual grammar; source-verified color constants; container/slot/button/spacing/Z/text metrics; match-vs-brand-vs-diegetic |
| `references/ux-principles.md` | Slot-interaction contracts; HUD occupied-region map and safe zones; information architecture; microcopy; 25 smells; 8 case studies |
| `references/accessibility.md` | Narrator, contrast targets, colorblind encoding, GUI-scale extremes, motion/flashing, controller and keyboard operability |
| `references/screen-widget-api.md` | Screen lifecycle; full widget catalogue with default metrics; the layout system; container screens and `Slot` math; input, focus, narration, tooltips, toasts |
| `references/render-pipeline.md` | Per-band blit/text cheat sheet; the 1.21.6 deferred-GUI rewrite; Picture-in-Picture; the 26.1 `extract*` renames |
| `references/loader-hooks.md` | HUD, screen events, keybinds, config screens, client-only safety — per loader, per band |
| `references/assets-and-fonts.md` | GUI sprite atlas and nine-slice `.mcmeta`; fonts and icon fonts; GUI-scale math; `pack_format`; localization |
| `references/vulkan-and-performance.md` | What the 26.2 Vulkan backend is, what breaks, the safety checklist, GUI performance, Sodium/Iris status |
| `references/libraries.md` | Config/UI library decision table; the JEI/REI/EMI exclusion-zone contract; multi-loader code sharing |
| `references/review-checklist.md` | The scored design-review rubric |
| `references/java-patterns.md` | Java design patterns for mod UI: state outside the `Screen`, version/loader adapter seams, Java 17/21/25 per band, Mixin limits, threading, testing |
| `scripts/skill.ps1`, `scripts/skill.sh` | Install / link / pull-back / diff against `~/.claude/skills` |
| `CHANGELOG.md` | What was verified, against which source, per refresh |

## Install

Clone into your Claude Code skills directory so the skill is discovered by name:

```bash
git clone https://github.com/slashdaemon/minecraft-mod-designer.git \
  ~/.claude/skills/minecraft-mod-designer
```

Or, from a checkout, `./scripts/skill.ps1 install` (copy), `link` (symlink — repo edits go live),
`diff` (drift check) or `pull` (capture in-place edits); Git Bash: `./scripts/skill.sh …`.

Claude Code picks it up on next start. Invoke it with `/minecraft-mod-designer`, or let it trigger
automatically on GUI/HUD/screen/widget work.

## Sourcing and confidence

Claims are marked **★★★** (primary source — decompiled vanilla, `javap` over Mojang-mapped jars,
official docs/javadoc), **★★** (official blog, release notes, changelog), or **★** (community or
inferred). Every reference file ends with an explicit *could not verify* list.

The strongest material — widget metrics, slot math, color constants, per-version signatures — was
read with `javap -p -constants` from Mojang-mapped client jars for 1.20.1, 1.20.5, 1.21.1, 1.21.2,
1.21.4, 1.21.6, 1.21.9, 1.21.11, 26.1.2, 26.2, 26.3 and 26.4-snapshot-8, and cross-checked against mappings.dev and the
NeoForged migration primers. The weakest is anything single-sourced to a 26.x primer; those are
flagged in place.

Minecraft's GUI API is version-volatile. Re-verify version-pinned coordinates against your own
toolchain before relying on them.
