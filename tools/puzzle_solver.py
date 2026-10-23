#!/usr/bin/env python3
"""Deterministic Sokoban reference rules and lexicographic optimal solver.

No third-party packages. Costs minimize pushes first, then player steps. A result
is exhaustive only when status='solved' or 'unsolvable'; budget exhaustion is
never reported as unsolvability. Coordinates use x right / y down.
"""
from __future__ import annotations
import argparse
from collections import deque
from dataclasses import dataclass
import heapq
import json
from pathlib import Path
from typing import Iterable

DIRS = (("U", (0, -1)), ("D", (0, 1)), ("L", (-1, 0)), ("R", (1, 0)))
VECTORS = dict(DIRS)
Pos = tuple[int, int]
State = tuple[Pos, tuple[Pos, ...]]


def add(a: Pos, b: Pos) -> Pos:
    return a[0] + b[0], a[1] + b[1]


@dataclass
class Level:
    data: dict

    def __post_init__(self):
        d = self.data
        self.width, self.height = int(d["width"]), int(d["height"])
        self.walls = frozenset(map(tuple, d.get("walls", [])))
        self.floors = frozenset((x, y) for y in range(self.height)
                               for x in range(self.width)) - self.walls
        self.goals = frozenset(map(tuple, d["goals"]))
        self.initial: State = (tuple(d["player"]), tuple(sorted(map(tuple, d["crates"]))))
        self.mechanic = d.get("mechanic", {"type": "plain"})
        self.glide = frozenset(map(tuple, d.get("glide", [])))
        self.portals = {}
        for a, b in d.get("portals", []):
            self.portals[tuple(a)] = tuple(b)
            self.portals[tuple(b)] = tuple(a)
        self.arrows = {tuple(a["cell"]): a["dir"] for a in d.get("arrows", [])}
        self.plates = frozenset(map(tuple, d.get("plates", [])))
        self.gates = frozenset(map(tuple, d.get("gates", [])))
        self.validate()

    def validate(self):
        if self.width <= 0 or self.height <= 0:
            raise ValueError("Board dimensions must be positive")
        if self.mechanic.get("type", "plain") not in ("plain", "terrain"):
            raise ValueError("Unsupported mechanic; solver must not silently ignore rules")
        player, crates = self.initial
        if player not in self.floors or any(c not in self.floors for c in crates):
            raise ValueError("Player/crate outside walkable board")
        if len(crates) != len(set(crates)) or player in crates:
            raise ValueError("Overlapping initial entities")
        if not self.goals <= self.floors or len(crates) != len(self.goals):
            raise ValueError("Need one distinct valid goal per crate")
        feature_cells = self.glide | set(self.portals) | set(self.arrows) | self.plates | self.gates
        if not feature_cells <= self.floors:
            raise ValueError("Terrain features must lie on valid floor")
        if any(direction not in VECTORS for direction in self.arrows.values()):
            raise ValueError("Arrow must specify U/D/L/R entry direction")
        portal_pairs = self.data.get("portals", [])
        if len(self.portals) != 2 * len(portal_pairs):
            raise ValueError("Portal endpoints must be distinct and paired uniquely")
        if self.glide & set(self.portals):
            raise ValueError("Glide and portal tiles cannot overlap")
        if self.gates and not self.plates:
            raise ValueError("Pressure gates require at least one plate")
        if not set(crates) & self.plates and (player in self.gates or set(crates) & self.gates):
            raise ValueError("Initial entities may not occupy closed pressure gates")

    def won(self, state: State) -> bool:
        return set(state[1]) == self.goals

    def step(self, state: State, action: str) -> tuple[State, int] | None:
        delta = VECTORS[action]
        player, crates_tuple = state
        crates = set(crates_tuple)
        gates_open = bool(crates & self.plates)

        def enter(cell):
            return (cell in self.floors and (cell not in self.gates or gates_open)
                    and (cell not in self.arrows or self.arrows[cell] == action))

        target = add(player, delta)
        if not enter(target):
            return None
        pushed = int(target in crates)
        if pushed:
            destination = add(target, delta)
            if not enter(destination) or destination in crates:
                return None
            while destination in self.glide:
                nxt = add(destination, delta)
                if not enter(nxt) or nxt in crates:
                    break
                destination = nxt
            if destination in self.portals:
                destination = self.portals[destination]
                if destination in crates or destination == target or not enter(destination):
                    return None
            crates.remove(target)
            crates.add(destination)
        if not crates & self.plates and (target in self.gates or crates & self.gates):
            return None
        return (target, tuple(sorted(crates))), pushed

    def static_dead_squares(self) -> frozenset[Pos]:
        """Reverse-pull reachability, sound for ordinary immovable-wall rules."""
        # Nonstandard motion may rescue a normal Sokoban dead square. Disable
        # static pruning for any terrain mechanic rather than risk false negatives.
        if self.glide or self.portals or self.arrows or self.gates:
            return frozenset()
        reachable = set(self.goals)
        queue = deque(self.goals)
        while queue:
            goal = queue.popleft()
            for _, delta in DIRS:
                old_box = add(goal, delta)
                old_pusher = add(old_box, delta)
                if old_box in self.floors and old_pusher in self.floors and old_box not in reachable:
                    reachable.add(old_box)
                    queue.append(old_box)
        return self.floors - reachable


