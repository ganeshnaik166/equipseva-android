"""
10-source image-candidate ensemble for catalog_reference_items.

Each provider module exports a `provider` singleton implementing the
SourceProvider protocol. The main pipeline collects candidates from all
providers in parallel, scores them via CLIP, and re-hosts the winner.

Anti-signal URL substrings (rejected at provider level OR ensemble level)
and trusted-domain bonuses live in this module so every provider stays in
sync.
"""
from __future__ import annotations

import threading
import time
from dataclasses import dataclass


# All DDG-using providers (ddg, manufacturer, listings, threed) share this
# lock so we never have more than one in-flight DDG image request. Stops
# the 202 Ratelimit cascade we hit when running them in parallel.
DDG_LOCK = threading.Lock()
DDG_MIN_INTERVAL_SEC = 1.5
_LAST_DDG_CALL = [0.0]


def ddg_throttle():
    """Acquire DDG_LOCK, sleep until DDG_MIN_INTERVAL_SEC has passed since
    the previous DDG call, then return. Caller must use as a context manager
    or release the lock manually after the DDG call returns."""
    DDG_LOCK.acquire()
    elapsed = time.time() - _LAST_DDG_CALL[0]
    if elapsed < DDG_MIN_INTERVAL_SEC:
        time.sleep(DDG_MIN_INTERVAL_SEC - elapsed)


def ddg_release():
    _LAST_DDG_CALL[0] = time.time()
    DDG_LOCK.release()


@dataclass
class Candidate:
    url: str
    provider: str
    prior: float          # source-trust weight, 0..1
    hint_brand: bool = False   # True if brand string appears in URL/filename


# URL substrings that should never feed into the candidate pool. We hate
# social-media stock photos, slide-deck thumbnails, and clickbait.
ANTI_SIGNALS = (
    "youtube.", "youtu.be",
    "pinterest.",
    "slideshare.",
    "tiktok.",
    "facebook.", "fbcdn.",
    "instagram.",
    "aliexpress.com",
    "indiamart.com",       # ToS — can't legally re-host their photos
    "medikabazaar.com",    # competitor, ToS
    "shutterstock.",       # watermarked stock
    "gettyimages.",        # watermarked stock
    "alamy.com",           # watermarked stock
    "stock.adobe.",
    "amazon.in", "amazon.com",  # generic retail photos, low quality
)


def is_clean_url(url: str) -> bool:
    u = url.lower()
    return not any(bad in u for bad in ANTI_SIGNALS)


# Provider load order doesn't matter functionally — we run them all in
# parallel — but listing them here is a single source of truth for what
# the ensemble looks like.
def all_providers():
    """Lazy import so a missing optional dep in one provider doesn't break
    the rest of the ensemble. Returns the list of available SourceProviders."""
    providers = []
    for module_name in (
        "ddg", "bing", "yandex",
        "gem", "wikimedia",
        "manufacturer", "listings", "threed",
        "google_cse",
    ):
        try:
            mod = __import__(f"sources.{module_name}", fromlist=["provider"])
            if hasattr(mod, "provider") and mod.provider is not None:
                providers.append(mod.provider)
        except Exception as e:
            print(f"  [sources] skipping {module_name}: {e}")
    return providers
