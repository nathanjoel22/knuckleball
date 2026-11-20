// ============================================================================
// G2 -- the Live Game report template. Same rules as template.ts: one
// self-contained HTML string, inline CSS/SVG, zero JavaScript, zero
// external requests, every string escaped, every number safeNum()'d.
// Reuses template.ts's CSS verbatim (imported, not copied) plus a small
// game-only stylesheet addition below, so the two reports read as one
// product (content spec: "Same theme and typography as the pen report").
// ============================================================================
import { escapeHtml, safeNum, colorForType, timesToHomeLine, asSport, reportVars, type Sport, VIEW_NAME, REPORT_VIEW, viewNote } from './helpers.ts'
import { ZONE_NAMES } from './helpers.ts'
import { drawGrid, drawLegend, drawLineChart, drawGridByResult, drawResultLegend, resultCategoryOf, drawTypeGrids, drawHitTypeGrids } from './svg.ts'
import { CSS as PEN_CSS } from './template.ts'
import {
  type GamePitch, computeGameByType, computeGameByInning, computeGameByCount, computeLeadoffReached,
  computeGamePerSideBlock, computeGameExcludedNullSide, computeGameVelocityByInning,
  computeRecentPensComparison, computeGameTrends, computeAtBatLog, resultGlyph,
  type RecentPenTypeRow, type GameHistoryEntry
} from './compute_game.ts'
import { computeVelocityDepth } from './compute.ts'
import { type GameEvent } from './compute_game.ts'
import { renderSprayCharts, renderWhatLedToIt, renderBaseStates, DIAMOND_CSS } from './diamond.ts'
import { renderPitchesThatMattered, renderBullpenToGame, CONNECT_CSS, type PenPitch } from './connect.ts'
import {
  type Comparison, NO_COMPARISON, type StoodOut, type TileSpec, WINDOWS, SR1_CSS, ids, radios, tabBar, windowSwitch, wb, panel,
  takeaway, card, tileFor, windowCaption, stoodOutCard, sparkCard, simpleTable, typeCell, footer, firstName, word, ordinal, pctOf,
  pickFastball, avgVelo, gunned, outsideRange, rangeText, sortStoodOut, sidePattern, clusterPattern, typeMin, inningMin,
  restCard, sevenDayCard, type Voice, type LevelGroup, levelGroup, versionsFor, ver, tabBarVersions, printTitle,
  type EmailVersion, emailComment, shortDate, sevenDayEmailLine, restEmailLine, comparedEmailLine
} from './sr1.ts'

// The one definition this report does NOT compute itself -- it's the exact
// object public.compute_game_summary(session_id) returns, fetched by
// index.ts through the caller's own RLS-scoped client (same function
// History calls client-side). See compute_game.ts's header comment.
export interface GameSummary {
  pitches: number; strikes: number
  strike_pct: number; strike_pct_denominator: number
  in_zone: number; in_zone_pct: number
  first_pitch_pitches: number; first_pitch_strike_pct: number | null
  k: number; bb: number; h: number; xbh: number
  outs_in_play: number; errors: number; hbp: number
  batters_faced: number
  outs_recorded: number; outs_source: 'counter' | 'derived'
  final_inning: number; final_inning_source: 'counter' | 'derived'
  pitch_count?: number   // Oct 19: pitches + the session's + / - adjustment (the rates still use pitches)
  runs?: number | null   // Oct 19: runs while he pitched; null when the game recorded none (games before runs were tracked)
  // Release 2: runs is charged to him (inherited runners' runs left out); null = not tracked (games before)
  er?: number | null
  ir?: number | null
  irs?: number | null
  bb_charged_prev?: number | null
  runners_left?: number | null   // Oct 21: runners on base when he came out; null = games saved before
  exit_runs?: number | null      // R3 Stage B: charged to him after he left (his runners who scored); in runs / er / bb
  exit_er?: number | null
  exit_bb?: number | null
  provisional?: boolean
}
const pitchCount = (s: GameSummary) => s.pitch_count ?? s.pitches

export interface GameReportPayload {
  // S1: from the SESSION ROW (index.ts), never from the client's payload.
  sport?: Sport
  sessionId: string
  pitcherId: string
  pitcherName: string
  uniformNumber: number | null
  teamName: string | null
  date: number
  opponent: string | null
  chartingPerspective: 'behind_catcher' | 'behind_pitcher' | null
  loggedByCoach: boolean
  pitchTypes: string[]
  gridSize?: number
  pitches: GamePitch[]
  recentPens?: RecentPenTypeRow[]
  recentPenPitches?: PenPitch[]   // Joel, Oct 7: the last 5 bullpens' pitches (same team), for "Bullpen to game"
  gameTrend: GameHistoryEntry[]
  summary: GameSummary
  events?: GameEvent[]   // G3: no-pitch events, read server-side under the caller's RLS
  raOn?: boolean   // U14: the session's answer to "Turn on Relative Accuracy?" (session row)
  comparison?: Comparison   // SR1 C: Stage B's baselines, the last games, the throwing hand (read at save, caller's reach)
}

function fmtVelo(v: number | null): string { return v === null ? '—' : String(Math.round(v)) + ' mph' }
function tile(value: string, label: string): string {
  return `<div class="tile"><div class="tile-val">${value}</div><div class="tile-lbl">${escapeHtml(label)}</div></div>`
}
// Decision 4: IP is derived from outs (17 outs = 5.2). Pure arithmetic on
// an already-single-sourced integer -- nothing here can disagree with
// anything else, so it's fine for both this file and History to each
// format it locally.
function fmtIP(outs: number): string {
  const innings = Math.floor(outs / 3)
  const rem = outs % 3
  return `${innings}.${rem}`
}
function allTypesOf(p: GameReportPayload): string[] {
  return p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(p.pitches.map(x => x.type)))
}

