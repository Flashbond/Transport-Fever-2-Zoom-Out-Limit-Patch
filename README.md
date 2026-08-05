# Transport Fever 2 - Zoom Out Limit Patch #
By default, the game's zoom-out limit is restricted to level 8. This patch increases the limit to level 10, making it much easier to get a clear overview of very large maps, including Megalomaniac-sized maps.

## What does it do ##
The patch modifies the game's executable directly. A *.bak* backup is created before the patched executable is written.

## How to use ##
**Close Transport Fever 2 before running the patch.**
### Option 1 - Run the PowerShell script ###
1. Download the *Transport-Fever-2-Zoom-Out-Limit-Patch.ps1* file.
1. Right-click the downloaded *.ps1* file and select **Properties**.
1. In the **General** tab, check **Unblock** at the bottom of the window, then click **OK**.
1. Right-click the *.ps1* file and select **Run with PowerShell**.

### Option 2 - Run it from Terminal ###
1. Copy the contents of *Transport-Fever-2-Zoom-Out-Limit-Patch.ps1* file.
1. Run Windows **Terminal**.
1. Paste the code into the terminal.
1. Press **Enter**.

The script automatically locates TransportFever2.exe and performs the required checks before modifying it.

## Note ##
It is strongly recommended to increase the *viewNearFar* far values in *base_config.lua* file which is located in game's *res/config/* folder. Otherwise, the fog may block the visible area.

	geometryQualityOptions = {
		{ viewNearFar = { 4.0, 8000.0 }, fogStartEndFarPerc = { .45, 1.0 }, lodDistanceScaling = .5 },		-- Low
		{ viewNearFar = { 4.0, 12000.0 }, fogStartEndFarPerc = { .33, 1.0 }, lodDistanceScaling = .75 },	-- Medium
		{ viewNearFar = { 4.0, 16000.0 }, fogStartEndFarPerc = { .25, 1.0 }, lodDistanceScaling = 1.0 },	-- High
		{ viewNearFar = { 4.0, 15000.0 }, fogStartEndFarPerc = { .125, 1.0 }, lodDistanceScaling = 10 },	-- Camera tool
		{ viewNearFar = { 0.5, 5000.0 }, fogStartEndFarPerc = { 1.0, 1.0 }, lodDistanceScaling = 1.0 },		-- Cockpit view
	}

## Backup & Safety ##
The script creates *TransportFever2.exe.bak* before modifying the original executable.

If the patch cannot be written successfully, it attempts to restore the executable from the backup.

## Disclaimer ##
This is an unofficial community patch and is not affiliated with or endorsed by Urban Games or the publishers of Transport Fever 2.
