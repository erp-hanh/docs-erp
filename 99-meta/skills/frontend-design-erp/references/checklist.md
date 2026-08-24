# Checklist trước khi mở PR giao diện

Đánh dấu một dòng nghĩa là **đã kiểm thật**, không phải đã đọc qua — cùng tinh thần với
`docs-erp/06-checklists/`.

Chạy phần máy kiểm trước, vì nó rẻ:

```bash
cd frontend-erp
node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs
npm run lint && npm test
```

Checklist này **bổ sung** cho `docs-erp/06-checklists/CL-PR-code-review.md`, không thay thế.

---

## 0. Bố cục và mật độ — đếm, đừng cảm

Mục này đứng đầu vì nó là thứ duy nhất trong cả checklist trả lời được câu "màn này có xấu
không". Sáu dòng dưới đây **đếm được**, nên đừng đánh dấu bằng cảm giác. Mở màn ở cửa sổ cao
900px rồi đếm:

- [ ] Có **dải đầu trang** (`khuon-man-hinh.md` mục 0.1): thẻ có nền và viền, không phải một
      hàng flex trần
- [ ] Hành động chính là **nút**, nằm bên phải dải đầu, và ở **cùng vị trí** với các màn khác
      — không phải một dòng chữ link
- [ ] Dải đầu **cao dưới 80px**: không nhãn phụ, không câu giải thích nghiệp vụ (lời giải
      thích thuộc về màn rỗng). Số đo hiện tại của `TieuDeTrang`: 74px có dòng dữ liệu, 51px
      không có — đo bằng `getBoundingClientRect().height`, gồm cả viền
- [ ] Nội dung đầu tiên bắt đầu **trên y=400px**; nếu thấp hơn thì đếm xem khối nào ở trên nó
      đang không nói gì
- [ ] Bảng hiện **ít nhất 8 dòng** không cần cuộn; nếu ít hơn, xem lại thanh lọc và dải chỉ số
- [ ] Mỗi con số trên màn **gọi tên được** và **không lặp lại ở chỗ thứ hai**

Với bảng, thêm ba dòng nữa:

- [ ] `table-layout: fixed` và mọi `<th>` khai `width` — mở trang 2 xem cột có nhảy chỗ không
- [ ] **Đúng một cột** dùng ô hai dòng; các cột còn lại cắt bằng dấu ba chấm, không tự xuống
      dòng kéo cao cả hàng
- [ ] Cột thao tác canh **phải**

## 1. Token — máy kiểm được

- [ ] Không có mã màu thô (`#rrggbb`, `rgb()`, `hsl()`) ngoài `tokens.css`
- [ ] Mọi khoảng cách đi qua `--gian-*`; `px` còn lại chỉ là `1px` viền
- [ ] Mọi cỡ chữ đi qua `--chu-*`; không có chữ nhỏ hơn 12px
- [ ] Mọi `transition` dùng `--nhip-*` và `--duong-cong`
- [ ] Không `style={{ ... }}` nội tuyến mang màu hoặc khoảng cách
- [ ] Token mới (nếu có) đã thêm bản chế độ tối và đã cập nhật `references/token.md`

## 2. Năm trạng thái — mắt kiểm

Mở màn hình và dựng thật từng ca, đừng suy luận:

- [ ] **Đang tải lần đầu**: khung xương đúng hình dạng, không nhảy khi dữ liệu về
- [ ] **Rỗng**: một câu giải thích + đúng một đường ra; phân biệt "chưa có" với "lọc không khớp"
- [ ] **Lỗi**: thông điệp nói cách sửa + mã tra cứu + nút thử lại (trừ `403`)
- [ ] **Có dữ liệu**: đủ cột, không tràn, không cuộn ngang ở thân trang
- [ ] **Đang làm mới nền**: giữ nguyên dữ liệu cũ, chỉ báo nhẹ — không nhấp về rỗng

## 3. Bảng và số

