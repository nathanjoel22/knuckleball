// Deploy with: supabase functions deploy invite-pitcher
// Requires these secrets set on your Supabase project (see SETUP.md):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, INVITE_REDIRECT_URL

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401, headers: corsHeaders })
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
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
  }

  let body: { email?: string; teamId?: string }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400, headers: corsHeaders })
  }

  const { email, teamId } = body
  if (!email || !teamId) {
    return new Response(JSON.stringify({ error: 'email and teamId are required' }), { status: 400, headers: corsHeaders })
  }

  const { data: team, error: teamErr } = await callerClient
    .from('teams')
    .select('id, coach_id, name')
    .eq('id', teamId)
    .single()

  if (teamErr || !team || team.coach_id !== user.id) {
    return new Response(JSON.stringify({ error: 'You do not own this team' }), { status: 403, headers: corsHeaders })
  }

  // Admin client — only this function ever sees the service role key.
  const adminClient = createClient(supabaseUrl, serviceRoleKey)

  const { error: inviteErr } = await adminClient.auth.admin.inviteUserByEmail(email, { redirectTo })
  if (inviteErr && !String(inviteErr.message).toLowerCase().includes('already registered')) {
    return new Response(JSON.stringify({ error: 'Invite email failed: ' + inviteErr.message }), { status: 500, headers: corsHeaders })
  }

  const { error: insertErr } = await callerClient.from('invites').insert({
    team_id: teamId,
    email,
    invited_by: user.id
  })
  if (insertErr) {
    return new Response(JSON.stringify({ error: 'Could not record invite: ' + insertErr.message }), { status: 500, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ ok: true, team: team.name }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
})
