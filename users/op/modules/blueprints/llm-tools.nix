# LLM tooling, split out of the dev-nube blueprint so that a dev nube can be had
# without it. Import both for a nube that wants both.
#
# A function of the flake inputs it needs rather than a plain module, for the same
# reason dev-nube is one: the claude-code overlay comes from a flake input and a
# module has no way to reach it. Call it from a flake's outputs:
#
#   (opQixCommunity.nixosModules.modules.blueprints.llm-tools {
#     inherit claude-code-third-party;
#   })
{ claude-code-third-party }:
{ lib, pkgs, ... }:
{
  nixpkgs.overlays = [ claude-code-third-party.overlays.default ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  environment.systemPackages = with pkgs; [
    claude-code
    # Agent multiplexers, both terminal front ends over several coding agents at once.
    herdr
    paseo
    # The pi coding agent, whose binary is `pi`.
    pi-coding-agent
  ];
}
