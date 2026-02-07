# Pre-packaged skill catalog — curated fromBundled calls with verified tool mappings
#
# Each entry explicitly declares which nixpkgs packages the skill needs.
# Only skills with tools available in nixpkgs are included here.
# Skills needing steipete-tools or custom packages should use the plugin system
# or mkSkill directly.

{ lib, pkgs, fromBundled }:

{
  github = fromBundled {
    name = "github";
    tools = [ pkgs.gh ];
  };

  tmux = fromBundled {
    name = "tmux";
    tools = [ pkgs.tmux ];
  };

  weather = fromBundled {
    name = "weather";
    tools = [ pkgs.curl ];
  };

  session-logs = fromBundled {
    name = "session-logs";
    tools = [ pkgs.jq pkgs.ripgrep ];
  };

  video-frames = fromBundled {
    name = "video-frames";
    tools = [ pkgs.ffmpeg ];
  };

  himalaya = fromBundled {
    name = "himalaya";
    tools = [ pkgs.himalaya ];
  };

  _1password = fromBundled {
    name = "1password";
    tools = [ pkgs._1password-cli ];
  };

  # Skills with no tool dependencies (teaching-only / API-key-only)
  # Included because they're useful out of the box.

  canvas = fromBundled { name = "canvas"; };
  coding-agent = fromBundled { name = "coding-agent"; };
  healthcheck = fromBundled { name = "healthcheck"; };
  skill-creator = fromBundled { name = "skill-creator"; };

  # TODO: Expand catalog as more tools land in nixpkgs or steipete-tools
  # gets a skill-library-compatible interface. Candidates:
  #   bird, camsnap, oracle, peekaboo, sag, summarize, sonoscli, imsg,
  #   gogcli, blucli, gifgrep, openhue, obsidian-cli, etc.
}
