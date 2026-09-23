-- U4/U4b -- HTML reports replace PDF (frozen files, public bucket, per-side splits,
-- expanded content per u4-html-reports.md and its U4b resumption spec).
--
-- A report is now a frozen, self-contained static HTML file in a PUBLIC Supabase
-- Storage bucket at an unguessable, permanent object name -- not a PDF attachment.
-- Saved sessions are immutable, so a report is a pure function of its session (plus
-- whatever prior-session history existed at generation time); it is generated once,
-- reused for every re-send, and never regenerated.
--
-- Why a public bucket, not signed URLs: a signed URL is tied to the project's JWT
-- secret -- if that ever rotates, every report link ever emailed dies at once. A
-- public bucket has no such expiry.
--
-- report_path / report_generated_at are NULLABLE: most sessions have no report yet
-- (every existing session, and any new one before its first View/Send).
--
-- ============================================================================
-- Bucket + policies
-- ============================================================================
--
-- The bucket is created public=true, which is what makes
-- GET /storage/v1/object/public/reports/<name> work with NO authentication and NO
-- RLS check at all -- Supabase Storage's public-URL path is a bypass of RLS
-- entirely, gated only by this flag, not by a policy. That is the mechanism behind
-- "anon may download by exact object name".
--
-- Deliberately NO SELECT policy is added on storage.objects for this bucket, for
-- anon or otherwise. storage.objects has RLS enabled by default; with no matching
-- policy, every RLS-governed access path (list(), the SDK's authenticated
-- download(), anything that queries the table rather than hitting the public-URL
-- bypass) is denied by default, for every role. Adding a SELECT policy scoped only
-- to bucket_id = 'reports' would grant list() the exact same visibility it would
-- grant direct-by-name reads, since RLS cannot distinguish HOW a row is queried --
-- only whether the row is visible at all. That would defeat "anon may NOT list" the
-- moment such a policy existed. So: public reads come from the bucket flag; listing
-- stays blocked by having no policy whatsoever. This is verified empirically with
-- the anon key on staging and again on production before anything depends on it --
-- see the packet's own instruction to prove this, not assume it.
--
-- No INSERT/UPDATE policy is needed either: the Edge Function writes new report
-- objects using the service-role key, which bypasses RLS entirely regardless of any
-- policy on this table.

insert into storage.buckets (id, name, public)
values ('reports', 'reports', true)
on conflict (id) do nothing;

-- ============================================================================
-- sessions columns
-- ============================================================================

alter table public.sessions
  add column report_path text,
  add column report_generated_at timestamptz;

comment on column public.sessions.report_path is
  'Object name (not a full URL) of this session''s frozen HTML report in the reports bucket. NULL until first generated. Never regenerated once set -- reused for every re-send. Lets a future session-deletion feature delete the report object (not implemented here).';
comment on column public.sessions.report_generated_at is
  'When report_path was first set. NULL until then.';

-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   alter table public.sessions
--     drop column if exists report_path,
--     drop column if exists report_generated_at;
--
--   -- Deliberately NOT included by default: dropping the bucket destroys every
--   -- report already emailed/opened -- those links break permanently, with no way
--   -- to recreate the exact same object name. Leave the bucket in place on a
--   -- rollback and only drop the two columns above. If the bucket genuinely must
--   -- go:
--   --   delete from storage.objects where bucket_id = 'reports';
--   --   delete from storage.buckets where id = 'reports';
-- ---------------------------------------------------------------------------------
