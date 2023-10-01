# [PowerShell] Interface WatchCat

Check the availability of the network and automatically restart the network adapter. (Just like Openwrt's Watchcat - network watchdog utility)

The Watch-Cat function continuously monitors network connectivity by pinging a specified address or default gateway. If the ping fails for a specified number of times, it can attempt to restart the network adapter to recover the connection.

**Administrator privileges required!**

# Quick Start

```powershell
git clone https://github.com/PillarsZhang/powershell-interface-watchcat.git
cd .\powershell-interface-watchcat\
Import-Module .\ -Force
Get-Help Watch-Cat -Full
Watch-Cat -WatchInterface "以太网"
```

# Install as module

```powershell
$ModulePath = "$Home\Documents\WindowsPowerShell\Modules\powershell-interface-watchcat\"
New-Item -ItemType Directory -Path $ModulePath -Force
Copy-Item -Path .\powershell-interface-watchcat.psm1 -Destination $ModulePath -Force
```

```powershell
Write-Host "To import the module globally, append follow line to ""$Home\Documents\WindowsPowerShell\profile.ps1"""
Import-Module powershell-interface-watchcat
```

# Install as service

Install as module first. Modify the `arguments` in `powershell-interface-watchcat.winsw.xml` and `PSModulePath` in `env`. [winsw v2](https://github.com/winsw/winsw/tree/master) required.

Recommend using [pwsh](https://aka.ms/PSWindows) (the latest version of PowerShell) to reduce memory usage. Otherwise, please repleace `pwsh` to `powershell` in `yml` config file.

```powershell
# For most users
$WinswUri = "https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW.NET461.exe"
# $WinswUri = "https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe"
Invoke-WebRequest -Uri $WinswUri -OutFile ".\powershell-interface-watchcat.winsw.exe"
.\powershell-interface-watchcat.winsw.exe install
.\powershell-interface-watchcat.winsw.exe start
.\powershell-interface-watchcat.winsw.exe status
```

Logs are writing to `powershell-interface-watchcat.winsw.out.log`. If there are Chinese characters, use the `GB 2312` encoding.
