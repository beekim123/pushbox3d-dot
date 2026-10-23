#!/usr/bin/env python3
"""V2: 200 original puzzles from authored topology families and explicit lessons.

Checkpointed per-world search; no downloaded levels. All accepted puzzles carry
exact push/move solutions, retained-rule mechanic-bypass evidence and symmetry
fingerprints. Run --limit 5 for the 20-level review slice, then --limit 50.
"""
from __future__ import annotations
import argparse
from collections import deque
from concurrent.futures import ProcessPoolExecutor, as_completed
import copy
import hashlib
import json
from pathlib import Path
import random
import time
from puzzle_solver import Level, DIRS, VECTORS, add, solve_macro, relaxed_dead_squares, replay
from generate_levels import AvoidLevel, use_counts, remove_kind, tutorial

ROOT=Path(__file__).resolve().parents[1]
PARTS=ROOT/'tests/campaign_parts'
WORLDS=('heaven','inferno','rainforest','city')
KINDS=dict(zip(WORLDS,('glide','portals','arrows','gates')))

# '.' is playable floor, '#' is structure. These are authored architectural
# patterns, not independent random wall scatter. Symmetry/rotation is never used
# as a way of creating extra accepted levels.
PATTERNS={
 'court_a':['######','#....#','#....#','#....#','######'],
 'court_b':['#######','#.....#','#.....#','#.....#','#######'],
 'corner_a':['#######','##....#','#.....#','#....##','#######'],
 'corner_b':['######','#....#','#....#','##...#','##...#','######'],
 'pond_a':['#######','#.....#','#..#..#','#.....#','#.....#','#######'],
 'pond_b':['########','#......#','#..##..#','#......#','########'],
 'neck_a':['########','#...#..#','#......#','#...#..#','#...#..#','########'],
 'neck_b':['########','#..#...#','#..#...#','#......#','#..#...#','########'],
 'turn_a':['########','###....#','#......#','#...####','#......#','########'],
 'turn_b':['########','#......#','####...#','#......#','#....###','########'],
 'ring_a':['########','#......#','#..##..#','#..##..#','#......#','########'],
 'ring_b':['#######','#.....#','#.##..#','#.##..#','#.....#','#.....#','#######'],
 'stairs_a':['#########','###....##','##......#','#.......#','#......##','##....###','#########'],
 'stairs_b':['########','#....###','#.....##','##.....#','###....#','##.....#','########'],
 'rooms_a':['#########','#...#...#','#.......#','#...#...#','##.###.##','#.......#','#########'],
 'rooms_b':['########','#..#...#','#......#','#..##..#','#......#','#...#..#','########'],
 'gallery_a':['########','#......#','#..#...#','#......#','#...#..#','#......#','########'],
 'gallery_b':['#########','#.......#','#.##.##.#','#.......#','#...#...#','#########'],
 'weave_a':['#########','#...#...#','#.......#','##.###.##','#.......#','#...#...#','#########'],
 'weave_b':['########','#......#','#.#..#.#','#......#','#..##..#','#......#','########'],
}
FAMILIES=[('court_a','court_b'),('corner_a','corner_b'),('pond_a','pond_b'),('neck_a','neck_b'),
          ('turn_a','turn_b'),('ring_a','ring_b'),('stairs_a','stairs_b'),('rooms_a','rooms_b'),
          ('gallery_a','gallery_b'),('weave_a','weave_b')]