def replay(level: Level, solution: str, state: State | None = None) -> dict:
    current = level.initial if state is None else state
    states = [current]
    pushes = 0
    for i, action in enumerate(solution):
        if action not in VECTORS:
            raise ValueError(f"Unknown action {action!r} at {i}")
        result = level.step(current, action)
        if result is None:
            raise ValueError(f"Illegal action {action} at {i}")
        current, pushed = result
        pushes += pushed
        states.append(current)
    return {"won": level.won(current), "pushes": pushes, "moves": len(solution), "states": states}


def relaxed_dead_squares(level: Level) -> frozenset[Pos]:
    """Sound optimistic one-box reachability for terrain boards.

    Gates and arrows are ignored, every glide prefix may stop (another box may
    serve as stopper), and portals may either teleport or stay. These relaxations
    only add possibilities. A square unable to reach any goal even here is dead.
    """
    reverse = {p: set() for p in level.floors}
    for source in level.floors:
        for _, delta in DIRS:
            behind = (source[0]-delta[0], source[1]-delta[1])
            if behind not in level.floors:
                continue
            target = add(source, delta)
            while target in level.floors:
                reverse[target].add(source)
                if target in level.portals:
                    reverse[level.portals[target]].add(source)
                if target not in level.glide:
                    break
                target = add(target, delta)
    reachable = set(level.goals)
    queue = list(reachable)
    while queue:
        for source in reverse[queue.pop()]:
            if source not in reachable:
                reachable.add(source)
                queue.append(source)
    return level.floors - reachable


def solve_macro(level: Level, max_states: int = 30000) -> dict:
    """Exact push-macro Dijkstra; walk BFS retains true shortest move tie-break.

    Player position is NOT collapsed to a reachable-region ID, since that would
    discard the movement tie-break and is invalid for directional root gates.
    """
    initial = level.initial
    dead = relaxed_dead_squares(level)
    base = {"solver": "push_macro_dijkstra_v2", "objective": "minimum pushes, then minimum moves",
            "counts_note": "One shortest walk retained per push; action-sequence multiplicity not counted."}
    if any(c in dead for c in initial[1]):
        return {**base, "status": "unsolvable", "expanded_states": 0, "discovered_states": 1}
    distance = {initial: (0, 0)}
    parent = {}
    queue = [(0, 0, initial)]
    expanded = 0
    while queue:
        pushes, moves, state = heapq.heappop(queue)
        if (pushes, moves) != distance[state]:
            continue
        if level.won(state):
            parts = []
            here = state
            while here != initial:
                here, part = parent[here]
                parts.append(part)
            solution = "".join(reversed(parts))
            check = replay(level, solution)
            assert check['won'] and (check['pushes'], check['moves']) == (pushes, moves)
            return {**base, "status": "solved", "pushes": pushes, "moves": moves, "solution": solution,
                    "expanded_states": expanded, "discovered_states": len(distance), "replay_verified": True}
        if expanded >= max_states:
            return {**base, "status": "budget_exhausted", "expanded_states": expanded,
                    "discovered_states": len(distance), "max_states": max_states}
        expanded += 1
        player, crates = state
        occupied = set(crates)
        # Shortest non-pushing walks under the actual directed/gated rules.
        walk = {player: ""}
        frontier = deque([player])
        while frontier:
            current = frontier.popleft()
            for action, delta in DIRS:
                target = add(current, delta)
                if target in occupied or target in walk:
                    continue
                outcome = level.step((current, crates), action)
                if outcome is not None:
                    walk[target] = walk[current] + action
                    frontier.append(target)
        for crate in crates:
            for action, delta in DIRS:
                behind = (crate[0]-delta[0], crate[1]-delta[1])
                if behind not in walk:
                    continue
                outcome = level.step((behind, crates), action)
                if outcome is None:
                    continue
                nxt, pushed = outcome
                assert pushed
                if any(c in dead for c in nxt[1]):
                    continue
                part = walk[behind] + action
                cost = (pushes+1, moves+len(part))
                if cost < distance.get(nxt, (10**9, 10**9)):
                    distance[nxt] = cost
                    parent[nxt] = (state, part)
                    heapq.heappush(queue, (*cost, nxt))
    return {**base, "status": "unsolvable", "expanded_states": expanded, "discovered_states": len(distance)}


