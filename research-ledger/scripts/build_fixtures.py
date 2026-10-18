#!/usr/bin/env python3
"""Build reviewed synthetic counterexamples from the preserved coursework fixture."""
from __future__ import annotations
import json
import re
from pathlib import Path
from datetime import datetime, timedelta

ROOT = Path(__file__).resolve().parents[1]
CLOCK = datetime(2025, 11, 15, 12)


def parse_original(text: str) -> dict[str, list[dict]]:
    data: dict[str, list[dict]] = {}
    for match in re.finditer(r'INSERT INTO\s+(`?\w+`?)\s*\((.*?)\)\s*VALUES\s*(.*?);', text, re.S):
        name, cols, body = match.groups()
        columns = [c.strip().strip('`') for c in cols.split(',')]
        rows = data.setdefault(name.strip('`'), [])
        for row in re.findall(r'\(([^()]*)\)', body):
            tokens = re.findall(r"'(?:[^']|'')*'|NULL|-?\d+(?:\.\d+)?", row)
            assert len(tokens) == len(columns), (name, row)
            values = [None if t == 'NULL' else t[1:-1].replace("''", "'") if t.startswith("'") else float(t) if '.' in t else int(t) for t in tokens]
            rows.append(dict(zip(columns, values)))
    return data


def stamp(value: datetime) -> str:
    return value.strftime('%Y-%m-%d %H:%M:%S')


