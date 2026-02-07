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
  env = {                     # optional: plain env vars (safe for Nix store)
    DEFAULT_BRANCH = "main";
  };
  secrets = {                 # optional: secret env vars (read from files at runtime)
    GITHUB_TOKEN = "/run/agenix/github-token";
  };
  overrides = {               # optional: patch frontmatter fields
    description = "Updated";
  };
}
```

Output: a derivation where `$out/` is a valid AgentSkills directory (`SKILL.md`, optionally `scripts/`, `references/`, `assets/`).

Passthru attributes:
- `.tools` — the package list (so the module can extract them for PATH)
- `.env` — plain env var attrset (exported directly in gateway wrapper)
- `.secrets` — secret env var attrset (file paths; contents read into env vars at runtime)
- `.skillName` — resolved name
- `.isOpenclawSkill = true` — type tag

### Environment & Secrets Model

Two mechanisms for env vars:

- **`env`** — plain key-value pairs, exported directly. Values end up in the Nix store (the gateway wrapper script). Use for non-sensitive configuration.
- **`secrets`** — values are **file paths only**. The gateway wrapper reads file contents into env vars at runtime. Secrets never touch the Nix store.

```bash
# From env:
export DEFAULT_BRANCH="main"

# From secrets:
GITHUB_TOKEN="$(cat "/run/agenix/github-token")"
export GITHUB_TOKEN
```

Secrets work with any secrets manager:

- **agenix**: `age.secrets.github-token.owner = "openclaw";`
- **sops-nix**: `sops.secrets.github-token = {};`
- **Plain files**: `echo "ghp_abc123" > ~/.secrets/github-token && chmod 600 ~/.secrets/github-token`

Null values in `secrets` trigger a build-time assertion — the user must provide a path.

If `overrides` is non-empty, a build-time script patches the YAML frontmatter. If empty, it's a plain copy.

**Location:** `nix/lib/mkSkill.nix`

### Layer 2: Fetchers

#### `fromBundled`

Uses the already-pinned openclaw source. No extra network fetch. Thin wrapper around `mkSkill` that sets `src` to the bundled skill path.

```nix
fromBundled {
  name = "github";         # dir name under openclaw's skills/
  tools = [ pkgs.gh ];     # explicit tool list
  env = {};                # optional plain env vars
  secrets = {};            # optional secrets (file paths)
  overrides = {};          # frontmatter patches
}
```

Tool lists are explicit — no eval-time YAML/JSON5 parsing. The catalog knows what each skill needs.

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

Each catalog entry is explicit about its tools:

```nix
github = fromBundled { name = "github"; tools = [ pkgs.gh ]; };
tmux = fromBundled { name = "tmux"; tools = [ pkgs.tmux ]; };
weather = fromBundled { name = "weather"; tools = [ pkgs.curl ]; };

# Skills needing secrets declare them (user overrides the values):
goplaces = fromBundled {
  name = "local-places";
  tools = [ pkgs.goplaces ];
  secrets = { GOOGLE_PLACES_API_KEY = null; };  # must be overridden
};
```

**Location:** `nix/lib/skill-catalog.nix`

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

### Tool + Env + Secrets Extraction

`config.nix` extracts `.tools`, `.env`, and `.secrets` from derivation skills and wires them into the gateway wrapper:

```nix
skillToolPackages = lib.flatten (map (s: s.tools or []) drvSkills);
skillEnv = lib.foldl' (acc: s: acc // (s.env or {})) {} drvSkills;
skillSecrets = lib.foldl' (acc: s: acc // (s.secrets or {})) {} drvSkills;
allExtraPackages = pluginPackages ++ skillToolPackages;
```

The gateway wrapper exports `env` values directly and reads `secrets` from files:

```bash
# Plain env
export DEFAULT_BRANCH="main"

# Secrets
GITHUB_TOKEN="$(cat "/run/agenix/github-token")"
export GITHUB_TOKEN
```

Secrets with `null` values trigger a build-time assertion — the user must provide a file path. This replaces the old `requiredEnv` pattern.

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
```

---

## Repo Directory Layout

```
nix/
  lib/                          # NEW
    default.nix                 # exports everything
    mkSkill.nix                 # builder
    fetchers.nix                # fromBundled, fromGitHub, fromClawHub
    skill-catalog.nix           # pre-packaged skills with explicit tool lists
  scripts/
    patch-skill-frontmatter.py  # NEW: build-time frontmatter patcher
  modules/
    home-manager/openclaw/
      options.nix               # MODIFIED: skills type accepts derivations
      files.nix                 # MODIFIED: partition drv vs inline skills
      config.nix                # MODIFIED: extract .tools + .env + .secrets from skills
    nixos/
      options.nix               # MODIFIED: skills type accepts derivations
      documents-skills.nix      # MODIFIED: partition drv vs inline skills
```

