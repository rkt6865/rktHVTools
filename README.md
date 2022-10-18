# rktHVTools

## Description

This is a collection of small functions to assist in gathing different types of information in a
Hyper-V environment.  All of the functions have been incorporated in the `rktHVTools.psm1` module.

## Usage

You can use the functions individually or you can install the `rktHVTools.psm1` module.  To install the module, just copy it to your modules folder.  The default directory for
user modules is:

`$home\Documents\WindowsPowerShell\Modules\<Module Folder>\<Module Files>`

You can then import the module during your Powershell session using the `Import-Module -Name "rktHVtools"` command.  You
can also call this from your `$profile`

## Required

These functions are dependent on the Microsoft SC Virtual Machine Manager module.  The module should be loaded prior to running any of these functions.
If not already loaded, type the following:

```
    Import-Module -Name "virtualmachinemanager"
```

Also, most of the functions rely on one or more Environment variables be set. **The following variables should be set prior to
running any of the functions**:

```
    $Env:vmm_username = <username>
    $Env:vmm_password = <password>
    $Env:vmm_server = <server>
```
NOTE: If these are not set, they will be set automatically if/when you run the **Connect-VMMServer &lt;vmm_server&gt;** function.

## List of functions

- Connect-VMMServer - Connects to a user specified SC VMM Server
- Get-HVClusterInfo - Retrieve memory and CPU infromation for each host in a cluster
- Get-HVCsvClusterInfo - Retrieve basic information for all of the CSVs in a Hyper-V compute cluster
- Get-HVHarddiskinfo - Retrieve hard disk information for each hard disk of a VM
- Get-HVHostHardware - Retrieve manufacturer, model, memory, and CPUs for a physical Hyper-V host
- Get-HVLldpInfo - Retrieve physical switch/port information for each interface of a Hyper-V host
- Get-HVWWN - Retrieve WWN information for each HBA of a Hyper-V host
- Get-HVCsvInfo - Retrieve basic information for a specific CSVs anywhere within the VMM
- Get-HVVmsOnCsv - Retrieve VMs located on a specific CSV
- Get-HVVMInfo - Retrieve basic VM resource information (CPUs, Memory, HD size)
- Get-HVHostNicInfo - Retrieve physical NIC information of a Hyper-V Host
- Get-HVClusterVMs - Retrieve all VMs in a particular cluster
- Get-HVHostLldpinfo - Retrieve physical switch/port/(faster)connection status information for each interface of a Hyper-V host
- Get-HVHostStoragePaths - Retrieve available storage paths for each CSV of a Hyper-V host
- Get-HVHostStoragePathTotals - Retrieve the total number of storage devices and paths of a Hyper-V host
- Get-HVHostLastBootUpTime - Retrieve the time a Hyper-V host last rebooted
- Get-HVHostMPIOSettings - Retrieve the MPIO settings of a Hyper-V host
- Get-HVHostNicStats - Retrieve the network packet errors/discards for each physical NIC of a Hyper-V host
- Get-HVHostNicDrivers - Retrieve the NIC driver details for each physical NIC of a Hyper-V host
- Get-HVHostNicVMQ - Retrieve the VMQ status (enabled/disabled) of a physical NIC of a Hyper-V host
- Get-HVNetworkVlans - Retrieve the network names and VLANs of a Hyper-V Logical Network