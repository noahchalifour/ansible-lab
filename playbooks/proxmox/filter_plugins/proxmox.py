import re


def extract_disks(proxmox_entry):
    result = []
    for key, value in proxmox_entry.items():
        if not isinstance(value, str):
            continue
        disk_match = re.search(r'local-lvm:[a-z0-9\-]*', value)
        if disk_match is not None:
            full_match = disk_match.group(0)
            storage, id_ = full_match.split(':')
            result.append({
                "disk": key,
                "storage": storage,
                "id": id_,
                "vm_id": str(proxmox_entry['vmid'])
            })
    return result


def vm_disk_update_map(vm_configs, import_results):
    results = {}
    for vm_config in vm_configs:
        vm_id = vm_config['vmid']
        results[vm_id] = False
        for result in import_results:
            if int(result['item']['item']['vm_id']) == vm_id and result['changed']:
                results[vm_id] = True
    return results


class FilterModule(object):
    def filters(self):
        return {
            'extract_disks': extract_disks,
            'vm_disk_update_map': vm_disk_update_map
        }