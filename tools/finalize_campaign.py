#!/usr/bin/env python3
"""Quality gate, factual intent annotation, chapter ordering and V2 assembly."""
import copy
import json
from pathlib import Path
import random
from collections import Counter
from puzzle_solver import Level, DIRS, VECTORS, add, solve_macro, replay
from generate_levels import AvoidLevel, use_counts, transition_uses
from generate_campaign import ROOT, PARTS, WORLDS, KINDS, CHAPTERS, LESSONS, make_candidate, evaluate, metadata, transformed_fingerprint


def facts(raw, report):
    level=Level(raw);state=level.initial
    identities={p:i for i,p in enumerate(state[1])}
    dirs=[set() for _ in state[1]]
    f={'boxes':len(state[1]),'slide_pushes':0,'teleports':0,'box_stopper_uses':0,
       'player_arrow_entries':0,'box_arrow_entries':0,'gate_passages':0,'goal_retrievals':0}
    for action in report['solution']:
        outcome=level.step(state,action);new,pushed=outcome
        events=transition_uses(level,state,action)
        if new[0] in level.arrows:f['player_arrow_entries']+=1
        if events['gates']:f['gate_passages']+=1
        if pushed:
            old_box=add(state[0],VECTORS[action]);new_box=next(iter(set(new[1])-set(state[1])))
            index=identities.pop(old_box);identities[new_box]=index;dirs[index].add(action)
            if old_box in level.goals:f['goal_retrievals']+=1
            if events['glide']:f['slide_pushes']+=1
            f['teleports']+=events['portals']
            if events['arrows']-(1 if new[0] in level.arrows else 0)>0:f['box_arrow_entries']+=1
            target=add(old_box,VECTORS[action])
            while target in level.glide:
                nxt=add(target,VECTORS[action])
                if nxt in state[1]:f['box_stopper_uses']+=1;break
                if nxt not in level.floors or (nxt in level.gates and not set(state[1])&level.plates) or (nxt in level.arrows and level.arrows[nxt]!=action):break
                target=nxt
        state=new
    f['boxes_requiring_multiple_push_directions']=sum(len(d)>1 for d in dirs)
    f['plate_is_goal']=bool(level.plates&level.goals)
    return f


def factual_intent(raw, report):
    f=facts(raw,report);world=raw['world'];n=f['boxes']
    opening='单箱练习：' if n==1 else f'{n}箱调度：'
    if world=='heaven':
        text=(f"参考路线含 {f['slide_pushes']} 次真实滑行，先认清滑道后的停靠格。")
        if f['box_stopper_uses']:text+='需要借另一只果篮作挡停点。'
        elif f['boxes_requiring_multiple_push_directions']:text+='果篮需要换方向推进，不能只沿一条直线。'
    elif world=='inferno':
        text=f"参考最优路线含 {f['teleports']} 次炉门转运；先为出口留出接手位置。"
        if f['goal_retrievals']:text+='有箱子会暂放目标后再取回，目标也能作暂存位。'
    elif world=='rainforest':
        role='玩家和箱子都要' if f['player_arrow_entries'] and f['box_arrow_entries'] else ('箱子要' if f['box_arrow_entries'] else '玩家要')
        text=f'{role}按箭头进入根门，先找合法的接近方向。'
        if f['boxes_requiring_multiple_push_directions']:text+='箱子转向后还需重新取位。'
    else:
        text='压板兼作目标，可让归位的箱子保持桥亮。' if f['plate_is_goal'] else '压板不是目标，运送完成后还要收回压桥箱。'
        text+=f"解法中有 {f['gate_passages']} 次桥格通行，要保留两侧的接近空间。"
    return opening+text,f


