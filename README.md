# docs-erp

Tài liệu kiến trúc gốc của hệ thống ERP. Đây là nguồn sự thật duy nhất về quy tắc
kiến trúc cho cả ba repo code: `backend-erp`, `frontend-erp`, `infra-erp`.

Tài liệu của từng module **không** nằm ở đây — chúng nằm trong repo code tương ứng
theo nguyên tắc "Documentation follows Code" (ADR-0005).

**Bắt đầu ở [00-START-HERE.md](00-START-HERE.md).**

## Cây thư mục

```text
00-START-HERE.md     # doc dau tien, 5 phut
01-rules/            # RULES  - cai gi bat buoc dung
02-principles/       # PRINCIPLES - suy luan the nao khi Rule khong noi het
03-decisions/        # DECISIONS  - vi sao lai quyet nhu vay (ADR)
04-conventions/      # CONVENTIONS - viet ra the nao, toi tung ky tu
05-templates/        # khuon de copy: ADR, module docs, CLAUDE.md
06-checklists/       # CHECKLISTS - kiem lai bang cach nao
99-meta/specs/       # spec thiet ke va implementation plan cua chinh repo nay
tools/check-ids.ps1  # kiem tinh toan ven cua mang luoi ID
```

Từ `00-` đến `06-` là tài liệu **chuẩn mực**: thứ mọi repo code phải tuân theo, và là
thứ được viện dẫn khi báo một vi phạm.

`99-meta/specs/` là tài liệu **quá trình**: nó ghi lại chính `docs-erp` đã được dựng
lên như thế nào — spec thiết kế và implementation plan của lần dựng nền. Nó mô tả một
thời điểm đã qua, không ràng buộc ai, và không được dùng làm căn cứ khi tranh luận
đúng sai. Cần biết quy tắc hiện hành thì đọc `01-` đến `06-`.

Vì vậy `tools/check-ids.ps1` **cố ý bỏ qua** `99-meta/specs/` (và cả `05-templates/`):
những file đó chứa ví dụ, trích dẫn và ID viết trong ngữ cảnh minh họa, không phải
tham chiếu thật. Quét chúng sẽ sinh ra lỗi giả và làm hỏng giá trị của script.

## Kiểm tính toàn vẹn

```powershell
powershell -ExecutionPolicy Bypass -File tools/check-ids.ps1
```
