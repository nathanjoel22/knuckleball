-- Rollback for 20261128000000_f2s3_birthdays (F2 Stage 3). Removes the September 1 job, the functions and the three
-- tables. Every birthday entered is deleted (that's the point of a rollback here); levels the job already raised stay.
begin;
select cron.unschedule('f2-level-switch') where exists (select 1 from cron.job where jobname = 'f2-level-switch');
drop function if exists public.f2_level_switch(date);
drop function if exists public.f2_level_rank(text);
drop function if exists public.f2_level_for(text, int);
drop function if exists public.set_birthday(uuid, date, boolean);
drop function if exists public.f2_age_on(date, date);
drop function if exists public.my_birthdays();
drop function if exists public.f2_bday_access(uuid);
drop table if exists public.level_switch_log;
drop table if exists public.birthday_contradictions;
drop table if exists public.profile_birthdays;
commit;
