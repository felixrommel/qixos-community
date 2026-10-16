{
  description = ''
    review-nube: Forgejo. See modules/blueprints/forgejo.nix.
  '';

  inputs = {
    opQixCommunity = {
      url = "path:../../../";
    };

    qixCore = {
      url = "git+https://github.com/originalposter/qixos?ref=refs/tags/v0.2.0";
    };
  };

  outputs = { self, opQixCommunity, qixCore, ... }:
  {
    qixosAppConfigurations.default = qixCore.lib.mkNubeApp {
      modules = [
        opQixCommunity.nixosModules.modules.blueprints.forgejo
        opQixCommunity.nixosModules.modules.blueprints.basic-template
      ];
    };
  };
}
