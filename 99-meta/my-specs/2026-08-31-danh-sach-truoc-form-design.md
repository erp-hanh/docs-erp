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

## 10. Soi bản rc.93 - mười hai thứ thấy được

Soi ngày 2026-08-31 trên `http://103.179.172.110` bằng `qa-admin@erp.test`, phân vùng
`DEFAULT`, bản `v0.1.0-rc.93`. Chụp **toàn trang** ở hai khung: `1366x768` (laptop phổ
biến) và `1920x1080`.

Lần soi đầu chỉ chụp khung `1264x569` và chỉ nhìn phần đầu mỗi màn, nên bỏ sót toàn bộ
nhóm A dưới đây. Ghi lại để lần sau không lặp: **soi giao diện thì chụp toàn trang, và ở
khung hẹp nhất mà người dùng thật dùng**, vì lỗi bố cục hiện ra ở đáy trang và ở khung hẹp.

### A. Vỡ bố cục

| # | Thấy gì | Ở đâu | Nặng |
|---|---|---|---|
| 1 | **Bảng tràn ngang, đẩy cả trang cuộn ngang.** Ở `1366` các cột phải bị cắt mất khỏi khung, không có vùng cuộn riêng cho bảng | `/chuyen-dong` | Nặng |
| 2 | **Hàng "thêm dòng mới" không thẳng cột với đầu bảng.** Ô mặt hàng trải hai cột, một dấu `-` cô độc dưới cột ĐVT, một câu chú thích ba dòng nằm trong cột KHO, hai ô số **không có nhãn**, nút `+` tràn ra ngoài mép bảng | ba màn phiếu | Nặng |
| 3 | **Mọi ô chọn hiện HAI điều khiển chồng nhau**: một ô gõ trống nằm trên một `select` "-- Chọn kho --". Đọc ra là một ô hỏng, không phải một ô tra cứu | ba màn phiếu, `/dieu-chinh` | Nặng |
| 4 | Form một cột hẹp **dán lệch trái**, bỏ trống nguyên nửa phải màn hình | `/dieu-chinh` | Vừa |
| 5 | Ba nút chân form **bó chữ xuống hai dòng** ở khung `1366` ("Ghi phiếu nhập / kho") | ba màn phiếu | Vừa |
| 6 | Ô "Số dòng" **rơi xuống một hàng riêng**, chừa khoảng trắng chết chừng 90px giữa thanh lọc và bảng | `/ton-kho` | Vừa |
| 7 | Ô Giá trị tồn chứa **số cộng một câu cảnh báo hai dòng**, nên dòng đó cao gấp đôi dòng thường - bảng gợn sóng và cột số mất canh | `/ton-kho` | Vừa |
| 8 | Dải đầu trang **chỉ có mỗi tiêu đề**: không mô tả, không nút, một băng trắng cao 60px | `/ton-kho` | Nhẹ |

### B. Chữ và số

| # | Thấy gì | Ở đâu |
|---|---|---|
| 9 | Ô lọc ngày hiện **`mm/dd/yyyy`** trên giao diện tiếng Việt. Người đọc Việt hiểu `08/31` là ngày 8 tháng 31 | `/phieu`, `/chuyen-dong` |
| 10 | Tiền hiện **bốn chữ số thập phân** (`1.794.117,6471`, `14.705,8824`), phá canh cột số | `/ton-kho`, `/chuyen-dong` |
| 11 | Cắt cụt chữ: tên vật tư (`Thep kiem chung gia ...`), và cả **tiêu đề cột** (`ĐƠN GIÁ BÌNH Q...`) | `/chuyen-dong`, `/ton-kho` |
| 12 | **Mã phiếu không phải link** (đường vào chi tiết nằm ở một cột riêng), và **UUID thô** in cạnh tiêu đề màn chi tiết | `/phieu`, `/phieu/:id` |

Mục 12 trái đúng dấu ấn thiết kế đã chốt của hệ: mã là nhân vật chính, mã luôn là link.

### C. Một nhận định phải sửa

Màn `/dieu-chinh` **đã có** một bảng danh sách nằm **dưới** form: hai mươi dòng điều chỉnh
mới nhất, không lọc thêm được, không có trang sau. Nên việc của đợt này ở màn đó là **đảo
thứ tự và cho lọc**, không phải dựng một màn danh sách từ đầu - rẻ hơn hẳn so với ước
lượng ban đầu.

### D. Phạm vi

Nhóm A mục 1, 2, 3 và nhóm B **phải sửa trong đợt này**: chúng nằm đúng trên những màn đợt
này vốn đã phải mở ra sửa, và ba cái đầu là thứ khiến người dùng gọi giao diện là vỡ.

Mục 4, 6, 7, 8 sửa kèm. Mục 5 sửa kèm nếu còn thời gian - nó chỉ xấu, không cản việc.

## 11. Thanh lọc và ô tìm kiếm

Người dùng nói ngày 2026-08-31: các ô lọc và tìm kiếm "trình bày chưa đẹp, nhìn còn thô".
Soi lại thì lý do là cấu trúc chứ không phải màu:

