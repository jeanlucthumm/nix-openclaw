# RFC: Nix Skills Library

- Date: 2026-02-07
- Status: Draft
- Branch: `feat/nix-skills-library`

## The Problem

Openclaw has 52 bundled skills and 3000+ community skills following the AgentSkills spec. Each skill says things like `requires.bins: ["gh"]` — but the binary has to come from somewhere. Right now there are two paths:

1. **Skills-only** — user installs tools manually. Breaks when tools are missing.
2. **Full plugin flake** — `openclawPlugin` with build system, source code, the works. Overkill when the tool already exists in nixpkgs.

The gap: there's no way to say "give me the `github` skill with `pkgs.gh` on PATH" in one line.

## The Solution

A lightweight skill library with three layers:

```
Layer 3: Pre-packaged catalog    skills.github, skills.summarize, ...
            |
Layer 2: Fetchers                fromBundled, fromGitHub, fromClawHub
            |
Layer 1: mkSkill                 mkSkill { src = ./github; tools = [ pkgs.gh ]; }
```

Skills stay in standard AgentSkills format. No custom format. The value-add is Nix providing the tools.

---

## Architecture

### Layer 1: `mkSkill`

The primitive. Takes a skill source + Nix tool packages, produces a derivation.

```nix
mkSkill {
  src = ./my-skill;           # dir containing SKILL.md
  tools = [ pkgs.gh ];        # Nix packages to put on PATH
  overrides = {               # optional: patch frontmatter fields
    description = "Updated";
  };
}
```

Output: a derivation where `$out/` is a valid AgentSkills directory (`SKILL.md`, optionally `scripts/`, `references/`, `assets/`).

Passthru attributes:
- `.tools` — the package list (so the module can extract them for PATH)
- `.skillName` — resolved name
- `.isOpenclawSkill = true` — type tag

If `overrides` is non-empty, a build-time script patches the YAML frontmatter. If empty, it's a plain copy.

**Location:** `nix/lib/mkSkill.nix`

### Layer 2: Fetchers

#### `fromBundled`

Uses the already-pinned openclaw source. No extra network fetch.

```nix
fromBundled {
  name = "github";         # dir name under openclaw's skills/
  extraTools = [];          # additional packages beyond auto-resolved
  overrides = {};           # frontmatter patches
}
```

Resolves `requires.bins` from the SKILL.md via `binToNixPkg` mapping. This is the workhorse for the pre-packaged catalog.

#### `fromGitHub`

Fetches a skill from any GitHub repo.

```nix
fromGitHub {
  owner = "BankrBot";
  repo = "openclaw-skills";
  skillPath = "skills/bankr";  # subdir within repo
  rev = "abc123";
  hash = "sha256-...";
  extraTools = [ pkgs.nodejs ];
}
```

#### `fromClawHub`

Fetches from the ClawHub registry. Lower priority — the API needs verification. Deferred to a later chunk.

```nix
fromClawHub {
  slug = "postgres-backups";
  hash = "sha256-...";
}
```

**Location:** `nix/lib/fetchers.nix`

### Layer 3: Pre-packaged Catalog

Curated `fromBundled` calls with verified tool mappings, exported as a flake output:

```nix
nix-openclaw.skills.${system}.github     # → mkSkill derivation
nix-openclaw.skills.${system}.summarize  # → mkSkill derivation
```

Each catalog entry is trivial:

```nix
github = fromBundled { name = "github"; };
tmux = fromBundled { name = "tmux"; };
weather = fromBundled { name = "weather"; };
```

The `binToNixPkg` mapping does the heavy lifting of resolving `requires.bins` to nixpkgs attributes.

**Location:** `nix/lib/skill-catalog.nix`

### `binToNixPkg` Mapping

A simple attrset mapping binary names to Nix packages:

```nix
{
  gh = pkgs.gh;
  jq = pkgs.jq;
  curl = pkgs.curl;
  rg = pkgs.ripgrep;
  tmux = pkgs.tmux;
  ffmpeg = pkgs.ffmpeg;
  uv = pkgs.uv;
  # ...
  # null = not in nixpkgs, skipped with warning
  clawhub = null;
  memo = null;
}
```

Grows over time. Tools mapped to `null` are skipped — the skill still loads, the tool is just the user's responsibility.

**Location:** `nix/lib/binToNixPkg.nix`

---

## Module Integration

### Option Type Change

`programs.openclaw.skills` currently accepts a `listOf mkSkillOption` (submodule attrsets). It needs to also accept `mkSkill` derivations.

```nix
skills = lib.mkOption {
  type = lib.types.listOf (lib.types.either
    lib.types.package       # mkSkill derivation
    mkSkillOption           # existing submodule format
  );
};
```

**File:** `nix/modules/home-manager/openclaw/options.nix`

### Skill Partitioning

`files.nix` partitions the skills list:

```nix
isSkillDrv = s: s ? isOpenclawSkill && s.isOpenclawSkill;
drvSkills = filter isSkillDrv cfg.skills;
inlineSkills = filter (s: !(isSkillDrv s)) cfg.skills;
```

Derivation skills get symlinked directly. Inline skills use existing `renderSkill` logic.

**File:** `nix/modules/home-manager/openclaw/files.nix`

### Tool Extraction

`config.nix` extracts `.tools` from derivation skills and adds them to the gateway wrapper PATH alongside plugin tools:

