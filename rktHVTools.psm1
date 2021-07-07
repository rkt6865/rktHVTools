function Connect-VMMServer {
    <#
    .SYNOPSIS
        Connect to System Center Virtual Machine Manager.
    .DESCRIPTION
        Establish a connection to a specific Virtual Machine Manager (VMM) server.
        This could be a local or remote VMM. The function is dependent on some Environment variables.  See Notes below.
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Connect-VMMServer
        Connects to a VMM server specified in the $Env:vmm_server variable.
    .EXAMPLE
        PS C:\> $VMMServer = Connect-VMMServer
        Create a variable containing the VMM server connetion.
    .NOTES
        The following Environment variable(s) must be set prior to running:
            $Env:vmm_username = <username>
            $Env:vmm_password = <password>
            $Env:vmm_server = <server>
    #>
    
    [CmdletBinding()]
    param (
    )
        
    begin {
    }
    
    process {
        # Check if username/password Environment variables have been set
        if (!(Test-Path Env:\vmm_username) -or !(Test-Path Env:\vmm_password) -or !(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variables need to be set prior to connect to the VMM server" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_username = <username>" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_password = <password>" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <server>" -ForegroundColor Yellow
            break
        }
    
        $vmm_username = $env:vmm_username
        $vmm_password = $env:vmm_password
        $vmm_server = $env:vmm_server
    
        # Create SecureString object needed to create PSCredential object
        $secureString = ConvertTo-SecureString -AsPlainText -Force -String $vmm_password
        # Create PSCredential
        $creds = New-Object System.Management.Automation.PSCredential ($vmm_username, $secureString)
    
        Get-SCVMMServer -ComputerName $vmm_server -Credential $creds
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
        Retrieve the amount of VMs, memory and CPU usage for each VMHost in a particular cluster.
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
        $vmm_server = $Env:vmm_server
    }
        
    process {
        $clstr = Get-SCVMHostCluster -VMMServer $vmm_server -Name $clusterName -ErrorAction Stop
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
function Get-HVCsvInfo {
    <#
    .SYNOPSIS
        Retrieve basic information of the Clustered Shared Volumes (CSVs) in a cluster.
    .DESCRIPTION
        Retrieves the name, capacity, amount used, and amount free for each CSV in a Hyper-V compute cluster.
        The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
    .PARAMETER ClusterName
        Specifies the name of the Hyper-V cluster containting the storage of interest. This parameter is mandatory.
    .INPUTS
        System.String.  Get-HVCsvInfo accepts a string as the name of the cluster.
    .OUTPUTS
        PSCustomObject. Get-HVCsvInfo returns the CSV name, capacity, used space, free space, and amount used percentage for each CSV in the cluster.
    .EXAMPLE
        PS C:\> Get-HVCsvInfo <myClusterName>
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
        $vmm_server = $Env:vmm_server
    }
        
    process {
        $clstr = Get-SCVMHostCluster -VMMServer $vmm_server -Name $clusterName -ErrorAction Stop
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found!"
            return
        }
        $csvs = $clstr.SharedVolumes | sort name
        foreach ($csv in $csvs) {
            $used = ($csv.Capacity / 1GB) - ($csv.FreeSpace / 1GB)
            $usedPct = ($used / ($csv.Capacity / 1GB))
            $hshCsvProps = [ordered]@{
                Name     = $csv.VolumeLabel
                Capacity = [math]::Round($csv.Capacity / 1GB, 2)
                Used     = [math]::round($used, 2)
                Free     = [math]::Round($csv.Freespace / 1GB, 2)
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
    
        $vmm_server = $Env:vmm_server
    }
        
    process {
        $vm = Get-SCVirtualMachine -VMMServer $vmm_server $vmname
        if (!$vm) {
            Write-Warning "The VM, $vmname, could not be found."
            return
        }
    
        $vDiskDrives = Get-SCVirtualDiskDrive -VMMServer $vmm_server -VM $vm
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
        PSCustomObject. Get-HVHostHardware returns the name, manufacturer, model, memory, CPU sockets, and total CPUs.
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
            HelpMessage = 'Enter the host name.')
        ]
        [String] $hostName
    )
        
    begin {
    }
        
    process {
        $sys = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $hostName -ErrorAction SilentlyContinue
        if ($sys -eq $null) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
    
        $hshSysProperties = [ordered]@{
            Name         = $sys.Name
            Manufacturer = $sys.Manufacturer
            Model        = $sys.Model
            Mem          = [math]::Round($sys.TotalPhysicalMemory / 1gb, 0)
            Sockets      = $sys.NumberOfProcessors
            TotProcs     = $sys.NumberOfLogicalProcessors
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
        PSCustomObject. Get-HVLldpInfo returns the host name, MAC, connection state, speed, physical switch name, physical port and description.
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
    
        $vmm_server = $Env:vmm_server
    }
        
    process {
        $hvHost = Get-SCVMHost -VMMServer $vmm_server -ComputerName $hostName -ErrorAction SilentlyContinue
        if (! $hvHost) {
            Write-Output "The Hyper-V host, $hostName, does not exit."
            break
        }
        $nics = Get-SCVMHostNetworkAdapter -VMHost $hvHost | ? { ($_.Name -notlike "*NDIS*") -and ($_.Name -notlike "*USB*") }
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
