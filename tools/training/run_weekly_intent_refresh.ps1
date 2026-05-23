Param(
  [string]$ApiBase = "http://127.0.0.1:8000",
  [int]$CurationLimit = 2000,
  [switch]$SkipTrain
)

$ErrorActionPreference = "Stop"

Write-Host "== Weekly Intent Refresh ==" -ForegroundColor Cyan
Write-Host "API: $ApiBase"

function Invoke-JsonGet([string]$Url) {
  return Invoke-RestMethod -Method GET -Uri $Url -ContentType "application/json"
}

function Invoke-JsonPost([string]$Url, $Body = $null) {
  if ($null -eq $Body) {
    return Invoke-RestMethod -Method POST -Uri $Url -ContentType "application/json"
  }
  $json = $Body | ConvertTo-Json -Depth 10
  return Invoke-RestMethod -Method POST -Uri $Url -Body $json -ContentType "application/json"
}

Write-Host "[1/5] Run nightly curation..." -ForegroundColor Yellow
$curation = Invoke-JsonPost "$ApiBase/api/ai/curation/nightly?limit=$CurationLimit"
Write-Host ("Created={0}, Skipped={1}, Total={2}" -f $curation.samples_created, $curation.samples_skipped, $curation.total_events)

Write-Host "[2/5] Read approved sample count..." -ForegroundColor Yellow
$approved = Invoke-JsonGet "$ApiBase/api/ai/training-samples?status=approved&limit=500"
$approvedCount = @($approved.items).Count
Write-Host "Approved samples: $approvedCount"

if ($approvedCount -lt 120) {
  Write-Host "Gate failed: approved < 120. Skip training this week." -ForegroundColor Red
  exit 2
}

if ($SkipTrain) {
  Write-Host "SkipTrain enabled. Data gate passed; training skipped by flag." -ForegroundColor Green
  exit 0
}

Write-Host "[3/5] Generate dataset..." -ForegroundColor Yellow
python -X utf8 tools\training\generate_dataset.py

Write-Host "[4/5] Train classifier..." -ForegroundColor Yellow
python -X utf8 tools\training\train_intent_classifier.py

Write-Host "[5/5] Export ONNX..." -ForegroundColor Yellow
python -X utf8 tools\training\export_onnx.py

Write-Host "Done. New runtime bundle at tools/training/dist/intent_onnx_runtime.zip" -ForegroundColor Green
