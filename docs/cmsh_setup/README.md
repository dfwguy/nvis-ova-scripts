# Running `cmsh` from a non-BCM host

Documentation for using the Base Command Manager (BCM) `cmsh` client on a server
that was **not** provisioned from a BCM image.

Organised per [Diátaxis](https://diataxis.fr/): tutorials teach, how-to guides
solve a specific problem, reference describes, explanation gives background.

## Contents

| Type | Document | Use when |
|---|---|---|
| Tutorial | [Connect cmsh from a non-BCM host](tutorials/connect-cmsh-from-non-bcm-host.md) | First time; you want the whole path start to finish |
| How-to | [Download BCM packages for offline install](how-to/download-bcm-packages.md) | The client has no access to the BCM repo |
| How-to | [Extract cmsh without installing it](how-to/extract-cmsh-without-installing.md) | `apt install` of the BCM debs aborts |
| How-to | [Set up cmsh credentials](how-to/set-up-cmsh-credentials.md) | New user needs to authenticate to CMDaemon |
| How-to | [Make cmsh permanent](how-to/make-cmsh-permanent.md) | You want to type `cmsh` and nothing else |
| How-to | [Troubleshoot a cmsh connection](how-to/troubleshoot-connection.md) | It won't connect, or the binary is missing |
| Reference | [Environment as built](reference/environment.md) | You need exact hostnames, versions, paths |
| Reference | [Commands used](reference/commands.md) | You want the copy-pasteable command set |
| Explanation | [How cmsh talks to CMDaemon](explanation/how-cmsh-talks-to-cmdaemon.md) | Understanding why this works at all |
| Explanation | [Why `dpkg -x` instead of `apt install`](explanation/why-dpkg-x.md) | Justifying the unconventional install |
| Explanation | [Version parity and upgrade risk](explanation/version-parity.md) | Planning for the next BCM upgrade |

## Status

This set documents a working configuration built on 2026-08-06. Items marked
**VERIFY** need a value confirmed from the CLI before the docs are final — see
the list at the bottom of [reference/environment.md](reference/environment.md).