// ---------- 3. Pitching line ----------
function renderPitchingLine(p: GameReportPayload): string {
  const s = p.summary
  const inPlay = p.pitches.filter(x => x.result === 'in_play')
  const hits = inPlay.filter(x => x.inPlayOutcome === 'hit')
  const oneB = hits.filter(x => x.hitType === '1B').length
  const twoB = hits.filter(x => x.hitType === '2B').length
  const threeB = hits.filter(x => x.hitType === '3B').length
  const hr = hits.filter(x => x.hitType === 'HR').length
  const hasHitTypes = hits.some(x => x.hitType)
  const byPosition = new Map<string, { outs: number; hits: number; errors: number }>()
  for (const x of inPlay) {
    if (!x.fielder) continue
    const row = byPosition.get(x.fielder) || { outs: 0, hits: 0, errors: 0 }
    if (x.inPlayOutcome === 'out') row.outs++
    else if (x.inPlayOutcome === 'hit') row.hits++
    else if (x.inPlayOutcome === 'error') row.errors++
    byPosition.set(x.fielder, row)
  }
  // Oct 20 (E5): wild pitches and balks in the line. Each runner's move is its own event, so the runners who moved on
  // one wild pitch are one WP (same inning, batter and count). Softball's illegal pitch (and its older balk rows)
  // stands in for the balk.
  const softball = asSport(p.sport) === 'softball'
  const evs = p.events ?? []
  const wp = new Set(evs.filter(e => e.eventType === 'wild_pitch').map(e => `${e.inningBefore}|${e.atBatIndex}|${e.ballsBefore}|${e.strikesBefore}`)).size
  const bk = evs.filter(e => softball ? (e.eventType === 'illegal_pitch' || e.eventType === 'balk') : e.eventType === 'balk').length
  const bkLabel = softball ? 'Illegal' : 'BK'
  // Release 2: ER (games charted with earned runs), IR / IRS (a reliever), SF / SAC, walks charged to the previous pitcher
  const sf = p.pitches.filter(x => x.sacrifice === 'SF').length, sac = p.pitches.filter(x => x.sacrifice === 'SAC').length
  const hasEr = s.er != null, hasIr = s.ir != null, hasSac = sf + sac > 0
  const posRows = Array.from(byPosition.entries())
    .map(([pos, r]) => `<tr><td>${escapeHtml(pos)}</td><td>${r.outs}</td><td>${r.hits}</td><td>${r.errors}</td></tr>`)
    .join('')
  return `
  <section class="section">
    <h2>Pitching line</h2>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>IP</th><th>BF</th><th>Pitches</th><th>Strikes</th><th>K</th><th>BB</th><th>H</th>${hasHitTypes ? '<th>1B/2B/3B/HR</th>' : ''}<th>HBP</th><th>WP</th><th>${bkLabel}</th><th>E</th><th>Outs in play</th>${s.runs != null ? '<th>R</th>' : ''}${hasEr ? '<th>ER</th>' : ''}${hasIr ? '<th>IR/IRS</th>' : ''}${hasSac ? '<th>SF/SAC</th>' : ''}</tr></thead>
      <tbody><tr>
        <td>${fmtIP(s.outs_recorded)}</td><td>${s.batters_faced}</td><td>${pitchCount(s)}</td><td>${s.strikes}</td>
        <td>${s.k}</td><td>${s.bb}</td><td>${s.h}</td>${hasHitTypes ? `<td>${oneB}/${twoB}/${threeB}/${hr}</td>` : ''}
        <td>${s.hbp}</td><td>${wp}</td><td>${bk}</td><td>${s.errors}</td><td>${s.outs_in_play}</td>${s.runs != null ? `<td>${s.runs}</td>` : ''}${hasEr ? `<td>${s.er}</td>` : ''}${hasIr ? `<td>${s.ir}/${s.irs ?? 0}</td>` : ''}${hasSac ? `<td>${sf}/${sac}</td>` : ''}
      </tr></tbody>
    </table></div>
    ${typeof s.runners_left === 'number' && s.runners_left > 0 ? `<p class="caption">Left ${s.runners_left} runner${s.runners_left === 1 ? '' : 's'} on base when the pitcher came out${(s.exit_runs ?? 0) > 0 ? `; ${s.exit_runs} of them scored after and ${(s.exit_runs ?? 0) === 1 ? 'is' : 'are'} in this line's R${hasEr ? ` (${s.exit_er ?? 0} earned)` : ''}` : ''}.</p>` : ''}
    ${hasIr && (s.irs ?? 0) > 0 ? `<p class="caption">${s.irs} of the ${s.ir} inherited runner${s.ir === 1 ? '' : 's'} scored — charged to the previous pitcher, not in this line's R or ER.</p>` : ''}
    ${posRows ? `
    <div class="table-scroll" style="margin-top:12px;"><table class="data-table">
      <thead><tr><th>Fielder</th><th>Outs</th><th>Hits</th><th>Errors</th></tr></thead>
      <tbody>${posRows}</tbody>
    </table></div>` : ''}
  </section>`
}

// ---------- 4. Location charts (by type, then by result) ----------
// U11 (4): one small grid per pitch type, right after the location charts.
// Strike % is the SAME result-based strike % the By pitch type table shows
// (computeGameByType), so the two never disagree.
function renderTypeGrids(p: GameReportPayload): string {
  const allTypes = allTypesOf(p)
  const stats: Record<string, { count: number; strikePct: number | null }> = {}
  for (const row of computeGameByType(p.pitches, allTypes, p.gridSize)) {
    if (row) stats[row.type] = { count: row.count, strikePct: row.strikePct }
  }
  if (!Object.keys(stats).length) return ''
  return `
  <section class="section">
    <h2>Location by pitch type — ${VIEW_NAME}</h2>
    ${drawTypeGrids({ gridSize: p.gridSize, allTypes, stats, pitches: p.pitches.map(x => ({ row: x.actualRow, col: x.actualCol, type: x.type })) })}
    <p class="caption">Where each pitch type went, both batter sides mixed. Strike % counts balls and strikes by result, same as the table below. A small count means read it lightly.</p>
  </section>`
}

function renderLocationCharts(p: GameReportPayload): string {
  const allTypes = allTypesOf(p)
  const typeGrid = drawGrid({
    gridSize: p.gridSize, batterSide: null,
    pitches: p.pitches.map(x => ({ row: x.actualRow, col: x.actualCol, type: x.type })),
    allTypes
  })
  const resultPts = p.pitches.map(x => ({ row: x.actualRow, col: x.actualCol, category: resultCategoryOf(x.result) }))
  const categoriesPresent = Array.from(new Set(resultPts.map(x => x.category)))
  const resultGrid = drawGridByResult({ gridSize: p.gridSize, batterSide: null, pitches: resultPts })
  return `
  <section class="section">
    <h2>Location — ${VIEW_NAME}</h2>
    <div class="grid-row"><div><h3>By pitch type</h3>${typeGrid}${drawLegend(allTypes)}</div></div>
    <div class="grid-row" style="margin-top:16px;"><div><h3>By result</h3>${resultGrid}${drawResultLegend(categoriesPresent)}</div></div>
    <p class="caption">Both batter sides mixed, physical framing -- numbers and directional words depend on who's hitting, so neither plot uses them.</p>
  </section>`
}

// ---------- 5. By pitch type ----------
function renderByType(p: GameReportPayload): string {
  const allTypes = allTypesOf(p)
  const rows = computeGameByType(p.pitches, allTypes, p.gridSize)
  if (!rows.length) return ''
  const body = rows.map(r => {
    const count = r.thin ? ` (${r.count})` : ''
    const whiff = r.whiffPct !== null ? `${r.whiffPct}%${r.whiffSwings < 5 ? ' (' + r.whiffSwings + ')' : ''}` : '—'
    const velo = r.hasVelo ? `${fmtVelo(r.avgVelo)} avg · ${fmtVelo(r.peakVelo)} peak` : '—'
    return `<tr>
      <td><span class="dot" style="background:${colorForType(r.type, allTypes)}"></span>${escapeHtml(r.type)}${count}</td>
      <td>${r.usagePct}%</td><td>${r.strikePct ?? '—'}%</td><td>${r.inZonePct}%</td><td>${whiff}</td><td>${r.calledStrikePct}%</td>
      <td>${r.inPlay.h}/${r.inPlay.out}/${r.inPlay.e}</td><td>${velo}</td>
    </tr>`
  }).join('')
  return `
  <section class="section">
    <h2>By pitch type</h2>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>Type</th><th>Usage</th><th>Strike %</th><th>In-zone %</th><th>Whiff %</th><th>Called-strike %</th><th>In-play H/Out/E</th><th>Velocity</th></tr></thead>
      <tbody>${body}</tbody>
    </table></div>
    ${timesToHomeLine(p.pitches)}
  </section>`
}

// ---------- 6. By inning ----------
function renderByInning(p: GameReportPayload): string {
  const rows = computeGameByInning(p.pitches, p.gridSize)
  if (!rows.length) return ''
  const body = rows.map(r => `<tr>
    <td>${r.inning}</td><td>${r.pitches}</td><td>${r.strikes}</td><td>${r.strikePct ?? '—'}%</td><td>${r.inZonePct}%</td>
    <td>${r.battersFaced}</td><td>${r.k}/${r.bb}/${r.h}</td>
    <td>${r.hasVelo ? fmtVelo(r.avgVelo) : '—'}${r.hasVelo ? ` <span class="caption" style="display:inline;">(peak ${fmtVelo(r.peakVelo)})</span>` : ''}</td>
  </tr>`).join('')
  return `
  <section class="section">
    <h2>By inning</h2>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>Inning</th><th>Pitches</th><th>Strikes</th><th>Strike %</th><th>In-zone %</th><th>BF</th><th>K/BB/H</th><th>Avg velo</th></tr></thead>
      <tbody>${body}</tbody>
    </table></div>
  </section>`
}

// ---------- 7. Results by count ----------
function renderByCount(p: GameReportPayload): string {
  const rows = computeGameByCount(p.pitches)
  if (!rows) return ''
  const body = rows.map(r => `<tr>
    <td>${escapeHtml(r.label)}</td><td>${r.pitches}</td><td>${r.strikePct ?? '—'}%</td><td>${r.inPlay.h}/${r.inPlay.out}/${r.inPlay.e}</td>
    <td>${r.ended.k}/${r.ended.bb}/${r.ended.h}/${r.ended.other}</td>
  </tr>`).join('')
  const lead = computeLeadoffReached(p.pitches, p.events ?? [])   // Release 2 (E7)
  return `
  <section class="section">
    <h2>Results by count</h2>
    <div class="table-scroll"><table class="data-table">
      <thead><tr><th>Count</th><th>Pitches</th><th>Strike %</th><th>In-play H/Out/E</th><th>Ended K/BB/H/other</th></tr></thead>
      <tbody>${body}</tbody>
    </table></div>
    ${lead.innings ? `<p class="caption">Leadoff batter reached base in ${lead.reached} of ${lead.innings} inning${lead.innings === 1 ? '' : 's'}.</p>` : ''}
  </section>`
}

// ---------- 8. vs RHB / vs LHB ----------
function renderPerSide(p: GameReportPayload): string {
  const allTypes = allTypesOf(p)
  const r = computeGamePerSideBlock(p.pitches, 'R', p.gridSize)
  const l = computeGamePerSideBlock(p.pitches, 'L', p.gridSize)
  const excluded = computeGameExcludedNullSide(p.pitches)
  if (!r && !l) return ''
  const block = (b: NonNullable<typeof r>) => {
    const label = b.side === 'R' ? 'vs Right-Handed Batters' : 'vs Left-Handed Batters'
    const grid = drawGrid({
      gridSize: p.gridSize, batterSide: b.side,
      pitches: b.pitches.map(x => ({ row: x.actualRow, col: x.actualCol, type: x.type })),
      allTypes
    })
    const zoneList = Object.entries(b.zoneCounts)
      .sort((a, c) => Number(a[0]) - Number(c[0]))
      .map(([num, count]) => `<li>${num} (${escapeHtml(ZONE_NAMES[Number(num)] ?? String(num))}): ${count}</li>`)
      .join('')
    // U14: an Intent game's pitches carry a hit kind -- one accuracy number and the exact / RA grids per pitch type
    const scored = b.pitches.filter(x => !!x.accuracyHitKind)
    const accLine = scored.length
      ? ` · ${Math.round(100 * scored.filter(x => x.accuracyHitKind === 'exact' || x.accuracyHitKind === 'ra').length / scored.length)}% accurate` : ''
    const hitGrids = scored.length ? drawHitTypeGrids({ gridSize: p.gridSize, batterSide: b.side, allTypes, raOn: !!p.raOn,
      pitches: scored.map(x => ({ type: x.type, row: x.actualRow, col: x.actualCol, kind: x.accuracyHitKind as 'exact' | 'ra' | 'miss' })) }) : ''
    return `
    <div class="side-block">
      <h3>${label}</h3>
      <p class="side-stats">${b.total} pitches · ${b.battersFaced} BF · ${b.strikePct ?? '—'}% strikes · ${b.inZonePct}% in-zone · ${b.whiffPct ?? '—'}% whiff · ${b.k}/${b.bb}/${b.h} K/BB/H${accLine}</p>
      <div class="grid-row">${grid}${drawLegend(allTypes)}
        <div class="side-lists"><div><strong>Location (by zone)</strong><ul>${zoneList || '<li>No pitches landed in the strike zone.</li>'}</ul></div></div>
      </div>${hitGrids}
    </div>`
  }
  const excludedNote = excluded
    ? `<p class="caption">${excluded} pitch${excluded === 1 ? '' : 'es'} recorded no batter side and ${excluded === 1 ? 'is' : 'are'} excluded below.</p>` : ''
  return `
  <section class="section">
    <h2>By batter side</h2>
    ${excludedNote}
    ${r ? block(r) : ''}
    ${l ? block(l) : ''}
  </section>`
}

// ---------- 9. Velocity ----------
function renderVelocity(p: GameReportPayload): string {
  const allTypes = allTypesOf(p)
  const vd = computeVelocityDepth(p.pitches as unknown as Parameters<typeof computeVelocityDepth>[0], allTypes)
  if (!vd.hasVelo) return ''
  const rows = vd.perType.map(t => {
    const count = t.thin ? ` (${t.count})` : ''
    return `<tr><td><span class="dot" style="background:${colorForType(t.type, allTypes)}"></span>${escapeHtml(t.type)}${count}</td>
      <td>${fmtVelo(t.avg)}</td><td>${fmtVelo(t.peak)}</td><td>${t.range} mph</td></tr>`
  }).join('')

  const byInning = computeGameVelocityByInning(p.pitches).filter(x => x.hasVelo)
  const inningRows = byInning.map(x => `<tr><td>${x.inning}</td><td>${fmtVelo(x.avg)}</td><td>${fmtVelo(x.peak)}</td></tr>`).join('')

  let driftChart = ''
  if (vd.drift.length >= 2) {
    const velos = vd.drift.map(d => d.velo as number)
    const lo = Math.floor(Math.min(...velos) / 5) * 5, hi = Math.ceil(Math.max(...velos) / 5) * 5
    const range = Math.max(1, hi - lo)
    const byType: Record<string, (number | null)[]> = {}
    for (const t of allTypes) byType[t] = vd.drift.map(d => d.type === t ? ((d.velo as number) - lo) / range : null)
    const series = allTypes.filter(t => vd.drift.some(d => d.type === t)).map(t => ({ label: t, color: colorForType(t, allTypes), points: byType[t] }))
    const chart = drawLineChart({ series, xLabels: vd.drift.map((_, i) => String(i + 1)), yAxisLabels: [String(lo), String(Math.round((lo + hi) / 2)), String(hi)] })
    driftChart = `<div class="drift"><h3>Velocity by pitch order</h3>${chart}<p class="caption">Each point is one gunned pitch, in the order it was thrown, whole mph.</p></div>`
  }

  return `
  <section class="section">
    <h2>Velocity</h2>
    <div class="table-scroll"><table class="data-table">
      <thead><tr><th>Type</th><th>Average</th><th>Peak</th><th>Range</th></tr></thead>
      <tbody>${rows}</tbody>
    </table></div>
    ${inningRows ? `
    <h3 style="margin-top:14px;">By inning</h3>
    <div class="table-scroll"><table class="data-table">
      <thead><tr><th>Inning</th><th>Average</th><th>Peak</th></tr></thead>
      <tbody>${inningRows}</tbody>
    </table></div>` : ''}
    ${driftChart}
  </section>`
}

// ---------- 10. Recent bullpens vs this game ----------
function renderRecentPens(p: GameReportPayload): string {
  const allTypes = allTypesOf(p)
  const gameByType = computeGameByType(p.pitches, allTypes, p.gridSize)
  const rows = computeRecentPensComparison(p.recentPens, gameByType)
  if (!rows || !rows.length) return ''
  const body = rows.map(r => `<tr>
    <td><span class="dot" style="background:${colorForType(r.type, allTypes)}"></span>${escapeHtml(r.type)}</td>
    <td>${r.penUsagePct}%</td><td>${r.penStrikePct ?? '—'}%</td><td>${r.penCommandPct ?? '—'}% (${r.penCommandLabel})</td>
    <td>${r.gameUsagePct}%</td><td>${r.gameInZonePct}%</td><td>${r.gameStrikePct ?? '—'}%</td><td>${r.gameWhiffPct ?? '—'}%</td>
  </tr>`).join('')
  return `
  <section class="section">
    <h2>Recent bullpens vs this game</h2>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr>
        <th>Type</th><th>Pen usage</th><th>Pen strike % (location)</th><th>Pen command %</th>
        <th>Game usage</th><th>Game in-zone %</th><th>Game strike % (result)</th><th>Game whiff %</th>
      </tr></thead>
      <tbody>${body}</tbody>
    </table></div>
    <p class="caption">Pen strike % and game in-zone % are the same measurement -- where the pitch landed -- taken on two different days. Descriptive only: this table doesn't say whether command "carried over," just what each day looked like. "Recent" means this pitcher's last 5 bullpen sessions before this game's date.</p>
  </section>`
}

// ---------- 11. Trends across games ----------
function renderGameTrends(p: GameReportPayload): string {
  const trend = computeGameTrends(p.gameTrend)
  if (!trend) return ''
  const xLabels = trend.map(h => h.dateLabel)
  const strikeSeries = trend.map(h => safeNum(h.strikePct))
  const fpsSeries = trend.map(h => safeNum(h.firstPitchStrikePct))
  const veloSeries = trend.map(h => h.hasVelo ? safeNum(h.avgVelo) : null)
  const pitchSeries = trend.map(h => safeNum(h.pitches))

  const pctChart = drawLineChart({
    series: [
      { label: 'Strike %', color: 'var(--kr-accent)', points: strikeSeries.map(v => v === null ? null : v / 100) },
      { label: 'First-pitch strike %', color: '#22B573', points: fpsSeries.map(v => v === null ? null : v / 100) }
    ],
    xLabels, yAxisLabels: ['0%', '50%', '100%']
  })
  const veloValues = veloSeries.filter((v): v is number => v !== null)
  const anyVelo = veloValues.length > 0
  const vLo = anyVelo ? Math.floor(Math.min(...veloValues) / 5) * 5 : 0
  const vHi = anyVelo ? Math.ceil(Math.max(...veloValues) / 5) * 5 : 1
  const vRange = Math.max(1, vHi - vLo)
  const veloChart = anyVelo ? drawLineChart({
    series: [{ label: 'Avg velocity', color: '#FF6B35', points: veloSeries.map(v => v === null ? null : (v - vLo) / vRange) }],
    xLabels, yAxisLabels: [String(vLo), String(Math.round((vLo + vHi) / 2)), String(vHi)]
  }) : ''
  const maxCount = Math.max(1, ...pitchSeries.filter((v): v is number => v !== null))
  const countChart = drawLineChart({
    series: [{ label: 'Pitch count', color: '#3D8BFF', points: pitchSeries.map(v => v === null ? null : v / maxCount) }],
    xLabels, yAxisLabels: ['0', String(Math.round(maxCount / 2)), String(maxCount)]
  })
  const kbbhRows = trend.map(h => `<tr><td>${escapeHtml(h.dateLabel)}</td><td>${h.k}</td><td>${h.bb}</td><td>${h.h}</td></tr>`).join('')

  return `
  <section class="section">
    <h2>Trends (last ${trend.length} games)</h2>
    <div class="trend-grid">
      <div><h3>Strike % and first-pitch strike %</h3>${pctChart}</div>
      ${anyVelo ? `<div><h3>Average velocity</h3>${veloChart}</div>` : ''}
      <div><h3>Pitch count</h3>${countChart}</div>
    </div>
    <div class="table-scroll" style="margin-top:12px;"><table class="data-table">
      <thead><tr><th>Date</th><th>K</th><th>BB</th><th>H</th></tr></thead><tbody>${kbbhRows}</tbody>
    </table></div>
  </section>`
}

// ---------- G3: Other events ----------
// One row per no-pitch event (inning · count before · event), sport labels,
// and a total line. An illegal pitch's own ball rides on its row. Omitted
// entirely when there are none, so those reports are byte-identical.
// Joel, Oct 12: runner moves between pitches (dragged or tapped on the field) are listed too.
const OTHER_EVENT_TYPES = ['intentional_walk', 'balk', 'auto_ball', 'auto_strike', 'illegal_pitch', 'tiebreak_runner',
  'stolen_base', 'caught_stealing', 'pickoff', 'wild_pitch', 'passed_ball', 'other']
function otherEventLabel(e: GameEvent, softball: boolean): string {
  switch (e.eventType) {
    case 'intentional_walk': return 'IBB'
    case 'balk': return softball ? 'Illegal pitch (ADV)' : 'Balk'
    case 'auto_ball': return 'Auto ball'
    case 'auto_strike': return 'Auto strike'
    case 'illegal_pitch': return (Array.isArray(e.runnerAdvances) && e.runnerAdvances.length) ? 'Illegal pitch (ADV)' : 'Illegal pitch (no ADV)'
    case 'tiebreak_runner': return 'Tiebreak runner on 2B'
    case 'stolen_base': return 'Stolen base'
    case 'caught_stealing': return 'Caught stealing'
    case 'pickoff': return 'Pickoff'
    case 'wild_pitch': return 'Wild pitch'
    case 'passed_ball': return 'Passed ball'
    case 'other': return 'Runner moved (other)'
    default: return e.eventType
  }
}
function renderOtherEvents(p: GameReportPayload): string {
  const softball = asSport(p.sport) === 'softball'
  const evs = (p.events ?? []).filter(e => OTHER_EVENT_TYPES.includes(e.eventType))
  const rows: { e: GameEvent; label: string }[] = []
  for (let i = 0; i < evs.length; i++) {
    const e = evs[i]
    const prev = rows.length ? rows[rows.length - 1].e : null
    const pairsWithPrev = e.eventType === 'auto_ball' && prev && prev.atBatIndex === e.atBatIndex &&
      (prev.eventType === 'illegal_pitch' || (softball && prev.eventType === 'balk')) &&
      (prev.seq === null || e.seq === null || e.seq === prev.seq + 1)
    if (pairsWithPrev) continue
    rows.push({ e, label: otherEventLabel(e, softball) })
  }
  if (!rows.length) return ''
  const counts: [string, number][] = []
  for (const r of rows) {
    const c = counts.find(x => x[0] === r.label)
    if (c) c[1]++; else counts.push([r.label, 1])
  }
  const count = (e: GameEvent) => (e.ballsBefore === null || e.strikesBefore === null) ? '—' : `${e.ballsBefore}-${e.strikesBefore}`
  const body = rows.map(r => `<div class="ab-row"><span class="ab-num">Inning ${r.e.inningBefore ?? '—'} · ${count(r.e)}</span> ${escapeHtml(r.label)}</div>`).join('')
  const total = `${rows.length} other event${rows.length === 1 ? '' : 's'}: ${counts.map(([l, n]) => `${n} ${escapeHtml(l)}`).join(', ')}`
  return `
  <section class="section">
    <h2>Other events</h2>
    <p class="caption">${total}</p>
    ${body}
  </section>`
}

// ---------- 12. At-bat log ----------
function renderAtBatLog(p: GameReportPayload): string {
  const log = computeAtBatLog(p.pitches, p.events ?? [])
  if (!log.length) return ''
  const byInning = new Map<number, typeof log>()
  for (const ab of log) {
    if (!byInning.has(ab.inning)) byInning.set(ab.inning, [])
    byInning.get(ab.inning)!.push(ab)
  }
  const innings = Array.from(byInning.keys()).sort((a, b) => a - b)
  const body = innings.map(inning => {
    const abs = byInning.get(inning)!.map(ab => {
      const sideLabel = ab.side === 'R' ? 'R' : ab.side === 'L' ? 'L' : '—'
      // S2 (Joel, Oct 1): softball has no Set/Windup, so its at-bats show the side only.
      const deliveryLabel = asSport(p.sport) === 'softball' ? '' : ab.delivery === 'set' ? 'Set' : ab.delivery === 'windup' ? 'Windup' : '—'
      const seq = ab.pitches.map(pt => {
        const g = resultGlyph(pt)
        const veloBit = pt.velo !== null && pt.velo !== undefined ? `${escapeHtml(pt.type)} ${Math.round(pt.velo)}` : escapeHtml(pt.type)
        const ttpBit = typeof pt.timeToPlate === 'number' ? ` ⏱${pt.timeToPlate.toFixed(2)}` : ''   // U11 (7)
        return `${veloBit} ${g.glyph}${g.label ? ' ' + g.label : ''}${ttpBit}`
      }).join(' · ')
      const ending = ab.incomplete ? 'incomplete' : escapeHtml(ab.ending)
      // Release 2 (E6): the runners' moves (with why) and the runs, after the ending
      const detail = ab.detail ? ` <span class="ab-detail" style="opacity:.75;">— ${escapeHtml(ab.detail)}</span>` : ''
      return `<div class="ab-row"><span class="ab-num">#${ab.atBatIndex} (${sideLabel}${deliveryLabel ? ', ' + deliveryLabel : ''})</span> ${seq} <span class="ab-ending">${ending}</span>${detail}</div>`
    }).join('')
    return `<div class="ab-inning"><h3>Inning ${inning}</h3>${abs}</div>`
  }).join('')
  return `
  <section class="section">
    <h2>At-bat log</h2>
    ${body}
    <p class="caption">● called · ○ ball · ✕ swing and miss · ◐ foul · ■ in play · ★ HBP · ▲ sacrifice · — other. Plain glyphs, no color dependence -- readable printed in black and white.</p>
  </section>`
}

