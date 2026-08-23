# Bàn giao - 2026-08-24, ADR-0027 thi công xong và ADR-0029 ra đời

Đọc file này trước khi làm tiếp trên cụm phân quyền. Bàn giao trước còn nguyên giá trị và nói
về đợt khác: `2026-08-22-ban-giao-vai-tro-dot-2a.md`. File này đóng mục 1 và mục 3 của nó.

Máy dev đang chạy `v0.1.0-rc.32` trên cả ba repo.

## Đã xong

**Mục 2 của bàn giao trước - ba file `modules/*/docs/Permission.md`.** Tiền đề "bảng vai trò
thật sống ở `cmd/internal/vaitro` dưới dạng `authz.Bang`" đã sai từ ADR-0023 đợt 1; nay cả ba
file nói đúng: nguồn sự thật lúc chạy là `roles`/`role_permissions` của **từng phân vùng**, còn
`cmd/internal/vaitro` giữ **bộ giá trị khởi tạo** với đúng hai người đọc `Bang()` là
`BoMacDinh()` và `KemVaiTroDanXuat()`. Mọi chỗ viện ADR-0010 như luật đang sống đã đổi sang
ADR-0023 mục 9.

**Mục 1 - lỗ `auth.admin` tự nhân bản: đã quyết, không phải đã bịt.** [ADR-0029](../../03-decisions/ADR-0029-nhan-ban-quan-tri-trong-cung-module.md)
chốt giữ nguyên hành vi và phát biểu lại bất biến cho đúng phạm vi:

- Hệ **giữ**: không ai phát ra được quyền mà mình không phát được.
- Hệ **không hứa**, và ADR-0024 đã lỡ đọc thành có: số người giữ một quyền không tăng nếu
  không có người ở tầng trên.

Lỗ ADR-0021 để lại là lỗ **xuyên module**, và nó đã đóng thật cho cả ba vai trò. ADR-0024
không bị thay thế - chỉ một câu ở Consequences được đính chính.

`TestNhanBanQuanTri_ChotTinhChatCuaBaVaiTroQuanTri` (`cmd/internal/vaitro/vaitro_test.go`) khoá
lại điều mà ADR-0029 ghi vào Nợ để lại: `inventory.admin` và `machine.admin` không nhân bản
được **vì nội dung tập quyền**, không vì một luật nào. Bỏ bốn mã `auth.*` khỏi chúng là chúng
nhân bản được ngay - bài này là thứ duy nhất kêu.

**Mục 3 - `cmd/dev seed-roles` của ADR-0027.** Đã có, đã chạy trên dev, và đã là bước `4b` của
`infra-erp/scripts/deploy-dev.sh` ngay sau `migrate-up`.

- Mỗi module xuất `MoiQuyen()`; `vaitro.DanhMucQuyen()` gộp ba module - **48 mã**. Một bài test
  đọc AST của chính `module.go` bắt ca thêm hằng mà quên thêm vào danh mục.
- `RoleRepository.NapBuVaiTroConThieu` chèn bằng **một câu** `INSERT ... WHERE NOT EXISTS ...
  RETURNING code`. Tập quyền chỉ chèn cho mã có trong `RETURNING` - chèn cho cả bộ là ghi vào
  tập quyền của vai trò đã tồn tại, đúng điều ADR-0027 mục 2 cấm.
- Phép đối soát ADR-0027 mục 7 lặp qua **mọi** công ty còn sống kể cả khi có cờ `--company`.

## Ba thứ đắt nhất học được đợt này

**1. Bản đầu của `seed-roles` bị R-06, R-09 và R-18 bác, và R-18 là mâu thuẫn cứng.** ADR-0027
mục 3 đòi đọc **thấy** hàng bia mộ để khỏi hồi sinh vai trò công ty đã xoá; R-18 cấm mọi
`SELECT` trong `*_repository.go` đọc bảng chịu soft delete mà không có `deleted_at IS NULL`.
Không ngoại lệ nào của R-18 phủ ca này. Người quyết chọn **gộp phép hỏi vào chính câu chèn**
thay vì mở ngoại lệ cho rule - `NOT EXISTS` cố ý không lọc `deleted_at`, và comment tại chỗ nói
thẳng điều đó. Ngày nào cần đọc bia mộ ở một đường khác, câu hỏi này quay lại và lúc ấy phải là
một ADR.

