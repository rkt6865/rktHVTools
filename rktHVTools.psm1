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

        function ExpressServiceCode {
            param ([string]$serviceTag)
            $Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            $ca = $ServiceTag.ToUpper().ToCharArray()
            [System.Array]::Reverse($ca)
            [System.Int64]$ExpressServiceCode = 0
        
            $i = 0
            foreach ($c in $ca) {
                $ExpressServiceCode += $Alphabet.IndexOf($c) * [System.Int64][System.Math]::Pow(36, $i)
                $i += 1
            }
            $ExpressServiceCode
        }
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
            Name               = $sys.Name
            Cluster            = $clusterName
            Manufacturer       = $sys.Manufacturer
            Model              = $sys.Model
            SerialNo           = $sn
            ExpressServiceCode = if ($sys.Manufacturer -like "Dell*") { expressServiceCode($sn) } else { "N/A" }
            Mem                = [math]::Round($sys.TotalPhysicalMemory / 1gb, 0)
            Sockets            = $proc.Count
            Cores              = $proc[0].NumberOfCores
            TotProcs           = ($proc.Count) * ($proc[0].NumberOfLogicalProcessors)
            Processor          = $proc[0].Name
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
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($hvHost.HostCluster) {
            $clusterName = ($hvHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        if ($Refresh) {
            Write-Host "Refreshing LLDP information for all connected adapters.  This will take a momemnt." -ForegroundColor Yellow
        }
        $nics = Get-SCVMHostNetworkAdapter -VMHost $hvHost | ? { ($_.Name -notlike "*NDIS*") -or ($_.Name -notlike "*USB*") }
        $nicPropsArr = @()
        foreach ($nic in $nics) {
            $err = ""
            #if (! $nic.LldpInformation) {
            if ($Refresh) {
                if ($nic.ConnectionState -eq "Connected") {
                    #Write-Output "Refreshing LLDP information for $($nic.ConnectionName). Please wait... (TEMP)"
                    Set-SCVMHostNetworkAdapter -VMHostNetworkAdapter $nic -RefreshLldp -ErrorAction SilentlyContinue -ErrorVariable err | Out-Null
                }
            }
            #}
            if ($err) {
                $pSwitchVal = "Failed to fetch LLDP information"
            }
            else {
                $pSwitchVal = $nic.LldpInformation.SystemName
            }

            $hshNicProps = [ordered]@{
                Host       = $hvHost.Name.Split(".")[0]
                Cluster    = $clusterName
                NIC        = $nic.ConnectionName
                MAC        = $nic.MacAddress
                State      = $nic.ConnectionState
                MaxSpeed   = $nic.MaxBandwidth
                pSwitch    = $pSwitchVal
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
                NodeAddress = $hba.NodeAddress -replace '..(?!$)','$&:'
                PortAddress = $hba.PortAddress -replace '..(?!$)','$&:'
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
            $vms = Get-HVVmsOnCsv $csvName
            $used = ($storVol.Capacity / 1GB) - ($storVol.FreeSpace / 1GB)
            $usedPct = ($used / ($storVol.Capacity / 1GB))
            $hshStorVolProps = [ordered]@{
                Name        = $storVol.VolumeLabel
                Cluster     = ($storVol.VMHost.HostCluster.Name).Split(".")[0]
                Owner       = (Get-ClusterSharedVolume -Cluster $storVol.vmhost.hostcluster | ? { $_.name -eq $storvol.volumelabel }).OwnerNode.name
                Capacity    = [math]::Round($storVol.Capacity / 1GB, 2)
                Provisioned = ($vms | Measure-Object -Property totalgb -sum).sum
                Used        = [math]::round($used, 2)
                Free        = [math]::Round($storVol.Freespace / 1GB, 2)
                UsedPct     = "{0:P0}" -f [math]::round($usedPct, 2)
                LUNId       = $storVol.StorageDisk.SMLunId
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
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $vms = Get-SCVirtualMachine -VMMServer $vmmserver | ? { $_.location -match $csvName } #| select name, @{N="Size";E={[math]::round(($_.TotalSize/1GB),2)}}, location | sort size -Descending
        if (!$vms) {
            Write-Warning "There are no VMs on the CSV or there are no CSVs with that name."
            return
        }

        foreach ($vm in $vms) {
            $hDisks = Get-SCVirtualHardDisk -VM $vm
            $hshVMProps = [ordered]@{
                Name     = $vm.Name
                RAM      = [math]::Round($vm.Memory / 1KB, 0)
                UsedGB   = [math]::Round($vm.TotalSize / 1GB, 2)
                TotalGB  = [math]::Round((($hDisks | Measure-Object -Property MaximumSize -Sum).sum) / 1GB, 2)
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
            Status   = $vm.Status
            VMState  = $vm.VirtualMachineState
            CPU      = $vm.CPUCount
            MemGB    = [math]::Round($vm.Memory / 1KB, 0)
            Size     = [math]::Round($vm.TotalSize / 1GB, 2)
            HDSizeGB = [math]::Round((($hDisks | Measure-Object -Property MaximumSize -Sum).sum) / 1GB, 2)
            BackupTag = $vm.Tag
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
.PARAMETER Refresh
    Refresh the LLDP information for the interface. Optional.
.INPUTS
    System.String.  Get-HVHostLldpInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostLldpInfo returns the host name, MAC, connection state, speed, physical switch name, and physical port.
.EXAMPLE
    PS C:\> Get-HVHostLldpInfo <myVMHostName>
    Retrieves the physical switch and port information for each interface of the Hyper-V host <myVMHostName>.
.EXAMPLE
    PS C:\> Get-HVHostLldpInfo -Refresh <myVMHostName>
    Retrieves the physical switch/port information after first retrieving the information from the physical switch.
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
        if ($Refresh) {
            $vmmNics = Get-HVLldpInfo -hostName $hostName -Refresh
        }else {
            $vmmNics = Get-HVLldpInfo -hostName $hostName
        }
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
function Get-HVHostMPIOSettings {
    <#
.SYNOPSIS
    Retrieve the MPIO settings of a Hyper-V host.
.DESCRIPTION
    Retrieve the MPIO settings of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostMPIOSettings accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostMPIOSettings returns the MPIO settings of the Hyper-V host.
.EXAMPLE
    PS C:\> Get-HVHostMPIOSettings <myVMHostName>
    Retrieves the MPIO settings of the Hyper-V host <myVMHostName>.
.EXAMPLE
    PS C:\> Get-SCVMHostCluster <clustername> | Get-SCVMHost | Get-HVHostMPIOSettings | Out-GridView
    Retrieves the MPIO settings of all of the Hyper-V hosts in the cluster <clustername>.
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
        $hvHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$hvHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }

        # Script block to run on remote host(s)
        $remoteMPIOblock = {
            $mpiox = Get-MPIOSetting
            $arrvendor = Get-MSDSMSupportedHW | ? { $_.vendorid -eq "PURE" }
            $mpiox | Add-Member -NotePropertyName LoadBal -NotePropertyValue (Get-MSDSMGlobalDefaultLoadBalancePolicy)
            $mpiox | Add-Member -NotePropertyName VendorID -NotePropertyValue ($arrvendor.vendorid)
            $mpiox | Add-Member -NotePropertyName ProductID -NotePropertyValue ($arrvendor.productid)

            $mpiox
        }
        # Retrieve the MPIO settings from the host
        #$mpiosettings = Invoke-Command -ComputerName $($hvHost.Name) -Credential $pscred -ScriptBlock $remoteMPIOblock
        $mpiosettings = Invoke-Command -ComputerName $($hvHost.Name) -ScriptBlock $remoteMPIOblock
        $mpiosettings.psobject.properties.Remove('RunspaceId')
    
        $hshMPIOProperties = [ordered]@{}
        $mpiosettings.psobject.properties | Foreach { $hshMPIOProperties[$_.Name] = $_.Value }
        New-Object -type PSCustomObject -Property $hshMPIOProperties
    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostNicStats {
    <#
.SYNOPSIS
    Retrieve any packet discards and errors of a physical NIC of a Hyper-V host.
.DESCRIPTION
    Retrieve any packet discards and errors of a physical NIC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostNicStats accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostNicStats returns the hostname, NIC, NIC status, received packet errors/discards, outbound packet errors/discards.
.EXAMPLE
    PS C:\> Get-HVHostNicStats <myVMHostName>
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
        $vHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $nics = Get-NetAdapter -Physical -CimSession $cimsession
        foreach ($nic in $nics) {
            $nicStats = Get-NetAdapterStatistics -CimSession $cimSession -Name $nic.Name

            $hshNICStatsProperties = [ordered]@{
                Name                     = $nic.PSComputerName
                Cluster                  = $clusterName
                Date                     = Get-Date -format "yyyy-MM-dd HH:mm:ss"
                NIC                      = $nicStats.Name
                NICDesc                  = $nic.InterfaceDescription
                MAC                      = $nic.MacAddress
                Connection               = $nic.MediaConnectionState
                Status                   = $nic.Status
                ReceivedPacketErrors     = $nicStats.ReceivedPacketErrors
                OutboundPacketErrors     = $nicStats.OutboundPacketErrors
                ReceivedDiscardedPackets = $nicStats.ReceivedDiscardedPackets
                OutboundDiscardedPackets = $nicStats.OutboundDiscardedPackets
            }
            New-Object -type PSCustomObject -Property $hshNICStatsProperties
        }
        Remove-CimSession -CimSession $cimSession

    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostNicDrivers {
    <#
.SYNOPSIS
    Retrieve the NIC driver information of a physical NIC of a Hyper-V host.
.DESCRIPTION
    Retrieve the NIC driver information of a physical NIC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostNicDrivers accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostNicDrivers returns the hostname, cluster, NIC, driver information.
.EXAMPLE
    PS C:\> Get-HVHostNicDrivers <myVMHostName>
    Retrieves the physical NIC driver information of the Hyper-V host <myVMHostName>.
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
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $nics = Get-NetAdapter -Physical -CimSession $cimsession
        foreach ($nic in $nics) {

            $hshNICStatsProperties = [ordered]@{
                Name           = $hostName.Split(".")[0]
                Cluster        = $clusterName
                NIC            = $nic.Name
                NICDesc        = $nic.InterfaceDescription
                MAC            = $nic.MacAddress
                DriverProvider = $nic.DriverProvider
                DriverVersion  = $nic.DriverVersion
                DriverDate     = $nic.DriverDate
                DriverFileName = $nic.DriverFileName
            }
            New-Object -type PSCustomObject -Property $hshNICStatsProperties
        }
        Remove-CimSession -CimSession $cimSession

    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostNicVMQ {
    <#
.SYNOPSIS
    Retrieve the VMQ status (enabled/disabled) of a physical NIC of a Hyper-V host.
.DESCRIPTION
    Retrieve the VMQ status (enabled/disabled) of a physical NIC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostNicVMQ accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostNicVMQ returns the hostname, NIC, VMQ values.
.EXAMPLE
    PS C:\> Get-HVHostNicVMQ <myVMHostName>
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
        $vHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $nics = Get-NetAdapter -Physical -CimSession $cimsession
        foreach ($nic in $nics) {
            $nicVmq = Get-NetAdapterVmq -CimSession $cimSession -Name $nic.Name

            $hshNICStatsProperties = [ordered]@{
                Name             = $nic.PSComputerName
                Cluster          = $clusterName
                NIC              = $nic.Name
                MAC              = $nic.MacAddress
                Connection       = $nic.MediaConnectionState
                Status           = $nic.Status
                VMQEnabled       = $nicVmq.Enabled
                MaxProcessors    = $nicvmq.MaxProcessors
                NumReceiveQueues = $nicVmq.NumberOfReceiveQueues
                Description      = $nic.InterfaceDescription
            }
            New-Object -type PSCustomObject -Property $hshNICStatsProperties
        }
        Remove-CimSession -CimSession $cimSession

    }
    
    end {
    }
}
###################################
###################################
function Get-HVNetworkVlans {
    <#
.SYNOPSIS
    Retrieve the network names and VLANs of a Hyper-V Logical Network.
.DESCRIPTION
    Retrieve the network names and VLANs of a Hyper-V Logical Network.
.PARAMETER logicalNetwork
    Specifies the name of the Hyper-v Logical Network. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVNetworkVlans accepts a string as the name of the Hyper-V Logical Network.
.OUTPUTS
    PSCustomObject. Get-HVNetworkVlans returns the network name and VLAN ID for each network.
.EXAMPLE
    PS C:\> Get-HVNetworkVlans <myLogicalNetworkName>
    Retrieves the network name and VLAN ID of the Hyper-V Logical Network <myLogicalNetworkName>.
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
            HelpMessage = 'Please logical network name (ie. internal, dmz, etc).')
        ]
        [String] $lNetworkName
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
        $lNetwork = Get-SCLogicalNetwork -ErrorAction SilentlyContinue | ? { $_.name -match $lNetworkName }
        if (!$lNetwork) {
            Write-Warning "There was an issue. Please verify that the logical network name, $lNetworkName, is correct."
            break
        }
        $networkDef = Get-SCLogicalNetworkDefinition -LogicalNetwork $lNetwork
        $subnets = $networkDef.SubnetVLans
        foreach ($subnet in $subnets) {
            $hshSubnetProperties = [ordered]@{
                LogicalNetwork = $networkDef.LogicalNetwork
                Subnet = $subnet.Subnet
                VLANID = $subnet.VLanID
            }
            New-Object -type PSCustomObject -Property $hshSubnetProperties
        }

    }
    
    end {
    }
}
###################################
###################################
function Get-HVVMTimeSynchronization {
    <#
.SYNOPSIS
    Checks whether the VMIntegrationService Time Synchronization is enabled on a VM.
.DESCRIPTION
    Checks whether the VMIntegrationService Time Synchronization is enabled on a VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name of the VM. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVVMTimeSynchronization accepts a string as the name VM.
.OUTPUTS
    Status of the Time Synchronization service (enabled/disabled).
.EXAMPLE
    PS C:\> Get-HVVMTimeSynchronization <VMName>
    Retrieves the Time Synchronization value for the VM <VMName>.
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

        #create a new cimsession to the host running the VM
        $cimsession = New-CimSession $vm.HostName
        $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ? { $_.name -eq "Time Synchronization" }
        $hshTimeSyncProps = [ordered]@{
            VMName  = $vm.Name
            Name    = $timesync.Name
            Enabled = $timesync.Enabled
        }
        New-Object -type PSCustomObject -Property $hshTimeSyncProps
        
    }
    
    end {
    }
}
###################################
###################################
function Enable-HVVMTimeSynchronization {
    <#
.SYNOPSIS
    Enables the Time Synchronization within the VMIntegrationService of a VM.
.DESCRIPTION
    Enables the Time Synchronization within the VMIntegrationService of a VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name of the VM. This parameter is mandatory.
.INPUTS
    System.String.  Enable-HVVMTimeSynchronization accepts a string as the name VM.
.OUTPUTS
    Status of the Time Synchronization service (enabled/disabled).
.EXAMPLE
    PS C:\> Enable-HVVMTimeSynchronization <VMName>
    Enables Time Synchronization for the VM <VMName>.
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

        #create a new cimsession to the host running the VM
        $cimsession = New-CimSession $vm.HostName
        $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ?{$_.name -eq "Time Synchronization"}
        if ($timesync.Enabled -eq $false) {
            Write-Host "Enabling Time Synchronization for $($vm.name)... " #-NoNewLine
            Enable-VMIntegrationService -CimSession $cimsession -VMName $vm.Name  -Name "Time Synchronization"
            $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ?{$_.name -eq "Time Synchronization"}
            Write-Host "Time Synchronization has been enabled."
            $hshTimeSyncProps = [ordered]@{
                VMName  = $vm.Name
                Name    = $timesync.Name
                Enabled = $timesync.Enabled
            }
            New-Object -type PSCustomObject -Property $hshTimeSyncProps
        } else {
            Write-Host "Time Synchronization has already been enabled on this VM."
        }
        
    }
    
    end {
    }
}
###################################
###################################
function Disable-HVVMTimeSynchronization {
    <#
.SYNOPSIS
    Disables the Time Synchronization within the VMIntegrationService of a VM.
.DESCRIPTION
    Disables the Time Synchronization within the VMIntegrationService of a VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name of the VM. This parameter is mandatory.
.INPUTS
    System.String.  Disable-HVVMTimeSynchronization accepts a string as the name VM.
.OUTPUTS
    Status of the Time Synchronization service (enabled/disabled).
.EXAMPLE
    PS C:\> Disable-HVVMTimeSynchronization <VMName>
    Disables Time Synchronization for the VM <VMName>.
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

        #create a new cimsession to the host running the VM
        $cimsession = New-CimSession $vm.HostName
        $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ?{$_.name -eq "Time Synchronization"}
        if ($timesync.Enabled) {
            Write-Host "Disabling Time Synchronization for $($vm.name)... " #-NoNewLine
            Disable-VMIntegrationService -CimSession $cimsession -VMName $vm.Name  -Name "Time Synchronization"
            $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ?{$_.name -eq "Time Synchronization"}
            Write-Host "Time Synchronization has been disabled."
            $hshTimeSyncProps = [ordered]@{
                VMName  = $vm.Name
                Name    = $timesync.Name
                Enabled = $timesync.Enabled
            }
            New-Object -type PSCustomObject -Property $hshTimeSyncProps
    
        } else {
            Write-Host "Time Synchronization has already been disabled on this VM."
        }
        
    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostFCDrivers {
    <#
.SYNOPSIS
    Retrieve the FC driver information of a physical FC of a Hyper-V host.
.DESCRIPTION
    Retrieve the FC driver information of a physical FC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostFCDrivers accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostFCDrivers returns the hostname, cluster, FC, driver information.
.EXAMPLE
    PS C:\> Get-HVHostFCDrivers <myVMHostName>
    Retrieves the physical FC driver information of the Hyper-V host <myVMHostName>.
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
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $fcAdapters = Invoke-Command -ComputerName $hostName -ScriptBlock { Get-WmiObject Win32_PnPSignedDriver | ? { $_.devicename -like "*fibre*" } }
        foreach ($fcAdapter in $fcAdapters) {

            $hshFCDriverProperties = [ordered]@{
                Name           = $hostName.Split(".")[0]
                Cluster        = $clusterName
                FC             = $fcAdapter.DeviceName
                DriverProvider = $fcAdapter.DriverProviderName
                DriverVersion  = $fcAdapter.DriverVersion
                DriverDate     = (($fcAdapter.DriverDate.split(".")[0]).substring(0,8)).Insert(4,'-').Insert(7,'-')
                #DriverFileName = $nic.DriverFileName
            }
            New-Object -type PSCustomObject -Property $hshFCDriverProperties
        }

    }
    
    end {
    }
}
###################################
###################################
function Get-HVHostFCInfo {
    <#
.SYNOPSIS
    Retrieve the FC information of a physical FC of a Hyper-V host.
.DESCRIPTION
    Retrieve the FC information of a physical FC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostFCInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostFCInfo returns the hostname, manufacturer, model, driver information.
.EXAMPLE
    PS C:\> Get-HVHostFCInfo <myVMHostName>
    Retrieves the physical FC information of the Hyper-V host <myVMHostName>.
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
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $fcAdapters = Invoke-Command -ComputerName $hostName -ScriptBlock { Get-WmiObject -Class MSFC_FCAdapterHBAAttributes -Namespace root\WMI }
        foreach ($fcAdapter in $fcAdapters) {

            $hshFCProperties = [ordered]@{
                Name             = $hostName.Split(".")[0]
                Cluster          = $clusterName
                Active           = $fcAdapter.Active
                Manufacturer     = $fcAdapter.Manufacturer
                Model            = $fcAdapter.Model
                Modeldescription = $fcAdapter.ModelDescription
                DriverName       = $fcAdapter.DriverName
                DriverVersion    = $fcAdapter.DriverVersion
            }
            New-Object -type PSCustomObject -Property $hshFCProperties
        }

    }
    
    end {
    }
}
###################################
###################################
function Move-HVVM {
    <#
    .SYNOPSIS
        Migrate VM to a different host in the same cluster.
    .DESCRIPTION
        Migrate VM to a different host in the same cluster.
    .PARAMETER vmName
        Specifies the name of the VM to be migrated. This parameter is mandatory.
    .PARAMETER vmHostName
        Specifies the name of the host to migrate the VM to. This parameter is mandatory.
    .INPUTS
        System.String.  Move-HVVM accepts a strings for both paramaters.
    .OUTPUTS
        VirtualMachine object.
    .EXAMPLE
        PS C:\> Move-HVVM <vmname> <vmhostname>
    .NOTES
        The following Environment variable(s) must be set prior to running:
            $Env:vmm_server = <server>
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the VM name')
        ]
        [String] $vmName,
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the hostname to migrate to')
        ]
        [String] $vmHostName
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
        $vm = Get-SCVirtualMachine $vmName
        if (!$vm) {
            Write-Warning "The VM, $vmName, could not be found."
            return
        }
    
        $destVmHost = Get-SCVMHost $vmHostName
        # Verify if host is part of the same cluster
        $currentVmHost = $vm.VMHost
        if ($currentVmHost.name -eq $destVmHost.Name) {
            Write-Warning "The current host, $($currentVmHost.computername), is the same as the destination host, $($destVmHost.computerName)"
            return
        }
        $availHosts = $vm.VMHost.HostCluster.Nodes | select Name -ExpandProperty Name | sort
        if ($availHosts -contains $destVmHost.Name) {
            Write-Host "Moving VM....."
            Move-SCVirtualMachine -VM $vm -VMHost $destVmHost
        }
        else {
            Write-Error "$vmHostName does not exist in the same cluster"
            return
        }
    }
            
    end {
    }
}
###################################
###################################
function Add-HVClusterCSV {
    <#
    .SYNOPSIS
        Add a new CSV to a cluster.
    .DESCRIPTION
        Add a new disk to a host and then make that disk a CSV in the cluster.
    .PARAMETER clusterName
        Specifies the name of the cluster where the CSV will be located. This parameter is mandatory.
    .PARAMETER disklabel
        Specifies the name of the new CSV. This parameter is mandatory.
    .PARAMETER diskSerialNo
        Specifies the UUID of the lun. Supplied by the storage group. This parameter is mandatory.
    .INPUTS
        System.String.  Add-HVClusterCSV accepts a strings for all paramaters.
    .OUTPUTS
        New CSV.
    .EXAMPLE
        PS C:\> Add-HVClusterCSV <clusterName> <disklabel> <diskSerialNo>
    .NOTES
        The following Environment variable(s) must be set prior to running:
            $Env:vmm_server = <server>
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the cluster name:')
        ]
        [String] $clusterName,
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the name of the CSV:')
        ]
        [String] $disklabel,
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the UUID/SerialNumber of the lun/disk:')
        ]
        [String] $diskSerialNo
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
        $vhostname = Get-SCVMHostCluster $clusterName | Get-SCVMHost | select computername -ExpandProperty computername | Get-Random
        # Script block to add and configure a new disk on remote host(s)  -- Think "Disk Manager" on the host
        $remoteDiskblock = {
            $newdisk = Get-Disk | ? { ($_.PartitionStyle -eq "RAW") -and ($_.SerialNumber -eq $using:diskSerialNo) }
            if (!($newdisk)) {
                Write-Host "That disk does not exist. Please verify the VMM you're connected to and that the cluster and disk serial number are correct." -ForegroundColor Yellow
                return 1
                Exit
            }
            $diskNum = $newdisk.Number
            # Online the disk
            if ($newdisk.IsOffline) {
                Set-Disk -Number $diskNum -IsOffline $false
            }
            # Initialize and format the disk
            $d1 = Get-Disk -Number $diskNum | `
                Initialize-Disk -PartitionStyle GPT -PassThru | `
                New-Partition -AssignDriveLetter -UseMaximumSize 
        
            Format-Volume -DriveLetter $d1.Driveletter -FileSystem NTFS -NewFileSystemLabel $using:diskLabel -AllocationUnitSize 65536 -Confirm:$false -ErrorAction SilentlyContinue
        }
        
        $diskRslt = Invoke-Command -ComputerName $vHostName -ScriptBlock $remoteDiskblock
        if ($diskRslt -eq 1) {return}
        
        #####################################################################
        
        # Script block to add a new disk to the cluster and CSV -- Think "Failover CLuster Manager" on the host
        $remoteCSVblock = {
            $availDisk = Get-ClusterAvailableDisk
            $availDiskName = $availDisk.name
            $availDisk | Add-ClusterDisk
            Add-ClusterSharedVolume -Name $availDiskName

            # Rename the CSV from "Cluster Disk 1" to it's proper name    
            (Get-ClusterSharedVolume -Name $availDiskName).Name = $using:diskLabel
            Get-ClusterSharedVolume -Name $using:diskLabel | ft -AutoSize # Display to user

            # Rename directory in cluster shared storage directory from "Volume1" to it's proper name
            $csv = Get-ClusterSharedVolume -Name $using:diskLabel
            $volName = ($csv.SharedVolumeInfo[0].FriendlyVolumeName).Split("\")[-1]
            $parentPath = Split-Path -Parent $csv.SharedVolumeInfo[0].FriendlyVolumeName
        
            Get-ChildItem -Path $parentPath -Directory | `
                ForEach-Object {
                if ($_.Name -match $volName) {
                    Rename-Item -Path $_.FullName -NewName ($_.Name -replace $volName, $using:diskLabel)
                }
            }
            Get-ChildItem -Path $parentPath -Directory | ?{$_.name -eq $using:diskLabel} | ft -AutoSize # Display to user
        }
        
        Invoke-Command -ComputerName $vHostName -ScriptBlock $remoteCSVblock
    }
            
    end {
    }
}
###################################
###################################
