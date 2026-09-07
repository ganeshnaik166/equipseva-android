#!/usr/bin/env python3
"""Independent-session evidence authorization tests in a NEW local cluster.

Python 3.12 stdlib and PostgreSQL 16+ binaries are required. No connection URL,
host, credential or existing data directory is accepted. This models selected
Supabase tables and SQL role/claim boundaries, not Storage or full-schema RLS.
"""
import argparse
import copy
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import sys
import time
import uuid


def quoted(value):
    return "'" + str(value).replace("'", "''") + "'"


def identifier(prefix, number):
    return f'{prefix}0000000-0000-0000-0000-{number:012d}'


ACTOR = identifier(1, 3)
OTHER = identifier(1, 4)
HOSPITAL = identifier(1, 1)


class Session:
    """One psql process/connection with a deliberately open transaction."""

    def __init__(self, runner, name, authenticated=False):
        self.runner, self.name = runner, name
        self.stdout = runner.run / (name + '.stdout.log')
        self.stderr = runner.run / (name + '.stderr.log')
        with self.stdout.open('w', encoding='utf-8') as out, self.stderr.open('w', encoding='utf-8') as err:
            self.process = subprocess.Popen(
                [str(x) for x in runner.sql_args], env=runner.env,
                creationflags=runner.flags, stdin=subprocess.PIPE,
                stdout=out, stderr=err, text=True)
        runner.sessions.append(self)
        setup = f'SET application_name={quoted(name)}; BEGIN;'
        if authenticated:
            setup += (f'SET LOCAL ROLE authenticated;'
                      f"SELECT set_config('request.jwt.claim.sub',{quoted(ACTOR)},true),"
                      "set_config('request.jwt.claim.role','authenticated',true);")
        setup += "SELECT jsonb_build_object('context',jsonb_build_object('pid',pg_backend_pid(),"
        setup += "'role',current_user,'uid',auth.uid(),'claim_role',auth.role(),"
        setup += "'isolation',current_setting('transaction_isolation'),'timezone',current_setting('timezone')));"
        self.execute(setup, 'ready')
        state = runner.until(lambda: self.done('ready'), name + ' initialized')
        self.pid = state['pid']

    def execute(self, sql, tag):
        if self.process.poll() is not None:
            raise AssertionError(self.name + ' exited before operation; inspect its logs')
        command = sql + f"\nSELECT 'EQS_DONE:{tag}';\n"
        with (self.runner.run / (self.name + '.sql')).open('a', encoding='utf-8') as log:
            log.write(command)
        self.process.stdin.write(command)
        self.process.stdin.flush()

    def state(self):
        rows = self.runner.query(
            'SELECT pid,state,wait_event_type,wait_event,query '
            'FROM pg_stat_activity WHERE application_name=' + quoted(self.name))
        return rows[0] if rows else None

    def done(self, tag):
        state = self.state()
        if state and state['state'] == 'idle in transaction' and state['query'].strip() == f"SELECT 'EQS_DONE:{tag}';":
            return state
        if self.process.poll() is not None:
            raise AssertionError(self.name + ' exited before ' + tag + '; inspect its logs')
        return None

    def finish(self, commit=True):
        command = ('COMMIT;' if commit else 'ROLLBACK;') + '\n\\q\n'
        with (self.runner.run / (self.name + '.sql')).open('a', encoding='utf-8') as log:
            log.write(command)
        self.process.communicate(command, timeout=15)
        result = self.result()
        self.runner.current.setdefault('transaction_order', []).append(
            {'session': self.name, 'pid': self.pid, 'action': 'COMMIT' if commit else 'ROLLBACK'})
        self.runner.require('transaction ends successfully', result['exit_code'] == 0 and not result['sqlstates'], result)
        return result

    def result(self):
        self.process.wait(timeout=15)
        stdout = self.stdout.read_text(encoding='utf-8')
        stderr = self.stderr.read_text(encoding='utf-8')
        result = {'name': self.name, 'pid': self.pid, 'exit_code': self.process.returncode,
                  'json': [json.loads(line) for line in stdout.splitlines() if line.startswith('{')],
                  'sqlstates': re.findall(r'ERROR:\s+([0-9A-Z]{5}):', stderr)}
        self.runner.current.setdefault('sessions', {})[self.name] = result
        return result


