@echo off
rem One package for 8.00 and 9.00. Common files go to ext_01; each version folder
rem becomes an ext_v/subst_v pair, which the engine mounts only on its exact version.
rem content.xml stays loose - it is read before any catalog is mounted.

set TOOL=..\..\..\..\XRCatTool.exe
set SRC=out\notifications_on_map
set DEST=steam\notifications_on_map

if not exist "%DEST%" mkdir "%DEST%"

rem common: everything outside the version folders
%TOOL% -dump -exclude "8.0/" -exclude "9.0/" -exclude "content.xml" -in "%SRC%" -out "%DEST%\ext_01.cat"

rem per version: the mod's own files
%TOOL% -dump -exclude "monitors.xpl" -in "%SRC%\8.0" -out "%DEST%\ext_v800.cat"
%TOOL% -dump -exclude "monitors.xpl" -in "%SRC%\9.0" -out "%DEST%\ext_v900.cat"

rem per version: the vanilla file this mod replaces
%TOOL% -dump -include "monitors.xpl" -in "%SRC%\8.0" -out "%DEST%\subst_v800.cat"
%TOOL% -dump -include "monitors.xpl" -in "%SRC%\9.0" -out "%DEST%\subst_v900.cat"

copy /y "%SRC%\content.xml" "%DEST%\content.xml"

set /p DUMMY=Hit ENTER to exit...
