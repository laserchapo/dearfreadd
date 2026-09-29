# Controller sequence — background AHK v2

Start the script stopped. Record the actual three click targets for each browser:

1. Click Record click 1 in the script; hover over the first intended button for three seconds.
2. Navigate the website manually if needed to reveal the next target. Click Record click 2; hover over the second target for three seconds.
3. Click Record click 3; hover over the message input for three seconds.

Use the same browser for all three points. After the third point, its assignment saves automatically. Repeat for additional browsers. Cancel recording discards only an unfinished recording. Existing assignments remain until replaced by a complete three-point recording.

Click Test one cycle first. Start all repeats the original 20-step order. Ctrl+Alt+F12 stops. Closing the panel stops runs.

Steps & settings contains four message boxes and nine delays. Save applies changes to the next run. Reset restores the imported message and timing defaults. Coordinates now come from the three recorded points, replacing the original viewport coordinates that did not match the current layout. Old origin-only assignments must be recorded again; they cannot run until all three points exist.

The original default explicit waits total 3,700 ms. Two additional adjustable waits now protect the fourth message: 250 ms after the third Enter, and 1,000 ms after the fourth Enter before the next skip. Existing saved wait values are retained from the user-confirmed working version. Each browser has independent scheduling. Moving a window is supported; resizing, changing zoom, scrolling or changing page layout may require recording the points again.

Saved assignments restore only while those same browser windows remain open. Reopened windows need recording again.

Background text entry requires an empty input before each message; it does not implement browser DOM fill/replace. Background input may still be ignored by some browser controls. Test sent means events were sent, not that the website received them. No live messages were sent during development.



Current input matches the user-confirmed working version: ControlClick with NA Pos, ControlSendText, and ControlSend to each saved browser window. No strict page-control detection is required. Click previews, reuse of saved points, Test one cycle, and Test clicks only remain available. The extra fourth-message waits are processing time, not verified delivery acknowledgments.


Chrome sessions: every Open sessions launch creates a unique temporary user-data folder and opens Chrome in Incognito mode. The same session number never reuses cookies or logins, including after restarting the PC. Close all windows belonging to a session to end it. Keep chrome-session-cleanup.ahk beside the main script: it runs independently and removes the owned temporary profile after its Chrome process exits, retrying locked files. Shutdown leftovers are never reused and are retried when a later session closes. Old persistent chrome-sessions folders are left untouched and are no longer opened by this launcher. The website/count preferences and all AHK coordinates, messages and timing settings still persist. Place browsers on the correct page with the same size/layout/zoom, then use Add windows - reuse 3 points. The launcher does not start the workflow automatically. Local tests cover unique paths, launch flags, UI, cleanup and protection of unowned folders; no live browser was launched for testing.

Extra click every N loops
------------------------
Open the Every N loops tab. Default interval is 10. Edit the count and click Save interval (0 disables it without forgetting the point). Click Record extra click, then hover over the desired button inside an assigned browser for 3 seconds. The coordinate saves automatically and is reused for assigned browsers with the same client size. A size mismatch blocks Start all until corrected or the feature is disabled.

Each browser counts completed loops independently. The extra click happens after the existing final-message wait and before the next loop. Counts reset on Start all. Test one cycle and Test clicks only exclude the extra click. No extra click runs until a point has been recorded. Settings persist in controller-sequence-periodic.ini; existing window assignments, three points, messages and timing settings are unchanged.

To load this update, stop the old script and reopen controller-sequence-background.ahk. Keep the same browser windows open so their saved assignments can be restored.

