..\..\..\..\XRCatTool.exe -dump -include "monitors.xpl" -in "out\notifications_on_map" -out "steam\notifications_on_map\subst_01.cat"
..\..\..\..\XRCatTool.exe -dump -exclude "monitors.xpl" -exclude "content.xml" -in "out\notifications_on_map" -out "steam\notifications_on_map\ext_01.cat"

set /p DUMMY=Hit ENTER to exit...
