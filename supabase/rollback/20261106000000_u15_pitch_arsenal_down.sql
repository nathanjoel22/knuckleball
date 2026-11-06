-- Rollback of 20261106000000_u15_pitch_arsenal: drops the arsenal function. Nothing else changed (the column grant and
-- coach_set_pitch_types were kept). Apps at v337+ then fail to save arsenal edits until the site is rolled back too.
drop function if exists public.set_pitch_arsenal(uuid, text[]);
