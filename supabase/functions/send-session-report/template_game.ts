// ============================================================================
// G2 -- the Live Game report template. Same rules as template.ts: one
// self-contained HTML string, inline CSS/SVG, zero JavaScript, zero
// external requests, every string escaped, every number safeNum()'d.
// Reuses template.ts's CSS verbatim (imported, not copied) plus a small
// game-only stylesheet addition below, so the two reports read as one
// product (content spec: "Same theme and typography as the pen report").
// ============================================================================
import { escapeHtml, safeNum, colorForType, timesToHomeLine, asSport, type Sport } from './helpers.ts'
import { ZONE_NAMES } from './helpers.ts'
import { drawGrid, drawLegend, drawLineChart, drawGridByResult, drawResultLegend, resultCategoryOf, drawTypeGrids } from './svg.ts'
import { CSS as PEN_CSS } from './template.ts'
import {
  type GamePitch, computeGameByType, computeGameByInning, computeGameByCount,
  computeGamePerSideBlock, computeGameExcludedNullSide, computeGameVelocityByInning,
  computeRecentPensComparison, computeGameTrends, computeAtBatLog, resultGlyph,
  type RecentPenTypeRow, type GameHistoryEntry
} from './compute_game.ts'
import { computeVelocityDepth } from './compute.ts'

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
}

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
  gameTrend: GameHistoryEntry[]
  summary: GameSummary
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