def solve(level: Level, max_states: int = 1000000, prune_deadlocks: bool = True) -> dict:
    """Dijkstra on full player+box states, cost=(pushes,moves).

    Counts equal-cost shortest action sequences (capped at 1e9), not alternative
    strategic solutions. Walk permutations may produce many equivalent routes.
    """
    initial = level.initial
    dead = level.static_dead_squares() if prune_deadlocks else frozenset()
    distance = {initial: (0, 0)}
    counts = {initial: 1}
    parent = {}
    queue = [(0, 0, initial)]
    expanded = 0
    rejected_deadlocks = 0
    best_cost = None
    winners = []
    while queue:
        pushes, moves, state = heapq.heappop(queue)
        cost = (pushes, moves)
        if cost != distance.get(state):
            continue
        if best_cost is not None and cost > best_cost:
            break
        if level.won(state):
            best_cost = cost
            winners.append(state)
            continue
        if expanded >= max_states:
            return {"status": "budget_exhausted", "expanded_states": expanded,
                    "discovered_states": len(distance), "max_states": max_states}
        expanded += 1
        for action, _ in DIRS:
            result = level.step(state, action)
            if result is None:
                continue
            nxt, pushed = result
            if pushed and any(c in dead for c in nxt[1]):
                rejected_deadlocks += 1
                continue
            next_cost = (pushes + pushed, moves + 1)
            previous = distance.get(nxt)
            if previous is None or next_cost < previous:
                distance[nxt] = next_cost
                counts[nxt] = counts[state]
                parent[nxt] = (state, action)
                heapq.heappush(queue, (*next_cost, nxt))
            elif next_cost == previous:
                counts[nxt] = min(1000000000, counts[nxt] + counts[state])
    base = {"expanded_states": expanded, "discovered_states": len(distance),
            "rejected_static_deadlocks": rejected_deadlocks,
            "static_dead_squares": sorted(dead), "objective": "minimum pushes, then minimum moves"}
    if not winners:
        return {"status": "unsolvable", **base}
    state = winners[0]
    route = []
    while state != initial:
        state, action = parent[state]
        route.append(action)
    solution = "".join(reversed(route))
    check = replay(level, solution)
    assert check["won"] and (check["pushes"], check["moves"]) == best_cost
    return {"status": "solved", **base, "pushes": best_cost[0], "moves": best_cost[1],
            "solution": solution, "optimal_action_sequences_capped": min(1000000000, sum(counts[s] for s in winners)),
            "replay_verified": True}


def from_ascii(rows: Iterable[str], **metadata) -> dict:
    rows = list(rows)
    width = max(map(len, rows))
    data = dict(width=width, height=len(rows), walls=[], crates=[], goals=[], **metadata)
    players = []
    for y, row in enumerate(rows):
        for x, char in enumerate(row.ljust(width, "#")):
            pos = [x, y]
            if char == "#": data["walls"].append(pos)
            if char in "$*": data["crates"].append(pos)
            if char in ".*+": data["goals"].append(pos)
            if char in "@+": players.append(pos)
    if len(players) != 1:
        raise ValueError("ASCII board must contain one player")
    data["player"] = players[0]
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("levels", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--max-states", type=int, default=1000000)
    parser.add_argument("--engine", choices=("macro", "full"), default="macro")
    args = parser.parse_args()
    data = json.loads(args.levels.read_text())
    levels = data if isinstance(data, list) else data.get("levels", [data])
    engine = solve_macro if args.engine == "macro" else solve
    results = [{"id": raw.get("id", str(i)), **engine(Level(raw), args.max_states)} for i, raw in enumerate(levels)]
    report = {"solver": "push_macro_dijkstra_v2" if args.engine == "macro" else "full_step_dijkstra_v1", "all_solved": all(r["status"] == "solved" for r in results),
              "levels": results,
              "limitations": ["Shortest-path metrics do not establish human enjoyment or insight difficulty.",
                              "Optimal sequence count includes equivalent player walks.",
                              "Only static dead squares are pruned; dynamic multi-box deadlocks remain in search."]}
    output = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(output + "\n")
    print(output)
    raise SystemExit(0 if report["all_solved"] else 1)


if __name__ == "__main__":
    main()
