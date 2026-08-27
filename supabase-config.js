// ─── FILL THESE IN ───────────────────────────────────────────────
// Get both values from your Supabase project dashboard:
// Project Settings → API → Project URL / Project API keys → "anon public"
//
// The anon key is safe to put in client-side code — it's a public key by
// design. Row Level Security policies (set up in schema.sql) are what
// actually keep people's data private, not this key.
const SUPABASE_URL = "https://fkgccjhuimkkbupbanxp.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZrZ2Njamh1aW1ra2J1cGJhbnhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4Mzc2MDQsImV4cCI6MjEwMjQxMzYwNH0.D6CYLb7Sadpl_G7fDwFLmH3Spl_D-IXyGbpQ2S8i__k";
// ──────────────────────────────────────────────────────────────────
// "Log in once, chart anywhere" (P1-01): persistSession + autoRefreshToken
// + detectSessionInUrl are the supabase-js defaults already, but are set
// explicitly here so that's a documented decision, not an accident of the
// library version. Deliberately NOT setting a custom storageKey: the SDK's
// default (`sb-<project-ref>-auth-token`, derived from SUPABASE_URL) is
// what every already-logged-in device's session is persisted under today
// -- overriding it would orphan those sessions and force a mass
// re-login on the next deploy, the opposite of this goal. bullpen-tracker
// .html's offline-auth fallback (readPersistedSessionRaw) recomputes this
// same default from SUPABASE_URL rather than needing a key here.
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});