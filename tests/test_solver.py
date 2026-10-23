"""Run: python3 -m unittest discover -s tests -v"""
import sys
from pathlib import Path
import unittest
import json
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from puzzle_solver import Level, from_ascii, replay, solve, solve_macro


class SolverTests(unittest.TestCase):
    def level(self, *rows):
        return Level(from_ascii(rows))

    def test_single_push(self):
        level = self.level("#####", "#@$.#", "#####")
        result = solve(level)
        self.assertEqual((result["pushes"], result["moves"], result["solution"]), (1, 1, "R"))

    def test_unsolvable_corner(self):
        level = self.level("#####", "#$@.#", "#   #", "#####")
        self.assertEqual(solve(level)["status"], "unsolvable")

    def test_budget_not_unsolvable(self):
        level = self.level("#####", "#@$.#", "#####")
        self.assertEqual(solve(level, max_states=0)["status"], "budget_exhausted")

    def test_won_initially(self):
        result = solve(self.level("#####", "#@* #", "#####"))
        self.assertEqual((result["pushes"], result["moves"]), (0, 0))

    def test_illegal_replay(self):
        with self.assertRaises(ValueError):
            replay(self.level("#####", "#@$.#", "#####"), "U")

    def test_two_crates_and_pruning_equivalence(self):
        level = self.level("#######", "# . . #", "# $ $ #", "#  @  #", "#######")
        a, b = solve(level), solve(level, prune_deadlocks=False)
        self.assertEqual((a["pushes"], a["moves"]), (b["pushes"], b["moves"]))
        self.assertTrue(replay(level, a["solution"])["won"])

    def test_unsupported_rule_rejected(self):
        data = from_ascii(["#####", "#@$.#", "#####"])
        data["mechanic"] = {"type": "unknown"}
        with self.assertRaises(ValueError):
            Level(data)

    def test_overlap_rejected(self):
        data = from_ascii(["#####", "#@$.#", "#####"])
        data["player"] = data["crates"][0]
        with self.assertRaises(ValueError):
            Level(data)

    def test_glide_stops_at_first_ordinary_cell(self):
        data = from_ascii(["########", "#@$   .#", "########"])
        data['glide'] = [[3,1],[4,1]]
        level=Level(data)
        state,pushed=level.step(level.initial,'R')
        self.assertEqual(state,((2,1),((5,1),)))
        self.assertEqual(pushed,1)

    def test_glide_stops_before_obstacle(self):
        data = from_ascii(["#######", "#@$  .#", "#######"])
        data['glide'] = [[3,1],[4,1],[5,1]]
        level=Level(data)
        self.assertEqual(level.step(level.initial,'R')[0][1],((5,1),))

    def test_player_does_not_glide(self):
        data = from_ascii(["#######", "#@  $.#", "#######"])
        data['glide'] = [[2,1],[3,1]]
        level=Level(data)
        self.assertEqual(level.step(level.initial,'R')[0][0],(2,1))

    def test_portal_resolves_once(self):
        data=from_ascii(["#######", "#@$   #", "#   . #", "#######"])
        data['portals']=[[[3,1],[4,2]]]
        level=Level(data)
        self.assertTrue(level.won(level.step(level.initial,'R')[0]))

    def test_portal_occupied_exit_rejects_whole_push(self):
        data=from_ascii(["#######", "#@$   #", "# ..$ #", "#######"])
        data['portals']=[[[3,1],[4,2]]]
        level=Level(data)
        self.assertIsNone(level.step(level.initial,'R'))

    def test_arrow_restricts_player_and_box_entry(self):
        data=from_ascii(["#######", "#@$  .#", "#     #", "#######"])
        data['arrows']=[{'cell':[3,1],'dir':'L'}]
        level=Level(data)
        self.assertIsNone(level.step(level.initial,'R'))
        self.assertIsNone(level.step(((3,2),((2,1),)),'U'))

    def test_pressure_pre_state_and_final_closure(self):
        data=from_ascii(["#######", "#@$  .#", "#     #", "#######"])
        data['plates']=[[2,1]]; data['gates']=[[3,1]]
        level=Level(data)
        # Starts open; box cannot leave the plate and remain on closed bridge.
        self.assertIsNone(level.step(level.initial,'R'))
        # Last plate must not be vacated if the player ends on the bridge.
        data['plates']=[[3,1]];data['gates']=[[2,1]]
        data['crates']=[[4,1]]
        level=Level(data)
        self.assertIsNone(level.step(((1,1),((2,1),)),'R'))

    def test_terrain_disables_unsound_static_deadlock_pruning(self):
        data=from_ascii(["#######", "#@$   #", "#   . #", "#######"])
        data['portals']=[[[3,1],[4,2]]]
        self.assertEqual(Level(data).static_dead_squares(),frozenset())

    def test_all_shipped_levels_exact_optimal_replay(self):
        root=Path(__file__).resolve().parents[1]
        if not (root/'assets/levels.json').exists(): self.skipTest('Levels not generated yet')
        campaign=json.loads((root/'assets/levels.json').read_text())
        levels=campaign['levels']
        reports=json.loads((root/'tests/solver_report.json').read_text())['levels']
        self.assertEqual(len(levels),204 if campaign.get('version',1)==2 else 16)
        for data,report in zip(levels,reports):
            with self.subTest(level=data['id']):
                level=Level(data)
                result=solve_macro(level)
                self.assertEqual(result['status'],'solved')
                self.assertEqual((result['pushes'],result['moves']), (report['pushes'],report['moves']))
                checked=replay(level,report['solution'])
                self.assertTrue(checked['won'])
                normalized=json.loads(json.dumps(checked['states']))
                self.assertEqual(normalized,report['states'])

    def test_macro_matches_full_step_reference(self):
        root=Path(__file__).resolve().parents[1]
        levels=json.loads((root/'assets/levels.json').read_text())['levels']
        selected=[d for d in levels if d.get('world')=='confluence' or d.get('order') in (1,5,25,50)]
        for raw in selected:
            with self.subTest(level=raw['id']):
                full=solve(Level(raw),max_states=1000000)
                macro=solve_macro(Level(raw),max_states=30000)
                self.assertEqual(full['status'],macro['status'])
                self.assertEqual((full['pushes'],full['moves']),(macro['pushes'],macro['moves']))


if __name__ == "__main__":
    unittest.main()
