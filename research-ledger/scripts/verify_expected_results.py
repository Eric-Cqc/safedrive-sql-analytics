#!/usr/bin/env python3
"""Compare fresh MySQL outputs to an independent data oracle, not old snapshots."""
from pathlib import Path
import argparse,json
from oracle import ROOT,analyze,compare_live
p=argparse.ArgumentParser();p.add_argument('--candidate-dir',required=True,type=Path);a=p.parse_args()
compare_live(a.candidate_dir,analyze(json.loads((ROOT/'data/fixtures.json').read_text())))
print('PASS: ten candidate TSV tables match the independent Python oracle. This comparison alone is not MySQL execution evidence.')
