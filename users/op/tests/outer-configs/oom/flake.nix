{
  description = ''
    Outer config for the OOM scenario: one template given too little memory to evaluate
    its own configuration, so the nix build inside qixos.Switch is killed part way.

    Its own scenario rather than a variant of smoke, because applying this is meant to
    fail and would take the other scenario's nubes down with it.

    The kill comes from one deliberately expensive nube rather than from starving the
    template outright. Starving it alone did not work: at memory=600 a switch thrashed
    against swap for over ten minutes without ever being killed. Demanding more than
    memory plus swap can hold gets there in one allocation instead.

    The template's memory and the nube's ENTRIES want tuning against a real run. Too
    much memory and the build finishes; too little and the qube never boots, so qrexec
    refuses and the switch fails without an error code. The test reports those two cases
    differently from each other and from a pass, so a wrong value says which way it is
    wrong.
    '';

  inputs = {
  };

  outputs = { ... }:
  let
    prefix = "test-oom-";
    adminName = "qixos-admin-test";

    moderateAppVm = {
      properties = {
        label = "red";
        netvm = "none";
      };

      localFlake = {
        path = "./users/op/tests/nubes/smoke";
        output = "qixosAppConfigurations.oomModerate";
      };
      deleteOnRemoval = true;
    };
  in {
    # The opposite case: a cluster that must not be killed. Four nubes that each fit in
    # the template's memory and do not fit together, so the switch succeeds only if they
    # are evaluated one at a time.
    #
    # A cluster of its own rather than more AppVMs on the one below, whose apply is
    # meant to fail.
    qixosConfigurations.sequenced = {
      managementTag = "created-by-${adminName}";
      baseTemplate = "${adminName}-base-template";

      nubeClusters."${prefix}seq-template" = {
        template = {
          properties = {
            label = "red";

            # Between what one nube takes to evaluate, 1.0 GB, and what the template
            # and all four take in a single evaluation, 4.2 GB, with the swap core
            # gives every nube counted on top of this. See oomModerate in the smoke
            # flake for where those numbers come from.
            memory = 2000;

            # Pinned, for the reason given on the cluster below.
            maxmem = 0;
          };

          localFlake = {
            path = "./users/op/tests/nubes/smoke";
            output = "qixosTemplateConfigurations.smoke";
          };
        };

        appVms."${prefix}seq-a" = moderateAppVm;
        appVms."${prefix}seq-b" = moderateAppVm;
        appVms."${prefix}seq-c" = moderateAppVm;
        appVms."${prefix}seq-d" = moderateAppVm;
      };
    };

    qixosConfigurations.oom = {
      managementTag = "created-by-${adminName}";
      baseTemplate = "${adminName}-base-template";

      nubeClusters."${prefix}template" = {
        template = {
          properties = {
            label = "red";

            # Enough to boot and answer qrexec, which starving it below this does not
            # reliably do. What kills the build is the nube below, not this number.
            memory = 600;

            # Without this qmemman balloons the qube up to maxmem on demand and the
            # build finishes, since `memory` is only the starting allocation. Zero
            # turns memory balancing off, pinning it at the value above.
            maxmem = 0;
          };

          localFlake = {
            path = "./users/op/tests/nubes/smoke";
            output = "qixosTemplateConfigurations.smoke";
          };
        };

        # The provocation. Its configuration is expensive to evaluate and cheap to
        # build, so the template runs out of memory part way through evaluating it.
        appVms."${prefix}appvm" = {
          properties = {
            label = "red";
            netvm = "none";
          };

          localFlake = {
            path = "./users/op/tests/nubes/smoke";
            output = "qixosAppConfigurations.oomHeavy";
          };
          deleteOnRemoval = true;
        };
      };
    };
  };
}
