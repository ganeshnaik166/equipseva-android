"""Google Custom Search Engine — env-gated optional source.

Cost: free for first 100 queries/day, $5/1000 after. Highest result
relevance of any source. Used as the "tiebreaker" when other sources
disagree on which candidate matches the SKU best.

Setup:
  1. Create a CSE at https://programmablesearchengine.google.com/
     - Sites to search: leave empty (search whole web)
     - Image search: ON
  2. Get the API key at https://console.cloud.google.com/ (enable
     "Custom Search API")
  3. Set env vars:
       GOOGLE_CSE_API_KEY=<your-api-key>
       GOOGLE_CSE_CX=<your-engine-id>

If neither env var is set, this module exports `provider = None` and the
ensemble silently skips it.
"""
from __future__ import annotations

import os

import requests

from sources import Candidate, is_clean_url

NAME = "google_cse"
PRIOR = 0.85

API_KEY = os.environ.get("GOOGLE_CSE_API_KEY")
CX = os.environ.get("GOOGLE_CSE_CX")


def _query(item: dict) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    return " ".join([p for p in parts if p]) + " medical equipment product photo"


class _GoogleCseProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        if not API_KEY or not CX:
            return []
        try:
            r = requests.get(
                "https://www.googleapis.com/customsearch/v1",
                params={
                    "key": API_KEY,
                    "cx": CX,
                    "q": _query(item),
                    "searchType": "image",
                    "num": str(min(k, 10)),
                    "imgSize": "large",
                },
                timeout=10,
            )
            if r.status_code != 200:
                return []
            items = r.json().get("items", [])
        except Exception:
            return []

        brand = (item.get("brand") or "").lower()
        out: list[Candidate] = []
        for it in items:
            url = it.get("link")
            if not url or not is_clean_url(url):
                continue
            out.append(Candidate(
                url=url, provider=NAME, prior=PRIOR,
                hint_brand=brand and brand.split()[0] in url.lower(),
            ))
        return out


provider = _GoogleCseProvider() if (API_KEY and CX) else None
