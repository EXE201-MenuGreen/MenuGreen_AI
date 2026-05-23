Param(
  [string]$ApiBase = "http://127.0.0.1:8010",
  [string]$UserId = "11111111-1111-1111-1111-111111111111",
  [string]$ThreadId = "seed-thread-1",
  [int]$Total = 150,
  [int]$ApproveTop = 130
)

$ErrorActionPreference = "Stop"

$notes = @(
  "Gợi ý bữa trưa dưới 60k cho dân văn phòng",
  "Tôi muốn món tối ít dầu và giàu protein",
  "Lên thực đơn giảm cân 7 ngày giúp tôi",
  "Món nào nhanh dưới 20 phút mà đủ chất",
  "Hôm nay tôi còn bao nhiêu kcal và carbs",
  "Gợi ý món dùng nguyên liệu còn trong tủ lạnh",
  "Tôi cần bữa sáng no lâu nhưng không quá đắt",
  "Tôi muốn meal prep 3 ngày cho đi làm",
  "Tôi dị ứng hải sản, gợi ý món thay thế",
  "Gợi ý bữa tối nhẹ bụng sau khi tập gym"
)

$corrected = @(
  "Bạn có thể ăn ức gà áp chảo + rau luộc + cơm gạo lứt, khoảng 560 kcal.",
  "Gợi ý: cá hấp gừng + canh rau + 1 chén cơm nhỏ, khoảng 520 kcal.",
  "Bữa trưa dưới 60k: trứng cuộn + đậu hũ sốt cà + rau xào, khoảng 600 kcal.",
  "Meal prep 3 ngày: gà luộc xé + khoai lang + salad, mỗi phần ~550 kcal.",
  "Bữa sáng no lâu: yến mạch + trứng + chuối, khoảng 500 kcal.",
  "Nếu dị ứng hải sản, thay bằng thịt gà nạc hoặc đậu phụ để đủ protein."
)

$areas = @("nutrition_chat","meal_recommendation","meal_plan_generation")

Write-Host "Seeding feedback events..." -ForegroundColor Cyan
$createdFeedback = 0
$createdSamples = 0

for ($i = 1; $i -le $Total; $i++) {
  $type = if ($i % 5 -eq 0) { "rating" } elseif ($i % 3 -eq 0) { "correction" } else { "thumbs_up" }
  $payload = @{
    user_id = $UserId
    thread_id = $ThreadId
    feedback_type = $type
    user_note = $notes[($i - 1) % $notes.Count]
    assistant_response = $corrected[($i - 1) % $corrected.Count]
    corrected_response = $corrected[($i - 1) % $corrected.Count]
    feature_area = $areas[($i - 1) % $areas.Count]
  }
  if ($type -eq "rating") { $payload.rating = 5 }

  try {
    $feedback = Invoke-RestMethod -Method POST -Uri "$ApiBase/api/ai/feedback" -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 10)
    $createdFeedback++

    $samplePayload = @{
      input_text = $payload.user_note
      expected_output = $payload.corrected_response
      labels = @("seed", $payload.feature_area)
    }

    $sample = Invoke-RestMethod -Method POST -Uri "$ApiBase/api/ai/feedback/$($feedback.feedback_id)/to-training-sample" -ContentType "application/json" -Body ($samplePayload | ConvertTo-Json -Depth 10)
    if ($sample.sample_id) { $createdSamples++ }
  }
  catch {
    Write-Host "Row $i failed: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Write-Host "Feedback created: $createdFeedback" -ForegroundColor Green
Write-Host "Samples created:  $createdSamples" -ForegroundColor Green

Write-Host "Approving pending samples..." -ForegroundColor Cyan
$list = Invoke-RestMethod -Method GET -Uri "$ApiBase/api/ai/training-samples?status=pending&limit=500" -ContentType "application/json"
$items = @($list.items)
$approveCount = [Math]::Min($ApproveTop, $items.Count)

for ($j = 0; $j -lt $approveCount; $j++) {
  $id = $items[$j].id
  $review = @{ status = "approved"; review_note = "auto-approved seed" }
  try {
    Invoke-RestMethod -Method PATCH -Uri "$ApiBase/api/ai/training-samples/$id/review" -ContentType "application/json" -Body ($review | ConvertTo-Json -Depth 10) | Out-Null
  }
  catch {
    Write-Host "Approve failed for $id" -ForegroundColor Yellow
  }
}

$approved = Invoke-RestMethod -Method GET -Uri "$ApiBase/api/ai/training-samples?status=approved&limit=500" -ContentType "application/json"
$pending = Invoke-RestMethod -Method GET -Uri "$ApiBase/api/ai/training-samples?status=pending&limit=500" -ContentType "application/json"

Write-Host "Approved now: $(@($approved.items).Count)" -ForegroundColor Green
Write-Host "Pending now:  $(@($pending.items).Count)" -ForegroundColor Green
Write-Host "Seed done." -ForegroundColor Cyan
