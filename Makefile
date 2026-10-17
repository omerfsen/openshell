# OpenShell self-paced training. Run `make help` for targets.
#
#   make test               run every lab's checks (bats)
#   make test LAB=05        run one lab's checks
#   make solution LAB=05    replay one lab's solution live against your gateway
#   make replay LAB=05      watch the recorded solution (no gateway needed)
#   make record LAB=05      re-record one solution (.log/.timing/.cast)

SHELL := /bin/bash
VERSION := $(shell cat VERSION)
LABS := $(sort $(wildcard labs/[0-9][0-9]-*))
lab_dir = $(firstword $(wildcard labs/$(LAB)-*))

.PHONY: help check-host images test solution replay replay-cast record record-all cleanup

help:
	@echo "OpenShell training for OpenShell $(VERSION)"
	@echo
	@echo "  make check-host            check this machine's prerequisites"
	@echo "  make images                build the training workload images"
	@echo "  make test [LAB=NN]         run all lab checks, or one lab's"
	@echo "  make solution LAB=NN       replay a lab's solution live (PAUSE=0 for full speed)"
	@echo "  make replay LAB=NN         watch the recorded solution with scriptreplay"
	@echo "  make replay-cast LAB=NN    watch the recorded solution with asciinema"
	@echo "  make record LAB=NN         re-record a solution"
	@echo "  make record-all            re-record every solution"
	@echo "  make cleanup               delete everything the course created"

check-host:
	@scripts/check-host.sh

images:
	docker build -t openshell-training/tools:$(VERSION) images/tools
	docker build -t openshell-training/baked-policy:$(VERSION) images/baked-policy

test: images
ifdef LAB
	bats $(lab_dir)/test.bats
else
	bats $(addsuffix /test.bats,$(LABS))
endif

solution:
	@test -n "$(LAB)" || { echo "usage: make solution LAB=NN"; exit 1; }
	$(lab_dir)/solution.sh

replay:
	@test -n "$(LAB)" || { echo "usage: make replay LAB=NN"; exit 1; }
	scriptreplay --timing $(lab_dir)/solution.timing $(lab_dir)/solution.log

replay-cast:
	@test -n "$(LAB)" || { echo "usage: make replay-cast LAB=NN"; exit 1; }
	asciinema play $(lab_dir)/solution.cast

record:
	@test -n "$(LAB)" || { echo "usage: make record LAB=NN"; exit 1; }
	scripts/record-solution.sh $(lab_dir)

record-all:
	@for lab in $(LABS); do scripts/record-solution.sh $$lab || exit 1; done

cleanup:
	scripts/cleanup.sh
