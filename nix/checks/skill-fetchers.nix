# Check: fromBundled and fromGitHub fetchers produce valid skill derivations
#
# Tests:
# 1. fromBundled builds a skill from the pinned openclaw source
# 2. fromBundled passthru attrs are correct
# 3. fromGitHub builds a skill from a pinned GitHub repo

{ pkgs, lib, mkSkill, openclawSrc }:

let
  fetchers = import ../lib/fetchers.nix { inherit lib pkgs mkSkill openclawSrc; };

  # Test 1: fromBundled with github skill
  bundled = fetchers.fromBundled {
    name = "github";
    tools = [ pkgs.gh ];
  };

  # Test 2: fromBundled with env and secrets
  bundledWithEnv = fetchers.fromBundled {
    name = "weather";
    tools = [ pkgs.curl ];
    env = { DEFAULT_UNIT = "metric"; };
    secrets = { WEATHER_API_KEY = "/run/agenix/weather-key"; };
  };

  # Test 3: fromGitHub — use the same pinned openclaw source as a "GitHub repo"
  # to avoid needing a separate fetch in CI
  sourceInfo = import ../sources/openclaw-source.nix;
  fromGH = fetchers.fromGitHub {
    owner = sourceInfo.owner;
    repo = sourceInfo.repo;
    rev = sourceInfo.rev;
    hash = sourceInfo.hash;
    skillPath = "skills/tmux";
    tools = [ pkgs.tmux ];
  };

in
pkgs.runCommand "check-skill-fetchers" {} ''
  set -euo pipefail

  echo "=== Test 1: fromBundled (github) ==="
  test -f "${bundled}/SKILL.md" || { echo "FAIL: SKILL.md missing"; exit 1; }
  grep -q "github" "${bundled}/SKILL.md" || { echo "FAIL: github not in SKILL.md"; exit 1; }
  echo "PASS: fromBundled github builds"

  echo "=== Test 2: fromBundled with env/secrets ==="
  test -f "${bundledWithEnv}/SKILL.md" || { echo "FAIL: SKILL.md missing"; exit 1; }
  echo "PASS: fromBundled with env/secrets builds"

  echo "=== Test 3: fromGitHub ==="
  test -f "${fromGH}/SKILL.md" || { echo "FAIL: SKILL.md missing"; exit 1; }
  grep -q "tmux" "${fromGH}/SKILL.md" || { echo "FAIL: tmux not in SKILL.md"; exit 1; }
  echo "PASS: fromGitHub builds"

  echo "All fetcher checks passed."
  mkdir -p "$out"
  touch "$out/passed"
''

# Eval-time assertions
// {
  passthruChecks = {
    bundledIsSkill = assert bundled.isOpenclawSkill == true; true;
    bundledName = assert bundled.skillName == "github"; true;
    bundledTools = assert builtins.length bundled.tools == 1; true;
    bundledEnv = assert bundledWithEnv.env.DEFAULT_UNIT == "metric"; true;
    bundledSecrets = assert bundledWithEnv.secrets.WEATHER_API_KEY == "/run/agenix/weather-key"; true;
    fromGHIsSkill = assert fromGH.isOpenclawSkill == true; true;
    fromGHName = assert fromGH.skillName == "tmux"; true;
  };
}
