#!/usr/bin/env python3
"""Build the local redesign comparison without granting visual acceptance.

    python tool/redesign_compare.py
    python tool/redesign_compare.py --actual-dir <shots> --output-dir <report>
    python tool/redesign_compare.py --actual-manifest <captures.json>
    python tool/redesign_compare.py --actual-manifest <captures.json> --target-source <commit>
    python tool/redesign_compare.py --actual-manifest <archive-captures.json> --serve
    python tool/redesign_compare.py --actual-manifest <archive-index.json> --archive-dir <archive-store> --serve
    python tool/redesign_compare.py --actual-manifest <first.json> --actual-manifest <second.json> --target-source <commit> --require-current-captures --no-diff-images
    python tool/redesign_compare.py --reviews <reviews.json> --require-reviewed
    python tool/redesign_compare.py --no-diff-images --output-dir <compact-report>

Requires Pillow, also used by the mockup pipeline. Input images are linked,
never copied. The output is local evidence and may contain wallet screenshots;
keep it private. Relative links require the inputs to remain at their paths.
Identical difference images share one PNG in the report directory.

For captures retained in separate folders, the private input manifest has
one "actual" object keyed by literal screenshot stem. Each entry contains
"path" (absolute or relative to the manifest) and "sha256" (64 lowercase hex
digits). An optional "source_sha" records the verified producer's 40-digit
commit. With --target-source, captures from other or unknown commits remain
visible for diagnosis and are excluded from acceptance. Supply source pins
from the capture's verified run record. Use the original filename or a
content-addressed file named by its digest. Missing entries remain visible.
Pass one manifest per verified batch. Add the optional top-level
"catalog_family" from the verified producer to identify prepared captures.
An index that combines families can set "catalog_family" on each entry.
For an overlapping screen and theme, an exact target capture takes
precedence. At that source the prepared Send, Tokens, Swap, Voting, Node and
Addresses catalogs take precedence over their alternate captures. A
target-source comparison counts these states only when their manifests identify
the prepared catalog. Held Tokens needs a positive balance in the selected
account and an expanded non-owner row. The seeded issuer's Mint form stays
available for diagnosis. Alternate captures remain available for diagnosis.
Multiple distinct files with equal precedence require an explicit selection.
For a static report on Windows, place the report and all images on the same drive.

To compare from a retained ZIP, use its path in "path" and include the
archive's SHA-256 under "archive_sha256" and the literal PNG name under
"archive_member". Keep the original PNG's "sha256" and producer "source_sha".
An index can use the bare archive digest as its path. With --archive-dir,
these paths resolve in the supplied archive directory. Other paths retain
the manifest's usual resolution.
The ZIP member may omit the catalog number, as the Windows entry archive
does. It must otherwise have the same screen and theme as the manifest key.
Use --serve to view such a report on loopback. The gallery reads only the
registered originals directly from their archives and renders difference PNGs
on request. The served page stays in memory unless --output-dir is supplied
to also save the report.
Report generation reads each unchanged archive together, with one archive
buffer in memory. The report keeps its original screen and theme order.
Each PNG has its own SHA-256 check. Gallery requests verify the current
bytes on disk again.

Manual reviews use screenshot stems as keys. For example:
{
  "reviews": {
    "01-home-rest-dark": {
      "verdict": "match",
      "reviewer": "Reviewer",
      "reviewed_at": "2026-10-22T12:00:00Z",
      "expected_sha256": "<64 lowercase hexadecimal characters>",
      "actual_sha256": "<64 lowercase hexadecimal characters>",
      "note": "Layout, components, colour, type, spacing and frames reviewed."
    }
  }
}

The other verdict is "mismatch". Repeat --reviews to read separate batches.
A review applies only to those two exact images. Conflicting verdicts for
the same image pair leave it unreviewed. A pixel score, including 100%,
leaves a pair unreviewed. This report does not update the prompt's Progress
table or qualify motion or Windows.
The score also counts pixels where at least one channel differs by 16 or
more. This helps distinguish small colour differences from larger ones.
"""

from __future__ import annotations

import argparse
import ast
from collections import Counter, OrderedDict, defaultdict
from collections.abc import Mapping, Sequence
from contextlib import closing
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
from functools import reduce
import hashlib
from html import escape
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, HTTPServer
import io
import json
import os
from pathlib import Path
import re
import secrets
import stat
import sys
from tempfile import NamedTemporaryFile
from urllib.parse import quote
import warnings
import zipfile
import zlib

from PIL import Image, ImageChops, ImageStat


ROOT = Path(__file__).resolve().parent.parent
THEMES = ("dark", "light")
SCREEN_COUNT = 47
IMAGE_SIZE = (1280, 780)
MAX_IMAGE_BYTES = 16 * 1024 * 1024
MAX_ARCHIVE_BYTES = 16 * 1024 * 1024
GALLERY_ARCHIVE_CACHE_BYTES = 4 * 1024 * 1024
MAX_CAPTURE_MANIFEST_BYTES = 256 * 1024
MAX_IMAGE_PIXELS = 4096 * 4096
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
GIT_SHA = re.compile(r"[0-9a-f]{40}\Z")
CATALOG_FAMILY = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
PREPARED_CATALOGS = {
    "07-send-rest": "send-confirm",
    "23-tokens": "token-holder",
    "26-swap-list": "swap-seeded",
    "28-az": "project-detail",
    "30-set-node": "node-verified",
    "35-set-addresses": "node-verified",
}
DIFF_PALETTE = bytes(
    intensity * channel // 255
    for intensity in range(256)
    for channel in (0xFF, 0x55, 0x7F)
)