**Không có component thanh lọc dùng chung.** `src/shared/components/` có mười ba component
nhưng **không có `ThanhLoc`**, trong khi mười màn danh sách đều tự dựng một thanh lọc:
`BalanceListPage`, `MovementListPage`, `VoucherListPage`, `StockItemListPage`,
`WarehouseListPage`, `PartnerListPage`, `LenhSanXuatListPage`, `MachineListPage`,
`UserListPage`, `CompanyListPage`. Mười bản chép tay thì mười bản lệch nhau, và không bản
nào chịu trách nhiệm về hình dạng chung.

Ba thứ hỏng cụ thể, đo trên rc.93:

| Thấy gì | Vì sao |
|---|---|
| Ô "Số dòng" **rơi xuống một hàng riêng** ở `/ton-kho`, chừa khoảng trắng chết | Hàng ô lọc tự xuống dòng không kiểm soát, và ô cuối bị đẩy sang hàng mới một mình |
| Mỗi danh mục chiếm **hai ô cạnh nhau** ("Tìm kho" và "Kho") | `ChonDanhMuc` dáng `'loc'` cố ý đặt ô tìm cạnh ô chọn để không cao gấp đôi các ô khác. Đó là một cách né bố cục, và cái giá là người đọc thấy hai trường không liên quan |
| Cùng hình dạng đó ở **dáng `'form'` xếp dọc** thì đọc ra là một ô hỏng, nhân đôi | Một ô gõ trống nằm trên một hộp thả xuống - xem mục 10 nhóm A số 3 |

### Ba việc

**1. Dựng `ThanhLoc` ở `src/shared/components/`.** Một hàng ngang; mọi ô cao bằng nhau;
nhãn nhỏ nằm trên ô; khoảng cách theo `--gian-*`. Ô "Số dòng" và nút "Xoá lọc" neo ở đầu
phải của **chính hàng đó**, không bao giờ rơi xuống một mình. Xuống dòng theo nhóm chứ
không theo từng ô. Nút "Xoá lọc" chỉ hiện khi có ít nhất một ô đang lọc.

**2. Dựng `OTraCuu` thay cặp ô tìm + ô chọn.** Một ô duy nhất: gõ để lọc, danh sách gợi ý
thả xuống ngay dưới, chọn xong ô hiện `mã - tên` kèm nút xoá. Hình dạng này thay
`ChonDanhMuc` ở **cả hai dáng**, nên nó xoá luôn lỗi "ô nhân đôi" ở bốn màn ghi. Sáu trạng
thái mà `ChonDanhMuc` đang giữ (đang tải, danh mục hỏng, chạm trần một trang, không khớp,
vừa bỏ chọn, lỗi của ô) phải giữ nguyên - chúng là phần đắt nhất của component cũ, không
phải phần thừa.

**3. Dựng `ONgay` hiển thị `dd/mm/yyyy`.** `<input type="date">` hiện theo locale của trình
duyệt chứ không theo `lang` của trang, nên không có cách nào ép nó ra `dd/mm` mà vẫn giữ
input gốc. Ô mới: gõ tay theo `dd/mm/yyyy`, kèm nút mở lịch. Đây là thứ duy nhất trong ba
việc phải viết logic mới thay vì gom lại thứ đã có.

### Phạm vi

Đợt này áp cho **sáu màn Kho vận**: ba màn phiếu mới, `/dieu-chinh`, `/ton-kho`,
`/chuyen-dong`, cộng ba màn danh mục `/vat-tu`, `/kho`, `/doi-tac` nếu chúng dùng chung ô
tra cứu.

**Bốn màn ngoài Kho vận** (`MachineListPage`, `UserListPage`, `CompanyListPage`,
`LenhSanXuatListPage`) **để đợt sau**. Chúng không nằm trên đường đi của đợt này, và đổi
mười màn một lượt là một PR không ai soi nổi.

Ghi rõ để không ai tưởng đã xong: sau đợt này hệ sẽ có **hai kiểu thanh lọc cùng tồn tại**
trong vài tuần. Đó là cái giá đã biết và chấp nhận, không phải một chỗ sót.

## 12. Đợt C đã làm, và một nhận định của mục 10 phải sửa

Thi công 2026-08-31, chạy trên `v0.1.0-rc.99`.

### Nhận định sai, và sự thật

Mục 10 nhóm A số 1 viết: *"Bảng tràn ngang, đẩy cả trang cuộn ngang. Ở 1366 các cột phải
bị cắt mất khỏi khung, không có vùng cuộn riêng cho bảng."*

**Sai ở nguyên nhân.** Đo trên dev: `document.scrollWidth === window.innerWidth === 1366` -
trang không hề cuộn ngang, và `<Bang>` đã có `overflow-x: auto` từ trước.

