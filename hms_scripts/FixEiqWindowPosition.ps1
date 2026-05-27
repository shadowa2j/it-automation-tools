$remoteApps = ("SmartPage.exe","IQWin32.exe", "IQSmartPage.exe", "IQCRM.exe")
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

Foreach ($app in $remoteApps) {
    # Convert the full process name, to a short name without .exe
    $appShort = $app.Substring(0, $app.IndexOf('.'))

    # Find all remoteApps running for the current user
    Write-Host -ForegroundColor Cyan "`nAttempting to find $($app)..."
    $processes = Get-WmiObject -Class win32_process | Where-Object {$_.name -eq $app} | Where-Object {$_.GetOwner().user -eq "$env:USERNAME"}
    
    # Find the specific process IDs associated to the remoteApp
    foreach ($process in $processes) {
        try {
        
            Stop-Process -Id $process.processId -Force -verbose
            Write-Host "$appShort was successfull terminated!" -ForegroundColor green
        }
        catch {
            Write-Host "Unable to stop process for $appShort. Please contact the IQMS Cloud Operations Service Desk." -ForegroundColor red
            Start-Sleep 5;
        }
    }
}

Write-Host -ForegroundColor Green "Done."

function Set-IQRegistry{
    Param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]$Path,
    [Parameter(Mandatory=$true, Position=2)]
    [string]$Property,
    [Parameter(Mandatory=$true, Position=3)]
    [string]$Value,
    [Parameter(Mandatory=$true, Position=4)]
    [ValidateSet("String", "Binary", "DWord", "QWord")]
    [string]$Type
    )

    if ($path -notlike "HKCU:\*"){
        throw "This is only intended to be used on HKCU registry entries"
    }

    if (!(Test-Path $Path)){
        
        # split the path at \ so we can test each folder for existence
        $entries = $Path.Split("\")

        # build the base path that we will add to for existence tests
        $currentPath = $entries[0] + "\" + $entries[1] + "\"

        # entries index 0 will be hkcu, 1 will be software
        # so start evaluating paths at index 2
        for ($i = 2; $i -lt $entries.Length; $i++){
            # update the path to test for
            $currentPath += $entries[$i] + "\"
            
            if (!(Test-Path $currentPath)){
                Write-Host "Creating $currentPath"
                New-Item -Path $currentPath -Verbose
            }
        }
    }

    Set-ItemProperty -Path $Path -Name $Property -Value $Value -Type $Type
}

Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQCRM.exe\FrmCRMMain -Property Left -Value 00000179 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQCRM.exe\FrmCRMMain -Property Top -Value 00000126 -Type DWord
Set-IQRegistry -Path "HKCU:\Software\IQMS\IQWin32\IQCRM.exe\IQDialogCheckBox\Prompt Before Closing CRM" -Property Left -Value 00000179 -Type DWord
Set-IQRegistry -Path "HKCU:\Software\IQMS\IQWin32\IQCRM.exe\IQDialogCheckBox\Prompt Before Closing CRM" -Property Top -Value 00000126 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQSPC.exe\FrmSPCInspectionSetup -Property Left -Value 00000179 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQSPC.exe\FrmSPCInspectionSetup -Property Top -Value 00000126 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQSPC.exe\TSPC_DM\PkInventory -Property Left -Value 00000179 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQSPC.exe\TSPC_DM\PkInventory -Property Top -Value 00000126 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQSTATUS.exe\FrmIQStatus -Property Left -Value 00000179 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\IQSTATUS.exe\FrmIQStatus -Property Top -Value 00000126 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\Iqwin32.exe\IQLauncher -Property Left -Value 00000179 -Type DWord
Set-IQRegistry -Path HKCU:\Software\IQMS\IQWin32\Iqwin32.exe\IQLauncher -Property Top -Value 00000126 -Type DWord