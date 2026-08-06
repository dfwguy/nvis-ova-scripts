# Version parity and upgrade risk

## The constraint

CMDaemon and `cmsh` are released as a matched pair. The packages express this as
a hard equality — `cmdaemon-cmsh` depends on `cmdaemon (= 11.0-164771-cm11.0-f6695c2d2a)`,
not on a range. That is not merely packaging conservatism: the management
protocol between client and daemon changes between builds, and a client from a
different build can be refused.

This is invisible on a BCM-managed cluster, because BCM upgrades the headnode and
the node images together. An out-of-band client breaks that guarantee. It is the
single most likely reason this setup will stop working.

## What an upgrade does

When the headnode is upgraded — even within 11.0, to a new build string — the
client on `network-server` is left behind. Because the files were placed with
`dpkg -x`, nothing on the client will notice or warn. The failure appears as a
connection that is refused or errors on version grounds, with no indication that
a headnode change caused it.

## Living with it

The realistic options, in rough order of effort:

- **Treat the client as a follower of the headnode.** Add a step to the BCM
  upgrade runbook: after upgrading the headnode, repeat the download and
  extraction for each external client. This keeps the current setup and costs a
  few minutes per upgrade.
- **Containerise the client.** Build an image from the BCM repo pinned to the
  headnode's build, mount the certificate in at runtime. Upgrades become an
  image rebuild, and the host filesystem stays clean. This also removes the
  requirement that the client's Ubuntu release match the headnode's.
- **Use the API instead.** `pythoncm` and the CMDaemon JSON API are intended for
  off-cluster consumers and are more tolerant across versions than the shell
  client. If the use case is automation rather than interactive administration,
  this sidesteps the whole problem.
- **SSH to the headnode.** Not a client at all, but it is always version-correct
  and worth keeping as the fallback when the local `cmsh` breaks mid-incident.

## The wider point

An out-of-band client is a small, useful piece of unmanaged infrastructure. It
works because BCM's architecture is genuinely client-server, and it is fragile
because BCM's release process assumes it is managing both ends. Knowing which of
those two facts you are relying on at any moment is most of what keeps this
maintainable.
