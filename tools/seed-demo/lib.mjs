// DS1 shared helpers: the config, the two projects, and signing in as each demo account with the public anon key.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

export const HERE = path.dirname(fileURLToPath(import.meta.url));
export const REPO = path.resolve(HERE, '..', '..');
export const OUT = path.join(HERE, 'out');

export const PROJECTS = {
  staging: { ref: 'wpsscxwawgiwmifpjpec', file: 'supabase-config.staging.js' },
  prod: { ref: 'fkgccjhuimkkbupbanxp', file: null }   // the committed supabase-config.js (the working copy may hold the staging swap)
};
// Present only on staging: the SQL files refuse to run on the wrong project with it (as f1a_loadtest_cleanup.sql does).
export const STAGING_MARKER_TEAM = '18fa6885-c85e-4c2a-88e9-e301c6f93723';

export function loadConfig(){
  const f = path.join(HERE, 'config.local.json');
  if(!fs.existsSync(f)) throw new Error('config.local.json is missing: copy config.example.json and fill it in (README.md, step 2)');
  const cfg = JSON.parse(fs.readFileSync(f, 'utf8'));
  if(!cfg.endDate) throw new Error('config.local.json needs an endDate (keep it the same for staging and production)');
  if(cfg.pitchers.length !== 10) throw new Error('DS1 expects ten pitchers (four improve, four hold, two slip)');
  return cfg;
}

export function args(){
  const a = process.argv.slice(2), out = { flags: new Set() };
  for(let i = 0; i < a.length; i++){
    if(a[i] === '--env') out.env = a[++i];
    else if(a[i].startsWith('--env=')) out.env = a[i].slice(6);
    else out.flags.add(a[i].replace(/^--/, ''));
  }
  return out;
}

export function projectFor(env){
  const p = PROJECTS[env];
  if(!p) throw new Error('--env must be staging or prod');
  const src = p.file ? fs.readFileSync(path.join(REPO, p.file), 'utf8')
    : execFileSync('git', ['-C', REPO, 'show', 'HEAD:supabase-config.js'], { encoding: 'utf8' });
  const url = (src.match(/const SUPABASE_URL = "([^"]+)"/) || [])[1];
  const key = (src.match(/const SUPABASE_ANON_KEY = "([^"]+)"/) || [])[1];
  if(!url || !key) throw new Error('could not read the URL and anon key for ' + env);
  if(!url.includes(p.ref)) throw new Error(`refused: the ${env} config points at ${url}, not project ${p.ref}`);
  return { env, ref: p.ref, url, key };
}

export function termsVersion(){
  const m = fs.readFileSync(path.join(REPO, 'bullpen-tracker.html'), 'utf8').match(/TERMS_VERSION\s*=\s*['"]([^'"]+)['"]/);
  if(!m) throw new Error('TERMS_VERSION not found in bullpen-tracker.html');
  return m[1];
}

// the calendar day of a timestamp in the facility's timezone (YYYY-MM-DD)
export const zonedDay = (iso, tz) => new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(iso));

export const sleep = ms => new Promise(r => setTimeout(r, ms));

// Retries Auth's per-IP limit (30 sign-ins / sign-ups per 5 minutes) instead of failing half way.
async function authCall(fn){
  for(let i = 0; ; i++){
    const res = await fn();
    const msg = res.error && (res.error.message || '');
    if(res.error && (res.error.status === 429 || /rate limit|too many/i.test(msg)) && i < 6){
      console.log('  (Auth rate limit: waiting 60 s)'); await sleep(60000); continue;
    }
    return res;
  }
}

// Signs in; makes the account with the sign-up page's own call if it doesn't exist yet. Returns { db, uid, created }.
export async function account(project, email, password, metadata, { allowCreate = true } = {}){
  const db = createClient(project.url, project.key, { auth: { persistSession: false, autoRefreshToken: true, detectSessionInUrl: false } });
  let r = await authCall(() => db.auth.signInWithPassword({ email, password }));
  if(!r.error) return { db, uid: r.data.user.id, created: false };
  if(!allowCreate || !/invalid login credentials/i.test(r.error.message || '')) throw new Error(`sign-in failed for ${email}: ${r.error.message}`);
  r = await authCall(() => db.auth.signUp({ email, password, options: { data: metadata } }));
  if(r.error) throw new Error(`sign-up failed for ${email}: ${r.error.message}`);
  if(!r.data.session) throw new Error(`sign-up for ${email} returned no session: "Confirm email" must be on in this project's Auth settings. Stop: it would email every account.`);
  return { db, uid: r.data.user.id, created: true };
}

// rpc() that throws on a transport error and returns the data
export async function call(db, fn, params){
  const { data, error } = await db.rpc(fn, params || {});
  if(error) throw new Error(`${fn}: ${error.message}`);
  return data;
}

export function writeOut(name, text){
  fs.mkdirSync(OUT, { recursive: true });
  const f = path.join(OUT, name);
  fs.writeFileSync(f, text);
  return f;
}

export const allPeople = cfg => [cfg.manager, ...cfg.coaches, ...cfg.pitchers];
export const sqlList = emails => emails.map(e => `'${e.toLowerCase().replace(/'/g, "''")}'`).join(',\n    ');
