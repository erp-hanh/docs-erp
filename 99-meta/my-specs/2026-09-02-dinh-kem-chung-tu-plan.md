# Đính kèm chứng từ gốc vào phiếu kho - kế hoạch

Ngày 2026-09-02. Người dùng yêu cầu hai lần: "thêm 1 vùng để tải chứng từ lên" ở màn lập
phiếu. Tôi đã nêu lo ngại backend chưa có gì, họ vẫn muốn - nên làm đầy đủ cả hai phía.

Đây là **đợt C** của ba đợt. Đợt A (kéo bề rộng cột bảng dòng phiếu) và đợt B (màn chi tiết
theo khuôn màn lập phiếu) đi trước vì chúng không đụng hạ tầng.

---

## Vì sao đợt này lớn hơn nó trông

Ba chỗ chặn, khảo sát ngày 2026-09-02:

1. **Không có chỗ nào để đặt tệp.** Service `api` trong `compose/dev-vps.yml` đang
   `read_only: true`, chỗ ghi duy nhất là `tmpfs: /tmp:size=16m` - nằm trong RAM, mất khi
   container dừng. `compose/dev.yml` thì service `api` không có khoá `volumes:` nào. Volume
   duy nhất của cả hệ là `erp_pgdata` cho Postgres, và trên VPS nó là bind mount
   `/srv/erp/postgres` - cố ý nằm ngoài `/opt/erp` để `docker system prune -v` không với tới.
2. **Backend chưa có một dòng nào về tệp.** Grep `multipart|FormFile|io.Copy|os.Create|minio|s3`
   trên toàn bộ `*.go`: 0 kết quả trong code nghiệp vụ. `go.mod` không có SDK lưu trữ nào.
3. **Phiếu đã ghi KHÔNG sửa được** - route chỉ có POST và DELETE, không có PATCH, và đó là
   quyết định có chủ ý (`voucher_routes.go`). Đường sửa một tờ phiếu là xoá rồi ghi lại.

Chỗ chặn 3 tưởng là chặn nặng nhất - tệp treo vào `voucher_id` sẽ mồ côi mỗi lần sửa phiếu -
nhưng MISA đã trả lời giúp, xem mục dưới.

---

## MISA làm gì

Tra ngày 2026-09-02, nguồn ghi kèm.

