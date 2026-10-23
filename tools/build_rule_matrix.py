#!/usr/bin/env python3
"""Build deterministic legal/illegal transition oracle for Godot parity testing."""
from collections import deque
import json
from pathlib import Path
import random
from puzzle_solver import Level, DIRS

ROOT=Path(__file__).resolve().parents[1]
levels=json.loads((ROOT/'assets/levels.json').read_text())['levels']
cases=[]
for raw in levels:
    level=Level(raw)
    queue=deque([level.initial]);seen={level.initial};states=[]
    while queue and len(states)<24:
        state=queue.popleft();states.append(state)
        for action,_ in DIRS:
            result=level.step(state,action)
            if result and result[0] not in seen:
                seen.add(result[0]);queue.append(result[0])
    rng=random.Random(raw['id']);current=level.initial
    collected=set(states)
    for i in range(1000):
        if i%37==0: current=level.initial
        options=[level.step(current,a) for a,_ in DIRS]
        options=[o for o in options if o]
        if not options:current=level.initial;continue
        current=rng.choice(options)[0]
        if current not in collected:
            collected.add(current);states.append(current)
        if len(states)>=48:break
    for state in states:
        expected={}
        for action,_ in DIRS:
            outcome=level.step(state,action)
            expected[action]=None if outcome is None else {'state':outcome[0],'pushed':outcome[1]}
        cases.append({'level':raw['id'],'state':state,'expected':expected})
output={'version':1,'cases':cases,'transition_count':4*len(cases)}
(ROOT/'tests/rules_matrix.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
print(f'{len(cases)} source states / {4*len(cases)} transitions')
