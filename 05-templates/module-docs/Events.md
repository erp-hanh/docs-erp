# `<ten-module>` — Events

> **Khung tài liệu — xóa mọi dòng trích dẫn `>` sau khi điền xong.**
>
> File này liệt kê event module **publish** và event module **subscribe**, kèm schema
> payload của từng cái. Nó là hợp đồng giữa module này và mọi module khác — thứ duy nhất
> hai module được biết về nhau ngoài `api/`.

## 0. Ràng buộc phải giữ khi sửa file này

> **Ba ràng buộc bắt buộc, không cái nào là khuyến nghị:**
>
> 1. **Payload chỉ chứa giá trị nguyên thủy** — chuỗi, số, boolean, thời điểm dạng
>    RFC 3339, và định danh dạng UUID. Không nhúng struct model, không nhúng cả bản ghi,
>    không nhúng thứ chỉ có nghĩa trong module này. Nhúng model vào payload là biến mọi
>    lần đổi cột trong bảng của mình thành một breaking change với mọi consumer.
> 2. **Mọi payload có `event_id`, `occurred_at`, `company_id`.** `event_id` là danh tính
>    của *sự việc* với thế giới bên ngoài, sinh **đúng một lần** lúc service ghi hàng vào
>    `outbox`, và **giữ nguyên qua mọi lần gửi lại**.
> 3. **Handler phải idempotent theo `event_id`.** Relay là **at-least-once**: cùng một
>    event sẽ đến hai lần, và đó là hành vi bình thường chứ không phải sự cố. Handler xử
>    lý lần thứ hai phải cho ra đúng trạng thái như sau lần thứ nhất — không trừ kho hai
>    lần, không ghi bút toán hai lần.
>
> Kèm theo: service **không bao giờ** gọi `bus.Publish`. Nó ghi một dòng `outbox` trong
> cùng transaction với dữ liệu nghiệp vụ rồi dừng lại; relay — package nằm ngoài
> `modules/` — mới là thứ publish ra bus.

## 1. Event module này publish

| Tên event | Khi nào phát | Aggregate | Ai đang subscribe |
|---|---|---|---|
| `<ten-module>.<doi_tuong>.<da_xay_ra>` | <sau khi việc gì commit> | `<doi_tuong>` | `<module_a>`, `<module_b>` |

> Tên event đặt ở **thì quá khứ**: nó mô tả một việc đã xảy ra và đã commit, không phải
> một mệnh lệnh cho người khác. `order.created` là event; `inventory.reserve` là một lời
> gọi đội lốt event, và nếu thật sự cần ra lệnh thì đó là ca gọi đồng bộ qua `api/`.
>
> Cột "Ai đang subscribe" là thông tin tham khảo, cập nhật khi biết — producer không phụ
> thuộc vào nó và **không được** rẽ nhánh theo nó. Giá trị của cột này nằm ở chỗ khác:
> khi định đổi payload, nó cho biết phải đi hỏi ai.

### `<ten-module>.<doi_tuong>.<da_xay_ra>`

**Phát ra khi:** <mô tả chính xác thời điểm, gắn với một transaction cụ thể ở
`Workflow.md`>

**Payload:**

```json
{
  "event_id": "9f1c0a6e-4b2d-4f8a-9c33-2b7d8e5a1f04",
  "occurred_at": "2026-08-10T09:15:00+07:00",
  "company_id": "3a7b1c22-88ef-4d10-b0a5-6c9e2f4d7a81",
  "<doi_tuong>_id": "5c2e9b41-7a63-4f92-8d15-0e4a6b3c9d27",
  "<truong_nghiep_vu>": "<giá trị nguyên thủy>",
  "<so_tien>": "15750000.0000"
}
```

| Field | Kiểu | Bắt buộc | Ý nghĩa |
|---|---|---|---|
| `event_id` | UUID | Có | Khóa dedupe phía consumer |
| `occurred_at` | RFC 3339 | Có | Thời điểm sự việc nghiệp vụ xảy ra |
| `company_id` | UUID | Có | Tenant của sự việc |
| `<doi_tuong>_id` | UUID | Có | Bản ghi bị tác động |
| `<truong_nghiep_vu>` | <string / number / bool> | <...> | <...> |
| `<so_tien>` | string | <...> | Tiền là **chuỗi**, không phải số JSON |

> Tiền tuần tự hóa thành chuỗi vì cột là `NUMERIC(18,4)`; đưa nó qua số JSON là đưa nó
> qua `double` và trả lại đúng sai số mà `NUMERIC` sinh ra để tránh.

**Đổi payload thì sao:** thêm field optional là an toàn. Xóa field, đổi kiểu, đổi ngữ
nghĩa của một field đang có là **breaking change** với mọi consumer — phát một tên event
mới song song và giữ tên cũ cho tới khi mọi consumer chuyển xong.

## 2. Event module này subscribe

| Tên event | Của module | Handler | Xử lý xong thì làm gì |
|---|---|---|---|
| `<module_khac>.<doi_tuong>.<da_xay_ra>` | `<module_khac>` | `<TenHandler>` | <...> |

### `<module_khac>.<doi_tuong>.<da_xay_ra>`

**Nhận để làm gì:** <một câu>

**Cách bảo đảm idempotent:** <nêu cơ chế cụ thể, ví dụ: ghi `event_id` vào
`idempotency_keys` trong cùng transaction với hiệu ứng; gặp lại `event_id` đã có thì bỏ
qua và coi như thành công>

> Mục này không được để trống và không nhận câu trả lời "handler này chạy hai lần cũng
> không sao". Nếu đúng là không sao thì viết ra **vì sao** — ví dụ thao tác là gán một
> giá trị cố định chứ không phải cộng dồn. Một câu khẳng định không có lý do là chỗ mà
> sáu tháng sau người ta thêm một phép cộng dồn vào.

**Xử lý thất bại:** <retry bao nhiêu lần, sau đó đi đâu, ai được báo>

**Thứ handler này KHÔNG được làm:** gọi ngược lại module đã phát event trong cùng luồng
xử lý — đó là biến một quan hệ bất đồng bộ thành một vòng phụ thuộc.

## 3. Event module này cố ý KHÔNG phát

| Việc | Vì sao không phát event |
|---|---|
| `<...>` | <ví dụ: không ai cần biết, và một event không có consumer là một hợp đồng phải giữ mà không đổi lại được gì> |

> Mục này ngắn nhưng đáng có: nó chặn xu hướng phát event cho mọi thứ "để sau này dùng".
> Mỗi event đã phát là một hợp đồng công khai, và hợp đồng không có ai ký vẫn phải giữ.