**Điều đáng lấy nhất:** đính kèm **sửa được sau khi chứng từ đã ghi sổ, KHÔNG cần bỏ ghi**.
Trường "Đính kèm" nằm trong phạm vi chức năng **Sửa nhanh**, và **Phiếu nhập kho, Chuyển kho**
có tên trong danh sách đó -
[helpact.misa.vn](https://helpact.misa.vn/kb/huong-dan-chuc-nang-sua-nhanh-va-pham-vi-chinh-sua-theo-tung-loai-chung-tu/).

Nghĩa là đính kèm **không phải một phần của tờ phiếu bất biến**. Nó là dữ liệu phụ, có đường
API riêng, vòng đời riêng. Chỗ chặn 3 tan.

Những gì MISA nói thêm:
- **5MB mỗi tệp** - mốc duy nhất tài liệu nêu, và nêu ở ngữ cảnh TSCĐ chứ không phải mọi
  chứng từ ([helpact](https://helpact.misa.vn/kb/dinh_kem_tai_lieu_vao_tscd_duoc_ghi_tang/)).
- **Nhiều tệp trên một chứng từ**, không nêu trần.
- **Tải về được**, và từ SME 2023 R9 thì **xem trước được** ngay trên chứng từ.
- **Cột tài liệu đính kèm hiện ngay trên màn DANH SÁCH** chứng từ ở nhiều phân hệ - xem nhanh
  không cần mở từng tờ.
- **Không có quyền riêng** cho đính kèm; trang phân quyền vai trò chỉ có sử dụng / thêm / sửa
  / xoá / in theo phân hệ ([helpact](https://helpact.misa.vn/kb/phan-quyen-cho-vai-tro/)).
- Nhãn trên màn: **"Đính kèm"**. SME tách hai loại: "Tệp đính kèm" và "Link liên kết".
- **Tên tài liệu là một trường riêng**, người dùng đặt, tách khỏi tên tệp gốc.

Bốn chỗ tài liệu KHÔNG nói, phải tự quyết: loại tệp cho phép, tổng dung lượng và số tệp mỗi
chứng từ, đính kèm khi đã khoá sổ, và xoá chứng từ thì tệp ra sao.

---

## Quyết định

| Điểm | Quyết | Lý do |
|---|---|---|
| Loại tệp | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` | Chứng từ gốc là thứ người ta chụp hoặc scan. Nhận mọi loại là mở cửa cho tệp thực thi. Kiểm bằng **magic bytes**, không tin `Content-Type` của client. |
| Cỡ | 5MB mỗi tệp, 10 tệp mỗi phiếu | 5MB là mốc duy nhất MISA nêu. Trần số tệp để một phiếu không nuốt hết đĩa VPS. |
| Khoá sổ | Không phải quyết | Hệ này chưa có khoá sổ kỳ kế toán. |
| Xoá phiếu | Xoá mềm tệp theo phiếu (`deleted_at`), **giữ tệp trên đĩa** | Cùng lối R-18 cả hệ đang dùng. Xoá nhầm phiếu thì khôi phục được cả tệp. Dọn đĩa là việc của một job sau, không phải của đường xoá. |
| Quyền | **KHÔNG thêm mã quyền mới** | Đi theo quyền của chính phiếu, đúng như MISA. Tránh luôn bẫy ADR-0027: quyền mới không tự tới các công ty đang chạy, và migration ghi thẳng `role_permissions` đã bị arch test chặn. |
| Tên hiển thị | Lấy tên tệp gốc, KHÔNG thêm trường "tên tài liệu" | MISA có, hệ này chưa cần: một ô nhập thêm cho mỗi tệp trong lúc thủ kho đang vội là một ô bị bỏ trống. Thêm sau nếu ai hỏi. |
| Link liên kết | Không làm | Hệ này chưa có ai lưu tài liệu trên Drive. |

**Tệp tải lên TRƯỚC khi phiếu tồn tại.** Ở màn lập phiếu chưa có `voucher_id` để treo. Lối
đi: `POST /attachments` nhận tệp và trả `id` với `voucher_id = NULL`; khi ghi phiếu thì thân
request mang thêm `attachment_ids: []`, service gắn chúng vào phiếu trong CÙNG transaction.
Tệp mồ côi quá 24 giờ thì một job dọn - **chưa làm ở đợt này**, ghi vào việc còn nợ.

---

## C1 - Hạ tầng: chỗ để tệp

**Files:** `infra-erp/compose/dev.yml`, `infra-erp/compose/dev-vps.yml`,
`infra-erp/docs/Deploy-dev-vps.md`

- Máy dev dưới máy: volume đặt tên `erp_tepdinhkem` → `api:/var/lib/erp/tep`.
- VPS: bind mount `/srv/erp/tep` → `api:/var/lib/erp/tep`, cùng lối `/srv/erp/postgres` đang
  dùng. Ra ngoài `/opt/erp` để `docker system prune -v` không với tới và để không lọt vào
  build context.
- `api` đang `read_only: true` - giữ nguyên, chỉ khai thêm đúng một mount ghi được. Đừng bỏ
  `read_only`: nó là một lớp chặn thật, và bỏ nó để tiện một lần là bỏ vĩnh viễn.
- Quyền thư mục trên VPS phải khớp uid mà container `api` chạy. Đọc Dockerfile của api xem
  nó chạy dưới uid nào trước khi `mkdir`.
- Cập nhật `Deploy-dev-vps.md`: tài liệu đó phải mô tả máy như nó đang chạy thật.

**Kiểm chứng:** ghi một tệp từ trong container, `docker compose restart api`, đọc lại thấy.
Rồi `docker compose down && up` một lần nữa - tệp phải còn.

## C2 - Backend: bảng và bốn đường

**Migration** `migrations/000045_tep_dinh_kem.up.sql` (+ `.down.sql`). Số 000045 vì cao nhất
hiện là 000044. **Không BEGIN/COMMIT** - golang-migrate chạy cả file bằng một ExecContext.

Bảng `voucher_attachments`:
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
- `company_id UUID NOT NULL REFERENCES companies(id)` - **bắt buộc**, R-06
- `voucher_id UUID NULL REFERENCES stock_vouchers(id)` - NULL khi tệp vừa tải lên chưa gắn
- `ten_tep TEXT NOT NULL` - tên gốc người dùng tải lên
- `loai_mime TEXT NOT NULL` - đã xác minh bằng magic bytes, không tin client
- `co_byte BIGINT NOT NULL`
- `duong_dan TEXT NOT NULL` - đường tương đối dưới `/var/lib/erp/tep`
- `created_at, created_by, deleted_at`
- Index partial `WHERE deleted_at IS NULL` trên `(company_id, voucher_id)`

**Đường dẫn tệp trên đĩa**: `{company_id}/{yyyy}/{mm}/{attachment_id}.{ext}`. Chia theo công
ty để một lệnh xoá công ty là xoá một cây; chia theo tháng để một thư mục không có triệu tệp.
**Tên tệp trên đĩa là UUID, KHÔNG phải tên người dùng đặt** - tên gốc có thể mang `../`, ký tự
Unicode, hoặc trùng nhau.

Bốn đường, khai ở `modules/inventory/internal/handler/attachment_routes.go`:
- `POST /api/v1/attachments` - multipart, một tệp mỗi lần. Trả `{id, ten_tep, co_byte, loai_mime}`.
- `GET /api/v1/stock-vouchers/:id/attachments` - danh sách tệp của một phiếu.
- `GET /api/v1/attachments/:id/tai-ve` - trả tệp. **R-11 đã chừa sẵn ngoại lệ envelope cho
  đường trả file** (`arch/testdata/r11/valid_tra_file.go`).
- `DELETE /api/v1/attachments/:id` - xoá mềm.

Và `POST /stock-vouchers` nhận thêm `attachment_ids: []` trong thân, gắn trong cùng
transaction với việc ghi phiếu.

**Tám dòng neo phải sửa** (generator `cmd/dev new-resource` biết chúng, xem
`cmd/dev/newresource_va.go`): permission, tên ràng buộc DB, nhánh dịch lỗi trùng khoá, cửa ra
permission, `MoiQuyen()`, `module.yaml` khối bảng, `module.yaml` khối bảng chịu phạm vi,
`vaitro.go`. **Nhưng đợt này KHÔNG thêm quyền mới**, nên bốn dòng neo về permission bỏ qua -
ghi rõ lý do trong `modules/inventory/docs/Permission.md`.

**Phạm vi kho**: phiếu áp luật trọn-hoặc-không (chỉ thấy phiếu khi MỌI dòng nằm trong phạm
vi). Tệp treo vào phiếu nên nó **thừa hưởng** luật đó - không tự dựng phép lọc thứ hai, đi qua
chính repository của phiếu.

**Ba bẫy bảo mật, cái nào lọt cũng là sự cố:**
1. `duong_dan` phải dựng từ UUID do máy chủ sinh, **không bao giờ** từ chuỗi client gửi. Một
   `../../etc/passwd` là đủ.
2. Đường tải về phải kiểm `company_id` của tệp khớp `actor.CompanyID` **trước khi** mở tệp.
   Repository không tự lọc - không có RLS, mỗi câu SQL tự mang `company_id = $1`.
3. Trả tệp phải kèm `Content-Disposition: attachment` và `X-Content-Type-Options: nosniff`.
   Một SVG hay HTML trả về với `inline` là XSS trên chính miền của ứng dụng.

**Test**: `go run ./cmd/dev test` (cần database thật, harness tự dựng container Postgres).
Không dùng `go test ./...` trần.

## C3 - Frontend: vùng đính kèm

**Files:** `src/modules/inventory/components/VungDinhKem.tsx` (mới) + `.module.css`,
`PhieuFormPage.tsx`, `VoucherDetailPage.tsx`, `api/`, `hooks/`

Hình dạng đã duyệt ở `mockup-erp/phieu-form-bo-cuc.html` (phương án A, khối `.vung-dinh-kem`):
nhãn "Đính kèm - Ảnh hoặc PDF, mỗi tệp tối đa 5MB", ô kéo thả "Chọn tệp hoặc kéo và thả tệp
vào đây", mỗi tệp đã tải thành một dòng có icon theo loại, tên, cỡ và nút bỏ.

Đặt ở **cả hai màn**: màn lập phiếu (tải trước, gắn khi ghi) và màn chi tiết (thêm/xoá sau
khi đã ghi - đúng như MISA cho Sửa nhanh).

Bốn trạng thái phải có, thiếu cái nào là màn chưa xong: đang tải lên (có thanh tiến trình
thật, không phải một chữ "đang tải"), tải xong, tải hỏng (nói rõ vì sao - quá cỡ, sai loại,
mạng đứt - và cho thử lại), và rỗng.

**Kiểm phía màn hình là UX, không phải nghiệp vụ (C-TS-05):** chặn cỡ và loại ngay ở trình
duyệt để người dùng khỏi chờ 5MB rồi mới biết sai, **nhưng máy chủ vẫn phải kiểm lại** - một
phép kiểm chỉ có ở frontend là một phép kiểm không tồn tại.

## Còn nợ sau đợt này

- **Job dọn tệp mồ côi** (tải lên rồi bỏ phiếu, `voucher_id` NULL quá 24 giờ).
- **Xem trước tệp** ngay trên phiếu (MISA có từ R9). Đợt này chỉ tải về.
- **Cột "có đính kèm" trên màn danh sách phiếu** - MISA có, thấy nhanh tờ nào đã kẹp chứng từ.
- **Dọn tệp trên đĩa khi xoá cứng một công ty.**
- Trường "tên tài liệu" riêng, và "Link liên kết".
