-- =====================================================================
-- 06_View.sql  (Pertemuan 6)  | DBMS: MySQL
-- Prasyarat: 00_Schema_Dataset_MySQL.sql (lebih bermakna bila 03/05 sudah dijalankan).
-- =====================================================================
USE electromart;

DROP VIEW IF EXISTS View_Produk;
DROP VIEW IF EXISTS View_Transaksi;
DROP VIEW IF EXISTS View_Laporan_Penjualan;
DROP VIEW IF EXISTS View_Stok_Rendah;
DROP VIEW IF EXISTS View_Produk_Aksesoris;

-- ---------------------------------------------------------------------
-- 1. View satu tabel: informasi produk tanpa atribut internal (stok mentah disembunyikan)
-- ---------------------------------------------------------------------
CREATE VIEW View_Produk AS
SELECT id_produk,
       nama_produk,
       kategori,
       harga,
       CASE WHEN stok = 0 THEN 'Habis'
            WHEN stok < 5 THEN 'Terbatas'
            ELSE 'Tersedia' END AS status_stok
FROM produk;

-- ---------------------------------------------------------------------
-- 2. View JOIN: transaksi beserta nama pelanggan (dan kasir)
-- ---------------------------------------------------------------------
CREATE VIEW View_Transaksi AS
SELECT p.id_penjualan,
       p.tanggal,
       pl.nama_pelanggan,
       pg.nama_pegawai AS kasir,
       p.total_harga,
       p.diskon,
       p.total_bayar
FROM penjualan p
LEFT JOIN pelanggan pl ON pl.id_pelanggan = p.id_pelanggan
LEFT JOIN pegawai   pg ON pg.id_pegawai   = p.id_pegawai;

-- ---------------------------------------------------------------------
-- 3. View agregasi: laporan penjualan per periode (bulan) dan kategori
--    COUNT(), SUM(), GROUP BY + JOIN 3 tabel
-- ---------------------------------------------------------------------
CREATE VIEW View_Laporan_Penjualan AS
SELECT DATE_FORMAT(p.tanggal, '%Y-%m')   AS periode,
       pr.kategori                       AS kategori,
       COUNT(DISTINCT p.id_penjualan)    AS jumlah_transaksi,
       SUM(d.jumlah)                     AS total_unit_terjual,
       SUM(d.subtotal)                   AS total_penjualan
FROM penjualan p
JOIN detail_penjualan d ON d.id_penjualan = p.id_penjualan
JOIN produk pr          ON pr.id_produk   = d.id_produk
GROUP BY DATE_FORMAT(p.tanggal, '%Y-%m'), pr.kategori;

-- ---------------------------------------------------------------------
-- 4. View stok rendah (batas: stok < 5)
-- ---------------------------------------------------------------------
CREATE VIEW View_Stok_Rendah AS
SELECT id_produk, nama_produk, kategori, stok
FROM produk
WHERE stok < 5;

-- ---------------------------------------------------------------------
-- 5. View updatable + WITH CHECK OPTION (hanya kategori Aksesoris)
-- ---------------------------------------------------------------------
CREATE VIEW View_Produk_Aksesoris AS
SELECT id_produk, nama_produk, kategori, harga, stok
FROM produk
WHERE kategori = 'Aksesoris'
WITH CASCADED CHECK OPTION;

-- ---------------------------------------------------------------------
-- PENGUJIAN SELECT
-- ---------------------------------------------------------------------
SHOW FULL TABLES WHERE Table_type = 'VIEW';

SELECT * FROM View_Produk;
SELECT * FROM View_Produk WHERE kategori = 'Aksesoris';
SELECT * FROM View_Transaksi ORDER BY tanggal;                       -- bukti JOIN
SELECT * FROM View_Laporan_Penjualan ORDER BY periode, kategori;     -- bukti agregasi
SELECT periode, SUM(jumlah_transaksi) AS transaksi_kategori, SUM(total_penjualan) AS total_bulan
FROM View_Laporan_Penjualan GROUP BY periode;
SELECT * FROM View_Stok_Rendah ORDER BY stok;

-- Verifikasi silang agregasi terhadap tabel asli
SELECT SUM(subtotal) AS total_semua_detail FROM detail_penjualan;
SELECT SUM(total_penjualan) AS total_dari_view FROM View_Laporan_Penjualan;

-- ---------------------------------------------------------------------
-- PENGUJIAN WITH CHECK OPTION (jalankan satu per satu)
-- ---------------------------------------------------------------------
-- Berhasil: data memenuhi kondisi view (kategori Aksesoris)
INSERT INTO View_Produk_Aksesoris (id_produk, nama_produk, kategori, harga, stok)
VALUES ('PRD020', 'Mousepad Gaming XL', 'Aksesoris', 120000, 30);
SELECT * FROM View_Produk_Aksesoris WHERE id_produk = 'PRD020';

-- Berhasil: update tetap dalam kondisi view
UPDATE View_Produk_Aksesoris SET harga = 130000 WHERE id_produk = 'PRD020';

-- DITOLAK: insert kategori di luar kondisi view
INSERT INTO View_Produk_Aksesoris (id_produk, nama_produk, kategori, harga, stok)
VALUES ('PRD021', 'Laptop Lenovo IdeaPad', 'Laptop', 9000000, 5);
-- ERROR 1369: CHECK OPTION failed 'electromart.View_Produk_Aksesoris'

-- DITOLAK: update yang membuat baris keluar dari kondisi view
UPDATE View_Produk_Aksesoris SET kategori = 'Laptop' WHERE id_produk = 'PRD020';
-- ERROR 1369: CHECK OPTION failed

-- Bersihkan data uji
DELETE FROM produk WHERE id_produk = 'PRD020';

-- ---------------------------------------------------------------------
-- DROP VIEW (salah satu view)
-- ---------------------------------------------------------------------
DROP VIEW View_Produk_Aksesoris;
SHOW FULL TABLES WHERE Table_type = 'VIEW';      -- tersisa 4 view utama

-- ---------------------------------------------------------------------
-- MANFAAT VIEW
-- ---------------------------------------------------------------------
-- Penyederhanaan query : JOIN dan agregasi kompleks disimpan sekali; pengguna cukup
--                        SELECT * FROM View_Laporan_Penjualan.
-- Keamanan data        : View_Produk menyembunyikan stok mentah; View_Transaksi tidak menampilkan
--                        email/alamat pelanggan; manajer cukup diberi akses ke view, bukan tabel dasar.
-- Konsistensi          : definisi laporan seragam untuk semua pengguna.
-- Integritas           : WITH CHECK OPTION mencegah perubahan lewat view yang melanggar kondisi view.
