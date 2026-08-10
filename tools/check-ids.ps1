#Requires -Version 5.1
<#
  Kiểm tính toàn vẹn của mạng lưới ID trong docs-erp.
  Fail khi: (a) một ID được tham chiếu nhưng không tồn tại,
            (b) một Rule thiếu trường Decisions hoặc Principles.
  Exit 0 nếu sạch, exit 1 nếu có lỗi.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$errors = New-Object System.Collections.Generic.List[string]

function Add-Err([string]$msg) { $script:errors.Add($msg) }

# ---------- 1. Thu thập ID được ĐỊNH NGHĨA ----------
$defined = New-Object System.Collections.Generic.HashSet[string]

$rulesFile = Join-Path $root '01-rules\RULES.md'
if (-not (Test-Path $rulesFile)) {
    Add-Err "Thiếu file 01-rules/RULES.md"
} else {
    Select-String -Path $rulesFile -Pattern '^###\s+(R-\d{2})\s' |
        ForEach-Object { [void]$defined.Add($_.Matches[0].Groups[1].Value) }
}

Get-ChildItem -Path (Join-Path $root '02-principles') -Filter 'P-*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($_.BaseName -match '^(P-[A-Z]+)-') { [void]$defined.Add($Matches[1]) }
    }

Get-ChildItem -Path (Join-Path $root '03-decisions') -Filter 'ADR-*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($_.BaseName -match '^(ADR-\d{4})-') { [void]$defined.Add($Matches[1]) }
    }

Get-ChildItem -Path (Join-Path $root '04-conventions') -Filter 'C-*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        Select-String -Path $_.FullName -Pattern '^###\s+(C-[A-Z]+-\d{2})\s' |
            ForEach-Object { [void]$defined.Add($_.Matches[0].Groups[1].Value) }
    }

Get-ChildItem -Path (Join-Path $root '06-checklists') -Filter 'CL-*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        Select-String -Path $_.FullName -Pattern '(CL-[A-Z]+-\d{2})\s' |
            ForEach-Object { [void]$defined.Add($_.Matches[0].Groups[1].Value) }
    }

# ---------- 2. Thu thập ID được THAM CHIẾU ----------
$fields = 'Principles|Decisions|Rules|Constrains|Implements|Verifies'
$idPattern = '(R-\d{2}|P-[A-Z]+|ADR-\d{4}|C-[A-Z]+-\d{2}|CL-[A-Z]+-\d{2})'

# Không neo vào đầu dòng: checklist viết "(Verifies: R-02, C-GO-05)" ở GIỮA dòng.
# Neo đầu dòng sẽ bỏ sót toàn bộ checklist và script báo xanh giả.
$refPattern = "\*{0,2}($fields)\*{0,2}\s*:\s*([^\r\n)]*)"

Get-ChildItem -Path $root -Filter '*.md' -Recurse |
    Where-Object { $_.FullName -notmatch '\\(05-templates|99-meta\\specs)\\' } |
    ForEach-Object {
        $file = $_.FullName.Substring($root.Length + 1)
        Select-String -Path $_.FullName -Pattern $refPattern -AllMatches |
            ForEach-Object {
                foreach ($m in $_.Matches) {
                    $val = $m.Groups[2].Value
                    if ($val.Trim() -eq '—' -or $val.Trim() -eq '-' -or $val.Trim() -eq '') { continue }
                    foreach ($idm in [regex]::Matches($val, $idPattern)) {
                        $id = $idm.Groups[1].Value
                        if (-not $defined.Contains($id)) {
                            Add-Err "$file : tham chiếu '$id' nhưng không có nơi nào định nghĩa"
                        }
                    }
                }
            }
    }

# ---------- 3. Rule phải có đủ trường link ngược ----------
if (Test-Path $rulesFile) {
    $content = Get-Content -Path $rulesFile -Raw -Encoding UTF8
    $blocks = [regex]::Split($content, '(?m)^###\s+') | Select-Object -Skip 1
    foreach ($b in $blocks) {
        if ($b -match '^(R-\d{2})') {
            $rid = $Matches[1]
            if ($b -notmatch '(?m)^\s*\*{0,2}Decisions\*{0,2}\s*:')  { Add-Err "RULES.md : $rid thiếu trường 'Decisions:'" }
            if ($b -notmatch '(?m)^\s*\*{0,2}Principles\*{0,2}\s*:') { Add-Err "RULES.md : $rid thiếu trường 'Principles:'" }
        }
    }
    $expected = 1..19 | ForEach-Object { 'R-{0:d2}' -f $_ }
    foreach ($e in $expected) {
        if (-not $defined.Contains($e)) { Add-Err "RULES.md : thiếu rule $e" }
    }
}

# ---------- 3b. Kiểm chéo HAI CHIỀU ----------
# Nếu RULES.md nói "R-18 -> ADR-0008" thì ADR-0008 phải có R-18 trong Constrains,
# và ngược lại. Thiếu một chiều là chuỗi truy vết bị đứt.

function Get-FieldIds([string]$text, [string]$field, [string]$idRegex) {
    $out = New-Object System.Collections.Generic.HashSet[string]
    foreach ($m in [regex]::Matches($text, "\*{0,2}$field\*{0,2}\s*:\s*([^\r\n)]*)")) {
        foreach ($i in [regex]::Matches($m.Groups[1].Value, $idRegex)) { [void]$out.Add($i.Groups[1].Value) }
    }
    return ,$out
}

