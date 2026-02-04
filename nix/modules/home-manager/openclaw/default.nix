{ config, lib, pkgs, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule [ "programs" "openclaw" "firstParty" ] [ "programs" "openclaw" "bundledPlugins" ])
    (lib.mkRenamedOptionModule [ "programs" "openclaw" "plugins" ] [ "programs" "openclaw" "customPlugins" ])
    ./options.nix
    ./config.nix
  ];
}
