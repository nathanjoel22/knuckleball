// U12 (Amendment 16, Joel Oct 6 2026): build a report entirely from STORED rows -- no client
// payload -- so a report can be regenerated server-side (the one-time Cairn re-render; available
// for future regeneration). It mirrors the app's builders line for line (bullpen-tracker.html:
// loadSessionsForCurrentSelection's pitch mapping, buildReportPayload, buildRecentPensForGame,
// buildGameTrendEntries, buildGameReportPayload, sessionStats, isDefaultVeloReading), including
// R4's rule that a report's team name, uniform number and trends come from the session's own team.
// It uses TODAY's values (pitch-type order, team name, uniform number) -- Joel accepted that.
// Not exposed to clients: only the operator-gated rerender-reports function calls it.

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { buildReportHtml, type ReportPayload } from './template.ts'
import { buildGameReportHtml, type GameReportPayload, type GameSummary } from './template_game.ts'
import type { Pitch, HistoryEntry } from './compute.ts'
import type { GamePitch, RecentPenTypeRow, GameHistoryEntry } from './compute_game.ts'
import { asSport, useSportPalette } from './helpers.ts'

const U6_CUTOFF_TS = 1789965601000   // the app's U6_CUTOFF_TS: a 65 mph reading before it is the old default, not a real speed
const PITCH_COLS = 'session_id, type, velo, target_row, target_col, actual_row, actual_col, accuracy_mode, in_accuracy_zone, ' +
  'accuracy_zone_cells, batter_side, ts, result, in_play_outcome, hit_type, fielder, delivery, inning, outs_before, ' +
  'balls_before, strikes_before, at_bat_index, time_to_plate'

type Row = Record<string, unknown>
// deno-lint-ignore no-explicit-any
type AppPitch = Record<string, any>
interface AppSession { id: string; date: number; kind: string; deletedAt: number | null; pitches: AppPitch[] }

const nn = (v: unknown) => (v === null || v === undefined ? null : v)
export function pitchFromRow(p: Row): AppPitch {
  return {
    type: p.type, velo: p.velo,
    targetRow: p.target_row, targetCol: p.target_col,
    actualRow: p.actual_row, actualCol: p.actual_col,
    accuracyMode: p.accuracy_mode || null,
    inAccuracyZone: (p.in_accuracy_zone === true || p.in_accuracy_zone === false) ? p.in_accuracy_zone : null,
    accuracyZoneCells: p.accuracy_zone_cells || null,
    batterSide: p.batter_side || null,
    ts: new Date(String(p.ts)).getTime(),
    result: p.result || null,
    inPlayOutcome: p.in_play_outcome || null,
    hitType: p.hit_type || null,
    fielder: p.fielder || null,
    delivery: p.delivery || null,
    timeToPlate: nn(p.time_to_plate) === null ? null : Number(p.time_to_plate),
    inning: nn(p.inning), outsBefore: nn(p.outs_before), ballsBefore: nn(p.balls_before),
    strikesBefore: nn(p.strikes_before), atBatIndex: nn(p.at_bat_index)
  }
}
const isDefaultVelo = (pt: AppPitch) => pt.velo === 65 && pt.ts < U6_CUTOFF_TS
const isStrikeCell = (r: number, c: number) => r >= 1 && r <= 3 && c >= 1 && c <= 3
const isAccurate = (p: AppPitch) => p.targetRow === p.actualRow && p.targetCol === p.actualCol
// The app formats with the viewer's locale; the server uses en-US in the app's home time zone.
const dateLabel = (ms: number) => new Intl.DateTimeFormat('en-US', { month: 'numeric', day: 'numeric', timeZone: 'America/New_York' }).format(new Date(ms))

// The subset of the app's sessionStats() the history trend reads.
function historyStats(pitches: AppPitch[]) {
  const total = pitches.length
  const strikes = pitches.filter(p => isStrikeCell(p.actualRow, p.actualCol)).length
  const accurate = pitches.filter(isAccurate).length
  const zone = pitches.filter(p => p.inAccuracyZone === true || p.inAccuracyZone === false)
  const zoneHits = zone.filter(p => p.inAccuracyZone === true).length
  const velos = pitches.filter(p => !isDefaultVelo(p)).map(p => p.velo).filter(v => v !== null && v !== undefined) as number[]
  return {
    total,
    strikePct: total ? Math.round((strikes / total) * 100) : 0,
    commandPct: zone.length ? Math.round((zoneHits / zone.length) * 100) : (total ? Math.round((accurate / total) * 100) : 0),
    hasVelo: velos.length > 0,
    avgVelo: velos.length ? Math.round(velos.reduce((a, b) => a + b, 0) / velos.length) : null
  }
}

