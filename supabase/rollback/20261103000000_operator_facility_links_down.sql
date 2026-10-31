-- Rollback for 20261103000000_operator_facility_links. Invites already made stay.
drop function public.facility_email_status(text);
