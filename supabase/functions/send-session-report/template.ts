// ============================================================================
// The report template. Builds one self-contained HTML string: inline CSS, no
// JavaScript, no external requests of any kind. Every string from the payload
// goes through escapeHtml(); every number goes through safeNum() before it is
// trusted. Nothing here reads a database -- it operates purely on the payload
// object it's given.
// ============================================================================
import { escapeHtml, safeNum, colorForType, TYPE_PALETTE_HEX } from './helpers.ts'
import { drawGrid, drawLegend, drawLineChart } from './svg.ts'
import {
  computeSummary, computeCommandDetail, computePerSideBlock, computeExcludedNullSide,
  computeVelocityDepth, computeWorkload, computeTrends, type Pitch, type HistoryEntry
} from './compute.ts'

export interface ReportPayload {
  sessionId: string
  pitcherId: string
  pitcherName: string
  uniformNumber: number | null
  teamName: string | null
  date: number
  chartingPerspective: 'behind_catcher' | 'behind_pitcher' | null
  loggedByCoach: boolean
  pitchTypes: string[]
  gridSize?: number
  pitches: Pitch[]
  history: HistoryEntry[]
}

const SIGNUP_URL = 'https://knuckleballonline.com/'

function fmtVelo(v: number | null): string {
  return v === null ? '—' : String(Math.round(v)) + ' mph'
}

function tile(value: string, label: string): string {
  return `<div class="tile"><div class="tile-val">${value}</div><div class="tile-lbl">${escapeHtml(label)}</div></div>`
}

// ---------- 1. Header ----------
function renderHeader(p: ReportPayload): string {
  const dateStr = new Date(p.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  const numBit = p.uniformNumber !== null && p.uniformNumber !== undefined ? ` <span class="header-num">#${escapeHtml(p.uniformNumber)}</span>` : ''
  const chartedBy = p.loggedByCoach ? 'the coaching staff' : escapeHtml(p.pitcherName)
  const perspectiveNote = p.chartingPerspective === 'behind_pitcher'
    ? `<p class="header-note">Charted from behind the pitcher. Every plot in this report is still catcher's view.</p>`
    : ''
  return `
  <header class="report-header">
    <div class="brand-mark">KNUCKLEBALL<span class="brand-dot">.</span></div>
    <h1>${escapeHtml(p.pitcherName)}${numBit}</h1>
    <p class="header-meta">${dateStr}${p.teamName ? ' · ' + escapeHtml(p.teamName) : ''} · ${p.pitches.length} pitch${p.pitches.length === 1 ? '' : 'es'} · charted by ${chartedBy}</p>
    ${perspectiveNote}
  </header>`
}

// ---------- 2. Summary tiles ----------
function renderSummary(p: ReportPayload): string {
  const s = computeSummary(p.pitches, p.gridSize)
  const tiles = [
    tile(String(s.total), 'Total pitches'),
    s.strikePct !== null ? tile(s.strikePct + '%', 'Strike %') : '',
    s.commandPct !== null ? tile(s.commandPct + '%', s.commandLabel === 'zone' ? 'Command % (zone)' : 'Command % (exact hit)') : ''
  ]
  if (s.hasVelo) {
    tiles.push(tile(fmtVelo(s.peakVelo), 'Peak velocity'))
    tiles.push(tile(fmtVelo(s.avgVelo), 'Average velocity'))
  }
  return `<section class="tiles">${tiles.filter(Boolean).join('')}</section>`
}

// ---------- 3. Location chart (mixed sides, physical) ----------
function renderLocationChart(p: ReportPayload): string {
  const allTypes = p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(p.pitches.map(x => x.type)))
  const grid = drawGrid({
    gridSize: p.gridSize, batterSide: null,
    pitches: p.pitches.map(x => ({ row: x.actualRow, col: x.actualCol, type: x.type })),
    allTypes
  })
  return `
  <section class="section">
    <h2>Location — catcher's view</h2>
    <div class="grid-row">${grid}${drawLegend(allTypes)}</div>
    <p class="caption">Every pitch this pen, both batter sides mixed. Numbers and directional words like "inside" depend on who's hitting, so this plot uses neither.</p>
  </section>`
}

