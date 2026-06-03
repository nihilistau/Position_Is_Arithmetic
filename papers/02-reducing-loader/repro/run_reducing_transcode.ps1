# Paper 02 repro - L1 (reducing, output-preserving) + L4 (bit-faithful forward).
#
# Proves, on a model you supply: the transcoded .sp-model is SMALLER than the
# source GGUF (L1), and the forward pass on the .sp-model is bit-faithful to the
# GGUF (L4 - the engine's E_FMT_4 closure gate).
#
# STATUS: real commands, but not yet re-run for this release. Per SERIES.md rule 4,
# run this green before paper 02 goes public. Set the two -* paths to your build.
#
# Usage:
#   .\run_reducing_transcode.ps1 -Model C:\path\model.gguf `
#       -Transcode C:\path\engine\build\...\sp_transcode.exe `
#       -BuildDir  C:\path\engine\build
param(
  [string]$Model     = $env:SP_TC_MODEL,
  [string]$Transcode = $env:SP_TC_BIN,      # the built sp_transcode executable
  [string]$BuildDir  = $env:SP_TC_BUILD,    # engine build dir, for the E_FMT_4 ctest gate
  [string]$OutDir    = "."
)
if (-not $Model -or -not (Test-Path $Model)) { Write-Host "Set -Model to a source GGUF"; exit 2 }
if (-not $Transcode -or -not (Test-Path $Transcode)) { Write-Host "Set -Transcode to the built sp_transcode binary"; exit 2 }

$out = Join-Path $OutDir "out.sp-model"
$tok = Join-Path $OutDir "out.sp-tokenizer"

Write-Host "== transcode (GGUF -> .sp-model, --verify) =="
& $Transcode $Model $out $tok --verify
if ($LASTEXITCODE -ne 0) { Write-Host "transcode failed"; exit 1 }

# --- L1: reducing? ---
$inB  = (Get-Item $Model).Length
$outB = (Get-Item $out).Length
$pct  = [math]::Round(100.0 * (1 - $outB / $inB), 1)
Write-Host ("== L1 == GGUF {0:N0} B  ->  .sp-model {1:N0} B   reducing={2}  ({3}% smaller)" -f $inB, $outB, ($outB -lt $inB), $pct)

# --- L4: bit-faithful forward (the engine's closure gate) ---
if ($BuildDir -and (Test-Path $BuildDir)) {
  Write-Host "== L4 == forward(.sp-model) == forward(GGUF)  [E_FMT_4 closure gate]"
  ctest --test-dir $BuildDir -R "E_FMT_4" --output-on-failure 2>&1 | Select-String 'Passed|Failed|tests passed|bit-identical'
} else {
  Write-Host "== L4 == set -BuildDir to run the E_FMT_4 closure gate (forward parity)."
}
