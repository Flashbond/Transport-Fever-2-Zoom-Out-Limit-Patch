# ------------------------------------------------------------
# Transport Fever 2 - Zoom Limit Patcher 
# ------------------------------------------------------------
& {
	# 0. Locate Transport Fever 2

	$Exe = $null
	$Candidates = @()
	$SteamPaths = @()
	
	$regPaths = @(
	    "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
	    "HKLM:\SOFTWARE\Valve\Steam"
	)
	
	foreach ($reg in $regPaths) {
	    $p = (Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue).SteamPath
	
	    if ($p) {
	        $SteamPaths += $p
	    }
	}
	
	$SteamPaths = $SteamPaths | Select-Object -Unique
	
	foreach ($steam in $SteamPaths) {
	
	    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
	
	    if (!(Test-Path $vdf)) {
	        continue
	    }
	
	    try {
	        $content = Get-Content $vdf -Raw -ErrorAction Stop
	    }
	    catch {
	        continue
	    }
	
	    $libraries = [regex]::Matches(
	        $content,
	        '"path"\s+"([^"]+)"'
	    ) | ForEach-Object {
	        $_.Groups[1].Value -replace '\\\\','\'
	    }
	
	    foreach ($library in $libraries) {
	
	        $candidate = Join-Path `
	            $library `
	            "steamapps\common\Transport Fever 2\TransportFever2.exe"
	
	        if (Test-Path $candidate) {
	            $Candidates += $candidate
	        }
	    }
	}
	
	$Candidates = $Candidates | Select-Object -Unique
	
	if ($Candidates.Count -eq 0) {
	    Write-Host "[ERROR] TransportFever2.exe could not be located." -ForegroundColor Red
	    return
	}
	
	if ($Candidates.Count -gt 1) {
	    Write-Host "[ERROR] Multiple TransportFever2.exe installations found." -ForegroundColor Red
	    return
	}
	
	$Exe = $Candidates[0]
	
	Write-Host "[OK] EXE found." -ForegroundColor Green

	# PE parsing

	$pe = [BitConverter]::ToInt32($data, 0x3C)

	if ($data[$pe] -ne 0x50 -or
		$data[$pe+1] -ne 0x45 -or
		$data[$pe+2] -ne 0x00 -or
		$data[$pe+3] -ne 0x00) {
		Write-Host "[ERROR] Invalid PE." -ForegroundColor Red
		return
	}

	$sections = [BitConverter]::ToUInt16($data, $pe + 6)
	$optional = [BitConverter]::ToUInt16($data, $pe + 20)
	$table = $pe + 24 + $optional

	$textStart = $textSize = $textVA = $null
	$rdataStart = $rdataSize = $rdataVA = $null

	for ($i = 0; $i -lt $sections; $i++) {

		$s = $table + ($i * 40)

		$name = [Text.Encoding]::ASCII.GetString(
			$data[$s..($s+7)]
		).TrimEnd([char]0)

		$va = [BitConverter]::ToUInt32($data, $s + 12)
		$rawSize = [BitConverter]::ToUInt32($data, $s + 16)
		$raw = [BitConverter]::ToUInt32($data, $s + 20)

		if ($name -eq ".text") {
			$textStart = [int]$raw
			$textSize = [int]$rawSize
			$textVA = [int]$va
		}

		if ($name -eq ".rdata") {
			$rdataStart = [int]$raw
			$rdataSize = [int]$rawSize
			$rdataVA = [int]$va
		}
	}

	if ($null -eq $textStart -or $null -eq $rdataStart) {
		Write-Host "[ERROR] Required PE sections not found." -ForegroundColor Red
		return
	}

	Write-Host "[OK] PE parsed." -ForegroundColor Green

	$text = [BitConverter]::ToString($data, $textStart, $textSize)
	$rdata = [BitConverter]::ToString($data, $rdataStart, $rdataSize)

	# 4. Find camera instruction

	$cameraPattern =
	'F3-0F-10-0D-(?:[0-9A-F]{2}-){4}F3-0F-5D-CA-F3-0F-11-8F-C0-00-00-00'

	$m = [regex]::Match($text, $cameraPattern)

	if (!$m.Success) {
		Write-Host "[ERROR] Camera instruction not found." -ForegroundColor Red
		return
	}

	$camera = $textStart + [int]($m.Index / 3)

	Write-Host "[OK] Camera instruction found." -ForegroundColor Green

	# 5.1 Calculate current .rdata target

	$dispOffset = 4
	$instructionSize = 8

	$disp = [BitConverter]::ToInt32(
		$data,
		$camera + $dispOffset
	)

	$cameraRVA = ($camera - $textStart) + $textVA
	$targetRVA = $cameraRVA + $instructionSize + $disp

	$target = $rdataStart + ($targetRVA - $rdataVA)

	if ($target -lt $rdataStart -or
		$target + 4 -gt $rdataStart + $rdataSize) {
		Write-Host "[ERROR] Camera target is outside .rdata." -ForegroundColor Red
		return
	}

	$current = [BitConverter]::ToUInt32($data, $target)

	if ($current -eq 0x41200000) {
		Write-Host "[Exiting] Already patched." -ForegroundColor Yellow
		return
	}

	# 5.2 + 6. Find and validate zoom constant candidate

	$VanillaZoom = 8.0
	$PatchZoom   = 10.0
	$MaxDistance = 0x10000

	$current = [BitConverter]::ToSingle($data, $target)

	if ($current -eq $PatchZoom) {
		Write-Host "[Exiting] Already patched." -ForegroundColor Yellow
		return
	}

	if ($current -ne $VanillaZoom) {
		Write-Host "[ERROR] Unexpected vanilla zoom value." -ForegroundColor Red
		return
	}

	$matches = [regex]::Matches(
		$rdata,
		'00-00-20-41'
	)

	if ($matches.Count -eq 0) {
		Write-Host "[ERROR] Zoom constant not found." -ForegroundColor Red
		return
	}

	$best = $null
	$bestDistance = [Int64]::MaxValue

	foreach ($m in $matches) {

		$candidate = $rdataStart + [int]($m.Index / 3)

		$candidateRVA =
			[Int64]($candidate - $rdataStart) +
			[Int64]$rdataVA

		$candidateDisp =
			$candidateRVA -
			([Int64]$cameraRVA + 8)

		if ($candidateDisp -lt [Int32]::MinValue -or
			$candidateDisp -gt [Int32]::MaxValue) {
			continue
		}

		$distance = [Math]::Abs(
			[Int64]$candidate - [Int64]$target
		)

		if ($distance -lt $bestDistance) {
			$best = $candidate
			$bestDistance = $distance
		}
	}

	if ($null -eq $best -or $bestDistance -gt $MaxDistance) {
		Write-Host "[ERROR] No suitable zoom constant candidate." -ForegroundColor Red
		return
	}

	$ZoomLimit = $best

	Write-Host "[OK] Zoom constant candidate selected." -ForegroundColor Green

	# 7. Calculate new RIP-relative displacement

	$newTargetRVA = ($best - $rdataStart) + $rdataVA
	$newDisp = [Int64]$newTargetRVA -
			   ([Int64]$cameraRVA + $instructionSize)

	if ($newDisp -lt [Int32]::MinValue -or
		$newDisp -gt [Int32]::MaxValue) {
		Write-Host "[ERROR] New address is out of range." -ForegroundColor Red
		return
	}

	[byte[]]$newBytes = [BitConverter]::GetBytes([Int32]$newDisp)

	for ($i = 0; $i -lt $newBytes.Length; $i++) {
		$data[$camera + $dispOffset + $i] = $newBytes[$i]
	}

	Write-Host "[OK] Patch prepared." -ForegroundColor Green

	# 8. Backup

	$Backup = "$Exe.bak"

	if (Test-Path $Backup) {
		Write-Host "[Warning] Backup already exists." -ForegroundColor Yellow
	}

	if (!(Test-Path $Backup)) {
		try {
			Copy-Item $Exe $Backup -ErrorAction Stop
		}
		catch {
			Write-Host "[ERROR] Could not create backup." -ForegroundColor Red
			return
		}

		if (!(Test-Path $Backup)) {
			Write-Host "[ERROR] Backup verification failed." -ForegroundColor Red
			return
		}

		Write-Host "[OK] Backup created." -ForegroundColor Green
	}

	# 9. Write

	try {
		[System.IO.File]::WriteAllBytes($Exe, $data)
	}
	catch {
		Write-Host "[ERROR] Could not write patched EXE." -ForegroundColor Red

		try {
			Copy-Item $Backup $Exe -Force -ErrorAction Stop
			Write-Host "[Warning] Original EXE restored." -ForegroundColor Yellow
		}
		catch {
			Write-Host "[ERROR] Restore failed." -ForegroundColor Red
		}

		return
	}

	Write-Host "[SUCCESS] TransportFever2.exe patched." -ForegroundColor Green
}; Read-Host "Hit Enter to continue..."
