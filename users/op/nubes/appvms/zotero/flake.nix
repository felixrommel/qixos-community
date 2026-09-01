{
  description = ''
    general nube cluster
    '';

  inputs = {
    opQixCommunity = {
      url = "path:../../../";
    };

    qixCore = {
      url = "git+https://github.com/originalposter/qixos?ref=master";
    };
  };

  outputs = { self, opQixCommunity, qixCore, ... }:
  {
    qixosAppConfigurations.zotero-nube = qixCore.lib.mkNubeApp {
      modules = [
        ({ pkgs, ... }: {
          home.packages = with pkgs; [zotero];
        })
#        opQixCommunity.nixosModules.modules.webdav { webdav.enable = true; }
        opQixCommunity.nixosModules.modules.blueprints.basic-template
      ];
    };

    nixosConfigurations.default = self.qixosAppConfigurations.signal-nube.nixosConfigurations.default;
  };
}
