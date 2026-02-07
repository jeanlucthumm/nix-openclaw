# mkSkill — the primitive skill builder
#
# Takes a skill source directory + Nix tool packages, produces a derivation.
# The output $out/ is a valid AgentSkills directory (SKILL.md, optionally scripts/, references/, assets/).
#
# Passthru attributes:
#   .tools          — package list (for PATH in gateway wrapper)
#   .env            — plain env var attrset (exported directly)
#   .secrets        — secret env var attrset (file paths; read at runtime)
#   .skillName      — resolved name
#   .isOpenclawSkill — type tag (always true)

{ lib, pkgs, python3 ? pkgs.python3 }:

{ src
, tools ? []
, env ? {}
, secrets ? {}
, overrides ? {}
, name ? null
}:

let
  patcher = ../scripts/patch-skill-frontmatter.py;

  # Resolve the skill name: explicit name > overrides.name > directory basename
  resolvedName =
    if name != null then name
    else if overrides ? name then overrides.name
    else builtins.baseNameOf (builtins.unsafeDiscardStringContext (toString src));

  hasOverrides = overrides != {};

  overrideArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (k: v: "'${k}=${v}'") overrides
  );

  # Assert that no secret has a null value (user must provide a file path)
  nullSecrets = lib.attrNames (lib.filterAttrs (_: v: v == null) secrets);
  secretAssertions = lib.forEach nullSecrets (name:
    throw "mkSkill: secret '${name}' for skill '${resolvedName}' is null — you must provide a file path (e.g. \"/run/agenix/${name}\")"
  );

in
pkgs.stdenvNoCC.mkDerivation {
  pname = "openclaw-skill-${resolvedName}";
  version = "0.1.0";
  inherit src;

  secretCheck = builtins.deepSeq secretAssertions true;
  nativeBuildInputs = lib.optionals hasOverrides [ python3 ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r . "$out/"
    ${lib.optionalString hasOverrides ''
      ${python3}/bin/python3 ${patcher} "$out/SKILL.md" "$out/SKILL.md" ${overrideArgs}
    ''}
    runHook postInstall
  '';

  passthru = {
    inherit tools env secrets;
    skillName = resolvedName;
    isOpenclawSkill = true;
  };
}
