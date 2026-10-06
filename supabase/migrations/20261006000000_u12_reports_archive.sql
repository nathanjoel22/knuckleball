-- U12 (Amendment 16, Joel Oct 6 2026): a PRIVATE bucket for the one-time archive of report files
-- before the Cairn re-render (rerender-reports function). No storage policies: clients can't list,
-- read or write it; only the server (service role) can. Rollback copies files back from here.
-- Rollback of this migration: supabase/rollback/20261006000000_u12_reports_archive_down.sql
insert into storage.buckets (id, name, public)
values ('reports-archive', 'reports-archive', false)
on conflict (id) do nothing;
