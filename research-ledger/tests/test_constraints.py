"""New synthetic mutation checks. SQL enforcement remains unexecuted."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from constraint_contract import Violation, amount, validate_change, validate_fixture, validate_row

F=json.loads((ROOT/'data/fixtures.json').read_text())
PRIMARY={'Driver':'driver_id','order':'order_id','Assignment':'assignment_id','Payment':'payment_id','ParkingCustody':'custody_id','Reimbursement':'reimbursement_id'}

class ConstraintTests(unittest.TestCase):
    def test_current_fixture_satisfies_new_contract_without_mutation(self):
        before=copy.deepcopy(F);validate_fixture(F);self.assertEqual(F,before)

    def test_32_synthetic_mutations_and_positive_controls(self):
        cases=json.loads((ROOT/'data/constraint-cases.json').read_text())['cases']
        self.assertEqual(len(cases),32)
        for case in cases:
            with self.subTest(case=case['name']):
                old=next(r for r in F['tables'][case['table']] if r[PRIMARY[case['table']]]==case['row_id'])
                new={**old,**case['patch']} if case['operation']!='delete' else None
                action=(lambda:validate_row(F,case['table'],new)) if case['operation']=='row' else (lambda:validate_change(F,case['table'],old,new))
                if case['expected']=='accept':action()
                else:
                    with self.assertRaises(Violation) as caught:action()
                    self.assertEqual(caught.exception.code,case['code'])

    def test_nonfinite_or_invalid_amounts_rejected(self):
        for value in [float('nan'),float('inf'),None,'bad']:
            with self.subTest(value=str(value)),self.assertRaises(Violation):amount(value)

    def test_trigger_row_references_names_and_event_scopes(self):
        schema=(ROOT/'sql/00_schema.sql').read_text()
        tables={name:set(re.findall(r'^\s{4}`?(\w+)`?\s+(?:INT|VARCHAR|TEXT|ENUM|DATETIME|DECIMAL|YEAR)\b',body,re.M)) for name,body in re.findall(r'CREATE TABLE\s+`?(\w+)`?\s*\((.*?)\) ENGINE\s*=\s*InnoDB;',schema,re.S)}
        sql=(ROOT/'sql/20_trigger.sql').read_text()
        triggers=re.findall(r'CREATE TRIGGER (\w+) (BEFORE|AFTER) (INSERT|UPDATE|DELETE) ON `?(\w+)`? FOR EACH ROW\s+BEGIN\s+(.*?)\nEND\$\$',sql,re.S)
        self.assertEqual(len(triggers),16)
        self.assertEqual({t[0] for t in triggers},set(re.findall(r'DROP TRIGGER IF EXISTS (\w+);',sql)))
        for name,_,event,table,body in triggers:
            with self.subTest(trigger=name):
                refs=set(re.findall(r'(?:NEW|OLD)\.(\w+)',body))
                self.assertLessEqual(refs,tables[table])
                if event=='INSERT':self.assertNotRegex(body,r'OLD\.')
                if event=='DELETE':self.assertNotRegex(body,r'NEW\.')

if __name__=='__main__':unittest.main()
