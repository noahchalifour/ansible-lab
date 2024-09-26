PROXMOX_DIR = playbooks/proxmox
TRUENAS_DIR = playbooks/truenas

.PHONY: run run-dev \
	run-proxmox run-proxmox-dev \
	run-truenas run-truenas-dev \
	install install-pip install-galaxy

run: run-proxmox run-truenas

run-dev: run-proxmox-dev run-truenas-dev

run-proxmox:
	ansible-playbook -i $(PROXMOX_DIR)/inventory.prod $(PROXMOX_DIR)/playbook.yml

run-proxmox-dev:
	ansible-playbook -i $(PROXMOX_DIR)/inventory.dev $(PROXMOX_DIR)/playbook.yml

run-truenas:
	ansible-playbook -kK -i $(TRUENAS_DIR)/inventory.prod $(TRUENAS_DIR)/playbook.yml

run-truenas-dev:
	ansible-playbook -kK -i $(TRUENAS_DIR)/inventory.dev $(TRUENAS_DIR)/playbook.yml

install: install-pip install-galaxy

install-pip:
	pip install --break-system-packages -r requirements/pip.txt

install-galaxy:
	ansible-galaxy collection install -r requirements/ansible_galaxy.yml