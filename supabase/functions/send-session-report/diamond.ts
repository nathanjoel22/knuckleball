// ============================================================================
// G5 (Joel, Oct 6 2026): the game report's field sections -- spray charts on
// the 25-box diamond, what led to each ball in play, the pitch type x result
// matrix and base states (the deciding pitches moved to connect.ts, "The pitches that mattered").
// Spec: plans/g5-live-game-diamond.md, "The field" and "Reports" 1-3.
//
// The field geometry is the tracker's g5FieldSvg() (bullpen-tracker.html),
// restated here because it runs in another runtime: the same 5x5 grid in its
// own coordinates (100 units a box), upright (Joel, Oct 7): home plate mid
// box 15, foul lines through 17/3 and 23/11, the fence arc from box 4's
// top-left corner to box 10's top-right corner; 2B at the bottom of box 25. Change both or neither.
// ============================================================================
import { escapeHtml, colorForType } from './helpers.ts'
import { drawGrid } from './svg.ts'
import type { GamePitch } from './compute_game.ts'

// Joel's box numbers by unrotated row/column (row 0 top, column 0 left).
export const G5_BOX = [[5, 6, 7, 8, 9], [4, 19, 20, 21, 10], [3, 18, 25, 22, 11], [2, 17, 24, 23, 12], [1, 16, 15, 14, 13]]
// Games charted before G5 have no box: they're placed by the fielder who made
// the play ("for now", Joel Oct 6; re-placed on the upright field Oct 7 --
// to confirm): C in home's box, P on the mound, each base's fielder at it,
// 2B and SS beside 2B, outfielders in the row inside the fence.
export const FIELDER_BOX: Record<string, number> = { C: 15, P: 24, '1B': 23, '2B': 22, SS: 18, '3B': 17, LF: 19, CF: 20, RF: 21 }
export const BB_LABEL: Record<string, string> = { ground: 'GB', line: 'LD', pop: 'Pop', fly: 'Fly', bunt: 'Bunt' }
const BB_ORDER = ['ground', 'line', 'pop', 'fly', 'bunt']
const OUTCOME_LABEL: Record<string, string> = { hit: 'Hits', out: 'Outs', error: 'Errors' }

export function sprayBoxOf(p: GamePitch): number | null {
  if (p.result !== 'in_play') return null
  if (typeof p.sprayBox === 'number' && p.sprayBox >= 1 && p.sprayBox <= 25) return p.sprayBox
  return p.fielder ? (FIELDER_BOX[p.fielder] ?? null) : null
}

const FIELD_COLORS = {
  baseball: { fence: '#B9D1C4', grass: '#C7DCBD', infield: '#B4C8AC', dirt: '#C9A97C', mound: '#B8956A', line: '#0F241B', shade: '15,36,27' },
  softball: { fence: '#BFDCEF', grass: '#CFE4F5', infield: '#BCD7EC', dirt: '#C9A97C', mound: '#B8956A', line: '#234B6E', shade: '35,75,110' }
}

