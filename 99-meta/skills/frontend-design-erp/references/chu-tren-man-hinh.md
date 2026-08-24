# Chữ trên màn hình

Chữ là vật liệu thiết kế, không phải phần chú thích thêm vào lúc cuối. Một màn hình bố cục
đẹp mà nhãn viết bằng tên cột database thì vẫn là màn hình khó dùng.

Trước khi viết một dòng chữ nào, hỏi: **màn này cần nói gì, và nói thế nào để người dùng
đi tiếp được?** Chữ tồn tại để việc dễ hiểu hơn, do đó dễ làm hơn. Không phải để lấp chỗ.

## Bốn luật gốc

**1. Gọi tên theo thứ người dùng biết, không theo thứ hệ thống có.**

| Sai | Đúng |
|---|---|
| `unit_id` | Đơn vị tính |
| Bản ghi không hợp lệ | Mã kho đã tồn tại |
| Thực thể vật tư | Vật tư |
| Submit | Lưu vật tư |

**2. Nút nói ra việc nó làm, và tên đó không đổi suốt luồng.**

Nút "Lưu vật tư" → thông báo "Đã lưu vật tư". Nút "Duyệt" → "Đã duyệt". Người dùng học
đường đi trong phần mềm bằng chính những chữ này; đổi tên giữa chừng là xóa mất tấm biển
chỉ đường. Dùng động từ chủ động, không dùng "Gửi", "OK", "Xác nhận" chung chung.

**3. Lỗi nói cách sửa, không xin lỗi, không mơ hồ.**

| Sai | Đúng |
|---|---|
| Có lỗi xảy ra | Mã kho đã tồn tại, chọn mã khác |
| Thao tác thất bại | Không kết nối được tới máy chủ, kiểm tra mạng rồi thử lại |
| Bạn không có quyền | Bạn không có quyền xóa vật tư. Liên hệ quản trị nếu cần quyền này |
| Dữ liệu không hợp lệ | Số lượng phải lớn hơn 0 |

Lỗi viết bằng giọng của phần mềm, không bằng giọng một người: không "Xin lỗi bạn", không
"Rất tiếc". Và luôn kèm mã tra cứu (`request_id`) ở banner cấp màn hình — đó là thứ người
dùng đọc cho tổng đài (R-17).

**4. Màn rỗng là lời mời, không phải thông báo.**

> Chưa có vật tư nào. Tạo vật tư đầu tiên để bắt đầu quản lý tồn kho.
> **[Tạo vật tư mới]**

Phân biệt hai ca rỗng, vì đường ra của chúng khác nhau:

| Ca | Nói gì | Đường ra |
|---|---|---|
| Chưa có dữ liệu bao giờ | "Chưa có vật tư nào" | Tạo mới |
| Có dữ liệu, bộ lọc không khớp | "Không có vật tư nào khớp bộ lọc" | Xóa lọc |

Nói sai ca thứ hai thành ca thứ nhất là làm người dùng tưởng hệ thống mất dữ liệu.

## Quy ước viết

- **Câu bình thường, không viết hoa mỗi chữ.** "Tạo vật tư mới", không "Tạo Vật Tư Mới".
  Chữ hoa toàn bộ chỉ dùng cho nhãn cột bảng (`--chu-xs` + `letter-spacing`).
- **Không dấu chấm cuối nhãn và nhãn nút.** Câu đầy đủ trong banner và mô tả thì có.
- **Số lượng đi với danh từ**: "137 vật tư", không "137 mục", không "137 records".
- **Ngày `dd/MM/yyyy`, giờ `HH:mm`** — ngày thuần thì không kèm `00:00`.
- **Tiền định dạng `vi-VN`**, đơn vị viết sau, và định dạng **từ chuỗi** backend trả về.
- **Không emoji trong giao diện.** Không phải vì nghiêm túc quá — mà vì emoji hiển thị khác
  nhau trên mỗi hệ điều hành, trình đọc màn hình đọc chúng thành những câu kỳ lạ, và chúng
  không đổi màu theo chế độ tối.
- **Mỗi phần tử làm đúng một việc.** Nhãn thì gán nhãn, gợi ý thì minh họa. Đừng để gợi ý
  âm thầm gánh thêm vai của nhãn.
- **Không để một chữ đứng một mình ở dòng cuối.** Chữ mồ côi làm khối chữ trông như bị
  cắt dở, và mắt dừng lại ở đó thay vì đọc tiếp. Hai lớp chống, dùng cả hai:
  `text-wrap: pretty` cho khối chữ, **và** một khoảng trắng không ngắt (`&nbsp;`) giữa hai
  chữ cuối của những dòng ngắn cố định như tên sản phẩm hay khẩu hiệu. Một mình
  `text-wrap` chỉ là **gợi ý** cho thuật toán ngắt dòng, không phải một đảm bảo — và
  trình duyệt chưa hỗ trợ thì nó im lặng bỏ qua.

## Chuyện dấu tiếng Việt

Chữ hiển thị trong repo hiện đang viết **tiếng Việt không dấu** (`Danh sach vat tu`,
`Dang tai...`), thống nhất với ghi chú trong code. Giữ đúng lối đó — đổi nó là một quyết
định của cả repo, không phải thứ sửa kèm trong một PR về giao diện.

Nhưng hãy dựng giao diện sao cho **ngày bỏ luật đó không phải sửa lại CSS**:

- `--dong-vua` 1.45 và `--dong-chat` 1.25 đã tính chỗ cho dấu ăn vào phần trên và phần dưới
  của dòng. Đừng ép chiều cao dòng xuống 1.2 cho "gọn".
- Font stack trong `tokens.css` chọn theo tiêu chí có bộ dấu tiếng Việt đầy đủ. Một font
  web đẹp thiếu `ẫ` sẽ rơi về font thay thế ngay giữa câu.
- Nhãn và nút cần chừa chỗ giãn khoảng **10%** khi thêm dấu — nút vừa khít chữ không dấu sẽ
  vỡ khi có dấu.
- Đừng dùng `text-transform: uppercase` cho chữ tiếng Việt có dấu ngoài nhãn cột: chữ hoa
  có dấu đọc chậm hơn hẳn.

## Mẫu thông điệp hay dùng

| Tình huống | Chữ |
|---|---|
| Đang lưu | `Dang luu...` (trên chính nút, nút bị khóa) |
| Lưu xong | `Da luu vat tu VT-001` |
| Xóa mềm | `Da xoa vat tu VT-001. Cac dong chuyen dong tro toi vat tu nay van con.` |
| Xác nhận xóa | `Xoa vat tu VT-001?` + nút `Xoa vat tu` / `Thoi` |
| 409 | `Du lieu tren man hinh da cu. Tai lai de xem ban moi nhat.` + nút `Tai lai` |
| 403 | `Ban khong co quyen <viec cu the>. Man hinh giu nguyen, khong co gi bi mat.` |
| Mất mạng | `Khong ket noi duoc toi may chu. Kiem tra mang roi thu lai.` |
| Đang tải nền | `Dang cap nhat...` (dải mảnh, không che dữ liệu cũ) |
| Mã tra cứu | `Ma tra cuu: 01HX7...` (cỡ `--chu-xs`, `--mau-chu-mo`, copy được) |

Ba chỗ trong mẫu trên đáng để ý vì chúng đến từ chính luật của hệ này: thông điệp xóa nói
rõ **cái gì ở lại** (xóa mềm, R-18); thông điệp `403` nói rõ **màn hình không mất gì**
(C-TS-06); và mọi lỗi cấp màn hình đều mang **mã tra cứu** (R-17).