Sự thật là một lỗi khác hẳn, và nặng hơn: **bảng sổ chuyển động đã lên MƯỜI MỘT cột trong
khi CSS còn khai bề rộng cho CHÍN.** Với `table-layout: fixed`, hai cột không được cấp bề
rộng nhận về đúng `0.015625px` - chúng không biến mất mà **bị nghiền nát**, chữ trong chúng
xuống dòng từng ký tự một và đẩy cả hàng cao lên 92px.

Không phép kiểm tự động nào bắt được: `tsc` và `eslint` đều mù với chuyện này, và bài test
đọc DOM cũng vậy vì jsdom không dựng layout. Cảnh báo đó nay nằm ngay trong file CSS.

### Đã sửa

| Sửa gì | Đo được |
|---|---|
| Khai đủ 11 cột, cân lại bề rộng | Hàng **92px -> 49px**; một màn 768px giờ đọc được 13 hàng thay vì 7 |
| Cột số rộng hơn cột chữ cùng cỡ | `-2.205.882,3529` (15 ký tự) hết tràn đè lên cột Ghi chú |
| Câu "Thiếu giá N dòng" nằm **cùng dòng** với con số | Hàng của nó hết cao gấp đôi hàng thường |
| Câu "Không có ghi chú" không xuống hai dòng | Ghi chú THẬT vẫn xuống dòng được - bài test khoá đúng điều đó |
| Nút chân phiếu `white-space: nowrap` | Hết "Ghi phiếu nhập / kho" hai dòng ở 1366 |
| `min-width: max-content` cho bảng trong vùng cuộn | Cột không bị bóp khi bảng hẹp hơn nội dung |

### Hai thứ nhìn như lỗi mà là chủ ý - KHÔNG sửa

- **Dải đầu trang Tồn kho chỉ có tên màn.** Đoạn dẫn đã cố ý chuyển xuống ngay trên bảng,
  có ghi lý do trong code: nó chống một hiểu nhầm về CON SỐ, nên chỗ đúng của nó là cạnh
  cái bảng chứ không phải cạnh cái tên.
- **Form điều chỉnh tồn hẹp 640px, dán lệch trái.** Đó là khuôn form một cột của skill
  `frontend-design-erp`. Đổi sang căn giữa là một quyết định thiết kế cho CẢ hệ, không phải
  một sửa lẻ của màn này - cần quyết riêng.

## 13. Đợt B đã làm

Thi công 2026-08-31, chạy trên `v0.1.0-rc.103`. Đây là phần điều hướng của mục 3-7.

| Đường | Trước | Nay |
|---|---|---|
| `/nhap-kho` | form trắng | danh sách phiếu nhập, nút **Lập phiếu nhập** |
| `/nhap-kho/moi` | không có | form lập phiếu nhập |
| `/xuat-kho`, `/chuyen-kho` | form trắng | như trên, đổi loại |
| `/dieu-chinh` | form trắng | danh sách các lần điều chỉnh, nút **Ghi điều chỉnh** |
| `/dieu-chinh/moi` | không có | form ghi điều chỉnh |
| `/phieu` | màn sổ gộp | **chuyển hướng** sang `/nhap-kho` |
| nhóm nav "Ghi sổ" | 5 mục ghi + 2 sổ | đổi tên **"Nghiệp vụ"**; mục Sổ phiếu rời menu |

Bốn màn danh sách dùng lại `VoucherListPage` / `MovementListPage` với một prop `loaiCoDinh`.
Không màn mới nào được viết, không endpoint nào được thêm.

### Bốn thứ chỉ lộ ra khi soi bản chạy thật

Cả bốn đều xanh ở máy, và cả bốn đều là hệ quả trực tiếp của chính đợt này:

1. Dải chỉ số nói **"Phiếu khớp bộ lọc"** ngay lần đầu mở màn - loại cố định bị tính là
   "đang lọc". Nó là bản chất của màn, không phải phép thu hẹp người dùng vừa đặt.
2. Cột **Loại** chép lại một chữ đã nằm ở tiêu đề màn, hai mươi lần trên hai mươi hàng.
3. Màn Điều chỉnh tồn khi chưa có dòng nào nói **"không có chuyển động nào khớp bộ lọc"**
   kèm nút Bỏ bộ lọc - trách người dùng về một bộ lọc họ không hề đặt. Câu đúng là "Chưa có
   lần điều chỉnh nào", và ở màn này rỗng là chuyện **bình thường**: nó nghĩa là sổ chưa
   lệch lần nào.
4. Tiêu đề màn là **"Điều chỉnh"** trong khi mục nav gọi **"Điều chỉnh tồn"**. Nhãn của một
   ô trong bảng không dùng lại được làm tên một màn hình.

### Còn lại của spec, chưa làm

- Cột "Thao tác" của màn phiếu một loại bị cắt tiêu đề ở khung 1366 (`THAO ...`).
- Ba màn danh mục `/vat-tu`, `/kho`, `/doi-tac` vẫn dùng thanh lọc chép tay - đợt A cố ý
  không đụng tới chúng.
- Bốn màn ngoài Kho vận (Thiết bị, Người dùng, Phân vùng, Lệnh sản xuất) vẫn là thanh lọc cũ.
