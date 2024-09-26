# Ansible Home Lab

This repository contains the Ansible playbooks for configuring my home lab.

### Directory Structure

```
|-- playbooks/                  # All the various different playbooks for the home lab
|   |-- proxmox/                # The Ansible configuration for Proxmox servers
|   |-- truenas/                # The Ansible configuration for TrueNAS servers
|-- requirements/
|   |-- pip.txt                 # Python pip requirements file
|   |-- ansible_galaxy.yml      # Ansible galaxy requirements file
```

### Setup

To run the configuration from this repository, make sure you have the following things installed:

- Python 3
- Ansible

Then you can run this to install the dependencies:

```
make install
```

### Running the Configuration

To run the configuration playbooks, run the following command:

```
make run
```