def repair_first_chapter(world, levels, reports, fingerprints):
    kind=KINDS[world]
    for i in range(1,5):
        r=reports[i];b=r['retained_rules_bypass_comparison'][kind]
        if b['status']=='unsolvable' or b.get('pushes',0)>=r['pushes']+3:continue
        order=i+1;stage=order
        rng=random.Random(47020000+WORLDS.index(world)*100000+order*100)
        minimum=1+(stage-1)//2 if world!='city' else 3+(stage-1)//2
        stats={}
        for attempt in range(20000):
            raw=make_candidate(rng,world,1,stage,attempt)
            if raw is None:continue
            report,status=evaluate(raw,kind,minimum,minimum+5,1200,strict=True)
            stats[status]=stats.get(status,0)+1
            if report is None:continue
            fingerprint=transformed_fingerprint(raw)
            if fingerprint in fingerprints:continue
            fingerprints.discard(r['symmetry_fingerprint']);fingerprints.add(fingerprint)
            metadata(raw,world,order)
            raw['par_pushes']=report['pushes'];raw['par_moves']=report['moves']
            report.update(id=raw['id'],symmetry_fingerprint=fingerprint,search_stats=stats,
                          states=replay(Level(raw),report['solution'])['states'])
            levels[i]=raw;reports[i]=report
            print('REPAIRED',raw['id'],report['pushes'],report['moves'],flush=True)
            break
        else:raise RuntimeError(f'No meaningful tutorial {world}/{order}')


def skeleton_fingerprint(raw):
    # Within a world, simply moving special paint on the identical crate/goal
    # skeleton is not accepted as another level.
    stripped={k:v for k,v in raw.items() if k not in ('glide','portals','arrows','plates','gates')}
    return transformed_fingerprint(stripped)


def repair_skeleton_duplicates(world, levels, reports):
    seen=set()
    occupied={skeleton_fingerprint(d) for d in levels}
    for i,raw in enumerate(levels):
        key=skeleton_fingerprint(raw)
        if key not in seen:
            seen.add(key);continue
        chapter=i//5+1;stage=i%5+1;kind=KINDS[world]
        rng=random.Random(48020000+WORLDS.index(world)*100000+(i+1)*100)
        original=reports[i]
        for attempt in range(20000):
            trial=make_candidate(rng,world,chapter,stage,attempt)
            if trial is None or skeleton_fingerprint(trial) in occupied:continue
            result,status=evaluate(trial,kind,max(2,original['pushes']-1),original['pushes']+2,3000,strict=True)
            if result is None:continue
            metadata(trial,world,i+1)
            result.update(id=trial['id'],symmetry_fingerprint=transformed_fingerprint(trial),
                          search_stats={'skeleton_duplicate_repair_attempts':attempt+1},
                          states=replay(Level(trial),result['solution'])['states'])
            levels[i]=trial;reports[i]=result
            new_key=skeleton_fingerprint(trial);occupied.add(new_key);seen.add(new_key)
            print('SKELETON_REPAIRED',trial['id'],result['pushes'],result['moves'],flush=True)
            break
        else:raise RuntimeError(f'Could not repair skeleton duplicate {world}/{i+1}')