def build() -> dict:
    data = parse_original((ROOT / 'data/original_seed.sql').read_text())
    for row in data['Vehicle']:
        row['registered_at'] = '2025-01-01 00:00:00'
    for order in data['order']:
        successes = [a for a in data['Assignment'] if a['order_id'] == order['order_id'] and a['outcome'] == 'successful']
        order['completed_at'] = successes[0]['end_time'] if order['status'] == 'completed' else None
        order['cancelled_at'] = '2025-11-04 10:30:00' if order['status'] == 'cancelled' else None
    for driver in data['Driver']:
        driver['avg_rating'] = None
        driver['rating_count'] = 0
        driver['rating_sum'] = 0
    for rating in data['Rating']:
        a = next(a for a in data['Assignment'] if a['assignment_id'] == rating['assignment_id'])
        rating['rated_at'] = stamp(datetime.fromisoformat(a['end_time']) + timedelta(minutes=10))
    for payment in data['Payment']:
        payment['refund_amount'] = 0
        payment['refund_time'] = None
    for incident in data['Incident']:
        order = next(o for o in data['order'] if o['order_id'] == incident['order_id'])
        incident['recorded_at'] = stamp(datetime.fromisoformat(order['completed_at']) + timedelta(minutes=15))
    data['Driver'].append(dict(driver_id=7, name='Driver 007', phone='555-0113', cert_id='TEST-LIC-007', status='active', avg_rating=None, rating_count=0, rating_sum=0))
    data['Brandmodel'].append(dict(id=9, name='Model Gamma Empty', parent_id=3))
    # A second report on the same order must not count as a second affected order.
    data['Incident'].append(dict(incident_id=6, order_id=2, reporter='driver', category='unsafe driving', description='Synthetic duplicate-event counterexample.', severity=4, resolution='Teaching fixture only.', recorded_at='2025-11-12 23:20:00'))
    # A known future incident must not leak into the reporting cutoff.
    data['Incident'].append(dict(incident_id=7, order_id=3, reporter='customer', category='vehicle damage', description='Synthetic future-event counterexample.', severity=5, resolution='Teaching fixture only.', recorded_at='2025-11-16 12:00:00'))
    # Reassignment with a failed first attempt tests order-grain attribution.
    data['Assignment'].append(dict(assignment_id=100, order_id=2, driver_id=7, assign_time='2025-11-12 20:01:00', start_time=None, end_time=None, odometer_before=None, odometer_after=None, vehicle_condition_before=None, vehicle_condition_after=None, outcome='refused'))
    scenarios = []

    def add(oid: int, label: str, end: datetime, *, request: datetime | None = None, driver: int = 7, paid: datetime | None = None, refund: datetime | None = None, refund_amount: float = 0, missing_payment: bool = False, distance: int | None = 20, rating: int | None = None, rating_time: datetime | None = None, completed: bool = True) -> None:
        start = end - timedelta(minutes=50)
        request = request or start - timedelta(minutes=30)
        data['order'].append(dict(order_id=oid, customer_id=5, vehicle_id=7, pickup_location='Zone E Gate', dropoff_location='Zone Boundary Hub', request_time=stamp(request), scheduled_start=stamp(start-timedelta(minutes=5)), service_type='drive_now', status='completed' if completed else 'cancelled', completed_at=stamp(end) if completed else None, cancelled_at=None if completed else stamp(start)))
        data['Assignment'].append(dict(assignment_id=oid, order_id=oid, driver_id=driver, assign_time=stamp(request+timedelta(minutes=1)), start_time=stamp(start) if completed else None, end_time=stamp(end) if completed else None, odometer_before=1000 if distance is not None else None, odometer_after=1000+distance if distance is not None else None, vehicle_condition_before='Synthetic case.', vehicle_condition_after='Synthetic case.', outcome='successful' if completed else 'refused'))
        if not missing_payment:
            data['Payment'].append(dict(payment_id=oid, order_id=oid, quoted_fee=100, final_fee=100 if paid else None, method='credit card', payment_time=stamp(paid) if paid else None, status='refunded' if refund else 'paid' if paid else 'pending', refund_amount=refund_amount, refund_time=stamp(refund) if refund else None))
        if rating:
            data['Rating'].append(dict(rating_id=oid, assignment_id=oid, stars=rating, content='Synthetic boundary rating.', rated_at=stamp(rating_time or end+timedelta(minutes=10))))
        scenarios.append(dict(order_id=oid, purpose=label, synthetic=True))

    add(16, 'Missing payment record; visible as unknown billing state', CLOCK-timedelta(days=2), missing_payment=True)
    add(17, 'Exactly 24 hours old; strict older-than excludes it', CLOCK-timedelta(hours=24))
    add(18, '24 hours plus one second; includes it', CLOCK-timedelta(hours=24, seconds=1))
    add(19, 'Exactly seven days old; lower bound includes it', CLOCK-timedelta(days=7))
    add(20, 'Seven days plus one second; outside window', CLOCK-timedelta(days=7, seconds=1))
    add(21, 'Future settlement and rating cannot leak into as-of results', CLOCK-timedelta(days=2), paid=CLOCK+timedelta(hours=1), rating=1, rating_time=CLOCK+timedelta(hours=2))
    add(22, 'Future refund must leave full as-of settlement visible', CLOCK-timedelta(days=3), paid=CLOCK-timedelta(days=3)+timedelta(minutes=1), refund=CLOCK+timedelta(days=1), refund_amount=100, rating=5)
    add(23, 'Full refund before cutoff; excludes positive-net repeat purchase', CLOCK-timedelta(days=4), paid=CLOCK-timedelta(days=4)+timedelta(minutes=1), refund=CLOCK-timedelta(days=1), refund_amount=100)
    add(24, 'Partial refund; reports net settlement separately', CLOCK-timedelta(days=5), paid=CLOCK-timedelta(days=5)+timedelta(minutes=1), refund=CLOCK-timedelta(days=1), refund_amount=40)
    add(25, 'Zero km is measured zero, not missing', CLOCK-timedelta(days=2, hours=1), paid=CLOCK-timedelta(days=2, hours=1)+timedelta(minutes=1), distance=0, rating=4)
    add(26, 'Unknown km stays NULL and raises coverage gap', CLOCK-timedelta(days=2, hours=2), paid=CLOCK-timedelta(days=2, hours=2)+timedelta(minutes=1), distance=None)
    add(27, 'Old request but recent completion; service clock is completion', CLOCK-timedelta(days=2, hours=3), request=CLOCK-timedelta(days=40), paid=CLOCK-timedelta(days=2, hours=3)+timedelta(minutes=1))
    add(28, 'Future completion excluded despite current completed status', CLOCK+timedelta(hours=2), request=CLOCK-timedelta(hours=2), paid=CLOCK+timedelta(hours=3))
    add(29, 'Old completed service, recent cash; cash and service cohorts differ', CLOCK-timedelta(days=40), paid=CLOCK-timedelta(days=1), driver=1)
    add(30, 'Cancelled request cannot become an unpaid completed service', CLOCK-timedelta(days=2), completed=False)
    add(31, 'Exactly 30-day service lower bound includes it', CLOCK-timedelta(days=30), paid=CLOCK-timedelta(days=30)+timedelta(minutes=1))
    add(32, 'One second before 30-day lower bound excludes service cohort', CLOCK-timedelta(days=30, seconds=1), paid=CLOCK-timedelta(days=30)+timedelta(minutes=1))
    add(33, 'Unrated driver with a completed service keeps NULL average', CLOCK-timedelta(days=1), paid=CLOCK-timedelta(hours=23), driver=6)
    return {'meta':{'dataset':'synthetic-boundaries-v2', 'synthetic':True, 'as_of':stamp(CLOCK), 'timezone':'Asia/Hong_Kong', 'currency':'CNY', 'distance_unit':'km', 'origin':'coursework fixture plus deliberately constructed counterexamples', 'limitations':['No real customer or operating data.', 'A single settlement and at most one refund event per order.', 'Current membership tier; no historical tier inference.']}, 'tables':data, 'scenarios':scenarios}


def sql_value(value: object) -> str:
    if value is None: return 'NULL'
    if isinstance(value, str): return "'" + value.replace("'", "''") + "'"
    return str(value)


def main() -> None:
    data = build()
    (ROOT/'data/fixtures.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
    chunks=['-- Generated synthetic fixtures. Edit scripts/build_fixtures.py, then regenerate.', 'SET NAMES utf8mb4;', "SET time_zone = '+08:00';", 'START TRANSACTION;']
    for name, rows in data['tables'].items():
        columns=list(rows[0])
        for row in rows:
            assert list(row)==columns, (name,row)
            chunks.append(f"INSERT INTO `{name}` ({', '.join('`'+c+'`' for c in columns)}) VALUES ({', '.join(sql_value(row[c]) for c in columns)});")
    chunks.append('COMMIT;')
    (ROOT/'sql/01_seed.sql').write_text('\n'.join(chunks)+'\n')
    print('Built synthetic fixture:', ', '.join(f'{name}={len(rows)}' for name,rows in data['tables'].items()))

if __name__=='__main__': main()
