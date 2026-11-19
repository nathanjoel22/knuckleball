// SR1 Stage D acceptance 16 and 17 (report side): Pitch Smart rest at the band edges and the 7-day warning one pitch
// either side of each level's line, through the report function's own code.
// usage: deno run scripts/sr1d-check.ts      (exit 1 on any difference)
import { restDays, backDate, sevenDayCard, restCard, PITCH_SMART, SEVEN_DAY_GUIDE } from '../supabase/functions/send-session-report/sr1.ts'
let fails = 0
const eq = (what: string, got: unknown, want: unknown) => { const ok = JSON.stringify(got) === JSON.stringify(want); if (!ok) fails++; console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}: ${JSON.stringify(got)}${ok ? '' : ' (want ' + JSON.stringify(want) + ')'}`) }
// 16. three games, one per age band, at the edges (Pitch Smart's table, mlb.com, Nov 19 2026)
eq('13-14, 50 pitches', restDays('13-14', 50), 2)
eq('13-14, 51 pitches', restDays('13-14', 51), 3)
eq('15-16, 75 pitches', restDays('15-16', 75), 3)
eq('15-16, 76 pitches', restDays('15-16', 76), 4)
eq('19-22, 105 pitches', restDays('19-22', 105), 4)
eq('19-22, 106 pitches (above the table: its top band)', restDays('19-22', 106), 4)
eq('7-8, 20 / 21 pitches', [restDays('7-8', 20), restDays('7-8', 21)], [0, 1])
eq('17-18, 80 / 81 pitches', [restDays('17-18', 80), restDays('17-18', 81)], [3, 4])
// back on the game's Eastern date + days + 1: Sun Nov 15 2026, 7 pm Eastern (00:00 UTC Nov 16)
const sunEvening = Date.UTC(2026, 10, 16, 0, 0)
eq('4 days after Sun, Nov 15', backDate(sunEvening, 4), 'Fri, Nov 20')
eq('0 days after Sun, Nov 15', backDate(sunEvening, 0), 'Mon, Nov 16')
const over = restCard({ level: 'high_school', age_group: '15-16', sport: 'baseball', seven_day: 0, parts: [] }, 96, sunEvening, false)
eq('over the daily max says so, never "can\'t"', [/Above Pitch Smart's daily max for ages 15–16 \(95\)/.test(over), /can't|cannot|not allowed/i.test(over)], [true, false])
eq('softball: no rest card, no 7-day card', [restCard({ level: 'high_school_up', age_group: null, sport: 'softball', seven_day: 300, parts: [] }, 90, sunEvening, false),
  sevenDayCard({ level: 'high_school_up', age_group: null, sport: 'softball', seven_day: 300, parts: [] })], ['', ''])
// 17. the warning shows just over each level's line, not at or under it
for (const [level, g] of Object.entries(SEVEN_DAY_GUIDE)) {
  const card = (n: number) => sevenDayCard({ level, age_group: null, sport: 'baseball', seven_day: n, parts: [{ kind: 'bullpen', started_at: '2026-11-18T15:00:00Z', pitches: n, this: true }] })
  eq(`${level}: ${g - 1} / ${g} / ${g + 1}`, [card(g - 1).includes(' over"'), card(g).includes(' over"'), card(g + 1).includes(' over"')], [false, false, true])
  eq(`${level}: wording never says can't`, /can't|cannot|not allowed|must not/i.test(card(g + 1)), false)
}
console.log(`${fails} fail${fails === 1 ? '' : 's'} · ${Object.keys(PITCH_SMART).length} age groups`)
Deno.exit(fails ? 1 : 0)
