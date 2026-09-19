#!/usr/bin/env python3
"""Test actual photo finalizer RPCs in a new, loopback-only PostgreSQL cluster.

Uses the existing stdlib cluster/session harness; accepts no DSN or existing
data directory. SQL roles/claims and selected tables are synthetic fixtures.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
import evidence_concurrency as base


class Runner(base.Runner):
    def __init__(self, pg_bin, output_root):
        super().__init__(pg_bin, output_root)
        here = Path(__file__).resolve().parent
        self.files.update(runner=Path(__file__).resolve(), harness=Path(base.__file__).resolve(),
                          finalizer=here.parent / 'migrations/20263900000000_round3823_finalize_repair_photo.sql')
        self.report['source_hashes'] = self.hashes()
        self.report['scope'] = 'local independent-session repair-photo finalizer F06-F09'
        self.report['limits'].append('Cooperating RPCs only: legacy array replacement can overwrite later; no Android recovery proof.')

    def finalizer_catalog(self):
        return self.query("SELECT to_jsonb(p) routine,p.proargtypes::text input_types,pg_get_function_result(p.oid) result,"
                          "pg_get_userbyid(p.proowner) owner,l.lanname language,"
                          "md5(replace(p.prosrc,E'\\r\\n',E'\\n')) body_md5,"
                          "has_function_privilege('authenticated',p.oid,'execute') authenticated,"
                          "has_function_privilege('anon',p.oid,'execute') anon,"
                          "has_function_privilege('service_role',p.oid,'execute') service "
                          "FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang WHERE p.oid="
                          "'public.finalize_repair_photo(uuid,text,text,text,bigint,timestamptz,text,jsonb)'::regprocedure")

    def start(self):
        super().start()
        for stage in ('apply', 'reapply'):
            result = self.command([*self.sql_args, '-f', self.files['finalizer']], timeout=30)
            (self.run / ('finalizer-' + stage + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
            if result.returncode:
                raise AssertionError('Actual finalizer migration failed at ' + stage)
        rows = self.finalizer_catalog()
        self.report['finalizer_catalog_before'] = rows
        source = self.files['finalizer'].read_text(encoding='utf-8')
        body = re.search(r'CREATE OR REPLACE FUNCTION public\.finalize_repair_photo\(.*?AS \$\$(.*?)\$\$;', source, re.S)
        if len(rows) != 1 or body is None:
            raise AssertionError('Finalizer source/catalog missing')
        row, p = rows[0], rows[0]['routine']
        if not (row['body_md5'] == hashlib.md5(body.group(1).encode()).hexdigest()
                and row['owner'] == 'eqs_evidence_owner' and row['language'] == 'plpgsql'
                and row['result'] == 'TABLE(ledger_id uuid, attachment_path text)'
                and row['input_types'] == '2950 25 25 25 20 1184 25 3802' and p['proretset']
                and p['prosecdef'] and p['provolatile'] == 'v' and p['proconfig'] == ['search_path=public, pg_temp']
                and row['authenticated'] and not row['anon'] and not row['service']):
            raise AssertionError('Finalizer installed contract mismatch')

    def seed(self, number, kind='photo_before', second_object=True):
        case = super().seed(number, kind, second_object)
        self.sql("UPDATE public.repair_jobs SET before_photos=ARRAY['existing-before'],"
                 "after_photos=ARRAY['existing-after'] WHERE id=" + base.quoted(case['job']))
        return case

    def registration(self, case, attempt, other_object=False):
        path = case['path_b'] if other_object else case['path']
        captured = '2026-09-07T06:00:00Z' if attempt == 'A' else '2026-09-07T06:01:00Z'
        args = ','.join(map(base.quoted, [case['job'], case['kind'], 'repair-photos/' + path, case['hash']]))
        args += ',3,' + base.quoted(captured) + ',' + base.quoted('test/' + attempt)
        args += ',' + base.quoted(json.dumps({'attempt': attempt})) + '::jsonb'
        return "SELECT jsonb_build_object('rpc_id',ledger_id,'attachment_path',attachment_path) FROM public.finalize_repair_photo(" + args + ');'

    def verify_finalized(self, result, case, allow=True, code=None, other_object=False):
        identity = self.verify_result(result, allow, code)
        if allow:
            paths = [row['attachment_path'] for row in result['json'] if 'rpc_id' in row]
            self.require('typed result identifies canonical attachment', paths == [case['path_b'] if other_object else case['path']], paths)
        return identity

    @staticmethod
    def appended(state, case, other_object=False):
        expected = copy.deepcopy(state)
        column = 'before_photos' if case['kind'] == 'photo_before' else 'after_photos'
        paths = expected['job'][column] or []
        path = case['path_b'] if other_object else case['path']
        expected['job'][column] = paths if path in paths else paths + [path]
        return expected

    def assert_state(self, case, expected):
        final = self.state(case)
        self.current['after'] = final
        self.require('complete job/mapping/object/ledger state matches material order', final == expected,
                     {'expected': expected, 'actual': final})

    def pair(self, number, first_kind, second_kind, outcome):
        case = self.seed(number, first_kind)
        other = copy.deepcopy(case)
        other['kind'] = second_kind
        distinct = outcome == 'distinct'
        other_object = distinct or outcome == 'collision'
        if distinct:
            other['hash'] = hashlib.sha256(('distinct-' + str(number)).encode()).hexdigest()
        before = self.state(case)
        self.current['before'] = before
        first = base.Session(self, self.current['id'] + '_first', True)
        second = base.Session(self, self.current['id'] + '_second', True)
        first.execute(self.registration(case, 'A'), 'registered')
        self.until(lambda: first.done('registered'), 'first finalizer completed inside open transaction')
        second.execute(self.registration(other, 'B', other_object), 'registered')
        self.observe_wait(second, first, 'second finalizer waits on first job transaction')
        self.require('uncommitted attachment and ledger invisible to observer', self.state(case) == before)
        first_id = self.verify_finalized(first.finish(outcome != 'rollback'), case)
        committed = self.state(case)
        if outcome == 'rollback':
            self.require('rolled-back first finalization leaves complete baseline', committed == before)
            expected = copy.deepcopy(before)
        else:
            expected = self.appended(before, case)
            self.require('first commits one matching ledger row', len(committed['ledger']) == 1 and committed['ledger'][0]['id'] == first_id)
            self.verify_row(case, committed['ledger'][0], 'A')
            expected['ledger'] = committed['ledger']
            self.require('first commit preserves other state', committed == expected)
        if outcome == 'collision':
            self.verify_finalized(second.result(), other, False, '42501')
        else:
            self.until(lambda: second.done('registered'), 'second finalizer completes after first ends')
            second_id = self.verify_finalized(second.finish(), other, other_object=other_object)
            after = self.state(case)
            if distinct:
                self.require('distinct photos have distinct evidence IDs', second_id != first_id and len(after['ledger']) == 2)
                rows = {row['id']: row for row in after['ledger']}
                self.require('first receipt immutable after second append', rows[first_id] == committed['ledger'][0])
                self.verify_row(other, rows[second_id], 'B', True)
                expected = self.appended(expected, other, True)
                expected['ledger'] = after['ledger']
            elif outcome == 'rollback':
                self.require('waiter survives aborted first ID', second_id != first_id and len(after['ledger']) == 1 and after['ledger'][0]['id'] == second_id)
                self.verify_row(other, after['ledger'][0], 'B')
                expected = self.appended(expected, other)
                expected['ledger'] = after['ledger']
            else:
                self.require('same operation returns immutable original receipt', second_id == first_id and after['ledger'] == committed['ledger'])
        self.assert_state(case, expected)

    def mutation_race(self, number, mode, order):
        attachment = mode.startswith('attachment_')
        case = self.seed(number, 'photo_after' if mode == 'attachment_after' else 'photo_before', False)
        if attachment:
            initial = base.Session(self, self.current['id'] + '_initial', True)
            initial.execute(self.registration(case, 'A'), 'registered')
            self.until(lambda: initial.done('registered'), 'initial receipt exists before attachment removal')
            original_id = self.verify_finalized(initial.finish(), case)
        before = self.state(case)
        self.current['before'] = before
        mutation, changed, error = self.mutation(case, mode, before)
        change = base.Session(self, self.current['id'] + '_change')
        finalizer = base.Session(self, self.current['id'] + '_finalize', True)
        if order == 'mutation_first':
            change.execute(mutation + ';', 'changed')
            self.until(lambda: change.done('changed'), 'authority mutation remains uncommitted')
            finalizer.execute(self.registration(case, 'A'), 'registered')
            self.observe_wait(finalizer, change, 'finalizer waits then rechecks changed source')
            change.finish()
            expected = changed
            if attachment:
                self.until(lambda: finalizer.done('registered'), 'authorized finalizer restores removed attachment')
                identity = self.verify_finalized(finalizer.finish(), case)
                self.require('restoration retains original receipt ID', identity == original_id)
                expected = self.appended(expected, case)
            else:
                self.verify_finalized(finalizer.result(), case, False, error)
        else:
            finalizer.execute(self.registration(case, 'A'), 'registered')
            self.until(lambda: finalizer.done('registered'), 'finalization complete but uncommitted')
            change.execute(mutation + ';', 'changed')
            self.observe_wait(change, finalizer, 'source mutation waits for finalizer transaction')
            identity = self.verify_finalized(finalizer.finish(), case)
            committed = self.state(case)['ledger']
            self.require('one authorized committed receipt', len(committed) == 1 and committed[0]['id'] == identity)
            self.verify_row(case, committed[0], 'A')
            self.until(lambda: change.done('changed'), 'later mutation can proceed')
            change.finish()
            _, expected, _ = self.mutation(case, mode, self.appended(before, case))
            expected['ledger'] = committed
            self.current['after_mutation_before_retry'] = self.state(case)
            self.require('later mutation preserves historical receipt', self.state(case) == expected)
            retry = base.Session(self, self.current['id'] + '_retry', True)
            retry.execute(self.registration(case, 'B'), 'registered')
            if attachment:
                self.until(lambda: retry.done('registered'), 'authorized retry reattaches')
                self.require('reattachment returns same receipt', self.verify_finalized(retry.finish(), case) == identity)
                expected = self.appended(expected, case)
            else:
                self.verify_finalized(retry.result(), case, False, error)
        self.assert_state(case, expected)

    def overlap(self, number, old_first):
        case = self.seed(number)
        self.sql("UPDATE public.repair_jobs SET before_photos=before_photos || ARRAY[" + base.quoted(case['path']) + "] WHERE id=" + base.quoted(case['job']))
        other = copy.deepcopy(case)
        other['hash'] = hashlib.sha256(('overlap-' + str(number)).encode()).hexdigest()
        before = self.state(case)
        self.current['before'] = before
        old = base.Session(self, self.current['id'] + '_old', True)
        new = base.Session(self, self.current['id'] + '_new', True)
        old_sql = base.Runner.registration(self, case, 'A')
        new_sql = self.registration(other, 'B', True)
        first, second, first_sql, second_sql = (old, new, old_sql, new_sql) if old_first else (new, old, new_sql, old_sql)
        first.execute(first_sql, 'registered')
        self.until(lambda: first.done('registered'), 'first RPC holds its job lock')
        second.execute(second_sql, 'registered')
        self.observe_wait(second, first, 'old/new RPC overlap waits on compatible job lock order')
        first_result = first.finish()
        self.until(lambda: second.done('registered'), 'second RPC resolves after first commit')
        second_result = second.finish()
        old_result, new_result = (first_result, second_result) if old_first else (second_result, first_result)
        old_id = self.verify_result(old_result, True)
        new_id = self.verify_finalized(new_result, other, other_object=True)
        final = self.state(case)
        self.require('old and new operations retain distinct evidence', old_id != new_id and len(final['ledger']) == 2)
        rows = {row['id']: row for row in final['ledger']}
        self.verify_row(case, rows[old_id], 'A')
        self.verify_row(other, rows[new_id], 'B', True)
        expected = self.appended(before, other, True)
        expected['ledger'] = final['ledger']
        self.assert_state(case, expected)

    def old_unattached_denial(self, number):
        case = self.seed(number)
        before = self.state(case)
        self.current['before'] = before
        session = base.Session(self, self.current['id'] + '_old', True)
        session.execute(base.Runner.registration(self, case, 'A'), 'registered')
        self.verify_result(session.result(), False, '42501')
        self.assert_state(case, before)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pg-bin', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    runner = Runner(args.pg_bin, args.output_root)
    try:
        runner.start()
        number = 1
        for kinds in [('photo_before', 'photo_before'), ('photo_after', 'photo_after'), ('photo_before', 'photo_after')]:
            runner.case('distinct appends ' + '/'.join(kinds), lambda n=number, k=kinds: runner.pair(n, *k, 'distinct'))
            number += 1
        for outcome in ('commit', 'rollback', 'collision'):
            runner.case('same key ' + outcome, lambda n=number, o=outcome: runner.pair(n, 'photo_before', 'photo_before', o))
            number += 1
        for mode in ('assignment_clear','assignment_reassign','mapping_clear','mapping_rebind',
                     'object_owner','object_size','object_delete','attachment_before','attachment_after'):
            for order in ('mutation_first', 'finalizer_first'):
                runner.case(mode + ' ' + order, lambda n=number, m=mode, o=order: runner.mutation_race(n, m, o))
                number += 1
        for old_first in (True, False):
            runner.case('old writer overlap ' + ('old first' if old_first else 'finalizer first'),
                        lambda n=number, o=old_first: runner.overlap(n, o))
            number += 1
        runner.case('old writer still denies unattached object', lambda: runner.old_unattached_denial(number))
        runner.report['function_catalog_after'] = runner.catalog()
        runner.report['finalizer_catalog_after'] = runner.finalizer_catalog()
        if runner.report['function_catalog_before'] != runner.report['function_catalog_after'] or runner.report['finalizer_catalog_before'] != runner.report['finalizer_catalog_after']:
            raise AssertionError('RPC metadata changed during data-only schedules')
        runner.report['completed'] = True
    except Exception as error:
        runner.report.update(completed=False, error=type(error).__name__ + ': ' + str(error))
        print('FAIL ' + runner.report['error'], flush=True)
    finally:
        runner.close()
    return 0 if runner.report.get('completed') and not runner.report['cleanup_errors'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
