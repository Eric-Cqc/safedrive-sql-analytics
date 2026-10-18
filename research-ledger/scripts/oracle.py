#!/usr/bin/env python3
"""Independent, dependency-free row-level oracle; never a MySQL compatibility claim."""
from __future__ import annotations
import calendar
import csv
import json
from collections import defaultdict
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any

ROOT=Path(__file__).resolve().parents[1]


def dt(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


def rnd(value: Any, places: int=2) -> float | None:
    return float(Decimal(str(value)).quantize(Decimal(1).scaleb(-places),rounding=ROUND_HALF_UP)) if value is not None else None


def month_before(value: datetime, months: int) -> datetime:
    n=value.year*12+value.month-1-months
    year,month=divmod(n,12)
    month+=1
    return value.replace(year=year,month=month,day=min(value.day,calendar.monthrange(year,month)[1]))


def analyze(fixture: dict, options: dict | None=None) -> dict[str,list[dict]]:
    p={'as_of':fixture['meta']['as_of'],'severity':4,'incident_threshold':0.30,'service_days':30,'custody_days':14,'top_routes':5,'grace_minutes':0,'purchase_months':3,'unpaid_days':7,'overdue_hours':24}
    p.update(options or {})
    clock=dt(p['as_of']); assert clock
    t=fixture['tables']
    customers={c['customer_id']:c for c in t['Customer']}
    drivers={d['driver_id']:d for d in t['Driver']}
    assignments={a['assignment_id']:a for a in t['Assignment']}
    success={a['order_id']:a for a in t['Assignment'] if a['outcome']=='successful'}
    payments={a['order_id']:a for a in t['Payment']}
    ratings={r['assignment_id']:r for r in t['Rating']}
    evidence=[]
    for o in t['order']:
        a=success.get(o['order_id']); pay=payments.get(o['order_id']); r=ratings.get(a['assignment_id']) if a else None
        settled=bool(pay and dt(pay['payment_time']) and dt(pay['payment_time'])<clock)
        refunded=bool(pay and dt(pay['refund_time']) and dt(pay['refund_time'])<clock)
        km=a['odometer_after']-a['odometer_before'] if a and a['odometer_before'] is not None and a['odometer_after'] is not None else None
        evidence.append({**o,'assignment':a,'payment':pay,'rating':r,'net':(pay['final_fee'] if settled else 0)-(pay['refund_amount'] if refunded else 0),'payment_state':'missing' if not pay else 'pending' if not settled else 'refunded' if refunded else 'paid','km':km})
    done=[e for e in evidence if dt(e['completed_at']) and dt(e['completed_at'])<clock]
    ids=lambda rows: ','.join(str(e['order_id']) for e in sorted(rows,key=lambda e:e['order_id'])) or None
    known=lambda r: bool(r and dt(r['rated_at'])<clock)
    out: dict[str,list[dict]]={f'q{i:02}':[] for i in range(1,11)}
    for cid,c in customers.items():
        orders=[e for e in done if e['customer_id']==cid]; order_set={e['order_id'] for e in orders}
        inc=[i for i in t['Incident'] if i['order_id'] in order_set and dt(i['recorded_at'])<clock]
        hi=[i for i in inc if i['severity']>=p['severity']]; affected=len({i['order_id'] for i in hi})
        if orders and affected/len(orders)>=p['incident_threshold']:
            out['q01'].append(dict(customer_id=cid,customer_name=c['name'],completed_orders=len(orders),incident_events=len(inc),high_severity_events=len(hi),affected_orders=affected,order_ids=ids(orders),affected_order_rate=rnd(affected/len(orders),4)))
    lower=clock-timedelta(days=p['service_days'])
    for did,d in drivers.items():
        all_orders=[e for e in done if e['assignment'] and e['assignment']['driver_id']==did]
        cohort=[e for e in all_orders if dt(e['completed_at'])>=lower]
        cash=sum(e['payment']['final_fee'] for e in all_orders if e['payment'] and dt(e['payment']['payment_time']) and lower<=dt(e['payment']['payment_time'])<clock)
        refunds=sum(e['payment']['refund_amount'] for e in all_orders if e['payment'] and dt(e['payment']['refund_time']) and lower<=dt(e['payment']['refund_time'])<clock)
        kms=[e['km'] for e in cohort if e['km'] is not None]
        out['q02'].append(dict(driver_id=did,driver_name=d['name'],completed_orders=len(cohort),service_cohort_net_paid_asof=rnd(sum(e['net'] for e in cohort)),cash_collected_window=rnd(cash),refunds_window=rnd(refunds),measured_km=sum(kms) if kms else None,missing_km_orders=sum(e['km'] is None for e in cohort),order_ids=ids(cohort),net_cash_window=rnd(cash-refunds)))
    out['q02'].sort(key=lambda r:(-r['completed_orders'],-r['service_cohort_net_paid_asof'],r['driver_id']))
    groups: dict[tuple,list[dict]]=defaultdict(list)
    done_by_assignment={e['assignment']['assignment_id']:e for e in done if e['assignment']}
    for pc in t['ParkingCustody']:
        if pc['assignment_id'] in done_by_assignment and clock-timedelta(days=p['custody_days'])<=dt(pc['check_in_time'])<clock:
            e=done_by_assignment[pc['assignment_id']]; groups[(pc['partner_name'],e['pickup_location'],e['dropoff_location'])].append(e)
    partners=sorted({key[0] for key in groups})
    for partner in partners:
        routes=sorted([k for k in groups if k[0]==partner],key=lambda k:(-len({e['order_id'] for e in groups[k]}),k[1],k[2]))
        for rank,key in enumerate(routes[:p['top_routes']],1):
            unique={e['order_id']:e for e in groups[key]}
            out['q03'].append(dict(partner_name=partner,pickup_location=key[1],dropoff_location=key[2],order_count=len(unique),custody_episodes=len(groups[key]),order_ids=ids(list(unique.values())),route_rank=rank))
    for e in done:
        a=e['assignment']
        if not a: continue
        late=(dt(a['start_time'])-dt(e['scheduled_start'])).total_seconds()/60
        if late>p['grace_minutes']:
            near={aa['order_id'] for aa in t['Assignment'] if aa['driver_id']==a['driver_id'] and aa['order_id']!=e['order_id'] and aa['outcome']=='successful' and dt(aa['start_time']) and dt(e['scheduled_start'])-timedelta(hours=1)<=dt(aa['start_time'])<=dt(e['scheduled_start'])+timedelta(hours=1) and dt(aa['start_time'])<clock}
            out['q04'].append(dict(order_id=e['order_id'],scheduled_start=e['scheduled_start'],start_time=a['start_time'],late_minutes=rnd(late),driver_id=a['driver_id'],driver_name=drivers[a['driver_id']]['name'],other_nearby_orders=len(near),order_ids=e['order_id']))
    out['q04'].sort(key=lambda r:r['order_id'])
    for did,d in drivers.items():
        rr=[r for r in t['Rating'] if assignments[r['assignment_id']]['driver_id']==did]; kr=[r for r in rr if known(r)]
        avg=lambda rows: rnd(sum(r['stars'] for r in rows)/len(rows)) if rows else None
        out['q05'].append(dict(driver_id=did,driver_name=d['name'],current_summary_avg=avg(rr),current_summary_count=len(rr),current_recomputed_avg=avg(rr),current_recomputed_count=len(rr),asof_avg=avg(kr),asof_rating_count=len(kr),order_ids=','.join(str(x) for x in sorted(assignments[r['assignment_id']]['order_id'] for r in kr)) or None))
    for e in sorted(done,key=lambda e:(e['completed_at'],e['order_id']),reverse=True):
        if customers[e['customer_id']]['membership_tier']=='VIP':
            out['q06'].append(dict(customer_name=customers[e['customer_id']]['name'],**{k:e[k] for k in ['order_id','request_time','completed_at','pickup_location','dropoff_location','service_type']},payment_state_asof=e['payment_state'],net_paid_asof=rnd(e['net']),measured_km=e['km'],order_ids=e['order_id']))
    for service in sorted({e['service_type'] for e in done}):
        cohort=[e for e in done if e['service_type']==service]; stars=[e['rating']['stars'] for e in cohort if known(e['rating'])]
        out['q07'].append(dict(service_type=service,completed_orders=len(cohort),review_count=len(stars),review_coverage=rnd(len(stars)/len(cohort),4),avg_rating=rnd(sum(stars)/len(stars)) if stars else None,min_rating=min(stars) if stars else None,max_rating=max(stars) if stars else None,order_ids=ids(cohort)))
    out['q07'].sort(key=lambda r:(-(r['avg_rating'] or -1),r['service_type']))
    for cid,c in customers.items():
        cohort=[e for e in done if e['customer_id']==cid and month_before(clock,p['purchase_months'])<=dt(e['request_time'])<clock and e['net']>0]
        if len(cohort)>1:
            vehicles=len({e['vehicle_id'] for e in cohort})
            out['q08'].append(dict(customer_id=cid,customer_name=c['name'],membership_tier=c['membership_tier'],paid_orders=len(cohort),vehicle_count=vehicles,net_paid_asof=rnd(sum(e['net'] for e in cohort)),order_ids=ids(cohort),repeat_order_share=rnd((len(cohort)-1)/len(cohort),4),extra_vehicle_order_share=rnd((len(cohort)-vehicles)/len(cohort),4)))
    out['q08'].sort(key=lambda r:(-r['repeat_order_share'],r['customer_id']))
    brands={b['id']:b for b in t['Brandmodel']}
    for m in sorted([m for m in t['Brandmodel'] if m['parent_id']],key=lambda m:(m['parent_id'],m['id'])):
        fleet=sorted([v for v in t['Vehicle'] if v['model_id']==m['id'] and dt(v['registered_at'])<clock],key=lambda v:v['vehicle_id'])
        out['q09'].append(dict(brand_id=m['parent_id'],brand_name=brands[m['parent_id']]['name'],model_id=m['id'],model_name=m['name'],vehicle_count=len(fleet),vehicle_ids=','.join(str(v['vehicle_id']) for v in fleet) or None))
    for e in sorted(done,key=lambda e:(e['completed_at'],e['order_id'])):
        if clock-timedelta(days=p['unpaid_days'])<=dt(e['completed_at'])<clock-timedelta(hours=p['overdue_hours']) and e['payment_state'] in {'missing','pending'}:
            out['q10'].append(dict(order_id=e['order_id'],customer_id=e['customer_id'],customer_name=customers[e['customer_id']]['name'],completed_at=e['completed_at'],quoted_fee=e['payment']['quoted_fee'] if e['payment'] else None,payment_state_asof=e['payment_state'],hours_since_completion=rnd((clock-dt(e['completed_at'])).total_seconds()/3600,4),order_ids=e['order_id']))
    return out


def compare_live(directory: Path, expected: dict[str,list[dict]]) -> None:
    for q,rows in expected.items():
        with (directory/f'{q}.tsv').open() as f:
            reader=csv.DictReader(f,delimiter='\t'); actual=list(reader)
            # Parameter probes can legitimately return no rows. The default
            # fixture still supplies a stable column contract for that query.
            contract = rows or analyze(json.loads((ROOT/'data/fixtures.json').read_text()))[q]
            assert contract, f'{q} has no known column contract'
            assert reader.fieldnames==list(contract[0]), f'{q} header mismatch'
        assert len(rows)==len(actual),f'{q} rows: expected {len(rows)}, actual {len(actual)}'
        for i,(a,e) in enumerate(zip(actual,rows)):
            for k,v in e.items():
                value=a[k]
                if v is None: assert value=='NULL',(q,i,k,value,v)
                elif isinstance(v,(float,int)):
                    assert abs(Decimal(value)-Decimal(str(v)))<=Decimal('0.000001'),(q,i,k,value,v)
                else: assert value==str(v),(q,i,k,value,v)


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--candidate-dir',type=Path);args=p.parse_args()
    fixture=json.loads((ROOT/'data/fixtures.json').read_text()); result=analyze(fixture)
    if args.candidate_dir:
        compare_live(args.candidate_dir,result);print('PASS: ten candidate TSV tables match independent row-level oracle; engine provenance is separate')
    else:
        print(json.dumps(result,ensure_ascii=False,indent=2))