function recentPensForGame(teamSessions: AppSession[], gameDateMs: number): RecentPenTypeRow[] | undefined {
  const priorPens = teamSessions
    .filter(s => !s.deletedAt && s.kind === 'bullpen' && s.date < gameDateMs)
    .slice().sort((a, b) => b.date - a.date).slice(0, 5)
  if (priorPens.length < 3) return undefined
  const pooled: Record<string, { count: number; strikes: number; zoneTotal: number; zoneHits: number; exact: number }> = {}
  priorPens.forEach(s => s.pitches.forEach(p => {
    if (!pooled[p.type]) pooled[p.type] = { count: 0, strikes: 0, zoneTotal: 0, zoneHits: 0, exact: 0 }
    const t = pooled[p.type]
    t.count++
    if (isStrikeCell(p.actualRow, p.actualCol)) t.strikes++
    if (p.inAccuracyZone === true || p.inAccuracyZone === false) { t.zoneTotal++; if (p.inAccuracyZone) t.zoneHits++ }
    if (isAccurate(p)) t.exact++
  }))
  const totalPitches = Object.values(pooled).reduce((n, t) => n + t.count, 0)
  if (!totalPitches) return undefined
  return Object.keys(pooled).map(type => {
    const t = pooled[type]
    return {
      type,
      usagePct: Math.round((t.count / totalPitches) * 100),
      strikePct: Math.round((t.strikes / t.count) * 100),
      commandPct: t.zoneTotal ? Math.round((t.zoneHits / t.zoneTotal) * 100) : Math.round((t.exact / t.count) * 100),
      commandLabel: t.zoneTotal ? 'zone' as const : 'exact' as const
    }
  })
}

export interface RenderedReport { html: string; kind: string; sport: string; payload: ReportPayload | GameReportPayload }