class ReportError(ValueError):
    """A controlled diagnostic that contains no private filesystem paths."""


@dataclass(frozen=True)
class Screen:
    number: int
    id: str
    title: str
    source: Path

    def stem(self, theme: str) -> str:
        return f"{self.number:02d}-{self.id}-{theme}"


@dataclass(frozen=True)
class Capture:
    path: Path
    sha256: str | None = None
    source_sha: str | None = None
    archive_member: str | None = None
    archive_sha256: str | None = None
    catalog_family: str | None = None

    def is_diagnostic(self, stem: str, *, require_catalog_family: bool = False) -> bool:
        prepared = PREPARED_CATALOGS.get(stem.rsplit("-", 1)[0])
        return (prepared is not None and self.catalog_family != prepared
                and (require_catalog_family or self.catalog_family is not None))


@dataclass(frozen=True)
class Difference:
    expected: Capture
    actual: Capture


class ScreenParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.screens: list[tuple[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag != "section" or "scr" not in (values.get("class") or "").split():
            return
        screen_id = values.get("id") or ""
        if re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", screen_id) is None:
            raise ReportError("A screen has a missing or unsafe id")
        self.screens.append((screen_id, values.get("data-title") or screen_id))


def screen_inventory(src: Path) -> list[Screen]:
    screens: list[Screen] = []
    for source in sorted(src.glob("*.html")):
        parser = ScreenParser()
        parser.feed(source.read_text(encoding="utf-8"))
        for screen_id, title in parser.screens:
            screens.append(Screen(len(screens) + 1, screen_id, title, source))
    if len(screens) != SCREEN_COUNT or len({s.id for s in screens}) != SCREEN_COUNT:
        raise ReportError("Expected 47 unique screens in ordered mockup HTML")
    return screens


def screen_notes(source: Path, screens: list[Screen]) -> dict[str, list[list[str]]]:
    text = source.read_text(encoding="utf-8")
    literal = re.search(r"\bconst\s+NOTES\s*=\s*(\{.*?\n\});", text, re.DOTALL)
    if literal is None:
        raise ReportError("Cannot find the literal mockup NOTES object")
    try:
        notes = ast.literal_eval(literal.group(1))
    except (SyntaxError, ValueError) as error:
        raise ReportError("Mockup NOTES must contain literal strings and lists") from error
    if not isinstance(notes, dict) or set(notes) != {s.id for s in screens}:
        raise ReportError("Mockup NOTES must cover exactly the 47 screen ids")
    for entries in notes.values():
        if not isinstance(entries, list) or any(
            not isinstance(entry, list)
            or len(entry) != 2
            or any(not isinstance(value, str) for value in entry)
            for entry in entries
        ):
            raise ReportError("Each mockup note must be a label and text")
    return notes


def load_reviews(source: Path | None) -> dict[str, object]:
    if source is None:
        return {}
    try:
        data = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as error:
        raise ReportError("Cannot read the reviews JSON") from error
    if not isinstance(data, dict) or not isinstance(data.get("reviews"), dict):
        raise ReportError("Reviews JSON must have a reviews object keyed by screenshot stem")
    return data["reviews"]


def unique_capture_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result = dict(pairs)
    if len(result) != len(pairs):
        raise ReportError("Capture manifest contains duplicate keys")
    return result


def _valid_catalog_family(value: object) -> bool:
    return (isinstance(value, str) and len(value) <= 40
            and CATALOG_FAMILY.fullmatch(value) is not None)


def load_actual_manifest(
    source: Path, stems: set[str], *, archive_dir: Path | None = None,
) -> dict[str, Capture]:
    try:
        if not source.is_file():
            raise ReportError("Capture manifest must be a regular file")
        with source.open("rb") as stream:
            raw = stream.read(MAX_CAPTURE_MANIFEST_BYTES + 1)
        if len(raw) > MAX_CAPTURE_MANIFEST_BYTES:
            raise ReportError("Capture manifest exceeds the byte limit")
        data = json.loads(raw, object_pairs_hook=unique_capture_keys)
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError) as error:
        raise ReportError("Cannot read the capture manifest JSON") from error
    if (not isinstance(data, dict) or not set(data) <= {"actual", "catalog_family"}
            or not isinstance(data.get("actual"), dict)):
        raise ReportError("Capture manifest must have one actual object keyed by screenshot stem")
    family = data.get("catalog_family")
    if "catalog_family" in data and not _valid_catalog_family(family):
        raise ReportError("Capture catalog family is invalid")

    captures: dict[str, Capture] = {}
    for stem, entry in data["actual"].items():
        if stem not in stems or not isinstance(entry, dict):
            raise ReportError("Invalid capture manifest entry")
        fields = entry.keys() - {"catalog_family"}
        archived = fields == {"path", "sha256", "source_sha", "archive_member", "archive_sha256"}
        if not archived and fields not in ({"path", "sha256"}, {"path", "sha256", "source_sha"}):
            raise ReportError("Invalid capture manifest entry")
        name, digest = entry["path"], entry["sha256"]
        source_sha = entry.get("source_sha")
        capture_family = entry.get("catalog_family", family)
        if "catalog_family" in entry and (
            not _valid_catalog_family(capture_family)
            or (family is not None and capture_family != family)
        ):
            raise ReportError("Capture catalog family is invalid or inconsistent")
        if (
            not isinstance(name, str) or not name or "\0" in name
            or not isinstance(digest, str) or SHA256.fullmatch(digest) is None
        ):
            raise ReportError("Invalid capture path or SHA-256")
        if "source_sha" in entry and (
            not isinstance(source_sha, str) or GIT_SHA.fullmatch(source_sha) is None
        ):
            raise ReportError("Capture source must be a full lowercase Git commit SHA")
        path = Path(name)
        member = entry.get("archive_member")
        archive_digest = entry.get("archive_sha256")
        if archived:
            unnumbered_stem = stem.partition("-")[2]
            if (
                member not in (f"{stem}.png", f"{unnumbered_stem}.png")
                or not isinstance(archive_digest, str)
                or SHA256.fullmatch(archive_digest) is None
                or (path.suffix.lower() != ".zip" and path.name != archive_digest)
            ):
                raise ReportError("Invalid ZIP member or archive SHA-256")
        elif path.name not in (f"{stem}.png", digest):
            raise ReportError("Capture file must use its literal name or SHA-256")
        try:
            base = source.parent
            if archived and archive_dir is not None and name == archive_digest:
                base = archive_dir
            resolved = (base / path).resolve()
        except (OSError, RuntimeError) as error:
            raise ReportError("Cannot resolve the capture path") from error
        captures[stem] = Capture(resolved, digest, source_sha, member, archive_digest, capture_family)
    return captures


def select_actual_captures(
    sources: Sequence[Path], stems: set[str], target_source: str | None,
    *, archive_dir: Path | None = None,
) -> dict[str, Capture]:
    candidates: dict[str, set[Capture]] = {}
    for source in sources:
        for stem, capture in load_actual_manifest(source, stems, archive_dir=archive_dir).items():
            candidates.setdefault(stem, set()).add(capture)

    selected: dict[str, Capture] = {}
    for stem, choices in candidates.items():
        exact = {
            choice for choice in choices
            if target_source is not None and choice.source_sha == target_source
        }
        choices = exact or choices
        choices = {
            choice for choice in choices
            if not choice.is_diagnostic(stem, require_catalog_family=target_source is not None)
        } or choices
        if len(choices) != 1:
            # Ambiguous history cannot qualify the requested revision. Keep
            # this pair in the target coverage backlog without choosing one.
            if target_source is not None and not exact:
                continue
            raise ReportError(f"Capture manifests select multiple files for {stem}")
        selected[stem] = next(iter(choices))
    return selected


def relative_url(target: Path, output: Path) -> str:
    return quote(Path(os.path.relpath(target, output)).as_posix(), safe="/")


def bounded_bytes(path: Path, limit: int) -> bytes:
    metadata = path.stat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > limit:
        raise ValueError("Expected a regular file within the input limit")
    with path.open("rb") as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError("File exceeds the input limit")
    return data


def _verified_archive_bytes(path: Path, digest: str | None) -> bytes:
    raw = bounded_bytes(path, MAX_ARCHIVE_BYTES)
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError("ZIP does not match the capture manifest SHA-256")
    return raw


class _ArchiveReadCache:
    """Reuse bounded, verified archives while their file identities agree."""

    def __init__(self, *, max_entries: int = 1, max_bytes: int = MAX_ARCHIVE_BYTES) -> None:
        self._archives: OrderedDict[
            Path, tuple[tuple[str | None, int, int, int, int, int], bytes]
        ] = OrderedDict()
        self._bytes = 0
        self._max_entries = max_entries
        self._max_bytes = max_bytes

    def read(self, path: Path, digest: str | None) -> bytes:
        info = path.stat()
        key = (digest, info.st_dev, info.st_ino, info.st_size,
               info.st_mtime_ns, info.st_ctime_ns)
        previous = self._archives.pop(path, None)
        if previous is not None:
            self._bytes -= len(previous[1])
        raw = previous[1] if previous is not None and previous[0] == key else (
            _verified_archive_bytes(path, digest)
        )
        # A verified archive above the gallery cache budget can still be kept
        # on its own, within the existing per-archive input limit.
        limit = max(self._max_bytes, len(raw))
        while len(self._archives) >= self._max_entries or self._bytes + len(raw) > limit:
            _, (_, evicted) = self._archives.popitem(last=False)
            self._bytes -= len(evicted)
        self._archives[path] = key, raw
        self._bytes += len(raw)
        return raw


def capture_bytes(capture: Capture, archive_cache: _ArchiveReadCache | None = None) -> bytes:
    if capture.archive_member is None:
        return bounded_bytes(capture.path, MAX_IMAGE_BYTES)
    read_archive = _verified_archive_bytes if archive_cache is None else archive_cache.read
    raw = read_archive(capture.path, capture.archive_sha256)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        entries = [info for info in archive.infolist()
                   if info.filename == capture.archive_member]
        if len(entries) != 1:
            raise ValueError("ZIP must contain one copy of the named PNG")
        info = entries[0]
        if (
            info.orig_filename != info.filename
            or info.is_dir() or info.flag_bits & 1
            or stat.S_IFMT(info.external_attr >> 16) not in (0, stat.S_IFREG)
            or not 0 < info.file_size <= MAX_IMAGE_BYTES
            or info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
        ):
            raise ValueError("ZIP PNG is unsupported or exceeds the input limit")
        with archive.open(info) as stream:
            data = stream.read(MAX_IMAGE_BYTES + 1)
        if len(data) != info.file_size:
            raise ValueError("ZIP PNG size differs from its directory entry")
        return data


def verified_bytes(capture: Capture, archive_cache: _ArchiveReadCache | None = None) -> bytes:
    data = capture_bytes(capture, archive_cache)
    if hashlib.sha256(data).hexdigest() != capture.sha256:
        raise ValueError("Asset has changed")
    return data


def decode_png(data: bytes) -> Image.Image:
    with warnings.catch_warnings():
        warnings.simplefilter("error", Image.DecompressionBombWarning)
        with Image.open(io.BytesIO(data)) as original:
            if original.format != "PNG" or getattr(original, "n_frames", 1) != 1:
                raise ValueError("Expected a single-frame PNG")
            if original.width * original.height > MAX_IMAGE_PIXELS:
                raise ValueError("PNG exceeds the pixel limit")
            return original.convert("RGBA")


class ReportGallery:
    """Serve the exact assets of one private comparison on loopback."""

    def __init__(self) -> None:
        self.assets: dict[str, tuple[Capture | Difference, str]] = {}
        self._archive_cache = _ArchiveReadCache(
            max_entries=32, max_bytes=GALLERY_ARCHIVE_CACHE_BYTES,
        )

    def add(self, url: str, capture: Capture, media_type: str = "image/png") -> None:
        self.assets[url] = capture, media_type

    def add_file(self, url: str, path: Path, media_type: str = "image/png") -> None:
        if url not in self.assets:
            digest = hashlib.sha256(bounded_bytes(path, MAX_IMAGE_BYTES)).hexdigest()
            self.add(url, Capture(path, digest), media_type)

    def add_difference(self, url: str, expected_url: str, actual_url: str) -> None:
        expected, _ = self.assets[expected_url]
        actual, _ = self.assets[actual_url]
        if not isinstance(expected, Capture) or not isinstance(actual, Capture):
            raise ReportError("Difference inputs must be original images")
        self.assets[url] = Difference(expected, actual), "image/png"

    def read_asset(self, url: str) -> tuple[bytes, str]:
        asset, media_type = self.assets[url]
        if isinstance(asset, Capture):
            return verified_bytes(asset, self._archive_cache), media_type
        with (
            closing(decode_png(verified_bytes(asset.expected, self._archive_cache))) as before,
            closing(decode_png(verified_bytes(asset.actual, self._archive_cache))) as after,
        ):
            diff = ImageChops.difference(before, after)
            return encode_diff_png(difference_mask(diff)), media_type

    def serve(self, page: bytes) -> None:
        prefix = "/" + secrets.token_urlsafe(24) + "/"
        read_asset = self.read_asset

        class GalleryHandler(BaseHTTPRequestHandler):
            timeout = 5

            def log_message(self, format: str, *args: object) -> None:
                pass

            def do_GET(self) -> None:
                host, port = self.server.server_address
                if self.headers.get("Host") != f"{host}:{port}" or not self.path.startswith(prefix):
                    self.send_error(404)
                    return
                try:
                    asset = self.path[len(prefix):]
                    if asset == "index.html":
                        data, media_type = page, "text/html; charset=utf-8"
                    else:
                        data, media_type = read_asset(asset)
                except (KeyError, OSError, ValueError, SyntaxError, zipfile.BadZipFile,
                        zlib.error, Image.DecompressionBombError, Image.DecompressionBombWarning):
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header("Content-Type", media_type)
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "no-store")
                self.send_header("X-Content-Type-Options", "nosniff")
                self.send_header("Referrer-Policy", "no-referrer")
                self.send_header(
                    "Content-Security-Policy",
                    "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; frame-ancestors 'none'",
                )
                self.end_headers()
                self.wfile.write(data)

        with HTTPServer(("127.0.0.1", 0), GalleryHandler) as server:
            host, port = server.server_address
            print(f"Private comparison page at http://{host}:{port}{prefix}index.html", flush=True)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                return


