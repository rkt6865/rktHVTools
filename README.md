# rktHVTools

## Description

This is a collection of small functions to assist in gathing different types of information in a
Hyper-V environment.  All of the functions have been incorporated in the `rktHVTools.psm1` module.

## Usage

You can use the functions individually or you can install the `rktHVTools.psm1` module.  The default directory for
user modules is:

`$home\Documents\WindowsPowerShell\Modules\<Module Folder>\<Module Files>`

You can then import the module during your Powershell session using the `Import-Module -Name "rktHVtools"` command.  You
can also call this from your `$profile`

## IMPORTANT

Most of the functions rely on one or more Environment variables be set. **The following variables should be set prior to
running any of the functions**:

```
    $Env:vmm_username = <username>
    $Env:vmm_password = <password>
    $Env:vmm_server = <server>
```

## List of functions

- Connect-VMMServer - Connects to a user specified SC VMM Server
- Get-HVClusterInfo - Retrieve memory and CPU infromation for each host in a cluster
- Get-HVCSVInfo - Retrieve basic information for all of the CSVs in a Hyper-V compute cluster
- Get-HVHarddiskinfo - Retrieve hard disk information for each hard disk of a VM
- Get-HVHostHardware - Retrieve manufacturer, model, memory, and CPUs for a physical Hyper-V host
- Get-HVLldpInfo - Retrieve physical switch/port information for each interface of a Hyper-V host
- Get-HVWWN - Retrieve WWN information for each HBA of a Hyper-V host
  