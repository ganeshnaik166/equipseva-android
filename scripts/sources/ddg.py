"""DuckDuckGo Images — broad-net baseline (no API key)."""
from __future__ import annotations

import time
from sources import Candidate, is_clean_url, ddg_throttle, ddg_release

NAME = "ddg"
PRIOR = 0.6


def _query(item: dict) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    base = " ".join([p for p in parts if p])
    return f"{base} medical equipment product photo white background isolated"


class _DdgProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        from duckduckgo_search import DDGS
        q = _query(item)
        brand = (item.get("brand") or "").lower()
        delay = 4.0
        for _ in range(3):
            ddg_throttle()
            try:
                try:
                    with DDGS() as ddgs:
                        results = list(ddgs.images(q, max_results=k, safesearch="off"))
                except Exception as e:
                    msg = str(e).lower()
                    if "ratelimit" in msg or "202" in msg or "rate" in msg:
                        time.sleep(delay)
                        delay *= 2
                        continue
                    return []
            finally:
                ddg_release()
            out: list[Candidate] = []
            for r in results:
                url = r.get("image")
                if not url or not is_clean_url(url):
                    continue
                out.append(Candidate(
                    url=url, provider=NAME, prior=PRIOR,
                    hint_brand=brand and brand.split()[0] in url.lower(),
                ))
            return out
        return []


provider = _DdgProvider()
