// ============================================================================
// The report template. Builds one self-contained HTML string: inline CSS, no
// JavaScript, no external requests of any kind. Every string from the payload
// goes through escapeHtml(); every number goes through safeNum() before it is
// trusted. Nothing here reads a database -- it operates purely on the payload
// object it's given.
// ============================================================================
import { escapeHtml, safeNum, colorForType, TYPE_PALETTE_HEX, isStrikeCell, timesToHomeLine, reportVars, asSport, type Sport, VIEW_NAME, REPORT_VIEW, viewNote } from './helpers.ts'
import { drawGrid, drawLegend, drawHitTypeGrids } from './svg.ts'
import { computePerSideBlock, computeExcludedNullSide, isU14, isHit, type Pitch, type HistoryEntry } from './compute.ts'
import {
  type Comparison, NO_COMPARISON, type StoodOut, type TileSpec, WINDOWS, SR1_CSS, ids, radios, tabBar, windowSwitch, wb, wi, panel,
  takeaway, card, tileFor, windowCaption, stoodOutCard, sparkCard, simpleTable, typeCell, footer, firstName, penWord, word,
  ordinal, pctOf, pickFastball, avgVelo, gunned, outsideRange, rangeText, sortStoodOut, missPattern, missDirs, DIR_WORDS,
  fadePattern, sidePattern, typeMin, sevenDayCard, type Voice, type LevelGroup, levelGroup, versionsFor, ver, tabBarVersions, printTitle, TZ,
  restDays, backDate, type EmailVersion, emailComment, shortDate, sevenDayEmailLine, comparedEmailLine, abbrOf
} from './sr1.ts'

// SR1 Stage A: a pen's purpose (sessions.purpose; the tracker's SESSION_TAGS) as the header says it
const SESSION_TAG_LABELS: Record<string, string> = { command: 'Command pen', velocity: 'Velocity pen', short_pen: 'Short pen' }

export interface ReportPayload {
  // S1: from the SESSION ROW (index.ts), never from the client's payload.
  sport?: Sport
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
  raOn?: boolean   // U14: the session's answer to "Turn on Relative Accuracy?" (session row)
  purpose?: string | null   // SR1 A: the pen's tag (session row); null = No tag
  comparison?: Comparison   // SR1 C: Stage B's baselines, the last same-kind pens, the throwing hand (read at save, caller's reach)
}

// S1 (Joel, Oct 1): the footer link goes to THIS sport's sign-in page.
const signInUrl = (sport: Sport) => `https://knuckleballonline.com/login.html?sport=${sport}`

function fmtVelo(v: number | null): string {
  return v === null ? '—' : String(Math.round(v)) + ' mph'
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
    <h2>Location — ${VIEW_NAME}</h2>
    <div class="grid-row">${grid}${drawLegend(allTypes)}</div>
    <p class="caption">Every pitch this pen, both batter sides mixed. Numbers and directional words like "inside" depend on who's hitting, so this plot uses neither.</p>
  </section>`
}

// ---------- 5. vs RHB / vs LHB blocks ----------
function renderSideBlock(block: NonNullable<ReturnType<typeof computePerSideBlock>>, allTypes: string[], gridSize?: number, raOn?: boolean): string {
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
    <p class="side-stats">${block.total} pitches · ${block.strikePct}% strikes · ${block.commandLabel === 'accuracy' ? `${block.commandPct}% accurate` : `${block.commandPct}% command (${block.commandLabel === 'zone' ? 'zone' : 'exact hit'})`}</p>
    <div class="grid-row">${grid}
      <div class="side-lists">
        <div><strong>Pitch mix</strong><ul>${usage}</ul></div>
        <div><strong>Location (by zone)</strong><ul>${zoneList || '<li>No pitches landed in the strike zone.</li>'}</ul></div>
      </div>
    </div>${block.u14 ? `
    ${drawHitTypeGrids({ gridSize, batterSide: block.side, allTypes, raOn: !!raOn,
      pitches: block.pitches.map(x => ({ type: x.type, row: x.actualRow, col: x.actualCol, kind: x.accuracyHitKind || 'miss' })) })}` : ''}
  </div>`
}
import { ZONE_NAMES as _ZN } from './helpers.ts'
function ZONE_NAME(n: number): string { return _ZN[n] ?? String(n) }

