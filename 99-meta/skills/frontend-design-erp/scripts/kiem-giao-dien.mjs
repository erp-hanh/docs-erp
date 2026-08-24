#!/usr/bin/env node
// kiem-giao-dien.mjs - Quet src/ tim nhung vi pham he thiet ke MA MAY BAT DUOC.
//
//   cd frontend-erp
//   node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs
//   node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs --src src
//
// Thoat 0 khi sach, 1 khi co vi pham - de cam vao mot buoc CI sau nay neu muon.
//
// Pham vi co y HEP. Bon nhom duoi day co chung mot tinh chat: chung sai mot cach chac
// chan, va grep bat duoc chung ma khong bao dong gia. Nam trang thai, tro nang, chat
// luong chu - nhung thu quan trong hon - khong nam o day vi may khong doc duoc chung;
// chung o references/checklist.md cho mat nguoi.
//
// Khong dung dependency nao: repo nay chua co, va mot script kiem tra khong phai ly do
// dung dan de them cai dau tien.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const doiSo = process.argv.slice(2);
const goc = layThamSo('--src') ?? 'src';

// File duy nhat duoc phep viet gia tri thô.
const FILE_MIEN_TRU = ['tokens.css'];

// .html co trong danh sach vi mockup trong mockup-erp/ cung phai theo he token - mot ban
// mockup duyet bang gia tri thô thi thu duoc duyet khong phai thu se len man that.
const DUOI_QUET = ['.css', '.ts', '.tsx', '.html'];
const THU_MUC_BO = new Set(['node_modules', 'dist', '.git', 'coverage']);

const LUAT = [
  {
    ma: 'mau-tho',
    mo: 'Mau viet tho - dung token trong tokens.css (references/token.md §1)',
    // #abc / #aabbcc / #aabbccdd, rgb(), rgba(), hsl(), hsla()
    re: /#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?)\s*\(/g,
  },
  {
    ma: 'khoang-cach-tho',
    mo: 'Khoang cach viet tho - dung --gian-* (luoi 4px)',
    // padding/margin/gap/inset... co gia tri px hoac rem. Tha 0 va 1px: 0 khong phai mot
    // lua chon thiet ke, 1px la be day duong vien.
    //
    // Hai lookbehind o dau la de KHONG bat `border-top`, `outline-left`...: chung khai be
    // day duong vien chu khong khai khoang cach, va mot dai 3px tren dinh mot the la mot
    // net ve chu khong phai mot cho hong cua luoi 4px.
    re: /(?<!border-)(?<!outline-)\b(?:padding|margin|gap|row-gap|column-gap|top|right|bottom|left|inset)(?:-(?:top|right|bottom|left|inline|block|x|y))?\s*:\s*[^;{}]*?(?<![\w.-])(?!0px\b)(?!1px\b)\d*\.?\d+(?:px|rem)\b/g,
  },
  {
    ma: 'co-chu-tho',
    mo: 'Co chu viet tho - dung --chu-*',
    // Chi bat px/rem tuyet doi. `em` va `%` la co TUONG DOI voi chu cha (0.9em cho <code>)
    // - do la mot quan he, khong phai mot gia tri lay tu he token.
    re: /\bfont-size\s*:\s*(?![^;{}]*var\()[^;{}]*\b\d*\.?\d+(?:px|rem)\b/g,
  },
  {
    ma: 'tieu-diem-bi-tat',
    mo: 'outline: none ma khong co :focus-visible thay the - khoa cua voi nguoi dung ban phim',
    re: /\boutline\s*:\s*(?:none|0)\b/g,
    // Hop le khi chinh khoi luat do co :focus-visible (co-so.css lam dung nhu vay).
    hopLeToanFile: (noiDung) => noiDung.includes(':focus-visible'),
  },
  {
    ma: 'style-noi-tuyen',
    mo: 'style={{ }} mang mau hoac khoang cach - dua vao *.module.css',
    re: /style=\{\{[^}]*(?:color|background|padding|margin|gap|border|fontSize)[^}]*\}\}/g,
    duoi: ['.tsx'],
  },
  {
    ma: 'emoji-lam-bieu-tuong',
    mo: 'Emoji trong giao dien - dung SVG noi tuyen (references/chu-tren-man-hinh.md)',
    re: /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]/gu,
  },
  {
    ma: 'chuyen-dong-tho',
    mo: 'Thoi luong chuyen dong viet tho - dung --nhip-*',
    re: /\b(?:transition|animation)(?:-duration)?\s*:\s*(?![^;{}]*var\()[^;{}]*\d+m?s/g,
    // Thoi luong ~0 nghia la TAT chuyen dong (khoi prefers-reduced-motion), khong phai
    // mot lua chon nhip do lay ra ngoai he token.
    hopLe: (dong) =>
      (dong.match(/\d*\.?\d+m?s\b/g) ?? []).every((one) => Number.parseFloat(one) <= 0.01),
  },
];

