# ========================================================
# Cookbook:: prism_plastics
# Script:: printermap.ps1
#
# Copyright 2025, IQMS, Inc.
#
# All rights reserved - Do Not Redistribute
# For IQMS internal use only
# ========================================================
# Sets user specific default printer
Start-Sleep 5

switch ("$($env:USERDOMAIN.ToLower())\$($env:USERNAME.tolower())") {
    "prismplastics\p10_001" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp01"); break;}
    "prismplastics\p10_002" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp02"); break;}
    "prismplastics\p10_003" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp03"); break;}
    "prismplastics\p10_004" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp04"); break;}
    "prismplastics\p10_005" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp05"); break;}
    "prismplastics\p10_006" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp06"); break;}
    "prismplastics\p10_007" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp07"); break;}
    "prismplastics\p10_008" {(rundll32 printui.dll,PrintUIEntry /y /n "p10sd-bcp08"); break;}
    "prismplastics\p20_001" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp01"); break;}
    "prismplastics\p20_002" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp02"); break;}
    "prismplastics\p20_003" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp03"); break;}
    "prismplastics\p20_004" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp04"); break;}
    "prismplastics\p20_005" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp05"); break;}
    "prismplastics\p20_006" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp06"); break;}
    "prismplastics\p20_007" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp07"); break;}
    "prismplastics\p20_008" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp08"); break;}
    "prismplastics\p20_009" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp09"); break;}
    "prismplastics\p20_010" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp10"); break;}
    "prismplastics\p20_011" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp11"); break;}
    "prismplastics\p20_012" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp12"); break;}
    "prismplastics\p20_013" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp13"); break;}
    "prismplastics\p20_014" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp14"); break;}
    "prismplastics\p20_015" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp15"); break;}
    "prismplastics\p20_016" {(rundll32 printui.dll,PrintUIEntry /y /n "p20sd-bcp16"); break;}
    "prismplastics\p30_001" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp01"); break;}
    "prismplastics\p30_003" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp03"); break;}
    "prismplastics\p30_004" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp04"); break;}
    "prismplastics\p30_005" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp05"); break;}
    "prismplastics\p30_006" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp06"); break;}
    "prismplastics\p30_007" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp07"); break;}   
    "prismplastics\p30_009" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp09"); break;}
    "prismplastics\p30_011" {(rundll32 printui.dll,PrintUIEntry /y /n "p30sd-bcp11"); break;}
    "prismplastics\p40_001" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp01"); break;}
    "prismplastics\p40_002" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp02"); break;}
    "prismplastics\p40_003" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp03"); break;}
    "prismplastics\p40_004" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp04"); break;}
    "prismplastics\p40_005" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp05"); break;}
    "prismplastics\p40_006" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp06"); break;}
    "prismplastics\p40_007" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp07"); break;}
    "prismplastics\p40_008" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp08"); break;}
    "prismplastics\p40_009" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp09"); break;}
    "prismplastics\p40_010" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp10"); break;}
    "prismplastics\p40_011" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp11"); break;}
    "prismplastics\p40_012" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp12"); break;}
    "prismplastics\p40_013" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp13"); break;}
    "prismplastics\p40_014" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp14"); break;}
    "prismplastics\p40_015" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp15"); break;}
    "prismplastics\p40_016" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp16"); break;}
    "prismplastics\p40_017" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp17"); break;}
    "prismplastics\p40_018" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp18"); break;}
    "prismplastics\p40_019" {(rundll32 printui.dll,PrintUIEntry /y /n "P40sd-bcp19"); break;}
    "prismplastics\p40_020" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp20"); break;}
    "prismplastics\p40_021" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp21"); break;}
    "prismplastics\p40_022" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp22"); break;}
    "prismplastics\p40_023" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp23"); break;}
    "prismplastics\p40_024" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp24"); break;}
    "prismplastics\p40_025" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp25"); break;}
    "prismplastics\p40_026" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp26"); break;}
    "prismplastics\p40_027" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp27"); break;}
    "prismplastics\p40_028" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp28"); break;} 
    "prismplastics\p40_029" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp29"); break;}
    "prismplastics\p40_030" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp30"); break;}
    "prismplastics\p40_031" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp31"); break;}
    "prismplastics\p40_032" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp32"); break;}
    "prismplastics\p40_033" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp33"); break;}
    "prismplastics\p40_034" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp34"); break;}
    "prismplastics\p40_035" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp35"); break;}
    "prismplastics\p40_036" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp36"); break;}
    "prismplastics\p40_037" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp37"); break;}
    "prismplastics\p40_038" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp38"); break;}
    "prismplastics\p40_039" {(rundll32 printui.dll,PrintUIEntry /y /n "p40sd-bcp39"); break;}
    "prismplastics\p60_001" {(rundll32 printui.dll,PrintUIEntry /y /n "P60sd-bcp01"); break;}
    "prismplastics\p60_002" {(rundll32 printui.dll,PrintUIEntry /y /n "P60sd-bcp02"); break;}
    "prismplastics\p60_003" {(rundll32 printui.dll,PrintUIEntry /y /n "P60sd-bcp03"); break;}
    "prismplastics\p60_004" {(rundll32 printui.dll,PrintUIEntry /y /n "P60sd-bcp04"); break;}
    "prismplastics\p60_005" {(rundll32 printui.dll,PrintUIEntry /y /n "P60sd-bcp05"); break;}
    "prismplastics\p60_006" {(rundll32 printui.dll,PrintUIEntry /y /n "P60sd-bcp06"); break;}
    "prismplastics\p60_012" {(rundll32 printui.dll,PrintUIEntry /y /n "P60sd-bcp12"); break;}
    "prismplastics\p70_001" {(rundll32 printui.dll,PrintUIEntry /y /n "P70sd-bcp01"); break;}
    "prismplastics\p70_002" {(rundll32 printui.dll,PrintUIEntry /y /n "P70sd-bcp02"); break;}
    "prismplastics\p70_003" {(rundll32 printui.dll,PrintUIEntry /y /n "P70sd-bcp03"); break;}
    "prismplastics\p70_004" {(rundll32 printui.dll,PrintUIEntry /y /n "P70sd-bcp04"); break;}
    "prismplastics\p70_005" {(rundll32 printui.dll,PrintUIEntry /y /n "P70sd-bcp05"); break;}
    "prismplastics\p70_012" {(rundll32 printui.dll,PrintUIEntry /y /n "P70sd-bcp12"); break;}
}

Start-Sleep 1
