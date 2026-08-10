# docs-erp Foundation Implementation Plan

> **Đọc sau thì lưu ý:** file này viết lúc ba repo code còn tên `backend`, `frontend`,
> `infra`. Ngày 2026-08-10 chúng đổi thành `backend-erp`, `frontend-erp`, `infra-erp`,
> và thư mục `erp/.specs/` chuyển về `docs-erp/99-meta/specs/`. Mọi đường dẫn và tên
> repo bên dưới giữ nguyên như lúc viết — đây là bản ghi của một thời điểm, không phải
> tài liệu chuẩn mực. Tên hiện hành xem `03-decisions/ADR-0002-multi-repo.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng repo tài liệu gốc `erp/docs-erp/` chứa 19 Architecture Rules, 7 Principles, 9 ADR, 4 Conventions, Templates và Checklists — ở dạng AI và người review dùng được để phát hiện vi phạm.

**Architecture:** Năm tầng tài liệu (RULES / PRINCIPLES / DECISIONS / CONVENTIONS / CHECKLISTS) nối với nhau bằng hệ thống ID ổn định và trường link ngược tường minh. Tính toàn vẹn của mạng lưới ID được bảo vệ bằng một script kiểm chéo hai chiều, viết trước khi viết nội dung. Docs từng module không nằm ở đây mà nằm trong repo code tương ứng.

**Tech Stack:** Markdown, Git, PowerShell 5.1 (script kiểm ID). Không có code ứng dụng trong phase này.

**Nguồn nội dung:** `d:\My project web\erp\.specs\2026-08-08-docs-erp-foundation-design.md` — plan này trỏ tới từng mục của spec thay vì chép lại, để tránh hai bản lệch nhau. Đọc spec trước khi bắt đầu.

---

## File Structure

| Đường dẫn | Trách nhiệm |
|---|---|
| `docs-erp/00-START-HERE.md` | Điểm vào duy nhất. Bản đồ 5 tầng, bảng định tuyến, thứ tự ưu tiên khi xung đột |
| `docs-erp/01-rules/RULES.md` | 19 rule canonical, mỗi rule 4 trường + link ngược |
| `docs-erp/01-rules/rules/R-*.md` | 5 rule cần ví dụ code dài |
| `docs-erp/02-principles/PRINCIPLES.md` | Index 7 principle + hard check tóm tắt |
| `docs-erp/02-principles/P-*.md` | Mỗi principle một file: câu hỏi, cách suy luận, hard check |
| `docs-erp/03-decisions/README.md` | Index ADR + trạng thái |
| `docs-erp/03-decisions/ADR-*.md` | 9 ADR bất biến |
| `docs-erp/04-conventions/C-*.md` | 4 file quy ước, mỗi mục có ID `C-XX-nn` |
| `docs-erp/05-templates/**` | Template module docs, ADR, migration, `module.yaml`, `CLAUDE.md` |
| `docs-erp/06-checklists/CL-*.md` | 4 checklist, mỗi dòng có `Verifies:` |
| `docs-erp/tools/check-ids.ps1` | Kiểm chéo hai chiều toàn bộ ID |
| `docs-erp/README.md` | Một đoạn giới thiệu + trỏ vào `00-START-HERE.md` |

**Quy ước ID** (script phụ thuộc vào đúng cú pháp này):

| Loại | Nơi định nghĩa | Cú pháp heading |
|---|---|---|
| Rule | `01-rules/RULES.md` | `### R-01 — <tên>` |
| Principle | tên file `02-principles/P-<KEY>-*.md` | `# P-<KEY> — <tên>` |
| ADR | tên file `03-decisions/ADR-<nnnn>-*.md` | `# ADR-<nnnn>: <tên>` |
| Convention item | trong `04-conventions/C-*.md` | `### C-DB-01 — <tên>` |
| Checklist item | trong `06-checklists/CL-*.md` | `- [ ] CL-NEWMOD-01 — <việc>` |

**Trường link ngược** (script quét đúng các tên này): `Principles:`, `Decisions:`, `Rules:`, `Constrains:`, `Implements:`, `Verifies:`. Giá trị là danh sách ID cách nhau bằng dấu phẩy, hoặc ký tự `—` nghĩa là không có.

---

# PHASE 1 — Khung repo, script kiểm ID, START-HERE

## Task 1: Khởi tạo 4 repo và khung thư mục

**Files:**
- Create: `erp/docs-erp/.gitignore`
- Create: `erp/docs-erp/README.md`
- Create: `erp/backend/.gitignore`, `erp/frontend/.gitignore`, `erp/infra/.gitignore`

- [ ] **Step 1: Tạo 4 repo git**

```powershell
cd "d:\My project web\erp"
foreach ($r in @('docs-erp','backend','frontend','infra')) {
  New-Item -ItemType Directory -Force $r | Out-Null
  git -C $r init -b main
}
```

Expected: bốn dòng `Initialized empty Git repository in .../<repo>/.git/`

- [ ] **Step 2: Tạo khung thư mục docs-erp**

```powershell
cd "d:\My project web\erp\docs-erp"
$dirs = @(
  '01-rules/rules',
  '02-principles',
  '03-decisions',
  '04-conventions',
  '05-templates/module-docs',
  '06-checklists',
  'tools'
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force $d | Out-Null }
Get-ChildItem -Recurse -Directory | Select-Object -ExpandProperty FullName
```

Expected: liệt kê đúng 9 thư mục — 7 mục trong `$dirs`, cộng hai thư mục cha ngầm `01-rules` và `05-templates`.

- [ ] **Step 3: Viết `docs-erp/.gitignore`**

```gitignore
# OS
Thumbs.db
Desktop.ini
.DS_Store

# Editor
.vscode/
.idea/

# Tạm
*.tmp
*.bak
```

- [ ] **Step 4: Viết `docs-erp/README.md`**

```markdown
# docs-erp

Tài liệu kiến trúc gốc của hệ thống ERP. Đây là nguồn sự thật duy nhất về quy tắc
kiến trúc cho cả ba repo code: `backend`, `frontend`, `infra`.

Tài liệu của từng module **không** nằm ở đây — chúng nằm trong repo code tương ứng
theo nguyên tắc "Documentation follows Code" (ADR-0005).

**Bắt đầu ở [00-START-HERE.md](00-START-HERE.md).**

## Kiểm tính toàn vẹn

```powershell
powershell -ExecutionPolicy Bypass -File tools/check-ids.ps1
```
```

- [ ] **Step 5: Tạo `.gitignore` tối thiểu cho 3 repo code**

```powershell
cd "d:\My project web\erp"
foreach ($r in @('backend','frontend','infra')) {
  Set-Content -Path "$r/.gitignore" -Encoding utf8 -Value @(
    '.env', '.env.*', '!.env.example', '*.log', '.vscode/', '.idea/'
  )
}
```

- [ ] **Step 6: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add .
git commit -m @'
chore: khởi tạo repo docs-erp và khung thư mục

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 2: Script kiểm chéo ID (viết trước, phải fail)

**Files:**
- Create: `docs-erp/tools/check-ids.ps1`

- [ ] **Step 1: Viết script**

```powershell
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
    Where-Object { $_.FullName -notmatch '\\05-templates\\' } |
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

# ---------- 4. Kết quả ----------
if ($errors.Count -gt 0) {
    Write-Host "check-ids: THAT BAI - $($errors.Count) loi" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host "check-ids: OK - $($defined.Count) ID, khong co tham chieu treo" -ForegroundColor Green
exit 0
```

- [ ] **Step 2: Chạy script, xác nhận nó FAIL**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```

Expected: `check-ids: THAT BAI` với dòng `Thiếu file 01-rules/RULES.md` và 19 dòng `thiếu rule R-nn`. Exit code 1.

Nếu script báo OK ở bước này thì script sai — sửa script, đừng đi tiếp.

- [ ] **Step 3: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add tools/check-ids.ps1
git commit -m @'
test: script kiem cheo ID cho mang luoi tai lieu

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 2b: Vá script — kiểm chéo hai chiều và link chết

**Files:**
- Modify: `docs-erp/tools/check-ids.ps1`

Script hiện chỉ kiểm một chiều (ID được trỏ có tồn tại không). Spec mục 12 đòi kiểm chéo **hai chiều**, và không có gì bảo vệ link markdown khỏi chết. Vá trước khi viết nội dung, vì vá sau khi đã có 40 file thì đắt hơn nhiều.

- [ ] **Step 1: Thêm mục 3b — kiểm chéo hai chiều**

Chèn sau khối "3. Rule phải có đủ trường link ngược", trước khối "4. Kết quả":

```powershell
# ---------- 3b. Kiểm chéo HAI CHIỀU ----------
# Nếu RULES.md nói "R-18 -> ADR-0008" thì ADR-0008 phải có R-18 trong Constrains,
# và ngược lại. Thiếu một chiều là chuỗi truy vết bị đứt.

function Get-FieldIds([string]$text, [string]$field, [string]$idRegex) {
    $out = New-Object System.Collections.Generic.HashSet[string]
    foreach ($m in [regex]::Matches($text, "\*{0,2}$field\*{0,2}\s*:\s*([^\r\n)]*)")) {
        foreach ($i in [regex]::Matches($m.Groups[1].Value, $idRegex)) { [void]$out.Add($i.Groups[1].Value) }
    }
    return $out
}

$ruleDecisions  = @{}   # R-xx -> HashSet[ADR-xxxx]
$rulePrinciples = @{}   # R-xx -> HashSet[P-XXX]

if (Test-Path $rulesFile) {
    $content = Get-Content -Path $rulesFile -Raw -Encoding UTF8
    $blocks = [regex]::Split($content, '(?m)^###\s+') | Select-Object -Skip 1
    foreach ($b in $blocks) {
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
        foreach ($rid in $ruleDecisions.Keys) {
            if ($ruleDecisions[$rid].Contains($aid) -and -not $constrains.Contains($rid)) {
                Add-Err "$rid : Decisions nêu $aid, nhưng $aid không có $rid trong 'Constrains:' (đứt một chiều)"
            }
        }
    }

# Principle.Rules phải khớp Rule.Principles
Get-ChildItem -Path (Join-Path $root '02-principles') -Filter 'P-*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($_.BaseName -notmatch '^(P-[A-Z]+)-') { return }
        $pid  = $Matches[1]
        $text = Get-Content -Path $_.FullName -Raw -Encoding UTF8
        $pRules = Get-FieldIds $text 'Rules' '(R-\d{2})'
        foreach ($rid in $pRules) {
            if (-not $rulePrinciples.ContainsKey($rid)) {
                Add-Err "$pid : Rules nêu $rid nhưng RULES.md không có rule đó"
            } elseif (-not $rulePrinciples[$rid].Contains($pid)) {
                Add-Err "$pid : Rules nêu $rid, nhưng $rid không có $pid trong 'Principles:' (đứt một chiều)"
            }
        }
        foreach ($rid in $rulePrinciples.Keys) {
            if ($rulePrinciples[$rid].Contains($pid) -and -not $pRules.Contains($rid)) {
                Add-Err "$rid : Principles nêu $pid, nhưng $pid không có $rid trong 'Rules:' (đứt một chiều)"
            }
        }
    }
```

- [ ] **Step 2: Thêm mục 3c — kiểm link markdown nội bộ**

```powershell
# ---------- 3c. Link markdown nội bộ không được chết ----------
Get-ChildItem -Path $root -Filter '*.md' -Recurse |
    Where-Object { $_.FullName -notmatch '\\05-templates\\' } |
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
```

- [ ] **Step 3: Chạy trên docs-erp, xác nhận vẫn ĐỎ đúng lý do**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```

Expected: vẫn đúng một lỗi `Thiếu file 01-rules/RULES.md`, **không** phát sinh lỗi link chết nào.

Lý do: `00-START-HERE.md` nhắc các file tương lai bằng **code span** (`` `01-rules/RULES.md` ``) chứ không phải cú pháp link `[text](path)`, nên mục 3c không đụng tới. `README.md` chỉ có một link thật trỏ `00-START-HERE.md`, file đó đã tồn tại.

Mục 3c sẽ bắt đầu có việc từ Phase 2, khi `RULES.md` trỏ sang `rules/R-05-events-for-decoupling.md` bằng link thật.

- [ ] **Step 4: Kiểm chứng bằng dữ liệu giả**

Dùng thư mục nháp `$env:TEMP\check-ids-probe2\` (KHÔNG đụng docs-erp), copy script sang `<nháp>\tools\`, dựng 4 ca:

**Ca E — đứt chiều ADR→Rule.** `RULES.md` có R-01..R-19, `R-18` ghi `**Decisions:** —`; `ADR-0008-x.md` ghi `**Constrains:** R-18`. Script PHẢI báo *"ADR-0008 : Constrains nêu R-18, nhưng R-18 không có ADR-0008"*.

**Ca F — đứt chiều Rule→ADR.** `R-18` ghi `**Decisions:** ADR-0008`; `ADR-0008-x.md` ghi `**Constrains:** —`. Script PHẢI báo lỗi đứt chiều ngược lại.

**Ca G — link chết.** Một file `.md` có `[abc](rules/khong-ton-tai.md)`. Script PHẢI báo *"link chết"*.

**Ca H — khớp đủ hai chiều + link sống → XANH.** R-18 ↔ ADR-0008 khớp nhau, P-TXN ↔ R-03 khớp nhau, mọi link trỏ file có thật. Script PHẢI exit 0.

Nếu ca nào trượt, sửa script cho tới khi đạt cả bốn. Dán output thật của cả bốn ca. Dọn thư mục nháp.

- [ ] **Step 5: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add tools/check-ids.ps1
git commit -m @'
test: kiem cheo hai chieu Rule-ADR, Rule-Principle va link markdown chet

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 3: `00-START-HERE.md`

**Files:**
- Create: `docs-erp/00-START-HERE.md`

Nội dung lấy từ **mục 10** của spec. Năm phần, đúng thứ tự.

- [ ] **Step 1: Viết file**

```markdown
# START HERE

## 1. Hệ thống này là gì

ERP modular monolith cho doanh nghiệp cơ khí và cảng, viết bằng Go (Gin + pgx/sqlx)
và React, dữ liệu trên PostgreSQL. Kiến trúc multi-tenant-ready: mọi bảng nghiệp vụ
có `company_id`, nhưng vận hành single-tenant trước, dùng chung một database.
Hệ thống không tích hợp IoT/PLC — Machine và Kalmar là module CRUD thường.

## 2. Bản đồ tài liệu

| Tầng | Vai trò | Ở đâu |
|---|---|---|
| **RULES** | What must be true — bắt buộc, kiểm được | `01-rules/` |
| **PRINCIPLES** | How we reason — cách suy luận khi áp dụng Rules | `02-principles/` |
| **DECISIONS** | Why we chose this — bất biến theo thời điểm | `03-decisions/` |
| **CONVENTIONS** | How we consistently implement it | `04-conventions/` |
| **CHECKLISTS** | How we verify it | `06-checklists/` |

Quan hệ giữa chúng:

```
        CONVENTIONS ──┐
Code ───┤             ├──> RULES ──> PRINCIPLES ──> DECISIONS
        CHECKLISTS ───┘
```

CONVENTIONS nằm giữa Rule và Code, không nối tiếp sau Rule: Rule nói *"FK phải có
index"*, Convention nói *"tên index là `idx_<table>_<cols>`"*. CHECKLISTS cắt ngang,
kiểm cả Rule lẫn Convention.

Mọi thứ đều có ID ổn định (`R-05`, `P-TXN`, `ADR-0006`, `C-DB-01`, `CL-NEWMOD-01`)
và trường link ngược. Báo một vi phạm chỉ cần nêu ID là tra ngược được toàn chuỗi.

## 3. Tôi cần làm X thì đọc gì

| Việc | Đọc theo thứ tự |
|---|---|
| Thêm module mới | `06-checklists/CL-NEWMOD-new-module.md` → R-01..R-05 → `05-templates/module-docs/` |
| Sửa schema | `06-checklists/CL-SCHEMA-schema-change.md` → R-06..R-09 → `04-conventions/C-DB-database.md` |
| Thêm endpoint | `06-checklists/CL-API-new-endpoint.md` → R-10..R-13 → `04-conventions/C-API-http.md` |
| Review PR | `06-checklists/CL-PR-code-review.md` |
| Không hiểu vì sao có quy tắc này | `03-decisions/` |

## 4. Khi xung đột

```
Rules > Principles > Conventions > existing code
```

Hai quy tắc bắt buộc, áp dụng cho cả người lẫn AI:

> **Nếu hai Rule mâu thuẫn nhau thì DỪNG LẠI và hỏi người. Không tự chọn bên.**
> Tự diễn giải một lần là tạo tiền lệ sai cho mọi lần sau.

> **Khi Principle thắng Convention trong một ca cụ thể, BẮT BUỘC mở issue sửa Convention.**
> Thứ tự ưu tiên là chỉ dẫn tạm thời cho tới khi tầng dưới được sửa cho khớp,
> không phải giấy phép bỏ qua nó.

`existing code` đứng cuối vì nó là thứ có thể sai và phải sửa. Code hiện có không
bao giờ là lý do để vi phạm Rule.

## 5. 30 phút đầu của người mới

1. Đọc mục 1–4 của file này (5 phút)
2. Đọc `01-rules/RULES.md` từ đầu đến cuối (15 phút) — không cần nhớ, chỉ cần biết có gì
3. Đọc `03-decisions/README.md` để nắm các quyết định nền (5 phút)
4. Mở checklist ứng với việc đầu tiên bạn sắp làm (5 phút)

Chưa cần đọc `02-principles/` và `04-conventions/` ngay — tra khi cần.
```

- [ ] **Step 2: Chạy script kiểm**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```

Expected: vẫn FAIL vì `RULES.md` chưa có, nhưng **không được** xuất hiện lỗi "tham chiếu treo" từ `00-START-HERE.md` — file này chỉ nhắc ID trong bảng và văn xuôi, không dùng trường link ngược.

- [ ] **Step 3: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 00-START-HERE.md README.md
git commit -m @'
docs: them 00-START-HERE lam diem vao duy nhat

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### ⏸ CHECKPOINT PHASE 1

Dừng lại cho người duyệt. Báo cáo:
- Cây thư mục thực tế (`Get-ChildItem -Recurse -Directory`)
- Output của `check-ids.ps1` (phải là FAIL với lý do đúng: thiếu RULES.md)
- Nội dung `00-START-HERE.md`

Không đi tiếp Phase 2 khi chưa được duyệt.

---

# PHASE 2 — 19 Rules

## Task 4: `RULES.md` — Nhóm A (Module Boundary) và B (Database)

**Files:**
- Create: `docs-erp/01-rules/RULES.md`

Nội dung mệnh đề lấy từ **mục 5** của spec, nhóm A và B. Khuôn mỗi entry:

```markdown
### R-01 — Module Boundary

**Mệnh đề bắt buộc:** <phát biểu binary>
**Dấu hiệu vi phạm:** <mẫu cụ thể để grep>
**Cách sửa:** <hành động>
**Ngoại lệ:** <có, hoặc "Không có ngoại lệ">
**Principles:** <ID hoặc —>
**Decisions:** <ID hoặc —>
```

- [ ] **Step 1: Viết phần đầu file + nhóm A**

```markdown
# 19 Architecture Rules

Rule là thứ **bắt buộc** và **kiểm được**: mỗi mệnh đề dưới đây trả lời được Có/Không
khi nhìn một file hoặc một diff, không cần biết ngữ cảnh nghiệp vụ.

Thứ không kiểm được bằng diff thì không nằm ở đây mà nằm ở `02-principles/`.

Khi hai Rule mâu thuẫn nhau: dừng lại, hỏi người. Không tự chọn bên.

---

## Nhóm A — Module Boundary

### R-01 — Module Boundary

**Mệnh đề bắt buộc:** Code trong `modules/<A>/internal/` chỉ được import bởi chính module A. Module khác chỉ được import `modules/<A>/api/` (interface + DTO).
**Dấu hiệu vi phạm:** Trong file thuộc `modules/B/`, có dòng import chứa `modules/A/internal`.
**Cách sửa:** Đưa thứ B cần lên `modules/A/api/` dưới dạng interface hoặc DTO, rồi import qua đó.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0001

### R-02 — No Cross-Module DB Access

**Mệnh đề bắt buộc:** Repository của module A chỉ được query bảng nằm trong danh sách `tables` khai báo ở `module.yaml` của A. Cấm JOIN sang bảng thuộc module khác.
**Dấu hiệu vi phạm:** Chuỗi SQL trong `modules/A/**/repository` có tên bảng không nằm trong `tables` của `modules/A/module.yaml`.
**Cách sửa:** Gọi service của module sở hữu bảng đó qua `api/` của nó. Nếu cần dữ liệu để lọc/hiển thị, nhận qua tham số hoặc qua event.
**Ngoại lệ:** Bảng trong `system_tables` (xem `C-DB-database.md`) được đọc bởi mọi module.
**Principles:** —
**Decisions:** ADR-0001

### R-03 — Layered Structure

**Mệnh đề bắt buộc:** Handler cấm import `pgx` hoặc `sqlx`. Service cấm import `gin` hoặc `net/http`. Repository cấm chứa `if` quyết định nghiệp vụ.
**Dấu hiệu vi phạm:** `import "github.com/jackc/pgx/v5"` trong file `*_handler.go`; `import "github.com/gin-gonic/gin"` trong file `*_service.go`.
**Cách sửa:** Chuyển truy cập dữ liệu xuống repository, chuyển thứ phụ thuộc HTTP lên handler.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** P-TXN, P-ERR
**Decisions:** ADR-0001

### R-04 — Dependency Direction

**Mệnh đề bắt buộc:** `shared/` cấm import bất kỳ package nào dưới `modules/`. Import graph giữa các module không được có chu trình.
**Dấu hiệu vi phạm:** Dòng import chứa `/modules/` trong file thuộc `shared/`.
**Cách sửa:** Đưa thứ dùng chung xuống `shared/`, hoặc đảo quan hệ bằng interface do `shared/` định nghĩa và module implement.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0001

### R-05 — Events for Decoupling

**Mệnh đề bắt buộc:** Gồm bốn mệnh đề, tất cả đều bắt buộc:
1. Service của A chỉ gọi đồng bộ sang module có tên trong `allowed_deps` của `module.yaml` thuộc A; ngoài danh sách phải đi qua event.
2. Chỉ service được ghi outbox. Handler và repository cấm.
3. Service ghi event vào bảng `outbox` **trong cùng transaction** với dữ liệu nghiệp vụ.
4. Service cấm gọi event bus trực tiếp bên trong transaction, kể cả qua `defer`. Publish ra bus xảy ra **sau commit**, do relay riêng đọc `outbox`.

**Dấu hiệu vi phạm:** Lời gọi `bus.Publish(` bên trong khối có `tx`; `defer bus.Publish(`; import module không có trong `allowed_deps`.
**Cách sửa:** Thay lời gọi bus bằng `outboxRepo.Append(ctx, tx, event)`. Để relay lo việc publish.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** P-EVT, P-IDEM, P-TXN
**Decisions:** ADR-0006

> Relay là **at-least-once**. Vì vậy `P-IDEM` không phải tùy chọn mà là điều kiện để
> ADR-0006 đứng vững: mọi event handler phải idempotent theo `event_id`.

Chi tiết và ví dụ code: [rules/R-05-events-for-decoupling.md](rules/R-05-events-for-decoupling.md)
```

- [ ] **Step 2: Viết tiếp nhóm B vào cùng file**

Dùng đúng khuôn trên cho R-06..R-09, mệnh đề lấy từ spec mục 5 nhóm B. Các giá trị bắt buộc:

| Rule | Principles | Decisions | Ngoại lệ |
|---|---|---|---|
| R-06 | — | ADR-0003 | Bảng trong `system_tables` (`C-DB`) |
| R-07 | — | — | Không có ngoại lệ |
| R-08 | — | — | Bảng `outbox` miễn `deleted_at` |
| R-09 | P-CONC | — | Bảng dưới 1000 dòng và không tham gia JOIN, phải ghi lý do trong migration |

Kèm khối định nghĩa sau, đặt ngay dưới R-06:

```markdown
> **"Bảng nghiệp vụ" nghĩa là gì:** mọi bảng **trừ** những bảng nằm trong danh sách
> `system_tables` khai báo tường minh ở `04-conventions/C-DB-database.md`.
> Khởi đầu `system_tables` gồm `schema_migrations` và `companies` — hai bảng này
> được miễn `company_id`, `deleted_at` và các cột audit của R-17.
> Bảng `outbox` **không** thuộc `system_tables`: nó có `company_id`, nhưng được miễn
> `deleted_at` vì event hết hạn lưu thì xóa cứng.
```

- [ ] **Step 3: Chạy script**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```

Expected: FAIL, và các lỗi phải là `thiếu rule R-10`..`R-19` cộng với tham chiếu treo tới `P-TXN`, `P-ERR`, `P-EVT`, `P-IDEM`, `P-CONC`, `ADR-0001`, `ADR-0003`, `ADR-0006` — những thứ Phase 3 mới tạo. **Không được** có lỗi nào khác.

- [ ] **Step 4: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 01-rules/RULES.md
git commit -m @'
docs: RULES.md nhom A (module boundary) va B (database)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 5: `RULES.md` — Nhóm C, D, E

**Files:**
- Modify: `docs-erp/01-rules/RULES.md` (append)

- [ ] **Step 1: Viết nhóm C (API), R-10..R-13**

Mệnh đề lấy từ spec mục 5 nhóm C. Giá trị bắt buộc:

| Rule | Principles | Decisions | Ngoại lệ |
|---|---|---|---|
| R-10 | — | — | Endpoint hành động không map được vào CRUD dùng dạng `POST /orders/{id}/actions/approve`, phải ghi vào `C-API` |
| R-11 | P-ERR | — | Endpoint trả file/stream |
| R-12 | — | — | Endpoint trả danh sách cố định dưới 50 dòng (ví dụ enum), phải ghi vào `C-API` |
| R-13 | — | — | Endpoint hạ tầng `/health`, `/ready`, `/metrics` nằm ngoài `/api/v1`; danh sách đóng, sửa phải cập nhật `C-API` |

- [ ] **Step 2: Viết nhóm D (Security), R-14..R-16**

| Rule | Principles | Decisions | Ngoại lệ |
|---|---|---|---|
| R-14 | — | — | Không có ngoại lệ |
| R-15 | — | ADR-0009 | Method public dùng nội bộ giữa service, đặt tên tiền tố `Internal`, phải ghi vào `module.yaml` |
| R-16 | P-OBS | — | Không có ngoại lệ |

- [ ] **Step 3: Viết nhóm E (Business/Data), R-17..R-19**

| Rule | Principles | Decisions | Ngoại lệ |
|---|---|---|---|
| R-17 | P-OBS, P-IDEM | ADR-0007 | Bảng trong `system_tables` |
| R-18 | — | ADR-0008 | Hard delete phải có ADR riêng |
| R-19 | — | ADR-0009 | Không có ngoại lệ |

Thêm khối ranh giới sau, đặt dưới R-17:

```markdown
> **R-17 khác P-OBS chỗ nào:** R-17 truy vết **dữ liệu nghiệp vụ** — ai sửa bản ghi
> nào, lúc nào, qua request nào; phục vụ người dùng cuối và kiểm toán. P-OBS lo
> **sức khỏe hệ thống** — latency, error rate, span; phục vụ người vận hành.
> Điểm giao duy nhất là `request_id`/`trace_id`: R-17 sở hữu nó, P-OBS chỉ tiêu thụ.
```

- [ ] **Step 4: Chạy script**

Expected: FAIL nhưng **chỉ còn** lỗi tham chiếu treo tới `P-*` và `ADR-*`. Không còn dòng `thiếu rule R-nn` nào.

- [ ] **Step 5: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 01-rules/RULES.md
git commit -m @'
docs: RULES.md nhom C (API), D (security), E (business/data)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 6: 5 rule chi tiết

**Files:**
- Create: `docs-erp/01-rules/rules/R-01-module-boundary.md`
- Create: `docs-erp/01-rules/rules/R-05-events-for-decoupling.md`
- Create: `docs-erp/01-rules/rules/R-06-tenant-column.md`
- Create: `docs-erp/01-rules/rules/R-09-index-by-design.md`
- Create: `docs-erp/01-rules/rules/R-17-traceability.md`

Mỗi file có cấu trúc:

```markdown
# R-05 — Events for Decoupling

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

<2-3 đoạn>

## Ví dụ SAI

```go
<code>
```

## Ví dụ ĐÚNG

```go
<code>
```

## Cách kiểm

```powershell
<lệnh grep cụ thể>
```
```

- [ ] **Step 1: Viết `R-05-events-for-decoupling.md`**

Phần "Ví dụ SAI" phải là service gọi `bus.Publish` trong transaction; "Ví dụ ĐÚNG" phải là ghi outbox trong transaction rồi relay publish sau commit, dùng chữ ký repository nhận `DBTX` theo `C-GO`. Lệnh kiểm:

```powershell
Select-String -Path "backend/modules/**/*.go" -Pattern 'defer\s+.*\.Publish\(|tx.*\n.*\.Publish\(' -AllMatches
```

- [ ] **Step 2: Viết 4 file còn lại theo cùng cấu trúc**

- `R-01`: ví dụ SAI import `modules/customer/internal/model`, ĐÚNG import `modules/customer/api`.
- `R-06`: ví dụ SAI `WHERE id = $1`, ĐÚNG `WHERE company_id = $1 AND id = $2`; nêu rõ vì sao thiếu `company_id` là lỗ hổng dữ liệu chứ không phải lỗi hiệu năng.
- `R-09`: ví dụ migration tạo bảng có FK mà quên index; nêu cách đặt tên `idx_<table>_<cols>`; trỏ sang skill `postgres-index-expert`.
- `R-17`: ví dụ service ghi audit trong cùng transaction; nêu vì sao audit ngoài transaction là sai.

- [ ] **Step 3: Chạy script, kết quả không đổi so với Task 5**

- [ ] **Step 4: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 01-rules/rules/
git commit -m @'
docs: 5 rule chi tiet co vi du code

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### ⏸ CHECKPOINT PHASE 2

Dừng cho người duyệt. Báo cáo:
- `RULES.md` đầy đủ 19 rule, mỗi rule 6 trường
- Output `check-ids.ps1`: chỉ còn lỗi tham chiếu treo `P-*`/`ADR-*`
- Danh sách ngoại lệ đã thêm (có 6 rule mang ngoại lệ) — người duyệt cần xác nhận từng cái, vì ngoại lệ là chỗ rule bị bào mòn

---

# PHASE 3 — Principles và ADR

## Task 7: 7 Principles

**Files:**
- Create: `docs-erp/02-principles/PRINCIPLES.md`
- Create: `docs-erp/02-principles/P-TXN-transaction-boundary.md`
- Create: `docs-erp/02-principles/P-ERR-error-handling.md`
- Create: `docs-erp/02-principles/P-TEST-testing.md`
- Create: `docs-erp/02-principles/P-IDEM-idempotency.md`
- Create: `docs-erp/02-principles/P-OBS-observability.md`
- Create: `docs-erp/02-principles/P-CONC-concurrency.md`
- Create: `docs-erp/02-principles/P-EVT-events.md`

Nội dung lấy từ **mục 6** của spec (bảng 7 principle + hard check + neo).

Khuôn mỗi file:

```markdown
# P-TXN — Transaction Boundary

**Câu hỏi nó trả lời:** Ai mở transaction, đóng ở đâu, khi nào cần?
**Rules:** R-03, R-05
**Decisions:** —

## Cách suy luận

<phần này là judgement, không binary>

## Hard check

<mệnh đề kiểm được — đây là phần neo xuống Rule/Convention>

## Ca khó

<2-3 tình huống thật và cách quyết>
```

- [ ] **Step 1: Viết 7 file principle**

Giá trị bắt buộc cho trường link ngược:

| File | Rules | Decisions |
|---|---|---|
| P-TXN | R-03, R-05 | — |
| P-ERR | R-11, R-03 | — |
| P-TEST | — | — |
| P-IDEM | R-05, R-17 | ADR-0006 |
| P-OBS | R-16, R-17 | — |
| P-CONC | R-09 | — |
| P-EVT | R-05 | ADR-0006 |

Ba nội dung bắt buộc không được bỏ:
- `P-TXN` mục "Ca khó" phải xử lý batch import (nhiều nghìn dòng): chia lô, mỗi lô một transaction, và nói rõ vì sao "một request ghi = một transaction" không áp dụng nguyên xi ở đây.
- `P-OBS` phải mở đầu bằng ranh giới với R-17 (đã nêu ở RULES.md), và ghi rõ **P-OBS cấm định nghĩa lại `request_id`**.
- `P-EVT` phải nói rõ nó khác R-05 chỗ nào: R-05 nói *được phép gọi ai* (kiểm bằng máy), P-EVT nói *khi nào nên chọn event* (judgement).

- [ ] **Step 2: Viết `PRINCIPLES.md` làm index**

Bảng 7 dòng: ID, câu hỏi nó trả lời, hard check tóm tắt một dòng, link tới file.

- [ ] **Step 3: Chạy script**

Expected: FAIL, chỉ còn tham chiếu treo tới `ADR-*`.

- [ ] **Step 4: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 02-principles/
git commit -m @'
docs: 7 architecture principles, moi cai neo xuong hard check

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 8: 9 ADR

**Files:**
- Create: `docs-erp/05-templates/ADR-template.md`
- Create: `docs-erp/03-decisions/README.md`
- Create: `docs-erp/03-decisions/ADR-0001-modular-monolith.md` … `ADR-0009-business-rule-chi-o-backend.md`

- [ ] **Step 1: Viết `05-templates/ADR-template.md`**

```markdown
# ADR-NNNN: <tiêu đề, một mệnh đề>

**Status:** Proposed | Accepted (YYYY-MM-DD) | Superseded by ADR-NNNN

## Context

<bối cảnh và ràng buộc tại thời điểm quyết. Viết ở thì quá khứ.>

## Decision

<quyết cái gì. Một câu.>

## Alternatives

<đã cân nhắc gì, vì sao loại. Ít nhất một phương án.>

## Consequences

**Được:** <...>
**Mất:** <...>
**Nợ để lại:** <...>

**Constrains:** <danh sách Rule ID sinh ra từ quyết định này, hoặc —>
```

> ADR đã `Accepted` thì **không sửa nội dung**. Muốn đổi thì viết ADR mới và đánh dấu
> ADR cũ `Superseded by ADR-NNNN`.

- [ ] **Step 2: Viết 9 ADR**

Nội dung `Decision` và `Constrains` lấy từ **mục 7** của spec:

| File | Decision | Constrains |
|---|---|---|
| `ADR-0001-modular-monolith.md` | Modular Monolith thay vì microservices | R-01, R-02, R-03, R-04 |
| `ADR-0002-multi-repo.md` | Bốn repo: docs-erp / backend / frontend / infra | — |
| `ADR-0003-multi-tenant-ready.md` | Shared DB + `company_id`; chưa làm database-per-tenant | R-06 |
| `ADR-0004-khong-tich-hop-iot-plc.md` | Không tích hợp IoT/PLC; Machine, Kalmar là CRUD thường | — |
| `ADR-0005-documentation-follows-code.md` | Docs module nằm trong repo code; docs gốc chỉ giữ quy tắc chung | — |
| `ADR-0006-event-bus-outbox.md` | Event bus nội bộ + outbox; publish sau commit; relay at-least-once | R-05 |
| `ADR-0007-traceability-bat-buoc.md` | Audit đầy đủ mọi thao tác ghi; `request_id` xuyên suốt | R-17 |
| `ADR-0008-soft-delete-by-default.md` | Xóa nghiệp vụ là đánh dấu, không xóa vật lý | R-18 |
| `ADR-0009-business-rule-chi-o-backend.md` | Backend là nơi duy nhất giữ business rule; không tin frontend | R-19, R-15 |

Mỗi ADR `Status: Accepted (2026-08-08)`.

Hai điểm bắt buộc không được bỏ:
- `ADR-0006` mục Consequences phải ghi rõ: *relay at-least-once, nên mọi event handler bắt buộc idempotent theo `event_id` (P-IDEM). Đây là điều kiện để quyết định này đứng vững, không phải khuyến nghị.*
- `ADR-0004` mục Alternatives phải ghi phương án tích hợp IoT/PLC đã bị loại và lý do — chính nó chặn việc mở lại tranh luận sau này.

- [ ] **Step 3: Viết `03-decisions/README.md`**

Bảng 9 dòng: ID, tiêu đề, Status, Constrains, link. Kèm một đoạn giải thích quy tắc bất biến của ADR.

- [ ] **Step 4: Chạy script**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```

Expected: **PASS** — `check-ids: OK`. Đây là lần đầu script xanh. Nếu vẫn đỏ, sửa cho tới khi xanh trước khi commit.

- [ ] **Step 5: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 03-decisions/ 05-templates/ADR-template.md
git commit -m @'
docs: 9 ADR va template ADR; check-ids lan dau xanh

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### ⏸ CHECKPOINT PHASE 3

Dừng cho người duyệt. Báo cáo:
- Output `check-ids.ps1` — phải xanh
- Bảng đối chiếu: mỗi Rule → ADR nào, mỗi ADR → Rule nào (kiểm hai chiều khớp nhau)
- Các Rule ghi `Decisions: —` và lý do

---

# PHASE 4 — Conventions, Templates, Checklists

## Task 9: `C-DB-database.md` và `C-API-http.md`

**Files:**
- Create: `docs-erp/04-conventions/C-DB-database.md`
- Create: `docs-erp/04-conventions/C-API-http.md`

Mỗi mục có heading `### C-DB-01 — <tên>` và trường `**Implements:** R-xx`.

- [ ] **Step 1: Viết `C-DB-database.md`**

Các mục bắt buộc:

| ID | Nội dung | Implements |
|---|---|---|
| C-DB-01 | Đặt tên bảng, cột, constraint | R-08 |
| C-DB-02 | Kiểu dữ liệu chuẩn: tiền `NUMERIC(18,4)`, thời gian `TIMESTAMPTZ`, ID `UUID` | R-08 |
| C-DB-03 | Bộ cột bắt buộc của bảng nghiệp vụ | R-06, R-08, R-17, R-18 |
| C-DB-04 | Danh sách `system_tables` và ngoại lệ của bảng `outbox` | R-06 |
| C-DB-05 | Đặt tên index `idx_<table>_<cols>`, quy tắc index FK | R-09 |
| C-DB-06 | Cách viết migration, đánh số, `up`/`down` | R-07 |
| C-DB-07 | Schema bảng `outbox` | R-05 |

`C-DB-03` phải liệt kê đủ: `id UUID PK`, `company_id UUID NOT NULL`, `created_at TIMESTAMPTZ NOT NULL`, `updated_at TIMESTAMPTZ NOT NULL`, `deleted_at TIMESTAMPTZ NULL`, `created_by UUID NOT NULL`, `updated_by UUID NOT NULL`.

`C-DB-07` phải có DDL đầy đủ của `outbox`, gồm `event_id UUID PK`, `company_id`, `aggregate_type`, `aggregate_id`, `event_type`, `payload JSONB`, `occurred_at TIMESTAMPTZ`, `published_at TIMESTAMPTZ NULL`, và index trên `(published_at) WHERE published_at IS NULL`.

**Ba điểm phát sinh từ Task 4, bắt buộc xử lý ở đây** — chúng nảy ra khi viết R-06/R-08/R-09 và nếu bỏ qua sẽ thành mâu thuẫn ngầm:

1. **`company_id` là FK tới `companies(id)`**, nên R-09 bắt buộc nó có index. `C-DB-05` phải nói rõ: index đơn trên `(company_id)` hầu như vô dụng — quy ước là **index composite dẫn đầu bằng `company_id`**, ví dụ `idx_orders_company_id_status ON orders(company_id, status)`. Không có dòng này, mọi bảng sẽ mọc một index rác.
2. **Quy ước comment miễn index.** R-09 cho phép miễn index kèm lý do ghi trong migration; Task 4 đã đặt ra cú pháp `-- miễn index: <lý do>`. `C-DB-05` phải chốt chính thức cú pháp này, nếu không mỗi người ghi một kiểu và ngoại lệ trở thành không kiểm được.
3. **`outbox` cũng nên miễn `updated_at`.** R-08 hiện chỉ miễn `deleted_at` cho `outbox`, nhưng event là immutable — `updated_at` trên đó vô nghĩa. `C-DB-04` phải ghi rõ outbox miễn cả `updated_at` và `deleted_at`, và `C-DB-07` không được có cột `updated_at`. Nếu chốt khác đi thì phải sửa `Ngoại lệ` của R-08 cho khớp.

- [ ] **Step 2: Viết `C-API-http.md`**

| ID | Nội dung | Implements |
|---|---|---|
| C-API-01 | Cấu trúc URL, danh từ số nhiều, endpoint hành động | R-10 |
| C-API-02 | Mã status theo tình huống | R-10 |
| C-API-03 | Struct envelope `data` / `error` / `meta` | R-11 |
| C-API-04 | Tham số `page`, `page_size`, `sort`, cú pháp filter | R-12 |
| C-API-05 | Bảng mã lỗi nghiệp vụ | R-11 |
| C-API-06 | Quy tắc versioning, định nghĩa breaking change | R-13 |

`C-API-03` phải có JSON mẫu đầy đủ cho cả ba trường hợp: thành công một bản ghi, thành công danh sách có `meta`, và lỗi validate 422 có danh sách field.

- [ ] **Step 3: Chạy script, phải vẫn xanh**

- [ ] **Step 4: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 04-conventions/C-DB-database.md 04-conventions/C-API-http.md
git commit -m @'
docs: convention database va HTTP API

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 10: `C-GO-backend.md` và `C-TS-frontend.md`

**Files:**
- Create: `docs-erp/04-conventions/C-GO-backend.md`
- Create: `docs-erp/04-conventions/C-TS-frontend.md`

- [ ] **Step 1: Viết `C-GO-backend.md`**

| ID | Nội dung | Implements |
|---|---|---|
| C-GO-01 | Layout package một module | R-01, R-03 |
| C-GO-02 | Đặt tên file, interface, method | — |
| C-GO-03 | **Transaction Ownership** | R-03, R-05 |
| C-GO-04 | Wrap error và bảng mã lỗi | R-11 |
| C-GO-05 | Nội dung `module.yaml` | R-02, R-05 |

`C-GO-03` là mục quan trọng nhất của file, phải có đủ:

```markdown
### C-GO-03 — Transaction Ownership

**Implements:** R-03, R-05

Ba mệnh đề bắt buộc:

1. **Service owns transaction boundary.**
2. **Repository không `BEGIN`/`COMMIT`/`ROLLBACK`** transaction nghiệp vụ.
3. **Repository nhận `DBTX` qua tham số**, không lấy từ `context`.

```
Handler
   ↓
Service
   ├── BEGIN
   ├── Repository A      (nhận DBTX)
   ├── Repository B      (nhận DBTX)
   ├── Outbox Repository (nhận DBTX)
   └── COMMIT
                ↓ (sau commit)
        Relay đọc outbox → publish ra bus
```

```go
// shared/db/dbtx.go
type DBTX interface {
    GetContext(ctx context.Context, dest interface{}, query string, args ...interface{}) error
    SelectContext(ctx context.Context, dest interface{}, query string, args ...interface{}) error
    QueryRowxContext(ctx context.Context, query string, args ...interface{}) *sqlx.Row
    ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error)
}
```

Cả `*sqlx.DB` và `*sqlx.Tx` đều thỏa interface này, nên repository không cần biết mình
đang chạy trong transaction hay không.

Chữ ký repository bắt buộc có `DBTX` ngay sau `ctx`:

```go
func (r *orderRepo) Insert(ctx context.Context, db DBTX, o *Order) error
```

**Vì sao truyền qua tham số chứ không qua `context`:** chữ ký hàm tự tố cáo vi phạm —
grep là biết repository có tự mở transaction hay không. Nếu truyền qua `context`, quên
truyền thì code vẫn chạy, chỉ là chạy ngoài transaction mà không báo lỗi gì.
```

`C-GO-05` phải có `module.yaml` mẫu đầy đủ với cả `tables` và `allowed_deps`.

- [ ] **Step 2: Viết `C-TS-frontend.md`**

| ID | Nội dung | Implements |
|---|---|---|
| C-TS-01 | Layout module frontend | R-01 |
| C-TS-02 | Đặt tên component, hook, file | — |
| C-TS-03 | Quản lý state, ranh giới server state / client state | — |
| C-TS-04 | Xử lý form và hiển thị lỗi từ envelope | R-11, R-19 |
| C-TS-05 | Ẩn/hiện theo quyền — và vì sao ẩn nút không phải là kiểm quyền | R-15, R-19 |

`C-TS-05` phải nói thẳng: ẩn nút chỉ là UX; backend vẫn phải từ chối. Kèm ví dụ frontend gọi API bị 403 và cách hiển thị.

- [ ] **Step 3: Chạy script, phải vẫn xanh**

- [ ] **Step 4: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 04-conventions/C-GO-backend.md 04-conventions/C-TS-frontend.md
git commit -m @'
docs: convention Go backend (gom transaction ownership) va TS frontend

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 11: Templates

**Files:**
- Create: `docs-erp/05-templates/module-docs/README.md`
- Create: `docs-erp/05-templates/module-docs/Database.md`
- Create: `docs-erp/05-templates/module-docs/Workflow.md`
- Create: `docs-erp/05-templates/module-docs/Permission.md`
- Create: `docs-erp/05-templates/module-docs/Events.md`
- Create: `docs-erp/05-templates/migration-template.sql`
- Create: `docs-erp/05-templates/module.yaml.template`
- Create: `docs-erp/05-templates/CLAUDE.md.template`

- [ ] **Step 1: Viết 5 file `module-docs/`**

Đây là bộ docs mà **mỗi module trong repo code** phải có (ADR-0005). Mỗi file là khung rỗng có heading và ghi chú điền gì.

- `README.md`: module này làm gì, sở hữu bảng nào, phụ thuộc module nào.
- `Database.md`: bảng, cột, quan hệ, index — phải khớp `module.yaml.tables`.
- `Workflow.md`: các luồng nghiệp vụ và trạng thái.
- `Permission.md`: danh sách permission và ai được làm gì.
- `Events.md`: event module này publish và subscribe, kèm schema payload.

- [ ] **Step 2: Viết `module.yaml.template`**

```yaml
# Khai báo ranh giới module. R-02 và R-05 kiểm dựa trên file này.
name: order

# Bảng module này SỞ HỮU. Repository của module chỉ được query những bảng ở đây
# cộng với system_tables. (R-02)
tables:
  - orders
  - order_items

# Module được phép gọi ĐỒNG BỘ. Ngoài danh sách này phải đi qua event. (R-05)
allowed_deps:
  - customer
  - product

# Method public dùng nội bộ giữa service, đặt tiền tố Internal. (ngoại lệ của R-15)
internal_methods: []
```

- [ ] **Step 3: Viết `migration-template.sql`**

Khung migration có sẵn bộ cột bắt buộc của `C-DB-03`, index FK theo `C-DB-05`, và phần `-- down`.

- [ ] **Step 4: Viết `CLAUDE.md.template`**

```markdown
# CLAUDE.md — <tên repo>

## Quy tắc kiến trúc

Nguồn sự thật duy nhất là repo `docs-erp`. **Đọc `docs-erp/00-START-HERE.md` trước
khi sửa bất cứ thứ gì.**

Khi hai Rule mâu thuẫn nhau: DỪNG LẠI và hỏi người. Không tự chọn bên.

Thứ tự ưu tiên khi xung đột: `Rules > Principles > Conventions > existing code`.

## Rule hay bị vi phạm nhất trong repo này

<điền sau khi có code thật — mỗi repo tự liệt kê 3-5 rule>

## Trước khi mở PR

Chạy qua `docs-erp/06-checklists/CL-PR-code-review.md`.
```

- [ ] **Step 5: Chạy script, phải vẫn xanh**

Lưu ý: script bỏ qua thư mục `05-templates/` khi quét tham chiếu, nên ID trong template không gây lỗi.

- [ ] **Step 6: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 05-templates/
git commit -m @'
docs: template module-docs, module.yaml, migration, CLAUDE.md

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 12: 4 Checklists

**Files:**
- Create: `docs-erp/06-checklists/CL-NEWMOD-new-module.md`
- Create: `docs-erp/06-checklists/CL-SCHEMA-schema-change.md`
- Create: `docs-erp/06-checklists/CL-API-new-endpoint.md`
- Create: `docs-erp/06-checklists/CL-PR-code-review.md`

Mỗi dòng có dạng `- [ ] CL-XXX-nn — <việc cụ thể> (Verifies: R-xx, C-XX-nn)`.

- [ ] **Step 1: Viết `CL-NEWMOD-new-module.md`**

Tối thiểu các mục:

```markdown
# Checklist — Thêm module mới

- [ ] CL-NEWMOD-01 — Đã tạo `module.yaml` với `tables` và `allowed_deps` (Verifies: R-02, R-05, C-GO-05)
- [ ] CL-NEWMOD-02 — Thư mục có `api/` và `internal/`; không package nào ngoài module import `internal/` (Verifies: R-01)
- [ ] CL-NEWMOD-03 — Handler không import pgx/sqlx; service không import gin (Verifies: R-03)
- [ ] CL-NEWMOD-04 — Module không tạo chu trình phụ thuộc (Verifies: R-04)
- [ ] CL-NEWMOD-05 — Đã có `docs/` trong module với đủ README, Database, Workflow, Permission, Events (Verifies: —)
- [ ] CL-NEWMOD-06 — Mọi bảng mới có đủ bộ cột bắt buộc (Verifies: R-06, R-08, R-17, R-18, C-DB-03)
- [ ] CL-NEWMOD-07 — Mọi FK có index (Verifies: R-09, C-DB-05)
- [ ] CL-NEWMOD-08 — Mọi method public của service có kiểm quyền (Verifies: R-15)
- [ ] CL-NEWMOD-09 — Event publish qua outbox, không gọi bus trong transaction (Verifies: R-05, C-GO-03)
- [ ] CL-NEWMOD-10 — Mọi method public của service có ít nhất một test (Verifies: —)
```

- [ ] **Step 2: Viết 3 checklist còn lại**

- `CL-SCHEMA`: kiểm R-06..R-09, C-DB-01..C-DB-06, và mục "không sửa migration đã merge".
- `CL-API`: kiểm R-10..R-13, C-API-01..C-API-06, và mục "lỗi trả về dùng mã trong bảng mã lỗi".
- `CL-PR`: bộ tổng hợp, thêm R-14, R-16, R-19 và mục "`module.yaml` đã cập nhật nếu module đổi bảng hoặc phụ thuộc".

- [ ] **Step 3: Chạy script**

Expected: xanh, và số ID tăng thêm đúng bằng số dòng checklist.

- [ ] **Step 4: Commit**

```powershell
cd "d:\My project web\erp\docs-erp"
git add 06-checklists/
git commit -m @'
docs: 4 checklist, moi dong tro ve Rule/Convention cu the

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 13: Kiểm toàn vẹn cuối và rải `CLAUDE.md`

**Files:**
- Create: `erp/backend/CLAUDE.md`, `erp/frontend/CLAUDE.md`, `erp/infra/CLAUDE.md`

- [ ] **Step 1: Chạy script lần cuối**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```

Expected: `check-ids: OK - <n> ID, khong co tham chieu treo`, exit 0.

- [ ] **Step 2: Xác nhận kiểm chéo hai chiều đã sạch**

Việc này do `check-ids.ps1` lo từ Task 2b — mục 3b so khớp `Rule.Decisions ↔ ADR.Constrains` và `Rule.Principles ↔ Principle.Rules`, mục 3c bắt link markdown chết. Step 1 xanh nghĩa là cả hai chiều đã khớp.

Không kiểm bằng mắt nữa: bước thủ công là bước người ta làm một lần rồi bỏ, và sau đó chuỗi truy vết mục ruỗng mà không ai biết.

- [ ] **Step 3: Tạo `CLAUDE.md` cho 3 repo code**

```powershell
cd "d:\My project web\erp"
foreach ($r in @('backend','frontend','infra')) {
  Copy-Item 'docs-erp/05-templates/CLAUDE.md.template' "$r/CLAUDE.md"
}
```

Sau đó sửa dòng tiêu đề của từng file thành tên repo tương ứng, và để mục "Rule hay bị vi phạm nhất" ở trạng thái chờ điền — ghi rõ *"điền sau khi có code thật"* thay vì để trống không giải thích.

- [ ] **Step 4: Tạo PR template cho 3 repo code (enforcement tầng 2)**

```powershell
cd "d:\My project web\erp"
foreach ($r in @('backend','frontend','infra')) {
  New-Item -ItemType Directory -Force "$r/.github" | Out-Null
}
```

Nội dung `backend/.github/pull_request_template.md`:

```markdown
## Thay đổi gì

<mô tả ngắn>

## Checklist bắt buộc

Chạy qua `docs-erp/06-checklists/CL-PR-code-review.md`. Đánh dấu phần áp dụng:

- [ ] Không vi phạm ranh giới module — `internal/` không bị import từ ngoài (R-01, R-02)
- [ ] Handler không chạm DB, service không chạm HTTP (R-03)
- [ ] Bảng mới có đủ `company_id` và bộ cột bắt buộc (R-06, R-08, R-17, R-18)
- [ ] FK mới có index (R-09)
- [ ] Endpoint mới theo envelope và chuẩn phân trang (R-11, R-12)
- [ ] Method service mới có kiểm quyền (R-15)
- [ ] Không log/trả về dữ liệu nhạy cảm (R-16)
- [ ] Không có business rule nào chỉ tồn tại ở frontend (R-19)
- [ ] `module.yaml` đã cập nhật nếu module đổi bảng hoặc phụ thuộc (R-02, R-05)
- [ ] Event publish qua outbox, không gọi bus trong transaction (R-05)

## Rule nào phải phá, vì sao

<để trống nếu không có. Nếu có, phải nêu ID rule và lý do — reviewer quyết định.>
```

`frontend/.github/pull_request_template.md` giữ các dòng R-01, R-11, R-19 và thêm dòng *"ẩn nút không thay cho kiểm quyền backend (R-15, C-TS-05)"*. `infra/.github/pull_request_template.md` chỉ giữ phần mô tả và mục "Rule nào phải phá".

Mục cuối là chỗ quan trọng nhất: không có nó, người ta phá rule âm thầm thay vì khai báo.

- [ ] **Step 5: Commit cả 4 repo**

```powershell
cd "d:\My project web\erp\docs-erp"
git add -A
git commit -m @'
docs: hoan thanh foundation docs-erp (19 rules, 7 principles, 9 ADR, 4 conventions)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@

cd "d:\My project web\erp"
foreach ($r in @('backend','frontend','infra')) {
  git -C $r add -A
  git -C $r commit -m @'
chore: khoi tao repo va CLAUDE.md tro ve docs-erp

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
}
```

---

### ⏸ CHECKPOINT PHASE 4 — Định nghĩa hoàn thành

Đối chiếu với mục 12 của spec:

- [ ] `docs-erp` là git repo, có commit
- [ ] Đủ file trong cây thư mục, không file nào còn placeholder
- [ ] 19 Rule đều có đủ 6 trường
- [ ] Mọi Rule truy về ít nhất một ADR, hoặc `Decisions: —` kèm lý do
- [ ] 7 Principle đều có hard check cụ thể
- [ ] 9 ADR đều có `Status` và `Constrains`
- [ ] Mọi dòng checklist có `Verifies:` trỏ tới ID có thật
- [ ] `check-ids.ps1` xanh
- [ ] `CLAUDE.md` có ở cả 3 repo code
- [ ] `.github/pull_request_template.md` có ở cả 3 repo code (enforcement tầng 2)

---

## Nợ để lại sau plan này

Ghi vào roadmap chặng hạ tầng, **không** làm ở đây:

| Nợ | Vì sao hoãn |
|---|---|
| CI enforce rule (import-boundary, grep R-11/R-14/R-16, migration check R-08/R-09) | Cần repo code tồn tại |
| Mục "Rule hay bị vi phạm nhất" trong 3 `CLAUDE.md` | Cần code thật mới biết |
| Testing-Strategy đầy đủ | Hiện chỉ có `P-TEST` |
| Environment/Config | Thuộc repo `infra` |
| Import-Export, Backup vs Recovery | Chặng vận hành |
