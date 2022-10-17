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