def main():
    all_levels=[];all_reports=[]
    for world in WORLDS:
        path=PARTS/f'{world}.json';part=json.loads(path.read_text())
        levels=part['levels'];reports=part['reports'];assert len(levels)==50
        fingerprints={r['symmetry_fingerprint'] for r in reports}
        repair_first_chapter(world,levels,reports,fingerprints)
        repair_skeleton_duplicates(world,levels,reports)
        # Keep the explicit first teaching puzzle; order each five-level chapter
        # by the measured push/move workload, not candidate discovery order.
        ordered=[]
        for chapter in range(10):
            pairs=list(zip(levels[chapter*5:chapter*5+5],reports[chapter*5:chapter*5+5]))
            if chapter==0:pairs=pairs[:1]+sorted(pairs[1:],key=lambda p:(p[1]['pushes'],p[1]['moves']))
            else:pairs.sort(key=lambda p:(p[1]['pushes'],p[1]['moves']))
            ordered+=pairs
        levels=[];reports=[]
        for i,(raw,report) in enumerate(ordered):
            report.setdefault('generation_order',raw['order'])
            metadata(raw,world,i+1)
            raw['stage_intent'],report['design_facts']=factual_intent(raw,report)
            raw['par_pushes']=report['pushes'];raw['par_moves']=report['moves']
            report['id']=raw['id']
            levels.append(raw);reports.append(report)
        path.write_text(json.dumps({'world':world,'levels':levels,'reports':reports},ensure_ascii=False,indent=2)+'\n')
        all_levels+=levels;all_reports+=reports
    fingerprints=[r['symmetry_fingerprint'] for r in all_reports]
    assert len(set(fingerprints))==200,'Duplicate under D4 geometry/feature/state transform'
    # Keep V1's four independently verified two-mechanic bonus challenges.
    backup=ROOT/'tools/legacy_bonus.json'
    if not backup.exists():
        v1=json.loads((ROOT/'assets/levels.json').read_text())['levels']
        bonus=[d for d in v1 if d['world']=='confluence']
        assert len(bonus)==4
        backup.write_text(json.dumps(bonus,ensure_ascii=False,indent=2)+'\n')
    bonus=json.loads(backup.read_text())
    for i,raw in enumerate(bonus):
        raw.update(requires=200,chapter=1,chapter_name='四方回响',stage=i+1,tier=11,
                   learning_goal='综合两个世界的机制，任何一种都不能绕过。',stage_intent='两个机制都必须实际使用；先检查连接处的取位和退出空间。')
        report=solve_macro(Level(raw));assert report['status']=='solved'
        raw['par_pushes']=report['pushes'];raw['par_moves']=report['moves']
        report.update(id=raw['id'],symmetry_fingerprint=transformed_fingerprint(raw),mechanic_uses=use_counts(Level(raw),report['solution']),
                      states=replay(Level(raw),report['solution'])['states'])
        report['retained_rules_bypass_comparison']={}
        for kind in ('glide','portals','arrows','gates'):
            if raw.get(kind):
                b=solve_macro(AvoidLevel(raw,kind));assert b['status']=='unsolvable'
                report['retained_rules_bypass_comparison'][kind]={'status':'unsolvable'}
        all_levels.append(raw);all_reports.append(report)
    output={'version':2,'campaign_name':'四隅织途 · 蟠桃园与四方旅程','main_levels':200,'bonus_levels':4,'levels':all_levels}
    (ROOT/'assets/levels.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'tests/solver_report.json').write_text(json.dumps({'solver':'push_macro_dijkstra_v2','all_solved':True,'levels':all_reports},ensure_ascii=False,indent=2)+'\n')
    # Keep preview in sync as a concise representative first chapter per world.
    subset=[d for d in all_levels if d['world']!='confluence' and d['chapter']==1]
    ids={d['id'] for d in subset}
    (ROOT/'assets/campaign_preview.json').write_text(json.dumps({'version':2,'levels':subset},ensure_ascii=False,indent=2)+'\n')
    (ROOT/'tests/campaign_preview_report.json').write_text(json.dumps({'all_solved':True,'levels':[r for r in all_reports if r['id'] in ids]},ensure_ascii=False,indent=2)+'\n')
    summary={'main_levels':200,'bonus_levels':4,'world_counts':dict(Counter(d['world'] for d in all_levels)),
             'box_counts':dict(Counter(len(d['crates']) for d in all_levels[:200])),
             'topology_counts':dict(Counter(d['topology'] for d in all_levels[:200])),
             'symmetry_unique_main_levels':len(set(fingerprints)),
             'bypass_exceptions':[{'id':r['id'],'normal_pushes':r['pushes'],'comparison':r['retained_rules_bypass_comparison']} for r in all_reports[:200] if r.get('bypass_exception')],
             'total_solution_moves':sum(r['moves'] for r in all_reports),'total_expanded_macro_states':sum(r['expanded_states'] for r in all_reports)}
    (ROOT/'tests/campaign_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
