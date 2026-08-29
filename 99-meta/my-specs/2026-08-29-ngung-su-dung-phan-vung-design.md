# Thiết kế: "Ngừng sử dụng" phân vùng, tách khỏi xoá

Ngày: 2026-08-29. Trạng thái: chờ duyệt.

Trả món nợ mà [ADR-0019](../../03-decisions/ADR-0019-phan-vung-la-cong-ty.md) mục Mất tự ghi
ra, và là việc số 1 trong ba việc còn nợ của
[bàn giao 2026-08-28](2026-08-28-quan-tri-phan-vung-ban-giao.md).

Quyết định nền sẽ là **ADR-0044**, thay mục 7 của ADR-0019 và cấp phép một câu ghi mới cho
[ADR-0041](../../03-decisions/ADR-0041-duong-ghi-neo-vao-companies-chi-cho-co-quan-tri.md).
ADR đó giữ phần *vì sao*; file này nói *làm gì*.

## 1. Vấn đề

Hôm nay hệ có **một** cách tắt một phân vùng: `deleted_at = now()`. ADR-0019 mục 7 gọi nó là
"vô hiệu hoá", và mục Mất của chính ADR đó đã nói ra cái giá:

> Vô hiệu hoá dùng chính `deleted_at`, nên không có cách nào tách một phân vùng tạm dừng khỏi
> một phân vùng đã bỏ. Giai đoạn một **không có** đường bật lại một phân vùng qua API.

Ba hệ quả đo được hôm nay:

| # | Lỗ | Bằng chứng |
|---|---|---|
| 0 | Chữ trên màn hình nói sai | `CompanyFormPage.tsx:338` viết "Vô hiệu hoá phân vùng" cho một thao tác **không đảo lại được**. Nhãn quyền `nhan_quyen.go:74` cũng vậy. |
| 1 | Không có đường bật lại | Không endpoint nào đặt `deleted_at = NULL`. Muốn bật lại phải chọc thẳng database. |
| 2 | Tạo nhầm thì không dọn được | `DeleteCompany` từ chối khi còn người dùng; từ ADR-0039 mọi phân vùng mới ra đời đã có sẵn một người, và `quan_tri_he_thong` cố ý không cầm `auth.user_delete` (ADR-0031 mục 2). |

## 2. MISA làm gì

Tra ngày 2026-08-29. Hai bản gọi khác tên: **AMIS** là "Ngừng sử dụng" (cặp với "Sử dụng"),
**SME 2023** là "Ngừng theo dõi" (tick trong form Sửa). Lấy chữ của AMIS vì nó gần hệ này hơn.