def read_image(
    capture: Capture | None, output: Path | None, *, url: str | None = None,
    archive_cache: _ArchiveReadCache | None = None,
) -> tuple[dict[str, object], Image.Image | None]:
    if capture is None:
        return {"state": "missing", "reason": "Image missing"}, None
    info: dict[str, object] = {}
    if url is not None:
        info["url"] = url
    elif output is not None:
        info["url"] = relative_url(capture.path, output)
    try:
        data = capture_bytes(capture, archive_cache)
        info["sha256"] = hashlib.sha256(data).hexdigest()
        if capture.sha256 is not None and info["sha256"] != capture.sha256:
            info.update(state="invalid", reason="Actual PNG does not match the capture manifest SHA-256")
            return info, None
        image = decode_png(data)
        info["size"] = list(image.size)
        info["state"] = "available"
        return info, image
    except FileNotFoundError:
        info.update(state="missing", reason="Image missing")
    except (OSError, ValueError, SyntaxError, zipfile.BadZipFile, zlib.error,
            Image.DecompressionBombError, Image.DecompressionBombWarning):
        info.update(state="invalid", reason="Unreadable, unsupported or oversized PNG")
    return info, None


def gallery_image(
    capture: Capture | None, output: Path | None, gallery: ReportGallery | None, url: str,
    archive_cache: _ArchiveReadCache | None = None,
) -> tuple[dict[str, object], Image.Image | None]:
    if gallery is None:
        return read_image(capture, output, archive_cache=archive_cache)
    info, image = read_image(capture, output, url=url, archive_cache=archive_cache)
    if capture is not None and image is not None:
        gallery.add(url, replace(capture, sha256=info["sha256"]))
    return info, image


