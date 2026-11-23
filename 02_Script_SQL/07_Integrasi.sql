-- =====================================================================
-- 07_Integrasi.sql  | Integrasi Pertemuan 1-6 dalam satu proses penjualan
-- DBMS: MySQL. Urutan: 00_Schema_Dataset_MySQL -> 04 -> 05 -> 06 -> file ini.
-- (Bagian hak akses pada PostgreSQL (02) dicerminkan di MySQL oleh pengecekan peran pegawai
--  di dalam procedure.)
-- =====================================================================
USE electromart;

DROP PROCEDURE IF EXISTS SP_Catat_Penjualan;

DELIMITER $$

-- Procedure pencatatan penjualan (Pertemuan 4) yang memanfaatkan:
--   pengecekan hak akses (P2), function + trigger (P5), dan dipanggil di dalam transaksi (P3).
CREATE PROCEDURE SP_Catat_Penjualan(
    IN p_id_penjualan VARCHAR(10),
    IN p_id_pelanggan VARCHAR(10),
    IN p_id_pegawai   VARCHAR(10),
    IN p_id_produk    VARCHAR(10),
    IN p_jumlah       INT
)
BEGIN
    DECLARE v_berwenang INT DEFAULT 0;
    DECLARE v_header    INT DEFAULT 0;
    DECLARE v_harga     DECIMAL(12,2) DEFAULT NULL;

    -- Langkah 2: hanya role_penjualan / role_admin yang boleh menginput penjualan
    SELECT COUNT(*) INTO v_berwenang
    FROM pegawai
    WHERE id_pegawai = p_id_pegawai AND peran IN ('role_penjualan','role_admin');
    IF v_berwenang = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Akses ditolak: pegawai tidak berwenang menginput penjualan';
    END IF;

    -- Buat header transaksi bila belum ada
    SELECT COUNT(*) INTO v_header FROM penjualan WHERE id_penjualan = p_id_penjualan;
    IF v_header = 0 THEN
        INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai)
        VALUES (p_id_penjualan, p_id_pelanggan, p_id_pegawai);
    END IF;

    -- Harga diambil dari master produk (produk tak terdaftar -> 0, lalu ditolak trigger)
    SELECT harga INTO v_harga FROM produk WHERE id_produk = p_id_produk;

    -- Subtotal, stok, log, total & diskon diproses trigger + function
    INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
    VALUES (p_id_penjualan, p_id_produk, p_jumlah, COALESCE(v_harga, 0), 0);
END$$

DELIMITER ;

-- =====================================================================
-- LANGKAH 1 (Pertemuan 1): Pencarian produk memakai indeks
-- =====================================================================
SHOW INDEX FROM produk;
EXPLAIN SELECT id_produk, nama_produk, harga, stok FROM produk WHERE kategori = 'Audio';
EXPLAIN SELECT * FROM penjualan WHERE id_pelanggan = 'PLG001' AND tanggal >= '2026-11-01';
SELECT id_produk, nama_produk, harga, stok FROM produk WHERE kategori = 'Audio';

-- =====================================================================
-- LANGKAH 2 (Pertemuan 2): Pemeriksaan hak akses pegawai
-- =====================================================================
SELECT id_pegawai, nama_pegawai, peran FROM pegawai;   -- PGW002 = role_penjualan (berwenang)

-- Pegawai gudang (PGW003) mencoba menginput penjualan -> DITOLAK
START TRANSACTION;
CALL SP_Catat_Penjualan('TRX200', 'PLG001', 'PGW003', 'PRD002', 1);   -- ERROR: Akses ditolak
ROLLBACK;
SELECT COUNT(*) AS trx200_tercatat FROM penjualan WHERE id_penjualan = 'TRX200';   -- 0

-- =====================================================================
-- LANGKAH 3 + 4 + 5 (Pertemuan 3, 4, 5): Transaksi berhasil
-- Maya (PGW002) menjual 1 Headphone (4.499.000) + 2 Mouse (500.000) ke Dewi (PLG004)
-- =====================================================================
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD007','PRD002');   -- stok sebelum

START TRANSACTION;
CALL SP_Catat_Penjualan('TRX201', 'PLG004', 'PGW002', 'PRD007', 1);
CALL SP_Catat_Penjualan('TRX201', 'PLG004', 'PGW002', 'PRD002', 2);
COMMIT;

SELECT * FROM penjualan WHERE id_penjualan = 'TRX201';
-- total 4.999.000; diskon 10% = 499.900; bayar 4.499.100 (dihitung function via trigger)
SELECT * FROM detail_penjualan WHERE id_penjualan = 'TRX201';
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD007','PRD002');   -- stok berkurang otomatis
SELECT * FROM log_stok WHERE keterangan LIKE '%TRX201%';                     -- log tercatat otomatis

-- =====================================================================
-- Transaksi gagal di tengah proses: item 1 valid, item 2 melebihi stok -> ROLLBACK semua
-- =====================================================================
START TRANSACTION;
CALL SP_Catat_Penjualan('TRX202', 'PLG005', 'PGW002', 'PRD004', 1);   -- valid
SAVEPOINT setelah_monitor;
CALL SP_Catat_Penjualan('TRX202', 'PLG005', 'PGW002', 'PRD006', 10);  -- ERROR: stok tidak mencukupi (stok 2)
ROLLBACK;   -- membatalkan seluruh TRX202 (termasuk monitor yang tadinya valid)

SELECT COUNT(*) AS trx202_tercatat FROM penjualan WHERE id_penjualan = 'TRX202';   -- 0
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD004','PRD006');          -- stok tidak berubah

-- =====================================================================
-- LANGKAH 6 (Pertemuan 6): Manajemen melihat laporan lewat View
-- =====================================================================
SELECT * FROM View_Transaksi ORDER BY tanggal;
SELECT * FROM View_Laporan_Penjualan ORDER BY periode, kategori;
SELECT * FROM View_Stok_Rendah ORDER BY stok;
SELECT * FROM View_Produk;

-- =====================================================================
-- DOKUMENTASI HUBUNGAN ANTAR KOMPONEN
-- =====================================================================
-- P1 Index       : mempercepat pencarian produk (kategori) dan riwayat transaksi (pelanggan+tanggal)
--                  yang dipakai kasir sebelum menjual dan manajer saat membaca laporan.
-- P2 Hak akses   : hanya pegawai berperan penjualan/admin yang boleh mencatat penjualan
--                  (PostgreSQL: GRANT/REVOKE pada role; MySQL: pengecekan peran di procedure).
-- P3 Transaksi   : seluruh item satu nota dieksekusi atomik; kegagalan satu item membatalkan nota.
-- P4 Procedure   : SP_Catat_Penjualan menyatukan langkah header+detail sehingga SQL tidak ditulis berulang.
-- P5 Function+Trigger : validasi (BEFORE), subtotal/diskon via function, stok & log_stok otomatis (AFTER).
-- P6 View        : manajemen membaca laporan penjualan & stok rendah tanpa akses langsung ke tabel dasar.
