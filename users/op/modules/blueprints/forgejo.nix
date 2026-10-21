# Forgejo for a qube with no network (netvm = "none"). Clients reach it through
# ../qubes-tcp-forward.nix: http://localhost:3000, its ROOT_URL, and ssh on port 2222.
#
# TODO: make these `setup.steps` once the setup module exists.
#
#   forgejo-admin admin user create --admin --username <admin> --email <admin>@localhost --random-password
#   forgejo-admin admin user create --username <name> --email <name>@localhost --random-password \
#     --must-change-password=false
#   forgejo-admin admin user generate-access-token --username <name> --token-name <token> \
#     --scopes write:repository,write:issue,read:user
#
# --must-change-password=false: Forgejo refuses API calls from an account that still has to
# change its password. read:user lets clients such as tea check a token.
{ pkgs, lib, config, ... }:
let
  cfg = config.services.forgejo;
  user = config.services.qubes.core.username;

  # The forgejo CLI as the service's account and with its environment, so admin commands
  # read the same app.ini and database the service does.
  forgejoAdmin = pkgs.writeShellApplication {
    name = "forgejo-admin";
    text = ''
      exec sudo -u ${cfg.user} env \
        FORGEJO_WORK_DIR=${cfg.stateDir} FORGEJO_CUSTOM=${cfg.customDir} \
        ${lib.getExe cfg.package} "$@"
    '';
  };
in
{
  services.forgejo = {
    enable = true;
    # As the user, in their home, so they own the data and can work in it directly.
    # /home is bound from /rw, so this survives a reboot.
    inherit user;
    group = user;
    stateDir = "/home/${user}/forgejo";
    database.type = "sqlite3";
    settings = {
      server = {
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        DOMAIN = "localhost";
        ROOT_URL = "http://localhost:3000/";
        # Forgejo's own ssh server, so the qube runs no sshd.
        START_SSH_SERVER = true;
        SSH_LISTEN_HOST = "127.0.0.1";
        SSH_LISTEN_PORT = 2222;
        SSH_PORT = 2222;
        SSH_DOMAIN = "localhost";
        BUILTIN_SSH_SERVER_USER = "git";
        # No netvm, so no avatars, CDNs or update checks to reach for.
        OFFLINE_MODE = true;
      };
      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = true;
      };
      repository.DEFAULT_PRIVATE = "private";
      # Forgejo runs git from inside its bare repos, which a system-wide
      # safe.bareRepository = explicit would refuse.
      "git.config"."safe.bareRepository" = "all";
      mailer.ENABLED = false;
      "cron.update_checker".ENABLED = false;
    };
  };

  # The module hides /home from the service. Keep the rest of the home hidden, but bring
  # back the one directory that is the service's own.
  systemd.services.forgejo.serviceConfig = {
    ProtectHome = lib.mkForce "tmpfs";
    BindPaths = [ cfg.stateDir ];
  };
  # Every ReadWritePaths entry must exist under this sandbox (226/NAMESPACE otherwise), and
  # the module lists the LFS directory without creating it while LFS is off.
  systemd.tmpfiles.rules = [ "d '${cfg.lfs.contentDir}' 0750 ${cfg.user} ${cfg.group} - -" ];

  # qubes-mount-dirs mounts /home after systemd-tmpfiles has run at boot, so the
  # directories the forgejo module's tmpfiles rules create under it land on the root
  # volume and are then hidden by the mount. Create them again once /home is there.
  systemd.services.forgejo-home-dirs = {
    description = "Create Forgejo's directories under /home";
    after = [ "qubes-mount-dirs.service" ];
    requires = [ "qubes-mount-dirs.service" ];
    before = [ "forgejo-secrets.service" "forgejo.service" ];
    requiredBy = [ "forgejo-secrets.service" "forgejo.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=${cfg.stateDir}";
    };
  };

  environment.systemPackages = [ forgejoAdmin ];
}
