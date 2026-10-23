#!/usr/bin/env python3
"""Re-solve the complete shipped campaign and verify its quality contracts."""
import json
import time
from collections import Counter
from pathlib import Path
from puzzle_solver import Level, solve_macro, replay
from generate_levels import AvoidLevel
from generate_campaign import transformed_fingerprint, WORLDS, KINDS
from finalize_campaign import skeleton_fingerprint

ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'assets/levels.json').read_text())
levels=data['levels'];reports=json.loads((ROOT/'tests/solver_report.json').read_text())['levels']
errors=[];records=[];started=time.time()
assert len(levels)==204 and len(reports)==204
assert Counter(d['world'] for d in levels)=={**{w:50 for w in WORLDS},'confluence':4}
fingerprints=[transformed_fingerprint(d) for d in levels[:200]]
assert len(set(fingerprints))==200
assert len({(d['world'],skeleton_fingerprint(d)) for d in levels[:200]})==200
for world in WORLDS:
    subset=[d for d in levels if d['world']==world]
    assert Counter(d['chapter'] for d in subset)=={c:5 for c in range(1,11)}
    for chapter in range(1,11):
        costs=[(d['par_pushes'],d['par_moves']) for d in subset if d['chapter']==chapter]
        assert [c[0] for c in costs]==sorted(c[0] for c in costs),(world,chapter,costs)
        assert (costs[1:] if chapter==1 else costs)==sorted(costs[1:] if chapter==1 else costs),(world,chapter,costs)
for raw,saved in zip(levels,reports):
    level=Level(raw)
    fresh=solve_macro(level,max_states=50000)
    assert fresh['status']=='solved',raw['id']
    assert (fresh['pushes'],fresh['moves'])==(saved['pushes'],saved['moves']),raw['id']
    checked=replay(level,saved['solution'])
    assert checked['won'] and json.loads(json.dumps(checked['states']))==saved['states']
    comparisons={}
    for kind in ('glide','portals','arrows','gates'):
        if not raw.get(kind):continue
        bypass=solve_macro(AvoidLevel(raw,kind),max_states=50000)
        comparisons[kind]={k:bypass[k] for k in ('status','pushes','moves') if k in bypass}
        valid=bypass['status']=='unsolvable' or (bypass['status']=='solved' and bypass['pushes']>=fresh['pushes']+3)
        if raw['world']=='confluence':valid=bypass['status']=='unsolvable'
        assert valid,(raw['id'],kind,bypass)
    records.append({'id':raw['id'],'pushes':fresh['pushes'],'moves':fresh['moves'],
                    'expanded_states':fresh['expanded_states'],'bypass':comparisons})
    if len(records)%25==0:print('VALIDATED',len(records),flush=True)
output={'version':2,'levels_validated':len(records),'errors':errors,'symmetry_unique':200,
        'same_world_skeleton_unique':200,'chapter_push_order_nondecreasing':True,'first_authored_tutorial_kept_first':True,
        'wall_seconds':round(time.time()-started,2),'levels':records}
(ROOT/'tests/results').mkdir(exist_ok=True)
(ROOT/'tests/results/campaign_validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
print('CAMPAIGN_VALIDATED',len(records),'errors',len(errors),'seconds',output['wall_seconds'])
