-- A1 (Oct 14 2026): the daily run that completes account deletions past their 7-day grace.
-- pg_cron calls public.a1_run_scheduled() once a day; it POSTs {"action":"execute"} to the delete-account function
-- with pg_net. The function's address, the (public) anon key and the shared secret are read from Supabase Vault --
-- never written in this file. Set them once per project (staging: done Oct 14; production: Joel, before shipping):
--   select vault.create_secret('<https://PROJECT.supabase.co/functions/v1/delete-account>', 'a1_function_url');
--   select vault.create_secret('<anon key>',  'a1_anon_key');
--   select vault.create_secret('<A1_CRON_SECRET>', 'a1_cron_secret');   -- the same value as the function secret
-- Rollback: select cron.unschedule('a1-account-deletion'); drop function public.a1_run_scheduled();
create extension if not exists pg_cron;
create extension if not exists pg_net;

create or replace function public.a1_run_scheduled()
returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_url text := (select decrypted_secret from vault.decrypted_secrets where name = 'a1_function_url');
  v_anon text := (select decrypted_secret from vault.decrypted_secrets where name = 'a1_anon_key');
  v_secret text := (select decrypted_secret from vault.decrypted_secrets where name = 'a1_cron_secret');
begin
  if v_url is null or v_anon is null or v_secret is null then
    raise notice 'A1: the vault secrets a1_function_url / a1_anon_key / a1_cron_secret are not set; nothing ran';
    return null;
  end if;
  return net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_anon,
                                  'x-a1-cron-secret', v_secret),
    body := '{"action":"execute"}'::jsonb,
    timeout_milliseconds := 60000);
end;
$$;
revoke all on function public.a1_run_scheduled() from public, anon, authenticated;

-- 09:17 UTC daily (early morning in the US); unschedule first so a re-run of this file never doubles the job
do $$ begin
  perform cron.unschedule('a1-account-deletion');
exception when others then null;
end $$;
select cron.schedule('a1-account-deletion', '17 9 * * *', 'select public.a1_run_scheduled()');
