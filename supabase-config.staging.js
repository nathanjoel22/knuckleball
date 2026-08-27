// STAGING config -- points the static frontend at the knuckleball-staging
// Supabase project instead of production. See DEPLOY.md for how to use
// this: local serve only, never deployed to GitHub Pages.
//
// The anon key is safe to put in client-side code either way -- it's a
// public key by design. Row Level Security is the actual security
// boundary (see supabase/schema/schema.sql), same as production.
const SUPABASE_URL = "https://wpsscxwawgiwmifpjpec.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indwc3NjeHdhd2dpd21pZnBqcGVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3MjM5MTgsImV4cCI6MjEwMzI5OTkxOH0.rIQ195qQDVa5jnZ6kAZk5ZRDaJjGZZa4cl1x4G_dDkE";
// Must match the auth options in supabase-config.js -- see the comment
// there (in particular: no custom storageKey, on purpose).
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});
