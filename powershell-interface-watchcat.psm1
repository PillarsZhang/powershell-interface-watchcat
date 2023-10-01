function Watch-Cat {
<#
.SYNOPSIS
    Check the availability of the network and automatically restart the network adapter. (Just like Openwrt's WatchCat - network watchdog utility)

.DESCRIPTION
    The Watch-Cat function continuously monitors network connectivity by pinging a specified address or default gateway. If the ping fails for a specified number of times, it can attempt to restart the network adapter to recover the connection.

.PARAMETER WatchInterface
    Specifies the network interface to monitor. This can be the interface alias, interface index, or interface description.

.PARAMETER PingAddress
    Specifies the address to ping. If not provided, the default gateway of the specified interface will be used.

.PARAMETER PingDelay
    Specifies the delay in seconds between each ping attempt. The default value is 10 seconds.

.PARAMETER MaxFailedAttempts
    Specifies the maximum number of consecutive ping failures before attempting to restart the network adapter. The default value is 3.

.PARAMETER MaxRestartAttempts
    Specifies the maximum number of restart attempts to recover the connection. The default value is 3.

.PARAMETER RestartDelay
    Specifies the delay in seconds after restarting the network adapter. The default value is 30 seconds.

.EXAMPLE
    Watch-Cat -WatchInterface "以太网"
    For users whose system language is Chinese, the specific interface name can be viewed by "Get-NetIPConfiguration" in PowerShell (InterfaceAlias).

.EXAMPLE
    Watch-Cat -WatchInterface "Ethernet" -PingAddress "8.8.8.8" -PingDelay 5 -MaxFailedAttempts 5 -MaxRestartAttempts 2 -RestartDelay 60
    Monitors the "Ethernet" interface by pinging "8.8.8.8" every 5 seconds. If the ping fails 5 times consecutively, it will attempt to restart the network adapter up to 2 times, with a 60-second delay after each restart.

.NOTES
    Author: Pillars Zhang
    Date: September 25, 2023
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WatchInterface,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$PingAddress,

        [Parameter(Mandatory = $false)]
        [int]$PingDelay = 20,

        [Parameter(Mandatory = $false)]
        [int]$MaxFailedAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int]$MaxRestartAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int]$RestartDelay = 60
    )

    $ErrorActionPreference = "Stop"

    $WatchNetIPConfiguration = Get-NetIPConfiguration -InterfaceAlias $WatchInterface
    if ($WatchNetIPConfiguration) {
        $WatchNetIPConfiguration
    } else {
        throw "Failed to find interface."
    }

    if (-not $PingAddress) {
        $GatewayMode = $true
    } else {
        $pingDest = $PingAddress
    }

    if ($GatewayMode) {
        $pingDest = Get-Gateway $WatchInterface
        if ($pingDest) {
            Write-Log "The default IPV4 gateway for interface ""$WatchInterface"" is ""$pingDest""."
        } else {
            Write-Log "Currently unable to retrieve the IPV4 gateway for interface ""$WatchInterface"", it may still be starting up. Sleeping 30 seconds..."
            Start-Sleep -Seconds 30
            $pingDest = Get-Gateway $WatchInterface
        }
    }

    if ($pingDest) {
        try {
            Test-Connection -ComputerName $pingDest -Count 1
        } catch {
            Write-Log "An error occurred during early ping, but watchcat will continue to run: $($_.Exception.Message)"
        }
    }

    Write-Log "Keep watching ""$WatchInterface"" on ""$pingDest"" ..."

    $failedAttempts = 0
    $restartAttempts = 0

    while ($true) {

        if ($GatewayMode -and ($failedAttempts -gt 0)) {
            $pingDest = Get-Gateway $WatchInterface
            Write-Log "Reload default IPV4 gateway for interface ""$WatchInterface"" as ""$pingDest""."
        }

        if ($pingDest) {
            $pingResult = Test-Connection -ComputerName $pingDest -Count 1 -Quiet
            if ($pingResult) {
                if ($restartAttempts -gt 0) {
                    Write-Log "Connection has been recovered."
                }
                $failedAttempts = 0
                $restartAttempts = 0
            } else {
                $failedAttempts++
                Write-Log "Ping $pingDest failed ($failedAttempts/$MaxFailedAttempts)"
            }
        } else {
            $failedAttempts++
            Write-Log "Bad interface or no address ($failedAttempts/$MaxFailedAttempts)"
        }

        if ($failedAttempts -ge $MaxFailedAttempts) {
            $restartAttempts++
            if ($restartAttempts -le $MaxRestartAttempts) {
                $WatchNetAdapter = Get-NetAdapter -InterfaceAlias $WatchInterface
                Write-Log "Restarting network adapter ""$($WatchNetAdapter.InterfaceDescription)"" ($restartAttempts/$MaxRestartAttempts)"
                $WatchNetAdapter | Restart-NetAdapter
                Write-Log "Sleep $RestartDelay seconds ..."
                Start-Sleep -Seconds $RestartDelay
                $failedAttempts = 0
            } else {
                throw "Failed to recover connection. Stop watching."
            }
        } else {
            Start-Sleep -Seconds $PingDelay
        }
        
    }
}

function Get-Gateway {
<#
.SYNOPSIS
    Get the IPv4 default gateway for a specified network interface.

.DESCRIPTION
    The Get-Gateway function retrieves the IPv4 default gateway (NextHop) for a specified network interface.

.PARAMETER InterfaceAlias
    Specifies the network interface alias for which to retrieve the gateway.

.EXAMPLE
    Get-Gateway "Ethernet"
    Retrieves the IPv4 default gateway for the "Ethernet" network interface.
#>

    param (
        [parameter(Mandatory = $true)]
        [string]$InterfaceAlias
    )
    $WatchNetIPConfiguration = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias
    return $WatchNetIPConfiguration.IPv4DefaultGateway.NextHop
}

function Write-Log {
<#
.SYNOPSIS
    Writes a log message with a precise millisecond timestamp.

.DESCRIPTION
    The Write-Log function appends a log message with a timestamp to the console output. The timestamp includes the date, time, and milliseconds for precise logging.

.PARAMETER Message
    Specifies the log message to be written.

.EXAMPLE
    Write-Log -Message "This is a log message."
    Writes a log message with a timestamp to the console output:
    2023-09-26 10:15:23.456 - This is a log message.
#>

    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logMessage = "$timestamp - $Message"
    
    Write-Host $logMessage
}

Export-ModuleMember -Function Watch-Cat
