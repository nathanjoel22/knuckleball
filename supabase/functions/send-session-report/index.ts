// Deploy with: supabase functions deploy send-session-report
// Requires these secrets set on your Supabase project (see SETUP.md):
//   RESEND_API_KEY, REPORT_FROM_EMAIL, SUPABASE_URL, SUPABASE_ANON_KEY

import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

const MAX_RECIPIENTS = 3
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function escapeHtml(str: string): string {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

// Must match TYPE_PALETTE in bullpen-tracker.html exactly, so a pitch
// type is always the same color in the app and in the emailed PDF.
const TYPE_PALETTE_HEX = ['#E8A83D', '#6FA287', '#C17A45', '#C0453B', '#7C9CBF', '#B98CCB', '#D4C15B', '#4FA8A8']

function hexToRgb(hex: string) {
  const h = hex.replace('#', '')
  return rgb(parseInt(h.substring(0, 2), 16) / 255, parseInt(h.substring(2, 4), 16) / 255, parseInt(h.substring(4, 6), 16) / 255)
}

const COLORS = {
  fieldDark: rgb(15 / 255, 36 / 255, 27 / 255),
  fieldPanel: rgb(24 / 255, 53 / 255, 39 / 255),
  chalk: rgb(0.97, 0.96, 0.93),
  darkText: rgb(0.09, 0.14, 0.11),
  faint: rgb(0.45, 0.5, 0.47),
  amber: hexToRgb('#E8A83D'),
  border: rgb(0.85, 0.85, 0.82),
  white: rgb(1, 1, 1)
}

function isStrikeCell(row: number, col: number) { return row >= 1 && row <= 3 && col >= 1 && col <= 3 }
function isAccurate(p: any) { return p.targetRow === p.actualRow && p.targetCol === p.actualCol }
function isRelativelyAccurate(p: any) {
  const mode = p.accuracyMode
  if (!mode) return isAccurate(p)
  switch (mode) {
    case 'ring': {
      const dRow = Math.abs(p.actualRow - p.targetRow)
      const dCol = Math.abs(p.actualCol - p.targetCol)
      return Math.max(dRow, dCol) <= 1
    }
    case 'nothingUp': return p.actualRow >= 3
    case 'nothingLow': return p.actualRow <= 1
    case 'nothingAway': return p.actualCol >= 3
    case 'nothingInside': return p.actualCol <= 1
    default: return isAccurate(p)
  }
}
function zoneNumber(row: number, col: number) {
  if (!isStrikeCell(row, col)) return null
  return (row - 1) * 3 + (col - 1) + 1
}
function colorForType(type: string, allTypes: string[]) {
  const idx = allTypes.indexOf(type)
  return hexToRgb(TYPE_PALETTE_HEX[idx >= 0 ? idx % TYPE_PALETTE_HEX.length : 0])
}

function drawZoneGrid(page: any, opts: { x: number; y: number; size: number }) {
  const { x, y, size } = opts
  const cell = size / 5
  page.drawRectangle({ x, y, width: size, height: size, borderColor: COLORS.border, borderWidth: 1, color: COLORS.white })
  for (let row = 0; row < 5; row++) {
    for (let col = 0; col < 5; col++) {
      const cx = x + col * cell
      const cy = y + (4 - row) * cell
      const inZone = isStrikeCell(row, col)
      page.drawRectangle({
        x: cx, y: cy, width: cell, height: cell,
        borderColor: COLORS.border, borderWidth: 0.5,
        color: inZone ? COLORS.fieldPanel : COLORS.white, opacity: inZone ? 0.07 : 1
      })
      const num = zoneNumber(row, col)
      if (num !== null) page.drawText(String(num), { x: cx + 3, y: cy + cell - 9, size: 6.5, color: COLORS.faint })
    }
  }
}

function cellCenter(x: number, y: number, size: number, row: number, col: number) {
  const cell = size / 5
  return { cx: x + col * cell + cell / 2, cy: y + (4 - row) * cell + cell / 2, cell }
}

function drawPitchDots(page: any, opts: { x: number; y: number; size: number; pitches: any[]; colorFn: (t: string) => any; dotRadius?: number }) {
  const { x, y, size, pitches, colorFn } = opts
  const dotRadius = opts.dotRadius ?? 3.2
  const counts: Record<string, number> = {}
  for (const p of pitches) {
    const key = p.actualRow + '-' + p.actualCol
    const idx = counts[key] || 0
    counts[key] = idx + 1
    const { cx, cy, cell } = cellCenter(x, y, size, p.actualRow, p.actualCol)
    const angle = idx * 137.508 * (Math.PI / 180)
    const radius = idx === 0 ? 0 : Math.min(cell * 0.32, 2.5 + idx * 1.8)
    const dx = radius * Math.cos(angle)
    const dy = radius * Math.sin(angle)
    page.drawCircle({ x: cx + dx, y: cy + dy, size: dotRadius, color: colorFn(p.type), borderColor: COLORS.white, borderWidth: 0.6 })
  }
}

function drawLegend(page: any, opts: { x: number; y: number; types: string[]; colorFn: (t: string) => any; font: any }) {
  let x = opts.x
  const { y, types, colorFn, font } = opts
  for (const t of types) {
    page.drawCircle({ x: x + 4, y: y + 3, size: 4, color: colorFn(t) })
    page.drawText(t, { x: x + 12, y, size: 9, font, color: COLORS.darkText })
    x += 12 + font.widthOfTextAtSize(t, 9) + 16
  }
}

async function buildReportPdf(payload: any): Promise<Uint8Array> {
  const { pitcherName, dateStr, teamName, stats, pitches, allTypes, history } = payload
  const doc = await PDFDocument.create()
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const regular = await doc.embedFont(StandardFonts.Helvetica)

  function newPage(subtitle: string) {
    const page = doc.addPage([612, 792])
    page.drawRectangle({ x: 0, y: 702, width: 612, height: 90, color: COLORS.fieldDark })
    page.drawText('KNUCKLEBALL', { x: 40, y: 760, size: 20, font: bold, color: COLORS.amber })
    page.drawText('ALWAYS A STEP AHEAD', { x: 40, y: 746, size: 7, font: regular, color: rgb(0.7, 0.75, 0.72) })
    page.drawText(subtitle, { x: 40, y: 718, size: 11, font: regular, color: COLORS.chalk })
    page.drawText(pitcherName, { x: 340, y: 756, size: 15, font: bold, color: COLORS.chalk })
    page.drawText(dateStr, { x: 340, y: 738, size: 9.5, font: regular, color: rgb(0.75, 0.8, 0.77) })
    if (teamName) page.drawText(teamName, { x: 340, y: 724, size: 9, font: regular, color: rgb(0.7, 0.75, 0.72) })
    return page
  }

  // ---------- PAGE 1: overview + all-pitches location plot ----------
  const page1 = newPage('Bullpen Session Report')
  let y = 660
  const statItems: [string, string][] = [
    ['PITCHES', String(stats.total)],
    ['STRIKE %', stats.strikePct + '%'],
    ['ACCURACY %', stats.accuracyPct + '%']
  ]
  if (stats.usesRelativeMode) statItems.push(['RELATIVE ACC %', stats.relativeAccuracyPct + '%'])
  statItems.push(['AVG MPH', stats.hasVelo ? String(stats.avgVelo) : '—'])
  const statSpacing = statItems.length > 4 ? 108 : 135
  let sx = 40
  for (const [label, val] of statItems) {
    page1.drawText(val, { x: sx, y, size: 24, font: bold, color: COLORS.fieldDark })
    page1.drawText(label, { x: sx, y: y - 16, size: 7.5, font: regular, color: COLORS.faint })
    sx += statSpacing
  }

  y -= 60
  page1.drawText('ALL PITCHES — LOCATION', { x: 40, y, size: 11, font: bold, color: COLORS.fieldDark })
  y -= 14
  const gridSize = 230
  const gridX = 40
  const gridY = y - gridSize
  drawZoneGrid(page1, { x: gridX, y: gridY, size: gridSize })
  drawPitchDots(page1, { x: gridX, y: gridY, size: gridSize, pitches, colorFn: (t) => colorForType(t, allTypes) })
  drawLegend(page1, { x: gridX + gridSize + 30, y: gridY + gridSize - 14, types: allTypes, colorFn: (t) => colorForType(t, allTypes), font: regular })
  page1.drawText('Each dot is one pitch, colored by type. Numbers mark the standard 1–9 strike zone.', {
    x: 40, y: gridY - 20, size: 8, font: regular, color: COLORS.faint
  })

  // ---------- PAGE 2+: per-pitch-type breakdown ----------
  const typesWithPitches = allTypes.filter((t: string) => pitches.some((p: any) => p.type === t))
  if (typesWithPitches.length) {
    let page = newPage('Pitch Type Breakdown')
    let rowY = 640
    let col = 0
    const colX = [40, 330]
    const miniSize = 150

    for (const type of typesWithPitches) {
      const typePitches = pitches.filter((p: any) => p.type === type)
      const strikes = typePitches.filter((p: any) => isStrikeCell(p.actualRow, p.actualCol)).length
      const accurate = typePitches.filter(isAccurate).length
      const relativeAccurate = typePitches.filter(isRelativelyAccurate).length
      const usesRelative = typePitches.some((p: any) => p.accuracyMode)
      const strikePct = Math.round((strikes / typePitches.length) * 100)
      const accuracyPct = Math.round((accurate / typePitches.length) * 100)
      const relativeAccuracyPct = Math.round((relativeAccurate / typePitches.length) * 100)

      const x = colX[col]
      const gy = rowY - miniSize
      page.drawCircle({ x: x + 5, y: rowY + 14, size: 5, color: colorForType(type, allTypes) })
      const relText = usesRelative ? `  ·  ${relativeAccuracyPct}% relative` : ''
      page.drawText(`${type}  ·  ${typePitches.length} pitches  ·  ${strikePct}% strikes  ·  ${accuracyPct}% accuracy${relText}`, {
        x: x + 16, y: rowY + 10, size: 9, font: bold, color: COLORS.fieldDark
      })
      drawZoneGrid(page, { x, y: gy, size: miniSize })
      drawPitchDots(page, { x, y: gy, size: miniSize, pitches: typePitches, colorFn: () => colorForType(type, allTypes), dotRadius: 2.6 })

      col++
      if (col > 1) { col = 0; rowY -= miniSize + 55 }
      if (rowY - miniSize < 60) {
        page = newPage('Pitch Type Breakdown (cont.)')
        rowY = 640
        col = 0
      }
    }
  }

  // ---------- PAGE 3+: trend charts across sessions ----------
  function drawTrendPage(subtitle: string, chartTitle: string, valueKey: string) {
    const page = newPage(subtitle)
    page.drawText(chartTitle, { x: 40, y: 660, size: 11, font: bold, color: COLORS.fieldDark })

    const chartX = 70, chartYBottom = 140, chartW = 480, chartH = 440
    page.drawLine({ start: { x: chartX, y: chartYBottom }, end: { x: chartX + chartW, y: chartYBottom }, thickness: 1, color: COLORS.border })
    page.drawLine({ start: { x: chartX, y: chartYBottom }, end: { x: chartX, y: chartYBottom + chartH }, thickness: 1, color: COLORS.border })

    for (let pct = 0; pct <= 100; pct += 25) {
      const gy = chartYBottom + (pct / 100) * chartH
      page.drawLine({ start: { x: chartX, y: gy }, end: { x: chartX + chartW, y: gy }, thickness: 0.5, color: COLORS.border })
      page.drawText(pct + '%', { x: chartX - 28, y: gy - 3, size: 8, font: regular, color: COLORS.faint })
    }

    const n = history.length
    const stepX = n > 1 ? chartW / (n - 1) : 0
    history.forEach((h: any, i: number) => {
      const px = chartX + i * stepX
      page.drawText(h.dateLabel, { x: px - 14, y: chartYBottom - 14, size: 7, font: regular, color: COLORS.faint })
    })

    for (const type of allTypes) {
      const pts: { x: number; y: number }[] = []
      history.forEach((h: any, i: number) => {
        const t = h.byType && h.byType[type]
        if (t && t.count > 0) {
          pts.push({ x: chartX + i * stepX, y: chartYBottom + (t[valueKey] / 100) * chartH })
        }
      })
      const color = colorForType(type, allTypes)
      for (let i = 0; i < pts.length - 1; i++) {
        page.drawLine({ start: pts[i], end: pts[i + 1], thickness: 2, color })
      }
      for (const pt of pts) page.drawCircle({ x: pt.x, y: pt.y, size: 3, color })
    }
    drawLegend(page, { x: chartX, y: chartYBottom + chartH + 20, types: allTypes, colorFn: (t) => colorForType(t, allTypes), font: regular })
  }

  if (history && history.length >= 2) {
    drawTrendPage('Accuracy Trend', 'ACCURACY % BY SESSION', 'accuracyPct')
    drawTrendPage('Relative Accuracy Trend', 'RELATIVE ACCURACY % BY SESSION', 'relativeAccuracyPct')
  }

  return doc.save()
}

function toBase64(bytes: Uint8Array): string {
  let binary = ''
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i])
  return btoa(binary)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401, headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  // Client scoped to the calling user's own session — used only to confirm
  // they are a real logged-in Knuckleball user before we send any email.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: userErr } = await callerClient.auth.getUser()
  if (userErr || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
  }

  let body: any
  try { body = await req.json() } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400, headers: corsHeaders })
  }

  const { emails, pitcherName, date, teamName, pitchTypes, pitches, stats, history } = body
  if (!emails || !emails.length || !pitcherName || !Array.isArray(pitches) || !stats) {
    return new Response(JSON.stringify({ error: 'emails, pitcherName, pitches, and stats are required' }), { status: 400, headers: corsHeaders })
  }
  if (!Array.isArray(emails) || emails.length > MAX_RECIPIENTS || !emails.every((e: any) => typeof e === 'string' && EMAIL_RE.test(e))) {
    return new Response(JSON.stringify({ error: `emails must be an array of up to ${MAX_RECIPIENTS} valid addresses` }), { status: 400, headers: corsHeaders })
  }

  const dateStr = date ? new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : ''

  // Union of every pitch type that appears anywhere, preserving the
  // pitcher's own arsenal order first, so colors stay stable over time
  // even if a type gets renamed or dropped later.
  const allTypes: string[] = Array.isArray(pitchTypes) ? [...pitchTypes] : []
  for (const p of pitches) if (!allTypes.includes(p.type)) allTypes.push(p.type)
  if (Array.isArray(history)) {
    for (const h of history) if (h.byType) for (const t of Object.keys(h.byType)) if (!allTypes.includes(t)) allTypes.push(t)
  }

  let pdfBytes: Uint8Array
  try {
    pdfBytes = await buildReportPdf({ pitcherName, dateStr, teamName, stats, pitches, allTypes, history })
  } catch (err) {
    return new Response(JSON.stringify({ error: 'PDF generation failed: ' + (err as Error).message }), { status: 500, headers: corsHeaders })
  }
  const pdfBase64 = toBase64(pdfBytes)

  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  const fromEmail = Deno.env.get('REPORT_FROM_EMAIL')
  if (!resendApiKey || !fromEmail) {
    return new Response(JSON.stringify({ error: 'Server email config missing' }), { status: 500, headers: corsHeaders })
  }

  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: fromEmail,
      to: emails,
      subject: `Bullpen Session Report — ${pitcherName}${dateStr ? ' — ' + dateStr : ''}`,
      html: `<p>Attached is the bullpen session report for ${escapeHtml(pitcherName)}${dateStr ? ' (' + escapeHtml(dateStr) + ')' : ''}.</p>`,
      attachments: [{ filename: 'session-report.pdf', content: pdfBase64 }]
    })
  })

  if (!resendRes.ok) {
    const errText = await resendRes.text()
    return new Response(JSON.stringify({ error: 'Resend send failed: ' + errText }), { status: 502, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
})
