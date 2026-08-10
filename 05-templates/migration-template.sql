-- =====================================================================================
-- KHUNG MIGRATION CHO MOT BANG NGHIEP VU
--
-- Comment trong file nay viet ASCII KHONG DAU co chu dich: PowerShell 5.1 doc file .sql
-- ma hoa UTF-8 khong BOM theo codepage ANSI, nen chuoi tieng Viet co dau se khong khop
-- khi grep, va script kiem se bao oan chinh file da ghi ly do mien.
--
-- CACH DUNG
--   1. Copy khoi UP sang  migrations/<6 chu so>_create_<bang>.up.sql
--   2. Copy khoi DOWN sang migrations/<6 chu so>_create_<bang>.down.sql
--   3. Thay moi <...> bang gia tri that, xoa dong nao khong dung.
--   4. Them ten bang vao truong `tables` cua modules/<ten-module>/module.yaml
--      va them muc vao Database.md cua module - CUNG MOT PR.
--
-- DANH SO: 6 chu so tang dan, KHONG dung timestamp. Hai nhanh cung lay mot so se dung
-- nhau ngay luc merge - do la chu dich, xung dot nhin thay duoc re hon thu tu sai im
-- lang. Doi so mot file CHUA merge khong vi pham gi.
--
-- CAM SUA MIGRATION DA MERGE. Sai thi viet migration moi voi so ke tiep.
--
-- KHOI UP KHONG DUNG "IF NOT EXISTS": no che giau viec migration dang chay tren mot
-- schema lech voi gia dinh cua no, bien mot loi ro rang thanh mot no-op im lang.
-- KHOI DOWN THI DUNG "IF EXISTS", vi down phai chay duoc ca khi up da hong giua chung.
--
-- KHONG tu viet BEGIN/COMMIT: PostgreSQL da boc ca chuoi lenh trong mot transaction
-- ngam, nen moi file migration von da nguyen tu. Ngoai le duy nhat la
-- CREATE INDEX CONCURRENTLY - cau do phai dung MOT MINH trong file rieng cua no.
-- =====================================================================================


-- =====================================================================================
-- UP  ->  migrations/<000xxx>_create_<bang>.up.sql
-- =====================================================================================

-- Nhom bang (ADR-0003): Bang nghiep vu.
-- Bang nghiep vu la mac dinh cua moi bang khong co ten trong ba danh sach mien tru, va
-- no KHONG duoc mien thu gi: co company_id, co du ba cot thoi gian, co du hai cot audit,
-- sinh ban ghi audit khi ghi, va chiu soft delete.
-- Muon nam ngoai mac dinh do thi phai co ADR truoc, khong phai mot comment o day.
CREATE TABLE <bang> (
    -- Thu tu khai cot: id -> company_id -> khoa ngoai -> cot nghiep vu -> cot thoi gian
    -- -> cot audit -> constraint muc bang.
    id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id   UUID          NOT NULL REFERENCES companies(id),

    <doi_tuong>_id UUID        NOT NULL,

    code         TEXT          NOT NULL,
    status       TEXT          NOT NULL DEFAULT '<trang_thai_mac_dinh>',
    -- Tien va so luong can do: NUMERIC(18,4). KHONG BAO GIO dung FLOAT/DOUBLE/REAL/MONEY
    -- - sai so nhi phan tich luy va mot so ke nghin dong se khong can.
    amount       NUMERIC(18,4) NOT NULL DEFAULT 0,
    -- So luong dem chiec: INTEGER. Ty le (thue suat, chiet khau): NUMERIC(9,6).
    quantity     INTEGER       NOT NULL DEFAULT 0,
    -- Thoi diem: TIMESTAMPTZ, khong bao gio TIMESTAMP. Ngay nghiep vu thuan: DATE.
    <su_kien>_at TIMESTAMPTZ   NOT NULL,
    note         TEXT,

    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- deleted_at la cot duy nhat cho NULL: NULL chinh la nghia "chua xoa".
    deleted_at   TIMESTAMPTZ,
    created_by   UUID          NOT NULL,
    -- updated_by la NOT NULL: luc INSERT no nhan dung gia tri cua created_by.
    updated_by   UUID          NOT NULL,

    -- Khoa ngoai khai o muc bang voi ten tuong minh khi can dich loi 23503 ra thong diep
    -- nghiep vu. Khai inline (REFERENCES ngay tren dong cot) van hop le nhung sinh ten
    -- tu dong <table>_<col>_fkey va khong dich duoc loi theo ten constraint.
    CONSTRAINT fk_<bang>_<bang_dich>
        FOREIGN KEY (<doi_tuong>_id) REFERENCES <bang_dich>(id),

    -- Trang thai dung TEXT + CHECK, khong dung ENUM cua PostgreSQL: them mot gia tri vao
    -- ENUM la DDL co khoa, con xoa mot gia tri thi khong co lenh nao lam duoc.
    -- Tap gia tri o day phai khop dung so do trang thai trong Workflow.md.
    CONSTRAINT ck_<bang>_status
        CHECK (status IN ('<trang_thai_1>', '<trang_thai_2>', '<trang_thai_3>')),

    CONSTRAINT ck_<bang>_amount_non_negative
        CHECK (amount >= 0),

    -- Chan do dai bang CHECK thay vi VARCHAR(n): doi gioi han sau nay khong can
    -- ALTER TABLE tren kieu cot.
    CONSTRAINT ck_<bang>_code_length
        CHECK (char_length(code) <= 32)
);