**2. Một cảnh báo luôn xuất hiện là một cảnh báo không ai đọc nữa.** rc.31 bắn năm dòng
`CANH BAO - hang "auth.company_*" khong vai tro nao cap`, và nó sẽ bắn đúng năm dòng ấy mọi lần
triển khai: năm mã đó chỉ thuộc vai trò dẫn xuất `quan_tri_he_thong`, thứ không bao giờ có hàng
`role_permissions`. `doiSoatQuyen` nay nhận tập miễn, và phép miễn **chỉ** áp cho vế cảnh báo -
trừ khỏi danh mục sẽ biến một hàng dữ liệu bẩn thành một lần thoát khác 0 sai địa chỉ. rc.32 im
đúng như mong đợi.

**3. `Deploy-dev-vps.md` đã sai một câu quan trọng và nay đã sửa.** Nó ghi rằng sửa
`deploy-dev.sh` chỉ có tác dụng từ lần deploy kế tiếp. Câu đó đúng trước `c762a3d` và sai từ
đó: bước `1d` chép script của ref vừa checkout ra file tạm rồi `exec` sang nó. Kiểm chứng ở
rc.31 - bước `4b` chạy ngay lần đầu. Phần `1d` **không** chữa: các bước `1a`-`1c` vẫn chạy bằng
bản cũ.

## Cạm bẫy của nhiều phiên cùng lúc - đã cắn thật

`main` của `backend-erp` được checkout ở **đúng một** cây làm việc mà nhiều phiên cùng dùng. Một
phiên commit thẳng vào `main` ở đó thì commit ấy đi theo cú `git push` của **bất kỳ phiên nào**.
Đợt này đã xảy ra: `431953f` (khối 7, sổ chuyển động tra được, của một phiên thứ ba) lên remote
qua cú push của phiên seed-roles. Nó xanh CI nên không hỏng gì, nhưng nó lên public qua tay
người khác.

Cách đã dùng để tránh, và nên dùng tiếp: nhánh riêng, cộng một `git worktree` dưới scratchpad khi
cây chính đang bận. Đợt này đã dựng worktree cho `infra-erp` vì cây chính của nó đang giữ việc dở
của phiên khác.

## Việc còn mở

1. **Đợt 2b - CRUD vai trò.** Khi vế ghi tập quyền ra đời, ADR-0028 mục 5 phải được áp ngay tại
   đó. Kèm theo, ADR-0029 mục Nợ để lại nêu một ca chưa ai xét: từ lúc có đường ghi, một
   `auth.admin` **sửa được tập quyền của vai trò mình đang mang**, và luật hiệu đối xứng của
   ADR-0024 mục 2 không chặn ca nó tự thêm một mã `auth.*` mà chính nó đang có.
2. **Ba spec còn mở của cụm màn phân quyền**, chép lại từ bàn giao trước vì chưa cái nào động
   tới: `2026-08-21-tim-kiem-nguoi-dung-spec.md`, `2026-08-21-nhan-vai-tro-kem-auth-me-spec.md`
   (ADR-0025 đã mở đường), `2026-08-21-gan-duoc-tren-danh-muc-vai-tro-spec.md`, và ADR-0026.
3. **Đường nạp thật của `seed-roles` chưa chạy trên dữ liệu thật.** Hai phân vùng trên dev đều
   đã đủ bảy vai trò nên mọi lần chạy đều `nap 0`. Đường nạp chỉ được chứng minh bằng bốn bài
   chạm database trên CI. Nó sẽ chạy thật lần đầu vào ngày module thứ tư lên - và đó đúng là
   ngày không nên phát hiện ra một lỗi.
4. **Chưa có màn hình nào cho quản trị thấy "module mới có những vai trò này"** (Nợ để lại của
   ADR-0027).

## Trạng thái dev

`v0.1.0-rc.32`: infra `0ef1f72`, backend `2a1747d`, frontend `4d6e8ff`. `/health` và `/ready`
200, web 200, ba cổng 5433/9090/3000 đều đóng từ ngoài. `seed-roles` báo hai công ty, nạp 0, bỏ
qua 7 mỗi bên, không dòng cảnh báo nào.

Tài khoản thử giữ nguyên như bàn giao trước: `qa-admin`, `qa-thukho`, `qa-kho-admin`,
`qa-muc-tieu`, cùng mật khẩu `QaPhamVi!2026`, phân vùng `DEFAULT`.

Một điều phiên khối 5 nhắn lại, đáng biết trước khi nghiệm thu: khối tìm kiếm danh mục mới xong
**backend**. `?q=` gọi bằng curl thì chạy, nhưng chưa màn hình nào có ô tìm kiếm, nên dòng "thủ
kho tìm được mã ngoài trang đầu" chưa xanh được ở rc.32.
