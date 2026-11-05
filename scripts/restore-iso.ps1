param(
    [Parameter(Mandatory = $true)]
    [string] $ManifestPath,
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$manifestFile = Get-Item -LiteralPath $ManifestPath
if ($manifestFile.PSIsContainer) {
    throw "Manifest path must refer to a file: $ManifestPath"
}

$manifest = @{}
foreach ($line in [System.IO.File]::ReadAllLines($manifestFile.FullName)) {
    $separator = $line.IndexOf('=')
    if ($separator -lt 1) {
        throw "Invalid manifest line: $line"
    }

    $key = $line.Substring(0, $separator)
    $value = $line.Substring($separator + 1)
    if ($key -notin @('format', 'filename', 'size_bytes', 'part_size_bytes', 'part_count', 'sha256')) {
        throw "Unexpected manifest field: $key"
    }
    if ($manifest.ContainsKey($key)) {
        throw "Duplicate manifest field: $key"
    }
    $manifest[$key] = $value
}

foreach ($key in @('format', 'filename', 'size_bytes', 'part_size_bytes', 'part_count', 'sha256')) {
    if (-not $manifest.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($manifest[$key])) {
        throw "Manifest is missing $key."
    }
}

if ($manifest.format -ne 'LAZZITE-SPLIT-1' -or
    $manifest.filename -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.iso$' -or
    $manifest.size_bytes -notmatch '^[0-9]+$' -or
    $manifest.part_size_bytes -notmatch '^[0-9]+$' -or
    $manifest.part_count -notmatch '^[0-9]+$' -or
    $manifest.sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'Manifest contains invalid or unsupported values.'
}

$isoSize = [long]::Parse($manifest.size_bytes)
$partSize = [long]::Parse($manifest.part_size_bytes)
$partCount = [int]::Parse($manifest.part_count)
$hash = $manifest.sha256.ToLowerInvariant()
$maxPartSize = 1900L * 1024L * 1024L
$maxIsoSize = 999L * $maxPartSize
if ($isoSize -le 0 -or $isoSize -gt $maxIsoSize -or $partSize -le 0 -or $partSize -gt $maxPartSize -or $partCount -lt 1 -or $partCount -gt 999) {
    throw 'Manifest size or part count is outside supported bounds.'
}

$expectedCount = [int][Math]::Ceiling($isoSize / [double]$partSize)
if ($expectedCount -ne $partCount) {
    throw 'Manifest part count does not match the declared total and part sizes.'
}

$directory = $manifestFile.DirectoryName
$checksumPath = Join-Path $directory ($manifest.filename + '.sha256')
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Checksum file is missing: $checksumPath"
}
$checksumLine = [System.IO.File]::ReadAllText($checksumPath).Trim()
if ($checksumLine -notmatch '^([A-Fa-f0-9]{64})\s+([A-Za-z0-9._-]+\.iso)$') {
    throw 'Checksum file has an invalid format.'
}
if ($Matches[1].ToLowerInvariant() -ne $hash -or $Matches[2] -ne $manifest.filename) {
    throw 'Checksum file does not match the manifest.'
}

$foundParts = @(Get-ChildItem -LiteralPath $directory -Filter ($manifest.filename + '.???') -File)
if ($foundParts.Count -ne $partCount) {
    throw "Expected $partCount numbered parts but found $($foundParts.Count)."
}

$parts = @()
$totalSize = 0L
for ($index = 1; $index -le $partCount; $index++) {
    $suffix = $index.ToString('D3', [Globalization.CultureInfo]::InvariantCulture)
    $partPath = Join-Path $directory ($manifest.filename + '.' + $suffix)
    if (-not (Test-Path -LiteralPath $partPath -PathType Leaf)) {
        throw "Missing part $partPath; expected sequence .001 through .$($partCount.ToString('D3'))."
    }
    $partLength = (Get-Item -LiteralPath $partPath).Length
    if ($partLength -le 0 -or $partLength -gt $partSize -or ($index -lt $partCount -and $partLength -ne $partSize)) {
        throw "Part has an invalid size: $partPath"
    }
    $totalSize += $partLength
    $parts += $partPath
}

if ($totalSize -ne $isoSize) {
    throw "Part sizes total $totalSize bytes, expected $isoSize bytes."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $directory $manifest.filename
}
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Refusing to overwrite existing output: $outputFullPath"
}
$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Output directory does not exist: $outputDirectory"
}

$temporaryPath = Join-Path $outputDirectory ('.' + [System.IO.Path]::GetFileName($outputFullPath) + '.restore.' + [Guid]::NewGuid().ToString('N'))
try {
    $outputStream = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        foreach ($partPath in $parts) {
            $inputStream = [System.IO.File]::OpenRead($partPath)
            try {
                $inputStream.CopyTo($outputStream)
            }
            finally {
                $inputStream.Dispose()
            }
        }
    }
    finally {
        $outputStream.Dispose()
    }

    $restored = Get-Item -LiteralPath $temporaryPath
    if ($restored.Length -ne $isoSize) {
        throw "Restored ISO size is $($restored.Length) bytes, expected $isoSize bytes."
    }
    $restoredHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($restoredHash -ne $hash) {
        throw 'Restored ISO SHA-256 does not match the manifest.'
    }
    [System.IO.File]::Move($temporaryPath, $outputFullPath)
    Write-Output "Restored $outputFullPath ($isoSize bytes, SHA-256 $restoredHash)."
}
catch {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    throw
}