// Everything read with `db` (the rerender job passes the admin client; it is operator-gated).
export async function renderReportFromRows(db: SupabaseClient, sessionId: string): Promise<RenderedReport> {
  const { data: s, error: sErr } = await db.from('sessions')
    .select('id, pitcher_id, team_id, logged_by, started_at, charting_perspective, kind, opponent, sport, deleted_at')
    .eq('id', sessionId).maybeSingle()
  if (sErr || !s) throw new Error('session not found: ' + (sErr?.message || sessionId))
  if (s.deleted_at) throw new Error('session is deleted')

  const [{ data: prof }, { data: team }, { data: member }, { data: teamRows }] = await Promise.all([
    db.from('profiles').select('full_name, pitch_types').eq('id', s.pitcher_id).maybeSingle(),
    db.from('teams').select('name').eq('id', s.team_id).maybeSingle(),
    db.from('pitcher_teams').select('uniform_number').eq('pitcher_id', s.pitcher_id).eq('team_id', s.team_id).maybeSingle(),
    // The pitcher's sessions charted for THIS team (R4 follow-up): the app's state.sessions, same-team, not deleted.
    db.from('sessions').select('id, started_at, kind, deleted_at').eq('pitcher_id', s.pitcher_id).eq('team_id', s.team_id).is('deleted_at', null)
  ])
  const ids = (teamRows ?? []).map((r: Row) => String(r.id))
  if (!ids.includes(s.id)) ids.push(s.id)
  const { data: pitchRows, error: pErr } = await db.from('pitches').select(PITCH_COLS).in('session_id', ids).order('ts', { ascending: true })
  if (pErr) throw new Error('pitches read failed: ' + pErr.message)
  const bySession: Record<string, AppPitch[]> = {}
  for (const p of ((pitchRows ?? []) as unknown as Row[])) (bySession[String(p.session_id)] ||= []).push(pitchFromRow(p))
  const teamSessions: AppSession[] = (teamRows ?? []).map((r: Row) => ({
    id: String(r.id), date: new Date(String(r.started_at)).getTime(), kind: String(r.kind || 'bullpen'),
    deletedAt: null, pitches: bySession[String(r.id)] ?? []
  }))
  const date = new Date(String(s.started_at)).getTime()
  const pitches = (bySession[s.id] ?? []).map(pt => isDefaultVelo(pt) ? { ...pt, velo: null } : pt)
  const common = {
    sport: asSport(s.sport), sessionId: s.id, pitcherId: s.pitcher_id,
    pitcherName: String(prof?.full_name ?? ''),
    uniformNumber: (member?.uniform_number ?? null) as number | null,
    date,
    chartingPerspective: (s.charting_perspective ?? null) as ReportPayload['chartingPerspective'],
    loggedByCoach: s.logged_by !== s.pitcher_id,
    pitchTypes: Array.isArray(prof?.pitch_types) ? prof!.pitch_types as string[] : []
  }

  useSportPalette(asSport(s.sport))
  if ((s.kind || 'bullpen') !== 'game') {
    const history: HistoryEntry[] = teamSessions
      .filter(x => x.id !== s.id && x.kind === 'bullpen')
      .sort((a, b) => a.date - b.date)
      .map(x => { const st = historyStats(x.pitches); return { date: x.date, dateLabel: dateLabel(x.date), ...st } as HistoryEntry })
    const payload: ReportPayload = { ...common, teamName: team ? String(team.name) : '', pitches: pitches as unknown as Pitch[], history }
    return { html: buildReportHtml(payload), kind: 'bullpen', sport: String(s.sport), payload }
  }

  const summaryOf = async (id: string) => {
    const { data, error } = await db.rpc('compute_game_summary', { p_session_id: id })
    if (error || !data || (data as Row).error) return null
    return data as Row
  }
  const summary = await summaryOf(s.id)
  if (!summary) throw new Error('compute_game_summary failed for ' + s.id)
  const priorGames = teamSessions.filter(x => x.id !== s.id && x.kind === 'game').sort((a, b) => b.date - a.date).slice(0, 5)
  const thisSession: AppSession = { id: s.id, date, kind: 'game', deletedAt: null, pitches: bySession[s.id] ?? [] }
  const gameTrend: GameHistoryEntry[] = []
  for (const x of priorGames.slice().reverse().concat([thisSession])) {
    const d = await summaryOf(x.id)
    if (!d) continue
    const velos = x.pitches.filter(p => !isDefaultVelo(p)).map(p => p.velo).filter(v => v !== null && v !== undefined) as number[]
    gameTrend.push({
      date: x.date, dateLabel: dateLabel(x.date),
      strikePct: d.strike_pct as number | null, firstPitchStrikePct: d.first_pitch_strike_pct as number | null,
      k: d.k as number, bb: d.bb as number, h: d.h as number,
      hasVelo: velos.length > 0, avgVelo: velos.length ? Math.round(velos.reduce((a, b) => a + b, 0) / velos.length) : null,
      pitches: d.pitches as number
    })
  }
  const { data: evRows, error: evErr } = await db.from('game_events')
    .select('event_type, at_bat_index, seq, inning_before, balls_before, strikes_before, runner_advances')
    .eq('session_id', s.id).order('seq', { ascending: true, nullsFirst: true })
  if (evErr) throw new Error('game events read failed: ' + evErr.message)
  const payload: GameReportPayload = {
    ...common,
    teamName: team ? String(team.name) : null,
    opponent: (s.opponent ?? null) as string | null,
    pitches: pitches as unknown as GamePitch[],
    recentPens: recentPensForGame(teamSessions, date),
    gameTrend,
    summary: summary as unknown as GameSummary,
    events: (evRows ?? []).map((e: Row) => ({
      eventType: String(e.event_type), atBatIndex: (e.at_bat_index as number | null) ?? null, seq: (e.seq as number | null) ?? null,
      inningBefore: (e.inning_before as number | null) ?? null, ballsBefore: (e.balls_before as number | null) ?? null,
      strikesBefore: (e.strikes_before as number | null) ?? null, runnerAdvances: (e.runner_advances as unknown[] | null) ?? null
    }))
  }
  return { html: buildGameReportHtml(payload), kind: 'game', sport: String(s.sport), payload }
}
