import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import os
import json
import time
from tqdm import tqdm

BASE_URL = "https://www.achaea.com"
START_URL = "https://www.achaea.com/game-help"

HEADERS = {
    "User-Agent": "Mozilla/5.0"
}

OUTPUT_DIR = "achaea_help_dataset"

RAW_DIR = os.path.join(OUTPUT_DIR, "raw_html")
TEXT_DIR = os.path.join(OUTPUT_DIR, "clean_text")

os.makedirs(RAW_DIR, exist_ok=True)
os.makedirs(TEXT_DIR, exist_ok=True)

visited = set()
queue = [START_URL]

dataset = []


def clean_text(soup):

    for tag in soup(["script", "style"]):
        tag.decompose()

    text = soup.get_text("\n")

    lines = [l.strip() for l in text.splitlines()]
    lines = [l for l in lines if l]

    return "\n".join(lines)


def extract_links(soup):

    links = []

    for a in soup.find_all("a", href=True):

        href = a["href"]

        if "game-help" in href:

            full = urljoin(BASE_URL, href)

            links.append(full)

    return links


def save_file(path, content):

    with open(path, "w", encoding="utf8") as f:
        f.write(content)


print("Starting spider...\n")

while queue:

    url = queue.pop(0)

    if url in visited:
        continue

    visited.add(url)

    print("Crawling:", url)

    try:

        r = requests.get(url, headers=HEADERS, timeout=15)

        html = r.text

    except:

        continue

    soup = BeautifulSoup(html, "html.parser")

    # save raw html
    file_id = str(len(visited))

    raw_path = os.path.join(RAW_DIR, f"{file_id}.html")
    save_file(raw_path, html)

    text = clean_text(soup)

    text_path = os.path.join(TEXT_DIR, f"{file_id}.txt")
    save_file(text_path, text)

    title = soup.title.text if soup.title else "unknown"

    dataset.append(
        {
            "id": file_id,
            "url": url,
            "title": title,
            "text_file": text_path,
        }
    )

    links = extract_links(soup)

    for link in links:

        if link not in visited:
            queue.append(link)

    time.sleep(0.5)


with open(os.path.join(OUTPUT_DIR, "dataset.json"), "w") as f:

    json.dump(dataset, f, indent=2)

print("\nSpider finished.")
print("Pages scraped:", len(dataset))