# Thiết kế: danh sách trước, form sau - bốn màn ghi của Kho vận

Ngày: 2026-08-31. Trạng thái: đã duyệt trong hội thoại cùng ngày.

Chỉ đụng `frontend-erp`. **Backend không phải làm gì**: hai đường đọc cần dùng đã có sẵn
tham số lọc `kind`.

## 1. Vấn đề

Bốn mục nav của nhóm "Ghi sổ" mở **thẳng một form trắng**:

| Mục | Đường | Màn đang mở ra |
|---|---|---|
| Nhập kho | `/nhap-kho` | `PhieuFormPage kind="nhap"` |
| Xuất kho | `/xuat-kho` | `PhieuFormPage kind="xuat"` |
| Chuyển kho | `/chuyen-kho` | `PhieuFormPage kind="chuyen"` |
| Điều chỉnh tồn | `/dieu-chinh` | `MovementRecordPage loai="dieu_chinh"` |

Nguồn: `src/app/routes.tsx:314-317`.

Ba hệ quả:

| # | Lỗ | Đo được ở đâu |
|---|---|---|
| 0 | Không có đường tự nhiên tới **danh sách phiếu nhập**. Muốn xem phiếu nhập đã lập thì phải sang màn khác tên (`/phieu`) rồi tự đặt bộ lọc. | `routes.tsx:341` - `/phieu` là danh sách duy nhất, và nó gộp cả ba loại |
| 1 | Bấm một mục nghiệp vụ là **rơi ngay vào một form trắng**, kể cả khi người dùng chỉ định tra cứu. Không có bước "nhìn cái đã có" trước bước "tạo cái mới". | `routes.tsx:314-317` |
| 2 | Màn `/phieu` gộp ba loại chứng từ vào một bảng, nên mọi lần dùng đều bắt đầu bằng một thao tác lọc. | `VoucherListPage.tsx` |

## 2. MISA làm gì

Tra ngày 2026-08-31, bản AMIS Kế toán.

