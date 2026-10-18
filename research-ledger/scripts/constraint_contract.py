"""Independent pure-data constraint oracle. It does not execute SQL or emulate MySQL."""
from __future__ import annotations
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation
from typing import Any

class Violation(ValueError):
    def __init__(self, code: str):
        self.code=code
        super().__init__(code)

def require(condition: bool, code: str) -> None:
    if not condition: raise Violation(code)

def amount(value: Any) -> Decimal:
    try:
        x=Decimal(str(value));require(x.is_finite(),'finite_amount');return x
    except (ValueError,TypeError,InvalidOperation):raise Violation('finite_amount') from None

def find(fixture: dict, table: str, key: str, value: Any) -> dict:
    row=next((r for r in fixture['tables'][table] if r[key]==value),None)
    require(row is not None,'foreign_key')
    return row

def validate_row(fixture: dict, table: str, row: dict) -> None:
    r=row
    if table=='Driver':
        n,s,avg=r['rating_count'],r['rating_sum'],r['avg_rating']
        require(isinstance(n,int) and isinstance(s,int) and n>=0,'rating_summary')
        if n==0:require(s==0 and avg is None,'rating_summary')
        else:
            require(n<=s<=5*n and avg is not None,'rating_summary')
            expected=(Decimal(s)/Decimal(n)).quantize(Decimal('.01'),rounding=ROUND_HALF_UP)
            require(amount(avg)==expected,'rating_summary')
    elif table=='order':
        vehicle=find(fixture,'Vehicle','vehicle_id',r['vehicle_id'])
        require(vehicle['customer_id']==r['customer_id'],'vehicle_owner')
        require(r['scheduled_start']>=r['request_time'] and (r['completed_at'] is None or r['completed_at']>=r['scheduled_start']) and (r['cancelled_at'] is None or r['cancelled_at']>=r['request_time']),'order_time')
        require((r['status']=='completed')==(r['completed_at'] is not None) and (r['status']=='cancelled')==(r['cancelled_at'] is not None),'order_state')
    elif table=='Assignment':
        order=find(fixture,'order','order_id',r['order_id']);find(fixture,'Driver','driver_id',r['driver_id'])
        require(r['assign_time']>=order['request_time'],'assignment_request_time')
        require((r['start_time'] is None or r['start_time']>=r['assign_time']) and (r['end_time'] is None or r['start_time'] is not None and r['end_time']>=r['start_time']),'assignment_time')
        if r['outcome']=='successful':require(r['start_time'] is not None and r['end_time'] is not None and order['status']=='completed' and order['completed_at']==r['end_time'],'successful_completion')
        before,after=r['odometer_before'],r['odometer_after']
        require(before is None and after is None or before is not None and after is not None and before>=0 and after>=before,'odometer')
    elif table=='Payment':
        order=find(fixture,'order','order_id',r['order_id'])
        quote,fee,refund=amount(r['quoted_fee']),r['final_fee'],amount(r['refund_amount'])
        require(quote>=0 and (fee is None or amount(fee)>=0) and refund>=0 and (refund==0 or fee is not None and refund<=amount(fee)),'payment_amount')
        paid,refunded=r['payment_time'],r['refund_time']
        require(r['status']=='pending' and fee is None and paid is None and refund==0 and refunded is None or r['status']=='paid' and fee is not None and paid is not None and refund==0 and refunded is None or r['status']=='refunded' and fee is not None and paid is not None and refund>0 and refunded is not None and refunded>=paid,'payment_state')
        require(paid is None or paid>=order['request_time'],'settlement_request_time')
    elif table=='Rating':
        a=find(fixture,'Assignment','assignment_id',r['assignment_id'])
        require(isinstance(r['stars'],int) and 1<=r['stars']<=5,'rating_stars')
        require(a['outcome']=='successful' and a['end_time'] is not None and r['rated_at']>=a['end_time'],'rating_time')
    elif table=='ParkingCustody':
        a=find(fixture,'Assignment','assignment_id',r['assignment_id'])
        require(r['check_in_time']>=a['assign_time'],'custody_time')
        require(amount(r['liability_limit'])>=0 and (r['fee'] is None or amount(r['fee'])>=0) and (r['check_out_time'] is None or r['check_out_time']>=r['check_in_time']),'custody_fields')
    elif table=='Reimbursement':
        a=find(fixture,'Assignment','assignment_id',r['assignment_id'])
        require(r['submit_time']>=a['assign_time'],'reimbursement_time')
        require(amount(r['claimed_amount'])>=0 and (r['approve_time'] is None or r['approve_time']>=r['submit_time']) and (r['status']!='approved' or r['approve_time'] is not None),'reimbursement_fields')

def validate_change(fixture: dict, table: str, old: dict, new: dict | None) -> None:
    if new is None:
        require(not(table=='Assignment' and old['outcome']=='successful'),'successful_delete')
        require(not(table=='Payment' and old['payment_time'] is not None),'settlement_delete')
        return
    if table=='Assignment':
        if old['outcome']=='successful':
            keys=['assignment_id','driver_id','order_id','outcome','assign_time','start_time','end_time']
            require(all(new[k]==old[k] for k in keys),'successful_immutable')
        require(not any(c['assignment_id']==old['assignment_id'] and c['check_in_time']<new['assign_time'] for c in fixture['tables']['ParkingCustody']) and not any(c['assignment_id']==old['assignment_id'] and c['submit_time']<new['assign_time'] for c in fixture['tables']['Reimbursement']),'dependent_event_time')
    elif table=='order':
        aa=[a for a in fixture['tables']['Assignment'] if a['order_id']==old['order_id']]
        if aa:require(all(new[k]==old[k] for k in ['order_id','customer_id','vehicle_id','request_time','scheduled_start']),'assigned_order_immutable')
        if any(a['outcome']=='successful' for a in aa):require(new['status']==old['status'] and new['completed_at']==old['completed_at'],'completed_order_immutable')
        require(not any(p['order_id']==old['order_id'] and p['payment_time'] is not None and p['payment_time']<new['request_time'] for p in fixture['tables']['Payment']),'request_settlement_time')
    elif table=='Payment':
        require(new['payment_id']==old['payment_id'] and new['order_id']==old['order_id'],'payment_identity')
        if old['payment_time'] is not None:require(new['payment_time']==old['payment_time'] and new['final_fee']==old['final_fee'],'settlement_immutable')
        if old['refund_time'] is not None:require(new['refund_time']==old['refund_time'] and new['refund_amount']==old['refund_amount'],'refund_immutable')
    elif table in {'ParkingCustody','Reimbursement','Rating'}:
        require(new['assignment_id']==old['assignment_id'],'assignment_identity')
    validate_row(fixture,table,new)

def validate_fixture(fixture: dict) -> None:
    for table in ['Driver','order','Assignment','Payment','Rating','ParkingCustody','Reimbursement']:
        for row in fixture['tables'][table]:validate_row(fixture,table,row)
    successful=[a for a in fixture['tables']['Assignment'] if a['outcome']=='successful']
    require(len({a['order_id'] for a in successful})==len(successful),'unique_successful_service')
    for order in fixture['tables']['order']:
        if order['status']=='completed':require(sum(a['order_id']==order['order_id'] for a in successful)==1,'completed_service_required')
