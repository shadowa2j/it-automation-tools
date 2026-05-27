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
Start-Sleep 5

switch ($env:username.ToUpper()) {

     "P30_001" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP01"); break;}
     "P30_003" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP03"); break;}
     "P30_004" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP04"); break;}
     "P30_005" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP05"); break;}
     "P30_006" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP06"); break;}
     "P30_007" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP07"); break;}
     "P30_009" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP09"); break;}
     "P30_011" {(rundll32 printui.dll,PrintUIEntry /y /n "P30SD-BCP11"); break;}
     "P40_001" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP01"); break;}
     "P40_002" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP02"); break;}
     "P40_003" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP03"); break;}
     "P40_004" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP04"); break;}
     "P40_005" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP05"); break;}
     "P40_006" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP06"); break;}
     "P40_007" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP07"); break;}
     "P40_008" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP08"); break;}
     "P40_009" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP09"); break;}
     "P40_010" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP10"); break;}
     "P40_011" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP11"); break;}
     "P40_012" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP12"); break;}
     "P40_013" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP13"); break;}
     "P40_014" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP14"); break;}
     "P40_015" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP15"); break;}
     "P40_016" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP16"); break;}
     "P40_017" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP17"); break;}
     "P40_018" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP18"); break;}
     "P40_019" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP19"); break;}
     "P40_020" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP20"); break;}
     "P40_021" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP21"); break;}
     "P40_022" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP22"); break;}
     "P40_023" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP23"); break;}
     "P40_024" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP24"); break;}
     "P40_025" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP25"); break;}
     "P40_026" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP26"); break;}
     "P40_027" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP27"); break;}
     "P40_028" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP28"); break;}
     "P40_029" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP29"); break;}
     "P40_030" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP30"); break;}
     "P40_031" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP31"); break;}
     "P40_032" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP32"); break;}
     "P40_033" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP33"); break;}
     "P40_034" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP34"); break;}
     "P40_035" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP35"); break;}
     "P40_036" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP36"); break;}
     "P40_037" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP37"); break;}
     "P40_038" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP38"); break;}
     "P40_039" {(rundll32 printui.dll,PrintUIEntry /y /n "P40SD-BCP39"); break;}
     "P70_001" {(rundll32 printui.dll,PrintUIEntry /y /n "P70SD-BCP01"); break;}
     "P70_002" {(rundll32 printui.dll,PrintUIEntry /y /n "P70SD-BCP02"); break;}
     "P70_003" {(rundll32 printui.dll,PrintUIEntry /y /n "P70SD-BCP03"); break;}
     "P70_004" {(rundll32 printui.dll,PrintUIEntry /y /n "P70SD-BCP04"); break;}
     "P70_005" {(rundll32 printui.dll,PrintUIEntry /y /n "P70SD-BCP05"); break;}
     "P70_012" {(rundll32 printui.dll,PrintUIEntry /y /n "P70SD-BCP07"); break;}

    # any other user
    "$($env:username.ToUpper())" {(rundll32 printui.dll,PrintUIEntry /y /n "IQMS_PDF_Printer"); break}
}

Start-Sleep 1