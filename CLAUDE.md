# CLAUDE.md — minecraft-mod-designer

This repo is the **versioned source of truth for the `minecraft-mod-designer` Claude Code skill**.
It is documentation only: no code, no build, no tests. The repo root is the skill payload —
`SKILL.md` + `references/` are copied, symlinked, or git-cloned to
`~/.claude/skills/minecraft-mod-designer`.

## Working here

- **Edit the repo, not the installed copy.** Check drift first with `scripts/skill.ps1 diff`
  (or `scripts/skill.sh diff`); if the installed copy was edited in place, `pull` it back before
  committing. If the installed copy is a git clone (the README's install path), `git pull` there
  after pushing instead.
- **`SKILL.md` frontmatter is load-bearing.** `name` must stay `minecraft-mod-designer` (it must
  match the install directory name) and `description` is the trigger surface — the reason the
  skill fires on a bare UI symbol (`SlotWidget`, `GuiPipeline`, `HudElementRegistry`, …). Widening
  coverage means adding those keywords to the description.
- **`SKILL.md` routes, references hold the tables.** Keep the entry file short; put lookup content
  in the matching `references/*.md`. Add a row to both routing tables in `SKILL.md` and to the
  contents table in `README.md` when adding a reference file.
- **Confidence over invention.** Mark claims ★★★ (decompiled/`javap` vanilla jars, official
  docs/javadoc, maven metadata), ★★ (official blog/release notes/changelog), ★ (community or
  inferred). Every reference file ends with a *could not verify* list — keep it honest. Never
  fabricate a version or patch number; snapshot facts name the snapshot (`26.4-snapshot-N`).
- **Stay consistent with `minecraft-mod-expert`.** Band letters (A … K = 26.3, L = 26.4 preview)
  and toolchain pins come from the expert skill. This repo owns UI/UX design and GUI
  implementation; build coordinates, mappings, packaging and general porting stay there.

## Scope

In: UI/UX design (visual grammar, metrics, interaction, HUD, accessibility, microcopy, review
rubric) and GUI implementation per band and loader (screens, widgets, layouts, containers, render
calls, HUD/keybind/config-screen hooks, sprites/fonts, Vulkan safety, UI libraries, Java patterns
for UI code). Out: build/toolchain coordinates, mappings, mixin refmaps, jar packaging, gameplay.

## Refreshing for a new Minecraft version

Re-verify the same way the 2026-11-11 refresh did: `javap -p -constants` over the official client
jars for the GUI packages, diff the GUI sprite `.mcmeta` files, read Mojang's patch notes and the
NeoForge primer, and check maven metadata / the Modrinth API for every library pin. Record what was
verified and against which source in `CHANGELOG.md`.

## Standing rules (inherited)

- Commits carry no `Co-Authored-By: Claude` trailer.
- No time concepts in planning docs — dependency ordering and state-by-version framing.
