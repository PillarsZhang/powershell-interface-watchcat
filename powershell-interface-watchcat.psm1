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
        [int]$PingDelay = 10,

        [Parameter(Mandatory = $false)]
        [int]$MaxFailedAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int]$MaxRestartAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int]$RestartDelay = 30
    )

    $ErrorActionPreference = "Stop"

    $NetIPInterface = (Get-NetIPConfiguration -InterfaceAlias $WatchInterface)
    if ($NetIPInterface) {
        $NetIPInterface
    } else {
        throw "Failed to find interface."
    }

    if (-not $PingAddress) {
        $GatewayMode = $true
    }

    if ($GatewayMode) {
        $PingAddress = $NetIPInterface.IPv4DefaultGateway.NextHop
        Write-Host "The default IPV4 gateway for the ""$WatchInterface"" interface is ""$PingAddress"", but it will be reset before each ping."
    }

    try {
        Test-Connection -ComputerName $PingAddress -Count 1
    } catch {
        Write-Host "An error occurred during early ping, but watchcat will continue to run: $($_.Exception.Message)"
    }

    if ($GatewayMode) {
        Write-Host "Keep watching ""$WatchInterface"" on gateway ..."
    } else {
        Write-Host "Keep watching ""$WatchInterface"" on ""$PingAddress"" ..."
    }    

    $failedAttempts = 0
    $restartAttempts = 0

    while ($true) {
        if ($GatewayMode) {
            $PingAddress = $NetIPInterface.IPv4DefaultGateway.NextHop
        }

        if ($PingAddress) {
            $pingResult = Test-Connection -ComputerName $PingAddress -Count 1 -Quiet
            if ($pingResult) {
                if ($restartAttempts -gt 0) {
                    Write-Host "Connection has been recovered."
                }
                $failedAttempts = 0
                $restartAttempts = 0
            } else {
                $failedAttempts++
                Write-Host "Ping $PingAddress failed ($failedAttempts/$MaxFailedAttempts)"
            }
        } else {
            $failedAttempts++
            Write-Host "Bad interface or no address ($failedAttempts/$MaxFailedAttempts)"
        }

        if ($failedAttempts -ge $MaxFailedAttempts) {
            $restartAttempts++
            if ($restartAttempts -le $MaxRestartAttempts) {
                Write-Host "Restarting network adapter ($restartAttempts/$MaxRestartAttempts)"
                Restart-NetAdapter -InterfaceAlias $WatchInterface -Confirm:$false
                Write-Host "Sleep $RestartDelay seconds ..."
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

Export-ModuleMember -Function Watch-Cat