```nix
skillToolPackages = lib.flatten (map (s: s.tools or []) drvSkills);
allExtraPackages = pluginPackages ++ skillToolPackages;
```

**File:** `nix/modules/home-manager/openclaw/config.nix`

### NixOS Module

Same pattern applied to `nix/modules/nixos/options.nix` and `documents-skills.nix`.

---

## Flake Outputs

```nix
# Per-system outputs (new):
skills = skillLib.catalog;           # attrset of skill derivations
lib.mkSkill = skillLib.mkSkill;
lib.fromBundled = skillLib.fromBundled;
lib.fromGitHub = skillLib.fromGitHub;
lib.binToNixPkg = skillLib.binToNixPkg;
```

---

## Repo Directory Layout

```
nix/
  lib/                          # NEW
    default.nix                 # exports everything
    mkSkill.nix                 # builder
    fetchers.nix                # fromBundled, fromGitHub, fromClawHub
    binToNixPkg.nix             # binary → package mapping
    skill-catalog.nix           # pre-packaged skills
  scripts/
    patch-skill-frontmatter.py  # NEW: build-time frontmatter patcher
  modules/
    home-manager/openclaw/
      options.nix               # MODIFIED
      files.nix                 # MODIFIED
      config.nix                # MODIFIED
    nixos/
      options.nix               # MODIFIED
      documents-skills.nix      # MODIFIED
```

---

## Implementation Chunks

### Chunk 1: `mkSkill` + frontmatter patcher

Create `nix/lib/mkSkill.nix` and `nix/scripts/patch-skill-frontmatter.py`. The builder copies `src`, optionally patches frontmatter, attaches passthru. Test by building a skill from a local directory.

### Chunk 2: `binToNixPkg` mapping

Create `nix/lib/binToNixPkg.nix`. Map all binary names from the 52 bundled skills to nixpkgs attributes (or null). Standalone attrset, no deps.

### Chunk 3: `fromBundled` fetcher

Create `nix/lib/fetchers.nix`. Uses pinned openclaw source + `binToNixPkg` to resolve tools automatically. Also includes `fromGitHub`.

### Chunk 4: Skill catalog

Create `nix/lib/skill-catalog.nix`. Call `fromBundled` for each of the 52 bundled skills.

### Chunk 5: Library entrypoint + flake outputs

Create `nix/lib/default.nix`. Modify `flake.nix` to expose `skills` and `lib` outputs.

### Chunk 6: Home Manager module integration

Modify `options.nix`, `files.nix`, `config.nix` to accept and handle skill derivations.

### Chunk 7: NixOS module integration

Same changes applied to the NixOS module.

### Chunk 8: `fromClawHub` (deferred)

Add ClawHub fetcher once the API is verified.

### Chunk 9: Checks

Add `nix/checks/skill-library-test.nix` to verify catalog skills build. Wire into flake checks and `garnix.yaml`.

---

## Migration & Coexistence

- **Existing plugins:** Untouched. Plugin system continues to work.
- **Existing inline skills:** Untouched. The submodule format remains supported.
- **First-party toggles:** Continue to work. Users can optionally migrate:

```nix
# Before:
firstParty.summarize.enable = true;

# After (lighter, no plugin flake resolution):
skills = [ nix-openclaw.skills.${system}.summarize ];
```

- **Name collisions:** If a skill derivation and a plugin provide the same skill name, Home Manager's file collision detection catches it at build time.

---

## Example User Config

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nix-openclaw.url = "github:openclaw/nix-openclaw";
  };

  outputs = { nixpkgs, home-manager, nix-openclaw, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nix-openclaw.overlays.default ];
      };
      skills = nix-openclaw.skills.${system};
      oc = nix-openclaw.lib.${system};
    in {
      homeConfigurations."user" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nix-openclaw.homeManagerModules.openclaw
          {
            programs.openclaw = {
              documents = ./documents;
              config.channels.telegram = { /* ... */ };

              skills = [
                # Pre-packaged (zero config)
                skills.github
                skills.summarize
                skills.tmux

                # From GitHub
                (oc.fromGitHub {
                  owner = "BankrBot";
                  repo = "openclaw-skills";
                  skillPath = "skills/bankr";
                  rev = "abc123";
                  hash = "sha256-...";
                  extraTools = [ pkgs.nodejs ];
                })

                # Full control
                (oc.mkSkill {
                  src = ./my-skills/custom;
                  tools = [ pkgs.ripgrep pkgs.jq ];
                })

                # Inline (existing format, still works)
                {
                  name = "my-inline-skill";
                  description = "Does things";
                  body = "# My Skill\nRun `my-tool` to do the thing.";
                }
              ];
            };
          }
        ];
      };
    };
}
```

---

## Open Questions

1. **Frontmatter parsing at eval time:** `fromBundled` needs to read `requires.bins` from SKILL.md to auto-resolve tools. The metadata is JSON embedded in YAML frontmatter. Extractable with `builtins.readFile` + string manipulation + `builtins.fromJSON`, but fragile. Alternative: the catalog explicitly lists bin names instead of parsing. Leaning toward explicit lists — simpler, more reliable.

2. **Overlay integration:** Should the skill catalog be available via the overlay too, or just as a flake output? Flake output is simpler.

3. **First-party plugin deprecation:** Should the `firstParty.*.enable` toggles eventually be deprecated in favor of the skill catalog? The skill catalog is lighter (no `builtins.getFlake`), but plugins can do more (stateDirs, requiredEnv validation, config.json). Probably keep both.
