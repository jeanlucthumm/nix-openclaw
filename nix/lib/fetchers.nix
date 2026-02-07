# Skill fetchers — convenience wrappers around mkSkill
#
# fromBundled: uses the already-pinned openclaw source (no extra fetch)
# fromGitHub:  fetches a skill from any GitHub repo

{ lib, pkgs, mkSkill, openclawSrc }:

{
  # fromBundled — thin wrapper that sets src to the bundled skill path
  #
  # openclawSrc is the fetched openclaw source tree; skills live at skills/<name>/
  fromBundled =
    { name
    , tools ? []
    , env ? {}
    , secrets ? {}
    , overrides ? {}
    }:
    mkSkill {
      inherit name tools env secrets overrides;
      src = "${openclawSrc}/skills/${name}";
    };

  # fromGitHub — fetches a skill from any GitHub repo
  fromGitHub =
    { owner
    , repo
    , rev
    , hash
    , skillPath ? ""
    , tools ? []
    , env ? {}
    , secrets ? {}
    , overrides ? {}
    , name ? null
    }:
    let
      fullSrc = pkgs.fetchFromGitHub {
        inherit owner repo rev hash;
      };
      src = if skillPath == "" then fullSrc else "${fullSrc}/${skillPath}";
    in
    mkSkill {
      inherit src tools env secrets overrides;
      name = if name != null then name
        else if skillPath != "" then builtins.baseNameOf skillPath
        else repo;
    };
}
