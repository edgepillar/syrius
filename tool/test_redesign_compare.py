#!/usr/bin/env python3
"""Exercise comparison evidence rules with tiny synthetic PNGs.

The caller supplies an existing, disposable directory in approved scratch:

    python tool/test_redesign_compare.py --temp-root <approved-scratch>

No real wallet, mockup screenshot or existing report is changed. These tests
qualify report behaviour only; they do not establish any screen's match.
"""

from __future__ import annotations

import argparse
from contextlib import redirect_stdout
import hashlib
import html
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

from PIL import Image, ImageOps

from redesign_compare import (
    Capture,
    ReportGallery,
    Screen,
    _ArchiveReadCache,
    capture_bytes,
    generate_report,
    load_actual_manifest,
    main,
    screen_inventory,
    screen_notes,
    select_actual_captures,
)


TEST_ROOT: Path | None = None


class VisualAcceptanceTests(unittest.TestCase):
    def test_all_matches_require_one_explicit_target(self) -> None:
        repo = Path(__file__).resolve().parents[1]
        target = "a" * 40
        manifest = Path("captures.json")

        def reviewed_pair(screen, theme, *args, **kwargs):
            return {
                "id": screen.stem(theme),
                "number": screen.number,
                "theme": theme,
                "state": "reviewed-match",
            }

        with (
            patch("redesign_compare.select_actual_captures", return_value={}),
            patch("redesign_compare.compare_pair", side_effect=reviewed_pair),
        ):
            for source, expected in ((None, "INCOMPLETE"), (target, "COMPLETE")):
                with self.subTest(target_source=source):
                    summary = generate_report(
                        repo, None, None, actual_manifest=manifest, target_source=source,
                    )["summary"]
                    self.assertEqual(summary["states"], {"reviewed-match": 94})
                    self.assertEqual(summary["visual_review"], expected)

    def test_require_reviewed_without_target_refuses_before_report(self) -> None:
        args = ["redesign_compare.py", "--require-reviewed", "--summary-only"]
        with (
            patch("sys.argv", args),
            patch("sys.stderr", new_callable=io.StringIO) as errors,
            patch("redesign_compare.generate_report") as report,
        ):
            with self.assertRaises(SystemExit) as result:
                main()
        self.assertEqual(result.exception.code, 2)
        self.assertIn("--require-reviewed requires --target-source", errors.getvalue())
        report.assert_not_called()


class ArchiveReadCacheTests(unittest.TestCase):
    def test_reuses_verified_bytes_until_the_archive_identity_changes(self) -> None:
        original, replacement = b"original", b"replaced"
        digest = hashlib.sha256(original).hexdigest()
        path = Path("capture.zip")
        metadata = SimpleNamespace(
            st_dev=1, st_ino=2, st_size=len(original),
            st_mtime_ns=3, st_ctime_ns=4,
        )
        cache = _ArchiveReadCache()
        with (
            patch.object(Path, "stat", return_value=metadata),
            patch("redesign_compare.bounded_bytes", side_effect=[original, replacement]) as load,
        ):
            self.assertEqual(cache.read(path, digest), original)
            self.assertEqual(cache.read(path, digest), original)
            self.assertEqual(load.call_count, 1)
            metadata.st_ino = 5
            with self.assertRaisesRegex(ValueError, "manifest SHA-256"):
                cache.read(path, digest)
            self.assertEqual(load.call_count, 2)

    def test_archive_byte_budget_evicts_the_least_recently_used_archive(self) -> None:
        files = {Path("a.zip"): b"aaaa", Path("b.zip"): b"bbbb",
                 Path("c.zip"): b"cccc"}
        cache = _ArchiveReadCache(max_entries=3, max_bytes=8)
        metadata = SimpleNamespace(
            st_dev=1, st_ino=2, st_size=4, st_mtime_ns=3, st_ctime_ns=4,
        )
        with (
            patch.object(Path, "stat", return_value=metadata),
            patch("redesign_compare.bounded_bytes", side_effect=lambda path, _: files[path]) as load,
        ):
            for name in ("a.zip", "b.zip", "a.zip", "c.zip", "a.zip", "b.zip"):
                path = Path(name)
                digest = hashlib.sha256(files[path]).hexdigest()
                self.assertEqual(cache.read(path, digest), files[path])
            self.assertEqual([call.args[0].name for call in load.call_args_list],
                             ["a.zip", "b.zip", "c.zip", "b.zip"])

    def test_interleaved_zip_members_keep_the_catalog_order(self) -> None:
        root = Path("comparison-fixture")
        src = root / "mockups" / "redesign" / "src" / "screens.html"
        first, second = Screen(1, "first", "First", src), Screen(2, "second", "Second", src)
        first_dark = first.stem("dark")
        first_light = first.stem("light")
        second_dark = second.stem("dark")
        with io.BytesIO() as data, Image.new("RGBA", (4, 3)) as image:
            image.save(data, format="PNG")
            png = data.getvalue()
            image.putpixel((0, 0), (15, 0, 0, 0))
            image.putpixel((1, 0), (0, 16, 0, 0))
            image.putpixel((2, 0), (0, 0, 0, 17))
            data.seek(0)
            data.truncate()
            image.save(data, format="PNG")
            changed_png = data.getvalue()
        png_digest = hashlib.sha256(png).hexdigest()
        captures, archives = {}, {}
        for name, members in (("a.zip", (first_dark, second_dark)), ("b.zip", (first_light,))):
            path = root / name
            with io.BytesIO() as data:
                with zipfile.ZipFile(data, "w") as archive:
                    for stem in members:
                        archive.writestr(f"{stem}.png", png)
                archives[path] = data.getvalue()
            digest = hashlib.sha256(archives[path]).hexdigest()
            for stem in members:
                captures[stem] = Capture(
                    path, png_digest if stem != second_dark else "0" * 64,
                    "a" * 40, f"{stem}.png", digest,
                )
        stat_result = SimpleNamespace(
            st_dev=1, st_ino=2, st_size=3, st_mtime_ns=4, st_ctime_ns=5,
        )
        gallery = ReportGallery()

        def read(path: Path, _: int) -> bytes:
            if path in archives:
                return archives[path]
            return changed_png if path.name == f"{first_light}.png" else png

        with (
            patch.object(Path, "stat", return_value=stat_result),
            patch("redesign_compare.screen_inventory", return_value=[first, second]),
            patch("redesign_compare.screen_notes", return_value={"first": [], "second": []}),
            patch("redesign_compare.select_actual_captures", return_value=captures),
            patch("redesign_compare.bounded_bytes", side_effect=read) as load,
        ):
            report = generate_report(
                root, None, None, actual_manifest=root / "inputs.json",
                target_source="a" * 40, required_size=(4, 3), gallery=gallery,
            )
        self.assertEqual([call.args[0] for call in load.call_args_list
                          if call.args[0] in archives], list(archives))
        self.assertEqual([pair["id"] for pair in report["pairs"]],
                         [first_dark, first_light, second_dark, second.stem("light")])
        self.assertEqual([pair["state"] for pair in report["pairs"]],
                         ["unreviewed", "unreviewed", "invalid", "missing"])
        self.assertEqual(report["summary"]["target_pairs"]["available"], 2)
        self.assertEqual(report["pairs"][0]["score"]["changed_pixels"], 0)
        self.assertEqual(report["pairs"][0]["score"]["changed_pixels_at_least_16"], 0)
        self.assertEqual(report["pairs"][1]["score"]["changed_pixels"], 3)
        self.assertEqual(report["pairs"][1]["score"]["changed_pixels_at_least_16"], 2)
        self.assertIn(f"capture/{first_dark}.png", gallery.assets)
        self.assertIn(f"diff/{first_light}.png", gallery.assets)
        self.assertNotIn(f"capture/{second_dark}.png", gallery.assets)

        with (
            patch.object(Path, "stat", return_value=stat_result),
            patch("redesign_compare.bounded_bytes", side_effect=read) as load,
        ):
            self.assertEqual(gallery.read_asset(f"capture/{first_dark}.png"), (png, "image/png"))
            self.assertEqual(gallery.read_asset(f"capture/{first_light}.png"), (png, "image/png"))
            delta, media_type = gallery.read_asset(f"diff/{first_dark}.png")
            self.assertEqual(media_type, "image/png")
            with Image.open(io.BytesIO(delta)) as image:
                self.assertEqual(image.getextrema(), (0, 0))
            path = captures[first_dark].path
            self.assertEqual([call.args[0] for call in load.call_args_list
                              if call.args[0] in archives], [path, captures[first_light].path])
            stat_result.st_ctime_ns += 1
            original = archives[path]
            archives[path] = b"changed"
            with self.assertRaisesRegex(ValueError, "ZIP does not match"):
                gallery.read_asset(f"capture/{first_dark}.png")
            archives[path] = original
            self.assertEqual(gallery.read_asset(f"capture/{first_dark}.png"), (png, "image/png"))


