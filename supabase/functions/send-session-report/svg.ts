// ============================================================================
// Inline SVG drawing -- no charting library, no external requests. Every
// function returns a plain string of SVG markup. Grid size is a parameter.
// ============================================================================
import { isStrikeCell, zoneNumber, colorForType, escapeHtml, viewCol, RESULT_COLOR, hitColors } from './helpers.ts'

export interface Pt { row: number; col: number; type: string }

// The ONE pitch-location dot, used by every report grid (drawGrid and
// drawGridByResult) -- callers only choose the color. Each dot gets a halo
// (2x radius) in its own color: that's what makes a cluster read as a
// cluster and a lone pitch stand out from the grid lines. All halos go in
// one <g opacity> drawn under all dots: group opacity composites the group
// as a whole, so overlapping halos never stack darker than 0.28 (no mud)
// and every solid dot, still drawn in pitch order, sits on top with its
// color clear. The solid dot + outline alone carries the location (see
// .kb-dot's print rule in template.ts), so halos are never the only cue.
// Overlapping pitches at the same cell spiral outward (golden-angle
// jitter), same technique the PDF used. Radius was clamp(cell*0.09, 2.2,
// 3.6) before -- 3.6 on every 5x5, 260px report grid -- now +25%.
interface DotPt { row: number; col: number; color: string }
function drawDots(pitches: DotPt[], cell: number): string {
  const r = +Math.max(2.75, Math.min(4.5, cell * 0.1125)).toFixed(2)
  const seen: Record<string, number> = {}
  let halos = '', dots = ''
  for (const p of pitches) {
    const key = p.row + '-' + p.col
    const idx = seen[key] || 0
    seen[key] = idx + 1
    const cx = p.col * cell + cell / 2, cy = p.row * cell + cell / 2
    const angle = idx * 137.508 * (Math.PI / 180)
    const radius = idx === 0 ? 0 : Math.min(cell * 0.32, 2.5 + idx * 1.8)
    const x = (cx + radius * Math.cos(angle)).toFixed(1), y = (cy + radius * Math.sin(angle)).toFixed(1)
    halos += `<circle cx="${x}" cy="${y}" r="${r * 2}" style="fill:${p.color}"/>`
    dots += `<circle class="kb-dot" cx="${x}" cy="${y}" r="${r}" style="fill:${p.color}" stroke="#FFFFFF" stroke-width="0.8"/>`
  }
  return `<g opacity="0.28">${halos}</g>${dots}`
}

// A location grid. batterSide is null for a MIXED-side plot (physical framing,
// no 1-9 numbers, no zone names -- per the framing rule); a real side ('R'|'L')
// draws the D8 numbers and is safe to pair with zone-name callouts elsewhere.
export function drawGrid(opts: {
  size?: number          // px, square
  gridSize?: number       // cells per side (5 today; U2b will pass 7)
  batterSide: 'R' | 'L' | null
  pitches: Pt[]
  allTypes: string[]
}): string {
  const size = opts.size ?? 260
  const gridSize = opts.gridSize ?? 5
  const cell = size / gridSize
  const { batterSide, pitches, allTypes } = opts

  let cells = ''
  for (let row = 0; row < gridSize; row++) {
    for (let col = 0; col < gridSize; col++) {
      const x = col * cell, y = row * cell
      const inZone = isStrikeCell(row, col, gridSize)
      cells += `<rect x="${x}" y="${y}" width="${cell}" height="${cell}" style="fill:${inZone ? 'var(--kr-surface)' : 'var(--kr-card)'};stroke:var(--kr-line)" stroke-width="1"/>`
      if (batterSide) {
        const num = zoneNumber(row, viewCol(col, gridSize), batterSide, gridSize)   // label from the STORED column (Amendment 16)
        if (num !== null) cells += `<text x="${x + 4}" y="${y + 11}" font-size="8" style="fill:var(--kr-axis);font-family:var(--kr-sans)">${num}</text>`
      }
    }
  }

  const dots = drawDots(pitches.map(p => ({ row: p.row, col: viewCol(p.col, gridSize), color: colorForType(p.type, allTypes) })), cell)

  return `<svg viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" role="img" aria-label="Pitch location grid">` +
    `<rect x="0" y="0" width="${size}" height="${size}" style="fill:var(--kr-card);stroke:var(--kr-line)"/>` + cells + dots + `</svg>`
}

