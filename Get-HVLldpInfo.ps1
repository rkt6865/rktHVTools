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
                MAC        = $nic.MacAddress
                State      = $nic.ConnectionState
                MaxSpeed   = $nic.MaxBandwidth
                pSwitch    = $nic.LldpInformation.SystemName
                pPort      = $nic.LldpInformation.PortId
                #Desc       = $nic.LldpInformation.PortDescription
                lastUpdate = $nic.LldpInformation.UpdatedTimestamp
            }
            #$nicPropsArr += New-Object -type PSCustomObject -Property $hshNicProps
            New-Object -type PSCustomObject -Property $hshNicProps
            
        }
                
    }
    
    end {
        
    }
}