-- Rang buoc duy nhat tren bang co soft delete PHAI la partial unique index.
-- Dung UNIQUE thuong thi mot ma da xoa mem van chiem cho vinh vien: xoa <bang> ma
-- 'PO-001' roi tao lai dung ma do se bao trung voi mot thu nguoi dung vua xoa.
CREATE UNIQUE INDEX uq_<bang>_company_id_code
    ON <bang>(company_id, code) WHERE deleted_at IS NULL;

-- Index composite DAN DAU BANG company_id, khop dung hinh dang WHERE that su chay trong
-- repository. Index don tren (company_id) la index rac: do chon loc gan bang khong nen
-- planner khong dung, ma van ton cho va lam cham moi lan ghi.
CREATE INDEX idx_<bang>_company_id_status ON <bang>(company_id, status);

-- Moi khoa ngoai KHAC company_id phai la cot dan dau cua mot index, hoac la cot thu hai
-- trong index composite mo dau bang company_id. Tren bang nghiep vu, dang thu hai la
-- dang gan nhu luon dung.
CREATE INDEX idx_<bang>_company_id_<doi_tuong>_id ON <bang>(company_id, <doi_tuong>_id);

-- Cot nao xuat hien trong WHERE hoac ORDER BY cua repository - va moi cot mo cho `sort`
-- - phai la cot thu nhat hoac thu hai cua it nhat mot index.
CREATE INDEX idx_<bang>_company_id_<su_kien>_at ON <bang>(company_id, <su_kien>_at);

-- Ten index va constraint theo mau:
--   idx_<table>_<cols>   uq_<table>_<cols>   fk_<table>_<ref_table>   ck_<table>_<mo_ta>
-- <cols> la ten day du cua cac cot, noi bang '_', DUNG THU TU trong index. Khong rut gon:
-- thu tu cot la thong tin quan trong nhat cua mot index composite nen no phai doc duoc
-- ra tu ten. PostgreSQL cat identifier o 63 byte va cat IM LANG; khi ten vuot muc do,
-- rut gon bang cach bo hau to _id khoi phan <cols> va ghi comment ASCII neu bo cot day du.

-- Index di CUNG FILE MIGRATION voi cot no phuc vu, khong doi mot migration "don index"
-- sau nay: tao index luc bang con rong gan nhu mien phi; tao no khi bang da vai trieu
-- dong la mot thao tac van hanh co rui ro, can CREATE INDEX CONCURRENTLY va can nguoi truc.

-- Chi bang thoa CA HAI dieu kien moi duoc mien index: (a) co ten trong reference_tables
-- cua ADR-0003, va (b) khong co khoa ngoai tro toi bang giao dich. Khi duoc mien, ghi
-- comment dung mau ASCII ngay trong file migration:
--   -- index-exempt: <ly do, ASCII khong dau>


-- =====================================================================================
-- DOWN  ->  migrations/<000xxx>_create_<bang>.down.sql
--
-- Down chi co mot viec: dua schema ve dung trang thai truoc khi up chay, lam theo THU TU
-- NGUOC voi up.
--   up tao bang   -> down la DROP TABLE IF EXISTS <bang>;  (index va constraint cua bang
--                    bi xoa theo, khong can liet ke lai)
--   up them cot   -> down la ALTER TABLE ... DROP COLUMN ...
--   up them index -> down la DROP INDEX IF EXISTS <ten_index>;
-- Down lam mat du lieu khong cuu lai duoc thi ghi ngay dau file:
--   -- destructive: rollback lam mat du lieu cot <ten cot>
-- =====================================================================================

DROP TABLE IF EXISTS <bang>;
