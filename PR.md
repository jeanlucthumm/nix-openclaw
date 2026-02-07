# PR: Nix Skills Library

## RFC

@docs/rfc/2026-02-07-nix-skills-library.md

## Summary

`mkSkill` + fetchers + pre-packaged catalog for bundling AgentSkills-format skills with Nix tool dependencies. Users pick skills from a catalog and get the tools on PATH automatically.

```nix
skills = with nix-openclaw.skills.${system}; [
  github      # bundles pkgs.gh
  summarize   # bundles summarize CLI
  tmux        # bundles pkgs.tmux
];
```

## Implementation Log

### Chunk 1: `mkSkill` + frontmatter patcher

**Files:** `nix/lib/mkSkill.nix`, `nix/scripts/patch-skill-frontmatter.py`, `nix/checks/skill-mkSkill.nix`, `nix/tests/fixtures/test-skill/SKILL.md`

`mkSkill` is a `stdenvNoCC.mkDerivation` that copies a skill source directory to `$out/`, optionally patches YAML frontmatter via a Python script, and attaches passthru attributes (`.tools`, `.env`, `.secrets`, `.skillName`, `.isOpenclawSkill`). Name resolution: explicit `name` arg > `overrides.name` > `builtins.baseNameOf src`. Null secrets trigger a `throw` at eval time. The frontmatter patcher (`patch-skill-frontmatter.py`) does line-level replacement of top-level YAML keys — no YAML library dependency, just regex on `^key:` lines. Check builds 3 variants (basic, patched, named) and verifies both runtime output and eval-time passthru correctness.

### Chunk 2: Fetchers (`fromBundled`, `fromGitHub`)

**Files:** `nix/lib/fetchers.nix`, `nix/checks/skill-fetchers.nix`

`fromBundled` is a thin wrapper around `mkSkill` that sets `src` to `"${openclawSrc}/skills/${name}"` — zero extra network fetch since it uses the already-pinned openclaw source. `fromGitHub` wraps `fetchFromGitHub` + `mkSkill`, extracting a skill subdirectory from an arbitrary repo. Both pass through all `mkSkill` args (tools, env, secrets, overrides). The check builds github (bundled), weather (bundled with env/secrets), and tmux (fromGitHub re-using the pinned source to avoid CI fetches).