| Dữ kiện | Nguồn |
|---|---|
| Vào tab **Xuất kho** thì thấy **danh sách chứng từ xuất kho đã lập**, kèm nút **Thêm** để lập phiếu mới. | [Phiếu xuất kho](https://helpact.misa.vn/kb/html_17010200/) |
| Phân hệ Kho có tab Nhập kho và tab Xuất kho **riêng**, mỗi tab theo dõi chứng từ của một chiều. Không có màn gộp hai chiều. | [Chức năng phân hệ Kho](https://helpact.misa.vn/kb/giai-thich-y-nghia-va-cac-chuc-nang-co-trong-phan-he-kho/) |
| Thứ tương ứng với sổ chuyển động của hệ này (Thẻ kho, Sổ chi tiết vật tư) nằm bên **Báo cáo**, không nằm trong menu nghiệp vụ. | [Báo cáo chi tiết kho](https://helpact.misa.vn/kb/bao-cao-chi-tiet-kho/) |

Chỗ tài liệu MISA không trả lời: bấm một dòng trong danh sách thì mở ra gì. Hệ này tự
quyết ở mục 4.

## 3. Quyết định

**Mỗi mục nav mở ra một danh sách. Form nằm sau một nút trên danh sách đó.**

Kèm hai quyết định người dùng chốt ngày 2026-08-31:

1. **Bỏ màn sổ phiếu gộp khỏi menu.** Ba danh sách riêng là đủ; giữ thêm một màn gộp
   nghĩa là một tờ phiếu xem được ở hai chỗ.
2. **Điều chỉnh tồn có danh sách riêng**, không đá người dùng sang Sổ chuyển động. Cùng
   khuôn với ba màn kia thì không phải học hai lối.

## 4. Bản đồ đường đi

| Đường | Màn | Dựng từ |
|---|---|---|
| `/nhap-kho` | Danh sách phiếu nhập, nút **Lập phiếu nhập** | `VoucherListPage` khoá sẵn `kind=nhap` |
| `/nhap-kho/moi` | Form lập phiếu nhập | `PhieuFormPage kind="nhap"`, y nguyên |
| `/xuat-kho`, `/xuat-kho/moi` | Như trên, `kind=xuat`, nút **Lập phiếu xuất** | |
| `/chuyen-kho`, `/chuyen-kho/moi` | Như trên, `kind=chuyen`, nút **Lập phiếu chuyển kho** | |
| `/dieu-chinh` | Danh sách các lần điều chỉnh, nút **Ghi điều chỉnh** | `MovementListPage` khoá sẵn `kind=dieu_chinh` |
| `/dieu-chinh/moi` | Form ghi điều chỉnh | `MovementRecordPage loai="dieu_chinh"`, y nguyên |
| `/phieu` | **Chuyển hướng** sang `/nhap-kho` | `ChuyenHuongDuongCu` |
| `/phieu/:id` | Chi tiết một tờ phiếu, **giữ nguyên** | `VoucherDetailPage` |
| `/chuyen-dong/:id` | Chi tiết một dòng chuyển động, **giữ nguyên** | `MovementDetailPage` |

**Chi tiết vẫn ở một chỗ cho mọi loại.** Hai màn chi tiết đã xử lý đủ ba loại phiếu và đủ
mọi loại chuyển động; tách chúng ra bốn đường chỉ để cho đối xứng là nhân bốn một màn
không có gì khác nhau bên trong.

**Nút quay lại của màn chi tiết phải đi theo loại**: từ một phiếu nhập quay về
`/nhap-kho`, phiếu xuất về `/xuat-kho`, phiếu chuyển kho về `/chuyen-kho`; từ một dòng
điều chỉnh về `/dieu-chinh`, các loại còn lại về `/chuyen-dong`. Đích cũ `/phieu` không
còn là một màn, nên để nguyên là dẫn người dùng vào một cú chuyển hướng.

## 5. Bộ lọc trên bốn màn danh sách

Ô lọc `kind` **biến mất khỏi thanh lọc** ở cả bốn màn - giá trị đã do đường quyết định.
Các ô còn lại giữ nguyên: kho, đối tác, khoảng ngày, sắp xếp.

Hệ quả phải giữ: tham số `kind` trên URL của bốn đường này **không đọc từ query string**.
Một `?kind=xuat` gõ tay vào `/nhap-kho` phải bị bỏ qua, không được đổi nội dung bảng -
nếu không, tiêu đề màn nói một đằng và bảng nói một nẻo.

## 6. Nhãn nhóm nav

Nhóm **"Ghi sổ"** đổi tên thành **"Nghiệp vụ"**. Sau đợt này năm mục trong đó không còn
là chỗ ghi nữa, mà là năm danh sách; giữ tên cũ là để lại một nhãn nói sai.

Nhóm **"Tra cứu"** còn hai mục: Tồn kho, Sổ chuyển động (Sổ phiếu nhập xuất rời khỏi
menu theo mục 3).

## 7. Những chỗ phải sửa theo

Mọi link đang trỏ `/nhap-kho`, `/xuat-kho`, `/chuyen-kho`, `/dieu-chinh` với ý **"lập một
tờ mới"** phải chuyển sang đuôi `/moi`. Đây là chỗ dễ sai nhất của đợt: sau khi đổi, các
đường cũ vẫn hợp lệ nhưng dẫn tới danh sách, nên một link sót lại **không đỏ ở đâu cả** -
nó chỉ lặng lẽ đưa người dùng tới một cái bảng thay vì một cái form.

| File | Chỗ | Ý hiện tại |
|---|---|---|
| `src/app/quy-trinh.ts:44-46` | Ba bước của sơ đồ quy trình | Lập phiếu -> `/moi` |
| `src/modules/inventory/components/movement-record-labels.ts:49,57,66` | Đích của ba loại ghi | Lập -> `/moi` |
| `src/modules/inventory/pages/BalanceListPage.tsx:235` | Đường ra của màn tồn rỗng | Lập -> `/moi` |
| `src/modules/inventory/pages/KhoVanHomePage.tsx:285,347` | Nút hành động và ô quy trình | Lập -> `/moi` |
| `src/modules/inventory/components/MovementRecordForm.tsx:186` | Chuyển giữa hai loại khi đang ghi dở | Giữ chiều ghi -> `/moi` |
| `src/app/ung-dung.ts:219-227` | `duongThuoc` của `inventory` | Thêm các đoạn mới, giữ hai tập không giao nhau |

Danh sách này lấy bằng grep ngày 2026-08-31 trên `origin/main` tại `09dec9a`; bước đầu của
plan phải grep lại, vì các phiên khác vẫn đang thêm màn.

## 8. Không làm trong đợt này

- **Không** thêm cột, ô lọc hay thao tác mới nào cho bốn màn danh sách. Chúng là hai màn
  đã có, đặt sẵn một giá trị lọc.
- **Không** sửa hai màn chi tiết ngoài nút quay lại.
- **Không** đụng backend. Không migration, không endpoint mới.
- **Không** viết ADR mới. Đây là điều hướng của giao diện, không lật một quyết định nền
  nào: [ADR-0043](../../03-decisions/ADR-0043-phieu-nhap-xuat-thuoc-inventory.md) nói phiếu
  thuộc `inventory` và điều đó không đổi.

## 9. Tiêu chí xong

1. Bốn mục nav mở ra bốn màn danh sách, mỗi màn có đúng một nút dẫn tới form của nó.
2. Từ danh sách bấm một dòng ra màn chi tiết; từ chi tiết bấm quay lại về **đúng** danh
   sách theo loại.
3. `/phieu` chuyển hướng sang `/nhap-kho`; không còn mục Sổ phiếu nhập xuất trên menu.
4. Không link nào trong `src/` còn trỏ vào bốn đường cũ với ý "lập một tờ mới" - kiểm
   bằng grep, không bằng mắt.
5. `npm run lint`, `npx vitest run`, `npm run arch` và `kiem-giao-dien.mjs` đều sạch.
6. Bài test khoá hai điều mà mắt không thấy: `?kind=` trên URL của bốn màn bị bỏ qua, và
   nút quay lại của chi tiết đi đúng đích theo từng loại.
