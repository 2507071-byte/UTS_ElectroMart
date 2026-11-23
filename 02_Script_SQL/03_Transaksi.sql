-- =====================================================================
-- 03_Transaksi.sql  (Pertemuan 3)  | DBMS: MySQL (InnoDB)
-- Prasyarat: jalankan 03_Dataset/00_Schema_Dataset_MySQL.sql terlebih dahulu.
-- Pada tahap ini trigger BELUM dipakai, sehingga stok & log diubah manual di dalam transaksi.
-- =====================================================================
USE electromart;

-- Pastikan trigger Pertemuan 5 tidak aktif (agar stok tidak berkurang dua kali jika file 05 sudah pernah dijalankan)
DROP TRIGGER IF EXISTS validasi_penjualan;
DROP TRIGGER IF EXISTS update_stok_penjualan;

-- Kondisi awal
SELECT id_produk, nama_produk, stok FROM produk WHERE id_produk IN ('PRD001','PRD002','PRD006','PRD008','PRD010');

-- =====================================================================
-- SKENARIO A: Transaksi berhasil (1 Laptop + 2 Mouse) -> COMMIT
-- =====================================================================
START TRANSACTION;

INSERT INTO penjualan (id_penjualan, tanggal, id_pelanggan, id_pegawai, total_harga, diskon, total_bayar)
VALUES ('TRX005', NOW(), 'PLG005', 'PGW002', 15000000, 1500000, 13500000);

INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES
('TRX005', 'PRD001', 1, 14500000, 14500000),
('TRX005', 'PRD002', 2,   250000,   500000);

UPDATE produk SET stok = stok - 1 WHERE id_produk = 'PRD001';
UPDATE produk SET stok = stok - 2 WHERE id_produk = 'PRD002';

INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan) VALUES
('PRD001', -1, 'KELUAR', 'Pengurangan stok dari TRX005'),
('PRD002', -2, 'KELUAR', 'Pengurangan stok dari TRX005');

COMMIT;

-- Bukti skenario A: transaksi tersimpan permanen, stok PRD001 15->14, PRD002 50->48
SELECT * FROM penjualan WHERE id_penjualan = 'TRX005';
SELECT * FROM detail_penjualan WHERE id_penjualan = 'TRX005';
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD001','PRD002');
SELECT * FROM log_stok WHERE keterangan LIKE '%TRX005%';

-- =====================================================================
-- SKENARIO B: Transaksi gagal (jumlah > stok) -> ROLLBACK
-- PRD006 (Smart TV) stok = 2, pelanggan ingin membeli 5 unit.
-- =====================================================================
START TRANSACTION;

INSERT INTO penjualan (id_penjualan, tanggal, id_pelanggan, id_pegawai, total_harga, diskon, total_bayar)
VALUES ('TRX006', NOW(), 'PLG001', 'PGW002', 42500000, 4250000, 38250000);

INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX006', 'PRD006', 5, 8500000, 42500000);

UPDATE produk SET stok = stok - 5 WHERE id_produk = 'PRD006';

-- Pengecekan: stok menjadi negatif (-3) => transaksi TIDAK VALID
SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD006';

ROLLBACK;   -- seluruh perubahan di atas dibatalkan

-- Bukti skenario B: TRX006 tidak ada, stok PRD006 kembali 2
SELECT COUNT(*) AS jumlah_trx006 FROM penjualan WHERE id_penjualan = 'TRX006';          -- 0
SELECT COUNT(*) AS jumlah_detail_trx006 FROM detail_penjualan WHERE id_penjualan = 'TRX006'; -- 0
SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD006';                          -- 2

-- =====================================================================
-- SKENARIO C: Pembatalan sebagian (SAVEPOINT / ROLLBACK TO / RELEASE)
-- Pelanggan PLG003 membeli: 2 Mouse, (Webcam dibatalkan), 3 Flashdisk.
-- =====================================================================
START TRANSACTION;

INSERT INTO penjualan (id_penjualan, tanggal, id_pelanggan, id_pegawai)
VALUES ('TRX007', NOW(), 'PLG003', 'PGW002');

-- Item 1: Mouse x2 (dipertahankan)
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX007', 'PRD002', 2, 250000, 500000);
UPDATE produk SET stok = stok - 2 WHERE id_produk = 'PRD002';
INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
VALUES ('PRD002', -2, 'KELUAR', 'Pengurangan stok dari TRX007');

SAVEPOINT sp_setelah_mouse;

-- Item 2: Webcam x1 (akan dibatalkan)
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX007', 'PRD010', 1, 950000, 950000);
UPDATE produk SET stok = stok - 1 WHERE id_produk = 'PRD010';
INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
VALUES ('PRD010', -1, 'KELUAR', 'Pengurangan stok dari TRX007');

-- Pelanggan membatalkan webcam -> kembali ke savepoint (Mouse tetap ada)
ROLLBACK TO SAVEPOINT sp_setelah_mouse;

-- Item 3: Flashdisk x3 (pengganti)
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
VALUES ('TRX007', 'PRD008', 3, 85000, 255000);
UPDATE produk SET stok = stok - 3 WHERE id_produk = 'PRD008';
INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
VALUES ('PRD008', -3, 'KELUAR', 'Pengurangan stok dari TRX007');

-- Total: 500.000 + 255.000 = 755.000 (< 1 juta, tanpa diskon)
UPDATE penjualan SET total_harga = 755000, diskon = 0, total_bayar = 755000
WHERE id_penjualan = 'TRX007';

RELEASE SAVEPOINT sp_setelah_mouse;   -- savepoint dihapus, transaksi berlanjut
COMMIT;

-- Bukti skenario C:
SELECT * FROM penjualan WHERE id_penjualan = 'TRX007';
SELECT * FROM detail_penjualan WHERE id_penjualan = 'TRX007';   -- hanya PRD002 dan PRD008 (tanpa PRD010)
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD002','PRD008','PRD010'); -- PRD010 tetap 25
SELECT * FROM log_stok WHERE keterangan LIKE '%TRX007%';       -- tidak ada log PRD010

-- Catatan: id_detail pada skenario B/C terlihat melompat karena AUTO_INCREMENT
-- tidak ikut di-rollback; ini perilaku normal InnoDB.

-- =====================================================================
-- ANALISIS ACID
-- =====================================================================
-- Atomicity   : penjualan + detail + update stok + log_stok dieksekusi sebagai satu unit.
--               Skenario B membuktikan semua dibatalkan (ROLLBACK) bila ada kegagalan;
--               skenario C membuktikan pembatalan parsial dengan SAVEPOINT.
-- Consistency : setelah COMMIT, stok produk selaras dengan detail penjualan dan log_stok;
--               stok negatif (skenario B) tidak pernah menjadi data permanen.
-- Isolation   : perubahan sebelum COMMIT tidak terlihat oleh sesi lain (InnoDB default
--               REPEATABLE READ), sehingga tidak ada pembacaan stok setengah jadi.
-- Durability  : setelah COMMIT data tersimpan permanen (redo log InnoDB) walaupun server restart.