// U11 (4): one small location grid per pitch type -- report view (Amendment 16),
// physical framing (batterSide null: both sides mixed, so no 1-9 numbers),
// drawn by the SAME drawGrid -> drawDots as every other report grid (same
// palette, dots and halos). Each report supplies its own per-type count and
// strike % so these always match that report's own tables (a bullpen's
// strike % is location-based, a game's is result-based). A type with very
// few pitches still gets its grid; the count beside it is the warning.
export function drawTypeGrids(opts: {
  gridSize?: number
  allTypes: string[]
  pitches: Pt[]
  stats: Record<string, { count: number; strikePct: number | null }>
}): string {
  const cells = opts.allTypes.filter(t => opts.stats[t] && opts.stats[t].count > 0).map(type => {
    const st = opts.stats[type]
    const grid = drawGrid({
      size: 150, gridSize: opts.gridSize, batterSide: null,
      pitches: opts.pitches.filter(pt => pt.type === type), allTypes: opts.allTypes
    })
    const strike = st.strikePct === null ? '' : ` · ${st.strikePct}% strikes`
    return `<div class="type-grid">
      <h3><span class="legend-dot" style="background:${colorForType(type, opts.allTypes)}"></span>${escapeHtml(type)}</h3>
      ${grid}
      <p class="type-grid-stats">${st.count} pitch${st.count === 1 ? '' : 'es'}${strike}</p>
    </div>`
  }).join('')
  return `<div class="type-grids">${cells}</div>`
}

export function drawLegend(types: string[]): string {
  return `<div class="legend">${types.map(t =>
    `<span class="legend-item"><span class="legend-dot" style="background:${colorForType(t, types)}"></span>${escapeHtml(t)}</span>`
  ).join('')}</div>`
}

// G2 content spec item 4: the game report's SECOND location chart is
// colored by result (ball/called strike/swing-and-miss/foul/in play), not
// by pitch type -- drawGrid above stays untouched (the bullpen path must
// render byte-for-byte identically, acceptance 14) so this is a sibling,
// not a parameter added to it. Same physical framing, same no-numbers-on-
// mixed-side rule as drawGrid.
export const RESULT_CATEGORIES = ['ball', 'called_strike', 'swinging_strike', 'foul', 'in_play', 'other'] as const
export type ResultCategory = typeof RESULT_CATEGORIES[number]
const RESULT_COLORS: Record<ResultCategory, string> = RESULT_COLOR   // D2: helpers.ts
export const RESULT_LABELS: Record<ResultCategory, string> = {
  ball: 'Ball', called_strike: 'Called strike', swinging_strike: 'Swing and miss',
  foul: 'Foul', in_play: 'In play', other: 'Other (HBP/interference/etc.)'
}

// A pitches.result value -> one of the 6 buckets above. Only the 5 named
// categories get their own bucket (matching the content spec's own list);
// everything else -- hbp, sac_bunt, sac_fly, dropped_third, interference,
// batter_interference, other -- piles into 'other', matching RESULT_LABELS'
// own documented scope ("Other (HBP/interference/etc.)"). foul_tip joins
// 'foul' (a foul-ball-family outcome, not a separate bucket the spec asked
// for) -- deliberately NOT folded into STRIKE_RESULTS/is_strike anywhere;
// this is a location-chart bucket only, unrelated to strike-% counting.
export function resultCategoryOf(result: string): ResultCategory {
  switch (result) {
    case 'ball': return 'ball'
    case 'strike_looking': return 'called_strike'
    case 'strike_swinging': return 'swinging_strike'
    case 'foul': case 'foul_tip': return 'foul'
    case 'in_play': return 'in_play'
    default: return 'other'
  }
}

export interface ResultPt { row: number; col: number; category: ResultCategory }

export function drawGridByResult(opts: {
  size?: number
  gridSize?: number
  batterSide: 'R' | 'L' | null
  pitches: ResultPt[]
}): string {
  const size = opts.size ?? 260
  const gridSize = opts.gridSize ?? 5
  const cell = size / gridSize
  const { batterSide, pitches } = opts

  let cells = ''
  for (let row = 0; row < gridSize; row++) {
    for (let col = 0; col < gridSize; col++) {
      const x = col * cell, y = row * cell
      const inZone = isStrikeCell(row, col, gridSize)
      cells += `<rect x="${x}" y="${y}" width="${cell}" height="${cell}" style="fill:${inZone ? 'var(--kr-surface)' : 'var(--kr-card)'};stroke:var(--kr-line)" stroke-width="1"/>`
      if (batterSide) {
        const num = zoneNumber(row, viewCol(col, gridSize), batterSide, gridSize)   // label from the STORED column (Amendment 16)
        if (num !== null) cells += `<text x="${x + 4}" y="${y + 11}" font-size="8" style="fill:var(--kr-axis);font-family:var(--kr-sans)">${num}</text>`
      }
    }
  }

  const dots = drawDots(pitches.map(p => ({ row: p.row, col: viewCol(p.col, gridSize), color: RESULT_COLORS[p.category] })), cell)

  return `<svg viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" role="img" aria-label="Pitch location by result">` +
    `<rect x="0" y="0" width="${size}" height="${size}" style="fill:var(--kr-card);stroke:var(--kr-line)"/>` + cells + dots + `</svg>`
}

