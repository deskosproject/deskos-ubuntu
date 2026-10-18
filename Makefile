# The Core release this repository compiles against, and the tool it needs.
#
# deskosctl embeds the DeskOS Core resources, so a flavor references Core's profiles and
# platforms by name and vendors nothing: what this repository pins is a version and the
# hashes of that release, so a substituted release fails instead of compiling.
include deskos.env

WORKSTATION ?= deskos-ubuntu
D           := .deskos/$(DESKOS_VERSION)
DESKOSCTL   := $(D)/deskosctl-$(DESKOS_VERSION)-linux-amd64
BASE        := https://github.com/deskosproject/deskos-core/releases/download/$(DESKOS_VERSION)
# Expected hashes of the pinned release, committed so a substituted release is detected:
# SHA256SUMS downloaded from the same release cannot authenticate itself. Update this file
# and deskos.env together when bumping the version.
DESKOS_SUMS := $(CURDIR)/deskos.sha256

.PHONY: fetch validate plan render vm-test

$(DESKOSCTL):
	mkdir -p $(D)
	cd $(D) && curl -fsSL -O "$(BASE)/deskosctl-$(DESKOS_VERSION)-linux-amd64" -O "$(BASE)/SHA256SUMS" \
	  && sha256sum -c --ignore-missing "$(DESKOS_SUMS)" && chmod 0755 deskosctl-$(DESKOS_VERSION)-linux-amd64

fetch: $(DESKOSCTL)

validate: fetch
	$(DESKOSCTL) validate .

plan: fetch
	$(DESKOSCTL) plan . --workstation $(WORKSTATION)

render: fetch
	$(DESKOSCTL) render . --workstation $(WORKSTATION) --output dist/$(WORKSTATION)

# The harness is vendored from the same release, so what it asserts and what the tool
# compiles are the same version's.
vm-test:
	python3 -m unittest discover -s tests/vm
