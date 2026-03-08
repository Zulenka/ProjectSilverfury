import argparse
import json
import os
import re
from pathlib import Path
from collections import defaultdict

HELP_REF_RE = re.compile(r'\bHELP\s+([A-Z0-9][A-Z0-9\-\' ]{1,80})\b', re.IGNORECASE)
CMD_PATTERNS = [
    re.compile(r'\bSyntax\s*:\s*(.+)', re.IGNORECASE),
    re.compile(r'\bUsage\s*:\s*(.+)', re.IGNORECASE),
    re.compile(r'\bCommand\s*:\s*(.+)', re.IGNORECASE),
]

CATEGORY_KEYWORDS = {
    'affliction': ['affliction', 'afflictions', 'cure', 'curing', 'herb', 'salve', 'focus', 'smoke'],
    'defence': ['defence', 'defenses', 'defences', 'shield', 'rebounding', 'fangbarrier', 'insomnia'],
    'class': ['class', 'guild', 'house', 'runewarden', 'serpent', 'occultist', 'dragon', 'monk', 'apostate'],
    'skill': ['skill', 'abilities', 'ability', 'lessons', 'discipline'],
    'combat': ['battle', 'combat', 'prone', 'parry', 'balance', 'equilibrium', 'limb'],
    'command': ['command', 'commands', 'syntax', 'usage'],
}


def normalize_ws(text: str) -> str:
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r'[^a-z0-9]+', '-', text)
    return text.strip('-') or 'untitled'


def guess_category(title: str, text: str) -> str:
    hay = f"{title}\n{text[:4000]}".lower()
    scores = {k: 0 for k in CATEGORY_KEYWORDS}
    for cat, kws in CATEGORY_KEYWORDS.items():
        for kw in kws:
            if kw in hay:
                scores[cat] += 1
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else 'general'


def find_text_dir(dataset_dir: Path) -> Path | None:
    candidates = [
        dataset_dir / 'clean_text',
        dataset_dir / 'help_clean',
        dataset_dir / 'text',
    ]
    for c in candidates:
        if c.exists() and c.is_dir():
            return c
    # recursive fallback
    for c in dataset_dir.rglob('*'):
        if c.is_dir() and c.name in {'clean_text', 'help_clean', 'text'}:
            return c
    return None


def find_page_meta(dataset_dir: Path):
    page_dir = dataset_dir / 'pages'
    meta = {}
    if not page_dir.exists():
        return meta
    for p in page_dir.glob('*.json'):
        try:
            obj = json.loads(p.read_text(encoding='utf-8'))
            pid = str(obj.get('id', p.stem))
            meta[pid] = obj
        except Exception:
            continue
    return meta


def extract_title(text: str, fallback: str) -> str:
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    if not lines:
        return fallback
    for ln in lines[:8]:
        if 3 <= len(ln) <= 120:
            return ln
    return fallback


def extract_commands(text: str):
    commands = set()
    for pat in CMD_PATTERNS:
        for m in pat.finditer(text):
            line = m.group(1).strip()
            line = re.sub(r'\s+', ' ', line)
            if line:
                commands.add(line[:200])
    # Imperative-ish all-caps or one-line command syntax
    for line in text.splitlines():
        s = line.strip()
        if 1 <= len(s) <= 120:
            if re.match(r'^[A-Z][A-Z0-9 _\-\[\]<>|/]+$', s):
                commands.add(s)
    return sorted(commands)