// One diamond: counts per box, shaded by share of the busiest box.
export function drawDiamond(opts: { counts: Record<number, number>; sport: 'baseball' | 'softball'; size?: number; color?: string }): string {
  const size = opts.size ?? 220
  const c = FIELD_COLORS[opts.sport] ?? FIELD_COLORS.baseball
  const soft = opts.sport === 'softball'
  const max = Math.max(1, ...Object.values(opts.counts))
  const shadeRgb = opts.color ? hexToRgb(opts.color) : c.shade
  let cells = ''
  for (let r = 0; r < 5; r++) {
    for (let col = 0; col < 5; col++) {
      const box = G5_BOX[r][col]
      const n = opts.counts[box] || 0
      const x = col * 100, y = r * 100
      cells += `<rect x="${x + 3}" y="${y + 3}" width="94" height="94" rx="6" fill="${n ? `rgba(${shadeRgb},${(0.18 + 0.6 * n / max).toFixed(2)})` : 'none'}" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2"/>`
      if (n) cells += `<text x="${x + 50}" y="${y + 50}" text-anchor="middle" dominant-baseline="central" font-size="34" font-weight="800" fill="#FFFFFF" stroke="rgba(0,0,0,0.35)" stroke-width="1.5" paint-order="stroke">${n}</text>`
    }
  }
  const base = (x: number, y: number) => `<rect x="${x - 11}" y="${y - 11}" width="22" height="22" rx="2" transform="rotate(45 ${x} ${y})"/>`
  // Joel, Oct 8 (baseball): foul territory #228B22, fair outfield a criss-cross of #228B22 and #3F704D (the app's g5FieldSvg)
  const mow = soft ? '' : `<defs><pattern id="kbmow" width="50" height="50" patternUnits="userSpaceOnUse" patternTransform="rotate(45 250 450)"><rect width="50" height="50" fill="#228B22"/><rect width="25" height="25" fill="#3F704D"/><rect x="25" y="25" width="25" height="25" fill="#3F704D"/></pattern></defs>`
  const field = `${mow}<rect width="500" height="500" fill="${soft ? c.fence : '#228B22'}"/>
<path d="M0,0 L500,0 L500,100 A650,650 0 0 0 0,100 Z" fill="${c.fence}"/>
<path d="M250,450 L0,200 L0,100 A650,650 0 0 1 500,100 L500,200 Z" fill="${soft ? c.grass : 'url(#kbmow)'}"/>
<path d="M0,100 A650,650 0 0 1 500,100" fill="none" stroke="${c.line}" stroke-width="6" opacity="0.75"/>
<path d="M250,450 L100,300 A250,250 0 0 1 400,300 Z" fill="${c.dirt}"/>
<polygon points="250,428 314,364 250,300 186,364" fill="${soft ? c.dirt : c.infield}"/>
${soft ? '<circle cx="250" cy="350" r="16" fill="none" stroke="#FFFFFF" stroke-width="2.5"/>' : `<circle cx="250" cy="350" r="14" fill="${c.mound}"/>`}
<path d="M250,450 L0,200 M250,450 L500,200" stroke="#FFFFFF" stroke-width="4"/>
<g fill="#FFFFFF" stroke="${c.line}" stroke-width="1.5">${base(350, 350)}${base(250, 282)}${base(150, 350)}</g>
<polygon points="237,438 263,438 263,451 250,464 237,451" fill="#FFFFFF" stroke="${c.line}" stroke-width="1.5"/>`
  return `<svg class="kb-diamond" width="${size}" height="${size}" viewBox="0 0 500 500" role="img" aria-label="Field boxes">${field}${cells}</svg>`
}
function hexToRgb(hex: string): string {
  const h = hex.replace('#', '')
  const v = parseInt(h.length === 3 ? h.split('').map(x => x + x).join('') : h, 16)
  return `${(v >> 16) & 255},${(v >> 8) & 255},${v & 255}`
}

function countBoxes(ps: GamePitch[]): Record<number, number> {
  const out: Record<number, number> = {}
  for (const p of ps) { const b = sprayBoxOf(p); if (b) out[b] = (out[b] || 0) + 1 }
  return out
}
function mixText(ps: GamePitch[]): string {
  const by: Record<string, number> = {}
  for (const p of ps) by[p.type] = (by[p.type] || 0) + 1
  return Object.entries(by).sort((a, b) => b[1] - a[1]).map(([t, n]) => `${escapeHtml(t.toUpperCase())} ${n}`).join(', ')
}
function figure(title: string, svg: string, n: number): string {
  return `<figure class="kb-fig"><figcaption>${escapeHtml(title)} <span class="kb-n">(${n})</span></figcaption>${svg}</figure>`
}