function renderPerSideBlocks(p: ReportPayload): string {
  const allTypes = p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(p.pitches.map(x => x.type)))
  const r = computePerSideBlock(p.pitches, 'R', allTypes, p.gridSize)
  const l = computePerSideBlock(p.pitches, 'L', allTypes, p.gridSize)
  const excluded = computeExcludedNullSide(p.pitches)
  // U14: a pen charted with no batter standing in has no side -- its exact / RA grids get their own block
  // (scored with the vs-RHB cells, as the app does). Only for U14 sessions; every other report is unchanged.
  const noSide = isU14(p.pitches) ? p.pitches.filter(x => !x.batterSide) : []
  const noSideBlock = noSide.length ? `
    <div class="side-block">
      <h3>No batter</h3>
      <p class="side-stats">${noSide.length} pitch${noSide.length === 1 ? '' : 'es'} · ${Math.round(100 * noSide.filter(isHit).length / noSide.length)}% accurate · scored with the vs RHB cells</p>
      ${drawHitTypeGrids({ gridSize: p.gridSize, batterSide: null, allTypes, raOn: !!p.raOn,
        pitches: noSide.map(x => ({ type: x.type, row: x.actualRow, col: x.actualCol, kind: x.accuracyHitKind || 'miss' })) })}
    </div>` : ''
  if (!r && !l && noSideBlock) return `
  <section class="section">
    <h2>Accuracy by pitch type</h2>
    ${noSideBlock}
  </section>`
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
    ${r ? renderSideBlock(r, allTypes, p.gridSize, p.raOn) : ''}
    ${l ? renderSideBlock(l, allTypes, p.gridSize, p.raOn) : ''}${noSideBlock}
  </section>`
}

// U11 (6): Windup / Set split, only when a pen used both.
function deliverySplitLine(p: ReportPayload): string {
  const windup = p.pitches.filter(x => x.delivery === 'windup').length
  const set = p.pitches.filter(x => x.delivery === 'set').length
  if (!windup || !set) return ''
  return `<p class="caption"><strong>Delivery:</strong> ${windup} from the windup · ${set} from the stretch</p>`
}

// Exported so the G2 game report (template_game.ts) can reuse it verbatim
// and only append game-specific rules -- this export changes nothing about
// what buildReportHtml below produces (acceptance 14: bullpen output stays
// byte-for-byte identical).
export const CSS = `
  :root{ color-scheme: light; }
  *{ box-sizing:border-box; }
  svg{ max-width:100%; height:auto; display:block; } /* trend/drift charts are drawn at a fixed 560px viewBox width -- without this they blow out the page on a phone instead of scaling down */
  /* D2 Stage D (Oct 13 2026): colors and fonts are this report's own --kr-* variables (helpers.ts reportVars) */
  body{ margin:0; background:var(--kr-bg); color:var(--kr-ink); font-family:var(--kr-sans); font-size:16px; line-height:1.5; }
  .page{ max-width:820px; margin:0 auto; padding:24px 20px 48px; }
  h1,h2{ font-family:var(--kr-display); font-weight:800; text-transform:uppercase; letter-spacing:0.01em; line-height:1; margin:0 0 6px; }
  h3{ font-family:var(--kr-sans); font-weight:800; margin:0 0 6px; }
  h1{ font-size:44px; }
  h2{ font-size:24px; margin-top:0; border-bottom:2px solid var(--kr-line); padding-bottom:6px; }
  h3{ font-size:14px; color:var(--kr-ink-dim); }
  .report-header{ background:var(--kr-brand); color:var(--kr-on-dark); padding:22px 20px; border-radius:12px; margin-bottom:20px; display:flex; flex-direction:column; gap:10px; }
  .report-header h1{ margin:2px 0 0; color:var(--kr-on-dark); }
  .brand-mark{ font-family:var(--kr-wordmark); font-weight:400; color:var(--kr-on-dark); letter-spacing:0.02em; font-size:24px; line-height:1; }
  .brand-mark.small{ font-family:var(--kr-sans); font-weight:700; font-size:10px; color:var(--kr-ink-dim); letter-spacing:0.04em; }
  .sport-tag{ position:relative; z-index:0; align-self:flex-start; padding:5px 12px; color:var(--kr-on-accent); font-family:var(--kr-sans); font-size:12px; font-weight:800; letter-spacing:0.14em; text-transform:uppercase; line-height:1; }
  .sport-tag::before{ content:''; position:absolute; inset:0; z-index:-1; background:var(--kr-accent); transform:skewX(-14deg); }
  .header-num{ font-size:0.7em; color:var(--kr-on-dark-dim); font-weight:700; }
  .header-meta{ margin:0; color:var(--kr-on-dark-dim); font-size:12px; }
  .header-note{ margin:0; color:var(--kr-accent-on-dark); font-size:12px; }   /* gold 10:1 on green; softball's lighter pink 5.2:1 on navy */
  .tiles{ display:flex; flex-wrap:wrap; gap:14px; margin:20px 0 28px; }
  .tile{ background:var(--kr-card); border:1px solid var(--kr-line); border-radius:12px; padding:12px 16px; min-width:110px; flex:1; text-align:center; }
  .tile-val{ font-family:var(--kr-display); font-size:32px; font-weight:700; line-height:1.05; font-variant-numeric:tabular-nums; }
  .tile-lbl{ font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:0.1em; color:var(--kr-ink-faint); margin-top:4px; }
  .section{ margin:28px 0; }
  .grid-row{ display:flex; gap:20px; flex-wrap:wrap; align-items:flex-start; }
  /* U11 (4): per-type grids -- wrap to fit: 2-3 across on a phone, more on
     wider screens, never a horizontal scroll. */
  .type-grids{ display:grid; grid-template-columns:repeat(auto-fill, minmax(140px, 1fr)); gap:14px 18px; }
  .type-grid{ min-width:0; }
  .type-grid h3{ display:flex; align-items:center; gap:6px; margin:0 0 6px; font-size:12px; }
  .type-grid svg{ width:100%; max-width:170px; height:auto; }
  .type-grid-stats{ margin:4px 0 0; font-size:12px; color:var(--kr-ink-faint); }
  .legend{ display:flex; flex-direction:column; gap:6px; padding-top:8px; }
  .legend-item{ display:flex; align-items:center; gap:6px; font-size:12px; }
  .legend-dot{ width:9px; height:9px; border-radius:2px; display:inline-block; }
  .dot{ width:8px; height:8px; border-radius:2px; display:inline-block; margin-right:6px; }
  .caption{ font-size:12px; color:var(--kr-ink-faint); margin:8px 0 0; }
  .table-scroll{ overflow-x:auto; -webkit-overflow-scrolling:touch; margin-top:10px; }
  .data-table{ width:100%; border-collapse:collapse; font-size:12px; font-variant-numeric:tabular-nums; }
  .data-table.wide{ min-width:560px; } /* command detail: 8 columns incl. free-text miss tendency -- needs room to scroll to, not to be crushed illegible */
  .data-table th{ text-align:left; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:0.08em; color:var(--kr-ink-faint); border-bottom:1px solid var(--kr-line); padding:5px 8px 5px 0; }
  .data-table td{ padding:6px 8px 6px 0; border-bottom:1px solid var(--kr-hair); vertical-align:top; }
  .data-table td.miss{ font-size:12px; color:var(--kr-ink-dim); }
  .side-block{ margin-top:16px; padding-top:12px; border-top:1px solid var(--kr-line); }
  .side-stats{ font-size:12px; color:var(--kr-ink-dim); }
  .side-lists{ display:flex; gap:24px; flex-wrap:wrap; }
  .side-lists ul{ margin:4px 0 0; padding-left:18px; font-size:12px; }
  .drift{ margin-top:14px; }
  .trend-grid{ display:flex; flex-direction:column; gap:18px; }
  .report-footer{ margin-top:36px; padding-top:16px; border-top:1px solid var(--kr-line); font-size:12px; color:var(--kr-ink-faint); }
  .report-footer a{ color:var(--kr-link); }
  @media (max-width:600px){
    .page{ padding:16px 12px 32px; }
    h1{ font-size:32px; }
    .tiles{ gap:10px; }
    .tile{ min-width:90px; padding:10px 12px; }
    .grid-row{ gap:14px; }
    .data-table{ font-size:12px; }
  }
  @media print{
    body{ background:#FFFFFF; }
    .report-header, .sport-tag::before{ -webkit-print-color-adjust:exact; print-color-adjust:exact; }
    .section{ page-break-inside:avoid; }
    /* Location dots (svg.ts drawDots): a dark outline so every dot still
       reads on a black-and-white printout, where pale pitch-type colors and
       the translucent halos wash out. CSS beats the SVG stroke attribute. */
    .kb-dot{ stroke:var(--kr-print); }
  }
`

// ---------- SR1 Stage C: the answer-first report (coach version) ----------
function penDate(p: ReportPayload): string {
  return new Date(p.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: TZ })
}
function penHeader(p: ReportPayload, id: string, g: LevelGroup): string {
  const numBit = p.uniformNumber !== null && p.uniformNumber !== undefined ? ` <span class="header-num">#${escapeHtml(p.uniformNumber)}</span>` : ''
  const tagBit = SESSION_TAG_LABELS[p.purpose ?? ''] ? ' · ' + SESSION_TAG_LABELS[p.purpose ?? ''] : ''
  return `
  <header class="report-header kr-head">
    <div class="kr-head-top"><div class="brand-mark">KNUCKLEBALL</div><span class="sport-tag">${asSport(p.sport) === 'softball' ? 'Softball' : 'Baseball'} · Bullpen</span></div>
    <h1>${escapeHtml(p.pitcherName)}${numBit}</h1>
    <p class="header-meta">${penDate(p)}${tagBit}${p.teamName ? ' · ' + escapeHtml(p.teamName) : ''}</p>
    ${tabBarVersions(id, penTabLabels(g))}
  </header>`
}
// SR1 E: each version's tabs (decision 10). Panels: 1 Summary · 2 Command · 3 Velocity & workload · 4 Trends ·
// 5 Where it went · 6 Progress without velocity (both little league player only)
function penTabLabels(g: LevelGroup) {
  const C = ['coach'], full = g === 'college' ? ['coach', 'player'] : C
  return [
    { panel: 1, label: 'Summary', versions: versionsFor(g) },
    { panel: 2, label: 'Command', versions: g === 'hs' ? ['coach', 'player'] : full },
    { panel: 3, label: 'Velocity & workload', versions: full },
    ...(g === 'hs' ? [{ panel: 3, label: 'Velocity', versions: ['player'] }] : []),
    { panel: 4, label: 'Trends', versions: full },
    ...(g === 'hs' ? [{ panel: 4, label: 'Progress', versions: ['player'] }] : []),
    ...(g === 'll' ? [{ panel: 5, label: 'Where it went', versions: ['player'] }, { panel: 6, label: 'Progress', versions: ['player'] }, { panel: 4, label: 'Progress', versions: ['parent'] }] : [])
  ]
}
// The pen's own numbers, everything the tabs and the rules read
function penFacts(p: ReportPayload) {
  const gs = p.gridSize ?? 5
  const ps = p.pitches
  const allTypes = p.pitchTypes.length ? p.pitchTypes : Array.from(new Set(ps.map(x => x.type)))
  const thrown = allTypes.filter(t => ps.some(x => x.type === t))
  const strike = (x: Pitch) => isStrikeCell(x.actualRow, x.actualCol, gs)
  const fb = pickFastball(ps)
  const byType = thrown.map(t => {
    const tp = ps.filter(x => x.type === t)
    return { type: t, n: tp.length, strikes: tp.filter(strike).length, hits: tp.filter(isHit).length, velo: avgVelo(tp),
      lo: Math.min(...tp.map(x => x.velo).filter(gunned)), hi: Math.max(...tp.map(x => x.velo).filter(gunned)) }
  })
  return {
    gs, ps, allTypes, thrown, strike, fb, byType,
    n: ps.length, hits: ps.filter(isHit).length, strikes: ps.filter(strike).length,
    spot: pctOf(ps.filter(isHit).length, ps.length), strikePct: pctOf(ps.filter(strike).length, ps.length),
    fbVelo: fb.type ? avgVelo(ps.filter(x => x.type === fb.type)) : null,
    anyVelo: ps.some(x => gunned(x.velo))
  }
}
type PenFacts = ReturnType<typeof penFacts>