def review_status(
    review: object, expected_sha: str, actual_sha: str
) -> dict[str, object]:
    if review is None:
        return {"state": "none"}
    if not isinstance(review, dict):
        return {"state": "invalid", "reason": "Review must be an object"}
    fields = ("verdict", "reviewer", "reviewed_at", "expected_sha256", "actual_sha256")
    if any(not isinstance(review.get(field), str) for field in fields):
        return {"state": "invalid", "reason": "Review fields are missing"}
    if (
        review["verdict"] not in ("match", "mismatch")
        or not review["reviewer"].strip()
        or SHA256.fullmatch(review["expected_sha256"]) is None
        or SHA256.fullmatch(review["actual_sha256"]) is None
        or not isinstance(review.get("note", ""), str)
    ):
        return {"state": "invalid", "reason": "Review fields are invalid"}
    try:
        reviewed_at = datetime.fromisoformat(review["reviewed_at"].replace("Z", "+00:00"))
        if reviewed_at.utcoffset() != timedelta(0):
            raise ValueError("UTC required")
    except ValueError:
        return {"state": "invalid", "reason": "Review time must be an ISO timestamp in UTC"}
    if review["expected_sha256"] != expected_sha or review["actual_sha256"] != actual_sha:
        return {"state": "stale", "reason": "Image hashes changed; visual review required"}
    return {"state": "current", **{key: review[key] for key in fields}, "note": review.get("note", "")}


