#!/usr/bin/env python3
"""
Achaea strong help spider.

Features:
- Crawls the help index and linked help pages
- Extracts candidate topics from titles, see-also sections, and help text
- Tries direct `?what=` requests for discovered topics
- Normalizes and saves raw HTML, text, and structured JSON
- Builds a command/topic index to help identify commands from help files
- Supports resume mode and polite rate limiting

Usage:
  py achaea_strong_spider.py
  py achaea_strong_spider.py --out achaea_help_dataset --delay 0.6 --max-pages 3000
  py achaea_strong_spider.py --seed-topic doubleslash --seed-topic parry
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Deque, Dict, Iterable, List, Optional, Set, Tuple
from urllib.parse import parse_qs, quote_plus, urlencode, urljoin, urlparse

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://www.achaea.com"
START_URL = "https://www.achaea.com/game-help"
GAME_HELP_PATH = "/game-help"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 AchaeaHelpSpider/1.0"
)

HELP_CMD_RE = re.compile(
    r"\b(?:HELP|AB|ABILITIES|SHOW|SCORE|STAT|SKILLS|WHO|ISSUE|QUESTS|NEWBIE|"
    r"CLANHELP|CITYHELP|HOUSEHELP|ORDERHELP|CHELP|CLHELP|HHELP|OHELP)\b"
    r"(?:\s+[A-Z0-9][A-Z0-9'._\-/]*)+",
    re.IGNORECASE,
)
SECTION_NUMBER_RE = re.compile(r"^\s*(\d+(?:\.\d+)*)\s+(.+?)\s*$")
SEE_ALSO_RE = re.compile(r"\((?:See also|See)\s*:?\s*(.*?)\)", re.IGNORECASE | re.DOTALL)
TITLE_RE = re.compile(r"^\s*(\d+(?:\.\d+)*)\s+(.+?)\s*$")
WORDLIKE_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9'._\-/]*")

SKIP_TOPICS = {
    "return to help index",
    "input",
}


def slugify_filename(text: str, max_len: int = 120) -> str:
    text = text.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")
    return text[:max_len] or "item"


@dataclass
class PageRecord:
    page_id: str
    url: str
    what: Optional[str]
    title: str
    section_number: Optional[str]
    text_path: str
    html_path: str
    json_path: str
    discovered_from: str
    command_candidates: List[str]
    topic_candidates: List[str]


class AchaeaSpider:
    def __init__(
        self,
        out_dir: Path,
        delay: float = 0.7,
        timeout: float = 20.0,
        max_pages: int = 5000,
        seed_topics: Optional[List[str]] = None,
        resume: bool = True,
        verbose: bool = True,
    ) -> None:
        self.out_dir = out_dir
        self.delay = delay
        self.timeout = timeout
        self.max_pages = max_pages
        self.seed_topics = seed_topics or []
        self.resume = resume
        self.verbose = verbose

        self.raw_dir = out_dir / "raw_html"
        self.text_dir = out_dir / "clean_text"
        self.page_json_dir = out_dir / "pages"
        self.index_dir = out_dir / "indexes"
        self.state_dir = out_dir / "state"
        self.logs_dir = out_dir / "logs"

        for directory in [
            self.raw_dir,
            self.text_dir,
            self.page_json_dir,
            self.index_dir,
            self.state_dir,
            self.logs_dir,
        ]:
            directory.mkdir(parents=True, exist_ok=True)

        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT})

        self.queue: Deque[Tuple[str, str]] = deque()
        self.visited_urls: Set[str] = set()
        self.visited_topics: Set[str] = set()
        self.failed_topics: Dict[str, int] = defaultdict(int)
        self.page_records: List[PageRecord] = []
        self.command_index: Dict[str, Set[str]] = defaultdict(set)
        self.topic_to_pages: Dict[str, Set[str]] = defaultdict(set)

        self.manifest_path = self.index_dir / "dataset_manifest.json"
        self.topic_index_path = self.index_dir / "topic_index.json"
        self.command_index_path = self.index_dir / "command_index.json"
        self.url_state_path = self.state_dir / "visited_urls.json"
        self.topic_state_path = self.state_dir / "visited_topics.json"
        self.fail_state_path = self.state_dir / "failed_topics.json"
        self.log_path = self.logs_dir / "crawl.log"

        if self.resume:
            self._load_state()

        if START_URL not in self.visited_urls:
            self.queue.append((START_URL, "seed:index"))

        for topic in self.seed_topics:
            topic = self.normalize_topic(topic)
            if topic and topic not in self.visited_topics:
                self.queue.append((self.make_topic_url(topic), f"seed:topic:{topic}"))

    def log(self, message: str) -> None:
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{timestamp}] {message}"
        if self.verbose:
            print(line)
        with self.log_path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")

    def _load_state(self) -> None:
        if self.url_state_path.exists():
            self.visited_urls = set(json.loads(self.url_state_path.read_text(encoding="utf-8")))
        if self.topic_state_path.exists():
            self.visited_topics = set(json.loads(self.topic_state_path.read_text(encoding="utf-8")))
        if self.fail_state_path.exists():
            self.failed_topics.update(json.loads(self.fail_state_path.read_text(encoding="utf-8")))
        if self.manifest_path.exists():
            try:
                data = json.loads(self.manifest_path.read_text(encoding="utf-8"))
                for item in data:
                    rec = PageRecord(**item)
                    self.page_records.append(rec)
                    if rec.what:
                        self.topic_to_pages[rec.what].add(rec.page_id)
                    for cmd in rec.command_candidates:
                        self.command_index[cmd].add(rec.page_id)
            except Exception:
                pass

    def save_state(self) -> None:
        self.url_state_path.write_text(
            json.dumps(sorted(self.visited_urls), indent=2), encoding="utf-8"
        )
        self.topic_state_path.write_text(
            json.dumps(sorted(self.visited_topics), indent=2), encoding="utf-8"
        )
        self.fail_state_path.write_text(
            json.dumps(dict(sorted(self.failed_topics.items())), indent=2), encoding="utf-8"
        )
        manifest_data = [rec.__dict__ for rec in self.page_records]
        self.manifest_path.write_text(
            json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8"
        )

        topic_index = {
            topic: sorted(page_ids) for topic, page_ids in sorted(self.topic_to_pages.items())
        }
        self.topic_index_path.write_text(
            json.dumps(topic_index, indent=2, ensure_ascii=False), encoding="utf-8"
        )

        command_index = {
            cmd: sorted(page_ids) for cmd, page_ids in sorted(self.command_index.items())
        }
        self.command_index_path.write_text(
            json.dumps(command_index, indent=2, ensure_ascii=False), encoding="utf-8"
        )

    @staticmethod
    def normalize_topic(topic: str) -> str:
        topic = topic.strip()
        topic = topic.strip("[](){}<>\"'")
        topic = topic.replace("&nbsp;", " ")
        topic = re.sub(r"\s+", " ", topic)
        topic = topic.strip()
        topic = topic.strip(". ")
        return topic.lower()

    @staticmethod
    def make_topic_url(topic: str) -> str:
        return f"{BASE_URL}{GAME_HELP_PATH}/?{urlencode({'what': topic})}"

    @staticmethod
    def canonicalize_url(url: str) -> str:
        parsed = urlparse(url)
        qs = parse_qs(parsed.query)
        what = qs.get("what", [None])[0]
        page_id = qs.get("id", [None])[0]
        if parsed.path.rstrip("/") == GAME_HELP_PATH and not parsed.query:
            return START_URL
        if parsed.path.rstrip("/") == GAME_HELP_PATH and what is not None:
            return f"{BASE_URL}{GAME_HELP_PATH}/?what={quote_plus(what)}"
        if parsed.path.rstrip("/") == GAME_HELP_PATH and page_id is not None:
            return f"{BASE_URL}{GAME_HELP_PATH}/?id={page_id}"
        return url

    def enqueue(self, url: str, reason: str) -> None:
        canonical = self.canonicalize_url(url)
        if canonical not in self.visited_urls:
            self.queue.append((canonical, reason))

    def fetch(self, url: str) -> Optional[requests.Response]:
        try:
            resp = self.session.get(url, timeout=self.timeout)
        except requests.RequestException as exc:
            self.log(f"FETCH ERROR {url} :: {exc}")
            return None
        time.sleep(self.delay)
        return resp

    def parse_page(self, url: str, html: str, discovered_from: str) -> Optional[PageRecord]:
        soup = BeautifulSoup(html, "html.parser")

        for tag in soup(["script", "style", "noscript"]):
            tag.decompose()

        raw_text = soup.get_text("\n")
        lines = [line.strip() for line in raw_text.splitlines()]
        lines = [line for line in lines if line]
        clean_text = "\n".join(lines)

        title = "unknown"
        heading = soup.find(["h1", "h2", "h3", "title"])
        if heading:
            title = heading.get_text(" ", strip=True)

        section_number = None
        title_match = TITLE_RE.match(title)
        if title_match:
            section_number = title_match.group(1)
            title = title_match.group(2).strip()

        what = self.extract_topic_from_url(url)
        if what:
            self.visited_topics.add(what)

        page_hash = hashlib.sha1(url.encode("utf-8")).hexdigest()[:16]
        base_name = slugify_filename((what or title or page_hash))
        page_id = f"{page_hash}-{base_name}"

        html_path = self.raw_dir / f"{page_id}.html"
        text_path = self.text_dir / f"{page_id}.txt"
        json_path = self.page_json_dir / f"{page_id}.json"

        html_path.write_text(html, encoding="utf-8")
        text_path.write_text(clean_text, encoding="utf-8")

        command_candidates = sorted(self.extract_commands(clean_text))
        topic_candidates = sorted(self.extract_topic_candidates(title, clean_text))

        page_payload = {
            "page_id": page_id,
            "url": url,
            "what": what,
            "title": title,
            "section_number": section_number,
            "discovered_from": discovered_from,
            "command_candidates": command_candidates,
            "topic_candidates": topic_candidates,
            "text": clean_text,
        }
        json_path.write_text(
            json.dumps(page_payload, indent=2, ensure_ascii=False), encoding="utf-8"
        )

        rec = PageRecord(
            page_id=page_id,
            url=url,
            what=what,
            title=title,
            section_number=section_number,
            text_path=str(text_path.relative_to(self.out_dir)),
            html_path=str(html_path.relative_to(self.out_dir)),
            json_path=str(json_path.relative_to(self.out_dir)),
            discovered_from=discovered_from,
            command_candidates=command_candidates,
            topic_candidates=topic_candidates,
        )
        return rec

    @staticmethod
    def extract_topic_from_url(url: str) -> Optional[str]:
        parsed = urlparse(url)
        qs = parse_qs(parsed.query)
        what = qs.get("what", [None])[0]
        if what is None:
            return None
        return AchaeaSpider.normalize_topic(what)

    def extract_links(self, soup: BeautifulSoup) -> Iterable[str]:
        for a in soup.find_all("a", href=True):
            href = a["href"].strip()
            if not href:
                continue
            full = urljoin(BASE_URL, href)
            parsed = urlparse(full)
            if parsed.netloc != urlparse(BASE_URL).netloc:
                continue
            if parsed.path.rstrip("/") != GAME_HELP_PATH:
                continue
            yield self.canonicalize_url(full)

    def extract_commands(self, text: str) -> Set[str]:
        commands: Set[str] = set()
        for match in HELP_CMD_RE.finditer(text):
            cmd = re.sub(r"\s+", " ", match.group(0).strip())
            commands.add(cmd.upper())

        # command tables: lines starting with a likely command token
        for line in text.splitlines():
            line = line.strip()
            if not line or len(line) > 140:
                continue
            if " - " in line or " : " in line:
                left = re.split(r"\s+-\s+|\s+:\s+", line, maxsplit=1)[0]
                if 1 <= len(left.split()) <= 5 and left.upper() == left and re.search(r"[A-Z]", left):
                    commands.add(left)
        return commands

    def extract_topic_candidates(self, title: str, text: str) -> Set[str]:
        candidates: Set[str] = set()

        # Title itself is often the topic.
        if title:
            candidates.add(self.normalize_topic(title))

        # See also blocks.
        for match in SEE_ALSO_RE.finditer(text):
            block = match.group(1)
            parts = re.split(r",| and |/|;", block)
            for part in parts:
                part = re.sub(r"\bHELP\b", "", part, flags=re.IGNORECASE)
                part = self.normalize_topic(part)
                if part and part not in SKIP_TOPICS and len(part) <= 120:
                    candidates.add(part)

        # HELP X references.
        for match in re.finditer(r"\bHELP\s+([A-Z0-9][A-Z0-9'._\-/ ]{0,80})", text, flags=re.IGNORECASE):
            topic = self.normalize_topic(match.group(1))
            topic = re.split(r"[\n\r]", topic)[0]
            topic = topic[:80].strip()
            if topic and topic not in SKIP_TOPICS:
                candidates.add(topic)

        # Section headings and numbered children in index-like pages.
        for line in text.splitlines():
            sec = SECTION_NUMBER_RE.match(line)
            if sec:
                topic = self.normalize_topic(sec.group(2))
                if topic and topic not in SKIP_TOPICS:
                    candidates.add(topic)

        # Heuristic: capitalized standalone short headings.
        for line in text.splitlines():
            line = line.strip()
            if 2 <= len(line) <= 70 and line == line.title() and len(line.split()) <= 8:
                topic = self.normalize_topic(line)
                if topic and topic not in SKIP_TOPICS:
                    candidates.add(topic)

        # Remove junk.
        cleaned = {
            c for c in candidates
            if c
            and c not in SKIP_TOPICS
            and not c.startswith("http")
            and c not in {"game help", "achaea help files", "help"}
        }
        return cleaned

    def topic_seems_valid(self, text: str) -> bool:
        bad_markers = [
            "No help files found",
            "No help file found",
            "could not be found",
            "not found",
        ]
        lower = text.lower()
        return not any(marker.lower() in lower for marker in bad_markers)

    def crawl(self) -> None:
        pages_processed = 0
        self.log(f"Starting crawl. Queue has {len(self.queue)} initial items.")

        while self.queue and pages_processed < self.max_pages:
            url, discovered_from = self.queue.popleft()
            url = self.canonicalize_url(url)
            if url in self.visited_urls:
                continue

            self.log(f"FETCH {url} <- {discovered_from}")
            resp = self.fetch(url)
            self.visited_urls.add(url)
            if resp is None:
                continue
            if resp.status_code != 200:
                self.log(f"SKIP STATUS {resp.status_code} {url}")
                continue

            html = resp.text
            soup = BeautifulSoup(html, "html.parser")
            text_preview = soup.get_text(" ", strip=True)
            if url != START_URL and not self.topic_seems_valid(text_preview):
                topic = self.extract_topic_from_url(url)
                if topic:
                    self.failed_topics[topic] += 1
                self.log(f"INVALID TOPIC PAGE {url}")
                continue

            rec = self.parse_page(url, html, discovered_from)
            if rec is None:
                continue
            pages_processed += 1
            self.page_records.append(rec)
            if rec.what:
                self.topic_to_pages[rec.what].add(rec.page_id)
            for cmd in rec.command_candidates:
                self.command_index[cmd].add(rec.page_id)

            # Enqueue linked help pages.
            for link in self.extract_links(soup):
                self.enqueue(link, f"page-link:{rec.page_id}")

            # Enqueue discovered topics as direct `?what=` pages.
            for topic in rec.topic_candidates:
                if topic not in self.visited_topics and self.failed_topics.get(topic, 0) < 2:
                    self.enqueue(self.make_topic_url(topic), f"topic-guess:{rec.page_id}")

            if pages_processed % 25 == 0:
                self.save_state()
                self.log(f"Checkpoint saved at {pages_processed} pages.")

        self.save_state()
        self.log(
            f"Finished. Pages: {len(self.page_records)} | Topics: {len(self.visited_topics)} | "
            f"Commands: {len(self.command_index)}"
        )


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Strong spider for Achaea help files")
    parser.add_argument("--out", default="achaea_help_dataset", help="Output directory")
    parser.add_argument("--delay", type=float, default=0.7, help="Delay between requests")
    parser.add_argument("--timeout", type=float, default=20.0, help="HTTP timeout")
    parser.add_argument("--max-pages", type=int, default=5000, help="Maximum pages to fetch")
    parser.add_argument(
        "--seed-topic",
        dest="seed_topics",
        action="append",
        default=[],
        help="Extra topic to seed directly, can be repeated",
    )
    parser.add_argument("--no-resume", action="store_true", help="Do not resume prior state")
    parser.add_argument("--quiet", action="store_true", help="Reduce console logging")
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    spider = AchaeaSpider(
        out_dir=Path(args.out),
        delay=args.delay,
        timeout=args.timeout,
        max_pages=args.max_pages,
        seed_topics=args.seed_topics,
        resume=not args.no_resume,
        verbose=not args.quiet,
    )
    spider.crawl()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
