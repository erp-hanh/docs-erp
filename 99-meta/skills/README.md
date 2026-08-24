# Sao lưu skill

## Bản nào là bản thật

Bản **đang chạy** nằm trong `erp/.claude/` (và `erp/.agents/skills/` cho phần bên thứ ba).
Đó là chỗ duy nhất Claude nạp skill, đường dẫn đó không đổi được. Sửa skill là sửa ở đó.

Thư mục này là **bản sao lưu có version**, chỉ để cứu khi mất máy. Nó không được nạp,
không có tác dụng gì lúc chạy.

## Đã sao lưu những gì

### Skill riêng của hệ ERP — gốc ở `erp/.claude/skills/`

- `frontend-design-erp/` — hệ thiết kế cho repo `frontend-erp`: token màu/chữ/khoảng cách,
  bộ component dùng chung, năm khuôn màn hình, quy tắc bảng–form–lỗi–phân quyền, checklist
  trước khi giao.
- `deploy-rc/` — đóng một bản release candidate của hệ ERP: tính số rc từ remote, tag cùng
  số trên cả ba repo `infra-erp`/`backend-erp`/`frontend-erp`, đẩy lên VPS dev rồi kiểm
  chứng từ máy ngoài.
- `token/` — kỷ luật tiết kiệm token: trả lời ngắn, đọc file có scope, không lan man.

### Lệnh gõ `/` — gốc là **file rời** ở `erp/.claude/commands/`

Đây không phải thư mục skill mà là các file `.md` rời, mỗi file một lệnh. Chúng nằm ở
`commands/` chứ không nằm thẳng trong `.claude/skills/`, nên bản sao lưu giữ nguyên tên
thư mục `commands/` để khỏi lẫn với skill thật — và để link `deploy.md` → `commit-github.md`
vẫn resolve đúng.

- `commit-github.md` — quy trình commit + push + mở PR: gate trước commit, message theo
  Conventional Commits, giữ vệ sinh nhánh, push an toàn. **Portable.**
- `deploy.md` — quy trình chung Local → Dev → Prod: tag rc, đẩy VPS dev, gate, rồi prod.
  Cố ý không chứa host/path/tên container cụ thể. **Portable.**
- `docker.md` — workflow Docker cho dự án mới, từ dev hot-reload tới image production theo
  pattern Compose override. **Portable.**
- `harden.md` — checklist làm cứng VPS trước khi lên prod: 5 mục bắt buộc (SSH key,
  firewall, fail2ban, app không chạy bằng root, reverse proxy), mỗi mục có CHECK + FIX +
  VERIFY. **Portable.**
- `ssh-github-vps-deploy-dev-prod-prompt.md` — dựng SSH key ed25519, nối GitHub qua SSH, và
  cấu hình hai VPS dev/prod chuẩn production (tắt password login, cấm root, hardening sshd).
  **Portable**, còn nguyên placeholder IP/user/repo/domain.
- `RBAC.md` — quy trình thiết kế phân quyền theo vai trò, không gắn với backend hay frontend
  nào. **Portable.**
- `auth-flow.md` — các bước dựng luồng đăng nhập JWT: access token trong memory, refresh
  token xoay vòng, blacklist trên Redis, `token_version` trong DB. Generic, không riêng ERP.
- `BACKUP-FEATURE-BLUEPRINT.md` — bản thiết kế tính năng backup (Go + React + Docker +
  Postgres + MinIO/S3, đẩy lên Google Drive qua rclone) để bê sang app khác. **Portable.**
- `BACKUP-GDRIVE-SETUP.md` — hướng dẫn admin nối Google Drive qua rclone OAuth. Viết cho
  MasterLMS chứ không phải ERP; giữ ở đây vì nó đi kèm blueprint bên trên.

### Skill bên thứ ba — gốc ở `erp/.agents/skills/`

Sáu skill này được symlink vào `erp/.claude/skills/`. Chúng là bộ "engineering skills" của
Matt Pocock, cài từ nguồn công khai chứ không phải viết tay cho dự án — mất máy vẫn cài lại
được, nhưng chép sang đây để bản đang dùng (có thể đã sửa cục bộ) không biến mất.

- `codebase-design/` — từ vựng chung để thiết kế "deep module": nhiều hành vi sau một giao
  diện nhỏ, đặt đúng đường nối, test được qua giao diện đó.
- `domain-modeling/` — dựng và mài mô hình nghiệp vụ: viết `CONTEXT.md` và ghi ADR.
- `grilling/` — tra hỏi người dùng đến cùng để làm sắc một kế hoạch hay một quyết định.
- `grill-with-docs/` — gọi `grilling` + `domain-modeling` một lượt: vừa tra hỏi vừa sinh
  tài liệu.
