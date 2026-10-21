# LLM agents, kept apart from the dev-nube blueprint. A function of its flake inputs,
# like the blueprint. Call it from a flake's outputs:
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
    # oh-my-pi, from can1357/oh-my-pi, whose binary is `omp`.
    omp
    opencode
  ];
}
