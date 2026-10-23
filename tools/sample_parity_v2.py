#!/usr/bin/env python3
"""Bounded off-solution reachable-state samples for V2 Godot/Python parity."""
from pathlib import Path
import sys,json,random,collections
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from puzzle_solver import Level,VECTORS
rng=random.Random(472204);cases=[]
for d in json.loads((ROOT/'assets/levels.json').read_text())['levels']:
 l=Level(d);seen={l.initial};q=collections.deque([l.initial])
 while q and len(seen)<800:
  s=q.popleft()
  for a in VECTORS:
   r=l.step(s,a)
   if r and r[0]not in seen:seen.add(r[0]);q.append(r[0])
 for s in rng.sample(sorted(seen),min(20,len(seen))):
  for a in VECTORS:
   r=l.step(s,a);cases.append({'level_id':d['id'],'player':s[0],'crates':s[1],'action':a,'expected':r[0]if r else None})
(ROOT/'tests/independent_cases_v2.json').write_text(json.dumps(cases,separators=(',',':'))+'\n')
print('V2 parity fixtures',len(cases))
