---
name: update-jeanluc-fixes
description: Update this branch to point to the latest commit from jeanlucthumm/openclaw jeanluc-fixes branch
disable-model-invocation: true
---

Update openclaw-source.nix to the latest commit from jeanlucthumm/openclaw jeanluc-fixes branch:

1. Get the latest commit SHA:
   ```bash
   gh api repos/jeanlucthumm/openclaw/commits/jeanluc-fixes --jq '.sha'
   ```

2. Calculate the new source hash:
   ```bash
   nix-prefetch-git --url https://github.com/jeanlucthumm/openclaw --rev <NEW_SHA> --quiet
   ```
   Use the `hash` field (SRI format starting with `sha256-`).

3. Update `nix/sources/openclaw-source.nix`:
   - Set `rev` to the new commit SHA
   - Set `hash` to the new hash from step 2
   - Keep `pnpmDepsHash` the same (it only changes when pnpm-lock.yaml changes)

4. Build to verify (and get correct pnpmDepsHash if it changed):
   ```bash
   nix build .#openclaw-gateway
   ```
   If it fails with a hash mismatch, use the "got:" hash from the error.

5. Update `pnpmDepsHash` with the correct value and verify build succeeds.

6. Commit with message: "pin: update to jeanlucthumm/openclaw jeanluc-fixes <SHORT_SHA>"
