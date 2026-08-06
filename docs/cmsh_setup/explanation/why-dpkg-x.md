# Why `dpkg -x` instead of `apt install`

## The problem with installing properly

The natural approach is to install `cmdaemon-cmsh` as a package. On this host it
does not work, for a reason that is structural rather than incidental.

`apt-cache depends --recurse` on `cmdaemon-cmsh` returns a set that contains both
`cm-master` and `cm-slave` — the headnode role and the managed-node role. Those
are alternatives, not companions. Handing the whole set to `apt install ./*.deb`
asks apt to satisfy a contradiction, and apt correctly declines the part of the
transaction it cannot resolve. The observable result is that everything except
`cmdaemon` and `cmdaemon-cmsh` gets unpacked, with some packages left in the `iU`
state until `dpkg --configure -a` finishes them.

## The deeper problem with succeeding

Even if the conflict were pruned, a successful package install is not obviously
what you want here. Two of the dependencies do things a non-BCM host should not
have done to it:

- **`cmdaemon`** ships the management daemon and its service unit. Installed
  normally, the postinst can start it, and a running CMDaemon on an unmanaged
  host will attempt to participate in the cluster rather than merely talk to it.
- **`cm-config-cm`** exists to configure a BCM host. It writes apt repository
  definitions, shell profile fragments, and other system-level configuration
  under the assumption that this machine is part of the cluster.

On a shared utility server that is not a cluster node, both are unwanted side
effects, and neither is needed to run a client binary.

## What `dpkg -x` buys

`dpkg -x` extracts the archive's files to a target root and does nothing else. No
maintainer scripts run, no services are created, no configuration is rewritten,
and dpkg's database is not touched. You get precisely the files, which for this
purpose is precisely the requirement.

The dependency tree is still installed properly through apt, so the shared
libraries under `/cm/` are managed and coherent. Only the two packages whose
maintainer scripts are unwanted are placed by hand.

## The cost

The trade is deliberate and worth stating plainly:

- `apt` does not know these files exist, so it will never upgrade or remove them.
  Upgrades become a manual step after every headnode BCM upgrade.
- There is no clean uninstall; removal means deleting paths by hand.
- Nothing prevents a future package from claiming the same paths, though in
  practice `/cm/` is exclusively BCM's.

For a client binary on a host that is not part of the cluster, an unmanaged file
set with no side effects is a better fit than a managed install that reconfigures
the machine. If this host ever does become BCM-managed, the right move is to
remove the extracted files and let BCM provision them.
