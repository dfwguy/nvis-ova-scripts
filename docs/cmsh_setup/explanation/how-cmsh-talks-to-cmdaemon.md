# Why this works at all: cmsh and CMDaemon

## cmsh is a client, not a component of the headnode

It is easy to assume `cmsh` is part of the headnode's management stack and can
only run there. It is not. `cmsh` is a network client. It opens a TLS connection
to CMDaemon on TCP 8081, authenticates with an X.509 client certificate,
exchanges management calls, and renders the results as a shell. All cluster
state lives in CMDaemon and its database on the headnode; the client holds none
of it.

This is why the exercise is tractable at all. There is no hidden local state to
reproduce, no shared filesystem requirement, no membership in the cluster. If a
process can reach port 8081 and present an accepted certificate, it is a valid
client.

## The pattern is already in use

Every BCM-managed compute node runs a `cmsh` that talks to the headnode's
CMDaemon exactly this way. The only thing special about the compute nodes is
that BCM provisioned the binary and the certificate for them. Doing it by hand
on an unmanaged host is the same client, obtained differently.

## Where the friction actually is

None of the difficulty is in the protocol. It is all in packaging and identity:

- **Packaging.** `cmsh` ships in `cmdaemon-cmsh`, which declares hard equality
  dependencies on the full `cmdaemon` server package and on `cm-config-cm`, a
  configuration package that assumes it is running on a BCM-provisioned host.
  The client cannot be obtained cleanly on its own.
- **Build coupling.** The binary links against BCM's own builds of OpenSSL,
  Boost, curl, and others under `/cm/`. Those must come from the same repo, which
  in turn ties the client to the headnode's Ubuntu release.
- **Identity.** There is no username and password. Access is a certificate, and
  the certificate carries the profile that determines what the holder may do.
  Getting a certificate onto the client is a deliberate act of delegation, not a
  configuration detail.

## Alternatives worth knowing

If what you actually want is programmatic access rather than an interactive
shell, the `pythoncm` bindings and the CMDaemon API are designed for off-cluster
use and avoid the packaging problem entirely. The `cmsh` route is the right one
when you specifically want the interactive administrative shell — for example so
that runbooks and muscle memory transfer unchanged from the headnode.
