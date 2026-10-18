"""Synthetic oracle/static/safety tests. No MySQL execution is claimed."""
import contextlib
import io
import json
from pathlib import Path
import stat
import tempfile
import csv
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from oracle import analyze, compare_live, month_before
from static_contract import check_schema
from audit_public_tree import check_text
import verify_mysql
from datetime import datetime

F=json.loads((ROOT/'data/fixtures.json').read_text())
A=analyze(F)
def ids(q, **where):
    return {int(x) for row in A[q] if all(row.get(k)==v for k,v in where.items()) for x in str(row.get('order_ids') or '').split(',') if x}

class ContractTests(unittest.TestCase):
    def test_eighteen_named_boundary_cases(self):
        self.assertEqual(len(F['scenarios']),18)
        paid={p['order_id']:p for p in F['tables']['Payment']}
        assignments={a['order_id']:a for a in F['tables']['Assignment'] if a['outcome']=='successful'}
        rated={a['order_id'] for a in assignments.values() if any(r['assignment_id']==a['assignment_id'] for r in F['tables']['Rating'])}
        conditions={
          16:16 in ids('q10') and 16 not in paid,
          17:17 not in ids('q10'),18:18 in ids('q10'),19:19 in ids('q10'),20:20 not in ids('q10'),
          21:21 in ids('q10') and 21 not in ids('q05'),
          22:22 in ids('q08') and paid[22]['refund_time']>F['meta']['as_of'],
          23:23 not in ids('q08') and paid[23]['refund_amount']==paid[23]['final_fee'],
          24:24 in ids('q08') and 0<paid[24]['refund_amount']<paid[24]['final_fee'],
          25:assignments[25]['odometer_before']==assignments[25]['odometer_after'],
          26:assignments[26]['odometer_before'] is None and next(r for r in A['q02'] if r['driver_id']==7)['missing_km_orders']==1,
          27:27 in ids('q02'),28:28 not in ids('q07'),29:29 not in ids('q02'),30:30 not in ids('q07'),
          31:31 in ids('q02'),32:32 not in ids('q02'),33:33 in ids('q07') and 33 not in rated}
        for case in F['scenarios']:
            with self.subTest(order=case['order_id']):self.assertTrue(conditions[case['order_id']])

    def test_duplicate_incidents_are_distinct_orders(self):
        row=next(r for r in A['q01'] if r['customer_id']==1)
        self.assertEqual((row['high_severity_events'],row['affected_orders'],row['completed_orders']),(2,1,3))
        self.assertEqual(row['affected_order_rate'],.3333)

    def test_cash_and_service_cohorts_differ(self):
        row=next(r for r in A['q02'] if r['driver_id']==1)
        self.assertEqual(row['cash_collected_window']-row['service_cohort_net_paid_asof'],100)
        self.assertNotIn(29,ids('q02',driver_id=1))

    def test_rating_coverage_and_future_rating(self):
        row=next(r for r in A['q05'] if r['driver_id']==7)
        self.assertEqual((row['current_summary_count'],row['asof_rating_count']),(3,2))
        self.assertEqual((row['current_summary_avg'],row['asof_avg']),(3.33,4.5))
        self.assertEqual(next(r for r in A['q07'] if r['service_type']=='drive_now')['review_coverage'],.2)

    def test_zero_vehicle_model_stays_visible(self):
        row=next(r for r in A['q09'] if r['model_id']==9)
        self.assertEqual(row['vehicle_count'],0);self.assertIsNone(row['vehicle_ids'])

    def test_shifted_clock_changes_boundary(self):
        shifted=analyze(F,{'as_of':'2025-11-15 13:00:00'})
        self.assertIn(17,{r['order_id'] for r in shifted['q10']})
        self.assertNotIn(19,{r['order_id'] for r in shifted['q10']})

    def test_grace_is_strict_and_month_arithmetic_clamps(self):
        self.assertEqual({r['order_id'] for r in analyze(F,{'grace_minutes':10})['q04']},{4,8})
        self.assertEqual(month_before(datetime(2025,3,31),1),datetime(2025,2,28))

    def test_fixture_relationships_and_single_successful_assignment(self):
        t=F['tables'];owner={v['vehicle_id']:v['customer_id'] for v in t['Vehicle']}
        orders={o['order_id']:o for o in t['order']};successful=[a for a in t['Assignment'] if a['outcome']=='successful']
        self.assertEqual(len({a['order_id'] for a in successful}),len(successful))
        for o in orders.values():self.assertEqual(owner[o['vehicle_id']],o['customer_id'])
        for a in successful:self.assertEqual(a['end_time'],orders[a['order_id']]['completed_at'])

    def test_check_field_references_and_regression(self):
        source=(ROOT/'sql/00_schema.sql').read_text();self.assertEqual(check_schema(source),11)
        bad=source.replace('CREATE TABLE Payment (','CREATE TABLE Payment (\n    CONSTRAINT bad CHECK (liability_limit >= 0),')
        with self.assertRaises(AssertionError):check_schema(bad)

    def test_database_identifier_guard(self):
        for name in ['mysql','safedrive_production','safedrive_test;DROP DATABASE mysql','safedrive_a`_test','x_test','safedrive_'+'a'*41+'_test']:
            with self.subTest(name=name),self.assertRaises(ValueError):verify_mysql.validate_database(name)
        verify_mysql.validate_database('safedrive_task23_20261002_test')

    def test_existing_schema_refused_before_any_create(self):
        calls=[]
        def execute(cmd,**kw):
            calls.append(kw['input'])
            if kw['input']=='SELECT VERSION();':return SimpleNamespace(returncode=0,stdout='VERSION()\nmock-version\n',stderr='')
            return SimpleNamespace(returncode=0,stdout='SCHEMA_NAME\nsafedrive_existing_test\n',stderr='')
        argv=['verify_mysql.py','--database','safedrive_existing_test','--mysql-socket','/tmp/mock-safedrive.sock']
        with patch.object(sys,'argv',argv),patch.object(verify_mysql.shutil,'which',return_value='mock-mysql'),patch.object(Path,'exists',return_value=True),patch.object(Path,'stat',return_value=SimpleNamespace(st_mode=stat.S_IFSOCK)),patch.object(verify_mysql.subprocess,'run',side_effect=execute),contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(verify_mysql.main(),64)
        self.assertTrue(all(sql.startswith('SELECT ') for sql in calls))

    def test_empty_parameter_results_keep_column_contract(self):
        empty=analyze(F,{'incident_threshold':1,'grace_minutes':60})
        self.assertEqual(empty['q01'],[]);self.assertEqual(empty['q04'],[])
        with tempfile.TemporaryDirectory(prefix='safedrive-oracle-test-') as temp:
            path=Path(temp)
            for q,rows in empty.items():
                with (path/f'{q}.tsv').open('w',newline='') as f:
                    w=csv.DictWriter(f,fieldnames=list(A[q][0]),delimiter='\t');w.writeheader()
                    w.writerows({k:'NULL' if v is None else v for k,v in row.items()} for row in rows)
            compare_live(path,empty)

    def test_audit_checks_phone_fields_without_hash_false_positives(self):
        errors=[];check_text(ROOT/'data/example.json',json.dumps({'sha256':'a'+('12345678'*8),'viewBox':'0 0 200 15','phone':'555-0101'}),errors)
        self.assertEqual(errors,[])
        check_text(ROOT/'data/example.json',json.dumps({'phone':''.join(str(i) for i in range(1,10))}),errors)
        self.assertTrue(errors)

    def test_built_reader_presets_equal_current_oracle(self):
        reader=json.loads((ROOT/'web/data/reader.json').read_text())
        self.assertEqual(reader['status'],'synthetic_python_oracle')
        self.assertEqual(len(reader['presets']),7)
        for preset in reader['presets']:
            self.assertEqual(preset['results'],analyze(F,preset['options']))
        self.assertEqual(reader['presets'][0]['results'],json.loads((ROOT/'evidence/oracle.json').read_text()))

if __name__=='__main__':unittest.main()
