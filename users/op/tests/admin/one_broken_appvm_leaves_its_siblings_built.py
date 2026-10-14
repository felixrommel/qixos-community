#!/usr/bin/env python3
"""An AppVM that cannot be built costs only itself.

A template used to build every AppVM of its cluster as part of its own build, so one
AppVM that failed to evaluate failed the whole switch and left every sibling on whatever
it had before. Each AppVM is now built on its own after the template, and one failing
leaves the template and the rest switched.

The siblings already have closures from earlier switches, and a failed switch leaves
those where they were, so finding one afterwards would prove nothing. The test removes
them from the template first, so each closure it finds was built by the switch under
test.

Mutating: it rewrites the template's /var/qixos/activation and leaves the cluster with
an AppVM that does not build until `smoke` is applied again.

usage: one_broken_appvm_leaves_its_siblings_built.py <flake-ref> <template> <broken> <sibling>...
"""
import subprocess
import sys

import harness

# From qixos core. Where qixos.Switch leaves each AppVM's built configuration.
ACTIVATION_DIR = "/var/qixos/activation"


def built(template, appvm):
    return harness.ssh(
        template, "test", "-x", f"{ACTIVATION_DIR}/{appvm}/nixos/bin/switch-to-configuration"
    ).returncode == 0


def main(argv):
    if len(argv) < 5:
        print(f"usage: {argv[0]} <flake-ref> <template> <broken> <sibling>...", file=sys.stderr)
        return 2

    flake, template, broken, siblings = argv[1], argv[2], argv[3], argv[4:]

    # Left running for the apply. Its switch runs on this same template, and the shutdown
    # that ends the switch commits the cleared directory along with what was built.
    if not harness.boot(template):
        return 1
    cleared = harness.ssh(template, "sudo", "rm", "-rf", ACTIVATION_DIR)
    if cleared.returncode != 0:
        print(f"could not clear {ACTIVATION_DIR} on {template}: {cleared.stderr.strip()}", file=sys.stderr)
        return 1

    # --update for the reason `run` gives: without it the template builds the copy of
    # this local flake it locked on a previous run.
    result = subprocess.run(
        ["qixos-rebuild", "--flake", flake, "apply", "--update"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        print(
            f"apply succeeded, so {broken} built and this proves nothing about a failure",
            file=sys.stderr,
        )
        return 1

    if not harness.boot(template):
        return 1
    unbuilt = [appvm for appvm in siblings if not built(template, appvm)]
    broken_built = built(template, broken)
    harness.shut_down(template)

    if broken_built:
        print(f"{broken} has a closure, so the apply failed for some other reason:", file=sys.stderr)
        print((result.stdout + result.stderr).strip(), file=sys.stderr)
        return 1

    if unbuilt:
        print(
            f"{broken} failing left nothing built for {', '.join(unbuilt)}, so its "
            f"failure took its siblings down with it:",
            file=sys.stderr,
        )
        print((result.stdout + result.stderr).strip(), file=sys.stderr)
        return 1

    print(f"{broken} failed and its {len(siblings)} siblings were built anyway")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