$ruleDecisions  = @{}   # R-xx -> HashSet[ADR-xxxx]
$rulePrinciples = @{}   # R-xx -> HashSet[P-XXX]

if (Test-Path $rulesFile) {
    $contentX = Get-Content -Path $rulesFile -Raw -Encoding UTF8
    $blocksX = [regex]::Split($contentX, '(?m)^###\s+') | Select-Object -Skip 1
    foreach ($b in $blocksX) {
        if ($b -match '^(R-\d{2})') {
            $rid = $Matches[1]
            $ruleDecisions[$rid]  = Get-FieldIds $b 'Decisions'  '(ADR-\d{4})'
            $rulePrinciples[$rid] = Get-FieldIds $b 'Principles' '(P-[A-Z]+)'
        }
    }
}

# ADR.Constrains phải khớp Rule.Decisions
Get-ChildItem -Path (Join-Path $root '03-decisions') -Filter 'ADR-*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($_.BaseName -notmatch '^(ADR-\d{4})-') { return }
        $aid  = $Matches[1]
        $text = Get-Content -Path $_.FullName -Raw -Encoding UTF8
        $constrains = Get-FieldIds $text 'Constrains' '(R-\d{2})'
        foreach ($rid in $constrains) {
            if (-not $ruleDecisions.ContainsKey($rid)) {
                Add-Err "$aid : Constrains nêu $rid nhưng RULES.md không có rule đó"
            } elseif (-not $ruleDecisions[$rid].Contains($aid)) {
                Add-Err "$aid : Constrains nêu $rid, nhưng $rid không có $aid trong 'Decisions:' (đứt một chiều)"
            }
        }
        foreach ($rid in @($ruleDecisions.Keys)) {
            if ($ruleDecisions[$rid].Contains($aid) -and -not $constrains.Contains($rid)) {
                Add-Err "$rid : Decisions nêu $aid, nhưng $aid không có $rid trong 'Constrains:' (đứt một chiều)"
            }
        }
    }

# Principle.Rules phải khớp Rule.Principles
Get-ChildItem -Path (Join-Path $root '02-principles') -Filter 'P-*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($_.BaseName -notmatch '^(P-[A-Z]+)-') { return }
        $pid2 = $Matches[1]
        $text = Get-Content -Path $_.FullName -Raw -Encoding UTF8
        $pRules = Get-FieldIds $text 'Rules' '(R-\d{2})'
        foreach ($rid in $pRules) {
            if (-not $rulePrinciples.ContainsKey($rid)) {
                Add-Err "$pid2 : Rules nêu $rid nhưng RULES.md không có rule đó"
            } elseif (-not $rulePrinciples[$rid].Contains($pid2)) {
                Add-Err "$pid2 : Rules nêu $rid, nhưng $rid không có $pid2 trong 'Principles:' (đứt một chiều)"
            }
        }
        foreach ($rid in @($rulePrinciples.Keys)) {
            if ($rulePrinciples[$rid].Contains($pid2) -and -not $pRules.Contains($rid)) {
                Add-Err "$rid : Principles nêu $pid2, nhưng $pid2 không có $rid trong 'Rules:' (đứt một chiều)"
            }
        }
    }

# ---------- 3c. Link markdown nội bộ không được chết ----------
Get-ChildItem -Path $root -Filter '*.md' -Recurse |
    Where-Object { $_.FullName -notmatch '\\(05-templates|99-meta\\specs)\\' } |
    ForEach-Object {
        $file = $_.FullName.Substring($root.Length + 1)
        $dir  = $_.DirectoryName
        $text = Get-Content -Path $_.FullName -Raw -Encoding UTF8
        foreach ($m in [regex]::Matches($text, '\[[^\]]*\]\(([^)]+)\)')) {
            $target = $m.Groups[1].Value.Trim()
            if ($target -match '^(https?:|mailto:|#)') { continue }
            $target = ($target -split '#')[0]
            if ($target -eq '') { continue }
            $full = Join-Path $dir $target
            if (-not (Test-Path -LiteralPath $full)) {
                Add-Err "$file : link chết -> '$target'"
            }
        }
    }

# ---------- 3d. Registry trong C-DB: moi adr phai tro ADR co that va da Accepted ----
$cdbFile = Join-Path $root '04-conventions\C-DB-database.md'
if (Test-Path $cdbFile) {
    $cdbText = Get-Content -Path $cdbFile -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($cdbText, '(?m)^\s*adr:\s*(ADR-\d{4})\s*$')) {
        $aid = $m.Groups[1].Value
        $adrFile = Get-ChildItem -Path (Join-Path $root '03-decisions') -Filter "$aid-*.md" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $adrFile) {
            Add-Err "C-DB-database.md : registry tro '$aid' nhung khong co file ADR do"
            continue
        }
        $adrText = Get-Content -Path $adrFile.FullName -Raw -Encoding UTF8
        if ($adrText -notmatch '(?m)^\*\*Status:\*\*\s*Accepted') {
            Add-Err "C-DB-database.md : registry tro '$aid' nhung ADR do khong o trang thai Accepted"
        }
    }
}

# ---------- 4. Kết quả ----------
if ($errors.Count -gt 0) {
    Write-Host "check-ids: THAT BAI - $($errors.Count) loi" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host "check-ids: OK - $($defined.Count) ID, khong co tham chieu treo" -ForegroundColor Green
exit 0