CHAPTERS={
 'heaven':['桃风初识','借枝停步','绕池寻位','花径窄口','回风转角','环园留路','三桃相会','隔圃传香','留白与次序','蟠桃归园'],
 'inferno':['炉门初访','出口让位','熔池绕行','双室穿梭','折廊换手','回炉取位','三焰同席','跨室调度','暂存与归槽','炉心盛宴'],
 'rainforest':['顺藤初行','从旁接近','绕根寻路','林隙让行','折枝回旋','环林留路','三果同归','树室分工','先后与回头','雨林合奏'],
 'city':['山桥初亮','留箱压桥','绕楼借路','两岸窄口','坡巷转折','环城通路','三厢协作','跨台调度','留路与次序','灯火归城'],
}
LESSONS={
 'heaven':['观察桃风滑道：果篮滑过后在普通土格停下。','先判断停靠点，再决定从哪一侧推动。','绕过桃池，从另一侧取位，不急于把篮子推到边缘。','狭窄花径需要给下一只果篮留出接近位置。','回折路径改变取位方向；先找停止格再出手。','环路可绕行，果篮却可能挡住自己的回路。','第三只果篮让暂存位置成为共享资源。','分区搬运，跨越连接口时保留两侧的取位空间。','先安排难回头的果篮，再填入容易到达的落点。','综合停靠、绕行与三篮次序，完成整园收获。'],
 'inferno':['箱子进入炉门后会出现在成对出口；旅人移到箱子原来的格子，不会随箱传送。','传送前看出口是否空着，并为后续推动留位置。','绕熔池找到传送后的接近方向。','双室不只要送进去，还要能接着推出来。','折廊中的接手位置比距离更重要。','利用环路重新接近已传送的箱子。','三只箱子共享取位空间；先留好炉门出口，再安排传送与归位次序。','跨室调度时先整理出口附近的落脚格。','临时停放与最终目标不同，先让路再归槽。','整合传送、接手与三箱次序，点亮炉心。'],
 'rainforest':['根门只允许沿箭头方向进入，必要时绕路。','到同一个格子也可能需要不同的接近方向。','绕过树根后再推动，别只盯住箱子到目标的直线。','窄口要为下一次合法入门留下通路。','先想清楚转弯后人能否站到箱子的另一边。','利用环林路径回到正确的入门方向。','三箱共同占用绕行空间，需要临时留白。','不同树室分配暂存箱子，连接口不能过早填满。','先完成最难取得推动位置的一箱。','综合方向、绕路与三箱先后，归还雨林果实。'],
 'city':['箱子压住灯板后桥门开启；按当前布局，让旅人或另一只箱子借桥通行。','先让一只箱子在兼作目标的灯板上停稳，再让旅人借桥绕到另一只箱子的推动位置。','绕楼寻找桥两侧的推动位置。','连接两岸的窄口必须留给箱子与旅人共同使用。','山巷转折时，先检查下一段桥是否仍然点亮。','环城绕路能换位，但别把唯一回路堵住。','第三只箱子带来压桥、暂存、运送三种分工。','跨台调度要处理桥前后的接近空间。','最后离开压板之前，确认没有实体留在关闭的桥上。','综合压桥、借路与三箱调度，点亮山城。'],
}
STAGES=('试探','换向','借位','留路','收束')


def transformed_fingerprint(raw):
    """D4 canonical full puzzle excluding player, so walk-start variants dedupe."""
    level=Level(raw)
    candidates=[]
    for mirror in (False,True):
        for rotation in range(4):
            def raw_t(p):
                x,y=p
                if mirror:x=-x
                for _ in range(rotation):x,y=-y,x
                return x,y
            f0=[raw_t(p) for p in level.floors]
            ox=min(x for x,y in f0);oy=min(y for x,y in f0)
            def t(p):
                x,y=raw_t(p);return [x-ox,y-oy]
            arrows=[]
            for pos,dir_ in level.arrows.items():
                v=raw_t(VECTORS[dir_])
                arrows.append([t(pos),next(k for k,v0 in DIRS if v0==v)])
            pairs=[]
            for a,b in raw.get('portals',[]):pairs.append(sorted([t(a),t(b)]))
            record=[sorted(t(p) for p in level.floors),sorted(t(p) for p in level.initial[1]),
                    sorted(t(p) for p in level.goals),sorted(t(p) for p in level.glide),sorted(arrows),
                    sorted(pairs),sorted(t(p) for p in level.plates),sorted(t(p) for p in level.gates)]
            candidates.append(json.dumps(record,separators=(',',':')))
    return hashlib.sha256(min(candidates).encode()).hexdigest()


def topology(name, variant):
    rows=PATTERNS[name];h=len(rows);w=len(rows[0])
    floors={(x,y) for y,row in enumerate(rows) for x,c in enumerate(row) if c=='.'}
    # At most one deliberately placed architectural post, never random scatter.
    if variant:
        choices=sorted(p for p in floors if all(add(p,d) in floors for _,d in DIRS))
        if choices:
            post=choices[(variant-1)%len(choices)]
            trial=floors-{post}
            seen={min(trial)};queue=list(seen)
            while queue:
                p=queue.pop()
                for _,d in DIRS:
                    q=add(p,d)
                    if q in trial and q not in seen:seen.add(q);queue.append(q)
            if seen==trial:floors=trial
    return w,h,floors


