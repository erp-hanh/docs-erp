# Bàn giao: đính kèm chứng từ, màn chi tiết, kéo cột

Ngày 2026-09-02. Nối tiếp `2026-09-02-lap-phieu-theo-mau-misa-ban-giao.md`.
Kế hoạch đính kèm: `2026-09-02-dinh-kem-chung-tu-plan.md`.

## Trạng thái

- **`v0.1.0-rc.111`** đang chạy trên dev. Tag khớp `main` cả ba repo.
- `main`: frontend `f90ed50`, backend `e6e984e`, infra `7eb2ed2`.
- **2384 bài xanh** (frontend), backend `go run ./cmd/dev test` xanh 46 gói.
- `tsc`, `lint`, `arch`, `kiem-giao-dien.mjs` sạch cả hai repo.
- **Chưa xác nhận được CI**: `gh` không đăng nhập host nào. Tag dựa trên bằng chứng cục bộ
  cộng một lượt đi thử tay đầu-cuối trên dev. Xem [[github-account-erp-hanh]].

## Ba việc người dùng giao, đã xong cả ba

1. **Kéo đổi bề rộng cột** ở bảng dòng phiếu. Khoá lưu riêng `lap-phieu-dong`. Kéo một cột
   KHÔNG đụng cột khác - bảng rộng theo tổng các cột (`table-layout: fixed` +
   `width: max-content`), tràn khung thì cuộn ngang, cột Thao tác dính mép phải.
2. **Màn chi tiết theo khuôn màn lập phiếu.** Đầu phiếu dải nền chìm, khối "Hàng hoá" có tên
   khối, hàng tổng trong `<tbody>`.
3. **Vùng tải chứng từ lên** - cả ba tầng, xem dưới.

## Đính kèm: ba tầng và chỗ chúng nối nhau

**Hạ tầng** (`infra-erp`, `cb849e5`): volume `erp_tepdinhkem` dưới máy dev, bind mount
`/srv/erp/tep` trên VPS (uid 100 gid 101, hỏi chính ảnh api chứ không đoán). `read_only: true`
của service api GIỮ NGUYÊN - mount này là chỗ ghi thứ hai và cuối cùng.

**Backend** (`e6e984e`): bảng `voucher_attachments`, bốn đường
(`POST /attachments`, `GET /stock-vouchers/:id/attachments`, `GET /attachments/:id/tai-ve`,
`DELETE /attachments/:id`), cộng `attachment_ids: []` trong thân `POST /stock-vouchers`.
**Không thêm mã quyền mới** - đi theo quyền của phiếu, đúng như MISA, và tránh bẫy ADR-0027.

**Frontend** (`f90ed50`): `VungDinhKem` dùng chung hai màn, khác nhau đúng prop `voucherId`.

**Đã đi thử thật đầu-cuối**: tải tệp → ghi phiếu → tệp gắn đúng vào `PN-2026-0014` → mở màn
chi tiết thấy lại. Byte nằm ở `/var/lib/erp/tep/{company_id}/2026/09/{uuid}.png`. Tệp còn
nguyên sau khi đổi tag - bind mount ngoài vòng đời container.

## Năm chốt bảo mật, mỗi cái một bài canh chứng minh bằng đột biến

| Chốt | Chỗ |
|---|---|
| Đường dẫn từ UUID máy chủ sinh, không từ tên người dùng | `attachment_service.go:263` |
| Câu đọc tệp mang `company_id` | `voucher_attachment_repository.go:81`, `:119` |
| `Content-Disposition: attachment` + `nosniff` | `attachment_handler.go:213-214` |
| Chốt chống `..` trong đường dẫn | `dia.go:118` |
| Magic bytes từ chối loại lạ | `attachment_service.go:546` |

Đột biến vào chốt 2 làm rò thẳng byte `‰PNG` của công ty khác ra ngoài - đó là mức độ của ca
này, không phải một phép kiểm hình thức.

## Còn nợ

- **Tệp mồ côi**: tải lên rồi bỏ phiếu thì tệp nằm lại với `voucher_id = NULL`. Chưa có job
  dọn. Bỏ một tệp ở màn LẬP cũng là bỏ cục bộ, không gọi DELETE.
- **Byte trên đĩa giữ nguyên sau xoá mềm** - dọn đĩa là việc riêng.
- **Bốn ca chưa thử tay**: kéo-thả thật, thanh tiến trình trên tệp lớn, mở tệp sau khi tải về,
  và câu chữ ba màn báo lỗi (quá cỡ / sai loại / quá 10 tệp).
- **Tám mục "quan trọng"** từ đợt soi code, nặng nhất: một tờ phiếu 20 dòng bắn ~40 lời gọi
  `/stock-balances`, quá nửa phục vụ một bảng xổ chưa ai mở.
- **Cột THÀNH TIỀN âm ở phiếu chuyển** trên màn chi tiết - đúng với sổ, nhưng trên một tờ
  phiếu chuyển thì tiền không mất đi đâu. Chưa hỏi người dùng.
- `mockup-erp/phieu-form-bo-cuc.html` đã lệch với code (vẫn vẽ khung kéo-thả to). Mockup hết
  hạn từ lúc lên code - đừng sửa, đừng duyệt lại nó.

## Bài học của đợt, đắt nhất là ba cái đầu

1. **Deploy nói dối ba lần, mỗi lần một kiểu.** Build chết vì mạng; commit nằm nhầm nhánh;
   biến môi trường không nằm trong git. Cả ba lần mọi cổng đều xanh. Xem
   [[deploy-bao-xanh-ma-chua-deploy]] và mục 4c/4d của `infra-erp/docs/Deploy-dev-vps.md`.
2. **Tám lỗi chặn merge, không cái nào do bộ test bắt.** Ba trong đó CÓ bài test canh, và cả
   ba bài đều xanh giả: một bài bọc mỗi sự kiện chuột trong một nhịp React riêng (dựng lại
   điều kiện trình duyệt không có); một bài mang tên nói canh cả hai nửa mà chỉ chạm một nửa;
   bốn bài đọc chữ của cả hàng, mà chuỗi cần canh đã nằm sẵn trong một thẻ ẩn ở ô bên cạnh.
3. **Bốn lỗi cuối cùng đều là MỘT SỰ THẬT CHÉP LÀM HAI BẢN.** Khối kéo cột chép giữa hai
   bảng; chuỗi đơn vị tính khai ở hai ô; khoảng cách 4px khai ở CSS trong khi phép tính nằm ở
   JS; chiều cao 256px khai ở CSS trong khi hằng ước lượng nằm ở JS. Không cái nào khó, cả
   bốn đều là sửa một chỗ quên chỗ kia.
4. **jsdom không tính bố cục.** Năm trong sáu lỗi của một đợt chỉ soi thật trên dev mới ra.
5. `git merge | tail; echo $?` in ra 0 KỂ CẢ khi merge dừng vì xung đột - pipe nuốt mã thoát
   của git y như của vitest. Đọc `git status` mới biết sự thật.
