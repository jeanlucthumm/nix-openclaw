# Skills Library Reference

The skills library lets you add Openclaw capabilities with one line. Each skill bundles a teaching document (SKILL.md) with the Nix packages needed to make it work.

## Three ways to add skills

### 1. From the catalog

Pre-packaged skills with verified tool mappings. Zero config.

```nix
{ nix-openclaw, ... }:
let
  skills = nix-openclaw.skills.${system};
in {
  programs.openclaw.skills = [
    skills.github
    skills.tmux
    skills.weather
  ];
}
```

### 2. From a GitHub repo

Any repo following the AgentSkills format (a directory with a `SKILL.md`).

```nix
{ nix-openclaw, pkgs, ... }:
let
  oc = nix-openclaw.lib.${system};
in {
  programs.openclaw.skills = [
    (oc.fromGitHub {
      owner = "someone";
      repo = "cool-skills";
      skillPath = "skills/cool-thing";  # subdirectory within repo
      rev = "abc123";
      hash = "sha256-...";
      tools = [ pkgs.nodejs ];
    })
  ];
}
```

### 3. Custom with `mkSkill`

Full control over source, tools, env, secrets, and frontmatter.

```nix
{ nix-openclaw, pkgs, ... }:
let
  oc = nix-openclaw.lib.${system};
in {
  programs.openclaw.skills = [
    (oc.mkSkill {
      src = ./my-skills/custom;
      tools = [ pkgs.ripgrep pkgs.jq ];
      env = { OUTPUT_FORMAT = "json"; };
      secrets = {
        MY_API_KEY = "/run/agenix/my-api-key";
      };
      overrides = {
        description = "My custom skill";
      };
    })
  ];
}
```

You can mix all three in the same `skills` list, alongside inline skills (the existing submodule format).

---

## Catalog

Skills with clear nixpkgs tool mappings. More will be added as mappings are verified.

| Skill | Tools installed | What it does |
|-------|----------------|--------------|
| `github` | `gh` | GitHub CLI (issues, PRs, runs, API) |
| `tmux` | `tmux` | Terminal multiplexer sessions |
| `weather` | `curl` | Weather lookups |
| `session-logs` | `jq`, `ripgrep` | Search and filter session logs |
| `video-frames` | `ffmpeg` | Extract frames from video |
| `himalaya` | `himalaya` | Email client |
| `_1password` | `_1password-cli` | 1Password vault access |
| `google-calendar` | `gcalcli` | Google Calendar (view, create, edit, delete events) |
| `canvas` | *(none)* | Canvas drawing instructions |
| `coding-agent` | *(none)* | Coding agent patterns |
| `healthcheck` | *(none)* | System health checks |
| `skill-creator` | *(none)* | Create new skills |

---

## API Reference

### `mkSkill`

The primitive builder. All other functions delegate to this.

```nix
mkSkill {
  src = ./my-skill;           # directory containing SKILL.md (required)
  name = "my-skill";          # skill name (default: basename of src)
  tools = [ pkgs.gh ];        # Nix packages to put on PATH (default: [])
  env = {                     # plain env vars, safe for Nix store (default: {})
    DEFAULT_BRANCH = "main";
  };
  secrets = {                 # secret env vars — file paths only (default: {})
    GITHUB_TOKEN = "/run/agenix/github-token";
  };
  stateDir = "my-tool";       # writable state dir name (default: null)
  overrides = {               # patch YAML frontmatter fields (default: {})
    description = "Updated";
  };
}
```

**Output:** a derivation where `$out/` is a valid AgentSkills directory.

**Passthru attributes** (accessible on the derivation):

| Attribute | Type | Description |
|-----------|------|-------------|
| `.tools` | `[package]` | Packages for PATH |
| `.env` | `{string}` | Plain env vars |
| `.secrets` | `{string}` | Secret file paths |
| `.stateDir` | `string?` | Writable state directory name (or `null`) |
| `.skillName` | `string` | Resolved skill name |
| `.isOpenclawSkill` | `bool` | Always `true` (type tag) |

**Name resolution order:** explicit `name` arg > `overrides.name` > `builtins.baseNameOf src`.

### `fromBundled`

Uses the already-pinned Openclaw source. No extra network fetch.

```nix
fromBundled {
  name = "github";           # directory name under openclaw's skills/ (required)
  tools = [ pkgs.gh ];       # (same args as mkSkill, minus src)
  env = {};
  secrets = {};
  stateDir = null;
  overrides = {};
}
```

### `fromGitHub`

Fetches a skill from any GitHub repo.

```nix
fromGitHub {
  owner = "someone";         # GitHub owner (required)
  repo = "cool-skills";      # GitHub repo (required)
  rev = "abc123";            # commit SHA (required)
  hash = "sha256-...";       # SRI hash (required)
  skillPath = "skills/cool"; # subdirectory within repo (default: repo root)
  name = "cool";             # skill name (default: basename of skillPath)
  tools = [ pkgs.nodejs ];   # (same args as mkSkill, minus src)
  env = {};
  secrets = {};
  stateDir = null;
  overrides = {};
}
```

