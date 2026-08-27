# Domain Docs

Cách các skill engineering đọc tài liệu nghiệp vụ của hệ ERP.

## Đọc trước khi khám phá code

- `docs-erp/CONTEXT.md`: bảng thuật ngữ.
- `docs-erp/03-decisions/ADR-NNNN-*.md`: đọc ADR chạm tới vùng sắp làm.
  Hiện có ADR-0001 tới ADR-0015.
- `docs-erp/01-rules/RULES.md`, `docs-erp/02-principles/P-*.md`,
  `docs-erp/04-conventions/C-*.md`: luật, nguyên tắc, quy ước bắt buộc.

Thiếu file nào thì đi tiếp im lặng, đừng báo thiếu, đừng đòi tạo trước.

## ADR ghi ở đâu

**Ghi vào `docs-erp/03-decisions/`, không tạo `docs/` hay `docs/adr/` ở gốc `erp`.**

Đánh số tiếp theo dãy đang có: ADR mới là ADR-0016. Tên file
`ADR-NNNN-<slug-khong-dau>.md`. `docs-erp/tools/check-ids.ps1` canh dãy ID
này và chạy trong CI của docs-erp; ADR nằm ngoài thư mục đó sẽ lọt khỏi
phép canh.

PR chạm cả ADR/RULES.md lẫn code phải merge docs-erp trước.

## Dùng đúng từ trong bảng thuật ngữ

Khi output gọi tên một khái niệm nghiệp vụ, dùng đúng từ đã chốt trong
`docs-erp/CONTEXT.md`. Chữ tiếng Việt phải có dấu.

Khái niệm chưa có trong bảng là một tín hiệu: hoặc đang bịa từ dự án không
dùng (nghĩ lại), hoặc đúng là lỗ hổng (ghi lại cho `/domain-modeling`).

## Báo khi chọi ADR

Nếu output mâu thuẫn với một ADR đang có, nói thẳng ra thay vì lặng lẽ đè:

> Chọi ADR-0009 (business rule chỉ ở backend), nhưng đáng mở lại vì...
