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
