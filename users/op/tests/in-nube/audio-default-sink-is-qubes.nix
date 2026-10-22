# Nube audio, which qixos core turns on wherever the gui agent is. Declares nothing in a
# nube that turned it off.
#
# What reaches the audio qube cannot be heard from here, so this stops at the last thing
# the nube controls: whatever an application plays goes to the Qubes sink.
{ pkgs, lib, config, ... }:
{
  config = lib.mkIf config.services.qubes.audio.enable {
    qixosTests.tests.audio-default-sink-is-qubes = pkgs.writeShellApplication {
      name = "audio-default-sink-is-qubes";
      runtimeInputs = [ config.services.pipewire.wireplumber.package pkgs.gnugrep pkgs.coreutils ];
      text = ''
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

        # Connecting starts pipewire by its socket, and wireplumber picks a default sink
        # some time after that.
        for _ in $(seq 30); do
          if wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q 'node.name = "qubes-sink"'; then
            echo "default sink is qubes-sink"
            exit 0
          fi
          sleep 1
        done

        echo "default sink is not qubes-sink after 30s:" >&2
        wpctl status >&2 || true
        exit 1
      '';
    };
  };
}
