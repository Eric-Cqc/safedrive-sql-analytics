#!/usr/bin/env python3
"""Fail-closed verifier: fresh named _test schemas, explicit local socket, no drops."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from oracle import ROOT,analyze,compare_live
from constraint_contract import validate_fixture
from static_contract import check_schema


def validate_database(name: str) -> None:
    if not re.fullmatch(r'safedrive_[a-z0-9_]{1,40}_test',name):
        raise ValueError('Refusing target: expected safedrive_[a-z0-9_]{1,40}_test')


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database',required=True,help='Fresh disposable synthetic test schema; existing schemas are refused')
    parser.add_argument('--mysql-socket',required=True,type=Path,help='Explicit local socket; no TCP or default credentials')
    parser.add_argument('--mysql-user',default='root')
    parser.add_argument('--baseline-root',type=Path,help='Optional preserved baseline to reproduce in two additional fresh schemas')
    args=parser.parse_args()
    try:
        validate_database(args.database)
        if not re.fullmatch(r'[A-Za-z0-9_]+',args.mysql_user): raise ValueError('Unsafe user identifier')
    except ValueError as exc:
        print(exc,file=sys.stderr);return 64
    # Pure-data preflight precedes every connection or destination mutation.
    try:
        fixture=json.loads((ROOT/'data/fixtures.json').read_text())
        if fixture.get('meta',{}).get('synthetic') is not True:
            raise ValueError('Explicit synthetic fixture required')
        validate_fixture(fixture)
        check_schema((ROOT/'sql/00_schema.sql').read_text())
    except (ValueError,AssertionError,OSError) as exc:
        print(f'REFUSED: local fixture/schema preflight failed: {exc}',file=sys.stderr);return 64
    if shutil.disk_usage(ROOT).free < 5*1024**3:
        print('BLOCKED-DISK: free space below 5 GiB. No database modified.',file=sys.stderr);return 3
    mysql=shutil.which('mysql')
    if not mysql or not args.mysql_socket.is_absolute() or not args.mysql_socket.exists() or not stat.S_ISSOCK(args.mysql_socket.stat().st_mode):
        print('BLOCKED-DB: explicit local socket/client unavailable. No database modified.',file=sys.stderr);return 2
    cmd=[mysql,'--no-defaults','--no-login-paths','--protocol=SOCKET',f'--socket={args.mysql_socket}',f'--user={args.mysql_user}','--connect-timeout=3','--batch','--raw']
    def execute(sql: str, db: str | None=None) -> str:
        r=subprocess.run(cmd+([f'--database={db}'] if db else []),input=sql,text=True,capture_output=True,timeout=30)
        if r.returncode: raise RuntimeError(r.stderr.strip())
        return r.stdout
    try:
        version=execute('SELECT VERSION();').strip().splitlines()[-1]
    except (RuntimeError,subprocess.TimeoutExpired) as exc:
        print(f'BLOCKED-DB: {exc}',file=sys.stderr);return 2
    # The second suffix is separate and equally guarded. Never DROP a pre-existing schema.
    names=[args.database,args.database[:-5]+'_repeat_test']
    baseline_names=[args.database[:-5]+'_baseline_test',args.database[:-5]+'_baseline2_test'] if args.baseline_root else []
    if any(len(name)>64 for name in names+baseline_names): print('Database name too long',file=sys.stderr);return 64
    try:
        for name in names+baseline_names:
            validate_database(name)
            exists=execute(f"SELECT SCHEMA_NAME FROM information_schema.schemata WHERE SCHEMA_NAME='{name}';")
            if exists.strip().splitlines()[1:]:
                print(f'REFUSED: {name} already exists. No mutation performed.',file=sys.stderr);return 64
        output=ROOT/'results'
        with tempfile.TemporaryDirectory(prefix='safedrive-results-') as temp:
            staging=Path(temp)
            traces=[]
            def run(source: Path, databases: list[str], upgraded: bool) -> list[Path]:
                dirs=[]
                for index,name in enumerate(databases):
                    # CREATE races fail closed. Do not use IF NOT EXISTS.
                    execute(f'CREATE DATABASE `{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;')
                    traces.append({'schema':name,'created_fresh':True,'synthetic_only':True})
                    target=staging/name;target.mkdir();dirs.append(target)
                    for file in ['00_schema.sql','20_trigger.sql','01_seed.sql']+(['05_views.sql'] if upgraded else []):
                        execute((source/'sql'/file).read_text(),name)
                    # Trigger replacement itself is rerun and checked without reseeding.
                    execute((source/'sql/20_trigger.sql').read_text(),name)
                    for file in sorted((source/'sql/10_queries').glob('q*.sql')):
                        (target/(file.stem+'.tsv')).write_text(execute(file.read_text(),name))
                    execute((source/'sql/30_assertions.sql').read_text(),name)
                    if upgraded:
                        compare_live(target,analyze(json.loads((ROOT/'data/fixtures.json').read_text())))
                        for probe in [{'as_of':'2025-11-16 12:00:00'},{'grace_minutes':10},{'severity':5},{'service_days':7},{'purchase_months':1},{'as_of':'2025-11-15 13:00:00'}]:
                            changed=target/('probe_'+str(len(list(target.glob('probe_*')))));changed.mkdir()
                            prefix='\n'.join(f"SET @{k}="+(f"'{v}'" if isinstance(v,str) else str(v))+';' for k,v in probe.items())+'\n'
                            for file in sorted((source/'sql/10_queries').glob('q*.sql')):
                                (changed/(file.stem+'.tsv')).write_text(execute(prefix+file.read_text(),name))
                            compare_live(changed,analyze(json.loads((ROOT/'data/fixtures.json').read_text()),probe))
                    elif index==0:
                        for file in target.glob('q*.tsv'):
                            if file.read_bytes()!=(source/'results'/file.name).read_bytes(): raise RuntimeError('Baseline snapshot changed: '+file.name)
                for file in dirs[0].glob('q*.tsv'):
                    if file.read_bytes()!=(dirs[1]/file.name).read_bytes(): raise RuntimeError('Repeated output differs: '+file.name)
                return dirs
            if args.baseline_root: run(args.baseline_root.resolve(),baseline_names,False)
            dirs=run(ROOT,names,True)
            # Publish outputs only after the whole run and independent oracle pass.
            output.mkdir(exist_ok=True)
            for file in dirs[0].glob('q*.tsv'): shutil.copyfile(file,output/file.name)
            hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'sql').rglob('*.sql'))}
            hashes['data/fixtures.json']=hashlib.sha256((ROOT/'data/fixtures.json').read_bytes()).hexdigest()
            report={'status':'passed','engine':'MySQL','server_version':version,'fixture':'synthetic-boundaries-v2','clock':'2025-11-15 12:00:00 Asia/Hong_Kong','runs':2,'parameter_probes_per_run':6,'baseline_reproduced':bool(args.baseline_root),'schemas':traces,'source_sha256':hashes,'result_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.glob('q*.tsv'))},'limitations':['Single-server serial assertions; no production concurrency/load validation.']}
            (ROOT/'evidence/mysql-verification.json').write_text(json.dumps(report,indent=2)+'\n')
        print('PASS: two fresh synthetic MySQL schemas; ten queries, six parameter probes, rollback/constraint checks and oracle comparison. Existing schemas untouched.')
        return 0
    except (RuntimeError,AssertionError,subprocess.TimeoutExpired,OSError) as exc:
        print(f'FAIL: {exc}. Fresh created test schemas retained for inspection; result publication stopped.',file=sys.stderr)
        return 1

if __name__=='__main__': sys.exit(main())