// ---------- Reports 1: spray charts ----------
export function renderSprayCharts(pitches: GamePitch[], allTypes: string[], sport: 'baseball' | 'softball'): string {
  const bip = pitches.filter(p => sprayBoxOf(p) !== null)
  if (!bip.length) return ''
  const d = (ps: GamePitch[], color?: string) => drawDiamond({ counts: countBoxes(ps), sport, color })
  const byResult = ['hit', 'out', 'error'].map(o => [o, bip.filter(p => p.inPlayOutcome === o)] as const).filter(([, ps]) => ps.length)
  const byBB = BB_ORDER.map(t => [t, bip.filter(p => p.bbType === t)] as const).filter(([, ps]) => ps.length)
  const byType = allTypes.map(t => [t, bip.filter(p => p.type === t)] as const).filter(([, ps]) => ps.length)
  const oldGame = bip.some(p => typeof p.sprayBox !== 'number')
  return `
  <section class="section">
    <h2>Balls in play — the field</h2>
    <div class="grid-row">${figure('All balls in play', d(bip), bip.length)}</div>
    ${byResult.length ? `<h3>By result</h3><div class="grid-row">${byResult.map(([o, ps]) => figure(OUTCOME_LABEL[o], d(ps), ps.length)).join('')}</div>` : ''}
    ${byBB.length ? `<h3>By how it was hit</h3><div class="grid-row">${byBB.map(([t, ps]) => figure(BB_LABEL[t], d(ps), ps.length)).join('')}</div>` : ''}
    <h3>By pitch type</h3><div class="grid-row">${byType.map(([t, ps]) => figure(t.toUpperCase(), d(ps, colorForType(t, allTypes)), ps.length)).join('')}</div>
    <p class="caption">Where each ball in play was fielded, on the field's 25 boxes (foul ground included). The number is how many; darker means more.${oldGame ? ' Games charted before the field chart are placed by the fielder who made the play.' : ''}</p>
  </section>`
}

// ---------- Reports 2: what led to it ----------
function smallGrid(ps: GamePitch[], allTypes: string[], gridSize: number): string {
  return drawGrid({ size: 96, gridSize, batterSide: null, pitches: ps.map(p => ({ row: p.actualRow, col: p.actualCol, type: p.type })), allTypes })
}
const MATRIX_COLS: [string, (p: GamePitch) => boolean][] = [
  ['Ball', p => p.result === 'ball'],
  ['Called strike', p => p.result === 'strike_looking'],
  ['Swinging strike', p => p.result === 'strike_swinging'],
  ['Foul', p => p.result === 'foul'],
  ['In play: hit', p => p.result === 'in_play' && p.inPlayOutcome === 'hit'],
  ['In play: out', p => p.result === 'in_play' && p.inPlayOutcome === 'out'],
  ['In play: error', p => p.result === 'in_play' && p.inPlayOutcome === 'error']
]
function isKDecider(p: GamePitch): boolean {
  return p.result === 'dropped_third' || ((p.result === 'strike_looking' || p.result === 'strike_swinging' || p.result === 'foul_tip') && p.strikesBefore >= 2)
}
function isBBDecider(p: GamePitch): boolean { return p.result === 'ball' && p.ballsBefore >= 3 }

export function renderWhatLedToIt(pitches: GamePitch[], allTypes: string[], gridSize: number): string {
  if (!pitches.length) return ''
  const bip = pitches.filter(p => sprayBoxOf(p) !== null)
  const boxRows = Array.from(new Set(bip.map(p => sprayBoxOf(p) as number))).sort((a, b) => a - b).map(box => {
    const ps = bip.filter(p => sprayBoxOf(p) === box)
    return `<tr><td>Box ${box}</td><td>${ps.length}</td><td>${mixText(ps)}</td><td>${smallGrid(ps, allTypes, gridSize)}</td></tr>`
  }).join('')
  const bbRows = BB_ORDER.map(t => [t, bip.filter(p => p.bbType === t)] as const).filter(([, ps]) => ps.length).map(([t, ps]) =>
    `<tr><td>${BB_LABEL[t]}</td><td>${ps.length}</td><td>${mixText(ps)}</td><td>${smallGrid(ps, allTypes, gridSize)}</td></tr>`).join('')
  const types = allTypes.filter(t => pitches.some(p => p.type === t))
  const matrix = types.map(t => {
    const tp = pitches.filter(p => p.type === t)
    return `<tr><td><strong>${escapeHtml(t.toUpperCase())}</strong></td><td>${tp.length}</td>${MATRIX_COLS.map(([, f]) => `<td>${tp.filter(f).length}</td>`).join('')}</tr>`
  }).join('')
  const tableHead = '<thead><tr><th></th><th>Balls in play</th><th>Pitch types</th><th>Pitch locations</th></tr></thead>'
  return `
  <section class="section">
    <h2>What led to it</h2>
    ${boxRows ? `<h3>By field box</h3><div class="table-scroll"><table class="data-table">${tableHead}<tbody>${boxRows}</tbody></table></div>` : ''}
    ${bbRows ? `<h3>By how it was hit</h3><div class="table-scroll"><table class="data-table">${tableHead}<tbody>${bbRows}</tbody></table></div>` : ''}
    <h3>Pitch type × result</h3>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>Type</th><th>Pitches</th>${MATRIX_COLS.map(([h]) => `<th>${h}</th>`).join('')}</tr></thead>
      <tbody>${matrix}</tbody>
    </table></div>

  </section>`
}

