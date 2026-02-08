# Check: catalog entries build valid skill derivations
#
# Tests a representative subset of catalog entries to verify they all
# produce valid skill directories with correct passthru.

{ pkgs, lib, catalog }:

let
  # Pick entries that exercise different patterns:
  # tools, no tools, multiple tools
  testEntries = {
    inherit (catalog) github tmux weather session-logs canvas google-calendar;
  };

  checks = lib.mapAttrsToList (name: skill: ''
    echo "  ${name}..."
    test -f "${skill}/SKILL.md" || { echo "FAIL: ${name}/SKILL.md missing"; exit 1; }
  '') testEntries;

in
pkgs.runCommand "check-skill-catalog" {} ''
  set -euo pipefail

  echo "=== Catalog skill builds ==="
  ${lib.concatStringsSep "\n" checks}
  echo "PASS: all tested catalog entries build"

  mkdir -p "$out"
  touch "$out/passed"
''

# Eval-time: verify passthru on a few entries
// {
  passthruChecks = {
    githubIsSkill = assert catalog.github.isOpenclawSkill == true; true;
    githubName = assert catalog.github.skillName == "github"; true;
    githubTools = assert builtins.length catalog.github.tools == 1; true;
    canvasNoTools = assert catalog.canvas.tools == []; true;
    sessionLogsTwoTools = assert builtins.length catalog.session-logs.tools == 2; true;
    gcalName = assert catalog.google-calendar.skillName == "google-calendar"; true;
    gcalStateDir = assert catalog.google-calendar.stateDir == "gcalcli"; true;
    gcalTools = assert builtins.length catalog.google-calendar.tools == 1; true;
  };
}
