# R9 - retrieve an out-of-distribution needle from 32k tokens of context,
# with the cold KV served off a byte-addressable drive (Ring-2), in ~1.8 GB RAM.
#
# Correctness (the HIT) reproduces on ANY drive. The us/read latency number is
# Optane-specific; on a generic NVMe expect it higher (tens of us). See EXPECTED.md.
#
# Usage:
#   .\run_r9_32k_needle.ps1 -Model C:\path\Qwen3-0.6B-f16.gguf -Drive F:\ -Corpus C:\path\wiki.test.raw
#
param(
  [string]$Model  = $env:SP_R9_MODEL,
  [string]$Drive  = $(if ($env:SP_R9_DRIVE)  { $env:SP_R9_DRIVE }  else { "F:\" }),
  [string]$Corpus = $env:SP_R9_CORPUS,
  [string]$Niah   = $(if ($env:SP_R9_NIAH)   { $env:SP_R9_NIAH }   else { "..\..\shannon-prime-system-engine\build\tests\niah.exe" }),
  [string]$Mingw  = "C:\ProgramData\mingw64\mingw64\bin"
)

if (-not (Test-Path $Niah))   { Write-Host "niah.exe not found at $Niah - build the engine first (see README.md)"; exit 2 }
if (-not $Model -or -not (Test-Path $Model))   { Write-Host "Set -Model to a Qwen3-0.6B-f16.gguf path"; exit 2 }
if (-not $Corpus -or -not (Test-Path $Corpus)) { Write-Host "Set -Corpus to a long text file (>= ~40k tokens), e.g. wikitext raw"; exit 2 }
if ($Mingw -and (Test-Path $Mingw)) { $env:Path = "$Mingw;$env:Path" }

# --- the R9 configuration (4x KV sparsification, sinks on, Ring-2 -> disk) ---
$env:SP_ARENA        = "q8"
$env:SP_RECALL_R     = "32"
$env:SP_RECALL_W     = "32"
$env:SP_RECALL_SINK  = "4"
$env:SP_RECALL_B     = "512"
$env:SP_RING2        = "1"
$env:SP_RING2_DISK   = "1"
$env:SP_RING2_DIR    = $Drive
$env:SP_NIAH_GGUF    = $Model
$env:SP_NIAH_CORPUS  = $Corpus
$env:SP_NIAH_N       = "32768"
$env:SP_NIAH_DEPTH   = "50"
$env:SP_NIAH_GEN     = "24"

Write-Host "R9: N=32768 needle, recall B=512 (4x), sinks=4, Ring-2 on $Drive"
Write-Host "Expect: a [ring1] ~911x cache-shrink line, then (after the I/O-bound prefill) a [niah] HIT with the secret in the answer, plus [ring2-disk] read stats."
Write-Host "This is I/O-heavy and can take 1-2+ hours on the reference 0.6B model. See EXPECTED.md."
& $Niah
