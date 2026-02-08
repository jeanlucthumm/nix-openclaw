# PR: Nix Skills Library

## RFC

@docs/rfc/2026-02-07-nix-skills-library.md

## Summary

`mkSkill` + fetchers + pre-packaged catalog for bundling AgentSkills-format skills with Nix tool dependencies. Users pick skills from a catalog and get the tools on PATH automatically.

```nix
skills = with nix-openclaw.skills.${system}; [
  github       # bundles pkgs.gh
  tmux         # bundles pkgs.tmux
  weather      # bundles pkgs.curl
  session-logs # bundles pkgs.jq + pkgs.ripgrep
];
```

## Implementation Log

### Chunk 1: `mkSkill` + frontmatter patcher

**Files:** `nix/lib/mkSkill.nix`, `nix/scripts/patch-skill-frontmatter.py`, `nix/checks/skill-mkSkill.nix`, `nix/tests/fixtures/test-skill/SKILL.md`

`mkSkill` is a `stdenvNoCC.mkDerivation` that copies a skill source directory to `$out/`, optionally patches YAML frontmatter via a Python script, and attaches passthru attributes (`.tools`, `.env`, `.secrets`, `.skillName`, `.isOpenclawSkill`). Name resolution: explicit `name` arg > `overrides.name` > `builtins.baseNameOf src`. Null secrets trigger a `throw` at eval time. The frontmatter patcher (`patch-skill-frontmatter.py`) does line-level replacement of top-level YAML keys — no YAML library dependency, just regex on `^key:` lines. Check builds 3 variants (basic, patched, named) and verifies both runtime output and eval-time passthru correctness.

### Chunk 2: Fetchers (`fromBundled`, `fromGitHub`)

**Files:** `nix/lib/fetchers.nix`, `nix/checks/skill-fetchers.nix`

`fromBundled` is a thin wrapper around `mkSkill` that sets `src` to `"${openclawSrc}/skills/${name}"` — zero extra network fetch since it uses the already-pinned openclaw source. `fromGitHub` wraps `fetchFromGitHub` + `mkSkill`, extracting a skill subdirectory from an arbitrary repo. Both pass through all `mkSkill` args (tools, env, secrets, overrides). The check builds github (bundled), weather (bundled with env/secrets), and tmux (fromGitHub re-using the pinned source to avoid CI fetches).

### Chunk 3: Skill catalog

**Files:** `nix/lib/skill-catalog.nix`, `nix/checks/skill-catalog.nix`

Starter catalog with 11 skills that have clear nixpkgs tool mappings: github, tmux, weather, session-logs, video-frames, himalaya, 1password, plus 4 tool-free skills (canvas, coding-agent, healthcheck, skill-creator). TODO at bottom for expanding. Check builds a representative subset and verifies passthru.

### Chunk 4: Library entrypoint + flake outputs

**Files:** `nix/lib/default.nix`, `flake.nix`

`nix/lib/default.nix` ties together mkSkill, fetchers, and catalog. `flake.nix` now exposes `skills.${system}.*` (catalog), `lib.${system}.{mkSkill,fromBundled,fromGitHub}` (builders), and 3 skill library checks.

### Chunk 5: Home Manager module integration

**Files:** `nix/modules/home-manager/openclaw/{options,files,config}.nix`

`skills` type changed to `listOf (either package mkSkillOption)`. `files.nix` partitions into `drvSkills`/`inlineSkills` — drv skills symlinked from store, inline skills use existing render logic. `config.nix` extracts `.tools` for PATH, `.env` for direct exports, `.secrets` for file-based runtime reads. Skill tools also added to `home.packages`.

### Chunk 6: NixOS module integration

**Files:** `nix/modules/nixos/{options,documents-skills,openclaw}.nix`

Same pattern: type union in options, partition in documents-skills, tool/env/secrets extraction in openclaw.nix gateway wrapper.

### Chunk 7: Extended checks

**Files:** `nix/checks/openclaw-hm-activation.nix`, `nix/checks/nixos-module-test.nix`, `nix/tests/hm-activation.py`

Both HM and NixOS VM tests now include a mkSkill derivation + inline skill. Verifies: skill dirs in workspace, gateway wrapper has tools on PATH, env vars exported.

### Chunk 8: `stateDir` for mkSkill + Google Calendar skill

**Files:** `nix/lib/mkSkill.nix`, `nix/lib/fetchers.nix`, `nix/lib/skill-catalog.nix`, `nix/lib/default.nix`, `nix/modules/nixos/documents-skills.nix`, `nix/modules/home-manager/openclaw/config.nix`, `nix/skills/google-calendar/SKILL.md`, `nix/checks/skill-mkSkill.nix`, `nix/checks/nixos-module-test.nix`, `nix/checks/openclaw-hm-activation.nix`, `nix/tests/hm-activation.py`, `nix/checks/skill-catalog.nix`

Skills that need persistent writable state (OAuth tokens, caches, configs) can now declare `stateDir = "name"`. The NixOS module creates the directory via systemd-tmpfiles at `workspace/.skill-state/<name>/`; the HM module does the same via activation script. Both `fromBundled` and `fromGitHub` fetchers now pass `stateDir` through to `mkSkill`.

First nix-native skill: `google-calendar` (gcalcli) with `stateDir = "gcalcli"` for OAuth token persistence. Lives in `nix/skills/` (not upstream), referenced directly via `mkSkill` in the catalog. The catalog now accepts `mkSkill` alongside `fromBundled` for skills with custom SKILL.md files.

Consumer usage: `skills = [ inputs.nix-moltbot.skills.${system}.google-calendar ];` — gcalcli lands on PATH and the writable state dir is created automatically.

**Bugs found during testing:**

- **HM test was grepping unit file, not wrapper script.** `systemctl --user cat` shows the unit file, but jq/env vars are in the wrapper script. Fixed to extract wrapper path from ExecStart and grep that instead.
- **systemd-tmpfiles unsafe path transition.** The `.skill-state` parent dir was implicitly created as `root:root` inside an `openclaw:openclaw`-owned workspace. tmpfiles refused to create child dirs due to the ownership transition. Fixed by adding an explicit `d` rule for `.skill-state` with correct ownership before per-skill subdirectory rules.
