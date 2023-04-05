-- Run this script with "sqlite3 -append docsapp" to append
-- a SQLAR database onto the end of the raw docsapp binary
-- and load it with most doc directory subtree content.
--
PRAGMA page_size=512;
DROP TABLE IF EXISTS sqlar;
.ar -c main.tcl wapp.tcl doc
DELETE FROM sqlar WHERE name LIKE '%/matrix/%';
VACUUM;
.q
