import io
import json
from pathlib import Path, PureWindowsPath
import unittest
from unittest.mock import patch

from tool.ci.check_tour_test_count import selected_passes


class TourTestCountTests(unittest.TestCase):
    def setUp(self):
        self.repo = Path.cwd()
        self.paths = ('test/one_test.dart', 'test/two_test.dart')

    def count(self, events):
        report = '\n'.join(json.dumps(event) for event in events).encode()
        return selected_passes(io.BytesIO(report), repo=self.repo, paths=self.paths)

    def report(self):
        events = [
            {'type': 'suite', 'suite': {'id': 1, 'path': self.paths[0]}},
            {'type': 'suite', 'suite': {'id': 2, 'path': (self.repo / self.paths[1]).as_uri()}},
            {'type': 'suite', 'suite': {'id': 3, 'path': 'test/unrelated_test.dart'}},
        ]
        for test_id, suite_id, hidden, skipped in (
            (11, 1, False, False),
            (12, 1, True, False),
            (13, 2, False, False),
            (14, 2, False, True),
            (15, 3, False, False),
        ):
            events.extend((
                {'type': 'testStart', 'test': {'id': test_id, 'suiteID': suite_id}},
                {'type': 'testDone', 'testID': test_id, 'result': 'success',
                 'hidden': hidden, 'skipped': skipped},
            ))
        return events + [{'type': 'done', 'success': True}]

    def test_counts_only_selected_ordinary_passes(self):
        self.assertEqual(self.count(self.report()), 2)

        windows_root = PureWindowsPath('D:/Workspace/Syrius')
        events = self.report()
        events[0]['suite']['path'] = r'test\One_test.dart'
        events[1]['suite']['path'] = (windows_root / 'TEST/TWO_TEST.DART').as_uri()
        with patch.object(Path, 'resolve', return_value=windows_root):
            self.assertEqual(self.count(events), 2)

    def test_refuses_missing_suites_and_incomplete_events(self):
        events = self.report()
        for invalid in (events[1:], events[:-1], events[:-2] + events[-1:]):
            with self.subTest(events=len(invalid)), self.assertRaises(ValueError):
                self.count(invalid)