class CaptureCatalogTests(unittest.TestCase):
    def test_accelerator_requires_the_prepared_catalog_for_both_screens(self) -> None:
        target = "a" * 40
        ordinary = Path("navigation.json")
        prepared = Path("project-detail.json")
        for screen in ("28-az", "29-az-project"):
            for theme in ("dark", "light"):
                with self.subTest(screen=screen, theme=theme):
                    stem = f"{screen}-{theme}"
                    generic = Capture(Path("generic.png"), source_sha=target)
                    project = Capture(Path("project.png"), source_sha=target,
                                      catalog_family="project-detail")
                    manifests = {ordinary: {stem: generic}, prepared: {stem: project}}
                    with patch("redesign_compare.load_actual_manifest",
                               side_effect=lambda path, _, **kwargs: manifests[path]):
                        self.assertTrue(generic.is_diagnostic(stem, require_catalog_family=True))
                        self.assertFalse(project.is_diagnostic(stem, require_catalog_family=True))
                        self.assertEqual(select_actual_captures(
                            (ordinary, prepared), {stem}, target), {stem: project})

    def test_node_and_addresses_use_prepared_settings_in_both_themes(self) -> None:
        target = "a" * 40
        ordinary = Path("settings.json")
        verified = Path("node-verified.json")
        for screen in ("30-set-node", "35-set-addresses"):
            for theme in ("dark", "light"):
                with self.subTest(screen=screen, theme=theme):
                    stem = f"{screen}-{theme}"
                    resting = Capture(Path("rest.png"), source_sha=target,
                                      catalog_family="settings")
                    ready = Capture(Path("ready.png"), source_sha=target,
                                    catalog_family="node-verified")
                    manifests = {ordinary: {stem: resting}, verified: {stem: ready}}
                    with patch("redesign_compare.load_actual_manifest",
                               side_effect=lambda path, _, **kwargs: manifests[path]):
                        self.assertTrue(resting.is_diagnostic(stem))
                        self.assertEqual(select_actual_captures(
                            (ordinary, verified), {stem}, target), {stem: ready})

    def test_held_tokens_requires_a_prepared_holder_capture(self) -> None:
        target = "a" * 40
        issuer_index, holder_index = Path("issuer.json"), Path("holder.json")
        for theme in ("dark", "light"):
            with self.subTest(theme=theme):
                stem = f"23-tokens-{theme}"
                issuer = Capture(Path("mint.png"), source_sha=target,
                                 catalog_family="seeded-states-visual")
                holder = Capture(Path("held.png"), source_sha=target,
                                 catalog_family="token-holder")
                manifests = {issuer_index: {stem: issuer}, holder_index: {stem: holder}}
                with patch("redesign_compare.load_actual_manifest",
                           side_effect=lambda path, _, **kwargs: manifests[path]):
                    self.assertTrue(issuer.is_diagnostic(stem, require_catalog_family=True))
                    self.assertFalse(holder.is_diagnostic(stem, require_catalog_family=True))
                    self.assertEqual(select_actual_captures(
                        (issuer_index, holder_index), {stem}, target), {stem: holder})

    def test_ambiguous_history_does_not_abort_exact_target_coverage(self) -> None:
        target = "a" * 40
        exact = Capture(Path("present.png"), source_sha=target)
        old = Capture(Path("old.png"), source_sha="b" * 40)
        older = Capture(Path("older.png"), source_sha="c" * 40)
        manifests = {
            Path("one.json"): {"present": exact, "historical": old, "single": old},
            Path("two.json"): {"present": old, "historical": older},
        }
        with patch(
            "redesign_compare.load_actual_manifest",
            side_effect=lambda path, _, **kwargs: manifests[path],
        ):
            self.assertEqual(
                select_actual_captures(tuple(manifests), set(), target),
                {"present": exact, "single": old},
            )
            with self.assertRaisesRegex(ValueError, "multiple files"):
                select_actual_captures(tuple(manifests), set(), None)
            manifests[Path("two.json")]["present"] = Capture(
                Path("conflict.png"), source_sha=target,
            )
            with self.assertRaisesRegex(ValueError, "multiple files for present"):
                select_actual_captures(tuple(manifests), set(), target)

    def test_portable_index_preserves_each_capture_family(self) -> None:
        source = Path("review") / "captures.json"
        archive_dir = Path("retained") / "objects"
        digest = "a" * 64
        entries = {
            "30-set-node-dark": {
                "path": digest,
                "sha256": "b" * 64,
                "source_sha": "c" * 40,
                "archive_member": "30-set-node-dark.png",
                "archive_sha256": digest,
                "catalog_family": "node-verified",
            },
            "30-set-node-light": {
                "path": "settings/scene.zip",
                "sha256": "d" * 64,
                "source_sha": "c" * 40,
                "archive_member": "30-set-node-light.png",
                "archive_sha256": "e" * 64,
                "catalog_family": "settings",
            },
        }
        index = {"actual": entries}
        with (
            patch.object(Path, "is_file", return_value=True),
            patch.object(Path, "open", side_effect=lambda *_: io.BytesIO(json.dumps(index).encode())),
        ):
            captures = load_actual_manifest(source, set(entries), archive_dir=archive_dir)
            self.assertEqual(captures["30-set-node-dark"].path, (archive_dir / digest).resolve())
            self.assertEqual(captures["30-set-node-dark"].catalog_family, "node-verified")
            self.assertEqual(captures["30-set-node-light"].path,
                             (source.parent / "settings/scene.zip").resolve())
            self.assertEqual(captures["30-set-node-light"].catalog_family, "settings")
            index["catalog_family"] = "node-verified"
            with self.assertRaisesRegex(ValueError, "inconsistent"):
                load_actual_manifest(source, set(entries), archive_dir=archive_dir)

    def test_prepared_capture_replaces_diagnostic_only_at_the_target_source(self) -> None:
        repo = Path("catalog-fixture")
        screen = Screen(7, "send-rest", "Send", repo / "transfer.html")
        stem = screen.stem("dark")
        target, previous = "a" * 40, "b" * 40
        with io.BytesIO() as data, Image.new("RGBA", (4, 3)) as image:
            image.save(data, format="PNG")
            png = data.getvalue()
        digest = hashlib.sha256(png).hexdigest()
        navigation = repo / "navigation.json"
        unclassified = repo / "unclassified.json"
        prepared = repo / "prepared.json"
        older = repo / "older.json"
        restored = repo / "restored.json"
        restored_old = repo / "restored_old.json"
        conflicting = repo / "conflicting.json"

        def manifest(family: str | None, directory: str, source: str) -> bytes:
            entry: dict[str, object] = {"actual": {
                stem: {"path": f"{directory}/{stem}.png", "sha256": digest, "source_sha": source},
            }}
            if family is not None:
                entry["catalog_family"] = family
            return json.dumps(entry).encode()

        inputs = {
            navigation: manifest("navigation", "plain", target),
            unclassified: manifest(None, "unknown", target),
            prepared: manifest("send-confirm", "filled", target),
            older: manifest("send-confirm", "prior", previous),
            restored: manifest("send-restored", "restored", target),
            restored_old: manifest("send-restored", "restored_old", previous),
            conflicting: manifest("send-confirm", "conflict", target),
        }
        review = {stem: {"verdict": "match", "reviewer": "Fixture",
                         "reviewed_at": "2026-11-20T00:00:00Z",
                         "expected_sha256": digest, "actual_sha256": digest}}
        with (
            patch.object(Path, "is_file", return_value=True),
            patch.object(Path, "open", autospec=True,
                         side_effect=lambda path, *_: io.BytesIO(inputs[path])),
            patch("redesign_compare.screen_inventory", return_value=[screen]),
            patch("redesign_compare.screen_notes", return_value={screen.id: []}),
            patch("redesign_compare.load_reviews", return_value=review),
            patch("redesign_compare.bounded_bytes", return_value=png),
        ):
            def report(*sources: Path, exact: bool = True) -> dict[str, object]:
                return generate_report(repo, None, None, actual_manifest=sources,
                                       target_source=target if exact else None,
                                       required_size=(4, 3))

            diagnostic = report(navigation, older)
            self.assertEqual(diagnostic["pairs"][0]["state"], "diagnostic-capture")
            self.assertEqual(diagnostic["summary"]["target_pairs"]["available"], 0)
            unknown = report(unclassified, older)
            self.assertEqual(unknown["pairs"][0]["state"], "diagnostic-capture")
            self.assertEqual(unknown["summary"]["target_pairs"]["available"], 0)
            self.assertEqual(report(unclassified, exact=False)["pairs"][0]["state"],
                             "reviewed-match")
            selected = report(navigation, unclassified, older, prepared)
            self.assertEqual(selected["pairs"][0]["actual"]["catalog_family"], "send-confirm")
            self.assertEqual(selected["pairs"][0]["state"], "reviewed-match")
            self.assertEqual(selected["summary"]["target_pairs"]["available"], 1)
            self.assertEqual(report(prepared, restored_old)["pairs"][0]["actual"][
                "catalog_family"], "send-confirm")
            self.assertEqual(report(navigation, prepared, restored)["pairs"][0]["actual"][
                "catalog_family"], "send-restored")
            self.assertEqual(report(restored)["summary"]["target_pairs"]["available"], 1)
            with self.assertRaisesRegex(ValueError, stem):
                report(navigation, prepared, conflicting)


