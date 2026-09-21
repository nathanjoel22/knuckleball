// ─── FILL THIS IN once you've deployed the send-session-report function ───
// SEND_REPORT_URL: your deployed function's URL, e.g.
//   https://YOUR_PROJECT.supabase.co/functions/v1/send-session-report
// The function authenticates the caller via their Supabase session
// (see bullpen-tracker.html), not a shared secret — nothing sensitive
// belongs in this file since it ships in the open static site.
const SEND_REPORT_URL = "https://fkgccjhuimkkbupbanxp.supabase.co/functions/v1/send-session-report";

// R0 follow-up: same authentication model (caller's own Supabase session,
// no shared secret) -- see join.html and bullpen-tracker.html's Resend button.
const VERIFY_EMAIL_URL = "https://fkgccjhuimkkbupbanxp.supabase.co/functions/v1/send-verification-email";

// R0 follow-up: same authentication model, coach-only in practice
// (get_removal_notice_info enforces this server-side regardless).
const REMOVAL_NOTICE_URL = "https://fkgccjhuimkkbupbanxp.supabase.co/functions/v1/send-removal-notice";