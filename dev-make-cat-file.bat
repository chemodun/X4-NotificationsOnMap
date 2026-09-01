@echo off
rem In-place dev packing of the substituted vanilla file, one catalog per game version.

..\..\XRCatTool.exe -dump -include "monitors.xpl" -in "8.0" -out "subst_v800.cat"
..\..\XRCatTool.exe -dump -include "monitors.xpl" -in "9.0" -out "subst_v900.cat"

set /p DUMMY=Hit ENTER to exit...
