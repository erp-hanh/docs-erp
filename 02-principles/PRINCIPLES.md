# 7 Architecture Principles

Rule trả lời *what must be true*: một mệnh đề Có/Không, nhìn một file hoặc một diff là
kết luận được, không cần biết ngữ cảnh nghiệp vụ. Principle trả lời *how we reason*:
thứ có tradeoff thật, hai lựa chọn đều đúng trong hoàn cảnh khác nhau, và cần người
đọc cân nhắc. Danh sách Rule nằm ở [../01-rules/RULES.md](../01-rules/RULES.md).

Principle **không** thay Rule và **không** nới Rule. Mỗi trang dưới đây bắt buộc chốt
xuống ít nhất một **hard check** — mệnh đề kiểm được, neo vào một Rule hoặc một
Convention cụ thể. Không có hard check thì trang đó chỉ là văn nghị luận, không ai mở
ra lúc đang review PR lúc 5 giờ chiều.

## Thứ tự ưu tiên khi xung đột

```
Rules > Principles > Conventions > existing code
```

Ba hệ quả, lấy từ `00-START-HERE.md`:

- Principle thắng Convention trong một ca cụ thể → **bắt buộc mở issue sửa Convention**.
  Thứ tự ưu tiên là chỉ dẫn tạm thời cho tới khi tầng dưới được sửa cho khớp, không
  phải giấy phép bỏ qua nó.
- Principle có vẻ mâu thuẫn với một Rule → **Rule thắng**, và đó là dấu hiệu trang
  Principle này viết sai. Sửa Principle, không nới Rule.
- Hai Rule mâu thuẫn nhau → dừng lại, hỏi người. Principle không phải chỗ để phân xử
  chuyện đó.

## Bảy trang

| ID | Câu hỏi nó trả lời | Hard check tóm tắt | File |
|---|---|---|---|
| P-TXN | Ai mở transaction, đóng ở đâu, khi nào cần? | `Begin`/`Commit`/`Rollback` chỉ có trong service; repository nhận `DBTX` qua tham số | [P-TXN-transaction-boundary.md](P-TXN-transaction-boundary.md) |
| P-ERR | Lỗi nào wrap, lỗi nào trả client, lỗi nào chỉ log? | Cấm `_ = err`, cấm `panic` ngoài `main`; lỗi ra client phải qua bảng mã trong `shared/errors` | [P-ERR-error-handling.md](P-ERR-error-handling.md) |
| P-TEST | Test cái gì, mock cái gì, bao nhiêu là đủ? | Mọi method public của service có ≥1 test; repository test chạy trên PostgreSQL thật, cấm mock SQL | [P-TEST-testing.md](P-TEST-testing.md) |
| P-IDEM | Thao tác nào bắt buộc idempotent? | POST sinh tiền/kho/chứng từ phải nhận `Idempotency-Key`; mọi event handler dedupe theo `event_id` | [P-IDEM-idempotency.md](P-IDEM-idempotency.md) |
| P-OBS | Đo gì, log ở mức nào? | Mọi handler có trace span; mọi lời gọi ra ngoài tiến trình có metric latency và error count | [P-OBS-observability.md](P-OBS-observability.md) |
| P-CONC | Chỗ nào có tranh chấp, khóa kiểu nào? | Update tồn kho/số dư/số chứng từ phải có `FOR UPDATE` hoặc cột `version`; cấm read-modify-write không khóa | [P-CONC-concurrency.md](P-CONC-concurrency.md) |
| P-EVT | Khi nào chọn event thay vì gọi trực tiếp? | Payload immutable, có `event_id` + `occurred_at` + `company_id`; cấm nhét nguyên entity vào payload | [P-EVT-events.md](P-EVT-events.md) |

## Ba cặp hay bị lẫn với nhau

Đọc trước khi tra, để khỏi mở nhầm trang:

- **P-OBS và R-17.** R-17 truy vết *dữ liệu nghiệp vụ* (ai sửa bản ghi nào, phục vụ
  kiểm toán). P-OBS lo *sức khỏe hệ thống* (latency, error rate, phục vụ vận hành).
  Điểm giao duy nhất là `request_id`/`trace_id`: R-17 sở hữu nó, P-OBS chỉ tiêu thụ.
- **P-EVT và R-05.** R-05 nói *được phép gọi ai* — kiểm được bằng máy, dựa trên
  `allowed_deps` trong `module.yaml`. P-EVT nói *khi nào nên chọn event* dù gọi trực
  tiếp vẫn hợp lệ — judgement, không kiểm được bằng diff.
- **P-IDEM và P-CONC.** P-CONC lo hai request *khác nhau* tranh nhau một hàng dữ liệu.
  P-IDEM lo *cùng một* thao tác được gửi tới hai lần. Khóa hàng không cứu được thao
  tác gửi hai lần, và khóa idempotency không cứu được hai người cùng sửa một bản ghi.