// ---------- Reports 3: base states ----------
const BASE_STATES: [number, string][] = [[0, 'Empty'], [1, '1st'], [2, '2nd'], [4, '3rd'], [3, '1st + 2nd'], [5, '1st + 3rd'], [6, '2nd + 3rd'], [7, 'Loaded']]
function stateCells(ps: GamePitch[], withMix: boolean): string {
  const strikes = ps.filter(p => ['strike_looking', 'strike_swinging', 'foul', 'foul_tip', 'in_play', 'sac_bunt', 'sac_fly', 'dropped_third'].includes(p.result)).length
  const bip = ps.filter(p => p.result === 'in_play')
  return `<td>${ps.length}</td><td>${ps.length ? Math.round(100 * strikes / ps.length) + '%' : '—'}</td>${withMix ? `<td>${mixText(ps)}</td>` : ''}` +
    `<td>${bip.length}</td><td>${bip.filter(p => p.inPlayOutcome === 'hit').length}</td><td>${bip.filter(p => p.inPlayOutcome === 'out').length}</td>` +
    `<td>${ps.filter(isKDecider).length}</td><td>${ps.filter(isBBDecider).length}</td>`
}
export function renderBaseStates(pitches: GamePitch[], allTypes: string[]): string {
  const known = pitches.filter(p => typeof p.runnersBefore === 'number')
  if (!known.length) return ''
  const states = BASE_STATES.map(([mask, label]) => [label, known.filter(p => p.runnersBefore === mask)] as const).filter(([, ps]) => ps.length)
  const rows = states.map(([label, ps]) => `<tr><td><strong>${label}</strong></td>${stateCells(ps, true)}</tr>`).join('')
  const split = states.map(([label, ps]) => allTypes.filter(t => ps.some(p => p.type === t)).map((t, i) =>
    `<tr><td>${i === 0 ? `<strong>${label}</strong>` : ''}</td><td>${escapeHtml(t.toUpperCase())}</td>${stateCells(ps.filter(p => p.type === t), false)}</tr>`).join('')).join('')
  const head = '<th>Pitches</th><th>Strike %</th>'
  const tail = '<th>Balls in play</th><th>Hits</th><th>Outs</th><th>K</th><th>BB</th>'
  return `
  <section class="section">
    <h2>Base states</h2>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>Runners on</th>${head}<th>Pitch mix</th>${tail}</tr></thead><tbody>${rows}</tbody>
    </table></div>
    <h3>By pitch type</h3>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>Runners on</th><th>Type</th>${head}${tail}</tr></thead><tbody>${split}</tbody>
    </table></div>
    <p class="caption">Every pitch counted by the bases as they were when it was thrown. K and BB count the pitch that ended the plate appearance; outs are outs on balls in play.</p>
  </section>`
}

export const DIAMOND_CSS = `
  .kb-fig{ margin:0; display:flex; flex-direction:column; align-items:center; gap:4px; }
  .kb-fig figcaption{ font-size:12px; font-weight:700; color:#2E4A40; }
  .kb-n{ font-weight:400; color:#527065; }
  .kb-mix{ font-size:11px; color:#527065; max-width:120px; text-align:center; }
`
