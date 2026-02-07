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