- [ ] Cột số canh phải, `tabular-nums`
- [ ] Tiền định dạng từ **chuỗi** backend trả về, không ép về `number`
- [ ] Không con số nào do frontend tính rồi gửi lên (R-19)
- [ ] Tổng số trang tính từ `meta.total`, không từ độ dài mảng
- [ ] Cột mã là link sang chi tiết, dính trái khi cuộn ngang
- [ ] Ô rỗng có nghĩa (đã xóa / chưa điền) hiện thành **chữ**, không phải ô trắng

## 4. Form và lỗi

- [ ] Nhãn nằm trên ô; placeholder không thay nhãn
- [ ] Lỗi `422` gắn đúng ô qua `error.fields[].field`, ô sai có `aria-invalid`
- [ ] Field lạ không bị nuốt — đẩy lên banner đầu form
- [ ] `409` mời tải lại; `403` giữ nguyên màn hình, không đăng xuất, không tự thử lại
- [ ] Mọi banner lỗi có `request_id`
- [ ] `Idempotency-Key` sinh lúc mở form với endpoint cần nó
- [ ] Nút Lưu khóa và đổi chữ khi đang gửi

## 5. Quyền

- [ ] Nút bật/tắt theo `allowed_actions`, không theo `role`
- [ ] Không có bảng chuyển trạng thái hardcode ở frontend
- [ ] Nút bị khóa có `lyDoKhoa` (vào `title` và vào chữ chỉ đọc màn hình)
- [ ] Không mục điều hướng nào bị ẩn theo role
- [ ] Màn hình xử lý được `403` tử tế ngay cả khi nút đang hiện

## 6. Trợ năng

- [ ] Đi hết màn bằng **bàn phím**, không dùng chuột: tab đúng thứ tự đọc, vòng tiêu điểm luôn nhìn thấy
- [ ] Không `outline: none` mà thiếu `:focus-visible` thay thế
- [ ] Nút chỉ có biểu tượng đều có `aria-label`
- [ ] Không dùng emoji làm biểu tượng
- [ ] Màu không phải kênh thông tin duy nhất ở bất cứ đâu
- [ ] Tương phản: chữ thường ≥ 4.5:1, chữ ≥ 20px ≥ 3:1, viền ô nhập ≥ 3:1
- [ ] Hộp thoại giữ tiêu điểm bên trong, `Esc` đóng được, đóng xong tiêu điểm về chỗ cũ
- [ ] Bật `prefers-reduced-motion` ở hệ điều hành: không còn chuyển động nào

## 7. Màn hẹp

- [ ] Ở 768px và 1200px: không cuộn ngang ở thân trang
- [ ] Bảng cuộn trong khung riêng của nó
- [ ] Vùng bấm ≥ 44px trên cảm ứng
- [ ] Không tắt zoom

## 8. Chữ

- [ ] Nhãn gọi theo tên người dùng biết, không theo tên field
- [ ] Tên nút giữ nguyên suốt luồng (nút "Lưu" → thông báo "Đã lưu")
- [ ] Lỗi nói cách sửa, không xin lỗi, không mơ hồ
- [ ] Câu bình thường, không viết hoa mỗi chữ
- [ ] **Chữ hiển thị viết tiếng Việt có dấu.** Luật này thắng lối không dấu của code cũ; gặp
      chuỗi không dấu trong vùng mình đang sửa thì sửa luôn, ngoài vùng đó thì để yên

## 9. Đồng nhất — câu hỏi cuối và quan trọng nhất

- [ ] Mở màn cùng khuôn gần nhất đặt **cạnh** màn mới: có chỗ nào lệch nhau không?
- [ ] Mọi thứ mới thêm đều đã có tên trong `bo-component.md` hoặc `khuon-man-hinh.md`
- [ ] Nếu phải phá một luật của skill này: đã ghi lý do vào mô tả PR

Câu hỏi cuối là câu đáng giá nhất. Một màn hình "trông khác các màn khác" là lỗi cần sửa,
không phải một đóng góp — và không có công cụ nào bắt được nó thay bạn.
