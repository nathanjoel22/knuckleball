// ============================================================================
// Joel, Oct 7 2026: the game report's "pitches that mattered" (strike three,
// first-pitch strikes, hits, outs in play -- plus walks and errors) and the
// bullpen-to-game connection: for each pitch type at each location thrown in
// this game, how the same pitch at the same location went in the pitcher's
// recent bullpens (last 5 before the game, same team) next to what happened to
// it in the game. Descriptive only -- it lines the two days up; it doesn't
// claim one caused the other.
// ============================================================================
import { escapeHtml, colorForType, isStrikeCell, viewCol } from './helpers.ts'
import { drawGrid } from './svg.ts'
import type { GamePitch } from './compute_game.ts'

// A bullpen pitch as the app sends it (catcher-frame location, like every stored pitch).
export interface PenPitch {
  type: string
  actualRow: number; actualCol: number
  targetRow: number | null; targetCol: number | null
  inAccuracyZone: boolean | null
}

const STRIKE_RESULTS = new Set(['strike_looking', 'strike_swinging', 'foul', 'foul_tip', 'in_play', 'sac_bunt', 'sac_fly', 'dropped_third'])
const isStrikeResult = (p: GamePitch) => STRIKE_RESULTS.has(p.result)
const isK = (p: GamePitch) => p.result === 'dropped_third' || ((p.result === 'strike_looking' || p.result === 'strike_swinging' || p.result === 'foul_tip') && p.strikesBefore >= 2)
const isBB = (p: GamePitch) => p.result === 'ball' && p.ballsBefore >= 3
const inPlay = (p: GamePitch, o: string) => p.result === 'in_play' && p.inPlayOutcome === o

function mixText(ps: { type: string }[]): string {
  const by: Record<string, number> = {}
  for (const p of ps) by[p.type] = (by[p.type] || 0) + 1
  return Object.entries(by).sort((a, b) => b[1] - a[1]).map(([t, n]) => `${escapeHtml(t.toUpperCase())} ${n}`).join(', ')
}
function grid(ps: GamePitch[], allTypes: string[], gridSize: number): string {
  return drawGrid({ size: 110, gridSize, batterSide: null, pitches: ps.map(p => ({ row: p.actualRow, col: p.actualCol, type: p.type })), allTypes })
}

// ---------- The pitches that mattered ----------
export function renderPitchesThatMattered(pitches: GamePitch[], allTypes: string[], gridSize: number): string {
  const groups: [string, GamePitch[]][] = [
    ['Strike three', pitches.filter(isK)],
    ['First-pitch strikes', pitches.filter(p => p.ballsBefore === 0 && p.strikesBefore === 0 && isStrikeResult(p))],
    ['Hits', pitches.filter(p => inPlay(p, 'hit'))],
    ['Outs in play', pitches.filter(p => inPlay(p, 'out'))],
    ['Walks', pitches.filter(isBB)],
    ['Errors', pitches.filter(p => inPlay(p, 'error'))]
  ]
  const shown = groups.filter(([, ps]) => ps.length)
  if (!shown.length) return ''
  const firstPitches = pitches.filter(p => p.ballsBefore === 0 && p.strikesBefore === 0)
  const fps = firstPitches.filter(isStrikeResult).length
  return `
  <section class="section">
    <h2>The pitches that mattered</h2>
    <div class="grid-row">${shown.map(([label, ps]) => `<figure class="kb-fig"><figcaption>${escapeHtml(label)} <span class="kb-n">(${ps.length})</span></figcaption>${grid(ps, allTypes, gridSize)}<div class="kb-mix">${mixText(ps)}</div></figure>`).join('')}</div>
    <p class="caption">The pitch type and location of the last pitch of each strikeout, ball in play and walk, and of every first pitch that went for a strike${firstPitches.length ? ` (${fps} of ${firstPitches.length} first pitches)` : ''}. Location grids mix both batter sides.</p>
  </section>`
}

// ---------- Bullpen to game ----------
const ROW_NAME = ['Above the zone', 'Up', 'Middle', 'Down', 'Below the zone']
const COL_NAME = ['Off the left edge', 'Left', 'Center', 'Right', 'Off the right edge']   // as drawn (the report's view)
function locationName(row: number, col: number, gridSize: number): string {
  if (gridSize !== 5) return `Row ${row + 1}, column ${viewCol(col, gridSize) + 1}`
  return `${ROW_NAME[row]} · ${COL_NAME[viewCol(col, gridSize)]}`
}
const penCommand = (p: PenPitch) => (p.inAccuracyZone === true || p.inAccuracyZone === false)
  ? p.inAccuracyZone
  : (p.targetRow !== null && p.targetCol !== null ? (p.targetRow === p.actualRow && p.targetCol === p.actualCol) : null)