// ---------- 4. Command detail + miss tendency ----------
function renderCommandDetail(p: ReportPayload): string {
  const allTypes = p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(p.pitches.map(x => x.type)))
  const rows = computeCommandDetail(p.pitches, allTypes, p.gridSize)
  if (!rows.length) return ''
  const body = rows.map(r => {
    const count = r.thin ? ` (${r.count})` : ''
    const zoneCell = r.hasZone ? `${r.zoneAccuracyPct}%` : '—'
    const veloCell = r.hasVelo ? `${fmtVelo(r.avgVelo)} avg · ${fmtVelo(r.peakVelo)} peak` : '—'
    const miss = r.missTendency
      ? `up ${r.missTendency.up}% · down ${r.missTendency.down}% · left ${r.missTendency.left}% · right ${r.missTendency.right}%`
      : 'On target every pitch.'
    return `<tr>
      <td><span class="dot" style="background:${colorForType(r.type, allTypes)}"></span>${escapeHtml(r.type)}</td>
      <td>${r.count}${count}</td><td>${r.usagePct}%</td><td>${r.strikePct}%</td>
      <td>${zoneCell}</td><td>${r.exactHitPct}%</td><td>${veloCell}</td>
      <td class="miss">${miss}</td>
    </tr>`
  }).join('')
  return `
  <section class="section">
    <h2>Command detail</h2>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>Type</th><th>Count</th><th>Usage</th><th>Strike %</th><th>Zone %</th><th>Exact %</th><th>Velocity</th><th>Miss tendency</th></tr></thead>
      <tbody>${body}</tbody>
    </table></div>
    <p class="caption">Miss tendency is direction on this same catcher's-view grid (up/down/left/right), not "arm side" or "inside" -- those depend on batter side.</p>
  </section>`
}

// ---------- 5. vs RHB / vs LHB blocks ----------
function renderSideBlock(block: NonNullable<ReturnType<typeof computePerSideBlock>>, allTypes: string[], gridSize?: number): string {
  const label = block.side === 'R' ? 'vs Right-Handed Batters' : 'vs Left-Handed Batters'
  const grid = drawGrid({
    gridSize, batterSide: block.side,
    pitches: block.pitches.map(x => ({ row: x.actualRow, col: x.actualCol, type: x.type })),
    allTypes
  })
  const usage = block.usageByType.map(u =>
    `<li><span class="dot" style="background:${colorForType(u.type, allTypes)}"></span>${escapeHtml(u.type)}: ${u.usagePct}% (${u.count})</li>`
  ).join('')
  // First mention of each zone in this block spells out the number AND the
  // canonical name together, per the content spec, then just the number.
  const zoneList = Object.entries(block.zoneCounts)
    .sort((a, b) => Number(a[0]) - Number(b[0]))
    .map(([num, count]) => {
      const n = Number(num)
      const name = ZONE_NAME(n)
      return `<li>${n} (${escapeHtml(name)}): ${count}</li>`
    }).join('')
  return `
  <div class="side-block">
    <h3>${label}</h3>
    <p class="side-stats">${block.total} pitches · ${block.strikePct}% strikes · ${block.commandPct}% command (${block.commandLabel === 'zone' ? 'zone' : 'exact hit'})</p>
    <div class="grid-row">${grid}
      <div class="side-lists">
        <div><strong>Pitch mix</strong><ul>${usage}</ul></div>
        <div><strong>Location (by zone)</strong><ul>${zoneList || '<li>No pitches landed in the strike zone.</li>'}</ul></div>
      </div>
    </div>
  </div>`
}
import { ZONE_NAMES as _ZN } from './helpers.ts'
function ZONE_NAME(n: number): string { return _ZN[n] ?? String(n) }

