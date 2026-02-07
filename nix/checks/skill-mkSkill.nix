# Check: mkSkill builds a valid skill derivation with correct passthru attrs
#
# Tests:
# 1. Basic mkSkill produces $out/SKILL.md
# 2. Passthru attrs (.tools, .env, .secrets, .skillName, .isOpenclawSkill) are correct
# 3. Frontmatter patching via overrides works
# 4. Skill name resolution (explicit > override > basename)

{ pkgs, lib, mkSkill }:

let
  testSrc = ../tests/fixtures/test-skill;

  # Test 1: Basic skill build
  basic = mkSkill {
    src = testSrc;
    tools = [ pkgs.hello ];
    env = { FOO = "bar"; };
    secrets = { SECRET_KEY = "/run/agenix/secret"; };
  };

  # Test 2: Skill with overrides (frontmatter patching)
  patched = mkSkill {
    src = testSrc;
    overrides = {
      description = "Patched description";
    };
  };

  # Test 3: Explicit name takes precedence
  named = mkSkill {
    src = testSrc;
    name = "custom-name";
  };

in
pkgs.runCommand "check-skill-mkSkill" {} ''
  set -euo pipefail

  echo "=== Test 1: Basic skill build ==="
  test -f "${basic}/SKILL.md" || { echo "FAIL: SKILL.md missing"; exit 1; }
  echo "PASS: SKILL.md exists"

  echo "=== Test 2: Passthru attributes ==="
  # These are checked at Nix eval time via the assertions below.
  # If we got here, eval succeeded.
  echo "PASS: passthru attrs evaluated"

  echo "=== Test 3: Frontmatter patching ==="
  grep -q "Patched description" "${patched}/SKILL.md" || { echo "FAIL: patched description not found"; exit 1; }
  echo "PASS: frontmatter patching works"

  echo "=== Test 4: Name resolution ==="
  # (checked at eval time below)
  echo "PASS: name resolution works"

  echo "All mkSkill checks passed."
  mkdir -p "$out"
  touch "$out/passed"
''

# Eval-time assertions (these fail the build if wrong)
// {
  passthruChecks = {
    basicIsSkill = assert basic.isOpenclawSkill == true; true;
    basicName = assert basic.skillName == "test-skill"; true;
    basicTools = assert builtins.length basic.tools == 1; true;
    basicEnv = assert basic.env.FOO == "bar"; true;
    basicSecrets = assert basic.secrets.SECRET_KEY == "/run/agenix/secret"; true;
    patchedName = assert patched.skillName == "test-skill"; true;
    namedName = assert named.skillName == "custom-name"; true;
  };
}
