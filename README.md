# DeskOS on Ubuntu

**Experimental, maintained here on purpose, and looking for people to use it and break it.**

This is the Ubuntu half of DeskOS, and it lives outside `deskos-core` deliberately. Core
compiles a workstation onto its platform **vendor's** bootc base (ADR 0004): a RHEL
workstation starts from Red Hat's base, a CentOS one from the CentOS project's. Ubuntu has no
such base — Canonical publishes container images, not an installable and updatable operating
system — so this organization owns one, and that is the whole reason this repository exists.

**"Experimental" is the honest word for that, and it is about the base, not about DeskOS.**
The base image is built and maintained by us, in
[`deskos-ubuntu-bootc`](https://github.com/deskosproject/deskos-ubuntu-bootc), from Canonical's
image plus the fixes it needs to boot and update as an operating system. Nobody upstream tests
it for us, no vendor supports this path, and the way it becomes less experimental is people
running it and telling us what breaks. It is public for exactly that.

## What is here

| | |
|---|---|
| `platforms/` | the facts about Ubuntu 26.04 as an OS target: the base image pinned by digest, apt and its package groups, the boot splash, and — written down rather than discovered — what Ubuntu's base does *not* do (it ships no `/etc/dconf/profile/user`, so a dconf default would reach nobody and this platform keeps its vendor's desktop; its `curl` is not there, so the platform says how a build fetches; Flatpak is 1.16.6, which predates `flatpak preinstall`) |
| `workstations/` | the workstation(s) a person is meant to take, and what each selects |
| `profiles/`, `desktop/`, `software/` | the resources those workstations select |
| `tests/vm/` | the harness that boots the artifact and asks the guest what it did, vendored from `deskos-core` at the pinned version |

## Build it

Same four steps as any DeskOS platform — get the compiler, validate, render, build — and then
one more, because there is no Anaconda path here: the disk is written directly.

```bash
# 1. the compiler, from the release this repository pins
base=https://github.com/deskosproject/deskos-core/releases/latest/download
mkdir -p bin && curl -fL -O "$base/deskosctl-linux-amd64" -O "$base/SHA256SUMS"
sha256sum -c --ignore-missing SHA256SUMS
install -D -m 0755 deskosctl-linux-amd64 bin/deskosctl

# 2. the resources, as it declares them
./bin/deskosctl validate .
./bin/deskosctl render . --workstation <the one you want> --output ./dist

# 3. the image
sudo podman build -t quay.io/<you>/deskos-ubuntu:test ./dist

# 4. the disk, from a compressed OCI layout
sudo skopeo copy containers-storage:quay.io/<you>/deskos-ubuntu:test \
  oci-archive:/var/tmp/deskos-ubuntu-oci:latest
sudo bootc install to-disk --target-imgref quay.io/<you>/deskos-ubuntu:test \
  --source-imgref oci-archive:/var/tmp/deskos-ubuntu-oci:latest --wipe /dev/<your-disk>
```

**`--target-imgref` must point at the image *you* publish**, never at the base and never at a
local layout: pointing it at the base would replace your workstation with the base at the next
update. That parameter is the difference between a lab disk and a machine that updates.

## Install it

- **A disk**, as in step 4: `bootc install to-disk` writes it, and the machine then updates
  from the reference you gave it.
- **A running Ubuntu box**, if it is already a bootc image: `bootc switch` to your reference
  and reboot. It does not work from a stock Ubuntu install — this is a new operating system
  image, not a configuration layer on top of one.

## What is worth testing

Everything below is a thing we know could break, not a generic checklist:

1. **Does it install and boot?** On real hardware if you have it. `bootc install to-disk` is
   the only path this repository validates, and only ever in a virtual machine here.
2. **Does the first boot reach a usable desktop?** Ubuntu's GDM starts GNOME Initial Setup
   only when there is no user account; this base ships without the `ubuntu` account for that
   reason. If you get a login loop or a wizard that never finishes, that is a report worth
   filing.
3. **Does an update apply and can you roll back?** `bootc upgrade`, reboot, `bootc rollback`.
   This is the claim that makes a bootc image worth anything, and it is the one we can test
   least.
4. **Snap.** Canonical's Firefox on Ubuntu is a snap, and snaps need `snapd` to be happy in a
   container-derived image. If the browser does not start, this is where to look.
5. **The vendor desktop.** This platform keeps Ubuntu's GNOME look and its defaults on
   purpose. If a setting does not arrive, or arrives and cannot be changed, say which key.
6. **The tools DeskOS puts on the machine**: the app channel, the icon cache after icons are
   copied in, and the system Flatpak question (1.16.6 has no `flatpak preinstall`, so a
   workstation that declares system applications fails at composition rather than shipping
   something that never installs).

## How to help

Roughly in order of how much it would move this platform forward:

- **Run it on a machine that is not a VM**, and report what breaks. Real firmware, real disk,
  real suspend and resume.
- **Rebuild the base for a new Ubuntu point release** in
  [`deskos-ubuntu-bootc`](https://github.com/deskosproject/deskos-ubuntu-bootc) and see whether
  the pins still hold: this repository pins the base by digest, so a new base is a pull request
  here with one line changed and the tests re-run.
- **Test the ARM64 question.** Nothing here assumes x86_64 except the base, and nobody has
  tried the other architecture.
- **Give the platform a real package source.** The example in `deskos-core` declares one signed
  third-party apt source; a workstation that needs more is a resource, not code.
- **Write down what Ubuntu's base does *not* provide** as you find it. Every such gap is
  currently a comment in `platforms/`, and each one was a small surprise for us; the useful
  contribution is the next surprise, with the measurement that shows it.
- **Break the installer path deliberately** and report what the failure looked like. A path
  that fails legibly is one a person can use.

## What is not here

- **RHEL, AlmaLinux, Fedora and CentOS**: those are `deskos-core` platforms, and every one of
  them starts from its vendor's own base. RHEL-derived images are never published anywhere.
- **A server or a minimal image**: this is a desktop workstation, with GNOME, and nothing else
  is claimed.