class Runner:
    def __init__(self, pg_bin, output_root):
        self.pg = pg_bin.resolve(strict=True)
        self.output = output_root.resolve()
        self.output.mkdir(parents=True, exist_ok=True)
        workspace = self.output / ('evidence-concurrency-' + time.strftime('%Y%m%d-%H%M%S') + '-' + secrets.token_hex(3))
        workspace.mkdir()
        self.run = workspace / 'evidence'
        self.run.mkdir()
        self.data = workspace / 'data'
        if not self.data.resolve().is_relative_to(self.output) or self.data.exists():
            raise ValueError('A new child data directory is required')
        self.flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        self.env = {k: v for k, v in os.environ.items() if not k.upper().startswith('PG')}
        self.env['PATH'] = str(self.pg) + os.pathsep + os.environ.get('PATH', '')
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            self.port = sock.getsockname()[1]
        self.sql_args = [self.binary('psql'), '-X', '-qAt', '-h', '127.0.0.1', '-p', self.port,
                         '-U', 'eqs_evidence_owner', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1',
                         '-v', 'VERBOSITY=verbose']
        here = Path(__file__).resolve().parent
        self.files = {
            'runner': Path(__file__).resolve(),
            'fixture': here / 'evidence_authorization.fixture.sql',
            'baseline': here.parent / 'migrations/20260811000000_round492_evidence_65b_chain.sql',
            'candidate': here.parent / 'migrations/20263898000000_round3821_evidence_authorization.sql',
        }
        self.report = {'scope': 'local independent-session E09/E11 fixture', 'cases': [],
                       'source_hashes': self.hashes(), 'python': sys.version,
                       'loopback_port': self.port, 'data_directory': str(self.data),
                       'limits': ['Synthetic SQL roles/claims, not real Auth or Storage HTTP integration.',
                                  'Only modeled tables and transitions; not full Supabase migration replay.',
                                  'Administrative mutations do not prove ordinary-user mutation privileges.',
                                  'READ COMMITTED only; no global deadlock-freedom or object-immutability claim.']}
        self.sessions, self.started = [], False
        self.current = {}

    def binary(self, name):
        path = self.pg / (name + ('.exe' if os.name == 'nt' else ''))
        if not path.is_file():
            raise ValueError('Required PostgreSQL binary missing: ' + str(path))
        return path

    def hashes(self):
        return {key: hashlib.sha256(path.read_bytes()).hexdigest() for key, path in self.files.items()}

    def command(self, args, **kwargs):
        return subprocess.run([str(x) for x in args], env=self.env, creationflags=self.flags,
                              text=True, capture_output=True, **kwargs)

    def sql(self, text, timeout=15):
        result = self.command(self.sql_args, input=text, timeout=timeout)
        if result.returncode:
            (self.run / 'failed-controller-sql.log').write_text(result.stdout + result.stderr, encoding='utf-8')
            raise AssertionError('Controller SQL failed; inspect preserved log')
        return result.stdout.strip()

    def query(self, text):
        return json.loads(self.sql("SELECT coalesce(json_agg(q),'[]'::json) FROM (" + text + ') q;'))

    def until(self, predicate, label, timeout=8):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(0.03)  # Poll observation; never release a race based on elapsed sleep.
        raise AssertionError('Observation deadline: ' + label)

    def require(self, label, condition, detail=None):
        self.current.setdefault('assertions', []).append({'label': label, 'passed': bool(condition), 'detail': detail})
        if not condition:
            raise AssertionError(label)

    def blocked(self, waiter, blocker):
        rows = self.query(f"""SELECT a.pid,a.state,a.wait_event_type,a.wait_event,a.query,
pg_blocking_pids(a.pid) AS blocker_pids,
(SELECT json_agg(json_build_object('type',l.locktype,'mode',l.mode,'granted',l.granted,
 'relation',l.relation::regclass::text,'transactionid',l.transactionid::text,'tuple',l.tuple))
 FROM pg_locks l WHERE l.pid=a.pid AND (NOT l.granted OR l.locktype IN ('tuple','transactionid'))) AS locks
FROM pg_stat_activity a WHERE a.pid={waiter.pid}
 AND a.state='active' AND a.wait_event_type='Lock' AND {blocker.pid}=ANY(pg_blocking_pids(a.pid))""")
        return rows[0] if rows else None

    def observe_wait(self, waiter, blocker, label):
        observation = self.until(lambda: self.blocked(waiter, blocker), label)
        self.current.setdefault('waits', []).append({'label': label, 'waiter': waiter.name, 'blocker': blocker.name, **observation})
        self.require(label + ' distinct sessions and ungranted lock', waiter.pid != blocker.pid
                     and any(not lock['granted'] for lock in observation['locks']), observation)
        return observation

    def start(self):
        version = self.command([self.binary('postgres'), '--version'], timeout=10).stdout.strip()
        match = re.search(r'(\d+)\.\d+', version)
        if not match or int(match.group(1)) < 16:
            raise ValueError('PostgreSQL 16+ required')
        self.report['postgres_version'] = version
        initialized = self.command([self.binary('initdb'), '-D', self.data, '-U', 'eqs_evidence_owner',
                                    '--auth=trust', '--encoding=UTF8', '--locale=C'], timeout=60)
        (self.run / 'initdb.log').write_text(initialized.stdout + initialized.stderr, encoding='utf-8')
        if initialized.returncode:
            raise AssertionError('Fresh initdb failed')
        with (self.data / 'postgresql.conf').open('a', encoding='utf-8') as config:
            config.write(f"\nlisten_addresses='127.0.0.1'\nport={self.port}\nunix_socket_directories=''\n"
                         "max_connections=12\nshared_buffers='32MB'\ntimezone='UTC'\nstatement_timeout='15s'\n"
                         "lock_timeout='12s'\nidle_in_transaction_session_timeout='30s'\n")
        self.started = True
        with (self.run / 'pg_ctl.log').open('w', encoding='utf-8') as log:
            started = subprocess.run([str(x) for x in [self.binary('pg_ctl'), '-D', self.data, '-l', self.run / 'postgres.log', '-w', 'start']],
                                     env=self.env, creationflags=self.flags, stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=log, timeout=60)
        if started.returncode:
            raise AssertionError('Fresh PostgreSQL startup failed')
        self.report['owned_postmaster_pid'] = int((self.data / 'postmaster.pid').read_text().splitlines()[0])
        for key in ('fixture', 'baseline', 'candidate'):
            result = self.command([*self.sql_args, '-f', self.files[key]], timeout=30)
            (self.run / (key + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
            if result.returncode:
                raise AssertionError(key + ' actual SQL file failed')
        self.report['function_catalog_before'] = self.catalog()
        source = self.files['candidate'].read_text(encoding='utf-8')
        expected = {
            'register_evidence': ('25 25 2950 25 20 25 25 1184 25 3802', 'uuid', False, 'v', 'uuid'),
            'verify_evidence_hash': ('2950 25', 'record', True, 's',
                'TABLE(matches boolean, ledger_id uuid, evidence_kind text, captured_at timestamp with time zone, producer_user_id uuid, producer_kind text)'),
            'evidence_for_repair_job': ('2950', 'record', True, 's',
                'TABLE(id uuid, evidence_kind text, content_sha256 text, content_size_bytes bigint, storage_url text, producer_user_id uuid, producer_kind text, captured_at timestamp with time zone, metadata jsonb, created_at timestamp with time zone)'),
        }
        checks = []
        for row in self.report['function_catalog_before']:
            body = re.search(r'CREATE OR REPLACE FUNCTION public\.' + row['proname'] + r'\(.*?AS \$\$(.*?)\$\$;', source, re.S)
            contract = expected.get(row['proname'])
            valid = body is not None and contract is not None
            valid = valid and row['body_md5'] == hashlib.md5(body.group(1).encode()).hexdigest()
            valid = valid and (row['input_types'], row['return_type'], row['proretset'], row['provolatile'], row['result_contract']) == contract
            valid = valid and row['owner'] == 'eqs_evidence_owner' and row['prosecdef'] and row['language'] == 'plpgsql'
            valid = valid and row['proconfig'] == ['search_path=public, pg_temp']
            valid = valid and not row['anon_execute'] and row['authenticated_execute'] and row['service_execute']
            checks.append({'function': row['proname'], 'passed': bool(valid)})
        self.report['function_preflight'] = checks
        if len(checks) != 3 or not all(check['passed'] for check in checks):
            raise AssertionError('Installed r3821 source/contract/owner/ACL preflight failed')

    def catalog(self):
        return self.query("SELECT p.oid,p.proname,md5(replace(p.prosrc,E'\\r\\n',E'\\n')) body_md5,"
                          "p.proargtypes::text input_types,pg_get_function_identity_arguments(p.oid) identity_arguments,"
                          "pg_get_function_result(p.oid) result_contract,p.prorettype::regtype::text return_type,"
                          "p.proretset,pg_get_userbyid(p.proowner) owner,l.lanname language,"
                          "p.prosecdef,p.provolatile,p.proconfig,p.proacl,"
                          "has_function_privilege('anon',p.oid,'execute') anon_execute,"
                          "has_function_privilege('authenticated',p.oid,'execute') authenticated_execute,"
                          "has_function_privilege('service_role',p.oid,'execute') service_execute "
                          "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
                          "JOIN pg_language l ON l.oid=p.prolang WHERE n.nspname='public' "
                          "AND p.proname IN ('register_evidence','verify_evidence_hash','evidence_for_repair_job') ORDER BY p.oid")

    def seed(self, number, kind='photo_before', second_object=False):
        case = {'job': identifier(3, 1000 + number), 'engineer': identifier(2, 2000 + number * 2),
                'engineer_b': identifier(2, 2001 + number * 2), 'object': identifier(4, 3000 + number * 2),
                'object_b': identifier(4, 3001 + number * 2), 'kind': kind,
                'hash': hashlib.sha256(('synthetic-photo-' + str(number)).encode()).hexdigest()}
        case['path'] = ACTOR + '/' + case['job'] + '/photo.jpg'
        case['path_b'] = ACTOR + '/' + case['job'] + '/other.jpg'
        paths = [case['path'], case['path_b']] if second_object else [case['path']]
        array = 'ARRAY[' + ','.join(quoted(path) for path in paths) + ']::text[]'
        self.sql(f"INSERT INTO public.engineers VALUES({quoted(case['engineer'])},{quoted(ACTOR)}),"
                 f"({quoted(case['engineer_b'])},{quoted(OTHER)});"
                 f"INSERT INTO public.repair_jobs(id,hospital_user_id,engineer_id,before_photos,after_photos) VALUES"
                 f"({quoted(case['job'])},{quoted(HOSPITAL)},{quoted(case['engineer'])},{array},{array});"
                 f"INSERT INTO public.repair_job_bids(repair_job_id,engineer_user_id,status)VALUES"
                 f"({quoted(case['job'])},{quoted(ACTOR)},'accepted');")
        for oid, path in [(case['object'], case['path'])] + ([(case['object_b'], case['path_b'])] if second_object else []):
            self.sql("INSERT INTO storage.objects(id,bucket_id,name,owner,owner_id,metadata)VALUES(" +
                     ','.join(map(quoted, [oid, 'repair-photos', path, ACTOR, ACTOR])) + ",'{\"size\":3,\"mimetype\":\"image/jpeg\"}');")
        return case

    def state(self, case):
        return self.query(f"""SELECT
(SELECT to_jsonb(j) FROM public.repair_jobs j WHERE id={quoted(case['job'])}) job,
(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM public.engineers e WHERE id IN ({quoted(case['engineer'])},{quoted(case['engineer_b'])})) engineers,
(SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY id),'[]') FROM storage.objects o WHERE id IN ({quoted(case['object'])},{quoted(case['object_b'])})) objects,
(SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY id),'[]') FROM public.evidence_ledger e WHERE source_id={quoted(case['job'])}) ledger""")[0]

    def registration(self, case, attempt, other_object=False):
        path = case['path_b'] if other_object else case['path']
        captured = '2026-09-07T06:00:00Z' if attempt == 'A' else '2026-09-07T06:01:00Z'
        values = [case['kind'], 'repair_job', case['job'], case['hash']]
        args = ','.join(map(quoted, values)) + ',3,' + quoted('repair-photos/' + path)
        args += ",'engineer'," + quoted(captured) + ',' + quoted('test/' + attempt)
        args += ',' + quoted(json.dumps({'attempt': attempt})) + '::jsonb'
        return "SELECT jsonb_build_object('rpc_id',public.register_evidence(" + args + '));'

    def verify_result(self, result, allow, code=None):
        contexts = [row['context'] for row in result['json'] if 'context' in row]
        self.require('actual RPC session identity and isolation', len(contexts) == 1
                     and contexts[0] == {'pid': result['pid'], 'role': 'authenticated', 'uid': ACTOR,
                                         'claim_role': 'authenticated', 'isolation': 'read committed', 'timezone': 'UTC'}, contexts)
        ids = [row['rpc_id'] for row in result['json'] if 'rpc_id' in row]
        if allow:
            self.require('authorized RPC returns one UUID without SQL error', result['exit_code'] == 0
                         and not result['sqlstates'] and len(ids) == 1 and str(uuid.UUID(ids[0])) == ids[0], result)
            return ids[0]
        self.require('denied RPC returns expected error and no ID', result['exit_code'] != 0
                     and result['sqlstates'] == [code] and not ids, result)
        return None

    def verify_row(self, case, row, attempt, other_object=False):
        expected = {'evidence_kind': case['kind'], 'source_kind': 'repair_job', 'source_id': case['job'],
                    'content_sha256': case['hash'], 'content_size_bytes': 3,
                    'storage_url': 'repair-photos/' + (case['path_b'] if other_object else case['path']),
                    'producer_user_id': ACTOR, 'producer_kind': 'engineer', 'platform_version': 'test/' + attempt,
                    'metadata': {'attempt': attempt, 'registration_authority': 'assigned_engineer',
                                 'hash_verification': 'client_asserted',
                                 'storage_object_id': case['object_b'] if other_object else case['object']}}
        self.require('entire registration provenance matches winning request', all(row[k] == v for k, v in expected.items()), row)
        target = '2026-09-07T06:00:00+00:00' if attempt == 'A' else '2026-09-07T06:01:00+00:00'
        created = datetime.fromisoformat(row['created_at'])
        captured = datetime.fromisoformat(row['captured_at'])
        self.require('capture and creation timestamps retained', row['captured_at'] == target
                     and created.tzinfo is not None and captured.tzinfo is not None, row)

    def duplicate(self, number, disposition):
        case = self.seed(number, second_object=disposition == 'collision')
        self.current['before'] = self.state(case)
        gate = Session(self, self.current['id'] + '_gate')
        gate.execute('LOCK TABLE public.evidence_ledger IN SHARE MODE;', 'barrier')
        self.until(lambda: gate.done('barrier'), 'ledger barrier held')
        first = Session(self, self.current['id'] + '_a', True)
        second = Session(self, self.current['id'] + '_b', True)
        first.execute(self.registration(case, 'A'), 'registered')
        second.execute(self.registration(case, 'B', disposition == 'collision'), 'registered')
        self.observe_wait(first, gate, 'first registration blocked on explicit barrier')
        self.observe_wait(second, gate, 'second registration simultaneously blocked on same barrier')
        self.require('both waits still present before releasing barrier', self.blocked(first, gate) and self.blocked(second, gate))
        gate.finish()

        def select_winner():
            for winner, loser, attempt in [(first, second, 'A'), (second, first, 'B')]:
                if winner.done('registered') and self.blocked(loser, winner):
                    return winner, loser, attempt
            return None
        winner, loser, attempt = self.until(select_winner, 'unique-key winner and waiting loser')
        unique_wait = self.observe_wait(loser, winner, 'unique-conflict registration blocked on uncommitted winner')
        self.require('unique conflict waits on transaction completion', any(
            lock['type'] == 'transactionid' and not lock['granted'] for lock in unique_wait['locks']), unique_wait)
        self.require('uncommitted evidence not visible to independent observer', not self.state(case)['ledger'])
        win_result = winner.finish(disposition != 'rollback')
        win_id = self.verify_result(win_result, True)
        committed = self.state(case)['ledger']
        if disposition == 'rollback':
            self.require('aborted winner leaves no committed row', not committed)
        else:
            self.require('winner commits one row', len(committed) == 1 and committed[0]['id'] == win_id, committed)
            self.verify_row(case, committed[0], attempt, disposition == 'collision' and attempt == 'B')
        if disposition == 'collision':
            lose_result = loser.result()
            self.verify_result(lose_result, False, '42501')
        else:
            self.until(lambda: loser.done('registered'), 'waiting registration completes after winner ends')
            lose_result = loser.finish()
            lose_id = self.verify_result(lose_result, True)
            self.require('retry ID follows winning transaction outcome', lose_id != win_id if disposition == 'rollback' else lose_id == win_id)
        after = self.state(case)
        self.current['after'] = after
        self.require('exactly one surviving immutable row', len(after['ledger']) == 1)
        if disposition == 'rollback':
            self.require('committed survivor ID matches the successful waiter', after['ledger'][0]['id'] == lose_id)
            self.verify_row(case, after['ledger'][0], 'B' if attempt == 'A' else 'A')
        else:
            self.require('loser preserves every winner ledger column', after['ledger'] == committed, after['ledger'])
        self.require('duplicate calls leave source and objects unchanged', {k:v for k,v in after.items() if k!='ledger'} ==
                     {k:v for k,v in self.current['before'].items() if k!='ledger'})

    def mutation(self, case, mode, initial):
        expected = copy.deepcopy(initial)
        if mode.startswith('assignment_'):
            value = None if mode == 'assignment_clear' else case['engineer_b']
            expected['job']['engineer_id'] = value
            return 'UPDATE public.repair_jobs SET engineer_id=' + ('NULL' if value is None else quoted(value)) + ' WHERE id=' + quoted(case['job']), expected, '42501'
        if mode.startswith('attachment_'):
            column = 'after_photos' if mode == 'attachment_after' else 'before_photos'
            expected['job'][column] = []
            return f"UPDATE public.repair_jobs SET {column}='{{}}' WHERE id=" + quoted(case['job']), expected, '42501'
        if mode.startswith('mapping_'):
            value = None if mode == 'mapping_clear' else OTHER
            next(e for e in expected['engineers'] if e['id'] == case['engineer'])['user_id'] = value
            return 'UPDATE public.engineers SET user_id=' + ('NULL' if value is None else quoted(value)) + ' WHERE id=' + quoted(case['engineer']), expected, '42501'
        obj = expected['objects'][0]
        if mode == 'object_delete':
            expected['objects'] = []
            return 'DELETE FROM storage.objects WHERE id=' + quoted(case['object']), expected, '02000'
        column, value, code = {'object_owner': ('owner_id', OTHER, '42501'),
                               'object_size': ('metadata', {'size':4,'mimetype':'image/jpeg'}, '22023'),
                               'object_name': ('name', case['path'] + '.renamed', '02000'),
                               'object_bucket': ('bucket_id', 'other-bucket', '02000')}[mode]
        obj[column] = value
        value_sql = quoted(json.dumps(value)) + '::jsonb' if column == 'metadata' else quoted(value)
        return f'UPDATE storage.objects SET {column}={value_sql} WHERE id=' + quoted(case['object']), expected, code

    def mutation_race(self, number, mode, order, rollback=False):
        case = self.seed(number, 'photo_after' if mode == 'attachment_after' else 'photo_before')
        before = self.state(case)
        self.current['before'] = before
        mutation, expected, error = self.mutation(case, mode, before)
        change = Session(self, self.current['id'] + '_change')
        registration = Session(self, self.current['id'] + '_reg', True)
        if order == 'mutation_first':
            change.execute(mutation + ';', 'changed')
            self.until(lambda: change.done('changed'), 'uncommitted authority mutation complete')
            registration.execute(self.registration(case, 'A'), 'registered')
            self.observe_wait(registration, change, 'registration waits on authority/object mutation')
            change.finish(not rollback)
            if rollback:
                self.until(lambda: registration.done('registered'), 'registration succeeds after mutation rollback')
                registered = registration.finish()
                identity = self.verify_result(registered, True)
                expected = copy.deepcopy(before)
                final = self.state(case)
                self.require('rolled-back mutation permits one authorized row', len(final['ledger']) == 1 and final['ledger'][0]['id'] == identity)
                self.verify_row(case, final['ledger'][0], 'A')
                expected['ledger'] = final['ledger']
            else:
                self.verify_result(registration.result(), False, error)
        else:
            registration.execute(self.registration(case, 'A'), 'registered')
            self.until(lambda: registration.done('registered'), 'authorized insert complete but uncommitted')
            change.execute(mutation + ';', 'changed')
            self.observe_wait(change, registration, 'authority/object mutation waits on registration locks')
            identity = self.verify_result(registration.finish(), True)
            committed = self.state(case)['ledger']
            self.require('authorized registration commits one row before later mutation', len(committed) == 1 and committed[0]['id'] == identity)
            self.verify_row(case, committed[0], 'A')
            self.until(lambda: change.done('changed'), 'later mutation completes after registration commit')
            change.finish()
            expected['ledger'] = committed
            retry = Session(self, self.current['id'] + '_retry', True)
            retry.execute(self.registration(case, 'B'), 'registered')
            self.verify_result(retry.result(), False, error)
        final = self.state(case)
        self.current['after'] = final
        self.require('complete final job/mapping/object/ledger state follows transaction order', final == expected, {'expected': expected, 'actual': final})

    def case(self, name, action):
        self.current = {'id': f'c{len(self.report["cases"])+1:02d}', 'name': name, 'passed': False}
        self.report['cases'].append(self.current)
        try:
            action()
            self.current['passed'] = True
            print('PASS ' + name, flush=True)
        except Exception as error:
            self.current['error'] = type(error).__name__ + ': ' + str(error)
            raise

    def close(self):
        errors = []
        for session in self.sessions:
            try:
                if session.process.poll() is None:
                    session.process.terminate()
                    try:
                        session.process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        session.process.kill()
                        session.process.wait(timeout=5)
            except Exception as error:
                errors.append(session.name + ':' + type(error).__name__)
        if self.started:
            try:
                stopped = self.command([self.binary('pg_ctl'), '-D', self.data, '-m', 'fast', '-w', 'stop'], timeout=30)
                (self.run / 'stop.log').write_text(stopped.stdout + stopped.stderr, encoding='utf-8')
                self.report['postgres_stopped'] = stopped.returncode == 0 and not (self.data / 'postmaster.pid').exists()
                if not self.report['postgres_stopped']:
                    errors.append('postgres_not_stopped')
            except Exception as error:
                errors.append('postgres:' + type(error).__name__)
        self.report['cleanup_errors'] = errors
        self.report['owned_session_exit_codes'] = {session.name: session.process.poll() for session in self.sessions}
        with socket.socket() as check_socket:
            check_socket.settimeout(1)
            self.report['listener_closed'] = check_socket.connect_ex(('127.0.0.1', self.port)) != 0
        if not self.report['listener_closed'] or any(value is None for value in self.report['owned_session_exit_codes'].values()):
            self.report['cleanup_errors'].append('owned_listener_or_session_still_running')
        self.report['source_hashes_after'] = self.hashes()
        if self.report['source_hashes_after'] != self.report['source_hashes']:
            self.report['completed'] = False
            self.report['source_changed_during_run'] = True
        (self.run / 'report.json').write_text(json.dumps(self.report, indent=2) + '\n', encoding='utf-8')
        print('Report: ' + str(self.run / 'report.json'), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pg-bin', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    runner = Runner(args.pg_bin, args.output_root)
    try:
        runner.start()
        for number, outcome in enumerate(('commit', 'rollback', 'collision'), 1):
            runner.case('concurrent same-key registrations: ' + outcome,
                        lambda n=number, o=outcome: runner.duplicate(n, o))
        number = 10
        for mode in ('assignment_clear', 'assignment_reassign', 'attachment_before', 'attachment_after',
                     'mapping_clear', 'mapping_rebind', 'object_owner', 'object_size', 'object_name',
                     'object_bucket', 'object_delete'):
            for order in ('mutation_first', 'registration_first'):
                runner.case(mode + ': ' + order, lambda n=number, m=mode, o=order: runner.mutation_race(n, m, o))
                number += 1
        for mode in ('assignment_reassign', 'object_owner'):
            runner.case(mode + ': mutation_rollback', lambda n=number, m=mode: runner.mutation_race(n, m, 'mutation_first', True))
            number += 1
        runner.report['function_catalog_after'] = runner.catalog()
        if runner.report['function_catalog_before'] != runner.report['function_catalog_after']:
            raise AssertionError('Evidence function catalog changed during data-only tests')
        runner.report['completed'] = True
    except Exception as error:
        runner.report.update(completed=False, error=type(error).__name__ + ': ' + str(error))
        print('FAIL ' + runner.report['error'], flush=True)
    finally:
        runner.close()
    return 0 if runner.report.get('completed') and not runner.report['cleanup_errors'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