def chunk_text(doc_id: str, title: str, text: str, chunk_size: int = 1200, overlap: int = 150):
    chunks = []
    start = 0
    idx = 0
    while start < len(text):
        end = min(len(text), start + chunk_size)
        chunk = text[start:end].strip()
        if chunk:
            chunks.append({
                'chunk_id': f'{doc_id}::chunk_{idx:04d}',
                'doc_id': doc_id,
                'title': title,
                'text': chunk,
            })
        idx += 1
        if end == len(text):
            break
        start = max(end - overlap, start + 1)
    return chunks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dataset-dir', default='achaea_help_dataset')
    ap.add_argument('--chunks-only', action='store_true')
    args = ap.parse_args()

    dataset_dir = Path(args.dataset_dir)
    if not dataset_dir.exists():
        raise SystemExit(f'Dataset directory not found: {dataset_dir}')

    text_dir = find_text_dir(dataset_dir)
    if text_dir is None:
        raise SystemExit('No documents found. Could not locate clean_text/ or help_clean/.')

    txt_files = sorted(text_dir.rglob('*.txt'))
    if not txt_files:
        raise SystemExit(f'No documents found in {text_dir}.')

    processed = dataset_dir / 'processed'
    idx_dir = processed / 'indexes'
    kb_dir = processed / 'knowledge_base'
    ret_dir = processed / 'retrieval'
    for d in [idx_dir, kb_dir, ret_dir]:
        d.mkdir(parents=True, exist_ok=True)

    page_meta = find_page_meta(dataset_dir)

    documents = []
    chunks = []
    command_index = defaultdict(list)
    ability_index = defaultdict(list)
    affliction_index = defaultdict(list)
    defence_index = defaultdict(list)
    class_index = defaultdict(list)
    skill_index = defaultdict(list)
    relations = []

    for fp in txt_files:
        raw = fp.read_text(encoding='utf-8', errors='ignore')
        text = normalize_ws(raw)
        if not text:
            continue
        stem = fp.stem
        meta = page_meta.get(stem, {})
        title = meta.get('title') or extract_title(text, stem)
        url = meta.get('url')
        doc_id = f'doc_{stem}'
        category = guess_category(title, text)
        help_refs = sorted({m.group(1).strip() for m in HELP_REF_RE.finditer(text)})
        commands = extract_commands(text)

        doc = {
            'doc_id': doc_id,
            'source_file': str(fp.relative_to(dataset_dir)),
            'title': title,
            'url': url,
            'category': category,
            'text': text,
            'help_refs': help_refs,
            'commands': commands,
        }
        documents.append(doc)
        chunks.extend(chunk_text(doc_id, title, text))

        title_l = title.lower()
        text_l = text.lower()
        for cmd in commands:
            key = cmd.lower()
            command_index[key].append({'doc_id': doc_id, 'title': title, 'url': url})
        # crude classification into indexes
        names = {title}
        names.update(help_refs)
        for name in names:
            n = name.strip()
            nl = n.lower()
            ref = {'doc_id': doc_id, 'title': title, 'url': url, 'name': n}
            if any(k in text_l or k in title_l for k in ['affliction', 'afflictions', 'cures', 'cure']):
                affliction_index[nl].append(ref)
            if any(k in text_l or k in title_l for k in ['defence', 'defenses', 'defences', 'shield', 'rebounding']):
                defence_index[nl].append(ref)
            if any(k in text_l or k in title_l for k in ['skill', 'ability', 'abilities']):
                ability_index[nl].append(ref)
                skill_index[nl].append(ref)
            if any(k in nl for k in ['runewarden', 'dragon', 'serpent', 'monk', 'apostate', 'occultist', 'sentinel', 'infernal', 'priest', 'bard', 'jester', 'shaman', 'alchemist', 'magi', 'blademaster', 'sylvan', 'paladin']):
                class_index[nl].append(ref)
        for ref in help_refs:
            relations.append({'from_doc_id': doc_id, 'to_help': ref, 'type': 'help_reference'})

    if not documents:
        raise SystemExit(f'No documents found in {text_dir}.')

    def dump_json(path: Path, obj):
        path.write_text(json.dumps(obj, indent=2, ensure_ascii=False), encoding='utf-8')

    def dump_jsonl(path: Path, rows):
        with path.open('w', encoding='utf-8') as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + '\n')

    dump_jsonl(kb_dir / 'documents.jsonl', documents)
    dump_jsonl(ret_dir / 'kb_chunks.jsonl', chunks)
    dump_json(idx_dir / 'command_index.json', dict(command_index))
    dump_json(idx_dir / 'ability_index.json', dict(ability_index))
    dump_json(idx_dir / 'affliction_index.json', dict(affliction_index))
    dump_json(idx_dir / 'defence_index.json', dict(defence_index))
    dump_json(idx_dir / 'class_index.json', dict(class_index))
    dump_json(idx_dir / 'skill_index.json', dict(skill_index))
    dump_json(idx_dir / 'relations.json', relations)
    dump_json(idx_dir / 'command_names.json', sorted(command_index.keys()))
    summary = {
        'dataset_dir': str(dataset_dir),
        'text_dir': str(text_dir),
        'documents': len(documents),
        'chunks': len(chunks),
        'commands': len(command_index),
        'help_references': len(relations),
    }
    dump_json(processed / 'summary.json', summary)
    print(f"Processed {len(documents)} documents from {text_dir}")
    print(f"Wrote outputs to {processed}")

if __name__ == '__main__':
    main()