def make_candidate(rng, world, chapter, stage, attempt):
    kind=KINDS[world]
    family=FAMILIES[chapter-1]
    name=family[(attempt//25+stage)%2]
    w,h,floors=topology(name,(attempt//100)%5)
    ordered=sorted(floors)
    boxes=1 if chapter==1 and world!='city' else (3 if chapter>=7 else 2)
    raw={'width':w,'height':h,'walls':sorted({(x,y) for y in range(h) for x in range(w)}-floors),
         'mechanic':{'type':'terrain'},'topology':name,'structural_variant':(attempt//100)%5}
    free=list(ordered);rng.shuffle(free)
    if kind=='glide':
        # Short contiguous wind lanes, not unrelated isolated speckles.
        starts=[p for p in ordered if sum(add(p,d) in floors for _,d in DIRS)>=3]
        start=rng.choice(starts or ordered)
        delta=rng.choice(list(VECTORS.values()))
        raw['glide']=[start]
        q=add(start,delta)
        for _ in range(1 if chapter<4 else rng.randint(1,2)):
            if q in floors:raw['glide'].append(q);q=add(q,delta)
        if chapter>=6 and rng.random()<.4:
            extra=rng.choice(ordered)
            if extra not in raw['glide']:raw['glide'].append(extra)
    elif kind=='portals':
        a=rng.choice(ordered)
        distant=[b for b in ordered if abs(a[0]-b[0])+abs(a[1]-b[1])>=3]
        raw['portals']=[[a,rng.choice(distant or [p for p in ordered if p!=a])]]
    elif kind=='arrows':
        useful=[p for p in ordered if sum(add(p,d) in floors for _,d in DIRS)>=3]
        cell=rng.choice(useful or ordered)
        dirs=[a for a,d in DIRS if (cell[0]-d[0],cell[1]-d[1]) in floors]
        raw['arrows']=[{'cell':cell,'dir':rng.choice(dirs)}]
        if chapter>=5 and rng.random()<.35:
            other=rng.choice([p for p in ordered if p!=cell])
            dirs=[a for a,d in DIRS if (other[0]-d[0],other[1]-d[1]) in floors]
            if dirs:raw['arrows'].append({'cell':other,'dir':rng.choice(dirs)})
    else:
        degree={p:sum(add(p,d) in floors for _,d in DIRS) for p in floors}
        preferred=[p for p in ordered if degree[p] in (2,3)]
        raw['gates']=[rng.choice(preferred or ordered)]
        raw['plates']=[rng.choice([p for p in ordered if p not in raw['gates']])]
    feature=set(raw.get('glide',[]))|{p for pair in raw.get('portals',[]) for p in pair}|{a['cell'] for a in raw.get('arrows',[])}|set(raw.get('gates',[]))|set(raw.get('plates',[]))
    goal_pool=[p for p in ordered if p not in feature]
    if len(goal_pool)<boxes+2:return None
    raw['goals']=rng.sample(goal_pool,boxes)
    if kind=='gates' and rng.random()<.7:raw['goals'][0]=raw['plates'][0]
    # Use the relaxed reachability oracle before selecting crates. This is a
    # candidate-selection aid, not an unproved state-pruning assumption.
    raw['player']=goal_pool[0];raw['crates']=rng.sample([p for p in ordered if p!=raw['player'] and p not in raw.get('gates',[])],boxes)
    try:temp=Level(raw)
    except ValueError:return None
    viable=[p for p in ordered if p not in relaxed_dead_squares(temp) and p not in feature and p not in raw['goals']]
    if len(viable)<boxes:return None
    raw['crates']=rng.sample(viable,boxes)
    player_pool=[p for p in ordered if p not in raw['crates'] and p not in raw.get('gates',[])]
    raw['player']=rng.choice(player_pool)
    return raw


def first_tutorial(world):
    if world!='city':return tutorial(KINDS[world])
    rows=['########','#...#..#','#......#','#...#..#','########']
    floors={(x,y) for y,row in enumerate(rows) for x,c in enumerate(row) if c=='.'}
    return {'width':8,'height':5,'walls':sorted({(x,y) for y in range(5) for x in range(8)}-floors),
            'player':[1,3],'crates':[[2,3],[3,2]],'goals':[[3,3],[5,2]],'plates':[[3,3]],'gates':[[4,2]],'mechanic':{'type':'terrain'}}


def metadata(raw, world, order):
    chapter=(order-1)//5+1;stage=(order-1)%5+1
    label=CHAPTERS[world][chapter-1]
    raw.update(id=f'{world}_{order:02}',world=world,order=order,chapter=chapter,chapter_name=label,stage=stage,
               name=f'{label}·{STAGES[stage-1]}',tier=chapter,
               difficulty='引导' if chapter==1 else ('进阶' if chapter<=4 else '巧思' if chapter<=7 else '精研'),
               tutorial=order==1,learning_goal=LESSONS[world][chapter-1],
               stage_intent=['识别本章所需的关键取位','改变接近方向，避免直推惯性','利用暂存空格整理次序','为最后一箱保留退路','独立完成本章组合考验'][stage-1])
    raw.setdefault('topology','authored_tutorial')


def evaluate(raw, kind, minimum, maximum, budget, strict=True):
    try:level=Level(raw)
    except ValueError:return None,'invalid'
    result=solve_macro(level,max_states=budget)
    if result['status']!='solved':return None,result['status']
    if not minimum<=result['pushes']<=maximum or result['moves']>180:return None,'difficulty'
    uses=use_counts(level,result['solution'])
    if not uses[kind]:return None,'unused'
    bypass=solve_macro(AvoidLevel(raw,kind),max_states=max(2500,budget))
    if bypass['status']=='budget_exhausted':return None,'bypass_budget'
    if strict and bypass['status']=='solved' and bypass['pushes']<result['pushes']+3:return None,'cheap_bypass'
    result['mechanic_uses']=uses
    result['retained_rules_bypass_comparison']={kind:{k:bypass[k] for k in ('status','pushes','moves') if k in bypass}}
    result['bypass_exception']=bypass['status']=='solved'
    return result,'accepted'


def world_job(world, limit, resume=True):
    PARTS.mkdir(parents=True,exist_ok=True)
    path=PARTS/f'{world}.json'
    old=json.loads(path.read_text()) if resume and path.exists() else {'levels':[],'reports':[]}
    levels=old['levels'][:limit];reports=old['reports'][:limit]
    fingerprints={r['symmetry_fingerprint'] for r in reports}
    start=time.time()
    for order in range(len(levels)+1,limit+1):
        chapter=(order-1)//5+1;stage=(order-1)%5+1
        kind=KINDS[world]
        stats={};rng=random.Random(47020000+WORLDS.index(world)*100000+order*100)
        if order==1:
            raw=first_tutorial(world);report=solve_macro(Level(raw));report['mechanic_uses']=use_counts(Level(raw),report['solution'])
            a=solve_macro(AvoidLevel(raw,kind));report['retained_rules_bypass_comparison']={kind:{k:a[k] for k in ('status','pushes','moves') if k in a}}
            report['bypass_exception']=False
        else:
            minima=[1,3,4,5,6,7,8,9,10,11]
            minimum=minima[chapter-1]+(stage-1)//2
            if world=='city' and chapter==1:minimum=3+(stage-1)//2
            maximum=minimum+5
            budget=1200 if chapter<=3 else 1800 if chapter<=6 else 2600
            found=False
            for attempt in range(20000):
                raw=make_candidate(rng,world,chapter,stage,attempt)
                if raw is None:stats['invalid']=stats.get('invalid',0)+1;continue
                report,status=evaluate(raw,kind,minimum,maximum,budget,strict=True)
                stats[status]=stats.get(status,0)+1
                if report is None:continue
                fingerprint=transformed_fingerprint(raw)
                if fingerprint in fingerprints:stats['duplicate']=stats.get('duplicate',0)+1;continue
                found=True;break
            if not found:
                path.with_suffix('.blocked.json').write_text(json.dumps({'world':world,'order':order,'stats':stats},indent=2))
                raise RuntimeError(f'{world} order{order}: no quality candidate, {stats}')
        metadata(raw,world,order)
        fingerprint=transformed_fingerprint(raw);fingerprints.add(fingerprint)
        raw['par_pushes']=report['pushes'];raw['par_moves']=report['moves']
        report.update(id=raw['id'],symmetry_fingerprint=fingerprint,search_stats=stats,
                      states=replay(Level(raw),report['solution'])['states'])
        levels.append(raw);reports.append(report)
        path.write_text(json.dumps({'world':world,'levels':levels,'reports':reports},ensure_ascii=False,indent=2)+'\n')
        print(f"{world} {order:02}/50 chapter{chapter} {raw['topology']} boxes{len(raw['crates'])} {report['pushes']}p/{report['moves']}m states{report['expanded_states']} candidates{sum(stats.values())} elapsed{time.time()-start:.1f}s",flush=True)
    return world,len(levels)


def main():
    p=argparse.ArgumentParser();p.add_argument('--limit',type=int,default=5);p.add_argument('--workers',type=int,default=2)
    p.add_argument('--world',choices=['all',*WORLDS],default='all');p.add_argument('--fresh',action='store_true');args=p.parse_args()
    selected=WORLDS if args.world=='all' else (args.world,)
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        jobs=[pool.submit(world_job,w,args.limit,not args.fresh) for w in selected]
        for job in as_completed(jobs):print('COMPLETE',job.result(),flush=True)
    if args.world=='all':
        levels=[];reports=[]
        for world in WORLDS:
            d=json.loads((PARTS/f'{world}.json').read_text());levels+=d['levels'];reports+=d['reports']
        fingerprints=[r['symmetry_fingerprint'] for r in reports]
        assert len(fingerprints)==len(set(fingerprints)),'Cross-world duplicate'
        target=ROOT/'assets/campaign_preview.json'
        target.write_text(json.dumps({'version':2,'levels':levels},ensure_ascii=False,indent=2)+'\n')
        (ROOT/'tests/campaign_preview_report.json').write_text(json.dumps({'all_solved':True,'levels':reports},ensure_ascii=False,indent=2)+'\n')
        print('PREVIEW',len(levels),'levels',target,flush=True)


if __name__=='__main__':main()
