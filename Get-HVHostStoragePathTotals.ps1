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
