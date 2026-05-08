cd ..\..

XRCatTool.exe -dump -include "monitors.xpl" -exclude "(content.xml)|(ui.xml)|(0001.*\.xml)|(.bak)" -in "extensions\notifications_on_map" -out "extensions\notifications_on_map\subst_01.cat"

set /p DUMMY=Hit ENTER to exit...
