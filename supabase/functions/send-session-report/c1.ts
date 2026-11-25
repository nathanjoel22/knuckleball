// ============================================================================
// C1 Stage A (Joel, Nov 25 2026; plans/c1-charting-parts.md, decisions in plans/c1-preconditions.md): reports for a
// session charted in parts. A session that charted only the INTENT part (the call: pitch type, target, batter side)
// has no location, result, count or velocity, so its report shows what was charted and says plainly what wasn't:
// pitch mix and the called spots, per pitch type and batter side. Pens (template.ts) and games (template_game.ts)
// share it. The tab structure (radio tabs, versions, print pages) is the SR1 one, with only the tabs that have content.
// Every report of a session charted in full is untouched by this file.
// ============================================================================
import { escapeHtml, reportVars, asSport, type Sport, VIEW_NAME, REPORT_VIEW, viewNote, zoneNumber, ZONE_NAMES, hasTarget, colorForType } from './helpers.ts'
import { drawCalledTypeGrids } from './svg.ts'
import {
  type Comparison, type TileSpec, type TabLabel, type EmailVersion, SR1_CSS, radios, panel, takeaway, card, tileFor, simpleTable, typeCell,
  footer, firstName, pickFastball, sevenDayCard, levelGroup, versionsFor, printTitle, emailComment, shortDate, pctOf
} from './sr1.ts'

// The plain statements (packet: "say plainly which parts were not")
export const INTENT_ONLY_LINE = { bullpen: 'Only the pitch calls were charted: no locations.', game: 'Only the pitch calls were charted: no locations, results or counts.' }
export const OUTCOME_ONLY_LINE = 'Only where each pitch landed was charted: no targets.'
// The header's part, after the date: " · Intent only" / " · Outcome only"
export const partBit = (which: 'intent' | 'outcome') => which === 'intent' ? ' · Intent only' : ' · Outcome only'

export interface CalledPitch { type: string; targetRow?: number | null; targetCol?: number | null; batterSide: 'R' | 'L' | null }
export interface IntentOnlyInput {
  kind: 'bullpen' | 'game'
  sport?: Sport
  sessionId: string
  pitcherName: string
  date: number
  dateText: string              // the header's date (Eastern)
  subExtra: string              // after the date in the summary line: the pen's tag, or the game's opponent
  chartedBy: string             // already escaped
  chartingPerspective: string | null
  pitches: CalledPitch[]
  allTypes: string[]
  gridSize?: number
  comparison: Comparison
  title: string
  css: string                   // the report's own stylesheet (pen or game), before SR1_CSS
  header: (id: string, labels: TabLabel[]) => string
  links: string                 // the footer's links line
}

const SIDE_LABEL: Record<string, string> = { R: 'vs Right-Handed Batters', L: 'vs Left-Handed Batters' }

