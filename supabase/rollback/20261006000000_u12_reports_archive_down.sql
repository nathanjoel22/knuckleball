-- Down migration for 20261006000000_u12_reports_archive.sql. Only once the archive is no longer
-- needed: deleting the bucket requires it to be empty (empty it from the dashboard first).
delete from storage.buckets where id = 'reports-archive';
