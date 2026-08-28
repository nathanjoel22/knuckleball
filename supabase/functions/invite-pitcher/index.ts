// Deploy with: supabase functions deploy invite-pitcher
// Requires these secrets set on your Supabase project (see SETUP.md):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, INVITE_REDIRECT_URL

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}
const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json' }
const reply = (obj: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: jsonHeaders })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return reply({ error: 'Missing Authorization header' }, 401)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const redirectTo = Deno.env.get('INVITE_REDIRECT_URL') ?? undefined

  // Client scoped to the calling coach's own session — used to verify
  // who they are and that they actually own the team they're inviting to.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: userErr } = await callerClient.auth.getUser()
  if (userErr || !user) {
    return reply({ error: 'Unauthorized' }, 401)
  }

  let body: { email?: string; teamId?: string }
  try {
    body = await req.json()
  } catch {
    return reply({ error: 'Invalid JSON body' }, 400)
  }

  const { email: rawEmail, teamId } = body
  if (!rawEmail || !teamId) {
    return reply({ error: 'email and teamId are required' }, 400)
  }

  // Normalise once. GoTrue lowercases addresses internally, and
  // accept-invite.html matches invites.email against the (lowercased)
  // session email, so anything stored here must be lowercased too.
  const email = String(rawEmail).trim().toLowerCase()

  // Cheap shape check for a clear, fast 400 -- GoTrue validates more
  // strictly downstream, this just avoids a pointless admin-API round trip
  // and a confusing error for an obvious typo like "notanemail".
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return reply({ error: 'That doesn’t look like a valid email address.', code: 'bad_email' }, 400)
  }

  const { data: team, error: teamErr } = await callerClient
    .from('teams')
    .select('id, coach_id, name')
    .eq('id', teamId)
    .single()

  if (teamErr || !team || team.coach_id !== user.id) {
    return reply({ error: 'You do not own this team' }, 403)
  }

  // Duplicate guard: one pending invite per (team, email). There is no DB
  // unique constraint on invites, so this application check is the guard.
  // The coach can read their own team's invite rows under RLS.
  const { data: existing, error: existingErr } = await callerClient
    .from('invites')
    .select('id')
    .eq('team_id', teamId)
    .eq('email', email)
    .eq('status', 'pending')
    .limit(1)
  if (existingErr) {
    return reply({ error: 'Could not check existing invites: ' + existingErr.message }, 500)
  }
  if (existing && existing.length) {
    return reply({
      error: 'There is already a pending invite for that email on this team.',
      code: 'duplicate'
    }, 409)
  }

  // Admin client — only this function ever sees the service role key.
  const adminClient = createClient(supabaseUrl, serviceRoleKey)

  const { error: inviteErr } = await adminClient.auth.admin.inviteUserByEmail(email, { redirectTo })
  if (inviteErr) {
    // GoTrue phrases the "this email already has an account" case a few
    // ways across versions ("already registered", "already been
    // registered", error_code "email_exists"). Match all of them.
    const m = String(inviteErr.message || '').toLowerCase()
    const alreadyHasAccount =
      (inviteErr as { code?: string }).code === 'email_exists' ||
      /email_exists/.test(m) ||
      (/already/.test(m) && /(registered|exists)/.test(m))
    if (alreadyHasAccount) {
      // The email already has a Knuckleball account. Adding an existing
      // player to a roster is acceptance-based and in-app (roster spec,
      // Track R / R2) -- until that ships, do NOT record an invite row and
      // do NOT auto-add. Tell the coach the honest truth instead of the
      // old silent half-success (invite row written, no email, nobody told).
      return reply({
        error: 'That email already has a Knuckleball account. Adding existing players to a roster is coming soon.',
        code: 'existing_account'
      }, 409)
    }
    return reply({ error: 'Invite email failed: ' + inviteErr.message }, 500)
  }

  const { error: insertErr } = await callerClient.from('invites').insert({
    team_id: teamId,
    email,
    invited_by: user.id
  })
  if (insertErr) {
    return reply({ error: 'Could not record invite: ' + insertErr.message }, 500)
  }

  return reply({ ok: true, team: team.name })
})
