# DeskOS on Ubuntu

**Ubuntu 26.04 LTS with GNOME, as a bootc image — installable, updatable and
rollback-able like any other DeskOS workstation.**

Verify what you are about to boot before you boot it — the signature names this
repository. Do this first, not after:

```bash
cosign verify quay.io/deskos/deskos-ubuntu:26.04 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/deskosproject/deskos-ubuntu/'

sudo bootc switch quay.io/deskos/deskos-ubuntu:26.04
sudo reboot
```

That is the whole install on a machine that already runs a bootc image. To write
a disk instead, see [Install it](#install-it).

> [!IMPORTANT]
> **Experimental, and the word is about the base.** Ubuntu has no official bootc
> base: Canonical publishes container images, not an installable and updatable
> operating system. So the Project DeskOS maintains one, in
> [`deskos-ubuntu-bootc`](https://github.com/deskosproject/deskos-ubuntu-bootc),
> and nobody upstream tests this path for us. It becomes less experimental the
> more people run it and report what breaks — which is why it is public.

This repository is the Ubuntu half of DeskOS and lives outside `deskos-core`
deliberately: Core compiles onto each platform **vendor's** bootc base, and
Ubuntu has none, so this organization owns one
([ADR 0020](https://github.com/deskosproject/deskos-core/blob/main/docs/adr/0020-ubuntu-lives-in-its-own-repository.md)).

## Use it

The image is published at `quay.io/deskos/deskos-ubuntu`, tagged `26.04` and
`:latest`: it is the `deskos-ubuntu` workstation, built and booted by this
repository's gate before it was pushed.

| Workstation | What it is |
|---|---|
| `deskos-ubuntu` | **the published one**: DeskOS on Ubuntu, keeping Ubuntu's own GNOME layout and defaults |
| `deskos-ubuntu-org-packages` | a second resource root — the same, plus the example organization's own packages — that you render and build yourself |

On a machine that already runs bootc:

```bash
sudo bootc switch quay.io/deskos/deskos-ubuntu:26.04
sudo reboot
```

`bootc switch` follows that tag, so `bootc upgrade` moves the machine to the next
publish. To pin one image instead, switch to its digest:

```bash
skopeo inspect --format '{{.Digest}}' docker://quay.io/deskos/deskos-ubuntu:26.04
sudo bootc switch quay.io/deskos/deskos-ubuntu@sha256:<that digest>
```

**It does not work from a stock Ubuntu install.** This is a new operating-system
image, not a configuration layer on top of one.

## Install it

A machine needs a bootc-capable source to install from, and Ubuntu has no
Anaconda path. The disk is written directly, from the published image:

```bash
# WIPES /dev/<your-disk>. bootc install runs INSIDE the image being installed,
# which is how this repository runs it, not from the host.
sudo podman run --rm --privileged --pid=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev -v /var/lib/containers:/var/lib/containers \
  quay.io/deskos/deskos-ubuntu:26.04 \
  bootc install to-disk /dev/<your-disk> --wipe \
  --target-imgref quay.io/deskos/deskos-ubuntu:26.04 \
  --composefs-backend --bootloader systemd --filesystem ext4
```

`--target-imgref` is where the installed machine looks for its updates. **It must
point at this image, never at the base:** pointing it at the base would replace
the workstation with the base at the next update.

This path is validated in a virtual machine here, from a compressed OCI layout
rather than from the registry, and never on real hardware
([What is worth testing](#what-is-worth-testing)).

## Make it yours

A workstation is a `Workstation` resource plus the profiles it selects. Copy the
one in [`workstations/`](workstations/) and edit it:

```yaml
apiVersion: core.deskos.org/v1alpha1
kind: Workstation
metadata:
  name: my-ubuntu-workstation
spec:
  platformRef: ubuntu-2604
  profiles:
    - deskos-core        # packages and the update policy
    - my-org-baseline    # your own layer: packages, repositories, settings
```

**Keep `deskos-core` and add your own layer; do not select `deskos-gnome` or
`deskos-look`.** Ubuntu ships its own GNOME layout and its own artwork, and this
platform declares `gnome.keepsVendorDefaults`: DeskOS writes no desktop default
here on purpose. Adding `deskos-gnome` would fight the vendor desktop instead of
using it, and `deskos-look` would put DeskOS's wallpaper and splash over
Ubuntu's.

What the platform *does not* provide is written down rather than discovered, in
[`platforms/ubuntu-2604.yaml`](platforms/ubuntu-2604.yaml): it ships no
`/etc/dconf/profile/user`, so a dconf default would reach nobody; its `curl` is
not there, so the platform says how a build fetches; Flatpak is 1.16.6, which
predates `flatpak preinstall`, so a workstation that declares system Flatpaks
fails at composition rather than shipping something that never installs.

Every resource kind, with an example, is in
[`deskos-core`'s resources reference](https://github.com/deskosproject/deskos-core/blob/main/docs/resources.md).

## Build it

Everything below compiles the image yourself. It needs **git**, rootful Podman,
and `deskosctl` from the Core release this repository pins in `deskos.env`:

```bash
# 1. the compiler, at the pinned release — not "latest", which may be another one.
# A pinned release names its asset with the version in it; only
# releases/latest/download has the version-less name.
. ./deskos.env
base="https://github.com/deskosproject/deskos-core/releases/download/$DESKOS_VERSION"
mkdir -p bin && cd bin
curl -fL -O "$base/deskosctl-$DESKOS_VERSION-linux-amd64" -O "$base/SHA256SUMS"
sha256sum -c --ignore-missing SHA256SUMS
mv "deskosctl-$DESKOS_VERSION-linux-amd64" deskosctl && chmod 0755 deskosctl
cd ..

# 2. the resources, as this repository declares them
./bin/deskosctl validate .
./bin/deskosctl render . --workstation deskos-ubuntu --output ./dist

# 3. the image
sudo podman build -t quay.io/<you>/deskos-ubuntu:test ./dist

# 4. the disk, from a compressed OCI layout
sudo skopeo copy containers-storage:quay.io/<you>/deskos-ubuntu:test \
  oci-archive:/var/tmp/deskos-ubuntu-oci:latest
sudo bootc install to-disk --target-imgref quay.io/<you>/deskos-ubuntu:test \
  --source-imgref oci-archive:/var/tmp/deskos-ubuntu-oci:latest --wipe /dev/<your-disk>
```

`make validate` composes every workstation in this repository without building
anything, and `make vm-test` runs the test harness's own unit tests. The disk,
boot, session and first-boot checks need a disk and a hypervisor, and they run in
this repository's publish gate — which is why the image you pull has already been
booted.

## What is worth testing

Everything below is a thing we know could break, not a generic checklist:

1. **Does it install and boot?** On real hardware if you have it. Real firmware,
   real disk, real suspend and resume.
2. **Does the first boot reach a usable desktop?** Ubuntu's GDM starts GNOME
   Initial Setup only when there is no user account, which is why this base
   ships without the inherited `ubuntu` account. A login loop, or a wizard that
   never finishes, is a report worth filing.
3. **Does an update apply, and can you roll back?** `bootc upgrade`, reboot,
   `bootc rollback`. This is the claim that makes a bootc image worth anything,
   and it is the one we can test least.
4. **Snap.** Canonical's Firefox is a snap, and snaps need `snapd` to be happy in
   a container-derived image. If the browser does not start, look there.
5. **The vendor desktop.** This platform keeps Ubuntu's GNOME look and defaults
   on purpose. If a setting does not arrive, or arrives and cannot be changed,
   say which key.
6. **The tools DeskOS puts on the machine**: `deskos report`, `deskos check` and
   `deskos update` should all work — they read the plan the image carries.

## How to help

- **Run it on a machine that is not a VM**, and report what breaks.
- **Rebuild the base for a new Ubuntu point release** in
  [`deskos-ubuntu-bootc`](https://github.com/deskosproject/deskos-ubuntu-bootc)
  and see whether the pins still hold: this repository pins the base by digest,
  so a new base is a one-line pull request here with the tests re-run.
- **Test the ARM64 question.** Nothing here assumes x86_64 except the base, and
  nobody has tried the other architecture.
- **Give the platform a real package source.** The example organization declares
  one signed third-party apt source; a workstation that needs more is a resource,
  not code.
- **Write down what Ubuntu's base does *not* provide** as you find it. Each one
  was a small surprise for us; the useful contribution is the next surprise, with
  the measurement that shows it.

## What is not here

- **RHEL, AlmaLinux, Fedora and CentOS**: those are `deskos-core` platforms, and
  every one of them starts from its vendor's own base. RHEL-derived images are
  never published anywhere.
- **A server or a minimal image**: this is a desktop workstation, with GNOME, and
  nothing else is claimed.
- **A bootc base.** That is the other repository, and it is consumed by digest.