---

## Implementation Chunks

### Chunk 1: `mkSkill` + frontmatter patcher

Create `nix/lib/mkSkill.nix` and `nix/scripts/patch-skill-frontmatter.py`. The builder copies `src`, optionally patches frontmatter, attaches passthru (`.tools`, `.env`, `.secrets`, `.skillName`, `.isOpenclawSkill`). Test by building a skill from a local directory.

### Chunk 2: Fetchers (`fromBundled`, `fromGitHub`)

Create `nix/lib/fetchers.nix`. `fromBundled` is a thin wrapper setting `src` to the pinned openclaw source path. `fromGitHub` fetches and extracts a skill subdirectory. Both delegate to `mkSkill`.

### Chunk 3: Skill catalog

Create `nix/lib/skill-catalog.nix`. Call `fromBundled` for each of the 52 bundled skills with explicit tool lists.

### Chunk 4: Library entrypoint + flake outputs

Create `nix/lib/default.nix`. Modify `flake.nix` to expose `skills` and `lib` outputs.

### Chunk 5: Home Manager module integration

Modify `options.nix`, `files.nix`, `config.nix` to accept skill derivations alongside inline submodules. Extract `.tools` for PATH, `.env` for direct exports, `.secrets` for file-based exports. Null secrets trigger assertion failure.

### Chunk 6: NixOS module integration

Same changes applied to the NixOS module.

### Chunk 7: `fromClawHub` (deferred)

Add ClawHub fetcher once the API is verified.

### Chunk 8: Checks

Add `nix/checks/skill-library-test.nix` to verify catalog skills build. Wire into flake checks and `garnix.yaml`.

---

## Migration & Coexistence

- **Existing plugins:** Continue to work. Not removed, but no longer the recommended path for new skills.
- **Existing inline skills:** Continue to work. The submodule format remains supported.
- **First-party toggles:** Continue to work. Migration is straightforward:

```nix
# Before (plugin system — resolves full flake, heavier):
firstParty.summarize.enable = true;

# After (skill library — uses pinned source, lighter):
skills = [ nix-openclaw.skills.${system}.summarize ];
```

- **Name collisions:** If a skill derivation and a plugin provide the same skill name, Home Manager's file collision detection catches it at build time.
- **Long-term direction:** The skill library is the single recommended extension system. Plugins remain for backward compatibility but new documentation and examples should use skills.

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
                # Pre-packaged (zero config — no secrets needed)
                skills.github
                skills.summarize
                skills.tmux

                # Pre-packaged with secrets
                (skills.goplaces.override {
                  secrets.GOOGLE_PLACES_API_KEY = config.sops.secrets.goplaces.path;
                })

                # From GitHub
                (oc.fromGitHub {
                  owner = "BankrBot";
                  repo = "openclaw-skills";
                  skillPath = "skills/bankr";
                  rev = "abc123";
                  hash = "sha256-...";
                  tools = [ pkgs.nodejs ];
                })

                # Full control
                (oc.mkSkill {
                  src = ./my-skills/custom;
                  tools = [ pkgs.ripgrep pkgs.jq ];
                  env = { OUTPUT_FORMAT = "json"; };
                  secrets = {
                    MY_API_KEY = "/run/agenix/my-api-key";
                  };
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

## Design Decisions (Resolved)

1. **Explicit tool lists, no eval-time parsing.** The catalog explicitly declares which Nix packages each skill needs. No YAML/JSON5 frontmatter parsing at Nix eval time. Simpler, more reliable. The catalog IS the curated/verified layer — explicit tool mappings are the point.

2. **Flake output only, no overlay.** Skills are exposed as `nix-openclaw.skills.${system}.*`, not via the Nix overlay. Skills are a domain-specific concept, not general packages.

3. **Single extension system.** Upstream Openclaw distinguishes "skills" (SKILL.md teaching docs) from "plugins" (TypeScript gateway extensions). nix-openclaw's `openclawPlugin` pattern is closer to a skill bundle than a real plugin. The skill library subsumes this: `mkSkill` handles tools, env vars, and skill content in one unit. The existing `openclawPlugin` system and `firstParty.*.enable` toggles continue to work but are no longer the recommended path. New capabilities should use the skill library.

4. **Two-tier env model.** `env` for plain config (exported directly, safe in Nix store). `secrets` for sensitive values (file paths only, read at runtime, never in Nix store). Null values in `secrets` = required (build fails if not overridden). No separate `requiredEnv` mechanism. No `stateDirs` — dropped until there's a demonstrated need.
