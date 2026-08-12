# CL-API — Thêm endpoint

**Dùng khi nào:** PR đăng ký một route mới, hoặc đổi hình dạng request/response của một
route đã có. Đổi hình dạng cũng dùng checklist này, vì phần lớn breaking change của API
xảy ra ở đó chứ không ở lúc thêm mới.

**Dùng thế nào:** đi từ trên xuống, đánh dấu từng dòng. Mỗi dòng kết thúc bằng một trường
`Verifies` trong ngoặc, trỏ ngược về Rule hoặc Convention cụ thể — mở ID đó ra đọc là
biết chính xác thứ đang bị kiểm. Rule nằm ở
[../01-rules/RULES.md](../01-rules/RULES.md), quy ước HTTP nằm ở
[../04-conventions/C-API-http.md](../04-conventions/C-API-http.md).

**Đánh dấu một dòng nghĩa là đã kiểm thật, không phải đã đọc qua.** API là hợp đồng công
khai: một endpoint merge sai hình dạng thì sửa nó về sau là breaking change, kể cả khi
hôm nay mới có đúng một client.

---

- [ ] CL-API-01 — Route đăng ký trong `router.Group("/api/v1")` ở composition root, không gõ tiền tố `/api/v1` vào từng route và không đăng ký thẳng trên router gốc (Verifies: R-13, C-API-01, C-API-06)
- [ ] CL-API-02 — Mọi segment của path là danh từ số nhiều kebab-case, không segment nào là động từ; `:id` luôn là UUID; không lồng quá hai tầng tài nguyên (Verifies: R-10, C-API-01)
- [ ] CL-API-03 — Status code khớp tình huống: POST tạo mới trả `201`, DELETE trả `204`, sai hình dạng request trả `422`, xung đột trạng thái trả `409`, bản ghi của công ty khác trả `404` chứ không phải `403` (Verifies: R-10, C-API-02)
- [ ] CL-API-04 — Handler không gọi `c.JSON` với `gin.H{}` hay struct khai tại chỗ; mọi đường ra đi qua hàm của `shared/response` (Verifies: R-11, C-API-03)
- [ ] CL-API-05 — Endpoint list bind đủ `form:"page"`, `form:"page_size"`, `form:"sort"` bằng cách nhúng `ListQuery`, và trả `meta.total`, `meta.page`, `meta.page_size`; không trả mảng trần làm body (Verifies: R-12, C-API-04)
- [ ] CL-API-06 — Giá trị `sort` do client gửi được tra qua map whitelist khai tĩnh ở cấp package trong repository; không có nối chuỗi hay `fmt.Sprintf` đưa `sort` vào SQL; `ORDER BY` có tie-breaker `id` (Verifies: R-12, C-API-04)
- [ ] CL-API-07 — Mọi cột có mặt trong whitelist `sort` là cột thứ nhất hoặc thứ hai của ít nhất một index (Verifies: R-09, C-API-04)
- [ ] CL-API-08 — Lỗi trả về dùng hằng mã lỗi khai trong `shared/errors`, và mã đó có dòng trong bảng mã lỗi; mã mới thì dòng tương ứng đã được thêm trong chính PR này (Verifies: R-11, C-API-05)
- [ ] CL-API-09 — DTO request không có field gắn tag `json:"company_id"` hay `form:"company_id"`, và handler không đọc `c.Param("company_id")`/`c.Query("company_id")`; giá trị đó lấy từ `actor.CompanyID` (Verifies: R-06, C-API-01)
- [ ] CL-API-10 — DTO response không serialize password hash, token, secret hay số CCCD; field nhạy cảm gắn tag `json:"-"`; ngoại lệ cấp hoặc làm mới token đã có dòng trong sổ đăng ký, nêu cả endpoint lẫn tên struct (Verifies: R-16, C-API-07)
- [ ] CL-API-11 — Handler `POST` sinh bút toán tiền, chuyển động kho, hoặc cấp số chứng từ có đọc header `Idempotency-Key`, thiếu header thì trả `422` mã `ERR_COMMON_IDEMPOTENCY_KEY_MISSING`, và endpoint đã có dòng trong bảng 5 của sổ đăng ký (Verifies: C-API-02, C-API-07)
- [ ] CL-API-12 — Endpoint dùng ngoại lệ nào — dạng `/actions/<verb>`, trả file, hay list miễn phân trang — đã có đúng một dòng trong bảng tương ứng của sổ đăng ký, kèm lý do và ngày duyệt (Verifies: R-10, R-11, R-12, C-API-07)
- [ ] CL-API-13 — Response mang header `X-Request-Id`, kể cả endpoint trả file được miễn envelope (Verifies: R-17, C-API-03)
- [ ] CL-API-14 — Handler lấy actor bằng `auth.FromContext(ctx)` rồi truyền xuống service làm tham số thứ hai; handler không chứa so sánh role hay permission, và không đọc header `Authorization` (Verifies: R-14, R-15, C-GO-06)
- [ ] CL-API-15 — Handler truyền `c.Request.Context()` làm tham số đầu tiên khi gọi service, và ghi log bằng logger dẫn xuất từ `ctx` chứ không phải logger toàn cục (Verifies: R-17, C-GO-02)
- [ ] CL-API-16 — Diff không xóa field, không đổi kiểu, không đổi tag `json` của DTO response đang có dưới `/api/v1`, và không thêm field gắn `binding:"required"` vào DTO request đã tồn tại (Verifies: R-13, C-API-06)
- [ ] CL-API-17 — Frontend gọi endpoint này không tự tính rồi gửi lên số tiền, thuế hay tồn kho; nó chỉ gửi đầu vào thô và render lại con số backend trả về (Verifies: R-19, C-TS-05)

---

## Mục dễ quên nhất, và nó không đỏ khi grep

Dòng đăng ký ngoại lệ trong
[../04-conventions/C-API-http.md](../04-conventions/C-API-http.md). Một endpoint dùng
ngoại lệ mà không có tên trong sổ đăng ký là **vi phạm chính Rule đó**, không phải một
thiếu sót giấy tờ — nhưng lệnh grep vẫn xanh, vì thứ nó quét là code chứ không phải sổ.
Đây là chỗ reviewer phải tự kiểm bằng mắt.

Ba việc đi kèm, cùng một PR: thêm endpoint thì thêm dòng; xóa endpoint thì xóa dòng; đổi
lý do miễn thì sửa dòng. Một dòng trỏ tới endpoint không còn tồn tại là một ngoại lệ đang
mở mà không ai canh.

## Ranh giới hay bị làm sai

| Cặp | Phân biệt bằng |
|---|---|
| `400` và `422` | Đã đọc được request hay chưa. JSON hỏng là `400`; đọc được nhưng vi phạm `binding` là `422` |
| `403` và `404` | Bản ghi thuộc công ty khác trả `404`. `403` chỉ dành cho ca có quyền truy cập dữ liệu nhưng không có quyền thao tác |
| `409` và `422` | Có cần đọc database mới biết sai hay không. Sai hình dạng là `422`; sai trạng thái là `409` |
