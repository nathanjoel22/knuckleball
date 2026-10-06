// Deploy with: supabase functions deploy rerender-reports
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY (platform-injected),
//          OPERATOR_EMAILS (comma-separated login emails allowed to run this -- Joel).
//
// U12 (Amendment 16, Joel Oct 6 2026): the ONE dated exception to "reports are frozen" -- re-render
// one team's existing reports in the pitcher's view, at their existing links. Run by Joel.
//
//   POST { mode: 'dry_run' | 'run' | 'rollback', team_id, archive?: '2026-10-06', expect_count? }
//   dry_run  (default) lists every session of team_id that has a report file; writes nothing.
//   run      requires expect_count = the dry run's count. For each report: copies the original file to
//            the PRIVATE reports-archive bucket at <archive>/<same name> (never overwrites an archived
//            copy), records it in <archive>/manifest.json (session, path, original generated date,
//            bytes, SHA-256), rebuilds the report from stored rows with today's renderer, and
//            overwrites the same object name -- the link doesn't change. No session row changes.
//   rollback copies every archived original back over its file, after checking its SHA-256.
// Never sends email. Never touches a session outside team_id. Uses the admin client throughout
// (an operator tool: it must read departed pitchers too), gated on OPERATOR_EMAILS.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { renderReportFromRows } from '../send-session-report/from_rows.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body, null, 1), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

async function sha256(bytes: Uint8Array): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', bytes as unknown as ArrayBuffer)
  return [...new Uint8Array(d)].map(b => b.toString(16).padStart(2, '0')).join('')
}
interface ManifestEntry {
  session_id: string; path: string; original_generated_at: string | null
  bytes: number; sha256: string; rerendered_bytes?: number; rerendered_sha256?: string; rerendered_at?: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Missing Authorization header' }, 401)

