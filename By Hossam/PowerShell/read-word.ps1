# Read Word document content
$wordPath = "C:\Users\hossam.aladdin\Documents\SQL Server Environment Assessment Report.docx"

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open($wordPath)

# Get all text content
$content = $doc.Content.Text

# Close and cleanup
$doc.Close($false)
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

# Output content
Write-Output $content