// "you" (the player's versions) or the first name (coach and parent): whose normal range, whose pitch
const whose = (p: ReportPayload, v: Voice) => v === 'you' ? 'your' : escapeHtml(firstName(p.pitcherName)) + "'s"
const typeSay = (t: string, v: Voice) => v === 'you' ? 'Your ' + escapeHtml(t.toLowerCase()) : escapeHtml(t)

function penStoodOut(p: ReportPayload, f: PenFacts, c: Comparison, v: Voice = 'coach'): StoodOut[] {
  const ws = c.baselines?.windows?.['3m']
  const who = whose(p, v)
  const items: StoodOut[] = []
  const rate = (metric: string, cur: number | null, range: [number, number] | undefined, minW: number, text: (dir: string, r: string) => string, unit: string, neutral = false) => {
    const o = outsideRange(cur, range, minW)
    if (!o || !range) return
    items.push({ kind: 'rate', metric, size: o.size, mark: neutral ? 'info' : o.dir === 'above' ? 'up' : 'down', text: text(o.dir, rangeText(range, unit)) })
  }
  if (ws?.range) {
    rate('spot', f.spot, ws.range.spot_pct, 5, (d, r) => `On the spot ${f.spot}% (${f.hits} of ${f.n}), ${d} ${who} normal range (${r}).`, '%')
    rate('strike', f.strikePct, ws.range.strike_pct, 5, (d, r) => `Strikes ${f.strikePct}% (${f.strikes} of ${f.n}), ${d} ${who} normal range (${r}).`, '%')
    rate('pitches', f.n, ws.range.pitches, 5, (d, r) => `${f.n} pitches, ${d === 'above' ? 'more' : 'fewer'} than ${who} normal range (${r}).`, '', true)
  }
  for (const t of f.byType) {
    const tr = ws?.types?.[t.type]?.range
    if (!tr) continue
    if (t.n >= typeMin) {
      rate('spot', pctOf(t.hits, t.n), tr.spot_pct, 5, (d, r) => `${typeSay(t.type, v)} hit its spot ${pctOf(t.hits, t.n)}% (${t.hits} of ${t.n}), ${d} ${who} normal range (${r}).`, '%')
      rate('strike', pctOf(t.strikes, t.n), tr.strike_pct, 5, (d, r) => `${typeSay(t.type, v)} strikes ${pctOf(t.strikes, t.n)}% (${t.strikes} of ${t.n}), ${d} ${who} normal range (${r}).`, '%')
    }
    if (t.type === f.fb.type && f.fbVelo !== null) rate('velo', f.fbVelo, tr.velo, 1, (d, r) => `${v === 'you' ? 'Your ' : ''}${escapeHtml(f.fb.label)} averaged ${f.fbVelo} mph, ${d} ${who} normal range (${r} mph).`, 'mph')
  }
  items.push(...missPattern(f.ps, isHit as (p: never) => boolean, c.throws, f.thrown))
  const fade = fadePattern(f.ps, f.fb.type, f.fb.label); if (fade) items.push(fade)
  const side = sidePattern(f.ps, f.strike as (p: never) => boolean); if (side) items.push(side)
  return sortStoodOut(items)
}

