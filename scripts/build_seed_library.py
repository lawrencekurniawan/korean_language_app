#!/usr/bin/env python3
"""Build the bundled starter library from openly licensed Korean sources.

The output is committed to the repository because it contains only
public-domain texts and CC BY-SA 4.0 Wikipedia extracts, with attribution
recorded per article. No textbook, subtitle, or exam content is included.

Usage:
    python3 scripts/build_seed_library.py
"""

from __future__ import annotations

import hashlib
import html as html_lib
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

WIKIPEDIA_API = "https://ko.wikipedia.org/w/api.php"
WIKISOURCE_API = "https://ko.wikisource.org/w/api.php"
USER_AGENT = "SoriSeedBuilder/0.1 (personal Korean learning app; contact: lawrencekurniawan@gmail.com)"

TARGET_BYTES = 1_850_000
MAX_ARTICLES = 320
MAX_EXTRACT_CHARS = 8_000
MIN_EXTRACT_CHARS = 700

CATEGORIES = [
    "분류:한국어",
    "분류:한글",
    "분류:대한민국의 문화",
    "분류:한국 요리",
    "분류:서울특별시",
    "분류:대한민국의 역사",
    "분류:대한민국의 지리",
    "분류:대한민국의 대중문화",
    "분류:대한민국의 교육",
    "분류:대한민국의 교통",
    "분류:대한민국의 사회",
    "분류:한국 문학",
    "분류:한국의 명절",
    "분류:대한민국의 스포츠",
    "분류:대한민국의 과학기술",
]

WIKISOURCE_TITLES = [
    "심청전",
    "홍길동전 (30장 경판본)",
    "흥부전 (경판 25장본)",
    "일설 춘향전",
]

BLOCKED_TITLE_PARTS = (
    "목록",
    "연표",
    "연혁",
    "분류:",
    "틀:",
    "위키백과:",
    "파일:",
    "동음이의",
)


def api_get(endpoint: str, params: dict) -> dict:
    params = {**params, "format": "json", "formatversion": "2"}
    url = endpoint + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def category_members(category: str) -> list[str]:
    titles: list[str] = []
    continuation: dict = {}
    while True:
        data = api_get(
            WIKIPEDIA_API,
            {
                "action": "query",
                "list": "categorymembers",
                "cmtitle": category,
                "cmnamespace": "0",
                "cmlimit": "500",
                **continuation,
            },
        )
        for item in data.get("query", {}).get("categorymembers", []):
            title = item.get("title", "")
            if title and not any(part in title for part in BLOCKED_TITLE_PARTS):
                titles.append(title)
        if "continue" not in data:
            break
        continuation = data["continue"]
    return titles


def fetch_extracts(endpoint: str, titles: list[str]) -> dict[str, str]:
    """Fetch full plain-text extracts one page at a time.

    The TextExtracts API only returns one full extract per request when
    ``explaintext`` is enabled, so batching silently drops pages.
    """
    results: dict[str, str] = {}
    for index, title in enumerate(titles):
        for attempt in range(4):
            try:
                data = api_get(
                    endpoint,
                    {
                        "action": "query",
                        "prop": "extracts",
                        "explaintext": "1",
                        "exsectionformat": "plain",
                        "exlimit": "1",
                        "redirects": "1",
                        "titles": title,
                    },
                )
                pages = data.get("query", {}).get("pages", [])
                if pages:
                    extract = pages[0].get("extract", "")
                    if extract:
                        results[title] = extract
                break
            except urllib.error.HTTPError as error:
                if error.code == 429 and attempt < 3:
                    time.sleep(4 * (attempt + 1))
                    continue
                print(f"extract failed for {title}: {error}", file=sys.stderr)
                break
            except Exception as error:  # noqa: BLE001
                print(f"extract failed for {title}: {error}", file=sys.stderr)
                break
        if index % 25 == 0:
            print(f"fetched {index}/{len(titles)} extracts", file=sys.stderr)
        time.sleep(0.35)
    return results


