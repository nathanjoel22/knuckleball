// ============================================================================
// Inline SVG drawing -- no charting library, no external requests. Every
// function returns a plain string of SVG markup. Grid size is a parameter.
// ============================================================================
import { isStrikeCell, zoneNumber, colorForType, escapeHtml } from './helpers.ts'

export interface Pt { row: number; col: number; type: string }

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
      cells += `<rect x="${x}" y="${y}" width="${cell}" height="${cell}" fill="${inZone ? '#E8F3EC' : '#FFFFFF'}" stroke="#CFE6D7" stroke-width="1"/>`
      if (batterSide) {
        const num = zoneNumber(row, col, batterSide, gridSize)
        if (num !== null) cells += `<text x="${x + 4}" y="${y + 11}" font-size="8" fill="#7C8C82" font-family="Georgia, serif">${num}</text>`
      }
    }
  }

  // Overlapping pitches at the same cell spiral outward (golden-angle jitter),
  // same technique the PDF used -- distinguishable dots, not a solid blob.
  const seen: Record<string, number> = {}
  let dots = ''
  for (const p of pitches) {
    const key = p.row + '-' + p.col
    const idx = seen[key] || 0
    seen[key] = idx + 1
    const cx = p.col * cell + cell / 2, cy = p.row * cell + cell / 2
    const angle = idx * 137.508 * (Math.PI / 180)
    const radius = idx === 0 ? 0 : Math.min(cell * 0.32, 2.5 + idx * 1.8)
    const dx = radius * Math.cos(angle), dy = radius * Math.sin(angle)
    const r = Math.max(2.2, Math.min(3.6, cell * 0.09))
    dots += `<circle cx="${(cx + dx).toFixed(1)}" cy="${(cy + dy).toFixed(1)}" r="${r}" fill="${colorForType(p.type, allTypes)}" stroke="#FFFFFF" stroke-width="0.8"/>`
  }

  return `<svg viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" role="img" aria-label="Pitch location grid">` +
    `<rect x="0" y="0" width="${size}" height="${size}" fill="#FFFFFF" stroke="#CFE6D7"/>` + cells + dots + `</svg>`
}

export function drawLegend(types: string[]): string {
  return `<div class="legend">${types.map(t =>
    `<span class="legend-item"><span class="legend-dot" style="background:${colorForType(t, types)}"></span>${escapeHtml(t)}</span>`
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
    grid += `<line x1="${padL}" y1="${y}" x2="${padL + plotW}" y2="${y}" stroke="#E5E5E0" stroke-width="1"/>`
    grid += `<text x="${padL - 6}" y="${y + 3}" font-size="8" fill="#7C8C82" text-anchor="end" font-family="Georgia, serif">${escapeHtml(opts.yAxisLabels[i])}</text>`
  }
  let xTicks = ''
  opts.xLabels.forEach((label, i) => {
    const x = padL + i * stepX
    xTicks += `<text x="${x}" y="${h - 4}" font-size="8" fill="#7C8C82" text-anchor="middle" font-family="Georgia, serif">${escapeHtml(label)}</text>`
  })

  let lines = ''
  for (const s of opts.series) {
    const pts: { x: number; y: number }[] = []
    s.points.forEach((v, i) => {
      if (v === null) return
      pts.push({ x: padL + i * stepX, y: padT + plotH - v * plotH })
    })
    for (let i = 0; i < pts.length - 1; i++) {
      lines += `<line x1="${pts[i].x.toFixed(1)}" y1="${pts[i].y.toFixed(1)}" x2="${pts[i + 1].x.toFixed(1)}" y2="${pts[i + 1].y.toFixed(1)}" stroke="${s.color}" stroke-width="2" fill="none"/>`
    }
    for (const pt of pts) lines += `<circle cx="${pt.x.toFixed(1)}" cy="${pt.y.toFixed(1)}" r="2.6" fill="${s.color}"/>`
  }

  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="Trend chart">` +
    `<line x1="${padL}" y1="${padT}" x2="${padL}" y2="${padT + plotH}" stroke="#CFE6D7"/>` +
    `<line x1="${padL}" y1="${padT + plotH}" x2="${padL + plotW}" y2="${padT + plotH}" stroke="#CFE6D7"/>` +
    grid + xTicks + lines + `</svg>`
}
