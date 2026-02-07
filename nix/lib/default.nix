# Skill library entrypoint
#
# Wires together mkSkill, fetchers, and catalog.
# Called from flake.nix with system-specific pkgs.

{ lib, pkgs, openclawSrc }:

let
  mkSkill = import ./mkSkill.nix { inherit lib pkgs; };
  fetchers = import ./fetchers.nix { inherit lib pkgs mkSkill openclawSrc; };
  catalog = import ./skill-catalog.nix {
    inherit lib pkgs;
    inherit (fetchers) fromBundled;
  };
in {
  inherit mkSkill catalog;
  inherit (fetchers) fromBundled fromGitHub;
}
