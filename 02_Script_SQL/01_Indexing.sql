-- =====================================================================
-- UTS PRAKTIKUM BASIS DATA - ElectroMart
-- 01_Indexing.sql  (Pertemuan 1)  | DBMS: PostgreSQL
-- Cara pakai di DBeaver:
--   1) Jalankan baris CREATE DATABASE di koneksi 'postgres'
--   2) Buat koneksi baru ke database electromart, lalu jalankan sisanya (Alt+X)
-- =====================================================================

--CREATE DATABASE electromart;   -- jalankan dulu, lalu pindah ke DB electromart
--ALTER DATABASE template1 REFRESH COLLATION VERSION;

-- ---------------------------------------------------------------------
-- 1. STRUKTUR TABEL
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS log_stok         CASCADE;
DROP TABLE IF EXISTS detail_penjualan CASCADE;
DROP TABLE IF EXISTS penjualan        CASCADE;
DROP TABLE IF EXISTS pegawai          CASCADE;
DROP TABLE IF EXISTS pelanggan        CASCADE;
DROP TABLE IF EXISTS produk           CASCADE;

CREATE TABLE produk (
    id_produk    VARCHAR(10)   PRIMARY KEY,
    nama_produk  VARCHAR(100)  NOT NULL,
    kategori     VARCHAR(50)   NOT NULL,
    harga        NUMERIC(12,2) NOT NULL,
    stok         INT           NOT NULL DEFAULT 0
);

CREATE TABLE pelanggan (
    id_pelanggan   VARCHAR(10)  PRIMARY KEY,
    nama_pelanggan VARCHAR(100) NOT NULL,
    email          VARCHAR(100) NOT NULL UNIQUE,
    no_hp          VARCHAR(20),
    alamat         TEXT
);

CREATE TABLE pegawai (
    id_pegawai   VARCHAR(10)  PRIMARY KEY,
    nama_pegawai VARCHAR(100) NOT NULL,
    peran        VARCHAR(30)  NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    no_hp        VARCHAR(20)
);