function renderPerSideBlocks(p: ReportPayload): string {
  const allTypes = p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(p.pitches.map(x => x.type)))
  const r = computePerSideBlock(p.pitches, 'R', allTypes, p.gridSize)
  const l = computePerSideBlock(p.pitches, 'L', allTypes, p.gridSize)
  const excluded = computeExcludedNullSide(p.pitches)
  if (!r && !l) {
    return excluded
      ? `<section class="section"><h2>By batter side</h2><p class="caption">No pitch in this pen recorded which side was hitting, so no per-side breakdown is available.</p></section>`
      : ''
  }
  const excludedNote = excluded
    ? `<p class="caption">${excluded} pitch${excluded === 1 ? '' : 'es'} in this pen recorded no batter side and ${excluded === 1 ? 'is' : 'are'} excluded from the blocks below (included everywhere else).</p>`
    : ''
  return `
  <section class="section">
    <h2>By batter side</h2>
    ${excludedNote}
    ${r ? renderSideBlock(r, allTypes, p.gridSize) : ''}
    ${l ? renderSideBlock(l, allTypes, p.gridSize) : ''}
  </section>`
}

// ---------- 6. Velocity depth ----------
function renderVelocityDepth(p: ReportPayload): string {
  const allTypes = p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(p.pitches.map(x => x.type)))
  const vd = computeVelocityDepth(p.pitches, allTypes)
  if (!vd.hasVelo) return ''
  const rows = vd.perType.map(t => {
    const count = t.thin ? ` (${t.count})` : ''
    return `<tr><td><span class="dot" style="background:${colorForType(t.type, allTypes)}"></span>${escapeHtml(t.type)}${count}</td>
      <td>${fmtVelo(t.avg)}</td><td>${fmtVelo(t.peak)}</td><td>${t.range} mph</td></tr>`
  }).join('')

  let driftChart = ''
  if (vd.drift.length >= 2) {
    const velos = vd.drift.map(d => d.velo as number)
    const lo = Math.floor(Math.min(...velos) / 5) * 5, hi = Math.ceil(Math.max(...velos) / 5) * 5
    const range = Math.max(1, hi - lo)
    const byType: Record<string, (number | null)[]> = {}
    for (const t of allTypes) byType[t] = vd.drift.map(d => d.type === t ? ((d.velo as number) - lo) / range : null)
    const series = allTypes.filter(t => vd.drift.some(d => d.type === t)).map(t => ({ label: t, color: colorForType(t, allTypes), points: byType[t] }))
    const chart = drawLineChart({
      series,
      xLabels: vd.drift.map((_, i) => String(i + 1)),
      yAxisLabels: [String(lo), String(Math.round((lo + hi) / 2)), String(hi)]
    })
    driftChart = `<div class="drift"><h3>Velocity by pitch order</h3>${chart}<p class="caption">Each point is one gunned pitch, in the order it was thrown, whole mph.</p></div>`
  }

  return `
  <section class="section">
    <h2>Velocity depth</h2>
    <div class="table-scroll"><table class="data-table">
      <thead><tr><th>Type</th><th>Average</th><th>Peak</th><th>Range</th></tr></thead>
      <tbody>${rows}</tbody>
    </table></div>
    ${driftChart}
  </section>`
}

