#!/usr/bin/env python3
"""Generate a portable synthetic reader from the current independent Python oracle."""
from pathlib import Path
import csv
import hashlib
import json
import shutil
from oracle import ROOT, analyze
from static_contract import check_schema
from constraint_contract import validate_fixture

PRESETS=[
 ('default','固定报告时点',{}),
 ('hour','时点后移 1 小时',{'as_of':'2025-11-15 13:00:00'}),
 ('day','时点后移 1 天',{'as_of':'2025-11-16 12:00:00'}),
 ('grace','迟到宽限 10 分钟',{'grace_minutes':10}),
 ('severity','严重事件阈值 5',{'severity':5}),
 ('service','服务窗口 7 天',{'service_days':7}),
 ('purchase','购买窗口 1 个月',{'purchase_months':1}),
]
QUERIES={
 'q01':('事件，还是受影响订单？','高严重度事件占哪些客户已完成订单的比例？','先按订单去重，再算受影响订单 / 完成订单。相同订单多个事件不重复抬高比例。','affected_order_rate'),
 'q02':('服务与现金，是两本账。','司机服务队列和窗口现金收付如何不同？','按完成时间选服务队列；现金按支付/退款时点选窗口。仅成功派单归属收入，重派不重复记账。里程为里程表差值。','net_cash_window'),
 'q03':('路线频次，按订单数。','每个保管合作方最常见的路线是什么？','不同订单是路线频次的单位；保管次数另列。平局按起终点稳定排序，不推断地理距离。','order_count'),
 'q04':('迟到，需要明确基准。','完成服务中哪些开始时间严格超过宽限？','实际开始与预约开始比较，超过才纳入。附近派单只显示时间邻近，不能据此断言因果。','late_minutes'),
 'q05':('现在知道，不等于当时知道。','评价汇总与重算是否一致？报告时点知道哪些评价？','当前汇总和 as-of 均值分别呈现；未来评价不泄漏到报告时点。插入、更新、删除触发器及回滚已在 MySQL 9.7.1 合成测试库验证。','asof_avg'),
 'q06':('VIP 身份，限于当前。','当前 VIP 客户有哪些已完成订单？','成员等级没有历史表，不能称作服务当日 VIP。支付状态与净收款根据报告时点判断。','net_paid_asof'),
 'q07':('均分之外，还看覆盖。','服务类型的评价均值在多大覆盖率下形成？','评价均值仅来自已知评价；分母是已完成订单。无评价是 NULL，不应填成零分或等同低质量。','review_coverage'),
 'q08':('复购，不等于车辆复用。','哪些客户发生多次正净结算购买？','完成、请求窗口、已结算和正净额共同筛选；全额退款排除。额外订单占比与车辆复用占比分开。','repeat_order_share'),
 'q09':('零辆，也是一条信息。','报告时点已登记车辆如何分布到品牌型号？','保留零车辆型号；只统计时点前登记的车辆。此问的证据是车辆，不能套用订单数。','vehicle_count'),
 'q10':('一秒，可以改变边界。','七天内完成且严格超过24小时的服务，哪些仍未结算？','按完成时间判断；七天边界包含，恰好24小时排除。缺失支付记录与待支付分开，未来支付尚不算结算。','hours_since_completion'),
}

def build() -> None:
    if shutil.disk_usage(ROOT).free<5*1024**3:raise SystemExit('STOP: disk below 5 GiB')
    check_schema((ROOT/'sql/00_schema.sql').read_text())
    fixture=json.loads((ROOT/'data/fixtures.json').read_text())
    validate_fixture(fixture)
    verification=json.loads((ROOT/'evidence/mysql-verification.json').read_text())
    if verification.get('status')!='passed':
        raise SystemExit('Live verification required before building a verified reader')
    for relative,expected in verification['source_sha256'].items():
        if hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()!=expected:
            raise SystemExit('Stale MySQL verification: '+relative)
    for name,expected in verification['result_sha256'].items():
        if hashlib.sha256((ROOT/'results'/name).read_bytes()).hexdigest()!=expected:
            raise SystemExit('Changed MySQL output: '+name)
    source={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for base in ['sql','scripts','data'] for p in sorted((ROOT/base).rglob('*')) if p.is_file() and '__pycache__' not in p.parts}
    payload={'schema':1,'status':'synthetic_python_oracle','mysql_status':'passed: MySQL 9.7.1; two fresh schemas; ten queries and six parameter probes per run',
        'fixture':fixture,'queries':{k:{'title':v[0],'question':v[1],'contract':v[2],'metric':v[3],
            'sql':(ROOT/f'sql/10_queries/{k}.sql').read_text(),'legacy_tsv':(ROOT/f'evidence/legacy-results/{k}.tsv').read_text()} for k,v in QUERIES.items()},
        'presets':[{'key':k,'name':n,'options':p,'results':analyze(fixture,p)} for k,n,p in PRESETS],
        'source_sha256':source,'evidence_note':'Python-derived expected rows, not MySQL query outputs. No real operating records.'}
    web=ROOT/'web';(web/'data').mkdir(parents=True,exist_ok=True)
    text=json.dumps(payload,ensure_ascii=False,separators=(',',':'))+'\n';(web/'data/reader.json').write_text(text)
    # Expected TSVs remain separate from future live results/.
    target=ROOT/'evidence/python-expected';target.mkdir(exist_ok=True)
    for q,rows in payload['presets'][0]['results'].items():
        with (target/f'{q}.tsv').open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]),delimiter='\t',lineterminator='\n');w.writeheader();w.writerows({k:'NULL' if v is None else v for k,v in row.items()} for row in rows)
    html=(web/'index.html').read_text().replace('<link rel="stylesheet" href="styles.css">','<style>'+(web/'styles.css').read_text()+'</style>').replace('<script src="app.js" defer></script>','')
    html=html.replace('</body>','<script type="application/json" id="reader-data">'+text.replace('<','\\u003c')+'</script><script>'+(web/'app.js').read_text()+'</script></body>')
    (web/'reader.html').write_text(html)
    report={'status':'generated','kind':'Python oracle; independently compared with MySQL 9.7.1','preset_count':len(PRESETS),'query_result_sets':len(PRESETS)*10,'fixture_orders':33,'boundary_cases':18,'reader_json_sha256':hashlib.sha256(text.encode()).hexdigest(),'source_sha256':source}
    (ROOT/'evidence/reader-build.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Built {len(PRESETS)} presets / 70 Python-derived query tables; reader {len(html.encode())} bytes')

if __name__=='__main__':build()
