function Connect-VMMServer {
    <#
    .SYNOPSIS
        Connect to System Center Virtual Machine Manager.
    .DESCRIPTION
        Establish a connection to a specific Virtual Machine Manager (VMM) server.
        This could be a local or remote VMM. The function is dependent on some Environment variables.  See Notes below.
    .PARAMETER vmm_server
        Specifies the name/fqdn of the VMM server. This parameter is mandatory.
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Connect-VMMServer <vmm_server>
        Connects to a VMM server specified in the $Env:vmm_server variable.
    .EXAMPLE
        PS C:\> $VMMServer = Connect-VMMServer <vmm_server>
        Create a variable containing the VMM server connetion.
    .NOTES
        The following Environment variable(s) will be used if configured:
            $Env:vmm_username = <username>
            $Env:vmm_password = <password>
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter the name (fqdn) of the VMM Server to connect to.')
        ]
        [String] $vmm_server
    )
        
    begin {
    }
    
    process {
        # Check if username/password Environment variables have been set.  If not, prompt for creds.
        if (!(Test-Path Env:\vmm_username) -or !(Test-Path Env:\vmm_password)) {
            $creds = Get-Credential -Message "Please enter Domain credentials for $vmm_server"
            $vmm_username = $creds.GetNetworkCredential().username
            $vmm_password = $creds.GetNetworkCredential().password
        }
        else {
            $vmm_username = $Env:vmm_username
            $vmm_password = $Env:vmm_password
        }
    
        # Create SecureString object needed to create PSCredential object
        $secureString = ConvertTo-SecureString -AsPlainText -Force -String $vmm_password
        # Create PSCredential
        $creds = New-Object System.Management.Automation.PSCredential ($vmm_username, $secureString)
            
        # Set ErrorActionPreference variable to prevent error from displaying when connecting to VMM server
        $ErrorActionPreference = 'SilentlyContinue'
        # Attempt to create a connection to the VMM server
        $vmmServer = Get-SCVMMServer -ComputerName $vmm_server -Credential $creds
        if (!$vmmServer) {
            Write-Warning "There was an issue. Please verify that the VMM server name, <$vmm_server>, and your credentials are correct."
            break
        }
    
        # Save credentials to an environment variable for possible later use.
        Set-Item ENV:vmm_username $vmm_username
        Set-Item ENV:vmm_password $vmm_password

        # Save $vmm_server to an environment variable for use it other scripts which require it
        Set-Item ENV:vmm_server $vmm_server
        return $vmmServer
    }
        
    end {
    }
}
###################################
###################################
function Get-HVClusterInfo {
    <#
    .SYNOPSIS
        Get real time memory/CPU stats for each host in a cluster.
    .DESCRIPTION
        Retrieve the number of VMs, memory and CPU usage for each VMHost in a particular cluster.
        The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
    .PARAMETER ClusterName
        Specifies the name of the cluster of interest. This parameter is mandatory.
    .INPUTS
        System.String.  Get-HVClusterInfo accepts a string as the name of the cluster.
    .OUTPUTS
        PSCustomObject. Get-HVClusterInfo returns the host name, number of VMs, total memory, memory used,
        memory available, memory used percentage, and CPU used percentage.
    .EXAMPLE
        PS C:\> Get-HVClusterInfo <myClusterName>
        Retrieves memory/cpu information for the cluster <myClusterName>.
    .NOTES
        The following Environment variable(s) must be set prior to running:
            $Env:vmm_server = <server>
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a Cluster name.')
        ]
        [String] $clusterName
    )
        
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
        
    process {
        $clstr = Get-SCVMHostCluster -VMMServer $vmmserver -Name $clusterName -ErrorAction Stop
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found!"
            return
        }
    
        $hosts = Get-SCVMHost -VMHostCluster $clstr | sort name
        foreach ($h in $hosts) {
            $memTot = $h.TotalMemory / 1gb
            $memAvail = $h.AvailableMemory / 1kb
            $memUsage = $memTot - $memAvail
    
            $hshHostProps = [ordered]@{
                Host       = $h.Name
                VMs        = ($h.VMs | ? { $_.Status -eq "Running" } | measure-object).count
                MemTotalGB = [math]::round($memTot, 2)
                MemUsageGB = [math]::round($memUsage, 2)
                MemAvailGB = [math]::round($memAvail, 2)
                MemPct     = "{0:P0}" -f ($memUsage / $memTot)
                CPUPct     = $h.cpuutilization
            }
            New-Object -type PSCustomObject -Property $hshHostProps
    
    
        }
    }
        
    end {
    }
}   
###################################
###################################
function Get-HVCsvClusterInfo {
    <#
.SYNOPSIS
    Retrieve basic information of the Clustered Shared Volumes (CSVs) in a cluster.
.DESCRIPTION
    Retrieves the name, capacity, amount used, and amount free for each CSV in a Hyper-V compute cluster.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER ClusterName
    Specifies the name of the Hyper-V cluster containting the storage of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVCsvClusterInfo accepts a string as the name of the cluster.
.OUTPUTS
    PSCustomObject. Get-HVCsvClusterInfo returns the CSV name, capacity, used space, free space, and amount used percentage for each CSV in the cluster.
.EXAMPLE
    PS C:\> Get-HVCsvClusterInfo <myClusterName>
    Retrieves the capacity, used space, free space for each CSV in the cluster <myClusterName>.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_server = <server>
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the Cluster name.')
        ]
        [String] $clusterName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $clstr = Get-SCVMHostCluster -VMMServer $vmmserver -Name $clusterName -ErrorAction SilentlyContinue
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found!"
            return
        }
        $csvs = Get-ClusterSharedVolume -Cluster $clstr
        foreach ($csv in $csvs) {
            $partitionInfo = $csv.SharedVolumeInfo[0].Partition
            $used = ($partitionInfo.Size / 1GB) - ($partitionInfo.FreeSpace / 1GB)
            $usedPct = ($used / ($partitionInfo.Size / 1GB))
            $hshCsvProps = [ordered]@{
                Name     = $csv.Name
                Owner    = $csv.OwnerNode.Name
                Capacity = [math]::Round($partitionInfo.Size / 1GB, 2)
                Used     = [math]::round($used, 2)
                Free     = [math]::Round($partitionInfo.Freespace / 1GB, 2)
                UsedPct  = "{0:P0}" -f [math]::round($usedPct, 2)
            }
            New-Object -type PSCustomObject -Property $hshCsvProps
        }
    }
    
    end {
    }
}
###################################
###################################
function Get-HVHarddiskInfo {
    <#
    .SYNOPSIS
        Retrieve the hard disk information for a VM.
    .DESCRIPTION
        Retrieves the hard disk information such as size, used space, scsi controller, and location for each disk of a VM.
        The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
    .PARAMETER vmName
        Specifies the name of the VM containting the disks of interest. This parameter is mandatory.
    .INPUTS
        System.String.  Get-HVHarddiskInfo accepts a string as the name of the VM.
    .OUTPUTS
        PSCustomObject. Get-HVHarddiskInfo returns the hard disk name, scsi/ide controller, disk size, and disk location.
    .EXAMPLE
        PS C:\> Get-HVHarddiskInfo <vmname>
        Retrieves the hard disk information in the VM <vmname>.
    .EXAMPLE
        PS C:\> Get-SCVirtualMachine myVM | Get-HVHarddiskInfo
        Retrieves the hard disk information in the VM <myVM>.
    .NOTES
        The following Environment variable(s) must be set prior to running:
            $Env:vmm_server = <server>
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the name of the VM')
        ]
        [String] $vmname
    )
        
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
    
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
        
    process {
        $vm = Get-SCVirtualMachine -VMMServer $vmmserver $vmname
        if (!$vm) {
            Write-Warning "The VM, $vmname, could not be found."
            return
        }
    
        $vDiskDrives = Get-SCVirtualDiskDrive -VMMServer $vmmserver -VM $vm
        foreach ($vDiskDrive in $vDiskDrives) {
            $busType = $vDiskDrive.BusType
            $bus = $vDiskDrive.Bus
            $lun = $vDiskDrive.Lun
            $hdisk = $vDiskDrive.VirtualHardDisk
            $locpath = $hdisk.location.Replace(":", "$")
            $hdFilename = "\\" + $hdisk.hostname + "\" + $locpath
    
            $hshDiskProperties = [ordered]@{
                vmName    = $vm.Name
                HDName    = $hdisk.Name
                CntrlType = $busType
                SCSIID    = "$($bus):$($lun)"
                UsedGB    = [math]::Round($hdisk.Size / 1GB, 2)
                MaxGB     = [math]::Round($hdisk.MaximumSize / 1GB, 2)
                CSV       = $hdisk.HostVolume.Name
                Filename  = $hdFilename
            }
            New-Object -type PSCustomObject -Property $hshDiskProperties
        }
    }
            
    end {
    }
}    
###################################
###################################
function Get-HVHostHardware {
    <#
.SYNOPSIS
    Retrieve hardware information of a Hyper-V host.
.DESCRIPTION
    Retrieves the name, manufacturer, model, memory and CPUs for a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostHardware accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostHardware returns the name, cluster, manufacturer, model, memory, CPU sockets, and total CPUs.
.EXAMPLE
    PS C:\> Get-HVHostHardware <myVMHostName>
    Retrieves the hardware information of the Hyper-V host <myVMHostName>.
.NOTES
    None.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a host name.')
        ]
        [String] $hostName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $vHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $sys = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $cimSession -Property Manufacturer, Model, TotalPhysicalMemory
        $sn = (Get-CimInstance -ClassName Win32_bios -CimSession $cimSession).SerialNumber
        $proc = Get-CimInstance -ClassName Win32_Processor -CimSession $cimSession
        Remove-CimSession -CimSession $cimSession

        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $hshSysProperties = [ordered]@{
            Name         = $sys.Name
            Cluster      = $clusterName
            Manufacturer = $sys.Manufacturer
            Model        = $sys.Model
            SerialNo     = $sn
            Mem          = [math]::Round($sys.TotalPhysicalMemory / 1gb, 0)
            Sockets      = $proc.Count
            Cores        = $proc[0].NumberOfCores
            TotProcs     = ($proc.Count) * ($proc[0].NumberOfLogicalProcessors)
            Processor    = $proc[0].Name
        }
        New-Object -type PSCustomObject -Property $hshSysProperties

    }
    
    end {
    }
}
###################################
###################################
function Get-HVLldpInfo {
    <#
.SYNOPSIS
    Retrieve physical switch and port information for each interface of a Hyper-V host.
.DESCRIPTION
    Retrieves the MAC address, physical switch name, physical switch port, and port description for each network
    interface of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.PARAMETER Refresh
    Refresh the LLDP information for the interface. Optional.
.INPUTS
    System.String.  Get-HVLldpInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVLldpInfo returns the host name, MAC, connection state, speed, physical switch name, and physical port.
.EXAMPLE
    PS C:\> Get-HVLldpInfo <myVMHostName>
    Retrieves the physical switch and port information for each interface of the Hyper-V host <myVMHostName>.
.EXAMPLE
    PS C:\> Get-HVLldpInfo -Refresh <myVMHostName>
    Retrieves the physical switch/port information after first retrieving the information from the physical switch.
.NOTES
    If the interface returns no information, try applying the -Refresh switch.  This will reach out to the switch to gather the information.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter the name of the Hyper-V host.')
        ]
        [String] $hostName,
        [Parameter(Mandatory = $false)]
        [Switch]
        $Refresh
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }

        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $hvHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (! $hvHost) {
            Write-Output "The Hyper-V host, $hostName, does not exit."
            break
        }
        $nics = Get-SCVMHostNetworkAdapter -VMHost $hvHost | ? { ($_.Name -notlike "*NDIS*") -or ($_.Name -notlike "*USB*") }
        $nicPropsArr = @()
        foreach ($nic in $nics) {
            if (! $nic.LldpInformation) {
                if ($Refresh) {
                    if ($nic.ConnectionState -eq "Connected") {
                        Write-Output "Refreshing LLDP information for $($nic.ConnectionName). Please wait... (TEMP)"
                        Set-SCVMHostNetworkAdapter -VMHostNetworkAdapter $nic -RefreshLldp | Out-Null
                    }
                }
            }
            $hshNicProps = [ordered]@{
                Host       = $hvHost.Name.Split(".")[0]
                Cluster    = $hvhost.HostCluster.Name.Split(".")[0]
                MAC        = $nic.MacAddress
                State      = $nic.ConnectionState
                MaxSpeed   = $nic.MaxBandwidth
                pSwitch    = $nic.LldpInformation.SystemName
                pPort      = $nic.LldpInformation.PortId
                Desc       = $nic.LldpInformation.PortDescription
                lastUpdate = $nic.LldpInformation.UpdatedTimestamp
            }
            #$nicPropsArr += New-Object -type PSCustomObject -Property $hshNicProps
            New-Object -type PSCustomObject -Property $hshNicProps
            
        }
                
    }
    
    end {
        
    }
}
###################################
###################################
function Get-HVWWN {
    <#
    .SYNOPSIS
        Retrieve WWN information of a Hyper-V host.
    .DESCRIPTION
        Retrieves the World Wide Name (node address and port address) for each hba of the host.
    .PARAMETER hostName
        Specifies the name of the Hyper-v host. This parameter is mandatory.
    .INPUTS
        System.String.  Get-HVWWN accepts a string as the name of the Hyper-V host.
    .OUTPUTS
        PSCustomObject. Get-HVWWN returns the host name, node address and port address.
    .EXAMPLE
        PS C:\> Get-HVWWN <myVMHostName>
        Retrieves the WWN of each hba of the Hyper-V host <myVMHostName>.
    .EXAMPLE
        PS C:\> Get-SCVMHost myVMHost | Get-HVWWN 
        Retrieves the WWN of each hba of the Hyper-V host <myVMHost>.
    .NOTES
        None.
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the host name.')
        ]
        [String] $hostName
    )
        
    begin {
    }
        
    process {
        $hbas = Get-InitiatorPort -CimSession $hostname -ErrorAction SilentlyContinue
        if ($hbas -eq $null) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $hbaArr = @()
        foreach ($hba in $hbas) {
            $hshHbaProperties = [ordered]@{
                Name        = $hba.PSComputerName
                NodeAddress = $hba.NodeAddress
                PortAddress = $hba.PortAddress
            }
            $hbaArr += New-Object -type PSCustomObject -Property $hshHbaProperties
        }
        $hbaArr
    }
        
    end {
    }
}
###################################
###################################
function Get-HVCsvInfo {
    <#
.SYNOPSIS
    Retrieve basic information of a specific Cluster Shared Volume (CSV) contained within the VMM.
.DESCRIPTION
    Retrieves the name, capacity, amount used, free space, and the LUN ID for the CSV.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name (or partial) name of the Cluster Shared Volume of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVCsvInfo accepts a string as the name (or partial name) of the CSV.
.OUTPUTS
    PSCustomObject. Get-HVCsvInfo returns the CSV name, capacity, used space, free space, pct used, and LUN ID of the CSV.
.EXAMPLE
    PS C:\> Get-HVCsvInfo <CsvName>
    Retrieves the fields listed in "Outputs" section for the CSV <CsvName>.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_server = <server>
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the name (or partial name) of a CSV.')
        ]
        [String] $csvName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        # The get-scstoragevolume will return the volume for each host in the cluster. Sorting with "-Unique" eliminates that
        $storVols = Get-SCStorageVolume -VMMServer $vmmServer | ? { $_.VolumeLabel -match $csvName } | sort storagevolumeid -Unique
        if (!$storVols) {
            Write-Warning "There are no CSVs with that name."
            return
        }
        # (Get-ClusterSharedVolume -Cluster $storvols.vmhost.hostcluster | ? {$_.name -eq $storvols.volumelabel}).OwnerNode.name

        foreach ($storVol in $storVols) {
            $used = ($storVol.Capacity / 1GB) - ($storVol.FreeSpace / 1GB)
            $usedPct = ($used / ($storVol.Capacity / 1GB))
            $hshStorVolProps = [ordered]@{
                Name     = $storVol.VolumeLabel
                Cluster  = ($storVol.VMHost.HostCluster.Name).Split(".")[0]
                Owner    = (Get-ClusterSharedVolume -Cluster $storVol.vmhost.hostcluster | ? { $_.name -eq $storvol.volumelabel }).OwnerNode.name
                Capacity = [math]::Round($storVol.Capacity / 1GB, 2)
                Used     = [math]::round($used, 2)
                Free     = [math]::Round($storVol.Freespace / 1GB, 2)
                UsedPct  = "{0:P0}" -f [math]::round($usedPct, 2)
                LUNId    = $storVol.StorageDisk.SMLunId
            }
            New-Object -type PSCustomObject -Property $hshStorVolProps
        }
    }
    
    end {
    }
}
###################################
###################################
function Get-HVVmsOnCsv {
    <#
.SYNOPSIS
    Retrieve the VMs located on a specific Cluster Shared Volume (CSV) contained within the VMM.
.DESCRIPTION
    Retrieves the name, RAM, disk size, and location of each VM on the CSV.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name (or partial) name of the Cluster Shared Volume of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVVmsOnCsv accepts a string as the name (or partial name) of the CSV.
.OUTPUTS
    PSCustomObject. Get-HVVmsOnCsv returns the name, RAM, disk size, and location of each VM on the CSV.
.EXAMPLE
    PS C:\> Get-HVVmsOnCsv <CsvName>
    Retrieves the fields listed in "Outputs" section for the CSV <CsvName>.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_server = <server>
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the name (or partial name) of a CSV.')
        ]
        [String] $csvName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmServer = $Env:vmm_server
    }
    
    process {
        $vms = Get-SCVirtualMachine | ? { $_.location -match $csvName } #| select name, @{N="Size";E={[math]::round(($_.TotalSize/1GB),2)}}, location | sort size -Descending
        if (!$vms) {
            Write-Warning "There are no VMs on the CSV or there are no CSVs with that name."
            return
        }

        foreach ($vm in $vms) {
            $hshVMProps = [ordered]@{
                Name     = $vm.Name
                RAM      = [math]::Round($vm.Memory / 1KB, 0)
                Size     = [math]::Round($vm.TotalSize / 1GB, 2)
                Location = $vm.Location
            }
            New-Object -type PSCustomObject -Property $hshVMProps
        }
    }
    
    end {
    }
}
###################################
###################################
function Get-HVVMInfo {
    <#
.SYNOPSIS
    Retrieve basic VM resource information.
.DESCRIPTION
    Retrieves the VM Name, CPUs, Memory, total disk storage, and location of the VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name of the VM. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVVMInfo accepts a string as the name VM.
.OUTPUTS
    PSCustomObject. Get-HVVMInfo returns the VM Name, CPUs, Memory, total disk storage, and location of the VM.
.EXAMPLE
    PS C:\> Get-HVVMInfo <VMName>
    Retrieves the fields listed in "Outputs" section for the VM <VMName>.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_server = <server>
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the VM name:')
        ]
        [String] $vmName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $vm = Get-SCVirtualMachine -VMMServer $vmmserver -Name $vmName
        if (!$vm) {
            Write-Warning "There is no VM with that name."
            return
        }

        #foreach ($vm in $vms) {
        $hDisks = Get-SCVirtualHardDisk -VM $vm
        $hshVMProps = [ordered]@{
            Name     = $vm.Name
            Host     = $vm.vmhost.name.split(".")[0]
            Cluster  = $vm.vmhost.HostCluster.Name.split(".")[0]
            CPU      = $vm.CPUCount
            MemGB    = [math]::Round($vm.Memory / 1KB, 0)
            Size     = [math]::Round($vm.TotalSize / 1GB, 2)
            HDSizeGB = [math]::Round((($hDisks | Measure-Object -Property MaximumSize -Sum).sum) / 1GB, 2)
            Location = $vm.Location
        }
        New-Object -type PSCustomObject -Property $hshVMProps
        #}
    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostNicInfo {
    <#
.SYNOPSIS
    Retrieve physical NIC information of a Hyper-V host.
.DESCRIPTION
    Retrieve physical NIC information of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostNicInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostNicInfo returns the hostname, NIC, NIC description, MAC, speed, and status.
.EXAMPLE
    PS C:\> Get-HVHostNicInfo <myVMHostName>
    Retrieves the physical NIC information of the Hyper-V host <myVMHostName>.
.NOTES
    None.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a host name.')
        ]
        [String] $hostName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $nics = Get-NetAdapter -Physical -CimSession $cimsession
        Remove-CimSession -CimSession $cimSession
        foreach ($nic in $nics) {
            $hshNICProperties = [ordered]@{
                Name       = $hostName
                NIC        = $nic.Name
                NICDesc    = $nic.InterfaceDescription
                MAC        = $nic.MacAddress
                MTU        = $nic.MtuSize
                Speed      = $nic.LinkSpeed
                Connection = $nic.MediaConnectionState
                Status     = $nic.Status
            }
            New-Object -type PSCustomObject -Property $hshNICProperties


        }
    }
    
    end {
    }
}
###################################
###################################
function Get-HVClusterVMs {
    <#
    .SYNOPSIS
        Return all VMs in a cluster.
    .DESCRIPTION
        Return all VMs in a particular cluster.
        The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
    .PARAMETER ClusterName
        Specifies the name of the cluster of interest. This parameter is mandatory.
    .INPUTS
        System.String.  Get-HVClusterVMs accepts a string as the name of the cluster.
    .OUTPUTS
        Microsoft.SystemCenter.VirtualMachineManager.VM. Get-HVClusterVMs returns the VM objects of the specified host.
    .EXAMPLE
        PS C:\> Get-HVClusterVMs <myClusterName>
        Retrieves all of the VMs in the cluster <myClusterName>.
    .NOTES
        The following Environment variable(s) must be set prior to running:
            $Env:vmm_server = <server>
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a Cluster name.')
        ]
        [String] $clusterName
    )
        
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
        
    process {
        $clstr = Get-SCVMHostCluster -VMMServer $vmmserver -Name $clusterName -ErrorAction Stop
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found!"
            return
        }
    
        $clusterVMs = Get-SCVirtualMachine -VMMServer $vmmserver -All | ? { $_.vmhost.hostcluster.name -eq $clstr }
        return $clusterVMs
    }
        
    end {
    }
}
###################################
###################################
function Get-HVHostRiloInfo {
    <#
.SYNOPSIS
    Retrieve iLo/iDRAC location and address of a Hyper-V host.
.DESCRIPTION
    Retrieves the iLo/iDRAC location and address of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostRiloInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostRiloInfo returns the iLo/iDRAC location and address.
.EXAMPLE
    PS C:\> Get-HVHostRiloInfo <myVMHostName>
    Retrieves the iLo/iDRAC location and address of the Hyper-V host <myVMHostName>.
.NOTES
    None.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a host name.')
        ]
        [String] $hostName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $vHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }

        $hshRiloProperties = [ordered]@{
            Name     = $vHost.ComputerName
            Location = $vHost.CustomProperty.Get_Item("Location")
            Rilo     = $vHost.CustomProperty.Get_Item("Rilo")
        }
        New-Object -type PSCustomObject -Property $hshRiloProperties

    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostLldpInfo {
    <#
.SYNOPSIS
    Retrieve physical switch and port information for each interface of a Hyper-V host.
.DESCRIPTION
    This version currently utilizes the Get-HVLldpinfo and Get-HVHostNicinfo functions to retrieves the MAC address, physical switch name, physical switch port, and connection status for each network
    interface of a Hyper-V host. The reason for using both functions is to retrieve the Lldp information (using the VMM) and the connection status information 
    directly from the host (much quicker than waiting on the VMM to refresh).
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostLldpInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostLldpInfo returns the host name, MAC, connection state, speed, physical switch name, and physical port.
.EXAMPLE
    PS C:\> Get-HVHostLldpInfo <myVMHostName>
    Retrieves the physical switch and port information for each interface of the Hyper-V host <myVMHostName>.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_server = <server>
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter the name of the Hyper-V host.')
        ]
        [String] $hostName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }

        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $vmmNics = Get-HVLldpInfo -hostName $hostName
        $cimNics = Get-HVHostNicInfo -hostName $hostName
        
        foreach ($cimNic in $cimNics) {
            $fMac = $cimNic.MAC.Replace("-", ":")
            #Write-Host $fMac
            $vmmNic = $vmmNics | ? { $_.MAC -eq $fMac }
       
            $hshNicProps = [ordered]@{
                Host       = $vmmNic.Host
                Cluster    = $vmmNic.Cluster
                NIC        = $cimNic.NIC
                MAC        = $vmmNic.MAC
                Speed      = $cimNic.Speed
                Connection = $cimNic.Connection
                Status     = $cimNic.Status
                pSwitch    = $vmmNic.pSwitch
                pPort      = $vmmNic.pPort
            }
            #$nicPropsArr += New-Object -type PSCustomObject -Property $hshNicProps
            New-Object -type PSCustomObject -Property $hshNicProps
        }
    }
    
    end {
        
    }
}
###################################
###################################
function Get-HVHostStoragePaths {
    <#
.SYNOPSIS
    Retrieve the available storage paths for each LUN of a Hyper-V host.
.DESCRIPTION
    Retrieve the available storage paths for each LUN of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostStoragePaths accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostStoragePaths returns the hostname, MPIO Disk, Number of paths, LUN ID, and volume label.
.EXAMPLE
    PS C:\> Get-HVHostStoragePaths <myVMHostName>
    Retrieves the available storage paths of the Hyper-V host <myVMHostName>.
.NOTES
    None.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a host name.')
        ]
        [String] $hostName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        # This block is to get the volume label by creating a lookup table of the diskid & name
        $storvols = Get-SCStorageVolume -VMHost $hostname | ? { $_.Name -like "C:\Clust*" }
        if ($storvols) {
            # Get CLuster - Check if host is part of cluster - this avoides potential error when creating hashtable
            if ($storvols[0].VMHost.HostCluster) {
                $clusterName = ($storvols[0].VMHost.HostCluster.Name).Split(".")[0]
            }
            else {
                $clusterName = "N/A"
            }

            # Create lookup table to map the "serial number" to the volume label
            $lunIdNameMap = @{}
            foreach ($item in $storvols) {
                $lunID = $item.StorageDisk.SMLunId
                $lunIdNameMap.Add($lunId, $item.VolumeLabel)
            }
        
            # Get the actual path information
            $mpioDriveInfo = (Get-WmiObject -Namespace root\wmi -Class mpio_disk_info -ComputerName $hostname).driveinfo
        
            foreach ($mpioDrive in $mpioDriveInfo) {
                $hshPathProps = [ordered]@{
                    Host    = $hostname
                    Cluster = $clusterName
                    Name    = $mpioDrive.Name
                    Paths   = $mpioDrive.numberpaths
                    LunID   = $mpioDrive.SerialNumber
                    Label   = $lunIdNameMap[$mpioDrive.SerialNumber]
                }
                New-Object -type PSCustomObject -Property $hshPathProps
            }
        }
        else {
            Write-Host "There are no storage volumes available for $hostname" -ForegroundColor Red
            break
        }

    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostStoragePathTotals {
    <#
.SYNOPSIS
    Retrieve the total number of storage devices and paths of a Hyper-V host.
.DESCRIPTION
    Retrieve the total number of storage devices and paths of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostStoragePathTotals accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostStoragePathTotals returns the Hostname, MNumber of devices, and Number of paths.
.EXAMPLE
    PS C:\> Get-HVHostStoragePathTotals <myVMHostName>
    Retrieves the total number of storage devices and paths of the Hyper-V host <myVMHostName>.
.NOTES
    None.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a host name.')
        ]
        [String] $hostName
    )
    
    begin {
    }
    
    process {
        # Get the actual path information
        $mpioDriveInfo = (Get-WmiObject -Namespace root\wmi -Class mpio_disk_info -ComputerName $hostname).driveinfo
        $measuredObj = $mpioDriveInfo | Measure-Object numberpaths -sum
            
        $hshPathTotals = [ordered]@{
            Host    = $hostname
            Devices = $measuredObj.Count
            Paths   = $measuredObj.Sum
        }
        New-Object -type PSCustomObject -Property $hshPathTotals
    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostLastBootUpTime {
    <#
.SYNOPSIS
    Retrieve the time a Hyper-V host last rebooted.
.DESCRIPTION
    Retrieve the time a Hyper-V host last rebooted.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostLastBootUpTime accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostLastBootUpTime returns the name, cluster, and the time the server last rebooted.
.EXAMPLE
    PS C:\> Get-HVHostLastBootUpTime <myVMHostName>
    Retrieves the time that the Hyper-V host <myVMHostName> was last rebooted.
.NOTES
    None.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a host name.')
        ]
        [String] $hostName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $vHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $os = Get-CimInstance -ClassName win32_operatingsystem -CimSession $cimSession -Property csname, lastbootuptime
        Remove-CimSession -CimSession $cimSession

        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        } else {
            $clusterName = "N/A"
        }
        $hshOsProperties = [ordered]@{
            Name         = $os.CSName
            Cluster      = $clusterName
            LastBootUpTime = $os.LastBootUpTime
        }
        New-Object -type PSCustomObject -Property $hshOsProperties

    }
    
    end {
    }
}
###################################
###################################
