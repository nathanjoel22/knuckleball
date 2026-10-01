-- S3 follow-up: Supabase's default privileges had already granted UPDATE
-- (and the rest) on session_notes to authenticated; with no UPDATE policy an
-- update changed nothing, but the grant shouldn't exist at all. Notes are
-- never edited. Idempotent (the S3 migration now does the same).
revoke all on public.session_notes from public, anon, authenticated;
grant select, insert, delete on public.session_notes to authenticated;
