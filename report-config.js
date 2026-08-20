// ─── FILL THESE IN once you've deployed the send-session-report function ───
// SEND_REPORT_URL: your deployed function's URL, e.g.
//   https://YOUR_PROJECT.supabase.co/functions/v1/send-session-report
// REPORT_API_KEY: a shared secret you make up yourself — it must match the
//   REPORT_API_KEY secret you set on the function (see SETUP.md). This is a
//   basic gate to stop random people from spamming your Resend account
//   through this endpoint; it is NOT full account-level security, since this
//   file ships in the open static site. Real per-user auth is the next step
//   once accounts are fully wired up.
const SEND_REPORT_URL = "https://fkgccjhuimkkbupbanxp.supabase.co/functions/v1/send-session-report";
const REPORT_API_KEY = "kb-9f3x-report-key-2q7m1z-lp8d";