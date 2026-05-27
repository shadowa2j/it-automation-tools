Param(
    [Parameter(Mandatory=$true, Position=1, HelpMessage="DBAlias. For example: IQORA?")]
    [string]$DBAlias,

    [Parameter(Mandatory=$true, Position=2, HelpMessage="Enter the DBA Username:")]
    [string]$DBA_Username,

    [Parameter(Mandatory=$true, Position=3,HelpMessage="Enter the password for the DBA User specified")]
    [securestring]$Password

)

# convert password to plain text so we can throw it into SQLPLUS
$passwordConvert = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

# prepare SQL Files
$sqlFile = "$($env:USERPROFILE)\Temp-getUsers.sql"
if ((Test-Path -Path $sqlFile) -eq $false) {
    New-Item -Path $sqlFile
} else {
    Remove-Item -Path $sqlFile
    New-Item -Path $sqlFile
}

$outputfile = "$env:USERPROFILE\Temp-outputUsers.txt"
if ((Test-Path -Path $outputfile) -eq $true) {
    Remove-Item -Path $outputfile
}
    
Add-Content -path $sqlFile "spool on;"
Add-Content -path $sqlFile "set heading off;"
Add-Content -path $sqlFile "set feedback off;"
Add-Content -path $sqlFile "select distinct user_name from s_users order by user_name asc;"
Add-Content -path $sqlFile "spool off;"
Add-Content -path $sqlFile "exit;"

# queries users and output to file that we will sort and loop over
sqlplus -S $DBA_Username/$passwordConvert@$DBAlias @$sqlFile | Out-File $outputfile
$array = Get-Content $outputfile | Select-Object -uniq

foreach ($item in $array) {
    $tempfolder = "C:\Program Files (x86)\IQMS\IQWin32\Temp\$($item)"
    if ($false -eq (Test-Path -Path "$tempfolder")) {
    New-Item -Path $tempfolder -ItemType Directory -Verbose
    }
}

# clean up
Remove-Item $sqlFile
Remove-Item $outputfile

Write-Host -ForegroundColor Green "Done"
Start-Sleep 3