| Dữ kiện | Nguồn |
|---|---|
| Xoá = bỏ hẳn, **chỉ khi chưa phát sinh dữ liệu**. Ngừng sử dụng = "không ảnh hưởng đến dữ liệu đã phát sinh". | [AMIS - tổng quan danh mục](https://helpact.misa.vn/kb/tong-quan-danh-muc-y-nghia-va-chuc-nang-thiet-lap-tren-he-thong/) |
| Đơn vị đã phát sinh mà bấm xoá thì MISA **tự chuyển thành ngừng theo dõi**, không báo lỗi. | [AMIS nền tảng](https://help.amis.vn/kb/co_cau_to_chuc) |
| Sau khi ngừng: **vẫn nằm trong danh sách** kèm dấu trạng thái; mất khỏi ô chọn khi lập chứng từ mới; còn nguyên trên báo cáo cũ. | [AMIS](https://helpact.misa.vn/kb/tong-quan-danh-muc-y-nghia-va-chuc-nang-thiet-lap-tren-he-thong/) |
| **Bật lại được** bằng chính menu đó ("Sử dụng"). | như trên |
| Khuôn này **dùng lại cho mọi danh mục** - khách hàng, vật tư, kho, tài khoản, cơ cấu tổ chức. Một cờ hai giá trị, đảo được hai chiều. | [AMIS - khai báo danh mục](https://helpact.misa.vn/kb/khai-bao-danh-muc/) |
| Chặn duy nhất: **không ngừng sử dụng được đơn vị cấp Tổng công ty/công ty**. | [AMIS](https://helpact.misa.vn/kb/html_11050100/), [SME 2023](https://helpsme.misa.vn/2023/kb/html_11050100/) |

**Ba chỗ tài liệu MISA không trả lời**, nên hệ này tự quyết và ghi lý do ở mục 4: bộ lọc hiện
đơn vị đã ngừng, số phận người dùng thuộc đơn vị đó, và chữ báo lỗi khi chặn xoá.

**Cắt bớt so với MISA, có lý do:**

- **Không cascade xuống cấp con.** Hệ này chưa có phân vùng nhiều cấp (ADR-0033 chưa làm), nên
  chưa có con để cascade.
- **Không có cửa chặn "cấp Tổng công ty".** Hệ này không có cấp tổ chức; mọi phân vùng ngang
  nhau. Cửa tương đương được đặt ở chỗ khác - xem mục 4.2.
- **Không bắt chước "bấm xoá thì tự chuyển thành ngừng".** Im lặng đổi việc người ta vừa bấm
  là thứ đợt trước đã trả giá hai lần. Hai nút riêng, chữ nói thật.

## 3. Trạng thái sau đợt này

Thêm `companies.is_active`. Ba trạng thái tách bạch:

| `is_active` | `deleted_at` | Nghĩa | Đảo lại được | Chiếm mã |
|---|---|---|---|---|
| `true` | `NULL` | Đang dùng | - | có |
| `false` | `NULL` | **Ngừng sử dụng** | có | **có** |
| bất kỳ | có giá trị | Đã xoá | không | không |

`uq_companies_code` giữ nguyên (`WHERE deleted_at IS NULL`), nên **phân vùng ngừng sử dụng
vẫn chiếm mã**. Cố ý: hai phân vùng cùng mã, một đang chạy một đang ngừng, sẽ làm mọi câu tra
lịch sử theo mã trở nên không đọc được.

## 4. Backend

### 4.1. Migration `000037`

```sql
ALTER TABLE companies ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
```

`DEFAULT true` là trạng thái an toàn theo C-DB: một phân vùng vừa tạo phải dùng được ngay.
Không backfill - mọi phân vùng đang sống đều đang dùng.

**Không index**, và migration phải ghi lý do để người rà R-09 khỏi đi tìm: bảng đếm bằng chục
hàng, cột hai giá trị, không câu nào lọc riêng theo nó.

### 4.2. Một method, một cửa chặn

`CompanyService.DatTrangThaiSuDung(ctx, actor, id string, dangSuDung bool) error`

Một method chứ không hai. Cửa quyền, phép kiểm `laUUID`, phép kiểm tồn tại và transaction
giống hệt nhau ở hai chiều; chỉ audit action rẽ nhánh. Hai method là bốn mươi dòng lặp.

Quyền: **dùng lại `auth.company_delete`**, không thêm mã mới. Chỉ một vai trò
(`quan_tri_he_thong`) cầm mọi `auth.company_*`, nên một mã mới không cấp thêm cho ai và không
chặn thêm ai - nó chỉ tốn hai bài test khoá tập quyền của ADR-0031 mục 5a và bắt đổi tên
`TestQuanTriHeThongCamDuNamQuyenCongTy`. Đổi **nhãn** của mã đó thành "Ngừng sử dụng / xoá
phân vùng" ở `nhan_quyen.go` là đủ để bảng phân quyền nói thật.

Ngày một vai trò được ngừng mà không được xoá, đó là một ADR tách mã - không phải hôm nay.

**Cửa chặn duy nhất, và chỉ ở chiều ngừng:** không ngừng sử dụng phân vùng mà chính actor đang
làm việc (`id == actor.CompanyID`). 409 chứ không 403 - nó nói về **trạng thái** chứ không về
quyền (C-API-05).

Cửa này bắt buộc phải có, và đây là chỗ nó khác `DeleteCompany`. Khối ghi chú ở
`company_service.go:564-574` nói rõ `DeleteCompany` **cố ý không** có cửa "phân vùng đang mở",
vì cửa "còn người dùng" đã bắt trước - actor luôn có một hàng `users` còn sống trong phân vùng
của chính mình. Đường ngừng sử dụng **không có** cửa "còn người dùng", nên tự đá mình ra ngoài
là chuyện xảy ra thật. Đây cũng là thứ gần nhất với cửa "không ngừng được cấp Tổng công ty"
của MISA.

Chiều bật lại không cần cửa đó: không ai đang đứng trong một phân vùng đã ngừng.

### 4.3. Hiệu lực của `is_active = false` - cửa nằm ở chỗ gọi, không ở SQL

Đây là phần rủi ro nhất của đợt, vì hỏng theo cả hai chiều đều **im lặng**: nhét cửa quá rộng
thì mặt quản trị không đọc được phân vùng đã ngừng, tức nút bật lại thành vô dụng; nhét quá
hẹp thì người dùng vẫn vào được một phân vùng đã tắt.

Ba hàm repo, ba cách xử lý khác nhau:

| Hàm repo | Ai gọi | Làm gì |
|---|---|---|
| `ConSong` | `auth_service.go:443` (`POST /auth/refresh`) - **chỉ** đường nghiệp vụ | thêm `AND is_active` vào `companyConSongSQL` |
| `IDByCode` | `auth_service.go:1035` (chọn phân vùng) - **chỉ** đường nghiệp vụ | thêm `AND is_active` vào `selectCompanyIDByCodeSQL` |
| `ByID` | `auth_service.go:876` (đọc hồ sơ) **và năm chỗ ở `company_service.go`** (mặt quản trị) | **không đụng SQL.** Cửa đặt tại chỗ gọi 876. |

`model.Company` mang thêm `IsActive`; `ByID` và câu liệt kê thêm cột đó vào SELECT.

**Hàng `user_companies` giữ nguyên, không gỡ ai.** Ngừng sử dụng phải bật lại được nguyên
trạng; gỡ người là mất dữ liệu không dựng lại được. MISA không nói gì về chỗ này - đây là
quyết của hệ này.

Người đang làm việc trong phân vùng vừa bị ngừng bị đá về màn đăng nhập trong **tối đa một chu
kỳ access token**, đúng như ADR-0019 mục 7 đã chốt cho `deleted_at`. Không đổi gì ở đó.

### 4.4. Nới `DeleteCompany`

Cửa hiện tại (`company_service.go:622`): `SoNguoiDangHoatDong > 0` thì 409.

Cửa mới: cho xoá khi số người đang hoạt động **bằng 0**, hoặc **bằng 1 và người đó chính là
người quản trị của phân vùng** (`is_admin`). Đó là hiện thân của "chưa phát sinh dữ liệu"
trong hệ này - phân vùng chưa ai vào ngoài người ra đời cùng nó.

Xoá thì **soft delete mọi hàng `user_companies` còn sống của phân vùng đó** trong cùng
transaction. Mọi hàng chứ không riêng hàng của người quản trị: `SoNguoiDangHoatDong` lọc
`u.is_active`, nên một tài khoản bị khoá không được đếm nhưng hàng gán của nó vẫn còn - đặc
cách theo "người quản trị" bỏ sót đúng ca đó.

Không đụng hàng `users`. Theo ADR-0034 tài khoản ấy có thể đang ở phân vùng khác, và
`quan_tri_he_thong` cố ý không cầm `auth.user_delete`.

**Hệ quả phải nói ra:** nếu đó là hàng gán duy nhất của họ, tài khoản ấy còn đăng nhập được
nhưng không chọn được phân vùng nào.

**Cửa "ít nhất một người quản trị" của ADR-0039 mục 3 không áp ở đây,** và ADR-0044 phải ghi
rõ điều đó. `GoKhoiPhanVung` và `ThayVaiTro` có cửa ấy vì chúng bỏ một phân vùng đang sống lại
không người chịu trách nhiệm; ở đây phân vùng biến mất nên vế "ít nhất một" không còn đối
tượng. Không ghi thì người soi sau sẽ đọc ra một lỗ hổng - đúng loại nhầm lẫn mà đợt trước bắt
được ở `DeleteUser`.

### 4.5. ADR-0041 phải cấp phép câu ghi thứ hai

ADR-0041 mục 1 chốt cấp phép theo **từng câu**, và đúng một câu được kể tên:
`UserCompanyRepository.DatNguoiQuanTri`. Câu gỡ hàng gán ở mục 4.4 là một `UPDATE
user_companies` neo vào `companies.id` lấy từ path param - **đúng hình dạng đó, câu thứ hai**.

ADR-0044 phải kể tên nó tường minh. Không làm thì đợt này phạm chính luật vừa dựng tuần trước.

Kèm theo, số ngoại lệ R-06 mà việc số 3 của bản bàn giao còn nợ đi từ **ba lên bốn**; danh
sách trắng theo tên hàm của checker tương lai phải có thêm hàm này.

`UPDATE companies SET is_active` thì **không** là ngoại lệ mới: `companies` thuộc `tenant_root`,
vốn được miễn R-06, và `UpdateCompany` với `SoftDelete` đã đi đúng hình dạng đó từ trước.

### 4.6. API

`PUT /companies/:id/active`, body `{"is_active": false}`. Bám khuôn `PUT /companies/:id/admin`
đã có. Mã lỗi mới cho cửa 4.2, đặt tên theo bảng C-API-05 - chốt tên chính xác khi viết plan,
không đoán ở đây.

`GET /companies` trả thêm `is_active` và nhận tham số lọc theo trạng thái.

## 5. Frontend

`CompanyListPage`: thêm cột trạng thái có chip và một bộ lọc. **Mặc định hiện cả hai** - phân
vùng đếm bằng chục chứ không phải nghìn dòng như danh mục vật tư của MISA, nên ẩn đi lợi
không bằng hại. Đây là chỗ MISA không nói.

`CompanyFormPage`: khối "Vô hiệu hoá phân vùng" hiện tại tách thành hai, và chữ "vô hiệu hoá"
biến mất khỏi toàn hệ:

- **Ngừng sử dụng** - đảo lại được. Khi đang ngừng thì chỗ đó là nút **Sử dụng lại**.
- **Xoá phân vùng** - không đảo lại được. Chỉ hiện khi xoá được.

Hai khối phải nói rõ khác biệt bằng chữ, không bằng màu: một cái tạm, một cái vĩnh viễn.

## 6. Bằng chứng phải có

Phép thử đột biến cho từng cửa mới - trả câu SQL hoặc gỡ cửa thì test phải đỏ đúng chỗ.

Bốn bài đáng kể nhất:

1. **Ngừng rồi bật lại, đi trọn hai chiều.** Ngừng sử dụng → `POST /auth/refresh` từ chối; bật
   lại → đăng nhập lại được. Bật lại mới là thứ tách "ngừng sử dụng" khỏi xoá; một bài chỉ đo
   chiều ngừng thì xanh cả khi cột này chỉ là `deleted_at` đội tên khác.
2. **Mặt quản trị vẫn đọc được phân vùng đã ngừng** - cả danh sách lẫn chi tiết. Bài này đỏ
   nếu ai đó nhét `AND is_active` vào `ByID` cho gọn. Không có bài này thì mục 4.3 chỉ là một
   lời hứa.
3. **Ngừng phân vùng đang đứng → 409**, không phải 403 và không phải xanh.
4. **`DeleteCompany` ba nhánh:** hai người → 409; một người **không phải** quản trị → 409;
   đúng một người và là quản trị → xanh, và **mọi** hàng gán còn sống của phân vùng biến mất.
   Ba nhánh vì cửa mới có hai điều kiện chứ không một.

Toàn bộ chạy trên PostgreSQL thật ở VPS dev, không phải `go build`.

Sau khi lên dev: **bấm tay**. Đợt trước 1276 test xanh vẫn để lọt bốn thông điệp câm và hai
câu chồng nhau; bài 2 ở trên là loại lỗi mà chỉ một lần bấm mới thấy.

## 7. Ngoài phạm vi

- Cascade xuống phân vùng con - ADR-0033 chưa làm.
- Áp khuôn "ngừng sử dụng" cho danh mục khác (khách hàng, vật tư, kho) như MISA. Đợt này chỉ
  làm `companies`; khuôn dựng ở đây là thứ các danh mục sau bám theo.
- Việc số 2 và số 3 của bản bàn giao (ADR-0039 mục 4 đi vòng qua đường sửa vai trò; checker
  cho ngoại lệ R-06). Đợt này chỉ **cập nhật con số** ba → bốn ở việc số 3.
- Ba mục Important của bản soi frontend chưa sửa.
