# Client half of `qubes.ConnectTCP`. Listens on a loopback port here and carries each
# connection to a port on another qube over qrexec, the way the stock updates-proxy
# forwarder carries 127.0.0.1:8082. The other side needs nothing installed:
# `qubes.ConnectTCP` is served by every qube, and connects to that port on its own
# loopback.
#
#   qubesTcpForward.forgejo = { qube = "review-nube"; port = 3000; };
#
# makes http://localhost:3000 in this qube reach port 3000 in review-nube.
#
# Each entry needs a dom0 policy line naming this qube and the port, in a file under
# /etc/qubes/policy.d/:
#
#   qubes.ConnectTCP +3000 <this-qube> review-nube allow
#
# Without it the connection is accepted here and then closed straight away, which looks
# like the far service being down.
{ pkgs, lib, config, ... }:
let
  cfg = config.qubesTcpForward;

  forward = name: entry: {
    sockets."qubes-tcp-forward-${name}" = {
      description = "Forward 127.0.0.1:${toString entry.localPort} to ${entry.qube}";
      wantedBy = [ "sockets.target" ];
      listenStreams = [ "127.0.0.1:${toString entry.localPort}" ];
      socketConfig = {
        BindToDevice = "lo";
        Accept = true;
      };
    };

    # The @ makes this a template, paired with the socket above by their shared name.
    # With Accept, systemd starts one instance of it per connection the socket accepts,
    # and hands that connection over as the instance's stdin and stdout.
    services."qubes-tcp-forward-${name}@" = {
      description = "Forward a connection to ${entry.qube} port ${toString entry.port}";
      serviceConfig = {
        ExecStart = "${pkgs.qubes-core-qrexec}/bin/qrexec-client-vm --use-stdin-socket ${entry.qube} qubes.ConnectTCP+${toString entry.port}";
        StandardInput = "socket";
        StandardOutput = "inherit";
      };
    };
  };
in
{
  options.qubesTcpForward = lib.mkOption {
    default = { };
    description = "Loopback ports forwarded to a port on another qube over qubes.ConnectTCP.";
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      options = {
        qube = lib.mkOption {
          type = lib.types.str;
          description = "qube to connect to";
        };
        port = lib.mkOption {
          type = lib.types.port;
          description = "port on that qube's loopback, and the argument in the policy line";
        };
        localPort = lib.mkOption {
          type = lib.types.port;
          default = config.port;
          defaultText = lib.literalExpression "port";
          description = "port to listen on here";
        };
      };
    }));
  };

  config.systemd = lib.mkMerge (lib.mapAttrsToList forward cfg);
}
