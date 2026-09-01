{
  inputs = {
  };
  
  outputs = { ... }:
  let
  prefix = "";
  suffix = "-nube";
  in {
    # qixosConfigurations describes the qubes part of the qixOS configuration.
    # It contains a set of nix qubes (nubes) clusters. Each cluster contains
    # 1 template and a set of app VMs that depend on that template.
    # This configuration only describes the VM specific parts of the nubes.
    # It does not contain the configuration that is applied *inside* of the VM.
    # That part is relegated to the configuration pointed to by the `flakeUrl`
    # field of the cluster template.
    qixosConfigurations.xenon = {
      # The qubes tag which signifies the qube is managed by the qixos-rebuild runner
      # recommended is `created-by-<qixos-rebuild runner name>` since this is automatically
      # set by qubes on any qube created by this qube and is unforgeable
      managementTag = "created-by-qixos-admin";
      # Name of the template to clone when creating new templates.
      # It is not very important which qube this is since it will run `nixos-rebuild switch`
      # and completely overwrite its own config. However it will keep cached things in /nix/store
      # until those are cleaned up.
      #
      # It is important that it has the `managementTag` attached to it.
      baseTemplate = "qixos-admin-base-template";

      # Big nube cluster
      nubeClusters."${prefix}general${suffix}" = {
        template = {
          properties = {
            label = "black";
          };
          localFlake = {
            path = "users/op/nubes/templates/basic";
            output = "qixosTemplateConfigurations.default";
	  };
        };

        appVms."${prefix}dev${suffix}" = {
          properties = {
            label = "orange";
            netvm = "sys-firewall";
          };
          localFlake = {
            path = "users/op/nubes/appvms/dev-nube";
            output = "qixosAppConfigurations.default";
          };
        };

        appVms."${prefix}dev-llm${suffix}" = {
          properties = {
            label = "orange";
            netvm = "sys-firewall";
          };

          remoteFlake = {
            url = "git+https://github.com/originalposter/qixos-community?ref=unstable&dir=users/op/nubes/appvms/dev-nube";
            output = "qixosAppConfigurations.default";
          };
        };

        appVms."${prefix}qixos-dev${suffix}" = {
          properties = {
            label = "orange";
            netvm = "sys-firewall";
          };

          remoteFlake = {
            url = "git+https://github.com/originalposter/qixos-community?ref=test-suite-alpha&dir=users/op/nubes/appvms/qixos-dev";
            output = "qixosAppConfigurations.default";
          };
        };

        appVms."${prefix}signal${suffix}" = {
          properties = {
            label = "green";
            netvm = "sys-firewall";
          };
          localFlake = {
            path = "users/op/nubes/appvms/signal";
            output = "qixosAppConfigurations.${prefix}signal${suffix}";
          };
        };

        appVms."${prefix}zotero${suffix}" = {
          properties = {
            label = "green";
            netvm = "sys-firewall";
          };
          localFlake = {
            path = "users/op/nubes/appvms/zotero";
            output = "qixosAppConfigurations.${prefix}zotero${suffix}";
          };
        };
      };
      # Cluster for handling secrets
      nubeClusters."${prefix}template-secrets${suffix}" = {
        template = {
          properties = {
            label = "black";
          };

          localFlake = {
            path = "users/op/nubes/templates/basic";
            output = "qixosTemplateConfigurations.default";
          };
        };

        appVms."${prefix}pgp${suffix}" = {
          properties = {
            label = "purple";
            netvm = "none";
          };

          localFlake = {
            path = "users/op/nubes/appvms/pgp-nube";
            output = "qixosAppConfigurations.${prefix}pgp${suffix}";
          };
        };

        appVms."${prefix}split-ssh${suffix}" = {
          properties = {
            label = "purple";
            netvm = "none";
          };

          localFlake = {
            path = "users/op/nubes/appvms/split-ssh-nube";
            output = "qixosAppConfigurations.${prefix}split-ssh${suffix}";
          };
        };

      };



    };
  };
}
