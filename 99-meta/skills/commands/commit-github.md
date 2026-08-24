---
name: commit-github
description: Quy trình commit + push code lên GitHub chuẩn, an toàn, portable. Dùng MỖI khi chuẩn bị commit/push/mở PR — kiểm tra trước commit, viết message theo Conventional Commits, giữ vệ sinh nhánh, push an toàn, mở PR đúng mẫu. Generic, copy file này vào .claude/skills/ của dự án khác là dùng được.
---

# Git Commit Standard

> Mục tiêu: commit gọn, message rõ, không lộ secret, không phá lịch sử remote, dễ review.
> **Ưu tiên:** Quy tắc trong CLAUDE.md / hướng dẫn dự án LUÔN thắng skill này.

---

## 1. Trước khi commit (gate bắt buộc)

Chạy theo thứ tự, fail bất kỳ bước nào → DỪNG, không commit:

1. **Xem mình đang sửa gì:** `git status` + `git diff` (chưa stage) / `git diff --staged` (đã stage).
2. **Build/test xanh:** chạy lệnh của dự án (vd `npm run build` + `npm test`, `go build ./... && go test ./...`, `pytest`). Đỏ → sửa trước, không commit code hỏng.
3. **Secret scan trên diff** — không commit khoá/mật khẩu:
   ```bash
   git diff --staged | grep -Ei "(-----BEGIN|password[[:space:]]*[:=]|secret|api[_-]?key|token[[:space:]]*[:=]|\.pem|private[_-]?key|aws_[a-z]+_key)"
   ```
   Có kết quả là secret thật → DỪNG, gỡ khỏi diff, thêm vào `.gitignore`.
4. **Stage có chủ đích:** `git add <file cụ thể>`. TRÁNH `git add -A`/`git add .` mù. KHÔNG commit artifact: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`, file lock build (`*.tsbuildinfo`).

---

## 2. Vệ sinh nhánh (branch)

- **KHÔNG commit thẳng lên `main`/`master`.** Đang ở nhánh mặc định → tạo nhánh trước:
  ```bash
  git switch -c <type>/<mô-tả-ngắn>      # vd feat/dispatch-plan, fix/login-csrf
  ```
- **Tên nhánh:** `feat/…`, `fix/…`, `chore/…`, `docs/…`, `refactor/…` + slug kebab-case ngắn.
- **Chọn nền nhánh (base):** tách từ nhánh tích hợp đang hoạt động (vd `main`/`develop` mới nhất). ⚠️ Nếu `main` TỤT XA sau bản đang chạy thực tế (deployed lineage), đừng deploy nhánh-tách-từ-main thẳng — sẽ regress; rebase/ghép feature lên đúng lineage đã deploy trước khi release.
- 1 nhánh = 1 mục tiêu. Việc không liên quan → nhánh khác.

---

## 3. Commit message — Conventional Commits

**Cú pháp:**
```
<type>(<scope tuỳ chọn>): <tóm tắt, mệnh lệnh, ≤ 72 ký tự, không dấu chấm cuối>

<thân: GIẢI THÍCH WHY, không lặp lại WHAT của diff. Xuống dòng ~72 ký tự.>

<footer tuỳ chọn: BREAKING CHANGE:, Refs #123, Co-Authored-By:>
```

**type hợp lệ:** `feat` (tính năng), `fix` (sửa lỗi), `docs`, `style` (format, không đổi logic), `refactor`, `perf`, `test`, `build`, `ci`, `chore` (lặt vặt), `revert`.

**Quy tắc:**
- Tóm tắt: động từ mệnh lệnh, không hoa đầu type. "add", "fix", "thêm" — không "added/fixing".
- `feat`/`fix` → tăng minor/patch (semver). Phá vỡ tương thích → `feat!:` hoặc footer `BREAKING CHANGE: …`.
- 1 commit = 1 thay đổi logic. Trộn nhiều việc → tách `git add -p` thành nhiều commit.

**Ví dụ:**
```
feat(auth): thêm đăng nhập 2FA qua TOTP

