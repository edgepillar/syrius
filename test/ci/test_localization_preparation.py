"""Keep localization source generation finite and separate from app execution."""

import json
import unittest

from tool.ci import prepare_localizations as preparation


class LocalizationDeltaTests(unittest.TestCase):
    def sample(self):
        before, after = {}, {}
        for name in preparation.DART_FILES:
            before[name] = b'class Locale {\n}\n'
            getters = ''.join('  String get ' + k + " => '" + v + "';\n"
                              for k, v in preparation.LABELS.items())
            after[name] = ('class Locale {\n' + getters + '}\n').encode()
        before[preparation.REPORT] = json.dumps(dict(ar=['old'], es=[])).encode()
        after[preparation.REPORT] = json.dumps(dict(
            ar=['old', *preparation.LABELS], es=list(preparation.LABELS))).encode()
        return before, after

    def test_exact_generated_edits_reconstruct_every_after_digest(self):
        before, after = self.sample()
        result = preparation.delta(before, after)
        self.assertEqual(set(result), set(preparation.OUTPUTS))
        for name, record in result.items():
            lines = before[name].decode().splitlines(keepends=True)
            for edit in reversed(record['edits']):
                start = edit['old_start']
                self.assertEqual(lines[start:start + len(edit['old_lines'])], edit['old_lines'])
                lines[start:start + len(edit['old_lines'])] = edit['new_lines']
            rebuilt = ''.join(lines).encode()
            self.assertEqual(rebuilt, after[name])
            self.assertEqual(preparation.sha(rebuilt), record['after_sha256'])

    def test_extra_missing_or_foreign_files_refuse(self):
        before, after = self.sample()
        for name in ('private.dart', '../app.dart', 'lib/main.dart'):
            with self.assertRaisesRegex(Exception, 'DELTA_REFUSED'):
                preparation.delta(before, dict(after, **{name: b'new'}))
        for name in preparation.OUTPUTS:
            offered = dict(after)
            del offered[name]
            with self.assertRaisesRegex(Exception, 'DELTA_REFUSED'):
                preparation.delta(before, offered)

    def test_existing_dart_changes_and_duplicate_getters_refuse(self):
        before, after = self.sample()
        name = preparation.DART_FILES[0]
        for value in (after[name].replace(b'Locale', b'Other'),
                      after[name] + b'String get zapReceivedNice;\n',
                      after[name] + b"String get privateLabel => 'private';\n",
                      after[name] + 'private \u00e9\n'.encode()):
            with self.assertRaisesRegex(Exception, 'DELTA_REFUSED'):
                preparation.delta(before, dict(after, **{name: value}))

    def test_untranslated_report_cannot_change_existing_keys_or_locales(self):
        before, after = self.sample()
        for value in (dict(ar=list(preparation.LABELS), es=list(preparation.LABELS)),
                      dict(ar=['old', *preparation.LABELS], es=[]),
                      dict(ar=['old', *preparation.LABELS], es=list(preparation.LABELS), private=[])):
            with self.assertRaisesRegex(Exception, 'DELTA_REFUSED'):
                preparation.delta(before, dict(after, **{preparation.REPORT: json.dumps(value).encode()}))

    def test_size_text_type_and_missing_getters_refuse(self):
        before, after = self.sample()
        name = preparation.DART_FILES[0]
        for value in (b'x' * (1024**2 + 1), 'private',
                      after[name].replace(b'zapReceivedNice', b'private')):
            with self.assertRaisesRegex(Exception, 'DELTA_REFUSED'):
                preparation.delta(before, dict(after, **{name: value}))


if __name__ == '__main__':
    unittest.main()