export function drawResultLegend(categoriesPresent: ResultCategory[]): string {
  return `<div class="legend">${categoriesPresent.map(c =>
    `<span class="legend-item"><span class="legend-dot" style="background:${RESULT_COLORS[c]}"></span>${escapeHtml(RESULT_LABELS[c])}</span>`
  ).join('')}</div>`
}

// A small multi-series line chart (trend section, velocity drift). Each
// series is { label, color, points: [{x:0..1, y:0..1 or null}] } -- callers
// pre-normalize both axes to 0..1; a null y is a gap (that series has no
// value at that x, e.g. a pitch type not thrown in an earlier session).
export function drawLineChart(opts: {
  width?: number; height?: number
  series: { label: string; color: string; points: (number | null)[] }[]
  xLabels: string[]
  yAxisLabels: string[]   // bottom-to-top, evenly spaced
}): string {
  const w = opts.width ?? 560, h = opts.height ?? 220
  const padL = 34, padB = 20, padT = 10, padR = 10
  const plotW = w - padL - padR, plotH = h - padT - padB
  const n = opts.xLabels.length
  const stepX = n > 1 ? plotW / (n - 1) : 0

  let grid = ''
  const gridN = opts.yAxisLabels.length
  for (let i = 0; i < gridN; i++) {
    const frac = gridN > 1 ? i / (gridN - 1) : 0
    const y = padT + plotH - frac * plotH
    grid += `<line x1="${padL}" y1="${y}" x2="${padL + plotW}" y2="${y}" style="stroke:var(--kr-grid)" stroke-width="1"/>`
    grid += `<text x="${padL - 6}" y="${y + 3}" font-size="8" text-anchor="end" style="fill:var(--kr-axis);font-family:var(--kr-sans)">${escapeHtml(opts.yAxisLabels[i])}</text>`
  }
  let xTicks = ''
  opts.xLabels.forEach((label, i) => {
    const x = padL + i * stepX
    xTicks += `<text x="${x}" y="${h - 4}" font-size="8" text-anchor="middle" style="fill:var(--kr-axis);font-family:var(--kr-sans)">${escapeHtml(label)}</text>`
  })

  let lines = ''
  for (const s of opts.series) {
    const pts: { x: number; y: number }[] = []
    s.points.forEach((v, i) => {
      if (v === null) return
      pts.push({ x: padL + i * stepX, y: padT + plotH - v * plotH })
    })
    for (let i = 0; i < pts.length - 1; i++) {
      lines += `<line x1="${pts[i].x.toFixed(1)}" y1="${pts[i].y.toFixed(1)}" x2="${pts[i + 1].x.toFixed(1)}" y2="${pts[i + 1].y.toFixed(1)}" style="stroke:${s.color}" stroke-width="2" fill="none"/>`
    }
    for (const pt of pts) lines += `<circle cx="${pt.x.toFixed(1)}" cy="${pt.y.toFixed(1)}" r="2.6" style="fill:${s.color}"/>`
  }

  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="Trend chart">` +
    `<line x1="${padL}" y1="${padT}" x2="${padL}" y2="${padT + plotH}" style="stroke:var(--kr-line)"/>` +
    `<line x1="${padL}" y1="${padT + plotH}" x2="${padL + plotW}" y2="${padT + plotH}" style="stroke:var(--kr-line)"/>` +
    grid + xTicks + lines + `</svg>`
}

// U14 (Joel, Oct 15): where one pitch type's pitches landed against one batter side, by how they scored:
// exact hits dark, relative-accuracy hits soft, misses as faint hollow rings (so the three counts add to the pitch
// count). Pitcher's view (Amendment 16), D8 numbers from the STORED column. A sibling of drawGrid, which stays as is.
export type HitKind = 'exact' | 'ra' | 'miss'
export function drawHitGrid(opts: { size?: number; gridSize?: number; batterSide: 'R' | 'L' | null; pts: { row: number; col: number; kind: HitKind }[] }): string {
  const size = opts.size ?? 150
  const gridSize = opts.gridSize ?? 5
  const cell = size / gridSize
  const hc = hitColors()
  let cells = ''
  for (let row = 0; row < gridSize; row++) {
    for (let col = 0; col < gridSize; col++) {
      const x = col * cell, y = row * cell
      const inZone = isStrikeCell(row, col, gridSize)
      cells += `<rect x="${x}" y="${y}" width="${cell}" height="${cell}" style="fill:${inZone ? 'var(--kr-surface)' : 'var(--kr-card)'};stroke:var(--kr-line)" stroke-width="1"/>`
      const num = opts.batterSide ? zoneNumber(row, viewCol(col, gridSize), opts.batterSide, gridSize) : null   // no side: no numbers
      if (num !== null) cells += `<text x="${x + 4}" y="${y + 11}" font-size="8" style="fill:var(--kr-axis);font-family:var(--kr-sans)">${num}</text>`
    }
  }
  const r = +Math.max(2.75, Math.min(4.5, cell * 0.1125)).toFixed(2)
  const seen: Record<string, number> = {}
  let marks = ''
  // misses first, so a hit in the same cell sits on top
  const ordered = [...opts.pts.filter(p => p.kind === 'miss'), ...opts.pts.filter(p => p.kind !== 'miss')]
  for (const p of ordered) {
    const vc = viewCol(p.col, gridSize)
    const key = p.row + '-' + vc
    const idx = seen[key] || 0
    seen[key] = idx + 1
    const cx = vc * cell + cell / 2, cy = p.row * cell + cell / 2
    const angle = idx * 137.508 * (Math.PI / 180)
    const radius = idx === 0 ? 0 : Math.min(cell * 0.32, 2.5 + idx * 1.8)
    const x = (cx + radius * Math.cos(angle)).toFixed(1), y = (cy + radius * Math.sin(angle)).toFixed(1)
    marks += p.kind === 'miss'
      ? `<circle cx="${x}" cy="${y}" r="${r}" style="fill:none;stroke:var(--kr-ink-faint)" stroke-width="1" opacity="0.5"/>`
      : `<circle class="kb-dot" cx="${x}" cy="${y}" r="${r}" style="fill:${p.kind === 'exact' ? hc.exact : hc.ra}" stroke="#FFFFFF" stroke-width="0.8"/>`
  }
  return `<svg viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" role="img" aria-label="Where this pitch landed: exact and relative-accuracy hits">` +
    `<rect x="0" y="0" width="${size}" height="${size}" style="fill:var(--kr-card);stroke:var(--kr-line)"/>` + cells + marks + `</svg>`
}

