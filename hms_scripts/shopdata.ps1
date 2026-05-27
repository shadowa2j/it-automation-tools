# ========================================================
# Cookbook:: prism_plastics
# Script:: printermap.ps1
#
# Copyright 2020, IQMS, Inc.
#
# All rights reserved - Do Not Redistribute
# For IQMS internal use only
# ========================================================
# Sets user specific default printer
Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Write-Host -ForegroundColor Cyan "Initializing Printers..."
Start-Sleep 10;
Start-Process -FilePath "powershell.exe" -ArgumentList "-File `"C:\Users\Public\Documents\printermap.ps1`"" -NoNewWindow -Wait;
Set-Location 'C:\Program Files (x86)\IQMS\IQWin32'

# detect the user and domain. If found, set the work center and launch shopdata.
switch ("$($env:USERDOMAIN.ToLower())\$($env:USERNAME.tolower())") {
     "prismplastics\p10_001" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-001"'; break;}
     "prismplastics\p10_002" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-002"'; break;}
     "prismplastics\p10_003" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-003"'; break;}
     "prismplastics\p10_004" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-004"'; break;}
     "prismplastics\p10_005" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-005"'; break;}
     "prismplastics\p10_006" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-006"'; break;}
     "prismplastics\p10_007" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-007"'; break;}
     "prismplastics\p10_008" {Start-Process 'ShopData.exe' -ArgumentList 'machine="10-008"'; break;}
     "prismplastics\p20_001" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-001"'; break;}
     "prismplastics\p20_002" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-002"'; break;}
     "prismplastics\p20_003" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-003"'; break;}
     "prismplastics\p20_004" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-004"'; break;}
     "prismplastics\p20_005" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-005"'; break;}
     "prismplastics\p20_006" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-006"'; break;}
     "prismplastics\p20_007" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-007"'; break;}
     "prismplastics\p20_008" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-008"'; break;}
     "prismplastics\p20_009" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-009"'; break;}
     "prismplastics\p20_010" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-010"'; break;}
     "prismplastics\p20_011" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-011"'; break;}
     "prismplastics\p20_012" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-012"'; break;}
     "prismplastics\p20_013" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-013"'; break;}
     "prismplastics\p20_014" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-014"'; break;}
     "prismplastics\p20_015" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-015"'; break;}
     "prismplastics\p20_016" {Start-Process 'ShopData.exe' -ArgumentList 'machine="20-016"'; break;}
     "prismplastics\p30_001" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-001"'; break;}
     "prismplastics\p30_003" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-003"'; break;}
     "prismplastics\p30_004" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-004"'; break;}
     "prismplastics\p30_005" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-005"'; break;}
     "prismplastics\p30_006" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-006"'; break;}
     "prismplastics\p30_007" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-007"'; break;}
     "prismplastics\p30_009" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-009"'; break;}
     "prismplastics\p30_011" {Start-Process 'ShopData.exe' -ArgumentList 'machine="30-011"'; break;}
     "prismplastics\p40_001" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-001"'; break;}
     "prismplastics\p40_002" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-002"'; break;}
     "prismplastics\p40_003" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-003"'; break;}
     "prismplastics\p40_004" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-004"'; break;}
     "prismplastics\p40_005" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-005"'; break;}
     "prismplastics\p40_006" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-006"'; break;}
     "prismplastics\p40_007" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-007"'; break;}
     "prismplastics\p40_008" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-008"'; break;}
     "prismplastics\p40_009" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-009"'; break;}
     "prismplastics\p40_010" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-010"'; break;}
     "prismplastics\p40_011" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-011"'; break;}
     "prismplastics\p40_012" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-012"'; break;}
     "prismplastics\p40_013" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-013"'; break;}
     "prismplastics\p40_014" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-014"'; break;}
     "prismplastics\p40_015" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-015"'; break;}
     "prismplastics\p40_016" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-016"'; break;}
     "prismplastics\p40_017" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-017"'; break;}
     "prismplastics\p40_018" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-018"'; break;}
     "prismplastics\p40_019" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-019"'; break;}
     "prismplastics\p40_020" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-020"'; break;}
     "prismplastics\p40_021" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-021"'; break;}
     "prismplastics\p40_022" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-022"'; break;}
     "prismplastics\p40_023" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-023"'; break;}
     "prismplastics\p40_024" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-024"'; break;}
     "prismplastics\p40_025" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-025"'; break;}
     "prismplastics\p40_026" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-026"'; break;}
     "prismplastics\p40_027" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-027"'; break;}
     "prismplastics\p40_028" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-028"'; break;}
     "prismplastics\p40_029" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-029"'; break;}
     "prismplastics\p40_030" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-030"'; break;}
     "prismplastics\p40_031" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-031"'; break;}
     "prismplastics\p40_032" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-032"'; break;}
     "prismplastics\p40_033" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-033"'; break;}
     "prismplastics\p40_034" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-034"'; break;}
     "prismplastics\p40_035" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-035"'; break;}
     "prismplastics\p40_036" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-036"'; break;}
     "prismplastics\p40_037" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-037"'; break;}
     "prismplastics\p40_038" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-038"'; break;}
     "prismplastics\p40_039" {Start-Process 'ShopData.exe' -ArgumentList 'machine="40-039"'; break;}
     "prismplastics\p60_001" {Start-Process 'ShopData.exe' -ArgumentList 'machine="60-001"'; break;}
     "prismplastics\p60_002" {Start-Process 'ShopData.exe' -ArgumentList 'machine="60-002"'; break;}
     "prismplastics\p60_003" {Start-Process 'ShopData.exe' -ArgumentList 'machine="60-003"'; break;}
     "prismplastics\p60_004" {Start-Process 'ShopData.exe' -ArgumentList 'machine="60-004"'; break;}
     "prismplastics\p60_005" {Start-Process 'ShopData.exe' -ArgumentList 'machine="60-005"'; break;}
     "prismplastics\p60_006" {Start-Process 'ShopData.exe' -ArgumentList 'machine="60-006"'; break;}
     "prismplastics\p60_012" {Start-Process 'ShopData.exe' -ArgumentList 'machine="60-012"'; break;}
     "prismplastics\p70_001" {Start-Process 'ShopData.exe' -ArgumentList 'machine="70-001"'; break;}
     "prismplastics\p70_002" {Start-Process 'ShopData.exe' -ArgumentList 'machine="70-002"'; break;}
     "prismplastics\p70_003" {Start-Process 'ShopData.exe' -ArgumentList 'machine="70-003"'; break;}
     "prismplastics\p70_004" {Start-Process 'ShopData.exe' -ArgumentList 'machine="70-004"'; break;}
     "prismplastics\p70_005" {Start-Process 'ShopData.exe' -ArgumentList 'machine="70-005"'; break;}
     "prismplastics\p70_012" {Start-Process 'ShopData.exe' -ArgumentList 'machine="70-012"'; break;}
     # if user isn't defined, simply launch shopdata.exe without a workcenter ID.
     default {Start-Process 'ShopData.exe'; break;}
}
