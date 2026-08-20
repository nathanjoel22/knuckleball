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
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);