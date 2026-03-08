#!/usr/bin/env python3
"""
Achaea Help Dataset Post-Processor

Consumes the output of achaea_strong_spider.py and builds normalized indexes for:
- commands
- abilities
- afflictions
- defences
- classes / skills
- retrieval chunks for RAG

Expected spider layout:
achaea_help_dataset/
├── clean_text/
├── pages/
├── indexes/
│   └── dataset_manifest.json

Usage:
    py achaea_post_processor.py
    py achaea_post_processor.py --dataset-dir achaea_help_dataset
    py achaea_post_processor.py --dataset-dir achaea_help_dataset --chunks-only
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Iterable

# -----------------------------
# Heuristics / vocab
# -----------------------------

CLASS_NAMES = {
    "runewarden", "dragon", "serpent", "occultist", "infernal", "monk",
    "jester", "apostate", "magi", "shaman", "priest", "sentinel",
    "alchemist", "bard", "blademaster", "druid", "paladin"
}

SKILL_HINTS = {
    "two arts", "chivalry", "weaponmastery", "runelore", "dragoncraft",
    "tekura", "subterfuge", "venom", "tarot", "spiritlore", "necromancy",
    "curses", "battlefury", "shindo", "metamorphosis", "groves",
    "harmonics", "elementalism", "crystalism"
}

COMMAND_PATTERNS = [
    re.compile(r"\bHELP\s+([A-Z0-9'\- ]{2,})\b"),
    re.compile(r"\bSyntax\s*:\s*([^\n]+)", re.IGNORECASE),
    re.compile(r"\bUsage\s*:\s*([^\n]+)", re.IGNORECASE),
    re.compile(r"\b(?:Type|Enter|Use)\s+([A-Z][A-Z0-9 _'\-]{2,})\b"),
]

AFFLICTION_TERMS = {
    "asthma", "slickness", "anorexia", "paralysis", "weariness", "clumsiness",
    "stupidity", "impatience", "epilepsy", "dizziness", "disfigurement",
    "sensitivity", "confusion", "haemophilia", "vomiting", "crippled",
    "broken left arm", "broken right arm", "broken left leg", "broken right leg",
    "prone", "generosity", "recklessness", "lethargy", "peace", "darkshade"
}

DEFENCE_TERMS = {
    "rebounding", "shielded", "fangbarrier", "insulation", "mass", "deafness",
    "blindness", "waterbreathing", "speed", "levitation", "cloak", "ghost",
    "truehearing", "fitness", "temperance", "fireskin", "thirdeye"
}

COMMAND_WORDS = {
    "attack", "kill", "follow", "queue", "stand", "wield", "unwield",
    "parry", "touch", "smoke", "eat", "apply", "focus", "diagnose",
    "clot", "summon", "mount", "dismount", "look", "inventory", "qq"
}

EXCLUDE_UPPER = {
    "AHAEA", "HTML", "HTTP", "HTTPS", "URL", "GAME HELP", "MAIN PAGE",
    "INTRODUCTION", "SEE ALSO", "COPYRIGHT", "COMMANDS"
}

SECTION_SPLIT_RE = re.compile(r"\n(?=[A-Z][A-Z /\-]{2,}:?\n)")
WHITESPACE_RE = re.compile(r"[ \t]+")
MULTI_NL_RE = re.compile(r"\n{3,}")
SLUG_CLEAN_RE = re.compile(r"[^a-z0-9\- ]+")
TOKEN_RE = re.compile(r"[a-z][a-z0-9_\-']+")


@dataclass
class DocRecord:
    doc_id: str
    source_file: str
    title: str
    url: str
    slug: str
    text: str
    category: str
    tags: list[str]
    guessed_class: str | None
    guessed_skill: str | None


@dataclass
class ChunkRecord:
    chunk_id: str
    doc_id: str
    title: str
    url: str
    category: str
    heading: str
    text: str
    tags: list[str]


# -----------------------------
# Helpers
# -----------------------------

def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = WHITESPACE_RE.sub(" ", text)
    text = MULTI_NL_RE.sub("\n\n", text)
    return text.strip()


def slugify(value: str) -> str:
    value = value.lower().strip()
    value = value.replace("&", " and ")
    value = SLUG_CLEAN_RE.sub("", value)
    value = re.sub(r"\s+", "-", value)
    value = re.sub(r"-+", "-", value)
    return value.strip("-") or "untitled"


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def write_jsonl(path: Path, rows: Iterable[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def token_set(text: str) -> set[str]:
    return set(TOKEN_RE.findall(text.lower()))


def guess_class(title: str, text: str) -> str | None:
    hay = f"{title}\n{text}".lower()
    for cls in sorted(CLASS_NAMES):
        if re.search(rf"\b{re.escape(cls)}\b", hay):
            return cls.title()
    return None


def guess_skill(title: str, text: str) -> str | None:
    hay = f"{title}\n{text}".lower()
    for skill in sorted(SKILL_HINTS):
        if skill in hay:
            return skill.title()
    skill_match = re.search(r"\b([A-Z][A-Za-z]+(?: [A-Z][A-Za-z]+)*) skill\b", text)
    if skill_match:
        return skill_match.group(1)
    return None


def infer_category(title: str, text: str, slug: str) -> str:
    low = f"{title}\n{text}\n{slug}".lower()

    if any(term in low for term in ["command", "syntax:", "usage:", "type ", "enter "]):
        if any(word in low for word in COMMAND_WORDS):
            return "command"
    if any(term in low for term in AFFLICTION_TERMS):
        return "affliction"
    if any(term in low for term in DEFENCE_TERMS):
        return "defence"
    if any(term in low for term in ["ability", "abilities", "skill", "balance", "equilibrium"]):
        if guess_class(title, text) or guess_skill(title, text):
            return "ability"
    if any(term in low for term in CLASS_NAMES):
        return "class"
    if any(term in low for term in ["house", "city", "clan", "organization"]):
        return "organization"
    if any(term in low for term in ["curing", "herb", "salve", "focus", "diagnose"]):
        return "curing"
    return "general"


def collect_tags(title: str, text: str, category: str) -> list[str]:
    hay = f"{title}\n{text}".lower()
    tags = {category}
    for cls in CLASS_NAMES:
        if re.search(rf"\b{re.escape(cls)}\b", hay):
            tags.add(cls)
    for skill in SKILL_HINTS:
        if skill in hay:
            tags.add(skill)
    for term in AFFLICTION_TERMS:
        if term in hay:
            tags.add(term)
    for term in DEFENCE_TERMS:
        if term in hay:
            tags.add(term)
    for term in ["balance", "equilibrium", "limb damage", "prone", "affliction", "venom", "shield", "parry"]:
        if term in hay:
            tags.add(term)
    return sorted(tags)


def split_into_chunks(title: str, text: str) -> list[tuple[str, str]]:
    text = normalize_text(text)
    if not text:
        return []

    # Prefer heading-based chunks.
    parts = SECTION_SPLIT_RE.split(text)
    if len(parts) > 1:
        out = []
        for idx, part in enumerate(parts, start=1):
            lines = [ln.strip() for ln in part.splitlines() if ln.strip()]
            if not lines:
                continue
            heading = lines[0][:120]
            body = "\n".join(lines[1:]).strip() or lines[0]
            out.append((heading, body))
        if out:
            return out

    # Fallback fixed-size chunking.
    paras = [p.strip() for p in text.split("\n\n") if p.strip()]
    out: list[tuple[str, str]] = []
    current: list[str] = []
    current_len = 0
    for para in paras:
        if current_len + len(para) > 1400 and current:
            body = "\n\n".join(current)
            out.append((title, body))
            current = [para]
            current_len = len(para)
        else:
            current.append(para)
            current_len += len(para)
    if current:
        out.append((title, "\n\n".join(current)))
    return out


def extract_commands(text: str) -> list[str]:
    found: set[str] = set()
    for pat in COMMAND_PATTERNS:
        for match in pat.finditer(text):
            value = match.group(1).strip()
            value = re.sub(r"\s+", " ", value)
            if len(value) < 2:
                continue
            if value.upper() in EXCLUDE_UPPER:
                continue
            # Pull out command-like phrases but keep multiword syntax.
            if sum(ch.isalpha() for ch in value) < 2:
                continue
            found.add(value)

    # Also look for all-caps command lines.
    for line in text.splitlines():
        line = line.strip()
        if not line or len(line) > 80:
            continue
        if re.fullmatch(r"[A-Z][A-Z0-9 _'\-]{2,}", line):
            if line in EXCLUDE_UPPER:
                continue
            found.add(line)

    return sorted(found)


def extract_named_terms(text: str, vocabulary: set[str]) -> list[str]:
    low = text.lower()
    return sorted(term for term in vocabulary if term in low)


def related_topics_from_text(text: str) -> list[str]:
    topics = set()
    for match in re.finditer(r"\bHELP\s+([A-Z][A-Z0-9 '\-]{1,60})", text):
        topic = match.group(1).strip(" .,")
        topics.add(topic.title())
    for match in re.finditer(r"\bSee also:?\s*([^\n]+)", text, re.IGNORECASE):
        raw = match.group(1)
        for part in re.split(r",|/|\band\b", raw, flags=re.IGNORECASE):
            part = part.strip(" .")
            if 2 <= len(part) <= 60:
                topics.add(part.title())
    return sorted(topics)


# -----------------------------
# Pipeline
# -----------------------------

def build_doc_records(dataset_dir: Path) -> list[DocRecord]:
    indexes_dir = dataset_dir / "indexes"
    pages_dir = dataset_dir / "pages"
    clean_dir = dataset_dir / "clean_text"

    manifest = load_json(indexes_dir / "dataset_manifest.json", [])
    docs: list[DocRecord] = []

    if manifest:
        for entry in manifest:
            page_id = str(entry.get("id", "")).strip()
            title = entry.get("title", "") or "untitled"
            url = entry.get("url", "")
            text_path = clean_dir / f"{page_id}.txt"
            if not text_path.exists():
                # Try page json fallback.
                page_json = pages_dir / f"{page_id}.json"
                if page_json.exists():
                    page = load_json(page_json, {})
                    text = normalize_text(page.get("text", ""))
                else:
                    continue
            else:
                text = normalize_text(text_path.read_text(encoding="utf-8", errors="ignore"))

            slug = slugify(title)
            category = infer_category(title, text, slug)
            docs.append(
                DocRecord(
                    doc_id=f"doc_{page_id}",
                    source_file=f"{page_id}.txt",
                    title=title,
                    url=url,
                    slug=slug,
                    text=text,
                    category=category,
                    tags=collect_tags(title, text, category),
                    guessed_class=guess_class(title, text),
                    guessed_skill=guess_skill(title, text),
                )
            )
    else:
        # Fallback: scan clean_text only.
        for text_path in sorted(clean_dir.glob("*.txt")):
            page_id = text_path.stem
            text = normalize_text(text_path.read_text(encoding="utf-8", errors="ignore"))
            title = text.splitlines()[0][:120] if text else f"page {page_id}"
            slug = slugify(title)
            category = infer_category(title, text, slug)
            docs.append(
                DocRecord(
                    doc_id=f"doc_{page_id}",
                    source_file=text_path.name,
                    title=title,
                    url="",
                    slug=slug,
                    text=text,
                    category=category,
                    tags=collect_tags(title, text, category),
                    guessed_class=guess_class(title, text),
                    guessed_skill=guess_skill(title, text),
                )
            )
    return docs


def build_indexes(docs: list[DocRecord], out_dir: Path) -> dict[str, Any]:
    processed_dir = out_dir / "processed"
    indexes_dir = processed_dir / "indexes"
    chunks_dir = processed_dir / "retrieval"
    kb_dir = processed_dir / "knowledge_base"

    processed_dir.mkdir(parents=True, exist_ok=True)

    # Normalized documents
    write_jsonl(kb_dir / "documents.jsonl", (asdict(doc) for doc in docs))

    # Commands / terms
    commands: dict[str, dict[str, Any]] = {}
    abilities: dict[str, dict[str, Any]] = {}
    afflictions: dict[str, dict[str, Any]] = {}
    defences: dict[str, dict[str, Any]] = {}
    classes: dict[str, dict[str, Any]] = {}
    skills: dict[str, dict[str, Any]] = {}
    relations: list[dict[str, Any]] = []
    chunks: list[ChunkRecord] = []
    category_counts = Counter()

    for doc in docs:
        category_counts[doc.category] += 1
        doc_dict = asdict(doc)

        if doc.guessed_class:
            cls_key = slugify(doc.guessed_class)
            classes.setdefault(cls_key, {
                "name": doc.guessed_class,
                "docs": [],
                "tags": set(),
                "skills": set(),
            })
            classes[cls_key]["docs"].append(doc.doc_id)
            classes[cls_key]["tags"].update(doc.tags)
            if doc.guessed_skill:
                classes[cls_key]["skills"].add(doc.guessed_skill)

        if doc.guessed_skill:
            skill_key = slugify(doc.guessed_skill)
            skills.setdefault(skill_key, {
                "name": doc.guessed_skill,
                "docs": [],
                "class": doc.guessed_class,
                "tags": set(),
            })
            skills[skill_key]["docs"].append(doc.doc_id)
            skills[skill_key]["tags"].update(doc.tags)

        for cmd in extract_commands(doc.text):
            key = slugify(cmd)
            entry = commands.setdefault(key, {
                "command": cmd,
                "docs": [],
                "categories": set(),
                "class": None,
                "skill": None,
            })
            entry["docs"].append(doc.doc_id)
            entry["categories"].add(doc.category)
            entry["class"] = entry["class"] or doc.guessed_class
            entry["skill"] = entry["skill"] or doc.guessed_skill
            relations.append({
                "source": doc.doc_id,
                "relation": "mentions_command",
                "target": cmd,
            })

        for aff in extract_named_terms(doc.text, AFFLICTION_TERMS):
            key = slugify(aff)
            entry = afflictions.setdefault(key, {
                "name": aff,
                "docs": [],
                "commands": set(),
                "classes": set(),
            })
            entry["docs"].append(doc.doc_id)
            if doc.guessed_class:
                entry["classes"].add(doc.guessed_class)
            for cmd in extract_commands(doc.text):
                entry["commands"].add(cmd)
            relations.append({
                "source": doc.doc_id,
                "relation": "mentions_affliction",
                "target": aff,
            })

        for defence in extract_named_terms(doc.text, DEFENCE_TERMS):
            key = slugify(defence)
            entry = defences.setdefault(key, {
                "name": defence,
                "docs": [],
                "classes": set(),
            })
            entry["docs"].append(doc.doc_id)
            if doc.guessed_class:
                entry["classes"].add(doc.guessed_class)
            relations.append({
                "source": doc.doc_id,
                "relation": "mentions_defence",
                "target": defence,
            })

        if doc.category in {"ability", "command", "curing"} or doc.guessed_class or doc.guessed_skill:
            ability_name = doc.title.strip()
            key = slugify(ability_name)
            entry = abilities.setdefault(key, {
                "name": ability_name,
                "docs": [],
                "class": doc.guessed_class,
                "skill": doc.guessed_skill,
                "category": doc.category,
                "tags": set(),
                "commands": set(),
                "related_topics": set(),
            })
            entry["docs"].append(doc.doc_id)
            entry["tags"].update(doc.tags)
            entry["commands"].update(extract_commands(doc.text))
            entry["related_topics"].update(related_topics_from_text(doc.text))

        for idx, (heading, body) in enumerate(split_into_chunks(doc.title, doc.text), start=1):
            chunks.append(
                ChunkRecord(
                    chunk_id=f"{doc.doc_id}_chunk_{idx:03d}",
                    doc_id=doc.doc_id,
                    title=doc.title,
                    url=doc.url,
                    category=doc.category,
                    heading=heading,
                    text=body,
                    tags=doc.tags,
                )
            )

    # Finalize set fields.
    def finalize(mapping: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
        rows = []
        for _, value in sorted(mapping.items(), key=lambda kv: kv[1].get("name") or kv[1].get("command") or ""):
            row = {}
            for k, v in value.items():
                if isinstance(v, set):
                    row[k] = sorted(v)
                else:
                    row[k] = v
            rows.append(row)
        return rows

    command_rows = finalize(commands)
    ability_rows = finalize(abilities)
    affliction_rows = finalize(afflictions)
    defence_rows = finalize(defences)
    class_rows = finalize(classes)
    skill_rows = finalize(skills)

    write_json(indexes_dir / "command_index.json", command_rows)
    write_json(indexes_dir / "ability_index.json", ability_rows)
    write_json(indexes_dir / "affliction_index.json", affliction_rows)
    write_json(indexes_dir / "defence_index.json", defence_rows)
    write_json(indexes_dir / "class_index.json", class_rows)
    write_json(indexes_dir / "skill_index.json", skill_rows)
    write_json(indexes_dir / "relations.json", relations)
    write_jsonl(chunks_dir / "kb_chunks.jsonl", (asdict(c) for c in chunks))

    # Handy command-only flat file for Mudlet / quick grep.
    write_json(indexes_dir / "command_names.json", sorted({row["command"] for row in command_rows}))

    summary = {
        "docs_processed": len(docs),
        "chunks_created": len(chunks),
        "category_counts": dict(category_counts),
        "commands_found": len(command_rows),
        "abilities_found": len(ability_rows),
        "afflictions_found": len(affliction_rows),
        "defences_found": len(defence_rows),
        "classes_found": len(class_rows),
        "skills_found": len(skill_rows),
    }
    write_json(processed_dir / "summary.json", summary)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Post-process Achaea spider dataset into AI-ready indexes.")
    parser.add_argument("--dataset-dir", default="achaea_help_dataset", help="Spider dataset directory")
    parser.add_argument("--chunks-only", action="store_true", help="Only regenerate normalized docs and retrieval chunks")
    args = parser.parse_args()

    dataset_dir = Path(args.dataset_dir)
    if not dataset_dir.exists():
        raise SystemExit(f"Dataset directory not found: {dataset_dir}")

    docs = build_doc_records(dataset_dir)
    if not docs:
        raise SystemExit("No documents found. Run the spider first and verify clean_text/ contains files.")

    summary = build_indexes(docs, dataset_dir)

    print("Post-processing complete.")
    for key, value in summary.items():
        print(f"- {key}: {value}")
    print(f"Output: {dataset_dir / 'processed'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