- `improve-codebase-architecture/` — quét codebase tìm chỗ đáng làm sâu, trình bằng một báo
  cáo HTML rồi grill tiếp chỗ được chọn.
- `setup-matt-pocock-skills/` — cấu hình repo cho năm skill trên: issue tracker, nhãn triage,
  chỗ để tài liệu domain. Chạy một lần.

## Bản portable: bản gốc có thể còn ở nơi khác

Mọi mục đánh dấu **Portable** ở trên đều được viết để copy sang dự án khác dùng luôn. Vì thế
bản trong `erp/` chưa chắc là bản mới nhất hay bản duy nhất — trước khi coi nó là căn cứ, hãy
tìm cả ở các dự án khác trên máy (`d:\My project web\skills\`, `.claude/commands/` và
`.claude/skills/` của từng dự án). Ngược lại, sửa một file portable ở đây thì các bản chép
bên dự án khác **không** tự cập nhật theo.

## Không nằm trong bản sao lưu này

- `erp/.claude/_disabled/` — các skill đã cố ý tắt (`postgres-index-expert`, `redis-expert`,
  `skill-creator`, `find-skills`, bản `unit-test` cũ). Không chép vì chúng không chạy.
- `postgres-index-expert`, `redis-expert`, `unit-test` **bản đang chạy** nằm ở
  `d:\My project web\.claude\skills\`, tức thư mục cha của `erp` — dùng chung cho nhiều dự
  án, nằm ngoài phạm vi repo này.

## Nó sẽ lệch dần

Vì là bản chép tay chứ không phải symlink hay submodule, hai bên **chắc chắn lệch** nếu
không ai chép lại. Đừng tin thư mục này là bản mới nhất; luôn đối chiếu với
`erp/.claude/skills/` trước khi lấy làm căn cứ.

## Link tương đối: cái bẫy khi chép

`tools/check-ids.ps1` bắt mọi link markdown trong `docs-erp` phải trỏ tới file có thật. Một
link tương đối resolve đúng ở `erp/.claude/skills/` có thể chết ở đây, và làm CI đỏ. Khi chép
một skill sang đây, quét lại mọi link tương đối trong file `.md`; link nào trỏ ra ngoài cây
skill thì sửa ở **cả hai bản** cho khỏi lệch — bỏ link, giữ thông tin, viết lại câu cho đúng.
Đừng chữa bằng cách cho `check-ids.ps1` bỏ qua thư mục này: đó là giấu lỗi.

Hiện có đúng một chỗ đã phải sửa như vậy:
`domain-modeling/CONTEXT-FORMAT.md` — ba đường dẫn ví dụ (`./src/ordering/CONTEXT.md` và hai
cái tương tự) vốn viết thành link markdown; nay để trong dấu nháy ngược. Sửa ở cả bản đang
chạy lẫn bản ở đây, kèm một ghi chú ngay trong file.

## Quy tắc chống lệch

Sửa skill xong thì chép lại sang đây **trong cùng một đợt việc**, commit chung với việc
đã làm — đừng để sang phiên sau:

```sh
cd erp/docs-erp
rm -rf 99-meta/skills/frontend-design-erp                 # cp đè không xoá file đã bị
cp -r ../.claude/skills/frontend-design-erp 99-meta/skills/   # xoá hay đổi tên bên gốc
git add 99-meta/skills/frontend-design-erp
```

## Khôi phục khi mất máy

```sh
git clone https://github.com/erp-hanh/docs-erp.git
mkdir -p erp/.claude/skills erp/.claude/commands erp/.agents/skills

# skill riêng của ERP
cp -r docs-erp/99-meta/skills/frontend-design-erp erp/.claude/skills/
cp -r docs-erp/99-meta/skills/deploy-rc           erp/.claude/skills/
cp -r docs-erp/99-meta/skills/token               erp/.claude/skills/

# lệnh gõ /
cp docs-erp/99-meta/skills/commands/*.md erp/.claude/commands/

# skill bên thứ ba, rồi symlink lại vào .claude/skills/
for s in codebase-design domain-modeling grill-with-docs grilling \
         improve-codebase-architecture setup-matt-pocock-skills; do
  cp -r "docs-erp/99-meta/skills/$s" erp/.agents/skills/
  ln -s "$PWD/erp/.agents/skills/$s" "erp/.claude/skills/$s"
done
```

Mockup nằm ở `../mockups/`, chép ngược về `erp/mockup-erp/` theo cùng cách. Thẻ `<link>`
trong mockup trỏ ra `../frontend-erp/src/shared/styles/`, nên chỉ mở đúng màu khi file đã
nằm ở `erp/mockup-erp/`.