// best / toughest of the last k same-kind, same-tag pens (this one + up to 5 before, 10+ pitches each)
function penRank(f: PenFacts, c: Comparison): { k: number; best: boolean; worst: boolean } {
  const k = Math.min(6, 1 + c.recent.length)
  if (f.n < 10 || f.spot === null || k < 4) return { k, best: false, worst: false }
  const spots = c.recent.slice(0, k - 1).map(r => r.pitches ? 100 * r.hits / r.pitches : 0)
  return { k, best: f.spot > Math.max(...spots), worst: f.spot < Math.min(...spots) }
}
function penHeadline(p: ReportPayload, f: PenFacts, c: Comparison, items: StoodOut[], v: Voice = 'coach'): string {
  const pen = penWord(p.purpose)
  const r = penRank(f, c)
  const lead = f.byType.filter(t => t.n >= typeMin).sort((a, b) => b.hits / b.n - a.hits / a.n)[0]
  if (r.best) return `${v === 'you' ? 'Your best' : 'Best'} ${pen} of the last ${word(r.k)}: ${f.spot}% on the spot${lead ? `, led by ${v === 'you' ? 'your' : 'the'} ${escapeHtml(lead.type.toLowerCase())}` : ''}.`
  if (r.worst) {
    const miss = items.find(i => i.kind === 'misses')
    return `${v === 'you' ? 'Your toughest' : 'Toughest'} ${pen} of the last ${word(r.k)}: ${f.spot}% on the spot${miss ? `, ${escapeHtml((miss.type ?? '').toLowerCase())} misses went ${DIR_WORDS[miss.dir ?? ''] ?? ''}` : ''}.`
  }
  if (items.length) return items[0].text
  return `${f.spot ?? 0}% on the spot and ${f.strikePct ?? 0}% strikes over ${f.n} pitch${f.n === 1 ? '' : 'es'}.`
}