// ---------- 7. Workload and pitch mix ----------
function renderWorkload(p: ReportPayload): string {
  const allTypes = p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(p.pitches.map(x => x.type)))
  const recentTotals = p.history.map(h => safeNum(h.total)).filter((n): n is number => n !== null)
  const wl = computeWorkload(p.pitches, allTypes, recentTotals)
  const rows = wl.byType.map(t =>
    `<tr><td><span class="dot" style="background:${colorForType(t.type, allTypes)}"></span>${escapeHtml(t.type)}</td><td>${t.count}</td><td>${t.usagePct}%</td></tr>`
  ).join('')
  const compare = wl.recentAvg !== null
    ? `<p class="caption">Recent average for this pitcher on this team: ${wl.recentAvg} pitches. This pen: ${wl.total}.</p>`
    : ''
  return `
  <section class="section">
    <h2>Workload and pitch mix</h2>
    <div class="table-scroll"><table class="data-table"><thead><tr><th>Type</th><th>Count</th><th>Usage</th></tr></thead><tbody>${rows}</tbody></table></div>
    ${compare}
  </section>`
}

// ---------- 8. Trends ----------
function renderTrends(p: ReportPayload): string {
  const trend = computeTrends(p.history)
  if (!trend) return ''
  const xLabels = trend.map(h => h.dateLabel)
  const strikeSeries = trend.map(h => safeNum(h.strikePct))
  const commandSeries = trend.map(h => safeNum(h.commandPct))
  const veloSeries = trend.map(h => h.hasVelo ? safeNum(h.avgVelo) : null)
  const pitchCountSeries = trend.map(h => safeNum(h.total))

  const pctChart = drawLineChart({
    series: [
      { label: 'Strike %', color: '#E8A83D', points: strikeSeries.map(v => v === null ? null : v / 100) },
      { label: 'Command %', color: '#6FA287', points: commandSeries.map(v => v === null ? null : v / 100) }
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
  const maxCount = Math.max(1, ...pitchCountSeries.filter((v): v is number => v !== null))
  const countChart = drawLineChart({
    series: [{ label: 'Pitch count', color: '#7C9CBF', points: pitchCountSeries.map(v => v === null ? null : v / maxCount) }],
    xLabels, yAxisLabels: ['0', String(Math.round(maxCount / 2)), String(maxCount)]
  })

  return `
  <section class="section">
    <h2>Trends (last ${trend.length} pens)</h2>
    <div class="trend-grid">
      <div><h3>Strike % and Command %</h3>${pctChart}</div>
      ${anyVelo ? `<div><h3>Average velocity</h3>${veloChart}</div>` : ''}
      <div><h3>Pitch count</h3>${countChart}</div>
    </div>
  </section>`
}

// ---------- 9. Footer ----------
function renderFooter(): string {
  return `
  <footer class="report-footer">
    <p>Numbers and patterns only -- this report doesn't grade or compare to a benchmark. That's a conversation between a pitcher and his coach.</p>
    <p>Grids are always drawn catcher's view, looking out toward the mound.</p>
    <p><span class="brand-mark small">KNUCKLEBALL<span class="brand-dot">.</span></span> &middot; <a href="${SIGNUP_URL}">knuckleballonline.com</a> &middot; generated ${new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}</p>
  </footer>`
}

const CSS = `
  :root{ color-scheme: light; }
  *{ box-sizing:border-box; }
  svg{ max-width:100%; height:auto; display:block; } /* trend/drift charts are drawn at a fixed 560px viewBox width -- without this they blow out the page on a phone instead of scaling down */
  body{ margin:0; background:#F7FAF8; color:#0F241B; font-family:Georgia,'Times New Roman',serif; font-size:15px; line-height:1.5; }
  .page{ max-width:820px; margin:0 auto; padding:24px 20px 48px; }
  h1,h2,h3{ font-family:Georgia,'Times New Roman',serif; font-weight:700; margin:0 0 6px; }
  h1{ font-size:28px; }
  h2{ font-size:19px; margin-top:0; border-bottom:2px solid #CFE6D7; padding-bottom:6px; }
  h3{ font-size:14px; color:#2E4A40; }
  .report-header{ background:#0F241B; color:#F1ECDD; padding:20px; border-radius:10px; margin-bottom:20px; }
  .brand-mark{ color:#E8A83D; font-weight:700; letter-spacing:0.06em; font-size:13px; }
  .brand-mark.small{ font-size:11px; }
  .brand-dot{ color:#E8A83D; }
  .header-num{ font-size:0.6em; color:#B7C2B4; font-weight:400; }
  .header-meta{ margin:6px 0 0; color:#B7C2B4; font-size:13px; }
  .header-note{ margin:8px 0 0; color:#E8A83D; font-size:12.5px; }
  .tiles{ display:flex; flex-wrap:wrap; gap:14px; margin:20px 0 28px; }
  .tile{ background:#FFFFFF; border:1px solid #CFE6D7; border-radius:8px; padding:12px 16px; min-width:110px; flex:1; text-align:center; }
  .tile-val{ font-size:26px; font-weight:700; }
  .tile-lbl{ font-size:11px; text-transform:uppercase; letter-spacing:0.06em; color:#527065; margin-top:2px; }
  .section{ margin:28px 0; }
  .grid-row{ display:flex; gap:20px; flex-wrap:wrap; align-items:flex-start; }
  .legend{ display:flex; flex-direction:column; gap:6px; padding-top:8px; }
  .legend-item{ display:flex; align-items:center; gap:6px; font-size:13px; }
  .legend-dot{ width:9px; height:9px; border-radius:2px; display:inline-block; }
  .dot{ width:8px; height:8px; border-radius:2px; display:inline-block; margin-right:6px; }
  .caption{ font-size:12px; color:#527065; margin:8px 0 0; }
  .table-scroll{ overflow-x:auto; -webkit-overflow-scrolling:touch; margin-top:10px; }
  .data-table{ width:100%; border-collapse:collapse; font-size:13px; }
  .data-table.wide{ min-width:560px; } /* command detail: 8 columns incl. free-text miss tendency -- needs room to scroll to, not to be crushed illegible */
  .data-table th{ text-align:left; font-size:10.5px; text-transform:uppercase; letter-spacing:0.05em; color:#527065; border-bottom:1px solid #CFE6D7; padding:5px 8px 5px 0; }
  .data-table td{ padding:6px 8px 6px 0; border-bottom:1px solid #E8F3EC; vertical-align:top; }
  .data-table td.miss{ font-size:12px; color:#2E4A40; }
  .side-block{ margin-top:16px; padding-top:12px; border-top:1px solid #CFE6D7; }
  .side-stats{ font-size:13px; color:#2E4A40; }
  .side-lists{ display:flex; gap:24px; flex-wrap:wrap; }
  .side-lists ul{ margin:4px 0 0; padding-left:18px; font-size:13px; }
  .drift{ margin-top:14px; }
  .trend-grid{ display:flex; flex-direction:column; gap:18px; }
  .report-footer{ margin-top:36px; padding-top:16px; border-top:1px solid #CFE6D7; font-size:11.5px; color:#527065; }
  .report-footer a{ color:#2E4A40; }
  @media (max-width:600px){
    .page{ padding:16px 12px 32px; }
    .tiles{ gap:10px; }
    .tile{ min-width:90px; padding:10px 12px; }
    .grid-row{ gap:14px; }
    .data-table{ font-size:12px; }
  }
  @media print{
    body{ background:#FFFFFF; }
    .report-header{ background:#0F241B !important; -webkit-print-color-adjust:exact; print-color-adjust:exact; }
    .section{ page-break-inside:avoid; }
  }
`

export function buildReportHtml(p: ReportPayload): string {
  const title = `Bullpen Report — ${p.pitcherName}`
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${escapeHtml(title)}</title>
<style>${CSS}</style>
</head>
<body>
<div class="page">
${renderHeader(p)}
${renderSummary(p)}
${renderLocationChart(p)}
${renderCommandDetail(p)}
${renderPerSideBlocks(p)}
${renderVelocityDepth(p)}
${renderWorkload(p)}
${renderTrends(p)}
${renderFooter()}
</div>
</body>
</html>`
}
