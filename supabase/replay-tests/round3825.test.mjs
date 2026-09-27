import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { PGlite } from '@electric-sql/pglite';

// This is a focused, disposable predecessor fixture, not a full Supabase reset.
// It executes the checked-in migration unchanged, including its precondition,
// red/green probes, transaction, and cleanup.
const migration = await readFile(
  new URL('../migrations/20263902000000_round3825_founder_audit_trigger_row_cast.sql', import.meta.url),
  'utf8',
);
const predecessor = await readFile(
  new URL('../migrations/20260806000000_round487_founder_audit_triggers.sql', import.meta.url),
  'utf8',
);
const oldFunctionStart = predecessor.indexOf(
  'CREATE OR REPLACE FUNCTION public.founder_audit_table_mutation()',
);
const oldFunctionEnd = predecessor.indexOf('\n$$;', oldFunctionStart);
assert.ok(oldFunctionStart >= 0 && oldFunctionEnd > oldFunctionStart);
const oldFunction = predecessor.slice(oldFunctionStart, oldFunctionEnd + '\n$$;'.length);

const founderClaim = migration.match(
  /json_build_object\('sub',\s*'([0-9a-f-]{36})',\s*'role',\s*'authenticated',\s*'email',\s*'([^']+)'\)/i,
);
assert.ok(founderClaim, 'round3825 founder probe claims must be present');
const [, founderId, founderEmail] = founderClaim;
const quotedFounderEmail = founderEmail.replaceAll("'", "''");
const probeId = '00000000-0000-4000-8000-000000003825';

async function fixture({ seedFounder, founderEmailInDb = founderEmail }) {
  const db = new PGlite();
  await db.exec(`
    CREATE SCHEMA auth;
    CREATE TABLE auth.users (id uuid PRIMARY KEY, email text NOT NULL);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
    $$;
    CREATE FUNCTION auth.email() RETURNS text LANGUAGE sql STABLE AS $$
      SELECT nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email'
    $$;
    CREATE FUNCTION public.is_founder() RETURNS boolean LANGUAGE sql STABLE AS $$
      SELECT lower(coalesce(auth.email(), '')) = lower('${quotedFounderEmail}')
    $$;
    CREATE TABLE public.founder_action_log (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      actor_user_id uuid NOT NULL REFERENCES auth.users(id),
      actor_email text NOT NULL,
      op_name text NOT NULL,
      target_table text,
      target_row_id uuid,
      before_value jsonb,
      after_value jsonb,
      reason text,
      outcome text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT clock_timestamp()
    );
  `);
  if (seedFounder) {
    await db.query(
      'INSERT INTO auth.users (id, email) VALUES ($1, $2)',
      [founderId, founderEmailInDb],
    );
  }
  await db.exec(oldFunction);
  for (let n = 1; n <= 7; n += 1) {
    await db.exec(`
      CREATE TABLE public._r3825_audited_${n} (id uuid PRIMARY KEY, touched_at timestamptz);
      CREATE TRIGGER _r3825_audit_${n}
        AFTER UPDATE ON public._r3825_audited_${n}
        FOR EACH ROW EXECUTE FUNCTION public.founder_audit_table_mutation('probe');
    `);
  }
  return db;
}

async function countAudit(db) {
  const { rows } = await db.query('SELECT count(*)::int AS n FROM public.founder_action_log');
  return rows[0].n;
}

test('round3825 commits without a founder auth.users row and leaves no probe state', async () => {
  const db = await fixture({ seedFounder: false });
  try {
    await db.exec(migration);
    assert.equal(await countAudit(db), 0);
    const { rows } = await db.query(`
      SELECT prosrc, to_regclass('_r3825_probe') AS probe
        FROM pg_proc
       WHERE oid = 'public.founder_audit_table_mutation()'::regprocedure
    `);
    assert.match(rows[0].prosrc, /to_jsonb\(NEW\)/);
    assert.match(rows[0].prosrc, /to_jsonb\(OLD\)/);
    assert.doesNotMatch(rows[0].prosrc, /(?:NEW|OLD)::jsonb/);
    assert.equal(rows[0].probe, null);
  } finally {
    await db.close();
  }
});

test('round3825 skips a founder actor whose stored email differs in case', async () => {
  const db = await fixture({ seedFounder: true, founderEmailInDb: founderEmail.toUpperCase() });
  try {
    await db.exec(migration);
    assert.equal(await countAudit(db), 0);
  } finally {
    await db.close();
  }
});

test('round3825 still probes a seeded founder and audits only founder writes', async () => {
  const db = await fixture({ seedFounder: true });
  try {
    await db.exec(migration);
    assert.equal(await countAudit(db), 0, 'migration probe must roll back its audit row');

    await db.exec(`
      BEGIN;
      CREATE TEMP TABLE _r3825_runtime (id uuid PRIMARY KEY, touched_at timestamptz) ON COMMIT DROP;
      CREATE TRIGGER _r3825_runtime_audit
        AFTER UPDATE ON _r3825_runtime
        FOR EACH ROW EXECUTE FUNCTION public.founder_audit_table_mutation('runtime');
      INSERT INTO _r3825_runtime (id, touched_at)
        VALUES ('${probeId}', now());
    `);
    await db.query("SELECT set_config('request.jwt.claims', $1, true)", [
      JSON.stringify({ sub: founderId, role: 'authenticated', email: founderEmail }),
    ]);
    await db.exec(`UPDATE _r3825_runtime SET touched_at = now() WHERE id = '${probeId}'`);
    const { rows } = await db.query(`
      SELECT actor_user_id::text, actor_email, op_name, target_row_id::text,
             before_value IS NOT NULL AS has_before,
             after_value IS NOT NULL AS has_after
        FROM public.founder_action_log
    `);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].actor_user_id, founderId);
    assert.equal(rows[0].actor_email, founderEmail);
    assert.equal(rows[0].op_name, 'runtime:update');
    assert.equal(rows[0].target_row_id, probeId);
    assert.equal(rows[0].has_before, true);
    assert.equal(rows[0].has_after, true);

    await db.query("SELECT set_config('request.jwt.claims', $1, true)", [
      JSON.stringify({
        sub: '00000000-0000-4000-8000-000000000001',
        role: 'authenticated',
        email: 'not-founder@example.invalid',
      }),
    ]);
    await db.exec(`UPDATE _r3825_runtime SET touched_at = now() WHERE id = '${probeId}'`);
    assert.equal(await countAudit(db), 1, 'non-founder write must return before audit insert');
    await db.exec('ROLLBACK');
    assert.equal(await countAudit(db), 0);
  } finally {
    await db.close();
  }
});