const viPham = [];
let soFile = 0;

for (const duongDan of duyet(goc)) {
  const ten = duongDan.split(sep).pop() ?? '';
  if (FILE_MIEN_TRU.includes(ten)) continue;

  const duoi = ten.slice(ten.lastIndexOf('.'));
  const noiDung = readFileSync(duongDan, 'utf8');
  soFile += 1;

  for (const luat of LUAT) {
    if (luat.duoi && !luat.duoi.includes(duoi)) continue;
    if (luat.hopLeToanFile?.(noiDung)) continue;

    const dongs = noiDung.split(/\r?\n/);
    for (let i = 0; i < dongs.length; i += 1) {
      const dong = dongs[i];
      // Bo qua dong ghi chu: mot vi du mau trong comment khong phai vi pham.
      const catBo = dong.trimStart();
      if (catBo.startsWith('//') || catBo.startsWith('*') || catBo.startsWith('/*')) continue;
      if (luat.hopLe?.(dong)) continue;

      luat.re.lastIndex = 0;
      const khop = dong.match(luat.re);
      if (khop) {
        viPham.push({
          file: relative(process.cwd(), duongDan),
          dong: i + 1,
          ma: luat.ma,
          mo: luat.mo,
          trich: dong.trim().slice(0, 100),
        });
      }
    }
  }
}

if (viPham.length === 0) {
  console.log(`kiem-giao-dien: sach. Da quet ${soFile} file duoi ${goc}/.`);
  console.log('Phan may khong kiem duoc nam o references/checklist.md - muc 2, 6 va 9.');
  process.exit(0);
}

const theoMa = new Map();
for (const v of viPham) {
  if (!theoMa.has(v.ma)) theoMa.set(v.ma, []);
  theoMa.get(v.ma).push(v);
}

console.log(`kiem-giao-dien: ${viPham.length} vi pham trong ${soFile} file.\n`);
for (const [ma, ds] of theoMa) {
  console.log(`[${ma}] ${ds[0].mo}`);
  for (const v of ds) {
    console.log(`  ${v.file}:${v.dong}  ${v.trich}`);
  }
  console.log('');
}
console.log('Doc references/token.md §1 de biet ba ngoai le duy nhat duoc viet gia tri tho.');
process.exit(1);

function* duyet(thuMuc) {
  let muc;
  try {
    muc = readdirSync(thuMuc);
  } catch {
    console.error(`kiem-giao-dien: khong mo duoc thu muc "${thuMuc}".`);
    console.error('Chay lenh nay tu thu muc frontend-erp/, hoac truyen --src <duong-dan>.');
    process.exit(2);
  }

  for (const ten of muc) {
    if (THU_MUC_BO.has(ten)) continue;
    const duongDan = join(thuMuc, ten);
    const thongTin = statSync(duongDan);
    if (thongTin.isDirectory()) {
      yield* duyet(duongDan);
    } else if (DUOI_QUET.includes(ten.slice(ten.lastIndexOf('.')))) {
      // Bo qua file test: chung dung gia tri tho lam du lieu mau, khong phai de hien thi.
      if (ten.includes('.test.')) continue;
      yield duongDan;
    }
  }
}

function layThamSo(ten) {
  const i = doiSo.indexOf(ten);
  return i >= 0 ? doiSo[i + 1] : undefined;
}
