// Branded emails (Joel, Oct 22 2026): Supabase Auth's own emails (password reset, invite, sign-up confirmation) in the
// same layout as Knuckleball's (supabase/functions/_shared/email.ts). Run: deno run --allow-read --allow-write
// supabase/templates/build.ts -- writes the three templates next to this file; paste or PATCH them into each project's
// Auth email templates. Each picks the sport the person chose at signup (user metadata intended_sport; none ->
// baseball). The Go template guards a missing value before comparing it.
import { brandedEmail } from '../functions/_shared/email.ts'
const URL = '{{ .ConfirmationURL }}'
const T: Record<string, { title: string; paragraphs: string[]; label: string; footnote: string }> = {
  recovery: { title: 'Reset your password', paragraphs: ['Someone asked to reset the password on your Knuckleball account. If that was you, choose a new one here:'],
    label: 'Choose a new password', footnote: "The link works once and expires in about an hour. If you didn't ask for this, ignore this email and your password stays the same." },
  invite: { title: "You're invited", paragraphs: ['Your coach invited you to chart your pitching on Knuckleball. Set up your account to join the team:'],
    label: 'Accept the invite', footnote: "If you weren't expecting this, you can ignore this email." },
  confirmation: { title: 'Confirm your email', paragraphs: ['Thanks for signing up for Knuckleball. Confirm your email to finish setting up your account:'],
    label: 'Confirm my email', footnote: "If you didn't create a Knuckleball account, you can ignore this email." },
}
for (const [name, t] of Object.entries(T)) {
  const one = (sport: string) => brandedEmail({ sport, title: t.title, paragraphs: t.paragraphs, button: { href: URL, label: t.label }, footnote: t.footnote })
  const tpl = `{{ if .Data.intended_sport }}{{ if eq .Data.intended_sport "softball" }}${one('softball')}{{ else }}${one('baseball')}{{ end }}{{ else }}${one('baseball')}{{ end }}`
  Deno.writeTextFileSync(new globalThis.URL(`./auth-${name}.html`, import.meta.url), tpl + '\n')
  console.log('wrote', `auth-${name}.html`, tpl.length, 'chars')
}
