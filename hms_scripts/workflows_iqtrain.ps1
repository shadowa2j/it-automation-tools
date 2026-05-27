# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\workflows_iqtrain.ps1

# collect environmental variables to build URLs
$custPrefix = $env:COMPUTERNAME.ToLower().Substring(0,4)
$custDomain = $env:USERDNSDOMAIN.ToLower()
if ($env:userdomain.tolower() -like "iqms-cloud") {
    $binding = "$($custPrefix).iqtrain.$custdomain"
} else {
    $binding = "iqtrain.$custdomain"
}

# add workflows as a trusted site
Add-HMSTrustedSite -zone 1 -siteName $binding # Intranet
Add-HMSTrustedSite -zone 2 -siteName $binding # Trusted Sites

# set IE Protected mode (by disabling it)
Set-HMSIEProtectedMode -zone 1 -value 3 # Intranet
Set-HMSIEProtectedMode -zone 2 -value 3 # Trusted Sites

# set ActiveX Security (by removing it)
Set-HMSIEActiveX -zone 1 -value 0 # Intranet
Set-HMSIEActiveX -zone 2 -value 0 # Trusted Sites

# launch Internet Explorer (because we use ActiveX)
Write-Host -ForegroundColor green "`nLaunching Work..."
Set-Location "C:\Program Files (x86)\Internet Explorer"
Start-Process -FilePath "C:\Program Files (x86)\Internet Explorer\iexplore.exe" -ArgumentList "http://$($binding)/pls/dad_iqora/web_approvals.get_data"
