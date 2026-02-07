# jeanluc-fixes branch

This branch tracks a custom fork of openclaw with fixes for personal deployment.

## Source pin

- Fork: `jeanlucthumm/openclaw` branch `jeanluc-fixes`
- Pin file: `nix/sources/openclaw-source.nix`
- Update skill: `/update-jeanluc-fixes`

## Server deployment

The nix-moltbot package is deployed to a personal server via the `~/nix` flake:

- **Flake location**: `~/nix/flake.nix` (managed by yadm, not git)
- **Input reference**: `nix-moltbot.url = "path:/home/jeanluc/Code/nix-openclaw"`
- **Deploy command**: `deploy .#server` (deploys to server.lan)
- **Server docs**: `~/nix/CLAUDE.md`

### Server notes

- Server is at `server.lan`
- Server uses nushell - SSH commands should use nushell syntax
- Secrets managed with agenix
- Use `manix` to search Nix options
