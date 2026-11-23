-- =====================================================================
-- 04_Stored_Procedure.sql  (Pertemuan 4)  | DBMS: MySQL
-- Prasyarat: 00_Schema_Dataset_MySQL.sql (dan opsional 03_Transaksi.sql).
-- Jalankan sebagai script (Alt+X di DBeaver) agar DELIMITER terbaca.
-- =====================================================================
USE electromart;

DROP PROCEDURE IF EXISTS SP_Tampil_Produk;
DROP PROCEDURE IF EXISTS SP_Tambah_Produk;
DROP PROCEDURE IF EXISTS SP_Ubah_Harga;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. SP_Tampil_Produk : menampilkan seluruh data produk
-- ---------------------------------------------------------------------
CREATE PROCEDURE SP_Tampil_Produk()
BEGIN
    SELECT id_produk, nama_produk, kategori, harga, stok
    FROM   produk
    ORDER  BY id_produk;
END$$

-- ---------------------------------------------------------------------
-- 2. SP_Tambah_Produk : menambah produk baru (dengan parameter)
--    Jika stok awal > 0, otomatis dicatat ke log_stok sebagai MASUK.
-- ---------------------------------------------------------------------
CREATE PROCEDURE SP_Tambah_Produk(
    IN p_id_produk   VARCHAR(10),
    IN p_nama_produk VARCHAR(100),
    IN p_kategori    VARCHAR(50),
    IN p_harga       DECIMAL(12,2),
    IN p_stok        INT
)
BEGIN
    IF p_harga IS NULL OR p_harga <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Harga produk harus lebih dari 0';
    END IF;
    IF p_stok IS NULL OR p_stok < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stok awal tidak boleh negatif';
    END IF;

    INSERT INTO produk (id_produk, nama_produk, kategori, harga, stok)
    VALUES (p_id_produk, p_nama_produk, p_kategori, p_harga, p_stok);

    IF p_stok > 0 THEN
        INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
        VALUES (p_id_produk, p_stok, 'MASUK', 'Stok awal produk baru');
    END IF;

    SELECT CONCAT('Produk ', p_id_produk, ' berhasil ditambahkan') AS pesan;
END$$

-- ---------------------------------------------------------------------
-- 3. SP_Ubah_Harga : mengubah harga berdasarkan ID produk dan harga baru
-- ---------------------------------------------------------------------
CREATE PROCEDURE SP_Ubah_Harga(
    IN p_id_produk   VARCHAR(10),
    IN p_harga_baru  DECIMAL(12,2)
)
BEGIN
    IF p_harga_baru IS NULL OR p_harga_baru <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Harga baru harus lebih dari 0';
    END IF;

    UPDATE produk SET harga = p_harga_baru WHERE id_produk = p_id_produk;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Produk tidak ditemukan atau harga tidak berubah';
    END IF;

    SELECT id_produk, nama_produk, harga AS harga_baru FROM produk WHERE id_produk = p_id_produk;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- PENGUJIAN (CALL) - jalankan satu per satu untuk screenshot
-- ---------------------------------------------------------------------
-- Daftar procedure
SHOW PROCEDURE STATUS WHERE Db = 'electromart';

-- Uji SP_Tampil_Produk
CALL SP_Tampil_Produk();

-- Uji SP_Tambah_Produk dengan data berbeda
CALL SP_Tambah_Produk('PRD011', 'Speaker JBL Flip 6',      'Audio',      1999000, 20);
CALL SP_Tambah_Produk('PRD012', 'SSD Samsung 970 EVO 1TB', 'Penyimpanan', 1750000, 15);
CALL SP_Tambah_Produk('PRD013', 'Kabel HDMI 2 Meter',      'Aksesoris',    75000, 0);   -- stok 0 -> tanpa log
CALL SP_Tampil_Produk();                                                               -- bukti produk bertambah
SELECT * FROM log_stok WHERE id_produk IN ('PRD011','PRD012','PRD013');                -- bukti log MASUK

-- Uji tidak valid (harus ditolak) - jalankan terpisah
CALL SP_Tambah_Produk('PRD014', 'Produk Salah', 'Aksesoris', -100, 5);                 -- ERROR harga
CALL SP_Tambah_Produk('PRD001', 'Duplikat',     'Laptop',  1000000, 1);                -- ERROR duplicate key

-- Uji SP_Ubah_Harga dengan data berbeda
SELECT id_produk, nama_produk, harga FROM produk WHERE id_produk IN ('PRD002','PRD008');  -- sebelum
CALL SP_Ubah_Harga('PRD002', 275000);
CALL SP_Ubah_Harga('PRD008', 90000);
SELECT id_produk, nama_produk, harga FROM produk WHERE id_produk IN ('PRD002','PRD008');  -- sesudah (bukti perubahan)
CALL SP_Ubah_Harga('PRD999', 100000);                                                     -- ERROR produk tidak ditemukan

-- Kembalikan harga awal agar dataset konsisten dengan skrip berikutnya
CALL SP_Ubah_Harga('PRD002', 250000);
CALL SP_Ubah_Harga('PRD008', 85000);

-- ---------------------------------------------------------------------
-- DROP PROCEDURE (bukti penguasaan pengelolaan procedure)
-- ---------------------------------------------------------------------
DROP PROCEDURE SP_Tampil_Produk;
SHOW PROCEDURE STATUS WHERE Db = 'electromart' AND Name = 'SP_Tampil_Produk';   -- kosong = sudah terhapus
-- CALL SP_Tampil_Produk();   -- akan ERROR: PROCEDURE does not exist

-- Buat ulang agar sistem tetap lengkap untuk tahap integrasi
DELIMITER $$
CREATE PROCEDURE SP_Tampil_Produk()
BEGIN
    SELECT id_produk, nama_produk, kategori, harga, stok
    FROM   produk
    ORDER  BY id_produk;
END$$
DELIMITER ;
CALL SP_Tampil_Produk();

-- ---------------------------------------------------------------------
-- PENJELASAN FUNGSI
-- ---------------------------------------------------------------------
-- SP_Tampil_Produk : membungkus query SELECT produk agar pegawai cukup CALL, bukan menulis ulang SQL.
-- SP_Tambah_Produk : insert produk via parameter + validasi harga/stok + pencatatan log_stok otomatis.
-- SP_Ubah_Harga    : update harga terkontrol (validasi nilai & keberadaan produk) sehingga
--                    pengubahan harga seragam dan minim salah ketik.