  const caller = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authHeader } } })
  const { data: { user }, error: userErr } = await caller.auth.getUser()
  if (userErr || !user || !user.email) return json({ error: 'Unauthorized' }, 401)
  const operators = (Deno.env.get('OPERATOR_EMAILS') || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean)
  if (!operators.includes(user.email.toLowerCase())) return json({ error: 'This tool is for the operator only.' }, 403)

  let body: { mode?: string; team_id?: string; archive?: string; expect_count?: number }
  try { body = await req.json() } catch { return json({ error: 'invalid_json' }, 400) }
  const mode = body.mode || 'dry_run'
  const teamId = String(body.team_id || '')
  const archive = String(body.archive || '2026-10-06')
  if (!/^[0-9a-f-]{36}$/.test(teamId)) return json({ error: 'team_id is required' }, 400)
  if (!/^\d{4}-\d{2}-\d{2}$/.test(archive)) return json({ error: 'archive must be a date like 2026-10-06' }, 400)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { autoRefreshToken: false, persistSession: false } })
  const { data: team } = await admin.from('teams').select('id, name, sport').eq('id', teamId).maybeSingle()
  if (!team) return json({ error: 'team not found' }, 404)
  const manifestPath = `${archive}/manifest.json`

  const readManifest = async (): Promise<ManifestEntry[]> => {
    const { data } = await admin.storage.from('reports-archive').download(manifestPath)
    if (!data) return []
    try { return JSON.parse(await data.text()) as ManifestEntry[] } catch { return [] }
  }
  const writeManifest = async (entries: ManifestEntry[]) => {
    const { error } = await admin.storage.from('reports-archive')
      .upload(manifestPath, new Blob([JSON.stringify(entries, null, 1)], { type: 'application/json' }), { upsert: true, contentType: 'application/json' })
    if (error) throw new Error('manifest write failed: ' + error.message)
  }

  if (mode === 'rollback') {
    const entries = (await readManifest()).filter(e => e.path)
    const results = []
    for (const e of entries) {
      const { data: blob, error } = await admin.storage.from('reports-archive').download(`${archive}/${e.path}`)
      if (error || !blob) { results.push({ path: e.path, ok: false, error: 'archived copy missing' }); continue }
      const bytes = new Uint8Array(await blob.arrayBuffer())
      if (await sha256(bytes) !== e.sha256) { results.push({ path: e.path, ok: false, error: 'archived copy hash mismatch -- not restored' }); continue }
      const { error: upErr } = await admin.storage.from('reports')
        .upload(e.path, bytes, { upsert: true, contentType: 'text/html; charset=utf-8', cacheControl: '300' })
      results.push({ path: e.path, ok: !upErr, error: upErr?.message })
    }
    return json({ mode, team: team.name, restored: results.filter(r => r.ok).length, of: results.length, results })
  }

  const { data: sessions, error: sErr } = await admin.from('sessions')
    .select('id, pitcher_id, started_at, kind, report_path, report_generated_at, profiles!sessions_pitcher_id_fkey(full_name)')
    .eq('team_id', teamId).not('report_path', 'is', null).is('deleted_at', null)
    .order('started_at', { ascending: true })
  if (sErr) return json({ error: 'sessions read failed: ' + sErr.message }, 500)
  const list = (sessions ?? []).map((s: Record<string, unknown>) => ({
    session_id: String(s.id), path: String(s.report_path), kind: String(s.kind),
    date: String(s.started_at).slice(0, 10), generated: s.report_generated_at as string | null,
    pitcher: ((s.profiles as Record<string, unknown> | null)?.full_name as string) ?? ''
  }))

  if (mode === 'dry_run') return json({ mode, team: team.name, team_id: teamId, count: list.length, sessions: list })
  if (mode !== 'run') return json({ error: 'mode must be dry_run, run or rollback' }, 400)
  if (body.expect_count !== list.length) {
    return json({ error: `expect_count must equal the dry run's count (${list.length}); nothing was changed.` }, 409)
  }

  const manifest = await readManifest()
  const results = []
  for (const s of list) {
    try {
      // 1. archive the current file -- once. An existing archived copy is never replaced, so a rerun
      //    after a partial run can't archive a re-rendered file over the original.
      let entry = manifest.find(m => m.path === s.path)
      if (!entry) {
        const { data: blob, error } = await admin.storage.from('reports').download(s.path)
        if (error || !blob) throw new Error('original file missing: ' + (error?.message || s.path))
        const bytes = new Uint8Array(await blob.arrayBuffer())
        const { error: aErr } = await admin.storage.from('reports-archive')
          .upload(`${archive}/${s.path}`, bytes, { upsert: false, contentType: 'text/html; charset=utf-8' })
        if (aErr) throw new Error('archive copy failed: ' + aErr.message)
        entry = { session_id: s.session_id, path: s.path, original_generated_at: s.generated, bytes: bytes.length, sha256: await sha256(bytes) }
        manifest.push(entry)
        await writeManifest(manifest)
      }
      // 2. rebuild from stored rows and overwrite the same object name.
      const rendered = await renderReportFromRows(admin, s.session_id)
      const out = new TextEncoder().encode(rendered.html)
      const { error: upErr } = await admin.storage.from('reports')
        .upload(s.path, out, { upsert: true, contentType: 'text/html; charset=utf-8', cacheControl: '300' })
      if (upErr) throw new Error('overwrite failed: ' + upErr.message)
      entry.rerendered_bytes = out.length; entry.rerendered_sha256 = await sha256(out); entry.rerendered_at = new Date().toISOString()
      await writeManifest(manifest)
      results.push({ path: s.path, pitcher: s.pitcher, kind: s.kind, ok: true })
    } catch (e) {
      results.push({ path: s.path, pitcher: s.pitcher, kind: s.kind, ok: false, error: (e as Error).message })
    }
  }
  return json({ mode, team: team.name, rerendered: results.filter(r => r.ok).length, of: results.length, archive: `reports-archive/${archive}/`, results })
})