// ---------- 1. Header ----------
function renderHeader(p: GameReportPayload): string {
  const s = p.summary
  const dateStr = new Date(p.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  const numBit = p.uniformNumber !== null && p.uniformNumber !== undefined ? ` <span class="header-num">#${escapeHtml(p.uniformNumber)}</span>` : ''
  const chartedBy = p.loggedByCoach ? 'the coaching staff' : escapeHtml(p.pitcherName)
  const perspectiveNote = p.chartingPerspective === 'behind_pitcher'
    ? `<p class="header-note">Charted from behind the pitcher. Every plot in this report is still catcher's view.</p>` : ''
  const oppBit = p.opponent ? ` vs ${escapeHtml(p.opponent)}` : ''
  const ipNote = s.outs_source === 'derived' ? ' (outs from pitches)' : ''
  return `
  <header class="report-header">
    <div class="brand-mark">KNUCKLEBALL<span class="brand-dot">.</span></div>
    <h1>${escapeHtml(p.pitcherName)}${numBit}</h1>
    <p class="header-meta">${dateStr}${oppBit}${p.teamName ? ' · ' + escapeHtml(p.teamName) : ''} · Live Game</p>
    <p class="header-meta">${fmtIP(s.outs_recorded)} IP${ipNote} · ${s.outs_recorded} outs recorded · ${s.batters_faced} batters faced · ${s.pitches} pitches · charted by ${chartedBy}</p>
    ${perspectiveNote}
  </header>`
}

// ---------- 2. Summary tiles ----------
function renderSummary(p: GameReportPayload): string {
  const s = p.summary
  const vd = computeVelocityDepth(p.pitches as unknown as Parameters<typeof computeVelocityDepth>[0], allTypesOf(p))
  const tiles = [
    tile(String(s.pitches), 'Pitches'),
    tile(s.strike_pct + '%', 'Strike %'),
    tile(s.in_zone_pct + '%', 'In-zone %'),
    s.first_pitch_strike_pct !== null ? tile(s.first_pitch_strike_pct + '%', 'First-pitch strike %') : '',
    tile(String(s.k), 'K'),
    tile(String(s.bb), 'BB'),
    tile(String(s.h) + (s.xbh ? ` (${s.xbh} XBH)` : ''), 'H')
  ]
  if (vd.hasVelo) {
    const velos = p.pitches.map(x => safeNum(x.velo)).filter((v): v is number => v !== null)
    tiles.push(tile(fmtVelo(Math.max(...velos)), 'Peak velocity'))
    tiles.push(tile(fmtVelo(Math.round(velos.reduce((a, b) => a + b, 0) / velos.length)), 'Average velocity'))
  }
  return `<section class="tiles">${tiles.filter(Boolean).join('')}</section>`
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
  const byPosition = new Map<string, { outs: number; hits: number; errors: number }>()
  for (const x of inPlay) {
    if (!x.fielder) continue
    const row = byPosition.get(x.fielder) || { outs: 0, hits: 0, errors: 0 }
    if (x.inPlayOutcome === 'out') row.outs++
    else if (x.inPlayOutcome === 'hit') row.hits++
    else if (x.inPlayOutcome === 'error') row.errors++
    byPosition.set(x.fielder, row)
  }
  const posRows = Array.from(byPosition.entries())
    .map(([pos, r]) => `<tr><td>${escapeHtml(pos)}</td><td>${r.outs}</td><td>${r.hits}</td><td>${r.errors}</td></tr>`)
    .join('')
  return `
  <section class="section">
    <h2>Pitching line</h2>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>IP</th><th>BF</th><th>Pitches</th><th>Strikes</th><th>K</th><th>BB</th><th>H</th><th>1B/2B/3B/HR</th><th>HBP</th><th>E</th><th>Outs in play</th></tr></thead>
      <tbody><tr>
        <td>${fmtIP(s.outs_recorded)}</td><td>${s.batters_faced}</td><td>${s.pitches}</td><td>${s.strikes}</td>
        <td>${s.k}</td><td>${s.bb}</td><td>${s.h}</td><td>${oneB}/${twoB}/${threeB}/${hr}</td>
        <td>${s.hbp}</td><td>${s.errors}</td><td>${s.outs_in_play}</td>
      </tr></tbody>
    </table></div>
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
    <h2>Location by pitch type — catcher's view</h2>
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
    <h2>Location — catcher's view</h2>
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
  </tr>`).join('')
  return `
  <section class="section">
    <h2>Results by count</h2>
    <div class="table-scroll"><table class="data-table">
      <thead><tr><th>Count</th><th>Pitches</th><th>Strike %</th><th>In-play H/Out/E</th></tr></thead>
      <tbody>${body}</tbody>
    </table></div>
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
    return `
    <div class="side-block">
      <h3>${label}</h3>
      <p class="side-stats">${b.total} pitches · ${b.battersFaced} BF · ${b.strikePct ?? '—'}% strikes · ${b.inZonePct}% in-zone · ${b.whiffPct ?? '—'}% whiff · ${b.k}/${b.bb}/${b.h} K/BB/H</p>
      <div class="grid-row">${grid}${drawLegend(allTypes)}
        <div class="side-lists"><div><strong>Location (by zone)</strong><ul>${zoneList || '<li>No pitches landed in the strike zone.</li>'}</ul></div></div>
      </div>
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
      { label: 'Strike %', color: '#E8A83D', points: strikeSeries.map(v => v === null ? null : v / 100) },
      { label: 'First-pitch strike %', color: '#6FA287', points: fpsSeries.map(v => v === null ? null : v / 100) }
    ],
    xLabels, yAxisLabels: ['0%', '50%', '100%']
  })
  const veloValues = veloSeries.filter((v): v is number => v !== null)
  const anyVelo = veloValues.length > 0
  const vLo = anyVelo ? Math.floor(Math.min(...veloValues) / 5) * 5 : 0
  const vHi = anyVelo ? Math.ceil(Math.max(...veloValues) / 5) * 5 : 1
  const vRange = Math.max(1, vHi - vLo)
  const veloChart = anyVelo ? drawLineChart({
    series: [{ label: 'Avg velocity', color: '#C17A45', points: veloSeries.map(v => v === null ? null : (v - vLo) / vRange) }],
    xLabels, yAxisLabels: [String(vLo), String(Math.round((vLo + vHi) / 2)), String(vHi)]
  }) : ''
  const maxCount = Math.max(1, ...pitchSeries.filter((v): v is number => v !== null))
  const countChart = drawLineChart({
    series: [{ label: 'Pitch count', color: '#7C9CBF', points: pitchSeries.map(v => v === null ? null : v / maxCount) }],
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

// ---------- 12. At-bat log ----------
function renderAtBatLog(p: GameReportPayload): string {
  const log = computeAtBatLog(p.pitches)
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
      const deliveryLabel = ab.delivery === 'set' ? 'Set' : ab.delivery === 'windup' ? 'Windup' : '—'
      const seq = ab.pitches.map(pt => {
        const g = resultGlyph(pt)
        const veloBit = pt.velo !== null && pt.velo !== undefined ? `${escapeHtml(pt.type)} ${Math.round(pt.velo)}` : escapeHtml(pt.type)
        const ttpBit = typeof pt.timeToPlate === 'number' ? ` ⏱${pt.timeToPlate.toFixed(2)}` : ''   // U11 (7)
        return `${veloBit} ${g.glyph}${g.label ? ' ' + g.label : ''}${ttpBit}`
      }).join(' · ')
      const ending = ab.incomplete ? 'incomplete' : escapeHtml(ab.ending)
      return `<div class="ab-row"><span class="ab-num">#${ab.atBatIndex} (${sideLabel}, ${deliveryLabel})</span> ${seq} <span class="ab-ending">${ending}</span></div>`
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

// ---------- 13. Footer ----------
function renderFooter(p: GameReportPayload): string {
  return `
  <footer class="report-footer">
    <p>Numbers and patterns only -- this report doesn't grade or compare to a benchmark. That's a conversation between a pitcher and his coach.</p>
    <p>A strike is: called strike, swinging strike, foul, any ball in play, sac bunt/fly, dropped third. A ball is: ball, HBP. Interference and "other" count toward pitches but neither bucket.</p>
    <p>Grids are always drawn catcher's view, looking out toward the mound.</p>
    <p><span class="brand-mark small">Knuckleball LLC 2026</span> &middot; <a href="https://knuckleballonline.com/login.html?sport=${asSport(p.sport)}">knuckleballonline.com</a> &middot; generated ${new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}</p>
  </footer>`
}

const GAME_CSS = `
  .ab-inning{ margin:14px 0; }
  .ab-row{ font-size:13px; padding:4px 0; border-bottom:1px solid #E8F3EC; }
  .ab-num{ font-weight:700; color:#2E4A40; margin-right:6px; }
  .ab-ending{ float:right; font-weight:700; color:#0F241B; }
`

export function buildGameReportHtml(p: GameReportPayload): string {
  const title = `Game Report — ${p.pitcherName}${p.opponent ? ' vs ' + p.opponent : ''}`
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${escapeHtml(title)}</title>
<style>${PEN_CSS}${GAME_CSS}</style>
</head>
<body>
<div class="page">
${renderHeader(p)}
${renderSummary(p)}
${renderPitchingLine(p)}
${renderLocationCharts(p)}
${renderTypeGrids(p)}
${renderByType(p)}
${renderByInning(p)}
${renderByCount(p)}
${renderPerSide(p)}
${renderVelocity(p)}
${renderRecentPens(p)}
${renderGameTrends(p)}
${renderAtBatLog(p)}
${renderFooter(p)}
</div>
</body>
</html>`
}