def select_review(
    reviews: Sequence[object], expected_sha: str, actual_sha: str,
) -> dict[str, object]:
    statuses = [review_status(review, expected_sha, actual_sha) for review in reviews]
    current = [status for status in statuses if status["state"] == "current"]
    if not current:
        return statuses[0] if statuses else {"state": "none"}
    if any(status["verdict"] != current[0]["verdict"] for status in current):
        return {"state": "conflicting", "reason": "Exact image reviews disagree"}
    return current[0]


def difference_mask(diff: Image.Image) -> Image.Image:
    return reduce(ImageChops.lighter, diff.split())


def encode_diff_png(mask: Image.Image) -> bytes:
    # Palette indices preserve all heatmap colors with one byte per pixel.
    mask.putpalette(DIFF_PALETTE)
    with io.BytesIO() as encoded:
        mask.save(encoded, format="PNG")
        return encoded.getvalue()


def store_diff(mask: Image.Image, output: Path) -> str:
    data = encode_diff_png(mask)
    digest = hashlib.sha256(data).hexdigest()
    directory = output / "diffs"
    directory.mkdir(exist_ok=True)
    if directory.is_symlink():
        raise ReportError("Difference image directory must not be a symbolic link")
    path = directory / f"{digest}.png"
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        # Publish only a complete file. Concurrent writers for this digest
        # publish the same bytes, and links never target a partial PNG.
        temporary = None
        try:
            with NamedTemporaryFile(dir=directory, prefix=".diff-", delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(data)
            os.replace(temporary, path)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    else:
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size != len(data):
            raise ReportError("Existing difference image does not match its digest")
        with path.open("rb") as existing:
            if existing.read(len(data) + 1) != data:
                raise ReportError("Existing difference image does not match its digest")
    return relative_url(path, output)


def compare_pair(
    screen: Screen,
    theme: str,
    expected_dir: Path,
    capture: Capture | None,
    output: Path | None,
    reviews: Mapping[str, Sequence[object]],
    required_size: tuple[int, int] = IMAGE_SIZE,
    *,
    target_source: str | None = None,
    write_diffs: bool = True,
    gallery: ReportGallery | None = None,
    archive_cache: _ArchiveReadCache | None = None,
) -> dict[str, object]:
    stem = screen.stem(theme)
    expected, before = gallery_image(
        Capture(expected_dir / f"{stem}.png"), output, gallery, f"mockup/{stem}.png",
    )
    actual, after = gallery_image(
        capture, output, gallery, f"capture/{stem}.png", archive_cache,
    )
    source_url = None
    if gallery is not None:
        source_url = "source/" + quote(screen.source.name, safe="")
        gallery.add_file(source_url, screen.source, "text/plain; charset=utf-8")
    elif output is not None:
        source_url = relative_url(screen.source, output)
    source_sha = capture.source_sha if capture else None
    if source_sha is not None:
        actual["source_sha"] = source_sha
    if capture is not None and capture.catalog_family is not None:
        actual["catalog_family"] = capture.catalog_family
    pair: dict[str, object] = {
        "id": stem,
        "screen": screen.id,
        "number": screen.number,
        "title": screen.title,
        "theme": theme,
        "source_url": source_url,
        "expected": expected,
        "actual": actual,
        "diff_url": None,
        "score": None,
        "review": {"state": "none"},
    }
    try:
        states = (expected["state"], actual["state"])
        if "invalid" in states or "missing" in states:
            pair["state"] = "invalid" if "invalid" in states else "missing"
            pair["reason"] = "; ".join(
                f"{label.capitalize()}: {info['reason']}"
                for label, info in (("mockup", expected), ("actual", actual))
                if info["state"] != "available"
            )
            return pair
        if before.size != required_size or after.size != required_size:
            pair.update(
                state="size-mismatch",
                reason=f"Both images must be {required_size[0]} by {required_size[1]}; images were not resized",
            )
            return pair
        if target_source is not None and source_sha != target_source:
            if source_sha is None:
                pair.update(state="unknown-source", reason="Actual capture has no source commit")
            else:
                pair.update(state="other-source", reason="Actual capture is from another commit")
        elif capture is not None and capture.is_diagnostic(
            stem, require_catalog_family=target_source is not None,
        ):
            family = PREPARED_CATALOGS[stem.rsplit("-", 1)[0]]
            pair.update(state="diagnostic-capture", reason=f"Prepared {family} capture required")
        else:
            review = select_review(reviews.get(stem, ()), expected["sha256"], actual["sha256"])
            pair["review"] = review
            pair["state"] = (
                f"reviewed-{review['verdict']}" if review["state"] == "current" else "unreviewed"
            )
        if output is None and gallery is None:
            return pair
        diff = ImageChops.difference(before, after)
        mean = sum(ImageStat.Stat(diff).mean) / 4
        mask = difference_mask(diff)
        pixels = before.width * before.height
        histogram = mask.histogram()
        changed = pixels - histogram[0]
        pair["score"] = {
            "similarity_pct": round(100 * (1 - mean / 255), 4),
            "mean_absolute_error_rgba": round(mean, 4),
            "changed_pixels": changed,
            "changed_pct": round(100 * changed / pixels, 4),
            "changed_pixels_at_least_16": sum(histogram[16:]),
        }
        if write_diffs:
            if gallery is None:
                pair["diff_url"] = store_diff(mask, output)
            else:
                pair["diff_url"] = f"diff/{stem}.png"
                gallery.add_difference(pair["diff_url"], expected["url"], actual["url"])
        return pair
    finally:
        for image in (before, after):
            if image is not None:
                image.close()


def render_html(manifest: dict[str, object]) -> str:
    def image_cell(label: str, info: dict[str, object]) -> str:
        label = escape(label, quote=True)
        if info.get("state") != "available":
            return f"<figure><figcaption>{label}</figcaption><p>{escape(str(info.get('reason', 'Unavailable')))}</p></figure>"
        url = escape(str(info["url"]), quote=True)
        size = info.get("size")
        caption = f"{label} ({size[0]} by {size[1]})" if size else label
        dimensions = f' width="{size[0]}" height="{size[1]}"' if size else ""
        return (
            f'<figure><figcaption>{caption}</figcaption><a href="{url}">'
            f'<img loading="lazy" decoding="async"{dimensions} src="{url}" alt="{label}">'
            '</a></figure>'
        )

    sections: list[str] = []
    review_links: list[str] = []
    for pair in manifest["pairs"]:
        stem = escape(pair["id"], quote=True)
        title = f'{pair["number"]:02d}. {escape(pair["title"])} ({escape(pair["theme"])})'
        if pair["state"] in ("unreviewed", "reviewed-mismatch"):
            review_links.append(f'<li><a href="#{stem}">{title}</a></li>')
        score = pair["score"]
        description = (
            "No pixel score"
            if score is None
            else f"Pixel similarity {score['similarity_pct']:.4f}%; changed pixels {score['changed_pct']:.4f}%"
        )
        if score is not None and "changed_pixels_at_least_16" in score:
            count = score["changed_pixels_at_least_16"]
            description += f". {count:,} pixels have a channel difference of at least 16"
        source = pair["actual"].get("source_sha")
        actual_label = f"Actual at {source[:12]}" if source is not None else "Actual"
        figures = image_cell("Mockup", pair["expected"]) + image_cell(actual_label, pair["actual"])
        if pair["diff_url"]:
            diff = {"state": "available", "url": pair["diff_url"], "size": pair["expected"]["size"]}
        elif score is not None:
            diff = {"reason": "Difference image omitted for this report"}
        else:
            diff = {}
        figures += image_cell("Difference (max RGBA channel)", diff)
        notes = "".join(f"<li><b>{escape(label)}</b> {escape(text)}</li>" for label, text in pair["notes"])
        review = pair["review"]
        review_text = str(review.get("reason", "Visual review required"))
        if review["state"] == "current":
            review_text = f"Reviewed by {review['reviewer']} at {review['reviewed_at']}. {review['note']}"
        reason = f"<p>{escape(pair['reason'])}</p>" if "reason" in pair else ""
        sections.append(
            f'<section id="{stem}"><h2>{title}</h2><p class="state">{escape(pair["state"])}</p>'
            f"<p>{description}. Scores are diagnostic; acceptance requires visual review.</p>{reason}"
            f"<p>{escape(review_text)}</p><div class=\"images\">{figures}</div>"
            f'<details><summary>Screen notes</summary><ul>{notes}</ul>'
            f'<a href="{escape(pair["source_url"], quote=True)}">Mockup source</a></details></section>'
        )
    counts = ", ".join(f"{state}: {count}" for state, count in sorted(manifest["summary"]["states"].items()))
    target = manifest["summary"].get("target_source")
    target_text = ""
    if target is not None:
        target_pairs = manifest["summary"]["target_pairs"]
        available = target_pairs["available"]
        total = manifest["summary"]["pairs"]
        target_text = f"<p>Target commit <code>{escape(target)}</code>. {available} of {total} pairs available.</p>"
        if target_pairs["remaining"]:
            links = "".join(
                f'<li><a href="#{escape(stem, quote=True)}">{escape(stem)}</a></li>'
                for stem in target_pairs["remaining"]
            )
            target_text += (
                '<details><summary>Pairs still needed at this commit</summary>'
                f'<ul>{links}</ul></details>'
            )
    review_index = (
        f'<details><summary>Available pairs to review ({len(review_links)})</summary>'
        f'<ol>{"".join(review_links)}</ol></details>' if review_links else ""
    )
    return (
        "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        "<title>Syrius redesign comparison</title><style>"
        "body{margin:24px;font:15px/1.5 system-ui,sans-serif;background:#11151b;color:#e1e5eb}"
        "a{color:#8abaff}section{padding:20px 0;border-top:1px solid #4d5560}h2{margin-bottom:4px}"
        ".state{font-weight:bold}.images{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}"
        "figure{margin:0;min-width:0}img{width:100%;height:auto}figcaption{margin-bottom:8px}"
        "details{margin-top:16px}li{margin:8px 0}@media(max-width:900px){.images{grid-template-columns:1fr}}"
        "</style><h1>Syrius redesign comparison</h1>"
        f"{target_text}"
        f"<p>{escape(counts)}</p><p>Visual review: {manifest['summary']['visual_review']}. "
        "A screenshot does not qualify motion, chain actions or Windows builds. "
        "This local report may contain wallet data; keep it private.</p>"
        "<p>Difference images show the largest absolute RGBA channel difference. "
        "Pixel similarity is 100 minus mean absolute RGBA error as a percentage of 255. "
        "Live data, font hinting and animation frames can change scores.</p>"
        + review_index
        + "".join(sections)
        + "</html>\n"
    )


def generate_report(
    repo: Path,
    actual_dir: Path | None,
    output: Path | None,
    reviews_path: Path | Sequence[Path] | None = None,
    *,
    actual_manifest: Path | Sequence[Path] | None = None,
    archive_dir: Path | None = None,
    target_source: str | None = None,
    required_size: tuple[int, int] = IMAGE_SIZE,
    write_diffs: bool = True,
    gallery: ReportGallery | None = None,
) -> dict[str, object]:
    if archive_dir is not None and actual_manifest is None:
        raise ReportError("Archive directory requires a capture manifest")
    if target_source is not None:
        if GIT_SHA.fullmatch(target_source) is None:
            raise ReportError("Target source must be a full lowercase Git commit SHA")
        if actual_manifest is None:
            raise ReportError("Target source requires a capture manifest")
    src = repo / "mockups" / "redesign" / "src"
    expected_dir = src.parent / "shots"
    screens = screen_inventory(src)
    notes = screen_notes(src / "90-tail.html", screens)
    review_sources = (
        (reviews_path,) if reviews_path is None or isinstance(reviews_path, Path) else reviews_path
    )
    reviews: dict[str, list[object]] = defaultdict(list)
    for source in review_sources:
        for stem, review in load_reviews(source).items():
            reviews[stem].append(review)
    stems = {screen.stem(theme) for screen in screens for theme in THEMES}
    if actual_manifest is not None:
        if actual_dir is not None:
            raise ReportError("Choose either an actual directory or a capture manifest")
        sources = (actual_manifest,) if isinstance(actual_manifest, Path) else actual_manifest
        actuals = select_actual_captures(sources, stems, target_source, archive_dir=archive_dir)
    else:
        directory = actual_dir if actual_dir is not None else repo / ".harness" / "shots"
        actuals = {stem: Capture(directory / f"{stem}.png") for stem in stems}
    if output is not None:
        if gallery is None and any(capture.archive_member is not None for capture in actuals.values()):
            raise ReportError("ZIP capture manifests require --serve when writing a gallery")
        output.mkdir(parents=True, exist_ok=True)
    archive_groups: dict[
        tuple[Path, str | None] | None,
        list[tuple[Screen, str, Capture | None]],
    ] = defaultdict(list)
    for screen in screens:
        for theme in THEMES:
            capture = actuals.get(screen.stem(theme))
            archive = (
                (capture.path, capture.archive_sha256)
                if capture is not None and capture.archive_member is not None
                else None
            )
            archive_groups[archive].append((screen, theme, capture))
    archive_cache = _ArchiveReadCache()
    pairs = []
    for group in archive_groups.values():
        for screen, theme, capture in group:
            pair = compare_pair(
                screen, theme, expected_dir, capture, output,
                reviews, required_size, target_source=target_source, write_diffs=write_diffs,
                gallery=gallery, archive_cache=archive_cache,
            )
            pair["notes"] = notes[screen.id]
            pairs.append(pair)
    pairs.sort(key=lambda pair: (pair["number"], THEMES.index(pair["theme"])))
    states = dict(Counter(pair["state"] for pair in pairs))
    summary = {
        "screens": len(screens),
        "pairs": len(pairs),
        "required_image_size": list(required_size),
        "states": states,
        "visual_review": "COMPLETE" if states.get("reviewed-match", 0) == 94 else "INCOMPLETE",
        "unrecognized_review_ids": sorted(set(reviews) - {pair["id"] for pair in pairs}),
    }
    if target_source is not None:
        summary["target_source"] = target_source
        remaining = [
            pair["id"] for pair in pairs
            if pair["state"] not in ("unreviewed", "reviewed-match", "reviewed-mismatch")
        ]
        summary["target_pairs"] = {"available": len(pairs) - len(remaining), "remaining": remaining}
    manifest = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "summary": summary,
        "pairs": pairs,
    }
    if output is not None:
        for name, data in (("manifest.json", manifest), ("summary.json", summary)):
            (output / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        (output / "index.html").write_text(render_html(manifest), encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    inputs = parser.add_mutually_exclusive_group()
    inputs.add_argument("--actual-dir", type=Path, help="One capture directory (default: .harness/shots)")
    inputs.add_argument("--actual-manifest", type=Path, action="append",
                        help="Private capture paths and SHA-256 pins, repeatable")
    parser.add_argument("--archive-dir", type=Path,
                        help="Directory containing archives named by their SHA-256")
    parser.add_argument("--target-source", help="Accept reviews only for captures at this full Git commit")
    parser.add_argument("--output-dir", type=Path, help="Save the comparison report here")
    parser.add_argument("--reviews", type=Path, action="append",
                        help="Manual, image-hash-bound visual review JSON, repeatable")
    parser.add_argument("--no-diff-images", action="store_true",
                        help="Link inputs and report scores without writing difference PNGs")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--serve", action="store_true",
                      help="Serve a private loopback gallery in memory with support for retained ZIP captures")
    mode.add_argument("--summary-only", action="store_true",
                      help="Print JSON after checking images without writing a report or diff images")
    parser.add_argument("--require-reviewed", action="store_true", help="Exit 1 unless all 94 pairs are reviewed matches")
    parser.add_argument("--require-current-captures", action="store_true",
                        help="Exit 1 unless all 94 pairs are available at --target-source")
    args = parser.parse_args()
    if args.require_current_captures and args.target_source is None:
        parser.error("--require-current-captures requires --target-source")
    if args.summary_only and args.output_dir is not None:
        parser.error("--summary-only prints to stdout and cannot use --output-dir")
    gallery = ReportGallery() if args.serve else None
    default_output = ROOT / "mockups" / "redesign" / "compare"
    output = None
    if args.output_dir is not None:
        output = args.output_dir.resolve()
    elif gallery is None and not args.summary_only:
        output = default_output.resolve()
    try:
        actual_dir = args.actual_dir.resolve() if args.actual_dir is not None else None
        manifest = generate_report(
            ROOT, actual_dir, output, args.reviews,
            actual_manifest=args.actual_manifest, archive_dir=args.archive_dir,
            target_source=args.target_source,
            write_diffs=not args.no_diff_images, gallery=gallery,
        )
    except (OSError, UnicodeError, ValueError) as error:
        # Paths and raw diagnostics can contain private profile information.
        message = str(error) if isinstance(error, ReportError) else "Cannot read inputs or write report"
        print(f"Comparison generation failed: {message}", file=sys.stderr)
        return 2
    summary = manifest["summary"]
    target_pairs = summary.get("target_pairs")
    if args.summary_only:
        print(json.dumps(summary, ensure_ascii=False))
    else:
        print(f"Comparison generated: 47 screens, 94 pairs; visual review {summary['visual_review']}")
        print(", ".join(f"{state}: {count}" for state, count in sorted(summary["states"].items())))
        if target_pairs is not None:
            print(f"Target pairs available: {target_pairs['available']}/{summary['pairs']}")
    missing_captures = args.require_current_captures and bool(target_pairs["remaining"])
    incomplete_reviews = args.require_reviewed and summary["visual_review"] != "COMPLETE"
    if missing_captures or incomplete_reviews:
        return 1
    if gallery is not None:
        gallery.serve(render_html(manifest).encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
