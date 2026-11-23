-- =====================================================================
-- 02_Hak_Akses.sql  (Pertemuan 2)  | DBMS: PostgreSQL
-- Jalankan di database electromart (setelah 01_Indexing.sql) sebagai superuser (postgres).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. BERSIHKAN (agar script bisa dijalankan ulang)
-- ---------------------------------------------------------------------
DO $$
DECLARE r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['user_admin','user_maya','user_eko','user_hendra',
                             'role_admin','role_penjualan','role_gudang','role_manajer']
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 1. CREATE ROLE (group role, tidak bisa login)
-- ---------------------------------------------------------------------
CREATE ROLE role_admin     NOLOGIN;
CREATE ROLE role_penjualan NOLOGIN;
CREATE ROLE role_gudang    NOLOGIN;
CREATE ROLE role_manajer   NOLOGIN;

-- ---------------------------------------------------------------------
-- 2. PRINCIPLE OF LEAST PRIVILEGE: cabut hak default PUBLIC
-- ---------------------------------------------------------------------
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
GRANT  USAGE ON SCHEMA public TO role_admin, role_penjualan, role_gudang, role_manajer;

-- ---------------------------------------------------------------------
-- 3. GRANT
-- ---------------------------------------------------------------------
-- role_admin: seluruh objek dan data
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_admin;
GRANT CREATE ON SCHEMA public TO role_admin;

-- role_penjualan: lihat produk & pelanggan, input transaksi
GRANT SELECT ON produk, pelanggan TO role_penjualan;
GRANT SELECT, INSERT, UPDATE, DELETE ON penjualan TO role_penjualan;   -- sengaja diberi luas dulu, lalu di-REVOKE (bagian 4)
GRANT SELECT, INSERT ON detail_penjualan TO role_penjualan;
GRANT USAGE, SELECT ON SEQUENCE detail_penjualan_id_detail_seq TO role_penjualan;

-- role_gudang: lihat produk, update stok saja (hanya kolom stok), catat log stok
GRANT SELECT ON produk TO role_gudang;
GRANT UPDATE (stok) ON produk TO role_gudang;
GRANT SELECT, INSERT ON log_stok TO role_gudang;
GRANT USAGE, SELECT ON SEQUENCE log_stok_id_log_seq TO role_gudang;

-- role_manajer: baca produk dan data penjualan (laporan)
GRANT SELECT ON produk, penjualan, detail_penjualan TO role_manajer;

-- ---------------------------------------------------------------------
-- 4. REVOKE
-- ---------------------------------------------------------------------
-- Pegawai penjualan tidak boleh mengubah/menghapus transaksi yang sudah tercatat
REVOKE UPDATE, DELETE ON penjualan FROM role_penjualan;
-- Pegawai penjualan tidak boleh menyentuh log stok (eksplisit)
REVOKE ALL ON log_stok FROM role_penjualan;
-- Gudang tidak boleh mengubah harga (hanya kolom stok yang boleh diupdate)
REVOKE UPDATE (harga) ON produk FROM role_gudang;

-- ---------------------------------------------------------------------
-- 5. BUAT USER DAN HUBUNGKAN DENGAN ROLE
-- ---------------------------------------------------------------------
CREATE USER user_admin  WITH PASSWORD 'Admin#123';
CREATE USER user_maya   WITH PASSWORD 'Maya#123';     -- PGW002 role_penjualan
CREATE USER user_eko    WITH PASSWORD 'Eko#123';      -- PGW003 role_gudang
CREATE USER user_hendra WITH PASSWORD 'Hendra#123';   -- PGW004 role_manajer

GRANT role_admin     TO user_admin;
GRANT role_penjualan TO user_maya;
GRANT role_gudang    TO user_eko;
GRANT role_manajer   TO user_hendra;

-- ---------------------------------------------------------------------
-- 6. PENGUJIAN HAK AKSES
-- Cara: SET ROLE <user>; jalankan SATU PER SATU (Ctrl+Enter) agar error tidak
-- menghentikan skrip. Akhiri dengan RESET ROLE;
-- ---------------------------------------------------------------------

