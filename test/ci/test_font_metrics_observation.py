"""Bound font metrics to the original finite fixture and reject private fields."""

import copy
import json
import unittest

from tool.ci import font_metrics_observation as metrics


class FontMetricsTests(unittest.TestCase):
    def fixture(self):
        samples = [dict(size=size, height=height, width=size * 9,
            line_height=size * height, natural_ascent=size * .8,
            natural_descent=size * .2, even_baseline=size * height / 2,
            proportional_baseline=size * height * .8, even_ascent=size,
            even_descent=size * .2, even_mode=1, proportional_mode=0)
            for size in (12, 14, 28, 56) for height in (1.45, 2)]
        return dict(schema=1, font='bundled_interface', samples=samples)

    def event(self, value):
        return (json.dumps(dict(type='print', testID=17,
            message=metrics.PREFIX + json.dumps(value))) + '\n').encode()

    def test_complete_and_partial_metrics_retain_only_finite_original_samples(self):
        original = self.fixture()
        result = metrics.project(self.event(original), complete=True)
        self.assertEqual(result['status'], 'OBSERVED')
        self.assertTrue(result['complete_cases'])
        self.assertEqual(result['samples'], original['samples'])
        self.assertEqual(set(result), {'schema', 'scope', 'status', 'font',
                                      'sample_count', 'complete_cases', 'samples'})
        partial = dict(original, samples=original['samples'][:3])
        result = metrics.project(self.event(partial), complete=True)
        self.assertEqual(result['status'], 'OBSERVED')
        self.assertFalse(result['complete_cases'])
        self.assertEqual(result['sample_count'], 3)
        self.assertEqual(original, self.fixture())

    def test_unknown_fields_labels_and_types_cannot_escape_the_projection(self):
        for change in (dict(font='private-input'), dict(path='private-input'),
                       dict(schema=True), dict(schema=2), dict(samples={}),
                       dict(samples=[])):
            result = metrics.project(self.event(dict(self.fixture(), **change)),
                                     complete=True)
            self.assertEqual(result, dict(schema=1, scope='bundled_font_metrics',
                                          status='REFUSED'))
            self.assertNotIn('private-input', json.dumps(result))

    def test_nonfinite_unbounded_or_private_sample_values_are_refused(self):
        for key, value in (('width', True), ('width', float('nan')),
                          ('width', float('inf')), ('width', -1),
                          ('width', 4097), ('natural_ascent', 'private-input'),
                          ('even_mode', 0), ('proportional_mode', 1),
                          ('detail', 'private-input')):
            original = self.fixture()
            original['samples'][0][key] = value
            result = metrics.project(self.event(original), complete=True)
            self.assertEqual(result['status'], 'REFUSED')
            self.assertNotIn('private-input', json.dumps(result))

    def test_duplicate_malformed_or_reordered_messages_never_grant_observation(self):
        event = self.event(self.fixture())
        self.assertIsNone(metrics.project(b'{"type":"done"}\n', complete=True))
        for raw in (event + event, b'not-json\n', event + b'\xff',
                    self.event('private-input')):
            self.assertEqual(metrics.project(raw, complete=True)['status'], 'REFUSED')
        original = copy.deepcopy(self.fixture())
        original['samples'][0], original['samples'][1] = (
            original['samples'][1], original['samples'][0])
        self.assertEqual(metrics.project(self.event(original), complete=True)['status'],
                         'REFUSED')

    def test_incomplete_and_oversized_streams_never_become_positive_metrics(self):
        event = self.event(self.fixture())
        for raw, complete in ((event, False), (event, None), (event.decode(), True),
                              (b' ' * (4 * 1024**2 + 1), True)):
            self.assertEqual(metrics.project(raw, complete=complete)['status'], 'REFUSED')
