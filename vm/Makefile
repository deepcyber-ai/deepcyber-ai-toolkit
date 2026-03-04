.PHONY: build build-xfce build-mate export-utm export-ova test clean

PACKER_DIR   := packer
ANSIBLE_DIR  := ansible
SCRIPTS_DIR  := scripts
DIST_DIR     := dist

# Desktop environment: xfce (default) or mate (Founder's Edition)
DESKTOP      ?= xfce
VM_NAME      := deepcyber-vm-$(DESKTOP)
OUTPUT_DIR   := $(PACKER_DIR)/output-$(VM_NAME)
QCOW2        := $(OUTPUT_DIR)/$(VM_NAME)

# Default Packer variable file
PACKER_VARS  := $(PACKER_DIR)/variables.pkrvars.hcl

# Default build uses XFCE
build: build-xfce

build-xfce:
	$(MAKE) _build DESKTOP=xfce

build-mate:
	$(MAKE) _build DESKTOP=mate

_build:
	cd $(PACKER_DIR) && packer init deepcyber-vm.pkr.hcl
	cd $(PACKER_DIR) && packer build \
		-var-file=variables.pkrvars.hcl \
		-var "desktop=$(DESKTOP)" \
		-var "vm_name=$(VM_NAME)" \
		deepcyber-vm.pkr.hcl

export-utm:
	@mkdir -p $(DIST_DIR)
	bash $(SCRIPTS_DIR)/export-utm.sh $(QCOW2) $(DIST_DIR)

export-ova:
	@mkdir -p $(DIST_DIR)
	bash $(SCRIPTS_DIR)/export-ova.sh $(QCOW2) $(DIST_DIR)

test:
	bash $(SCRIPTS_DIR)/test-vm.sh $(QCOW2)

clean:
	rm -rf $(PACKER_DIR)/output-deepcyber-vm-* $(DIST_DIR) $(PACKER_DIR)/packer_cache
