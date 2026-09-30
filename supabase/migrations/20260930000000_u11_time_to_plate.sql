-- U11 (7): time to home from the stretch.
--
-- Decision (Joel, Sept 30 2026): an optional stopwatch reading on a pitch --
-- the charter taps ⏱ at the pitcher's first move and again at the catcher's
-- glove (only when Set is selected), and the elapsed time attaches to the
-- next pitch recorded. Seconds, hundredths. Readings outside 0.80-3.00 are
-- a late start or stop and are never stored (the client refuses them; this
-- CHECK is the backstop). NULL = not timed -- the normal case.
--
-- Only schema change in U11: batter_side already allows NULL
-- (pitches_batter_side_check) and delivery already allows bullpen rows
-- (pitches_delivery_check has no kind condition), so "no batter" and
-- Set / Windup in bullpens need nothing here.
--
-- Rollback (manual):
--   alter table public.pitches drop constraint if exists pitches_time_to_plate_check;
--   alter table public.pitches drop column if exists time_to_plate;

alter table public.pitches add column time_to_plate numeric(4,2);

alter table public.pitches add constraint pitches_time_to_plate_check
  check (time_to_plate is null or (time_to_plate >= 0.80 and time_to_plate <= 3.00));

comment on column public.pitches.time_to_plate is
  'U11 (7): time to home from the stretch, in seconds (first move to the catcher''s glove), stopwatch-timed by the charter on this pitch. NULL = not timed. 0.80-3.00 only.';