---

## Secrets Model

Two mechanisms for environment variables:

**`env`** — plain key-value pairs. Values end up in the Nix store (the gateway wrapper script). Use for non-sensitive configuration.

```bash
# Generated in gateway wrapper:
export DEFAULT_BRANCH="main"
```

**`secrets`** — values are file paths only. The gateway wrapper reads file contents into env vars at runtime. Secrets never touch the Nix store.

```bash
# Generated in gateway wrapper:
GITHUB_TOKEN="$(cat "/run/agenix/github-token")"
export GITHUB_TOKEN
```

**Null values in `secrets` fail the build.** If a catalog skill declares a required secret, you must provide the file path:

```nix
# This fails at build time:
skills.goplaces  # has secrets.GOOGLE_PLACES_API_KEY = null

# This works:
(skills.goplaces.override {
  secrets.GOOGLE_PLACES_API_KEY = "/run/agenix/goplaces-key";
})
```

Works with any secrets manager: agenix, sops-nix, plain files.

---

## State Directories

Skills that need persistent writable state (OAuth tokens, caches, config files) can declare a `stateDir`. The modules create a writable directory at `workspace/.skill-state/<stateDir>/`.

```nix
mkSkill {
  src = ./my-oauth-tool;
  tools = [ pkgs.my-oauth-tool ];
  stateDir = "my-oauth-tool";  # creates workspace/.skill-state/my-oauth-tool/
}
```

The SKILL.md tells the agent to pass this path to the tool (e.g., `--config-folder workspace/.skill-state/my-oauth-tool/`). No env var injection needed — the agent knows the workspace root.

**How it's created:**
- **NixOS module**: `systemd-tmpfiles` rule (`d` type, owned by service user)
- **Home Manager**: `mkdir -p` in the activation script

**Example** — `google-calendar` uses this for gcalcli's OAuth tokens:

```nix
skills.google-calendar  # stateDir = "gcalcli", tools = [ gcalcli ]
```

After first setup (`gcalcli init`), the refresh token persists across service restarts and rebuilds because the state directory is outside the Nix store.

---

## How It Works

When you add a skill derivation to `programs.openclaw.skills`:

1. The module partitions skills into derivation-based (from the library) and inline (submodule attrsets)
2. Derivation skills get symlinked from the Nix store to `~/.openclaw/workspace/skills/<name>/`
3. The gateway wrapper script is updated:
   - `.tools` packages added to `PATH`
   - `.env` values exported directly
   - `.secrets` file paths read with `cat` and exported at runtime
4. Skill tool packages are added to `home.packages` so they're available on your regular PATH too

The same pattern applies to the NixOS module (`services.openclaw`), using tmpfiles rules instead of Home Manager symlinks.

---

## Mixing with Plugins and Inline Skills

All three formats work together in the same `skills` list:

```nix
programs.openclaw.skills = [
  # Skill library derivation
  skills.github

  # Inline skill (existing format, still works)
  {
    name = "my-inline-skill";
    description = "Does things";
    body = "# My Skill\nRun `my-tool` to do the thing.";
    mode = "inline";
  }
];

# Plugins still work too (separate option)
programs.openclaw.plugins = [
  { source = "github:owner/full-plugin"; }
];
```

Name collisions between skills and plugins are caught at build time.

---

## Flake Outputs

```nix
# Per-system:
nix-openclaw.skills.${system}.*                  # catalog derivations
nix-openclaw.lib.${system}.mkSkill               # primitive builder
nix-openclaw.lib.${system}.fromBundled            # pinned source wrapper
nix-openclaw.lib.${system}.fromGitHub             # GitHub fetcher

# Checks:
nix-openclaw.checks.${system}.skill-mkSkill       # mkSkill unit tests
nix-openclaw.checks.${system}.skill-fetchers      # fetcher unit tests
nix-openclaw.checks.${system}.skill-catalog        # catalog build tests
```

---

## Adding Skills to the Catalog

To add a new skill to the catalog, edit `nix/lib/skill-catalog.nix`.

**Upstream skill** (SKILL.md lives in the openclaw repo):

```nix
my-new-skill = fromBundled {
  name = "my-new-skill";     # must match directory name in openclaw's skills/
  tools = [ pkgs.some-tool ]; # explicit — no magic, no YAML parsing
};
```

**Nix-native skill** (SKILL.md lives in `nix/skills/`):

```nix
my-new-skill = mkSkill {
  src = ../skills/my-new-skill;
  name = "my-new-skill";
  tools = [ pkgs.some-tool ];
  stateDir = "my-tool";       # if the tool needs writable state
};
```

Use nix-native skills when the SKILL.md doesn't exist upstream, or when you need a custom teaching document for a nixpkgs tool.

The tool list is explicit by design. The catalog is the curated/verified layer — we don't parse skill frontmatter at eval time.
