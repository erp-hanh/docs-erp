# Sao lưu skill

## Bản nào là bản thật

Bản **đang chạy** nằm ở `erp/.claude/skills/frontend-design-erp/`. Đó là chỗ duy nhất
Claude nạp skill, đường dẫn đó không đổi được. Sửa skill là sửa ở đó.

Thư mục này là **bản sao lưu có version**, chỉ để cứu khi mất máy. Nó không được nạp,
không có tác dụng gì lúc chạy.

## Nó sẽ lệch dần

Vì là bản chép tay chứ không phải symlink hay submodule, hai bên **chắc chắn lệch** nếu
không ai chép lại. Đừng tin thư mục này là bản mới nhất; luôn đối chiếu với
`erp/.claude/skills/` trước khi lấy làm căn cứ.

## Quy tắc chống lệch

Sửa skill xong thì chép lại sang đây **trong cùng một đợt việc**, commit chung với việc
đã làm — đừng để sang phiên sau:

```sh
cd erp/docs-erp
rm -rf 99-meta/skills/frontend-design-erp                 # cp đè không xoá file đã bị
cp -r ../.claude/skills/frontend-design-erp 99-meta/skills/   # xoá hay đổi tên bên gốc
git add 99-meta/skills/frontend-design-erp
```

## Khôi phục khi mất máy

```sh
git clone https://github.com/erp-hanh/docs-erp.git
mkdir -p erp/.claude/skills
cp -r docs-erp/99-meta/skills/frontend-design-erp erp/.claude/skills/
```

Mockup nằm ở `../mockups/`, chép ngược về `erp/mockup-erp/` theo cùng cách. Thẻ `<link>`
trong mockup trỏ ra `../frontend-erp/src/shared/styles/`, nên chỉ mở đúng màu khi file đã
nằm ở `erp/mockup-erp/`.