// U14: per pitch type, one hit grid, headline "H hits of N — E exact, R RA" (RA off: exact only, no RA count)
export function drawHitTypeGrids(opts: { gridSize?: number; batterSide: 'R' | 'L' | null; allTypes: string[]; raOn: boolean;
  pitches: { type: string; row: number; col: number; kind: HitKind }[] }): string {
  const hc = hitColors()
  const grids = opts.allTypes.map(type => {
    const pts = opts.pitches.filter(p => p.type === type)
    if (!pts.length) return ''
    const e = pts.filter(p => p.kind === 'exact').length, ra = pts.filter(p => p.kind === 'ra').length
    const head = opts.raOn ? `${e + ra} hit${e + ra === 1 ? '' : 's'} of ${pts.length} — ${e} exact, ${ra} RA`
      : `${e} hit${e === 1 ? '' : 's'} of ${pts.length}`
    return `<div class="type-grid">
      <h3><span class="legend-dot" style="background:${colorForType(type, opts.allTypes)}"></span>${escapeHtml(type)}</h3>
      ${drawHitGrid({ gridSize: opts.gridSize, batterSide: opts.batterSide, pts })}
      <p class="type-grid-stats">${head}</p>
    </div>`
  }).join('')
  if (!grids) return ''
  const legend = opts.raOn
    ? `<div class="legend" style="display:flex;flex-wrap:wrap;gap:6px 16px;margin:0 0 10px"><span class="legend-item"><span class="legend-dot" style="background:${hc.exact}"></span>Exact</span>` +
      `<span class="legend-item"><span class="legend-dot" style="background:${hc.ra}"></span>RA</span>` +
      `<span class="legend-item"><span class="legend-dot" style="background:none;box-shadow:inset 0 0 0 1px var(--kr-ink-faint);opacity:0.6"></span>Miss</span></div>`
    : ''
  // inline styles only: the report stylesheet stays byte-identical for every report without U14 pitches
  return `<div style="margin-top:14px">${legend}<div class="type-grids">${grids}</div></div>`
}
