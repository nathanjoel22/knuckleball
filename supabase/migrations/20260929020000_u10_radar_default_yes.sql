-- U10 (5): radar gun defaults to YES.
--
-- Decision (Joel, Sept 29 2026): "Yes, unless the player has chosen No."
-- The U9 column was `boolean NOT NULL DEFAULT false`, so no stored value
-- could be trusted as a deliberate No: on production, of 26 pitchers at
-- false, 14 had setup stamped done by the U9 migration itself (they never
-- saw the question), 4 never finished setup, and 8 finished setup after U9
-- but may only have tapped "Set Up Later" / "Save Profile", which don't
-- write an answer. Joel chose option (b): flip every pitcher's false to
-- true; anyone who really wants No sets it once more. From here on the
-- default is true, so a stored false can only come from the player (setup
-- modal / Profile) or a coach (coach_set_uses_radar_gun) choosing No.
--
-- Pitchers only: this is the PITCHER's setting (see the column comment);
-- coach rows don't use it and are left exactly as they are.
--
-- Rollback (manual, run only if needed):
--   alter table public.profiles alter column uses_radar_gun set default false;
-- The rows flipped below can't be told apart afterwards -- restore their
-- old values from the pre-migration production backup (BACKUPS.md) if a
-- true rollback is ever needed.

alter table public.profiles alter column uses_radar_gun set default true;

update public.profiles
   set uses_radar_gun = true
 where role = 'pitcher'
   and uses_radar_gun = false;

comment on column public.profiles.uses_radar_gun is
  'The PITCHER''s own preference (U9): whether the velocity strip appears at
   all on the charting page, for whoever charts them. Default true since U10
   (Sept 29 2026): Yes unless the player -- or a head coach editing his
   profile -- has chosen No. Changing it never affects an already-open
   session -- the client snapshots this value onto the session/draft object
   at creation and resume (see sessionUsesRadarGun() in bullpen-tracker.html),
   never re-reading it live mid-pen even from the same device.';