const GAME_CSS = `
  .ab-inning{ margin:14px 0; }
  .ab-row{ font-size:12px; padding:4px 0; border-bottom:1px solid var(--kr-hair); }
  .ab-num{ font-weight:700; color:var(--kr-ink-dim); margin-right:6px; }
  .ab-ending{ float:right; font-weight:700; color:var(--kr-ink); }
`

// ---------- SR1 Stage C: the answer-first game report (coach version) ----------
// SR1 E: each version's tabs (decision 10). Panels: 1 Summary · 2 Location · 3 Batters · 4 Pitch types · 5 Trends ·
// 6 Every pitch · 7 Where it went · 8 Progress without velocity (7 and 8: little league player only)
function gameTabLabels(g: LevelGroup) {
  const full = g === 'college' ? ['coach', 'player'] : ['coach']
  return [
    { panel: 1, label: 'Summary', versions: versionsFor(g) },
    { panel: 2, label: 'Location', versions: g === 'hs' ? ['coach', 'player'] : full },
    { panel: 3, label: 'Batters', versions: g === 'hs' ? ['coach', 'player'] : full },
    { panel: 4, label: 'Pitch types', versions: full },
    { panel: 5, label: 'Trends', versions: full },
    ...(g === 'hs' ? [{ panel: 5, label: 'Progress', versions: ['player'] }] : []),
    { panel: 6, label: 'Every pitch', versions: full },
    ...(g === 'll' ? [{ panel: 7, label: 'Where it went', versions: ['player'] }, { panel: 8, label: 'Progress', versions: ['player'] }, { panel: 5, label: 'Progress', versions: ['parent'] }] : [])
  ]
}
const G_STRIKES = new Set(['strike_looking', 'strike_swinging', 'foul', 'foul_tip', 'in_play', 'sac_bunt', 'sac_fly', 'dropped_third'])
const gStrike = (x: GamePitch) => G_STRIKES.has(x.result)
const gCounts = (x: GamePitch) => x.result !== 'interference' && x.result !== 'other'
const gHit = (x: GamePitch) => x.result === 'in_play' && x.inPlayOutcome === 'hit'
function gameDate(p: GameReportPayload): string {
  return new Date(p.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}
function gameHeader(p: GameReportPayload, id: string, g: LevelGroup): string {
  const numBit = p.uniformNumber !== null && p.uniformNumber !== undefined ? ` <span class="header-num">#${escapeHtml(p.uniformNumber)}</span>` : ''
  return `
  <header class="report-header kr-head">
    <div class="kr-head-top"><div class="brand-mark">KNUCKLEBALL</div><span class="sport-tag">${asSport(p.sport) === 'softball' ? 'Softball' : 'Baseball'} · Live Game</span></div>
    <h1>${escapeHtml(p.pitcherName)}${numBit}</h1>
    <p class="header-meta">${gameDate(p)}${p.opponent ? ` vs ${escapeHtml(p.opponent)}` : ''}${p.teamName ? ' · ' + escapeHtml(p.teamName) : ''}</p>
    ${tabBarVersions(id, gameTabLabels(g))}
  </header>`
}
function gameFacts(p: GameReportPayload) {
  const ps = p.pitches, s = p.summary, allTypes = allTypesOf(p)
  const thrown = allTypes.filter(t => ps.some(x => x.type === t))
  const fb = pickFastball(ps)
  const log = computeAtBatLog(ps, p.events ?? []).filter(e => e.pitches.length > 0)
  const done = log.filter(e => !e.incomplete)
  // Two of the first three for strikes (Joel, Nov 19): two of a batter's first three pitches were strikes, or the
  // at-bat ended on a strike before the third pitch
  const twoOfThree = done.filter(e => {
    const f3 = e.pitches.slice(0, 3)
    return f3.filter(gStrike).length >= 2 || (e.pitches.length < 3 && gStrike(e.pitches[e.pitches.length - 1]))
  }).length
  const innings = Array.from(new Set(ps.map(x => x.inning))).filter(i => typeof i === 'number').sort((a, b) => a - b).map(inn => {
    const ip = ps.filter(x => x.inning === inn), den = ip.filter(gCounts).length
    return { inning: inn, n: ip.length, strikes: ip.filter(x => gStrike(x) && gCounts(x)).length, den, strikePct: pctOf(ip.filter(x => gStrike(x) && gCounts(x)).length, den),
      fbVelo: fb.type ? avgVelo(ip.filter(x => x.type === fb.type)) : null }
  })
  const byType = thrown.map(t => {
    const tp = ps.filter(x => x.type === t), den = tp.filter(gCounts).length
    return { type: t, n: tp.length, strikes: tp.filter(x => gStrike(x) && gCounts(x)).length, den, velo: avgVelo(tp),
      k: done.filter(e => e.ending.startsWith('K') && e.pitches[e.pitches.length - 1].type === t).length }
  })
  return { ps, s, allTypes, thrown, fb, log, done, twoOfThree, innings, byType,
    fbVelo: fb.type ? avgVelo(ps.filter(x => x.type === fb.type)) : null, anyVelo: ps.some(x => gunned(x.velo)) }
}
type GameFacts = ReturnType<typeof gameFacts>

const gWhose = (p: GameReportPayload, v: Voice) => v === 'you' ? 'your' : escapeHtml(firstName(p.pitcherName)) + "'s"
function gameStoodOut(p: GameReportPayload, f: GameFacts, c: Comparison, v: Voice = 'coach'): StoodOut[] {
  const ws = c.baselines?.windows?.['3m']
  const who = gWhose(p, v)
  const s = f.s, items: StoodOut[] = []
  const rate = (metric: string, cur: number | null, range: [number, number] | undefined, minW: number, text: (dir: string, r: string) => string, unit: string, neutral = false) => {
    const o = outsideRange(cur, range, minW)
    if (!o || !range || cur === null) return
    items.push({ kind: 'rate', metric, value: cur, dir: o.dir, size: o.size, mark: neutral ? 'info' : o.dir === 'above' ? 'up' : 'down', text: text(o.dir, rangeText(range, unit)) })
  }
  if (ws?.range) {
    rate('strike', s.strike_pct, ws.range.strike_pct, 5, (d, r) => `Strikes ${s.strike_pct}% of ${s.strike_pct_denominator} pitches, ${d} ${who} normal range (${r}).`, '%')
    const fpN = Math.round((s.first_pitch_strike_pct ?? 0) * s.first_pitch_pitches / 100)
    rate('fp', s.first_pitch_strike_pct, ws.range.fp_strike_pct, 5, (d, r) => `First pitch was a strike to ${fpN} of ${s.first_pitch_pitches} batters (${s.first_pitch_strike_pct}%), ${d} ${who} normal range (${r}).`, '%')
    rate('zone', s.in_zone_pct, ws.range.in_zone_pct, 5, (d, r) => `${s.in_zone} of ${s.pitches} pitches in the zone (${s.in_zone_pct}%), ${d} ${who} normal range (${r}).`, '%')
    rate('pitches', pitchCount(s), ws.range.pitches, 5, (d, r) => `${pitchCount(s)} pitches, ${d === 'above' ? 'more' : 'fewer'} than ${who} normal range (${r}).`, '', true)
  }
  for (const t of f.byType) {
    const tr = ws?.types?.[t.type]?.range
    if (!tr) continue
    if (t.n >= typeMin) rate('type', pctOf(t.strikes, t.den), tr.strike_pct, 5, (d, r) => `${v === 'you' ? 'Your ' + escapeHtml(t.type.toLowerCase()) : escapeHtml(t.type)} strikes ${pctOf(t.strikes, t.den)}% (${t.strikes} of ${t.den}), ${d} ${who} normal range (${r}).`, '%')
    if (t.type === f.fb.type && f.fbVelo !== null) rate('velo', f.fbVelo, tr.velo, 1, (d, r) => `${v === 'you' ? 'Your ' : ''}${escapeHtml(f.fb.label)} averaged ${f.fbVelo} mph, ${d} ${who} normal range (${r} mph).`, 'mph')
  }
  const sr = ws?.range?.strike_pct
  if (sr) {
    const inn = f.innings.filter(i => i.n >= inningMin && i.strikePct !== null)
      .map(i => ({ i, o: outsideRange(i.strikePct, sr, 5) })).filter(x => x.o).sort((a, b) => b.o!.size - a.o!.size)[0]
    if (inn) {
      const one = f.innings[0]
      const velo = inn.i.fbVelo !== null && one && one.fbVelo !== null && inn.i.inning !== one.inning && Math.round(one.fbVelo - inn.i.fbVelo) >= 1
        ? ` and ${escapeHtml(f.fb.label)} ${Math.round(one.fbVelo - inn.i.fbVelo)} mph under the ${ordinal(one.inning)} (${Math.round(one.fbVelo)} → ${Math.round(inn.i.fbVelo)})` : ''
      items.push({ kind: 'inning', metric: velo ? 'velo-inning' : 'inning', mark: 'info', size: inn.o!.size, inning: inn.i.inning, dir: inn.o!.dir, value: inn.i.strikePct!,
        text: `${ordinal(inn.i.inning)} inning: ${inn.i.strikePct}% strikes${velo}.` })
    }
  }
  const cl = clusterPattern(f.ps.filter(gHit)); if (cl) items.push(cl)
  const side = sidePattern(f.ps.filter(gCounts), gStrike as (p: never) => boolean); if (side) items.push(side)
  return sortStoodOut(items)
}

function gameRank(f: GameFacts, c: Comparison): { k: number; best: boolean; worst: boolean } {
  const s = f.s, k = Math.min(6, 1 + c.recent.length)
  if (k < 4 || s.strike_pct_denominator < 10) return { k, best: false, worst: false }
  const prior = c.recent.slice(0, k - 1).map(r => r.game && r.game.strike_pct_denominator ? 100 * r.game.strikes / r.game.strike_pct_denominator : 0)
  return { k, best: s.strike_pct > Math.max(...prior), worst: s.strike_pct < Math.min(...prior) }
}
function gameHeadline(p: GameReportPayload, f: GameFacts, c: Comparison, items: StoodOut[], v: Voice = 'coach'): string {
  const s = f.s
  const rateItem = items.find(i => i.kind === 'rate' && (i.metric === 'fp' || i.metric === 'strike' || i.metric === 'zone'))
  const inn = items.find(i => i.kind === 'inning')
  if (rateItem && inn) {
    const name = rateItem.metric === 'fp' ? 'First-pitch strikes' : rateItem.metric === 'zone' ? 'In-zone pitches' : 'Strikes'
    const up = rateItem.dir === 'above', innUp = inn.dir === 'above'
    return `${name} ${up ? 'up' : 'down'} to ${rateItem.value}%, ${up === innUp ? 'and' : 'but'} ${v === 'you' ? 'your ' : ''}strikes ${innUp ? 'rose' : 'faded'} to ${inn.value}% in the ${ordinal(inn.inning ?? 0)}.`
  }
  const r = gameRank(f, c)
  if (r.best) return `${v === 'you' ? 'Your best' : 'Best'} strike-throwing game of the last ${word(r.k)}: ${s.strike_pct}% strikes.`
  if (r.worst) return `${s.strike_pct}% strikes, ${v === 'you' ? 'your' : 'the'} fewest of the last ${word(r.k)} games.`
  if (items.length) return items[0].text
  return `${fmtIP(s.outs_recorded)} innings, ${pitchCount(s)} pitches: ${s.strike_pct}% strikes${s.first_pitch_strike_pct !== null ? `, ${s.first_pitch_strike_pct}% first-pitch strikes` : ''}.`
}

function gameStrip(s: GameSummary): string {
  return `<div class="kr-strip">${[[fmtIP(s.outs_recorded), 'IP'], [String(pitchCount(s)), 'P'], [String(s.k), 'K'], [String(s.bb), 'BB'], [String(s.h), 'H'], [s.runs != null ? String(s.runs) : '—', 'R']]
    .map(([v, l]) => `<div><b>${v}</b><span>${l}</span></div>`).join('')}</div>`
}
function gameWindows(p: GameReportPayload, c: Comparison, id: string, tiles: TileSpec[], v: Voice): string {
  const first = firstName(p.pitcherName)
  const wins = c.baselines ? WINDOWS.map(w => w.key).filter(k => c.baselines!.windows[k]) : []
  return wins.length
    ? windowSwitch(id, wins) + wins.map(k => wb(k, windowCaption(first, k, c.baselines!.windows[k], 'game', '', v)
        + `<div class="kr-tiles">${tiles.map(t => tileFor(t, c.baselines!.windows[k], 'game')).join('')}</div>`)).join('')
    : `<div class="kr-tiles">${tiles.map(t => tileFor(t, undefined, 'game')).join('')}</div><p class="kr-wcap">No earlier games to compare with yet.</p>`
}
function gameTiles(f: GameFacts): TileSpec[] {
  const s = f.s
  return [
    { label: 'Strike %', cur: s.strike_pct, unit: '%', key: 'strike_pct' },
    { label: '1st-pitch strike', cur: s.first_pitch_strike_pct, unit: '%', key: 'fp_strike_pct' },
    { label: '2 of first 3', cur: pctOf(f.twoOfThree, f.done.length), unit: '%', key: 'two_of_three', plain: true, sub: `${f.twoOfThree} of ${f.done.length} batters` },
    { label: 'In zone', cur: s.in_zone_pct, unit: '%', key: 'in_zone_pct' }
  ]
}
// SR1 Stage F: each version's email (e01), frozen into the report; the bullets never repeat the headline
const gBullets = (items: StoodOut[], headline: string) => items.filter(i => i.text !== headline).slice(0, 2).map(i => i.text)
function gameEmails(p: GameReportPayload, f: GameFacts, c: Comparison, g: LevelGroup, items: StoodOut[], itemsYou: StoodOut[]): Record<string, EmailVersion> {
  const s = f.s, name = p.pitcherName, first = escapeHtml(firstName(name)), date = shortDate(p.date), ip = fmtIP(s.outs_recorded), r = gameRank(f, c)
  const four = [{ v: `${s.strike_pct}%`, l: 'Strike' }, { v: s.first_pitch_strike_pct === null ? '—' : `${s.first_pitch_strike_pct}%`, l: '1st pitch' }, { v: `${s.k} / ${s.bb}`, l: 'K / BB' }, { v: String(pitchCount(s)), l: 'Pitches' }]
  const subject = `Game report: ${name} · ${ip} IP, ${s.k} K · ${date}`
  const rest = restEmailLine(c.workload, pitchCount(s), p.date)
  const lines = (who: string, kid = false) => [rest, sevenDayEmailLine(c.workload, kid), who ? comparedEmailLine(c, who, 'game') : null].filter(Boolean) as EmailVersion['lines']
  const out: Record<string, EmailVersion> = {
    coach: { subject, headline: gameHeadline(p, f, c, items), stats: four, bullets: gBullets(items, gameHeadline(p, f, c, items)), lines: lines(first + "'s"), button: 'Open the full report' }
  }
  const youSubject = `Your game report: ${ip} IP, ${s.k} K · ${date}`
  if (g === 'll') {
    out.player = { subject: youSubject, headline: s.k ? `You pitched ${ip} innings and struck out ${s.k}!` : `You pitched ${ip} innings and threw ${s.strike_pct}% strikes.`,
      stats: [{ v: `${s.strike_pct}%`, l: 'Strikes' }, { v: s.first_pitch_strike_pct === null ? '—' : `${s.first_pitch_strike_pct}%`, l: '1st pitch' }, { v: String(s.k), l: 'K' }],
      bullets: [], lines: lines('', true), button: 'See where every pitch went' }
    out.parent = { subject, headline: `${ip} innings, ${s.k} strikeout${s.k === 1 ? '' : 's'}, ${s.bb} walk${s.bb === 1 ? '' : 's'}${p.opponent ? ` against ${escapeHtml(p.opponent)}` : ''}.`,
      stats: [{ v: ip, l: 'IP' }, { v: String(s.k), l: 'K' }, { v: String(s.bb), l: 'BB' }, { v: String(pitchCount(s)), l: 'Pitches' }],
      bullets: [`${s.strike_pct}% strikes${r.best ? `, ${first}'s best in the last ${word(r.k)} games` : ''}.`], lines: lines(first + "'s"), button: 'Open the full report' }
  } else {
    out.player = { subject: youSubject, headline: gameHeadline(p, f, c, itemsYou, 'you'), stats: four, bullets: gBullets(itemsYou, gameHeadline(p, f, c, itemsYou, 'you')), lines: lines('your'), button: 'Open the full report' }
  }
  return out
}
function gameCaptions(p: GameReportPayload): string {
  const note = viewNote(p.chartingPerspective).replace('class="header-note"', 'class="caption"')
  return (note || `<p class="caption">Every grid in this report is drawn in the ${VIEW_NAME}, ${REPORT_VIEW === 'pitcher' ? 'looking in from the mound toward home plate' : 'looking out toward the mound'}.</p>`)
    + `<p class="caption">A strike is: called strike, swinging strike, foul, any ball in play, sac bunt/fly, dropped third. A ball is: ball, HBP. Interference and "other" count toward pitches but neither bucket.</p>`
}
// The full Summary: the coach's, and in "you" for a high school (top two items) or college player
function gameSummaryTab(p: GameReportPayload, f: GameFacts, c: Comparison, id: string, items: StoodOut[], v: Voice = 'coach', maxItems = 3): string {
  const s = f.s
  const chartedBy = p.loggedByCoach ? 'the coaching staff' : escapeHtml(p.pitcherName)
  const head = card('', `<h2 class="kr-headline">${gameHeadline(p, f, c, items, v)}</h2>
    <p class="kr-sub">${gameDate(p)}${p.opponent ? ` vs ${escapeHtml(p.opponent)}` : ''} · ${s.batters_faced} batter${s.batters_faced === 1 ? '' : 's'} · charted by ${chartedBy}</p>`)
  const hlInning = items.find(i => i.kind === 'inning')?.inning
  const inningTable = f.innings.length ? card('By inning', simpleTable(['Inn', 'Pitches', 'Strike', `${escapeHtml(f.fb.label)} mph`],
    f.innings.map(i => [String(i.inning), String(i.n), i.strikePct === null ? '—' : `${i.strikePct}%`, i.fbVelo === null ? '—' : String(Math.round(i.fbVelo))]),
    f.innings.findIndex(i => i.inning === hlInning))) : ''
  return head + gameStrip(s) + gameWindows(p, c, id, gameTiles(f), v) + inningTable
    + stoodOutCard(items.slice(0, maxItems), !!c.baselines?.windows?.['3m']?.range, firstName(p.pitcherName), 'What stood out', v)
    + restCard(c.workload, pitchCount(s), p.date, p.teamName === 'Independent') + sevenDayCard(c.workload) + gameCaptions(p)
}
// Little league player (g09): two numbers, what went well, no velocity anywhere
function gameSummaryLLPlayer(p: GameReportPayload, f: GameFacts, c: Comparison, id: string, itemsYou: StoodOut[]): string {
  const s = f.s
  const head = card('', `<h2 class="kr-headline">${s.k ? `You pitched ${fmtIP(s.outs_recorded)} innings and struck out ${s.k}!` : `You pitched ${fmtIP(s.outs_recorded)} innings and threw ${s.strike_pct}% strikes.`}</h2>
    <p class="kr-sub">${gameDate(p)}${p.opponent ? ` vs ${escapeHtml(p.opponent)}` : ''}</p>`)
  const well = itemsYou.filter(i => i.mark === 'up' && i.metric !== 'velo' && i.metric !== 'velo-inning')
  const fpN = Math.round((s.first_pitch_strike_pct ?? 0) * s.first_pitch_pitches / 100)
  const fallback: StoodOut[] = s.first_pitch_pitches ? [{ mark: 'up', kind: 'rate', size: 0, text: `You threw a strike on the first pitch to ${fpN} of ${s.first_pitch_pitches} batters.` }] : []
  return head + gameWindows(p, c, id, gameTiles(f).slice(0, 2), 'you')
    + stoodOutCard(well.length ? well : fallback, true, firstName(p.pitcherName), 'What went well', 'you')
    + restCard(c.workload, pitchCount(s), p.date, p.teamName === 'Independent') + sevenDayCard(c.workload, true)
    + `<p class="kr-novelo">No velocity on this version. Your coach and parents can see it.</p>`
}
// Little league parent (g11): rest and workload first, one line on how it went, the line strip
function gameSummaryLLParent(p: GameReportPayload, f: GameFacts, c: Comparison): string {
  const s = f.s, first = escapeHtml(firstName(p.pitcherName)), r = gameRank(f, c)
  const ip = fmtIP(s.outs_recorded)
  const how = card('How it went', `<h2 class="kr-headline">${ip} innings, ${s.k} strikeout${s.k === 1 ? '' : 's'}, ${s.bb} walk${s.bb === 1 ? '' : 's'}${p.opponent ? ` against ${escapeHtml(p.opponent)}` : ''}.</h2>
    <p class="kr-sub">${s.strike_pct}% strikes${r.best ? `, ${first}'s best in the last ${word(r.k)} games` : ''}.</p>`)
  return restCard(c.workload, pitchCount(s), p.date, p.teamName === 'Independent') + sevenDayCard(c.workload) + how + gameStrip(s)
}
// Little league player: Where it went (location by result and by type; no velocity) and Progress without velocity
function gameWhereItWent(p: GameReportPayload, f: GameFacts): string {
  return takeaway(`Where your pitches went: ${f.s.in_zone} of ${f.s.pitches} in the zone`) + renderLocationCharts(p) + renderTypeGrids(p)
}
function gameProgressLite(p: GameReportPayload): string {
  const t = (p.gameTrend ?? []).slice(-6)
  if (t.length < 3) return takeaway('Your progress starts once you have three games') + card('', `<p class="caption">This page draws one line per number once you have at least three games on this team.</p>`)
  const last = t[t.length - 1]
  return takeaway(`Your last ${word(t.length)} games`)
    + sparkCard('Strike %', t.map(g => safeNum(g.strikePct)), `${last.strikePct ?? 0}%`, `last ${t.length} games`)
    + sparkCard('1st-pitch strike', t.map(g => safeNum(g.firstPitchStrikePct)), `${last.firstPitchStrikePct ?? 0}%`, `last ${t.length} games`)
}

function gameLocationTab(p: GameReportPayload, f: GameFacts): string {
  const s = f.s
  return takeaway(`${s.in_zone} of ${s.pitches} pitches in the zone (${s.in_zone_pct}%)`)
    + renderLocationCharts(p) + renderTypeGrids(p) + renderPitchesThatMattered(p.pitches, allTypesOf(p), p.gridSize ?? 5)
}

function gameBattersTab(p: GameReportPayload, f: GameFacts): string {
  const groups: { label: string; b: number; h: number; k: number; bb: number }[] = []
  f.done.forEach((e, i) => {
    const g = Math.floor(i / 9)
    groups[g] ||= { label: ordinal(g + 1), b: 0, h: 0, k: 0, bb: 0 }
    const last = e.pitches[e.pitches.length - 1]
    groups[g].b++
    if (gHit(last)) groups[g].h++
    if (e.ending.startsWith('K')) groups[g].k++
    if (e.ending === 'BB' || e.ending.startsWith('IBB') || /walk/i.test(e.ending)) groups[g].bb++
  })
  let hl: string
  if (groups.length > 1) {
    const worst = groups.slice().sort((a, b) => b.h / b.b - a.h / a.b)[0]
    hl = `Hitters did the most damage ${worst.label.toLowerCase()} time through: ${worst.h} hit${worst.h === 1 ? '' : 's'} in ${worst.b}`
  } else hl = groups.length ? `${groups[0].h} hit${groups[0].h === 1 ? '' : 's'} from ${groups[0].b} batter${groups[0].b === 1 ? '' : 's'}` : 'No completed at-bats'
  const worstIdx = groups.length > 1 ? groups.indexOf(groups.slice().sort((a, b) => b.h / b.b - a.h / a.b)[0]) : -1
  const tto = groups.length ? card('', simpleTable(['Time through', 'Batters', 'Hits', 'K', 'BB'], groups.map(g => [g.label, String(g.b), String(g.h), String(g.k), String(g.bb)]), worstIdx)
    + `<p class="caption">A new time through the order every 9 batters this pitcher faced.</p>`) : ''
  const reached = (e: typeof f.done[number]) => gHit(e.pitches[e.pitches.length - 1]) || e.ending === 'BB' || e.ending.startsWith('IBB')
  const ahead = f.done.filter(e => gStrike(e.pitches[0])), behind = f.done.filter(e => !gStrike(e.pitches[0]))
  const afterFirst = f.done.length ? card('After the first pitch', simpleTable(['Count', 'Batters', 'Reached (H + BB)'],
    [['0–1 (ahead)', String(ahead.length), String(ahead.filter(reached).length)], ['1–0 (behind)', String(behind.length), String(behind.filter(reached).length)]])
    + `<p class="caption">A first pitch put in play counts as ahead.</p>`) : ''
  return takeaway(hl) + tto + afterFirst
    + renderSprayCharts(p.pitches, allTypesOf(p), asSport(p.sport)) + renderWhatLedToIt(p.pitches, allTypesOf(p), p.gridSize ?? 5)
    + renderBaseStates(p.pitches, allTypesOf(p)) + renderByCount(p) + renderPerSide(p)
}

function gamePitchTypesTab(p: GameReportPayload, f: GameFacts): string {
  const top = f.byType.slice().sort((a, b) => b.n - a.n)[0]
  const hl = top ? `${escapeHtml(top.type)} carried it: ${top.n} of ${f.ps.length}, ${pctOf(top.strikes, top.den) ?? 0}% strikes` : 'No pitches charted'
  const table = card('', simpleTable(['Pitch', '#', 'Strike', 'Avg', 'K'], f.byType.map(t => [typeCell(t.type, f.allTypes), String(t.n),
    t.den ? `${pctOf(t.strikes, t.den)}%` : '—', t.velo === null ? '—' : String(Math.round(t.velo)), String(t.k)])))
  const fbInn = f.innings.filter(i => i.fbVelo !== null)
  const fbCard = fbInn.length >= 2 ? sparkCard(`${f.fb.label} mph by inning`, fbInn.map(i => i.fbVelo), `${Math.round(fbInn[0].fbVelo!)} → ${Math.round(fbInn[fbInn.length - 1].fbVelo!)}`,
    `innings ${fbInn[0].inning}–${fbInn[fbInn.length - 1].inning}`, 'var(--kr-accent)') : ''
  return takeaway(hl) + table + fbCard + renderByType(p) + renderVelocity(p)
}

function gameTrendsTab(p: GameReportPayload): string {
  const t = (p.gameTrend ?? []).slice(-6)
  const vals = t.map(g => safeNum(g.strikePct)).filter((v): v is number => v !== null)
  const hl = vals.length >= 2 ? `Last ${word(vals.length)} games: strikes ${vals[0]}% → ${vals[vals.length - 1]}%` : 'Trends start once there are a few games'
  return takeaway(hl) + renderGameTrends(p) + renderRecentPens(p)
    + renderBullpenToGame(p.pitches, p.recentPenPitches, allTypesOf(p), p.gridSize ?? 5)
}

function gameEveryPitchTab(p: GameReportPayload, f: GameFacts): string {
  return takeaway(`${f.s.batters_faced} batter${f.s.batters_faced === 1 ? '' : 's'}, ${pitchCount(f.s)} pitches`)
    + renderPitchingLine(p) + renderOtherEvents(p) + renderAtBatLog(p)
}

export function buildGameReportHtml(p: GameReportPayload): string {
  const title = `Game Report — ${p.pitcherName}${p.opponent ? ' vs ' + p.opponent : ''}`
  const c = p.comparison ?? NO_COMPARISON
  const id = ids(p.sessionId)
  const f = gameFacts(p)
  const items = gameStoodOut(p, f, c)
  const itemsYou = gameStoodOut(p, f, c, 'you')
  const g = levelGroup(c.workload?.level ?? c.baselines?.level ?? null)   // SR1 E: the versions this file carries
  const wins = c.baselines ? WINDOWS.map(w => w.key).filter(k => c.baselines!.windows[k]) : []
  const tl = gameTabLabels(g), pt = printTitle(p.pitcherName, 'Live Game', gameDate(p), wins)   // SR1 G: print
  const links = `<p><span class="brand-mark small">Knuckleball LLC 2026</span> &middot; <a href="https://knuckleballonline.com/login.html?sport=${asSport(p.sport)}">knuckleballonline.com</a> &middot; <a href="https://knuckleballonline.com/privacy.html#${asSport(p.sport)}">Privacy</a> &middot; <a href="https://knuckleballonline.com/terms.html#${asSport(p.sport)}">Terms</a> &middot; generated ${new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}</p>`
  // D2: this report's own colors and fonts (--kr-*) for its sport -- no hex swap, no site stylesheet.
  return (`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${escapeHtml(title)}</title>
<style>${reportVars(asSport(p.sport))}${PEN_CSS}${GAME_CSS}${DIAMOND_CSS}${CONNECT_CSS}${SR1_CSS}</style>
</head>
<body>
<div class="page kr" data-kr-versions="${versionsFor(g).join(' ')}">
${radios(id, ['1', '2', '3', '4', '5', '6', '7', '8'], wins)}
${gameHeader(p, id, g)}
<main class="kr-main">
${panel(1, ver(['coach'], gameSummaryTab(p, f, c, id, items))
  + (g === 'll' ? ver(['player'], gameSummaryLLPlayer(p, f, c, id, itemsYou)) + ver(['parent'], gameSummaryLLParent(p, f, c))
    : ver(['player'], gameSummaryTab(p, f, c, id, itemsYou, 'you', g === 'hs' ? 2 : 3))), tl, pt)}
${panel(2, gameLocationTab(p, f), tl, pt)}
${panel(3, gameBattersTab(p, f), tl, pt)}
${panel(4, gamePitchTypesTab(p, f), tl, pt)}
${panel(5, gameTrendsTab(p), tl, pt)}
${panel(6, gameEveryPitchTab(p, f), tl, pt)}
${g === 'll' ? panel(7, gameWhereItWent(p, f), tl, pt) + panel(8, gameProgressLite(p), tl, pt) : ''}
</main>
${footer(firstName(p.pitcherName), links, true)}
</div>
${emailComment(gameEmails(p, f, c, g, items, itemsYou))}
</body>
</html>`)
}