Tài khoản admin bật được 2FA để giảm rủi ro lộ mật khẩu.
Mã 6 số kiểm bằng cửa sổ ±1 step cho lệch đồng hồ.

Refs #142
```
```
fix(orders): chặn tạo lệnh vượt số chuyến của đơn (race TOCTOU)
```

> **Footer Co-Authored-By (tuỳ dự án):** nếu commit có AI/người khác hỗ trợ và dự án yêu cầu ghi nhận, thêm dòng `Co-Authored-By: Tên <email>` ở footer. Bỏ nếu dự án không dùng.

**Commit message nhiều dòng (an toàn cross-shell):**
```bash
git commit -m "$(cat <<'EOF'
feat(scope): tóm tắt ngắn

Thân giải thích why.
EOF
)"
```

---

## 4. Cấm tuyệt đối (trừ khi user yêu cầu rõ)

- `--no-verify` (bỏ qua hook) — hook fail thì SỬA gốc, đừng skip.
- `--amend` / `rebase` trên commit ĐÃ push (viết lại lịch sử chung).
- `git push --force` — nếu buộc phải, dùng `--force-with-lease` và CHỈ trên nhánh riêng của mình.
- Bỏ ký commit (`--no-gpg-sign`) nếu dự án bật signing.
- Commit khi build/test đỏ.

---

## 5. Push

```bash
git push -u origin <branch>      # lần đầu: set upstream
git push                          # các lần sau
```
- Push nhánh feature, KHÔNG push thẳng `main` trừ khi quy trình dự án cho phép.
- Push xong kiểm CI (nếu có) xanh trước khi mở PR.

---

## 6. Mở Pull Request (gh CLI)

```bash
gh pr create --base <main|develop> --head <branch> \
  --title "<type>(<scope>): tóm tắt" \
  --body "$(cat <<'EOF'
## Tóm tắt
- <gạch đầu dòng: thay đổi chính + why>

## Test Plan
- [ ] <bước verify / lệnh test đã chạy>
EOF
)"
```
- Title theo Conventional Commits (để squash-merge sinh changelog đúng).
- Body: nêu WHY + cách test. Link issue (`Refs #…` / `Closes #…`).
- Không tự merge PR của chính mình nếu dự án yêu cầu review.

---

## 7. Checklist nhanh trước khi gõ `git commit`

- [ ] Build/test xanh?
- [ ] Secret scan sạch?
- [ ] Chỉ stage file liên quan (không artifact, không .env)?
- [ ] Đang ở nhánh feature (không phải main)?
- [ ] Message đúng Conventional Commits + thân nêu why?
- [ ] 1 commit = 1 thay đổi logic?

---

## 8. Tuỳ biến cho từng dự án (sửa khi copy sang repo khác)

- Lệnh build/test (mục 1.2) — đổi theo stack.
- Nhánh mặc định (`main`/`master`/`develop`) ở mục 2, 6.
- Footer `Co-Authored-By` — giữ/bỏ theo quy ước nhóm.
- Quy ước scope (vd theo module/package của dự án).
- Nếu repo có quy trình tag/release/deploy riêng → skill này CHỈ lo tới bước commit + push (+ PR). Sau đó chuyển sang skill deploy của dự án để tag release + đẩy môi trường. Chuỗi: **commit-github (commit+push) → skill deploy (tag + deploy)**. Tên skill deploy + cách nối ghi trong CLAUDE.md của từng dự án.
  - ⚠️ Dự án **nhiều repo**: thay đổi cross-cutting → commit từng repo trên nhánh CÙNG TÊN. Đánh tag rc (cùng số mọi repo, tính từ remote sau `fetch`) + chọn lineage thuộc skill deploy, KHÔNG làm ở bước commit.

> **Cách dùng portable:** copy file `commit-github.md` vào `.claude/skills/` của dự án khác → gọi qua Skill tool khi commit.
