-- =====================================================================
-- 05_Function_Trigger.sql  (Pertemuan 5)  | DBMS: MySQL
-- Prasyarat: 00_Schema_Dataset_MySQL.sql. Jalankan sebagai script (Alt+X).
-- Setelah trigger aktif, JANGAN ubah stok manual saat INSERT detail_penjualan
-- (stok & log dikelola otomatis oleh trigger).
-- =====================================================================
USE electromart;

DROP TRIGGER  IF EXISTS validasi_penjualan;
DROP TRIGGER  IF EXISTS update_stok_penjualan;
DROP FUNCTION IF EXISTS hitung_total;
DROP FUNCTION IF EXISTS hitung_diskon;

DELIMITER $$

-- ---------------------------------------------------------------------
-- A. STORED FUNCTION
-- ---------------------------------------------------------------------
-- Total = Harga Satuan x Jumlah
CREATE FUNCTION hitung_total(p_harga DECIMAL(12,2), p_jumlah INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN p_harga * p_jumlah;
END$$

-- Diskon = 10% x Total bila Total >= 1.000.000, selain itu 0
CREATE FUNCTION hitung_diskon(p_total DECIMAL(12,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    IF p_total >= 1000000 THEN
        RETURN p_total * 0.10;
    END IF;
    RETURN 0;
END$$

-- ---------------------------------------------------------------------
-- B. TRIGGER
-- ---------------------------------------------------------------------
-- validasi_penjualan: BEFORE INSERT pada detail_penjualan
-- Memvalidasi produk, jumlah, harga, stok; lalu mengisi subtotal dengan hitung_total().
CREATE TRIGGER validasi_penjualan
BEFORE INSERT ON detail_penjualan
FOR EACH ROW
BEGIN
    DECLARE v_ada  INT DEFAULT 0;
    DECLARE v_stok INT DEFAULT 0;

    SELECT COUNT(*) INTO v_ada FROM produk WHERE id_produk = NEW.id_produk;
    IF v_ada = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validasi gagal: produk tidak terdaftar';
    END IF;

    IF NEW.jumlah IS NULL OR NEW.jumlah <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validasi gagal: jumlah pembelian harus lebih dari 0';
    END IF;

    IF NEW.harga_satuan IS NULL OR NEW.harga_satuan <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validasi gagal: harga satuan harus lebih dari 0';
    END IF;

    SELECT stok INTO v_stok FROM produk WHERE id_produk = NEW.id_produk;
    IF NEW.jumlah > v_stok THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validasi gagal: stok tidak mencukupi';
    END IF;

    SET NEW.subtotal = hitung_total(NEW.harga_satuan, NEW.jumlah);
END$$

-- update_stok_penjualan: AFTER INSERT pada detail_penjualan
-- Mengurangi stok, mencatat log_stok, dan menghitung ulang total/diskon/total_bayar header.
CREATE TRIGGER update_stok_penjualan
AFTER INSERT ON detail_penjualan
FOR EACH ROW
BEGIN
    DECLARE v_total  DECIMAL(12,2);
    DECLARE v_diskon DECIMAL(12,2);

    UPDATE produk SET stok = stok - NEW.jumlah WHERE id_produk = NEW.id_produk;

    INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
    VALUES (NEW.id_produk, -NEW.jumlah, 'KELUAR', CONCAT('Pengurangan stok dari ', NEW.id_penjualan));

    SELECT COALESCE(SUM(subtotal), 0) INTO v_total
    FROM detail_penjualan WHERE id_penjualan = NEW.id_penjualan;

    SET v_diskon = hitung_diskon(v_total);

    UPDATE penjualan
    SET total_harga = v_total,
        diskon      = v_diskon,
        total_bayar = v_total - v_diskon
    WHERE id_penjualan = NEW.id_penjualan;
END$$

DELIMITER ;

SHOW FUNCTION STATUS WHERE Db = 'electromart';
SHOW TRIGGERS;

-- ---------------------------------------------------------------------
-- C. PENGUJIAN FUNCTION (tanpa mengubah data)
-- ---------------------------------------------------------------------
SELECT hitung_total(250000, 2)   AS total_500rb,
       hitung_diskon(500000)     AS diskon_500rb_nol,
       hitung_diskon(999999)     AS diskon_batas_bawah_nol,
       hitung_diskon(1000000)    AS diskon_batas_pas_100rb,
       hitung_diskon(15000000)   AS diskon_15jt_1_5jt;

-- ---------------------------------------------------------------------
-- D. PENGUJIAN TRIGGER
-- Catatan: kondisi awal stok (dataset segar): PRD008=100, PRD010=25, PRD002=50, PRD006=2
-- Jalankan tiap pengujian ERROR secara terpisah (Ctrl+Enter).
-- ---------------------------------------------------------------------
INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai) VALUES
('TRX101','PLG001','PGW002'),   -- uji 1 & 6 (valid, tanpa diskon)
('TRX102','PLG002','PGW002'),   -- uji 5 (diskon)
('TRX103','PLG003','PGW002'),   -- uji batas diskon tepat 1.000.000
('TRX104','PLG004','PGW002');   -- uji data tidak valid (ditolak)

-- (1)+(6) Pembelian jumlah tersedia & TIDAK memenuhi syarat diskon: 5 Flashdisk = 425.000
SELECT id_produk, stok FROM produk WHERE id_produk='PRD008';                 -- sebelum: 100
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX101','PRD008',5,85000,0);                                        -- subtotal diisi trigger
SELECT * FROM detail_penjualan WHERE id_penjualan='TRX101';                  -- subtotal 425000
SELECT * FROM penjualan WHERE id_penjualan='TRX101';                         -- total 425000, diskon 0, bayar 425000
SELECT id_produk, stok FROM produk WHERE id_produk='PRD008';                 -- sesudah: 95
SELECT * FROM log_stok WHERE keterangan='Pengurangan stok dari TRX101';      -- log KELUAR -5

-- (5) Memenuhi syarat diskon: 2 Webcam x 950.000 = 1.900.000 -> diskon 190.000, bayar 1.710.000
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX102','PRD010',2,950000,0);
SELECT * FROM penjualan WHERE id_penjualan='TRX102';
SELECT id_produk, stok FROM produk WHERE id_produk='PRD010';                 -- 25 -> 23
SELECT * FROM log_stok WHERE keterangan='Pengurangan stok dari TRX102';

-- (5b) Batas tepat: 4 Mouse x 250.000 = 1.000.000 -> diskon 100.000 (>= berlaku)
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX103','PRD002',4,250000,0);
SELECT * FROM penjualan WHERE id_penjualan='TRX103';                         -- 1000000 / 100000 / 900000

-- (2) Jumlah melebihi stok: Smart TV stok 2, beli 5  -> DITOLAK
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX104','PRD006',5,8500000,0);        -- ERROR: Validasi gagal: stok tidak mencukupi

-- (3) Jumlah nol dan negatif -> DITOLAK
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX104','PRD002',0,250000,0);         -- ERROR: jumlah harus lebih dari 0
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX104','PRD002',-3,250000,0);        -- ERROR: jumlah harus lebih dari 0

-- (4) Produk tidak terdaftar -> DITOLAK
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX104','PRD999',1,100000,0);         -- ERROR: produk tidak terdaftar

-- Harga tidak valid -> DITOLAK
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX104','PRD002',1,0,0);              -- ERROR: harga satuan harus lebih dari 0

-- Bukti transaksi tidak valid tidak meninggalkan jejak: stok PRD006 tetap 2, TRX104 tanpa detail
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD006','PRD002');
SELECT COUNT(*) AS detail_trx104 FROM detail_penjualan WHERE id_penjualan='TRX104';   -- 0
DELETE FROM penjualan WHERE id_penjualan='TRX104';                                    -- bersihkan header kosong

-- Ringkasan bukti log stok
SELECT * FROM log_stok ORDER BY id_log DESC LIMIT 10;

-- ---------------------------------------------------------------------
-- E. ANALISIS HUBUNGAN FUNCTION, TRIGGER, DAN INTEGRITAS DATA
-- ---------------------------------------------------------------------
-- * Function (hitung_total, hitung_diskon) = satu sumber aturan hitung. Dipanggil trigger,
--   sehingga subtotal/diskon tidak bergantung pada input manual yang bisa salah.
-- * validasi_penjualan (BEFORE) = gerbang integritas: data tidak valid (produk fiktif,
--   jumlah <= 0, harga <= 0, stok kurang) ditolak sebelum disimpan.
-- * update_stok_penjualan (AFTER) = menjaga konsistensi: stok berkurang, log_stok tercatat,
--   dan total/diskon/total_bayar header selalu sinkron dengan detail.
-- * Kombinasi ketiganya membuat proses penjualan otomatis, konsisten, dan dapat diaudit.