export function intentOnlyReport(o: IntentOnlyInput): string {
  const c = o.comparison
  const id = String(o.sessionId || 'x').replace(/[^a-zA-Z0-9]/g, '').slice(0, 8) || 'x'
  const g = levelGroup(c.workload?.level ?? c.baselines?.level ?? null)
  const V = versionsFor(g)
  // One set of panels for every version: nothing here is velocity, a grade or a he / his (SR1 E)
  const tabs: TabLabel[] = [{ panel: 1, label: 'Summary', versions: V }, { panel: 2, label: 'Called spots', versions: V }]
  const ps = o.pitches.filter(x => !!x.type)
  const called = ps.filter(hasTarget)
  const n = ps.length
  const thrown = o.allTypes.filter(t => ps.some(x => x.type === t))
  const byType = thrown.map(t => ({ type: t, n: ps.filter(x => x.type === t).length })).sort((a, b) => b.n - a.n)
  const sides = { R: ps.filter(x => x.batterSide === 'R'), L: ps.filter(x => x.batterSide === 'L'), none: ps.filter(x => x.batterSide !== 'R' && x.batterSide !== 'L') }
  const sided = sides.R.length + sides.L.length
  const noun = o.kind === 'game' ? 'game' : 'pen'
  const top = byType[0]
  const plural = (k: number, w: string) => `${k} ${w}${k === 1 ? '' : (w.endsWith('ch') ? 'es' : 's')}`
  const headline = !n ? 'No pitches called.'
    : `${plural(n, 'pitch')} called${top && thrown.length > 1 ? `; ${escapeHtml(top.type)} the most (${top.n} of ${n})` : top ? `, all ${escapeHtml(top.type)}` : ''}.`
  const batterBit = !n ? '' : sided === 0 ? (o.kind === 'game' ? '' : ' · No batter') : sided < n ? ' · Mixed' : ''
  const line = INTENT_ONLY_LINE[o.kind]

  // ---------- Summary ----------
  const fb = pickFastball(ps)
  const dash = 'not charted'
  const tiles: TileSpec[] = o.kind === 'game'
    ? [{ label: 'Strike %', cur: null, unit: '%', key: 'strike_pct', sub: dash }, { label: '1st-pitch strike', cur: null, unit: '%', key: 'fp_strike_pct', sub: dash },
       { label: 'In zone', cur: null, unit: '%', key: 'in_zone_pct', sub: dash }, { label: 'Pitches called', cur: n, unit: '', key: 'pitches', plain: true }]
    : [{ label: 'On the spot', cur: null, unit: '%', key: 'spot_pct', sub: dash }, { label: 'Strike %', cur: null, unit: '%', key: 'strike_pct', sub: dash },
       { label: `${fb.label} avg mph`, cur: null, unit: 'mph', key: 'velo', sub: dash }, { label: 'Pitches called', cur: n, unit: '', key: 'pitches', plain: true }]
  const sideCols = [...(sides.R.length ? ['vs right'] : []), ...(sides.L.length ? ['vs left'] : []), ...(sided && sides.none.length ? [o.kind === 'game' ? 'No side' : 'No batter'] : [])]
  const mixRows = byType.map(t => [typeCell(t.type, o.allTypes), String(t.n), `${pctOf(t.n, n)}%`,
    ...(sides.R.length ? [String(sides.R.filter(x => x.type === t.type).length)] : []),
    ...(sides.L.length ? [String(sides.L.filter(x => x.type === t.type).length)] : []),
    ...(sided && sides.none.length ? [String(sides.none.filter(x => x.type === t.type).length)] : [])])
  const mix = n ? card('Pitch mix', simpleTable(['Pitch', 'Called', 'Mix', ...sideCols], mixRows)) : ''
  const note = viewNote(o.chartingPerspective).replace('class="header-note"', 'class="caption"')
  const viewCap = note || `<p class="caption">Every grid in this report is drawn in the ${VIEW_NAME}, ${REPORT_VIEW === 'pitcher' ? 'looking in from the mound toward home plate' : 'looking out toward the mound'}.</p>`
  const summary = card('', `<h2 class="kr-headline">${headline}</h2>
    <p class="kr-sub">${o.dateText}${o.subExtra} · ${plural(n, 'pitch')} called · ${plural(thrown.length, 'pitch type')}${batterBit} · charted by ${o.chartedBy}</p>`)
    + card('Intent only', `<p class="kr-sub">${line} So this ${noun} has no ${o.kind === 'game' ? 'strike %, pitching line, at-bats, spray chart or rest card' : 'accuracy, strike %, velocity or miss patterns'}, and it isn't counted in ${firstName(o.pitcherName) === 'the pitcher' ? 'the' : escapeHtml(firstName(o.pitcherName)) + "'s"} averages or trends.</p>`)
    + `<div class="kr-tiles">${tiles.map(t => tileFor(t, undefined, noun)).join('')}</div>`
    + mix
    + (o.kind === 'bullpen' ? sevenDayCard(c.workload) : '')
    + viewCap

  // ---------- Called spots ----------
  const zoneList = (side: 'R' | 'L', list: CalledPitch[]) => {
    const counts: Record<number, number> = {}
    for (const x of list) {
      const z = zoneNumber(x.targetRow ?? null, x.targetCol ?? null, side, o.gridSize ?? 5)
      if (z !== null) counts[z] = (counts[z] || 0) + 1
    }
    const off = list.filter(x => hasTarget(x) && zoneNumber(x.targetRow ?? null, x.targetCol ?? null, side, o.gridSize ?? 5) === null).length
    const items = Object.entries(counts).sort((a, b) => Number(a[0]) - Number(b[0]))
      .map(([z, k]) => `<li>${z} (${escapeHtml(ZONE_NAMES[Number(z)] ?? z)}): ${k}</li>`).join('')
    return `<ul>${items}${off ? `<li>Off the zone: ${off}</li>` : ''}${items || off ? '' : '<li>No calls.</li>'}</ul>`
  }
  const pts = (list: CalledPitch[]) => list.map(x => ({ row: x.targetRow ?? null, col: x.targetCol ?? null, type: x.type }))
  const sideBlock = (side: 'R' | 'L') => {
    const list = sides[side]
    if (!list.length) return ''
    return `
    <div class="side-block">
      <h3>${SIDE_LABEL[side]}</h3>
      <p class="side-stats">${plural(list.length, 'pitch')} called · ${o.allTypes.filter(t => list.some(x => x.type === t)).map(t => `${escapeHtml(t)} ${list.filter(x => x.type === t).length}`).join(' · ')}</p>
      ${drawCalledTypeGrids({ gridSize: o.gridSize, batterSide: side, allTypes: o.allTypes, pitches: pts(list) })}
      <div class="side-lists"><div><strong>Called by zone</strong>${zoneList(side, list)}</div></div>
    </div>`
  }
  const noSide = sided && sides.none.length ? `
    <div class="side-block">
      <h3>${o.kind === 'game' ? 'No batter side' : 'No batter'}</h3>
      <p class="side-stats">${plural(sides.none.length, 'pitch')} called</p>
      ${drawCalledTypeGrids({ gridSize: o.gridSize, batterSide: null, allTypes: o.allTypes, pitches: pts(sides.none) })}
    </div>` : ''
  const allGrids = drawCalledTypeGrids({ gridSize: o.gridSize, batterSide: null, allTypes: o.allTypes, pitches: pts(called) })
  const calledTab = takeaway(n ? `Where the ${plural(n, 'pitch')} ${n === 1 ? 'was' : 'were'} called` : 'No pitches called')
    + (allGrids ? card('', `${allGrids}${drawLegendInline(thrown, o.allTypes)}<p class="caption">Each ring is one called spot: where the pitch was aimed, not where it went (no locations were charted). ${sided ? 'Both batter sides mixed, so no zone numbers here.' : ''} ${VIEW_NAME[0].toUpperCase() + VIEW_NAME.slice(1)}.</p>`) : '')
    + (sided ? `
  <section class="section">
    <h2>By batter side</h2>
    ${sideBlock('R')}${sideBlock('L')}${noSide}
  </section>` : '')

  // ---------- each version's email (SR1 F), frozen with the report ----------
  const date = shortDate(o.date), kindWord = o.kind === 'game' ? 'Game' : 'Bullpen'
  const stats = [{ v: String(n), l: 'Calls' }, { v: String(thrown.length), l: 'Pitch types' }]
  const base: EmailVersion = { subject: `${kindWord} report: ${o.pitcherName} · ${plural(n, 'pitch call')} · ${date}`, headline: headline, stats,
    bullets: [line], lines: [], button: 'Open the full report' }
  const emails: Record<string, EmailVersion> = { coach: base }
  emails.player = { ...base, subject: `Your ${kindWord.toLowerCase()} report: ${plural(n, 'pitch call')} · ${date}` }
  if (g === 'll') emails.parent = base

  const pt = printTitle(o.pitcherName, o.kind === 'game' ? 'Live Game' : 'Bullpen', o.dateText, [])
  return (`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${escapeHtml(o.title)}</title>
<style>${reportVars(asSport(o.sport))}${o.css}${SR1_CSS}</style>
</head>
<body>
<div class="page kr" data-kr-versions="${V.join(' ')}">
${radios(id, ['1', '2'], [])}
${o.header(id, tabs)}
<main class="kr-main">
${panel(1, summary, tabs, pt)}
${panel(2, calledTab, tabs, pt)}
</main>
${footer(firstName(o.pitcherName), o.links, true)}
</div>
${emailComment(emails)}
</body>
</html>`)
}
// the pitch types called, in the pitcher's own order (the legend's colours match the rings)
function drawLegendInline(thrown: string[], allTypes: string[]): string {
  return `<div class="legend" style="flex-direction:row;flex-wrap:wrap;gap:6px 16px">${thrown.map(t =>
    `<span class="legend-item"><span class="legend-dot" style="background:${colorForType(t, allTypes)}"></span>${escapeHtml(t)}</span>`).join('')}</div>`
}
