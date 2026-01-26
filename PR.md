# PR: Add NixOS module for isolated system user

## Issue

https://github.com/clawdbot/nix-clawdbot/issues/22

Upstream issue: https://github.com/clawdbot/clawdbot/issues/2341

## Goal

Add a NixOS module (`nixosModules.clawdbot`) that runs the gateway as an isolated system user instead of the personal user account.

## Security Motivation

Currently the gateway runs as the user's personal account, giving the LLM full access to SSH keys, credentials, personal files, etc. Running as a dedicated locked-down user contains the blast radius if the LLM is compromised.

## Implementation Plan

1. Create `nix/modules/nixos/clawdbot.nix` (new NixOS module)
2. Create dedicated `clawdbot` system user with minimal privileges
3. Run gateway as system-level systemd service (not user service)
4. Apply systemd hardening:
   - `DynamicUser=true` or dedicated user
   - `ProtectHome=true`
   - `PrivateTmp=true`
   - `NoNewPrivileges=true`
   - `ProtectSystem=strict`
5. Handle credential management (Claude OAuth in isolated user's home)
6. Export as `nixosModules.clawdbot` in flake.nix

## Reference

- Existing home-manager module: `nix/modules/home-manager/clawdbot.nix`
- Systemd service definition: lines 803-829
- The home-manager module can coexist for users who prefer user-level service

## Notes

- This branch has PR #10 cherry-picked (NixOS/aarch64 support fixes)
- Claude OAuth credentials need separate setup for the clawdbot user
