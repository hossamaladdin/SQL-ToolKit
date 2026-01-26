Azure Bastion App Mode Extension v2.1
======================================

PERMANENT LOCATION:
C:\Users\hossam.aladdin\Documents\Chrome Extensions\Azure-Bastion-App-Mode

This extension automatically opens Azure Bastion URLs in popup windows with minimal borders.

HOW IT WORKS:
-------------
- Background script monitors all tabs for Bastion URLs
- When detected, MOVES the tab to a new popup window (preserves session!)
- Does NOT close/recreate the tab - keeps authentication context intact
- Content script also intercepts window.open calls as fallback
- Result: Same as Chrome's "Install as app" but automatic

INSTALLATION:
-------------
1. Open Chrome: chrome://extensions/
2. Enable "Developer mode" (top-right toggle)
3. Click "Load unpacked"
4. Select this folder: C:\Users\hossam.aladdin\Documents\Chrome Extensions\Azure-Bastion-App-Mode
5. Done!

USAGE:
------
Just click "Open in new browser tab" in Azure Portal Bastion page.
The tab will automatically convert to a popup window with minimal borders.

UPDATES:
--------
When you need to update the extension, edit the files in this folder,
then go to chrome://extensions/ and click the reload button on the extension.

TROUBLESHOOTING:
----------------
If it's not working:
1. Check chrome://extensions/ - make sure extension is enabled
2. Check for errors in the extension (click "Errors" button)
3. Try reloading the extension
4. Refresh the Azure Portal page

VERSION HISTORY:
----------------
v2.1 - FIXED: Moves tab instead of recreating - preserves session/authentication
v2.0 - Hybrid approach: background + content script for maximum compatibility
v1.x - Previous versions (deprecated)
