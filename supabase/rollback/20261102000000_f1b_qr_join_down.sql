-- Rollback for 20261102000000_f1b_qr_join (F1-B). Only functions were added; memberships made through codes stay.
drop function public.rotate_group_code(uuid);
drop function public.my_group_codes();
drop function public.join_group_via_token(text, uuid);
drop function public.group_join_info(text);
-- The column grants it restored stay: re-opening table-wide reads of join codes would bring back the leak it fixed.