def fetch_wikisource_texts(titles: list[str]) -> dict[str, str]:
    """Fetch Wikisource pages through the parse API and strip HTML.

    Wikisource's TextExtracts output is only a short page header for most
    classical texts, so the rendered HTML is used instead.
    """
    results: dict[str, str] = {}
    for index, title in enumerate(titles):
        for attempt in range(3):
            try:
                data = api_get(
                    WIKISOURCE_API,
                    {
                        "action": "parse",
                        "page": title,
                        "prop": "text",
                        "redirects": "1",
                    },
                )
                html = data.get("parse", {}).get("text", "")
                if html:
                    results[title] = strip_html(html)
                break
            except urllib.error.HTTPError as error:
                if error.code == 429 and attempt < 2:
                    time.sleep(4 * (attempt + 1))
                    continue
                print(f"wikisource failed for {title}: {error}", file=sys.stderr)
                break
            except Exception as error:  # noqa: BLE001
                print(f"wikisource failed for {title}: {error}", file=sys.stderr)
                break
        time.sleep(0.35)
    return results


def strip_html(html: str) -> str:
    html = re.sub(r"(?is)<(style|script)[^>]*>.*?</\1>", "", html)
    html = re.sub(r"(?is)<!--.*?-->", "", html)
    html = re.sub(r"(?i)<br\s*/?>", "\n", html)
    html = re.sub(r"(?i)</(p|div|h[1-6]|li|tr|blockquote)>", "\n", html)
    text = re.sub(r"<[^>]+>", " ", html)
    text = html_lib.unescape(text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = []
    for line in text.splitlines():
        line = re.sub(r"[ \t]{2,}", " ", line).strip()
        if not line:
            continue
        # Drop CSS fragments and navigation chrome that can survive the tag strip.
        if line.startswith(".") and "{" in line:
            continue
        if hangul_ratio(line) < 0.15 and len(line) < 30:
            continue
        lines.append(line)
    return "\n".join(lines)


def hangul_ratio(text: str) -> float:
    if not text:
        return 0.0
    hangul = len(re.findall(r"[\uac00-\ud7a3]", text))
    letters = len(re.findall(r"[^\s\d\W]", text))
    return hangul / max(letters, 1)


WIKISOURCE_START_MARKERS = {
    "심청전": "심쳥젼권지상이라",
    "홍길동전 (30장 경판본)": "화셜 됴션국",
    "흥부전 (경판 25장본)": "흥부젼 권지단",
    "일설 춘향전": "『여바라 방자야!』",
}

BOILERPLATE_MARKERS = (
    "자매 프로젝트",
    "위키백과",
    "위키문헌",
    "위키데이터",
    "이 문헌은",
    "이 문서는",
    "스캔 파일",
    "관련 글꼴",
    "문서 끼워넣기",
    "교정 및",
)


def clean_extract(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = text.strip()
    return text


def clean_wikipedia_text(text: str) -> str:
    """Remove citation markers and short section headings from an extract."""
    text = clean_extract(text)
    lines = []
    for line in text.split("\n"):
        line = re.sub(r"\[\d+\]|\[\s*편집\s*\]|\[\s*출처\s*\]", "", line).strip()
        if not line:
            continue
        if len(line) <= 24 and not re.search(r"[.!?。！？…][\"'”’』」\]]*$", line):
            continue
        lines.append(line)
    return "\n".join(lines)


def clean_wikisource_text(title: str, text: str) -> str:
    """Drop the MediaWiki preamble and page chrome from a Wikisource text."""
    text = clean_extract(text)
    marker = WIKISOURCE_START_MARKERS.get(title)
    if marker and marker in text:
        text = text[text.index(marker):]

    lines = []
    for line in text.split("\n"):
        line = re.sub(r"\[\s*편집\s*\]", "", line).strip()
        if not line:
            continue
        if any(marker in line for marker in BOILERPLATE_MARKERS):
            continue
        lines.append(line)
    return "\n".join(lines)


def truncate_at_sentence(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    window = text[:limit]
    cut = max(
        window.rfind("다."),
        window.rfind("요."),
        window.rfind("."),
        window.rfind("?"),
        window.rfind("!"),
    )
    if cut > limit * 0.55:
        return window[: cut + 1].strip()
    return window.rsplit(" ", 1)[0].strip()


def is_useful(text: str) -> bool:
    if len(text) < MIN_EXTRACT_CHARS:
        return False
    if hangul_ratio(text) < 0.35:
        return False
    if text.count("\n") < 2:
        return False
    if re.search(r"(각주|출처|참고 문헌|외부 링크)\s*$", text):
        return False
    return True


def wikipedia_article(title: str, text: str) -> dict:
    return {
        "id": "wikipedia-ko-" + hashlib.sha1(title.encode("utf-8")).hexdigest()[:16],
        "title": title,
        "source": "Korean Wikipedia",
        "sourceURL": "https://ko.wikipedia.org/wiki/"
        + urllib.parse.quote(title.replace(" ", "_")),
        "license": "CC BY-SA 4.0",
        "attribution": "Korean Wikipedia contributors",
        "kind": "prose",
        "text": text,
    }


def wikisource_article(title: str, text: str) -> dict:
    return {
        "id": "wikisource-ko-" + hashlib.sha1(title.encode("utf-8")).hexdigest()[:16],
        "title": title,
        "source": "Korean Wikisource",
        "sourceURL": "https://ko.wikisource.org/wiki/"
        + urllib.parse.quote(title.replace(" ", "_")),
        "license": "Public domain",
        "attribution": "Korean Wikisource",
        "kind": "prose",
        "text": text,
    }


def main() -> int:
    output = Path(__file__).resolve().parent.parent / "Sori/Resources/Content/library-seed.json"
    pd_only = "--pd-only" in sys.argv

    if pd_only:
        existing = json.loads(output.read_text(encoding="utf-8"))
        articles: list[dict] = existing.get("articles", [])
        seen_hashes = {
            hashlib.sha256(article["text"].encode("utf-8")).hexdigest()
            for article in articles
        }
        total_bytes = len(output.read_bytes())
        print(f"loaded {len(articles)} existing articles", file=sys.stderr)
    else:
        titles: list[str] = []
        seen_titles: set[str] = set()
        for category in CATEGORIES:
            try:
                members = category_members(category)
            except Exception as error:  # noqa: BLE001
                print(f"category failed: {category}: {error}", file=sys.stderr)
                continue
            print(f"{category}: {len(members)} members", file=sys.stderr)
            for title in members:
                if title not in seen_titles:
                    seen_titles.add(title)
                    titles.append(title)

        print(f"candidate titles: {len(titles)}", file=sys.stderr)

        articles = []
        seen_hashes = set()
        total_bytes = 0

        for index in range(0, len(titles), 20):
            batch = titles[index : index + 20]
            try:
                extracts = fetch_extracts(WIKIPEDIA_API, batch)
            except Exception as error:  # noqa: BLE001
                print(f"extract batch failed: {error}", file=sys.stderr)
                continue

            for title, raw in extracts.items():
                text = truncate_at_sentence(clean_wikipedia_text(raw), MAX_EXTRACT_CHARS)
                if not is_useful(text):
                    continue
                digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
                if digest in seen_hashes:
                    continue
                seen_hashes.add(digest)
                article = wikipedia_article(title, text)
                size = len(json.dumps(article, ensure_ascii=False).encode("utf-8"))
                articles.append(article)
                total_bytes += size
                if total_bytes >= TARGET_BYTES or len(articles) >= MAX_ARTICLES:
                    break
            if total_bytes >= TARGET_BYTES or len(articles) >= MAX_ARTICLES:
                break
            if index % 100 == 0:
                print(
                    f"progress: {len(articles)} articles, {total_bytes / 1_000_000:.2f} MB",
                    file=sys.stderr,
                )
            time.sleep(0.2)

        print(
            f"wikipedia: {len(articles)} articles, {total_bytes / 1_000_000:.2f} MB",
            file=sys.stderr,
        )

    try:
        pd_texts = fetch_wikisource_texts(WIKISOURCE_TITLES)
    except Exception as error:  # noqa: BLE001
        print(f"wikisource failed: {error}", file=sys.stderr)
        pd_texts = {}

    pd_count = 0
    for title in WIKISOURCE_TITLES:
        raw = pd_texts.get(title)
        if not raw:
            continue
        text = truncate_at_sentence(clean_wikisource_text(title, raw), 12_000)
        if len(text) < 500:
            continue
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if digest in seen_hashes:
            continue
        seen_hashes.add(digest)
        article = wikisource_article(title, text)
        total_bytes += len(json.dumps(article, ensure_ascii=False).encode("utf-8"))
        articles.append(article)
        pd_count += 1

    print(
        f"final: {len(articles)} articles ({pd_count} new public domain), "
        f"{total_bytes / 1_000_000:.2f} MB",
        file=sys.stderr,
    )

    payload = {
        "version": "2026.10.3",
        "generatedAt": "2026-10-21",
        "description": "Starter library of real Korean texts for reading and typing practice.",
        "articles": articles,
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"wrote {output} ({output.stat().st_size / 1_000_000:.2f} MB)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