-- 6.1 Matriks hak akses (tidak menimbulkan error, cocok untuk screenshot)
SELECT u.usr AS "user", t.tbl AS tabel,
       has_table_privilege(u.usr, t.tbl, 'SELECT') AS "select",
       has_table_privilege(u.usr, t.tbl, 'INSERT') AS "insert",
       has_table_privilege(u.usr, t.tbl, 'UPDATE') AS "update",
       has_table_privilege(u.usr, t.tbl, 'DELETE') AS "delete"
FROM (VALUES ('user_admin'),('user_maya'),('user_eko'),('user_hendra')) AS u(usr)
CROSS JOIN (VALUES ('produk'),('pelanggan'),('pegawai'),('penjualan'),('detail_penjualan'),('log_stok')) AS t(tbl)
ORDER BY u.usr, t.tbl;

-- 6.2 user_maya (role_penjualan)
SET ROLE user_maya;
SELECT * FROM produk;                                   -- BERHASIL
SELECT * FROM pelanggan;                                -- BERHASIL
INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai)
VALUES ('TRXTST1','PLG001','PGW002');                   -- BERHASIL (input transaksi)
ALTER TABLE produk ADD COLUMN catatan TEXT;             -- DITOLAK: must be owner of table produk
SELECT * FROM log_stok;                                 -- DITOLAK: permission denied for table log_stok
UPDATE penjualan SET diskon = 0 WHERE id_penjualan='TRXTST1'; -- DITOLAK (sudah di-REVOKE)
DELETE FROM penjualan WHERE id_penjualan='TRXTST1';     -- DITOLAK (sudah di-REVOKE)
RESET ROLE;
DELETE FROM penjualan WHERE id_penjualan='TRXTST1';     -- pembersihan oleh superuser

-- 6.3 user_eko (role_gudang)
SET ROLE user_eko;
SELECT id_produk, nama_produk, stok FROM produk;        -- BERHASIL
UPDATE produk SET stok = stok + 10 WHERE id_produk='PRD003'; -- BERHASIL (update stok)
INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
VALUES ('PRD003', 10, 'MASUK', 'Restock dari distributor');  -- BERHASIL
UPDATE produk SET harga = 1 WHERE id_produk='PRD003';   -- DITOLAK: permission denied for table produk (kolom harga)
DELETE FROM produk WHERE id_produk='PRD003';            -- DITOLAK
SELECT * FROM penjualan;                                -- DITOLAK
RESET ROLE;
-- kembalikan data uji
UPDATE produk SET stok = stok - 10 WHERE id_produk='PRD003';
DELETE FROM log_stok WHERE keterangan = 'Restock dari distributor';

-- 6.4 user_hendra (role_manajer)
SET ROLE user_hendra;
SELECT * FROM produk;                                   -- BERHASIL
SELECT * FROM penjualan;                                -- BERHASIL
SELECT * FROM detail_penjualan;                         -- BERHASIL
INSERT INTO penjualan (id_penjualan) VALUES ('TRXTST2');-- DITOLAK
UPDATE produk SET stok = 0;                             -- DITOLAK
SELECT * FROM log_stok;                                 -- DITOLAK
RESET ROLE;

-- 6.5 user_admin (role_admin)
SET ROLE user_admin;
SELECT COUNT(*) FROM log_stok;                          -- BERHASIL
CREATE TABLE tes_admin (id INT);                        -- BERHASIL
DROP TABLE tes_admin;                                   -- BERHASIL
RESET ROLE;

-- ---------------------------------------------------------------------
-- 7. PENERAPAN PRINCIPLE OF LEAST PRIVILEGE
-- ---------------------------------------------------------------------
-- * Hak default PUBLIC dicabut; setiap role hanya mendapat hak yang dibutuhkan tugasnya.
-- * Penjualan: boleh baca produk/pelanggan dan INSERT transaksi, tidak boleh UBAH/HAPUS
--   transaksi (integritas audit) dan tidak boleh melihat log_stok.
-- * Gudang: UPDATE dibatasi pada kolom stok (column-level privilege), harga tidak boleh diubah.
-- * Manajer: read-only, tidak ada INSERT/UPDATE/DELETE.
-- * Hanya role_admin yang boleh DDL/mengelola seluruh objek.
-- * Hak diberikan ke ROLE, user hanya menjadi anggota -> pergantian pegawai cukup GRANT/REVOKE role.