function penWindows(p: ReportPayload, c: Comparison, id: string, tiles: TileSpec[], v: Voice, cls = ''): string {
  const first = firstName(p.pitcherName)
  const extra = p.purpose && SESSION_TAG_LABELS[p.purpose] ? ` · ${penWord(p.purpose)}s only` : ''
  const wins = c.baselines ? WINDOWS.map(w => w.key).filter(k => c.baselines!.windows[k]) : []
  return wins.length
    ? windowSwitch(id, wins) + wins.map(k => wb(k, windowCaption(first, k, c.baselines!.windows[k], 'pen', extra, v)
        + `<div class="kr-tiles${cls}">${tiles.map(t => tileFor(t, c.baselines!.windows[k], 'pen')).join('')}</div>`)).join('')
    : `<div class="kr-tiles${cls}">${tiles.map(t => tileFor(t, undefined, 'pen')).join('')}</div><p class="kr-wcap">No earlier sessions to compare with yet.</p>`
}
function penTiles(f: PenFacts): TileSpec[] {
  return [
    { label: 'On the spot', cur: f.spot, unit: '%', key: 'spot_pct' },
    { label: 'Strike %', cur: f.strikePct, unit: '%', key: 'strike_pct' },
    { label: `${f.fb.label} avg mph`, cur: f.fbVelo, unit: 'mph', key: 'velo', type: f.fb.type ?? undefined, sub: f.anyVelo ? 'not gunned' : 'radar off' },
    { label: 'Pitches', cur: f.n, unit: '', key: 'pitches', neutral: true }
  ]
}
// The full Summary: the coach's, and in "you" for a high school (top two items) or college player
function penSummary(p: ReportPayload, f: PenFacts, c: Comparison, id: string, items: StoodOut[], v: Voice = 'coach', maxItems = 3): string {
  const chartedBy = p.loggedByCoach ? 'the coaching staff' : escapeHtml(p.pitcherName)
  const sided = f.ps.filter(x => x.batterSide === 'R' || x.batterSide === 'L').length
  const batterBit = !f.n ? '' : sided === 0 ? ' · No batter' : sided < f.n ? ' · Mixed' : ''
  const tag = p.purpose && SESSION_TAG_LABELS[p.purpose] ? ` · ${penWord(p.purpose)} (tagged at start)` : ''
  const head = card('', `<h2 class="kr-headline">${penHeadline(p, f, c, items, v)}</h2>
    <p class="kr-sub">${penDate(p)}${tag} · ${f.n} pitch${f.n === 1 ? '' : 'es'} · ${f.thrown.length} pitch type${f.thrown.length === 1 ? '' : 's'}${batterBit} · charted by ${chartedBy}</p>`)
  return head + penWindows(p, c, id, penTiles(f), v)
    + stoodOutCard(items.slice(0, maxItems), !!c.baselines?.windows?.['3m']?.range, firstName(p.pitcherName), 'What stood out', v)
    + sevenDayCard(c.workload) + penViewCaption(p)
}
// Little league player (b08): two numbers, what went well, no velocity anywhere
function penSummaryLLPlayer(p: ReportPayload, f: PenFacts, c: Comparison, id: string, itemsYou: StoodOut[]): string {
  const r = penRank(f, c)
  const head = card('', `<h2 class="kr-headline">${f.hits} of your ${f.n} pitches hit your spot.${r.best ? ` Your best pen of the last ${word(r.k)}!` : ''}</h2>
    <p class="kr-sub">${r.best ? `Best of your last ${r.k} bullpens.` : `${penDate(p)} · ${f.n} pitches`}</p>`)
  const well = itemsYou.filter(i => i.mark === 'up' && i.metric !== 'velo' && i.kind !== 'fade')
  const top = f.byType.filter(t => t.n >= 1).sort((a, b) => b.hits / b.n - a.hits / a.n)[0]
  const fallback: StoodOut[] = top ? [{ mark: 'up', kind: 'rate', size: 0, text: `Your ${escapeHtml(top.type.toLowerCase())} hit your spot ${top.hits} of ${top.n} times.` }] : []
  return head + penWindows(p, c, id, penTiles(f).slice(0, 2), 'you')
    + stoodOutCard(well.length ? well : fallback, true, firstName(p.pitcherName), 'What went well', 'you')
    + sevenDayCard(c.workload, true)
    + `<p class="kr-novelo">No velocity on this version. Your coach and parents can see it.</p>`
}
// Little league parent (b11): workload and rest first, one line on how it went
function penSummaryLLParent(p: ReportPayload, f: PenFacts, c: Comparison): string {
  const w = c.workload, baseball = asSport(p.sport) === 'baseball'
  const first = escapeHtml(firstName(p.pitcherName))
  const r = penRank(f, c)
  const tag = p.purpose && SESSION_TAG_LABELS[p.purpose] ? ` (${penWord(p.purpose)})` : ''
  let restLine = "Pitch Smart's rest rules count game pitches; no games in the last 7 days."
  const game = w?.parts.filter(x => x.kind === 'game' && !x.this).slice(-1)[0]
  if (game) {
    const d = w?.age_group ? restDays(w.age_group, game.pitches) : null
    const day = new Date(game.started_at).toLocaleDateString('en-US', { weekday: 'long', timeZone: 'America/New_York' })
    restLine = d === null ? `Pitch Smart's rest rules count game pitches: ${day}'s game had ${game.pitches}.`
      : `Pitch Smart's rest rules count game pitches: ${day}'s game rest ends ${backDate(Date.parse(game.started_at), d)}.`
  }
  const workload = baseball ? `<section class="kr-card kr-work"><h3 class="kr-label">Workload</h3><div class="kr-rest-big">${f.n} pitches in this pen${tag}</div><p class="kr-sub">${restLine}</p></section>` + sevenDayCard(w) : ''
  const how = card('How it went', `<h2 class="kr-headline">${f.hits} of ${f.n} pitches hit the spot${r.best ? `, ${first}'s best pen of the last ${word(r.k)}` : ''}.</h2>`)
  const a3 = c.baselines?.windows?.['3m']?.avg
  const wordFor = (cur: number | null, avg: number | undefined, best = false) => best ? '<span class="kr-word kr-up">best yet</span>'
    : cur === null || avg === undefined || avg === null ? '' : `<span class="kr-word">${cur - Math.round(avg) >= 3 ? 'above usual' : cur - Math.round(avg) <= -3 ? 'below usual' : 'steady'}</span>`
  const tile = (label: string, val: string, wd: string) => `<div class="kr-tile"><div class="kr-tile-lbl">${label}</div><div class="kr-tile-val">${val}</div>${wd}</div>`
  const tiles = `<div class="kr-tiles kr-tiles-3">${tile('Strikes', `${f.strikePct ?? 0}%`, wordFor(f.strikePct, a3?.strike_pct))}${tile('On the spot', `${f.spot ?? 0}%`, wordFor(f.spot, a3?.spot_pct, r.best))}${tile('Pitches', String(f.n), '')}</div>`
  return workload + how + tiles
}
// SR1 Stage F: each version's email (packet section 3 Stage F; e02), frozen into the report. The bullets never repeat
// the headline (it is often the top item).
const bullets = (items: StoodOut[], headline: string) => items.filter(i => i.text !== headline).slice(0, 2).map(i => i.text)
function penEmails(p: ReportPayload, f: PenFacts, c: Comparison, g: LevelGroup, items: StoodOut[], itemsYou: StoodOut[]): Record<string, EmailVersion> {
  const name = p.pitcherName, first = firstName(name), date = shortDate(p.date), r = penRank(f, c)
  const velo = f.fbVelo !== null ? [{ v: String(Math.round(f.fbVelo)), l: `${f.fb.label} avg` }] : []
  const four = [{ v: `${f.spot ?? 0}%`, l: 'On the spot' }, { v: `${f.strikePct ?? 0}%`, l: 'Strike' }, ...velo, { v: String(f.n), l: 'Pitches' }]
  const subject = `Bullpen report: ${name} · ${f.hits} of ${f.n} on the spot · ${date}`
  const lines = (who: string, kid = false) => [sevenDayEmailLine(c.workload, kid), comparedEmailLine(c, who, 'pen')].filter(Boolean) as EmailVersion['lines']
  const out: Record<string, EmailVersion> = {
    coach: { subject, headline: penHeadline(p, f, c, items), stats: four, bullets: bullets(items, penHeadline(p, f, c, items)), lines: lines(escapeHtml(first) + "'s"), button: 'Open the full report' }
  }
  const youSubject = `Your bullpen report: ${f.hits} of ${f.n} on the spot · ${date}`
  if (g === 'll') {
    const top = f.byType.filter(t => t.n >= 1).sort((a, b) => b.hits / b.n - a.hits / a.n)[0]
    out.player = { subject: youSubject, headline: `${f.hits} of your ${f.n} pitches hit your spot.${r.best ? ` Your best pen of the last ${word(r.k)}!` : ''}`,
      stats: [{ v: `${f.strikePct ?? 0}%`, l: 'Strikes' }, { v: `${f.spot ?? 0}%`, l: 'On your spot' }, ...(top ? [{ v: `${top.hits}/${top.n}`, l: `${escapeHtml(abbrOf(top.type))} on spot` }] : [])],
      bullets: [], lines: [sevenDayEmailLine(c.workload, true)].filter(Boolean) as EmailVersion['lines'], button: 'See where every pitch went' }
    out.parent = { subject, headline: `${f.hits} of ${f.n} pitches hit the spot${r.best ? `, ${escapeHtml(first)}'s best pen of the last ${word(r.k)}` : ''}.`,
      stats: [{ v: `${f.strikePct ?? 0}%`, l: 'Strikes' }, { v: `${f.spot ?? 0}%`, l: 'On the spot' }, { v: String(f.n), l: 'Pitches' }],
      bullets: [], lines: lines(escapeHtml(first) + "'s"), button: 'Open the full report' }
  } else {
    out.player = { subject: youSubject, headline: penHeadline(p, f, c, itemsYou, 'you'), stats: four, bullets: bullets(itemsYou, penHeadline(p, f, c, itemsYou, 'you')), lines: lines('your'), button: 'Open the full report' }
  }
  return out
}
function penViewCaption(p: ReportPayload): string {
  const note = viewNote(p.chartingPerspective).replace('class="header-note"', 'class="caption"')
  return (note || `<p class="caption">Every grid in this report is drawn in the ${VIEW_NAME}, ${REPORT_VIEW === 'pitcher' ? 'looking in from the mound toward home plate' : 'looking out toward the mound'}.</p>`)
}
// Little league player: Where it went (b09) -- the hit / miss grids and one line per pitch, no velocity
function penWhereItWent(p: ReportPayload, f: PenFacts, c: Comparison): string {
  const grids = drawHitTypeGrids({ gridSize: f.gs, batterSide: null, allTypes: f.allTypes, raOn: !!p.raOn,
    pitches: f.ps.map(x => ({ type: x.type, row: x.actualRow, col: x.actualCol, kind: x.accuracyHitKind || (isHit(x) ? 'exact' : 'miss') })) })
  const best = f.byType.slice().sort((a, b) => b.hits / b.n - a.hits / a.n)[0]
  const lines: StoodOut[] = f.byType.map(t => ({ mark: t === best ? 'up' as const : 'info' as const, kind: 'rate', size: 0, text: `${escapeHtml(t.type)}: ${t.hits} of ${t.n} on your spot.` }))
  missPattern(f.ps, isHit as (p: never) => boolean, c.throws, f.thrown).forEach(m => lines.push({ ...m, mark: 'info', text: `${escapeHtml(m.type ?? '')}: most misses went ${DIR_WORDS[m.dir ?? ''] ?? ''}.` }))
  return takeaway('Where your pitches went')
    + card('', `${grids}<p class="caption">Filled = hit the spot · ring = missed it. ${VIEW_NAME[0].toUpperCase() + VIEW_NAME.slice(1)}.</p>`)
    + `<section class="kr-card"><ul class="kr-sos">${lines.map(it => `<li class="kr-so"><span class="kr-mk kr-mk-${it.mark}">${it.mark === 'up' ? '▲' : 'i'}</span><span>${it.text}</span></li>`).join('')}</ul></section>`
}
// Little league player: Progress without velocity
function penProgressLite(p: ReportPayload, f: PenFacts): string {
  const hist = p.history.filter(h => (safeNum(h.total) ?? 0) >= 10).slice(-5)
  if (hist.length < 2) return takeaway('Your progress starts once you have three pens') + card('', `<p class="caption">This page draws one line per number once you have at least three pens of 10 or more pitches on this team.</p>`)
  const k = hist.length + 1
  return takeaway(`Your last ${word(k)} pens`)
    + sparkCard('On the spot', [...hist.map(h => h.commandPct), f.spot], `${f.spot ?? 0}%`, `last ${k} pens`)
    + sparkCard('Strike %', [...hist.map(h => h.strikePct), f.strikePct], `${f.strikePct ?? 0}%`, `last ${k} pens`)
    + sparkCard('Pitches', [...hist.map(h => h.total), f.n], String(f.n), `last ${k} pens`)
}

function penCommand(p: ReportPayload, f: PenFacts, c: Comparison): string {
  const ok = f.byType.filter(t => t.n >= typeMin).sort((a, b) => b.hits / b.n - a.hits / a.n)
  const hl = !ok.length ? (f.byType.length ? `${f.spot ?? 0}% on the spot over ${f.n} pitches` : 'No pitches charted')
    : ok.length === 1 ? `${escapeHtml(ok[0].type)} found its spot ${pctOf(ok[0].hits, ok[0].n)}%`
    : `${escapeHtml(ok[0].type)} found its spot ${pctOf(ok[0].hits, ok[0].n)}%; ${escapeHtml(ok[ok.length - 1].type.toLowerCase())} ${pctOf(ok[ok.length - 1].hits, ok[ok.length - 1].n)}%`
  const grids = drawHitTypeGrids({ gridSize: f.gs, batterSide: null, allTypes: f.allTypes, raOn: !!p.raOn,
    pitches: f.ps.map(x => ({ type: x.type, row: x.actualRow, col: x.actualCol, kind: x.accuracyHitKind || (isHit(x) ? 'exact' : 'miss') })) })
  const wins = c.baselines ? WINDOWS.map(w => w.key).filter(k => c.baselines!.windows[k]) : []
  const vsAvg = (t: string, cur: number | null) => {
    if (cur === null || !wins.length) return '—'
    return wins.map(k => {
      const a = c.baselines!.windows[k].types?.[t]?.avg?.spot_pct
      if (a === undefined || a === null) return wi(k, '—')
      const d = cur - Math.round(a)   // from the average as shown
      return wi(k, `<span class="${d > 0 ? 'kr-up' : d < 0 ? 'kr-down' : 'kr-faint'}">${d > 0 ? '+' : d < 0 ? '−' : ''}${Math.abs(d)}</span>`)
    }).join('')
  }
  const typeTable = simpleTable(['Pitch', '#', 'Strike', 'Spot', 'vs avg'],
    f.byType.map(t => [typeCell(t.type, f.allTypes), String(t.n), `${pctOf(t.strikes, t.n)}%`, `${pctOf(t.hits, t.n)}%`, vsAvg(t.type, pctOf(t.hits, t.n))]))
  const dirs = c.throws ? ['up', 'down', 'arm', 'glove'] : ['up', 'down', 'left', 'right']
  const dirHead = c.throws ? ['Up', 'Down', 'Arm', 'Glove'] : ['Up', 'Down', 'Left', 'Right']
  const missRow = (label: string, ps: Pitch[]) => {
    const cnt: Record<string, number> = {}
    ps.filter(x => !isHit(x)).forEach(m => missDirs(m, c.throws).forEach(d => { cnt[d] = (cnt[d] || 0) + 1 }))
    const max = Math.max(0, ...dirs.map(d => cnt[d] || 0))
    return [label, ...dirs.map(d => (cnt[d] || 0) && (cnt[d] || 0) === max ? `<strong>${cnt[d]}</strong>` : String(cnt[d] || 0))]
  }
  const missRows = [missRow('All', f.ps), ...f.byType.filter(t => t.n > t.hits).map(t => missRow(escapeHtml(t.type), f.ps.filter(x => x.type === t.type)))]
  const missCap = c.throws ? 'From each pitch\'s target. A miss up and to one side counts in both.' : 'From each pitch\'s target, left and right as drawn (the throwing hand isn\'t set). A miss up and to one side counts in both.'
  const sideRow = (label: string, ps: Pitch[]) => ps.length ? [label, String(ps.length), `${pctOf(ps.filter(f.strike).length, ps.length)}%`, `${pctOf(ps.filter(isHit).length, ps.length)}%`] : null
  const sideRows = [sideRow('vs right', f.ps.filter(x => x.batterSide === 'R')), sideRow('vs left', f.ps.filter(x => x.batterSide === 'L')), sideRow('No batter', f.ps.filter(x => !x.batterSide))].filter((r): r is string[] => !!r)
  return takeaway(hl)
    + card('', `${grids}<p class="caption">Filled = hit the spot · ring = missed it. ${VIEW_NAME[0].toUpperCase() + VIEW_NAME.slice(1)}.</p>`)
    + card('By pitch type', typeTable + (wins.length ? `<p class="caption">vs avg: on-the-spot points against the window chosen on Summary.</p>` : ''))
    + (f.n > f.hits ? card('Where misses went', simpleTable(['', ...dirHead], missRows) + `<p class="caption">${missCap}</p>`) : '')
    + (sideRows.length ? card('By batter side', simpleTable(['', 'Pitches', 'Strike', 'Spot'], sideRows)) : '')
    + renderPerSideBlocks(p) + renderLocationChart(p)
}

function penVelocity(p: ReportPayload, f: PenFacts): string {
  const fbV = f.fb.type ? f.ps.filter(x => x.type === f.fb.type).map(x => x.velo).filter(gunned) : []
  const label = escapeHtml(f.fb.label)
  let hl: string
  if (!f.anyVelo) hl = 'No velocity today: the radar gun was off'
  else if (fbV.length >= 20 && fadePattern(f.ps, f.fb.type, f.fb.label)) {
    const head = fbV.slice(0, -10), tail = fbV.slice(-10)
    hl = `${label} held ${Math.min(...head)}–${Math.max(...head)} for ${head.length} pitches, then slid to ${Math.min(...tail)}–${Math.max(...tail)}`
  } else if (fbV.length) hl = `${label} averaged ${avgVelo(f.ps.filter(x => x.type === f.fb.type))} mph (${Math.min(...fbV)}–${Math.max(...fbV)})`
  else hl = 'Velocity by pitch type'
  const chart = fbV.length >= 2 ? card('', fbOrderChart(fbV) + `<p class="caption">Each point is one gunned ${label}, in order.</p>`) : ''
  const rows = f.byType.map(t => [typeCell(t.type, f.allTypes), t.velo === null ? '—' : String(Math.round(t.velo)), t.velo === null ? '—' : (t.lo === t.hi ? String(t.lo) : `${t.lo}–${t.hi}`), `${pctOf(t.n, f.n)}%`])
  const recentTotals = p.history.map(h => safeNum(h.total)).filter((n): n is number => n !== null)
  const recentAvg = recentTotals.length ? Math.round(recentTotals.reduce((a, b) => a + b, 0) / recentTotals.length) : null
  const delivery = asSport(p.sport) === 'softball' ? '' : deliverySplitLine(p).replace('<strong>Delivery:</strong> ', '') + timesToHomeLine(p.pitches)
  return takeaway(hl)
    + chart
    + card('', simpleTable(['Pitch', 'Avg', 'Range', 'Mix'], rows) + (recentAvg !== null ? `<p class="caption">Recent average for this pitcher on this team: ${recentAvg} pitches. This pen: ${f.n}.</p>` : ''))
    + (delivery.trim() ? card('Delivery', delivery) : '')
}
function fbOrderChart(v: number[]): string {
  const lo = Math.floor(Math.min(...v)) - 1, hi = Math.ceil(Math.max(...v)) + 1, W = 560, H = 170, L = 34, R = 10, T = 12, B = 22
  const X = (i: number) => L + (W - L - R) * i / Math.max(1, v.length - 1), Y = (y: number) => T + (H - T - B) * (hi - y) / Math.max(1, hi - lo)
  const ticks = [lo, Math.round((lo + hi) / 2), hi]
  const band = v.length > 10 ? `<rect x="${X(v.length - 10).toFixed(1)}" y="${T}" width="${(X(v.length - 1) - X(v.length - 10)).toFixed(1)}" height="${H - T - B}" fill="var(--kr-hl)"/><text x="${((X(v.length - 10) + X(v.length - 1)) / 2).toFixed(1)}" y="${T + 14}" text-anchor="middle" font-size="12" font-weight="700" fill="var(--kr-accent-ink)">last 10: ${(Math.round(v.slice(-10).reduce((a, b) => a + b, 0)) / 10).toFixed(1).replace(/\.0$/, '')}</text>` : ''
  return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Fastball velocity by pitch order">${band}${ticks.map(t => `<line x1="${L}" x2="${W - R}" y1="${Y(t).toFixed(1)}" y2="${Y(t).toFixed(1)}" stroke="var(--kr-grid)"/><text x="${L - 6}" y="${(Y(t) + 4).toFixed(1)}" text-anchor="end" font-size="11" fill="var(--kr-axis)">${t}</text>`).join('')}<polyline fill="none" stroke="var(--kr-accent)" stroke-width="2.5" stroke-linejoin="round" points="${v.map((y, i) => X(i).toFixed(1) + ',' + Y(y).toFixed(1)).join(' ')}"/><text x="${L}" y="${H - 4}" font-size="11" fill="var(--kr-axis)">1st</text><text x="${W - R}" y="${H - 4}" text-anchor="end" font-size="11" fill="var(--kr-axis)">${ordinal(v.length)}</text></svg>`
}

function penTrends(p: ReportPayload, f: PenFacts): string {
  const hist = p.history.filter(h => (safeNum(h.total) ?? 0) >= 10).slice(-5)   // the baselines' 10-pitch rule (Joel, Nov 19)
  if (hist.length < 2) return takeaway('Trends start once there are three pens') + card('', `<p class="caption">This report draws one line per number once this pitcher has at least three pens of 10 or more pitches on this team.</p>`)
  const k = hist.length + 1
  const allVelo = avgVelo(f.ps)
  const series = [
    { label: 'On the spot', name: 'On-the-spot rate', v: [...hist.map(h => h.commandPct), f.spot], txt: `${f.spot ?? 0}%` },
    { label: 'Strike %', name: 'Strike rate', v: [...hist.map(h => h.strikePct), f.strikePct], txt: `${f.strikePct ?? 0}%` },
    { label: 'Avg mph', name: 'Velocity', v: [...hist.map(h => h.hasVelo ? h.avgVelo : null), allVelo], txt: allVelo === null ? '—' : String(Math.round(allVelo)) },
    { label: 'Pitches', name: 'Pitch count', v: [...hist.map(h => h.total), f.n], txt: String(f.n) }
  ]
  let hl = `${word(k)[0].toUpperCase() + word(k).slice(1)} pens of trends: on the spot, strikes, velocity and pitches`
  let best = 0
  for (const s of series.slice(0, 3)) {
    const v = s.v.filter((x): x is number => x !== null && x !== undefined)
    let up = 0, down = 0
    for (let i = 1; i < v.length; i++) { if (v[i] > v[i - 1]) up++; else if (v[i] < v[i - 1]) down++ }
    const m = Math.max(up, down)
    if (v.length >= 4 && m >= 3 && m > best) { best = m; hl = `${s.name} has ${up >= down ? 'climbed' : 'fallen'} in ${m} of the last ${v.length - 1} pens` }
  }
  return takeaway(hl) + series.map(s => sparkCard(s.label, s.v.map(x => x ?? null), s.txt, `last ${k} pens`)).join('')
}

export function buildReportHtml(p: ReportPayload): string {
  const title = `Bullpen Report — ${p.pitcherName}`
  const c = p.comparison ?? NO_COMPARISON
  const id = ids(p.sessionId)
  const f = penFacts(p)
  const items = penStoodOut(p, f, c)
  const itemsYou = penStoodOut(p, f, c, 'you')
  const g = levelGroup(c.workload?.level ?? c.baselines?.level ?? null)   // SR1 E: the versions this file carries
  const wins = c.baselines ? WINDOWS.map(w => w.key).filter(k => c.baselines!.windows[k]) : []
  const tl = penTabLabels(g), pt = printTitle(p.pitcherName, 'Bullpen', penDate(p), wins)   // SR1 G: print
  const links = `<p><span class="brand-mark small">Knuckleball LLC 2026</span> &middot; <a href="${signInUrl(asSport(p.sport))}">knuckleballonline.com</a> &middot; <a href="https://knuckleballonline.com/privacy.html#${asSport(p.sport)}">Privacy</a> &middot; <a href="https://knuckleballonline.com/terms.html#${asSport(p.sport)}">Terms</a> &middot; generated ${new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: TZ })}</p>`
  // D2: this report's own colors and fonts (--kr-*) for its sport -- no hex swap, no site stylesheet.
  return (`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${escapeHtml(title)}</title>
<style>${reportVars(asSport(p.sport))}${CSS}${SR1_CSS}</style>
</head>
<body>
<div class="page kr" data-kr-versions="${versionsFor(g).join(' ')}">
${radios(id, ['1', '2', '3', '4', '5', '6'], wins)}
${penHeader(p, id, g)}
<main class="kr-main">
${panel(1, ver(['coach'], penSummary(p, f, c, id, items))
  + (g === 'll' ? ver(['player'], penSummaryLLPlayer(p, f, c, id, itemsYou)) + ver(['parent'], penSummaryLLParent(p, f, c))
    : ver(['player'], penSummary(p, f, c, id, itemsYou, 'you', g === 'hs' ? 2 : 3))), tl, pt)}
${panel(2, penCommand(p, f, c), tl, pt)}
${panel(3, penVelocity(p, f), tl, pt)}
${panel(4, penTrends(p, f), tl, pt)}
${g === 'll' ? panel(5, penWhereItWent(p, f, c), tl, pt) + panel(6, penProgressLite(p, f), tl, pt) : ''}
</main>
${footer(firstName(p.pitcherName), links, true)}
</div>
${emailComment(penEmails(p, f, c, g, items, itemsYou))}
</body>
</html>`)
}