const pct = (n: number, d: number) => d ? Math.round(100 * n / d) + '%' : '—'

export function renderBullpenToGame(pitches: GamePitch[], pen: PenPitch[] | undefined, allTypes: string[], gridSize: number): string {
  if (!pen || !pen.length || !pitches.length) return ''
  const key = (t: string, r: number, c: number) => `${t}|${r}|${c}`
  const game: Record<string, GamePitch[]> = {}
  for (const p of pitches) (game[key(p.type, p.actualRow, p.actualCol)] ||= []).push(p)
  const pens: Record<string, PenPitch[]> = {}
  for (const p of pen) (pens[key(p.type, p.actualRow, p.actualCol)] ||= []).push(p)
  const order = (t: string) => { const i = allTypes.indexOf(t); return i < 0 ? 99 : i }
  const rows = Object.entries(game)
    .map(([k, gp]) => { const [t, r, c] = k.split('|'); return { type: t, row: +r, col: +c, gp, pp: pens[k] || [] } })
    .sort((a, b) => order(a.type) - order(b.type) || b.gp.length - a.gp.length || b.pp.length - a.pp.length)
  const body = rows.map(x => {
    const cmd = x.pp.map(penCommand).filter(v => v !== null) as boolean[]
    return `<tr>
      <td style="white-space:nowrap"><span class="dot" style="background:${colorForType(x.type, allTypes)}"></span>${escapeHtml(x.type.toUpperCase())}</td>
      <td>${escapeHtml(locationName(x.row, x.col, gridSize))}</td>
      <td>${x.pp.length || '—'}</td><td>${x.pp.length ? pct(x.pp.filter(p => isStrikeCell(p.actualRow, p.actualCol, gridSize)).length, x.pp.length) : '—'}</td>
      <td>${cmd.length ? pct(cmd.filter(Boolean).length, cmd.length) : '—'}</td>
      <td>${x.gp.length}</td><td>${x.gp.filter(isStrikeResult).length}</td><td>${x.gp.filter(p => p.result === 'strike_swinging').length}</td>
      <td>${x.gp.filter(p => inPlay(p, 'hit')).length}</td><td>${x.gp.filter(p => inPlay(p, 'out')).length}</td>
    </tr>`
  }).join('')
  const types = allTypes.filter(t => pitches.some(p => p.type === t) || pen.some(p => p.type === t))
  const penGrids = types.filter(t => pen.some(p => p.type === t)).map(t => {
    const pp = pen.filter(p => p.type === t), gp = pitches.filter(p => p.type === t)
    return `<figure class="kb-fig"><figcaption>${escapeHtml(t.toUpperCase())}</figcaption>
      <div class="kb-pair"><div><div class="kb-mix">Bullpens (${pp.length})</div>${drawGrid({ size: 110, gridSize, batterSide: null, pitches: pp.map(p => ({ row: p.actualRow, col: p.actualCol, type: p.type })), allTypes })}</div>
      <div><div class="kb-mix">This game (${gp.length})</div>${grid(gp, allTypes, gridSize)}</div></div></figure>`
  }).join('')
  return `
  <section class="section">
    <h2>Bullpen to game</h2>
    <div class="grid-row">${penGrids}</div>
    <h3>Same pitch, same spot</h3>
    <div class="table-scroll"><table class="data-table wide">
      <thead><tr><th>Type</th><th>Location</th><th>Pen thrown</th><th>Pen strike % (location)</th><th>Pen command %</th>
        <th>Game thrown</th><th>Strikes</th><th>Whiffs</th><th>Hits</th><th>Outs in play</th></tr></thead>
      <tbody>${body}</tbody>
    </table></div>
    <p class="caption">Every pitch type and location thrown in this game, next to the same pitch at the same location in this pitcher's last ${'5'} bullpens before the game (same team). Bullpen strike % is where the pitch landed; game strikes count results (called, swinging, foul, in play). Locations are as drawn in this report. Descriptive only: it lines the two days up, it doesn't say one caused the other.</p>
  </section>`
}

export const CONNECT_CSS = `
  .kb-pair{ display:flex; gap:10px; }
  .kb-pair .kb-mix{ max-width:none; margin-bottom:2px; }
`