CREATE TABLE penjualan (
    id_penjualan VARCHAR(10)   PRIMARY KEY,
    tanggal      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_pelanggan VARCHAR(10)   REFERENCES pelanggan(id_pelanggan),
    id_pegawai   VARCHAR(10)   REFERENCES pegawai(id_pegawai),
    total_harga  NUMERIC(12,2) NOT NULL DEFAULT 0,
    diskon       NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_bayar  NUMERIC(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE detail_penjualan (
    id_detail    SERIAL        PRIMARY KEY,
    id_penjualan VARCHAR(10)   REFERENCES penjualan(id_penjualan),
    id_produk    VARCHAR(10)   REFERENCES produk(id_produk),
    jumlah       INT           NOT NULL,
    harga_satuan NUMERIC(12,2) NOT NULL,
    subtotal     NUMERIC(12,2) NOT NULL
);

CREATE TABLE log_stok (
    id_log           SERIAL       PRIMARY KEY,
    id_produk        VARCHAR(10)  REFERENCES produk(id_produk),
    jumlah_perubahan INT          NOT NULL,
    tipe_transaksi   VARCHAR(20)  NOT NULL,   -- 'MASUK' / 'KELUAR'
    keterangan       VARCHAR(255),
    tanggal          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 2. DATASET
-- ---------------------------------------------------------------------
INSERT INTO produk (id_produk, nama_produk, kategori, harga, stok) VALUES
('PRD001','Laptop Asus ZenBook 14','Laptop',14500000,15),
('PRD002','Mouse Wireless Logitech M330','Aksesoris',250000,50),
('PRD003','Keyboard Mekanikal Keychron K2','Aksesoris',1200000,3),
('PRD004','Monitor LG 27 Inch IPS','Monitor',3200000,8),
('PRD005','Smartphone Samsung Galaxy S23','Smartphone',12999000,10),
('PRD006','Smart TV Sony 55 Inch 4K','TV',8500000,2),
('PRD007','Headphone Sony WH-1000XM5','Audio',4499000,12),
('PRD008','Flashdisk SanDisk 64GB','Aksesoris',85000,100),
('PRD009','Printer Epson EcoTank L3210','Periferal',2400000,4),
('PRD010','Webcam Logitech C920','Aksesoris',950000,25);

INSERT INTO pelanggan (id_pelanggan, nama_pelanggan, email, no_hp, alamat) VALUES
('PLG001','Budi Santoso','budi.santoso@email.com','085611223344','Jl. Merdeka No. 12, Jakarta'),
('PLG002','Siti Aminah','siti.aminah@email.com','085622334455','Jl. Mawar No. 5, Bandung'),
('PLG003','Rian Hidayat','rian.hidayat@email.com','085633445566','Jl. Pemuda No. 88, Surabaya'),
('PLG004','Dewi Lestari','dewi.lestari@email.com','085644556677','Jl. Diponegoro No. 45, Semarang'),
('PLG005','Ahmad Fauzi','ahmad.fauzi@email.com','085655667788','Jl. Gajah Mada No. 20, Yogyakarta');

INSERT INTO pegawai (id_pegawai, nama_pegawai, peran, email, no_hp) VALUES
('PGW001','Andi Wijaya','role_admin','andi.admin@electromart.com','081234567890'),
('PGW002','Maya Putri','role_penjualan','maya.sales@electromart.com','081234567891'),
('PGW003','Eko Prasetyo','role_gudang','eko.gudang@electromart.com','081234567892'),
('PGW004','Hendra Gunawan','role_manajer','hendra.manager@electromart.com','081234567893');

INSERT INTO penjualan (id_penjualan, tanggal, id_pelanggan, id_pegawai, total_harga, diskon, total_bayar) VALUES
('TRX001','2026-11-01 10:15:00','PLG001','PGW002',15000000,1500000,13500000),
('TRX002','2026-11-03 14:30:00','PLG002','PGW002',850000,0,850000),
('TRX003','2026-11-05 11:00:00','PLG003','PGW002',4400000,440000,3960000),
('TRX004','2026-11-08 16:45:00','PLG004','PGW002',12999000,1299900,11699100);

INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES
('TRX001','PRD001',1,14500000,14500000),
('TRX001','PRD002',2,250000,500000),
('TRX002','PRD008',10,85000,850000),
('TRX003','PRD003',1,1200000,1200000),
('TRX003','PRD004',1,3200000,3200000),
('TRX004','PRD005',1,12999000,12999000);

INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan, tanggal) VALUES
('PRD001',16,'MASUK','Stok awal barang masuk dari distributor','2026-10-25 08:00:00'),
('PRD001',-1,'KELUAR','Pengurangan stok dari TRX001','2026-11-01 10:15:00'),
('PRD002',52,'MASUK','Stok awal barang masuk dari distributor','2026-10-25 08:00:00'),
('PRD002',-2,'KELUAR','Pengurangan stok dari TRX001','2026-11-01 10:15:00'),
('PRD008',110,'MASUK','Stok awal barang masuk dari distributor','2026-10-25 08:00:00'),
('PRD008',-10,'KELUAR','Pengurangan stok dari TRX002','2026-11-03 14:30:00'),
('PRD003',4,'MASUK','Stok awal barang masuk dari distributor','2026-10-25 08:00:00'),
('PRD003',-1,'KELUAR','Pengurangan stok dari TRX003','2026-11-05 11:00:00'),
('PRD004',9,'MASUK','Stok awal barang masuk dari distributor','2026-10-25 08:00:00'),
('PRD004',-1,'KELUAR','Pengurangan stok dari TRX003','2026-11-05 11:00:00'),
('PRD005',11,'MASUK','Stok awal barang masuk dari distributor','2026-10-25 08:00:00'),
('PRD005',-1,'KELUAR','Pengurangan stok dari TRX004','2026-11-08 16:45:00');

-- ---------------------------------------------------------------------
-- 3. INDEXING
-- ---------------------------------------------------------------------
-- Single-column index #1: pencarian produk berdasarkan kategori
CREATE INDEX idx_produk_kategori ON produk (kategori);

-- Single-column index #2: pencarian transaksi berdasarkan tanggal
CREATE INDEX idx_penjualan_tanggal ON penjualan (tanggal);

-- Single-column index #3: mempercepat JOIN detail -> produk (FK tidak otomatis diindeks di PostgreSQL)
CREATE INDEX idx_detail_produk ON detail_penjualan (id_produk);

-- Composite index: pencarian transaksi berdasarkan pelanggan DAN tanggal
CREATE INDEX idx_penjualan_pelanggan_tanggal ON penjualan (id_pelanggan, tanggal);

ANALYZE;

-- ---------------------------------------------------------------------
-- 4. BUKTI PEMERIKSAAN INDEKS (katalog pg_indexes)
-- ---------------------------------------------------------------------
SELECT schemaname, tablename, indexname, indexdef
FROM   pg_indexes
WHERE  schemaname = 'public'
  AND  tablename IN ('produk','penjualan','detail_penjualan')
ORDER  BY tablename, indexname;

-- ---------------------------------------------------------------------
-- 5. BUKTI PENGGUNAAN INDEKS (EXPLAIN)
-- Data masih sedikit sehingga planner cenderung Seq Scan. Untuk demonstrasi,
-- seq scan dimatikan sementara agar terlihat index dipakai.
-- ---------------------------------------------------------------------
SET enable_seqscan = off;

-- (a) produk berdasarkan kategori -> idx_produk_kategori
EXPLAIN SELECT * FROM produk WHERE kategori = 'Aksesoris';

-- (b) transaksi berdasarkan rentang tanggal -> idx_penjualan_tanggal
EXPLAIN SELECT * FROM penjualan
WHERE tanggal BETWEEN '2026-11-01' AND '2026-11-05 23:59:59';

-- (c) transaksi berdasarkan pelanggan + tanggal -> idx_penjualan_pelanggan_tanggal
EXPLAIN SELECT * FROM penjualan
WHERE id_pelanggan = 'PLG001' AND tanggal >= '2026-11-01';

RESET enable_seqscan;

-- ---------------------------------------------------------------------
-- 6. PENJELASAN ALASAN PEMILIHAN INDEKS
-- ---------------------------------------------------------------------
-- * produk.kategori        : kolom filter paling sering untuk katalog/pencarian produk.
-- * penjualan.tanggal      : laporan dan pencarian transaksi biasanya berbasis periode (range).
-- * detail_penjualan.id_produk : kolom JOIN ke produk (laporan per produk/kategori).
-- * Composite (id_pelanggan, tanggal):
--     - id_pelanggan di posisi PERTAMA karena dipakai dengan kondisi kesamaan (=) dan
--       selektivitasnya tinggi (menyempitkan ke riwayat satu pelanggan).
--     - tanggal di posisi KEDUA karena umumnya berupa rentang (>=, BETWEEN), dan kolom
--       range sebaiknya diletakkan setelah kolom equality agar index bisa dipakai penuh,
--       sekaligus hasilnya sudah terurut menurut tanggal.
--     - Aturan leftmost-prefix: index ini juga melayani query hanya dengan id_pelanggan,
--       tetapi tidak efektif untuk query hanya dengan tanggal (sudah ada idx_penjualan_tanggal).
-- * Trade-off: setiap index menambah biaya INSERT/UPDATE dan ruang disk, sehingga hanya
--   kolom yang benar-benar dicari yang diindeks.