class CompareTests(unittest.TestCase):
    def setUp(self) -> None:
        if TEST_ROOT is None:
            raise RuntimeError("Run this test script with --temp-root pointing to approved scratch")
        self.temporary = tempfile.TemporaryDirectory(prefix="compare-", dir=TEST_ROOT)
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        self.src = self.repo / "mockups" / "redesign" / "src"
        self.src.mkdir(parents=True)
        self.expected = self.src.parent / "shots"
        self.expected.mkdir()
        self.actual = self.repo / "actual"
        self.actual.mkdir()
        self.output = self.repo / "report"
        self.ids = ["screen-z", "screen-a"] + [f"screen-{n}" for n in range(3, 48)]
        sections = "\n".join(
            f'<section class="scr" id="{screen_id}" data-title="{html.escape(screen_id + " < & >", quote=True)}"></section>'
            for screen_id in self.ids
        )
        (self.src / "10-screens.html").write_text(sections, encoding="utf-8")
        notes = {screen_id: [["At rest", "A <note> & text"]] for screen_id in self.ids}
        # Put the closing brace on its own line, as in the actual mockup source.
        (self.src / "90-tail.html").write_text("const NOTES = " + repr(notes)[:-1] + "\n};", encoding="utf-8")
        for number, screen_id in enumerate(self.ids, 1):
            for theme in ("dark", "light"):
                self.save_png(self.expected / f"{number:02d}-{screen_id}-{theme}.png")
        self.stem = "01-screen-z-dark"

    @staticmethod
    def save_png(path: Path, size: tuple[int, int] = (4, 3)) -> None:
        with Image.new("RGBA", size, (12, 34, 56, 255)) as image:
            image.save(path)

    def add_actual(self, size: tuple[int, int] = (4, 3)) -> None:
        self.save_png(self.actual / f"{self.stem}.png", size)

    def review_file(
        self, verdict: str = "match", stale_field: str | None = None, *,
        filename: str = "reviews.json",
    ) -> Path:
        record = {
            "verdict": verdict,
            "reviewer": "Reviewer <test>",
            "reviewed_at": "2026-10-22T12:00:00Z",
            "note": "Reviewed <layout> & frames",
            "expected_sha256": hashlib.sha256((self.expected / f"{self.stem}.png").read_bytes()).hexdigest(),
            "actual_sha256": hashlib.sha256((self.actual / f"{self.stem}.png").read_bytes()).hexdigest(),
        }
        if stale_field:
            record[stale_field] = "0" * 64
        path = self.repo / filename
        path.write_text(json.dumps({"reviews": {self.stem: record}}), encoding="utf-8")
        return path

    def report(self, reviews: Path | tuple[Path, ...] | None = None) -> dict[str, object]:
        return generate_report(
            self.repo, self.actual, self.output, reviews, required_size=(4, 3)
        )

    def test_missing_actual_remains_visible(self) -> None:
        result = self.report()
        self.assertEqual(len(result["pairs"]), 94)
        self.assertEqual(result["pairs"][0]["state"], "missing")
        self.assertEqual(result["pairs"][0]["actual"]["state"], "missing")
        self.assertIsNone(result["pairs"][0]["score"])
        self.assertEqual(result["summary"]["visual_review"], "INCOMPLETE")

    def test_wrong_size_is_not_rescaled_or_scored(self) -> None:
        self.add_actual((3, 4))
        pair = self.report()["pairs"][0]
        self.assertEqual(pair["state"], "size-mismatch")
        self.assertIsNone(pair["score"])
        self.assertIsNone(pair["diff_url"])

    def test_default_requires_1280_by_780_even_if_tiny_images_agree(self) -> None:
        self.add_actual()
        pair = generate_report(self.repo, self.actual, self.output)["pairs"][0]
        self.assertEqual(pair["state"], "size-mismatch")

    def test_corrupt_png_is_invalid(self) -> None:
        (self.actual / f"{self.stem}.png").write_bytes(b"not a PNG")
        pair = self.report()["pairs"][0]
        self.assertEqual(pair["state"], "invalid")
        self.assertNotIn(str(self.repo), pair["actual"]["reason"])

    def test_equal_pixels_still_require_visual_review(self) -> None:
        self.add_actual()
        pair = self.report()["pairs"][0]
        self.assertEqual(pair["score"]["similarity_pct"], 100)
        self.assertEqual(pair["state"], "unreviewed")
        self.assertIsNotNone(pair["diff_url"])
        compact = self.repo / "compact-report"
        result = generate_report(
            self.repo, self.actual, compact, required_size=(4, 3), write_diffs=False,
        )
        self.assertEqual(result["pairs"][0], dict(pair, diff_url=None))
        self.assertEqual(result["summary"]["visual_review"], "INCOMPLETE")
        self.assertFalse((compact / "diffs").exists())
        page = (compact / "index.html").read_text(encoding="utf-8")
        self.assertIn("Difference image omitted for this report", page)
        self.assertIn("Available pairs to review (1)", page)
        self.assertIn(f'href="#{self.stem}"', page)
        self.assertNotIn('href="#01-screen-z-light"', page)

    def test_indexed_diff_preserves_every_heatmap_color(self) -> None:
        with Image.new("RGBA", (256, 1), (0, 0, 0, 255)) as before:
            before.save(self.expected / f"{self.stem}.png")
        with Image.frombytes("L", (256, 1), bytes(range(256))) as levels:
            with levels.convert("RGBA") as after:
                after.save(self.actual / f"{self.stem}.png")
            with ImageOps.colorize(levels, "#000000", "#ff557f") as reference:
                expected_pixels = reference.tobytes()

        result = generate_report(self.repo, self.actual, self.output, required_size=(256, 1))
        pair = result["pairs"][0]
        self.assertEqual(pair["score"]["changed_pixels"], 255)
        with Image.open(self.output / pair["diff_url"]) as indexed:
            self.assertEqual(indexed.mode, "P")
            with indexed.convert("RGB") as decoded:
                self.assertEqual(decoded.tobytes(), expected_pixels)

    def test_equal_diffs_share_one_verified_file(self) -> None:
        self.add_actual()
        self.save_png(self.actual / "02-screen-a-light.png")
        pairs = self.report()["pairs"]
        url = pairs[0]["diff_url"]
        self.assertIsNotNone(url)
        self.assertEqual(pairs[3]["diff_url"], url)
        path = self.output / url
        data = path.read_bytes()
        self.assertEqual(path.stem, hashlib.sha256(data).hexdigest())
        self.assertEqual(list(path.parent.iterdir()), [path])
        page = (self.output / "index.html").read_text(encoding="utf-8")
        self.assertEqual(page.count(f'width="4" height="3" src="{url}"'), 2)
        before = path.stat()
        self.report()
        after = path.stat()
        self.assertEqual((after.st_ino, after.st_mtime_ns), (before.st_ino, before.st_mtime_ns))

        changed = bytes([data[0] ^ 1]) + data[1:]
        path.write_bytes(changed)
        with self.assertRaisesRegex(ValueError, "Existing difference image"):
            self.report()
        self.assertEqual(path.read_bytes(), changed)

    def test_stale_review_on_either_image_is_invalidated(self) -> None:
        self.add_actual()
        for field in ("expected_sha256", "actual_sha256"):
            with self.subTest(field=field):
                pair = self.report(self.review_file(stale_field=field))["pairs"][0]
                self.assertEqual(pair["state"], "unreviewed")
                self.assertEqual(pair["review"]["state"], "stale")

    def test_review_batches_select_exact_hashes_and_surface_conflicts(self) -> None:
        self.add_actual()
        older = self.review_file(stale_field="actual_sha256", filename="older.json")
        current = self.review_file(verdict="mismatch")
        for batches in ((older, current), (current, older), (current, current)):
            with self.subTest(batches=batches):
                pair = self.report(batches)["pairs"][0]
                self.assertEqual(pair["state"], "reviewed-mismatch")

        conflicting = self.review_file(filename="conflicting.json")
        for batches in ((current, conflicting), (conflicting, current)):
            with self.subTest(batches=batches):
                pair = self.report(batches)["pairs"][0]
                self.assertEqual(pair["state"], "unreviewed")
                self.assertEqual(pair["review"]["state"], "conflicting")
                page = (self.output / "index.html").read_text(encoding="utf-8")
                self.assertIn("Exact image reviews disagree", page)

    def test_inventory_and_report_keep_source_order(self) -> None:
        result = self.report()
        pairs = result["pairs"]
        self.assertEqual([pair["id"] for pair in pairs[:4]], [
            "01-screen-z-dark", "01-screen-z-light", "02-screen-a-dark", "02-screen-a-light"
        ])
        page = (self.output / "index.html").read_text(encoding="utf-8")
        self.assertLess(page.index('id="01-screen-z-dark"'), page.index('id="02-screen-a-dark"'))
        self.assertIn("A &lt;note&gt; &amp; text", page)
        self.assertIn("screen-z &lt; &amp; &gt;", page)

    def test_valid_match_requires_hashes_and_review_metadata(self) -> None:
        self.add_actual()
        pair = self.report(self.review_file())["pairs"][0]
        self.assertEqual(pair["state"], "reviewed-match")
        self.assertEqual(pair["review"]["state"], "current")
        self.assertIsNotNone(pair["diff_url"])
        page = (self.output / "index.html").read_text(encoding="utf-8")
        self.assertIn("Reviewer &lt;test&gt;", page)
        self.assertIn("Reviewed &lt;layout&gt; &amp; frames", page)
        self.assertNotIn("Available pairs to review", page)

    def test_reviewed_mismatch_does_not_follow_pixel_score(self) -> None:
        self.add_actual()
        pair = self.report(self.review_file(verdict="mismatch"))["pairs"][0]
        self.assertEqual(pair["score"]["similarity_pct"], 100)
        self.assertEqual(pair["state"], "reviewed-mismatch")
        page = (self.output / "index.html").read_text(encoding="utf-8")
        self.assertIn(f'href="#{self.stem}"', page)

    def test_bad_review_metadata_cannot_grant_acceptance(self) -> None:
        self.add_actual()
        reviews = self.review_file()
        data = json.loads(reviews.read_text(encoding="utf-8"))
        data["reviews"][self.stem]["reviewed_at"] = "2026-10-22T12:00:00"
        reviews.write_text(json.dumps(data), encoding="utf-8")
        pair = self.report(reviews)["pairs"][0]
        self.assertEqual(pair["state"], "unreviewed")
        self.assertEqual(pair["review"]["state"], "invalid")

    def test_notes_never_execute_javascript_or_python(self) -> None:
        source = self.src / "90-tail.html"
        source.write_text("const NOTES = { 'screen-z': object()\n};", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "literal strings and lists"):
            screen_notes(source, screen_inventory(self.src))

    def test_manifest_links_existing_literal_and_content_addressed_captures(self) -> None:
        self.add_actual()
        first = self.actual / f"{self.stem}.png"
        other = self.repo / "other"
        other.mkdir()
        second = other / "capture.png"
        self.save_png(second)
        digest = hashlib.sha256(second.read_bytes()).hexdigest()
        second = second.rename(other / digest)
        manifest = self.repo / "captures.json"
        manifest.write_text(json.dumps({"actual": {
            self.stem: {"path": str(first.relative_to(self.repo)), "sha256": digest},
            "02-screen-a-light": {"path": str(second), "sha256": digest},
        }}), encoding="utf-8")

        result = generate_report(
            self.repo, None, self.output, actual_manifest=manifest, required_size=(4, 3),
        )
        pairs = {pair["id"]: pair for pair in result["pairs"]}
        self.assertEqual(result["summary"]["states"], {"unreviewed": 2, "missing": 92})
        self.assertEqual(pairs[self.stem]["actual"]["url"], f"../actual/{self.stem}.png")
        self.assertEqual(pairs["02-screen-a-light"]["actual"]["url"], f"../other/{digest}")
        self.assertFalse((self.output / "actual").exists())
        self.assertEqual(sorted(path.name for path in other.iterdir()), [digest])

    def test_manifest_hash_mismatch_refuses_score_and_review(self) -> None:
        self.add_actual()
        manifest = self.repo / "captures.json"
        manifest.write_text(json.dumps({"actual": {
            self.stem: {"path": f"actual/{self.stem}.png", "sha256": "0" * 64},
        }}), encoding="utf-8")
        pair = generate_report(
            self.repo, None, self.output, self.review_file(),
            actual_manifest=manifest, required_size=(4, 3),
        )["pairs"][0]
        self.assertEqual(pair["state"], "invalid")
        self.assertIn("manifest SHA-256", pair["reason"])
        self.assertEqual(pair["review"], {"state": "none"})
        self.assertIsNone(pair["score"])
        self.assertIsNone(pair["diff_url"])

    def test_target_source_admits_review_only_for_the_selected_commit(self) -> None:
        self.add_actual()
        reviews = self.review_file()
        digest = hashlib.sha256((self.actual / f"{self.stem}.png").read_bytes()).hexdigest()
        manifest = self.repo / "captures.json"
        current = "a" * 40
        historical = "b" * 40
        for captured, state in (
            (current, "reviewed-match"), (historical, "other-source"), (None, "unknown-source"),
        ):
            with self.subTest(captured=captured):
                entry = {"path": f"actual/{self.stem}.png", "sha256": digest}
                if captured is not None:
                    entry["source_sha"] = captured
                manifest.write_text(json.dumps({"actual": {self.stem: entry}}), encoding="utf-8")
                result = generate_report(
                    self.repo, None, self.output, reviews, actual_manifest=manifest,
                    target_source=current, required_size=(4, 3), write_diffs=False,
                )
                pair = result["pairs"][0]
                self.assertEqual(result["summary"]["states"], {state: 1, "missing": 93})
                self.assertEqual(result["summary"]["target_source"], current)
                coverage = result["summary"]["target_pairs"]
                self.assertEqual(coverage["available"], int(captured == current))
                self.assertEqual(self.stem in coverage["remaining"], captured != current)
                self.assertEqual(pair["actual"].get("source_sha"), captured)
                self.assertEqual(pair["score"]["similarity_pct"], 100)
                self.assertEqual(pair["review"]["state"], "current" if captured == current else "none")
                page = (self.output / "index.html").read_text(encoding="utf-8")
                self.assertIn(f"Target commit <code>{current}</code>", page)
                self.assertIn("Pairs still needed at this commit", page)
                self.assertEqual(f'href="#{self.stem}"' in page, captured != current)
                if captured is not None:
                    self.assertIn(f"Actual at {captured[:12]}", page)

    def test_capture_batches_prefer_target_and_require_a_unique_selection(self) -> None:
        current = "a" * 40
        historical = "b" * 40
        second_stem = "02-screen-a-light"
        previous = self.actual / "previous"
        selected = self.actual / "selected"
        for directory in (previous, selected):
            directory.mkdir()
            self.save_png(directory / f"{self.stem}.png")
        self.save_png(previous / f"{second_stem}.png")
        digest = hashlib.sha256((selected / f"{self.stem}.png").read_bytes()).hexdigest()

        def save_manifest(directory: Path, source: str, *stems: str) -> Path:
            manifest = directory / "captures.json"
            manifest.write_text(json.dumps({"actual": {
                stem: {"path": f"{stem}.png", "sha256": digest, "source_sha": source}
                for stem in stems
            }}), encoding="utf-8")
            return manifest

        older = save_manifest(previous, historical, self.stem, second_stem)
        fresh = save_manifest(selected, current, self.stem)
        result = generate_report(
            self.repo, None, self.output, actual_manifest=(fresh, older),
            target_source=current, required_size=(4, 3), write_diffs=False,
        )
        pairs = {pair["id"]: pair for pair in result["pairs"]}
        self.assertEqual(pairs[self.stem]["actual"]["url"], f"../actual/selected/{self.stem}.png")
        self.assertEqual(pairs[second_stem]["actual"]["url"], f"../actual/previous/{second_stem}.png")
        self.assertEqual(pairs[second_stem]["state"], "other-source")
        self.assertEqual(result["summary"]["target_pairs"]["available"], 1)
        self.assertNotIn(self.stem, result["summary"]["target_pairs"]["remaining"])
        self.assertIn(second_stem, result["summary"]["target_pairs"]["remaining"])

        save_manifest(previous, current, self.stem, second_stem)
        conflict = self.repo / "conflict"
        with self.assertRaisesRegex(ValueError, self.stem):
            generate_report(
                self.repo, None, conflict, actual_manifest=(older, fresh),
                target_source=current, required_size=(4, 3), write_diffs=False,
            )
        self.assertFalse(conflict.exists())

    def test_zip_gallery_keeps_the_original_bytes_without_extracting(self) -> None:
        source = "a" * 40
        name = f"{self.stem}.png"
        image = (self.expected / name).read_bytes()
        # A retained archive can be named by its digest instead of a suffix.
        payload = io.BytesIO()
        with zipfile.ZipFile(payload, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr(name, image)
        archive_digest = hashlib.sha256(payload.getvalue()).hexdigest()
        retained = self.actual / archive_digest
        retained.write_bytes(payload.getvalue())
        capture_path = self.repo / "captures.json"
        entry = {
            "path": f"actual/{retained.name}",
            "sha256": hashlib.sha256(image).hexdigest(),
            "source_sha": source,
            "archive_sha256": archive_digest,
            "archive_member": name,
        }
        capture_path.write_text(json.dumps({"actual": {self.stem: entry}}))

        with self.assertRaisesRegex(ValueError, "ZIP capture manifests require"):
            generate_report(self.repo, None, self.output, actual_manifest=capture_path)
        self.assertFalse(self.output.exists())

        argv = [
            "redesign_compare.py", "--actual-manifest", str(capture_path),
            "--target-source", source, "--require-current-captures", "--summary-only",
        ]
        with (
            patch("redesign_compare.ROOT", self.repo),
            patch("sys.argv", argv),
            patch(
                "redesign_compare.generate_report",
                side_effect=lambda *args, **kwargs: generate_report(
                    *args, required_size=(4, 3), **kwargs,
                ),
            ),
            patch("redesign_compare.ImageChops.difference", side_effect=AssertionError),
            redirect_stdout(io.StringIO()) as stdout,
        ):
            self.assertEqual(main(), 1)
        self.assertFalse(self.output.exists())
        self.assertFalse((self.src.parent / "compare").exists())
        summary = json.loads(stdout.getvalue())
        self.assertEqual(summary["target_pairs"]["available"], 1)
        self.assertEqual(len(summary["target_pairs"]["remaining"]), 93)
        self.assertEqual(summary["states"], {"unreviewed": 1, "missing": 93})
        self.assertEqual(summary["visual_review"], "INCOMPLETE")

        with (
            patch("redesign_compare.ROOT", self.repo),
            patch("sys.argv", [*argv[:-2], "--serve"]),
            patch(
                "redesign_compare.generate_report",
                side_effect=lambda *args, **kwargs: generate_report(
                    *args, required_size=(4, 3), **kwargs,
                ),
            ),
            patch.object(ReportGallery, "serve", autospec=True) as serve,
            redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(main(), 0)
        served_gallery, page = serve.call_args.args
        self.assertIn(f'src="capture/{name}"'.encode(), page)
        self.assertIn(f'src="diff/{name}"'.encode(), page)
        self.assertEqual(served_gallery.read_asset(f"capture/{name}"), (image, "image/png"))
        self.assertFalse((self.src.parent / "compare").exists())

        gallery = ReportGallery()
        report = generate_report(
            self.repo, None, self.output, actual_manifest=capture_path,
            target_source=source, required_size=(4, 3), gallery=gallery,
        )
        pair = report["pairs"][0]
        url = f"capture/{name}"
        self.assertEqual(pair["actual"]["url"], url)
        self.assertEqual(pair["state"], "unreviewed")
        self.assertEqual(pair["score"]["changed_pixels"], 0)
        self.assertEqual(report["summary"]["target_pairs"]["available"], 1)
        descriptor, media_type = gallery.assets[url]
        self.assertEqual(media_type, "image/png")
        self.assertEqual(capture_bytes(descriptor), image)
        diff_url = pair["diff_url"]
        diff, diff_type = gallery.read_asset(diff_url)
        self.assertEqual(diff_type, "image/png")
        with Image.open(io.BytesIO(diff)) as rendered:
            self.assertEqual(rendered.size, (4, 3))
            self.assertEqual(rendered.getextrema(), (0, 0))
        report_html = (self.output / "index.html").read_text()
        self.assertIn(url, report_html)
        self.assertIn(diff_url, report_html)
        self.assertNotIn(archive_digest, report_html)
        self.assertFalse((self.output / "capture").exists())
        self.assertFalse((self.output / "diffs").exists())
        self.assertEqual(list(self.actual.iterdir()), [retained])

        expected = self.expected / name
        self.save_png(expected, (2, 3))
        with self.assertRaisesRegex(ValueError, "Asset has changed"):
            gallery.read_asset(diff_url)
        expected.write_bytes(image)
        retained.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "ZIP does not match"):
            gallery.read_asset(diff_url)
        retained.write_bytes(payload.getvalue())

        for field in ("sha256", "archive_sha256"):
            with self.subTest(wrong_pin=field):
                invalid = ReportGallery()
                bad_entry = dict(entry, **{field: "0" * 64})
                # Use a normal ZIP filename so either content pin can be checked.
                zip_file = self.actual / "archive.zip"
                zip_file.write_bytes(payload.getvalue())
                bad_entry["path"] = "actual/archive.zip"
                capture_path.write_text(json.dumps({"actual": {self.stem: bad_entry}}))
                report = generate_report(
                    self.repo, None, self.output, actual_manifest=capture_path,
                    target_source=source, required_size=(4, 3), gallery=invalid,
                )
                self.assertEqual(report["pairs"][0]["state"], "invalid")
                self.assertEqual(report["summary"]["target_pairs"]["available"], 0)
                self.assertNotIn(url, invalid.assets)

    def test_zip_gallery_accepts_the_same_screen_without_its_catalog_number(self) -> None:
        source = "a" * 40
        image = (self.expected / f"{self.stem}.png").read_bytes()
        member = f"{self.stem.partition('-')[2]}.png"
        archive_path = self.actual / "entry.zip"
        with zipfile.ZipFile(archive_path, "w") as archive:
            archive.writestr(member, image)
        capture_path = self.repo / "captures.json"
        entry = {
            "path": "actual/entry.zip",
            "sha256": hashlib.sha256(image).hexdigest(),
            "source_sha": source,
            "archive_sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(),
            "archive_member": member,
        }
        capture_path.write_text(json.dumps({"actual": {self.stem: entry}}))
        gallery = ReportGallery()
        report = generate_report(
            self.repo, None, self.output, actual_manifest=capture_path,
            target_source=source, required_size=(4, 3), gallery=gallery,
        )
        pair = report["pairs"][0]
        self.assertEqual(report["summary"]["target_pairs"]["available"], 1)
        self.assertEqual(gallery.read_asset(pair["actual"]["url"]), (image, "image/png"))

        for wrong_name in ("screen-z-light.png", "screen-a-dark.png", f"inside/{member}"):
            with self.subTest(wrong_name=wrong_name):
                entry["archive_member"] = wrong_name
                capture_path.write_text(json.dumps({"actual": {self.stem: entry}}))
                with self.assertRaisesRegex(ValueError, "Invalid ZIP member"):
                    load_actual_manifest(capture_path, {self.stem})

    def test_current_capture_gate_distinguishes_coverage_from_visual_review(self) -> None:
        target = "a" * 40
        captures = self.repo / "captures.json"
        entries = {}
        for name in sorted(self.expected.glob("*.png")):
            actual = self.actual / name.name
            self.save_png(actual)
            entries[name.stem] = {
                "path": f"actual/{name.name}",
                "sha256": hashlib.sha256(actual.read_bytes()).hexdigest(),
                "source_sha": target,
            }
        argv = [
            "redesign_compare.py", "--target-source", target,
            "--actual-manifest", str(captures), "--output-dir", str(self.output),
            "--require-current-captures", "--no-diff-images",
        ]
        for wrong_size in (False, True):
            with self.subTest(wrong_size=wrong_size):
                if wrong_size:
                    actual = self.actual / f"{self.stem}.png"
                    self.save_png(actual, (2, 2))
                    entries[self.stem]["sha256"] = hashlib.sha256(actual.read_bytes()).hexdigest()
                captures.write_text(json.dumps({"actual": entries}), encoding="utf-8")
                with (
                    patch("redesign_compare.ROOT", self.repo),
                    patch("sys.argv", argv),
                    patch(
                        "redesign_compare.generate_report",
                        side_effect=lambda *args, **kwargs: generate_report(
                            *args, required_size=(4, 3), **kwargs,
                        ),
                    ),
                    redirect_stdout(io.StringIO()),
                ):
                    self.assertEqual(main(), int(wrong_size))
                summary = json.loads((self.output / "summary.json").read_text(encoding="utf-8"))
                self.assertEqual(summary["target_pairs"], {
                    "available": 93 if wrong_size else 94,
                    "remaining": [self.stem] if wrong_size else [],
                })
                self.assertEqual(summary["visual_review"], "INCOMPLETE")
                self.assertFalse((self.output / "diffs").exists())
                page = (self.output / "index.html").read_text(encoding="utf-8")
                needed_heading = "Pairs still needed at this commit"
                self.assertEqual(needed_heading in page, wrong_size)
                if wrong_size:
                    needed = page.split(needed_heading, 1)[1].split("</details>", 1)[0]
                    self.assertIn(f'href="#{self.stem}"', needed)
                review = page.split("Available pairs to review", 1)[1].split("</details>", 1)[0]
                self.assertEqual(f'href="#{self.stem}"' in review, not wrong_size)

    def test_target_source_requires_manifest_before_output(self) -> None:
        with self.assertRaisesRegex(ValueError, "requires a capture manifest"):
            generate_report(self.repo, self.actual, self.output, target_source="a" * 40)
        self.assertFalse(self.output.exists())

    def test_manifest_rejects_duplicate_or_unknown_capture_stems(self) -> None:
        manifest = self.repo / "captures.json"
        entry = json.dumps({"path": f"actual/{self.stem}.png", "sha256": "0" * 64})
        for entries, message in (
            (f'"{self.stem}":{entry},"{self.stem}":{entry}', "duplicate keys"),
            (f'"00-unregistered-dark":{entry}', "Invalid capture manifest entry"),
            (f'"{self.stem}":{entry[:-1]},"source_sha":"short"}}', "full lowercase Git commit SHA"),
        ):
            with self.subTest(message=message):
                manifest.write_text('{"actual":{' + entries + '}}', encoding="utf-8")
                with self.assertRaisesRegex(ValueError, message):
                    generate_report(self.repo, None, self.output, actual_manifest=manifest)
                self.assertFalse(self.output.exists())

    def test_generation_preserves_unknown_output_files_and_links_inputs(self) -> None:
        self.add_actual()
        self.output.mkdir()
        retained = self.output / "keep.txt"
        retained.write_text("retained", encoding="utf-8")
        self.report()
        self.assertEqual(retained.read_text(encoding="utf-8"), "retained")
        self.assertEqual({path.name for path in self.output.iterdir()}, {
            "keep.txt", "diffs", "index.html", "manifest.json", "summary.json"
        })
        manifest = json.loads((self.output / "manifest.json").read_text(encoding="utf-8"))
        self.assertFalse(manifest["pairs"][0]["expected"]["url"].startswith("/"))
        self.assertFalse(manifest["pairs"][0]["actual"]["url"].startswith("/"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--temp-root", required=True, type=Path)
    arguments, test_arguments = parser.parse_known_args()
    if not arguments.temp_root.is_dir():
        parser.error("--temp-root must be an existing approved scratch directory")
    TEST_ROOT = arguments.temp_root
    unittest.main(argv=[__file__, *test_arguments])
