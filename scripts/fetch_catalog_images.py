#!/usr/bin/env python3
"""
Auto-fetch product images for public.catalog_reference_items.

Pipeline per item:
  1. Build query: "<brand> <model> <item_name> medical equipment"
  2. DuckDuckGo image search → top 5 candidate URLs (no API key)
  3. Download candidates, score each with CLIP against the query text
  4. Pick the highest-scoring candidate above MIN_CONFIDENCE
  5. Upload winner to Supabase Storage `catalog-reference-images/{id}.jpg`
  6. PATCH the row with image_url, source, confidence, needs_image_review=false

Items where no candidate clears the threshold are flagged for manual review
(needs_image_review stays true).

Usage:
  # Dry run on first 5 items, no upload, just print scores:
  python3 scripts/fetch_catalog_images.py --limit 5 --dry-run

  # Full run, writes to Supabase. Requires service-role key.
  SUPABASE_SERVICE_ROLE_KEY=<key> \
  python3 scripts/fetch_catalog_images.py

  # Resume — only items where needs_image_review=true:
  SUPABASE_SERVICE_ROLE_KEY=<key> \
  python3 scripts/fetch_catalog_images.py --only-pending

Env:
  SUPABASE_URL                 (defaults to local.properties)
  SUPABASE_SERVICE_ROLE_KEY    (required unless --dry-run)
"""
from __future__ import annotations

import argparse
import io
import json
import os
import pathlib
import sys
import time
from dataclasses import dataclass

import requests
import torch
import open_clip
from PIL import Image
from duckduckgo_search import DDGS

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE_JSON = REPO_ROOT / "data" / "hospital_equipment_catalogue.json"
PICKS_JSON = REPO_ROOT / "data" / "catalog_image_picks.json"  # audit log
BUCKET = "catalog-reference-images"
MIN_CONFIDENCE = 0.22       # cosine sim threshold
TOP_K_CANDIDATES = 8        # bumped from 5 — we filter more aggressively now
HTTP_TIMEOUT = 8
USER_AGENT = "Mozilla/5.0 (compatible; EquipSeva-CatalogBot/1.0; +https://equipseva.com)"

# Quality gates so the marketplace cards always show clean white-BG product
# shots at decent resolution.
MIN_IMAGE_WIDTH = 600       # reject candidates smaller than this on shorter side
TARGET_WIDTH = 1200         # final width after rembg + upscale


# ─────────────────────────────────────────────────────────────────────────────
# Config plumbing

def load_supabase_url() -> str:
    if env := os.environ.get("SUPABASE_URL"):
        return env
    lp = REPO_ROOT / "local.properties"
    if lp.exists():
        for line in lp.read_text().splitlines():
            if line.startswith("SUPABASE_URL="):
                return line.split("=", 1)[1].strip()
    raise RuntimeError("SUPABASE_URL not set (env or local.properties)")


def load_service_key() -> str | None:
    return os.environ.get("SUPABASE_SERVICE_ROLE_KEY")


# ─────────────────────────────────────────────────────────────────────────────
# CLIP scorer

@dataclass
class ClipScorer:
    model: torch.nn.Module
    preprocess: object
    tokenizer: object
    device: str

    @classmethod
    def load(cls) -> "ClipScorer":
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        print(f"[clip] loading openai/clip-vit-base-patch32 on {device}…")
        model, _, preprocess = open_clip.create_model_and_transforms(
            "ViT-B-32", pretrained="openai"
        )
        tokenizer = open_clip.get_tokenizer("ViT-B-32")
        model = model.to(device).eval()
        return cls(model=model, preprocess=preprocess, tokenizer=tokenizer, device=device)

    @torch.no_grad()
    def score(self, image_bytes: bytes, text: str) -> float:
        try:
            img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception:
            return 0.0
        img_tensor = self.preprocess(img).unsqueeze(0).to(self.device)
        text_tokens = self.tokenizer([text]).to(self.device)
        img_feat = self.model.encode_image(img_tensor)
        txt_feat = self.model.encode_text(text_tokens)
        img_feat = img_feat / img_feat.norm(dim=-1, keepdim=True)
        txt_feat = txt_feat / txt_feat.norm(dim=-1, keepdim=True)
        return float((img_feat * txt_feat).sum(dim=-1).item())


# ─────────────────────────────────────────────────────────────────────────────
# Search + download

def build_query(item: dict) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    base = " ".join([p for p in parts if p])
    # "white background isolated" biases DDG toward catalogue-style product
    # shots over hospital-room or installed-on-site photos.
    return f"{base} medical equipment product photo white background isolated"


def ddg_image_urls(query: str, k: int = TOP_K_CANDIDATES) -> list[str]:
    """Top-k image URLs from DuckDuckGo. Retries with exponential backoff
    on rate-limit (DDG returns HTTP 202 when throttling)."""
    delay = 4.0
    for attempt in range(3):
        try:
            with DDGS() as ddgs:
                results = list(ddgs.images(query, max_results=k, safesearch="off"))
            return [r["image"] for r in results if r.get("image")]
        except Exception as e:
            msg = str(e)
            if "Ratelimit" in msg or "202" in msg or "rate" in msg.lower():
                print(f"  [ddg] rate-limited; sleep {delay:.0f}s and retry…")
                time.sleep(delay)
                delay *= 2
                continue
            print(f"  [ddg] error: {e}")
            return []
    print("  [ddg] giving up after retries")
    return []


def download(url: str) -> bytes | None:
    try:
        r = requests.get(url, timeout=HTTP_TIMEOUT, headers={"User-Agent": USER_AGENT})
        if r.status_code == 200 and len(r.content) > 1024:
            return r.content
    except Exception:
        return None
    return None


def image_resolution(image_bytes: bytes) -> tuple[int, int] | None:
    """(width, height) of the image, or None if it doesn't decode."""
    try:
        with Image.open(io.BytesIO(image_bytes)) as im:
            return im.size
    except Exception:
        return None


# Lazy global so we only load the rembg ONNX session once.
_REMBG_SESSION = None


def normalize_to_white_bg(image_bytes: bytes, target_width: int = TARGET_WIDTH) -> bytes:
    """Strips the background with rembg, composites onto a pure-white canvas,
    upscales (LANCZOS) so the shorter side hits target_width. Always returns a
    JPEG byte string ready to upload."""
    global _REMBG_SESSION
    if _REMBG_SESSION is None:
        from rembg import new_session
        # u2netp is small (~5 MB), fast on CPU, and good enough for product
        # photos. Switch to "isnet-general-use" for heavier accuracy if needed.
        _REMBG_SESSION = new_session(model_name="u2netp")
    from rembg import remove
    rgba = remove(image_bytes, session=_REMBG_SESSION)
    fg = Image.open(io.BytesIO(rgba)).convert("RGBA")
    # Composite onto white.
    canvas = Image.new("RGB", fg.size, (255, 255, 255))
    canvas.paste(fg, mask=fg.split()[3])
    # Upscale so shorter side hits target_width while keeping aspect ratio.
    w, h = canvas.size
    short = min(w, h)
    if short < target_width:
        scale = target_width / short
        new_w, new_h = int(w * scale), int(h * scale)
        canvas = canvas.resize((new_w, new_h), Image.LANCZOS)
    out = io.BytesIO()
    canvas.save(out, "JPEG", quality=88, optimize=True)
    return out.getvalue()


# ─────────────────────────────────────────────────────────────────────────────
# Supabase REST

class SupabaseRest:
    def __init__(self, url: str, key: str):
        self.url = url.rstrip("/")
        self.key = key
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
        }

    def upload_image(self, item_id: int, image_bytes: bytes, content_type: str = "image/jpeg") -> str:
        """Returns the public URL on success."""
        ext = "jpg" if "jpeg" in content_type or "jpg" in content_type else (
            "png" if "png" in content_type else "webp"
        )
        path = f"{item_id}.{ext}"
        endpoint = f"{self.url}/storage/v1/object/{BUCKET}/{path}"
        r = requests.post(
            endpoint,
            headers={**self.headers, "Content-Type": content_type, "x-upsert": "true"},
            data=image_bytes,
            timeout=15,
        )
        if r.status_code not in (200, 201):
            raise RuntimeError(f"upload failed [{r.status_code}]: {r.text[:200]}")
        return f"{self.url}/storage/v1/object/public/{BUCKET}/{path}"

    def patch_row(self, item_id: int, image_url: str, confidence: float, source: str = "auto-ddg-clip"):
        endpoint = f"{self.url}/rest/v1/catalog_reference_items?id=eq.{item_id}"
        body = {
            "image_url": image_url,
            "image_url_source": source,
            "image_url_confidence": confidence,
            "needs_image_review": False,
        }
        r = requests.patch(
            endpoint,
            headers={**self.headers, "Content-Type": "application/json", "Prefer": "return=minimal"},
            json=body,
            timeout=10,
        )
        if r.status_code not in (200, 204):
            raise RuntimeError(f"patch failed [{r.status_code}]: {r.text[:200]}")

    def fetch_pending_ids(self) -> set[int]:
        endpoint = f"{self.url}/rest/v1/catalog_reference_items"
        r = requests.get(
            endpoint,
            headers={**self.headers, "Range": "0-9999"},
            params={"select": "id", "needs_image_review": "eq.true"},
            timeout=10,
        )
        r.raise_for_status()
        return {row["id"] for row in r.json()}


# ─────────────────────────────────────────────────────────────────────────────
# Audit-replay path: skip search/score, just upload winners from the JSON the
# dry-run produced. Use this after a long search run when you finally have
# the service-role key handy.

def upload_from_audit(args) -> int:
    if not PICKS_JSON.exists():
        print(f"ERROR: {PICKS_JSON} missing — run without --upload-from-audit first", file=sys.stderr)
        return 1
    key = load_service_key()
    if not key:
        print("ERROR: SUPABASE_SERVICE_ROLE_KEY env var required", file=sys.stderr)
        return 1
    supa = SupabaseRest(load_supabase_url(), key)

    audit = json.loads(PICKS_JSON.read_text())
    winners = [r for r in audit if r.get("winner") and r["winner"].get("score", 0) >= args.threshold]
    print(f"[audit] {len(audit)} rows total · {len(winners)} clear threshold {args.threshold}")

    uploaded = 0
    failed = 0
    for row in winners:
        item_id = row["id"]
        url = row["winner"]["url"]
        score = row["winner"]["score"]
        data = download(url)
        if not data:
            print(f"  [{item_id:3d}] [skip] re-download failed for {url[:80]}")
            failed += 1
            continue
        try:
            normalized = normalize_to_white_bg(data)
            public_url = supa.upload_image(item_id, normalized)
            supa.patch_row(item_id, public_url, score)
            uploaded += 1
            print(f"  [{item_id:3d}] OK  {public_url}  ({len(normalized)//1024} KB)")
        except Exception as e:
            failed += 1
            print(f"  [{item_id:3d}] ERR {e}")
    print(f"\n[done] uploaded={uploaded}  failed={failed}")
    return 0 if failed == 0 else 1


# ─────────────────────────────────────────────────────────────────────────────
# Main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None, help="Process at most N items")
    ap.add_argument("--start-id", type=int, default=None, help="Skip items with id < N")
    ap.add_argument("--dry-run", action="store_true", help="Don't upload or PATCH; just print scores")
    ap.add_argument("--only-pending", action="store_true", help="Skip rows already curated (needs_image_review=false)")
    ap.add_argument("--threshold", type=float, default=MIN_CONFIDENCE)
    ap.add_argument(
        "--upload-from-audit", action="store_true",
        help="Skip search/scoring; just upload winners already recorded in data/catalog_image_picks.json",
    )
    args = ap.parse_args()

    # Fast-path: replay the audit file straight into Supabase Storage. Use this
    # after a long dry-run has produced data/catalog_image_picks.json.
    if args.upload_from_audit:
        return upload_from_audit(args)

    catalogue = json.loads(CATALOGUE_JSON.read_text())
    items = catalogue["items"]
    print(f"[load] {len(items)} catalogue items")

    supa: SupabaseRest | None = None
    if not args.dry_run:
        key = load_service_key()
        if not key:
            print("ERROR: SUPABASE_SERVICE_ROLE_KEY env var required (or use --dry-run)", file=sys.stderr)
            return 1
        supa = SupabaseRest(load_supabase_url(), key)

    pending: set[int] | None = None
    if args.only_pending and supa:
        pending = supa.fetch_pending_ids()
        print(f"[load] {len(pending)} rows still need an image")

    clip = ClipScorer.load()

    audit: list[dict] = []
    if PICKS_JSON.exists():
        try:
            audit = json.loads(PICKS_JSON.read_text())
        except Exception:
            audit = []
    audit_index = {row["id"]: i for i, row in enumerate(audit)}

    processed = 0
    matched = 0
    for item in items:
        if args.limit is not None and processed >= args.limit:
            break
        if args.start_id is not None and item["id"] < args.start_id:
            continue
        if pending is not None and item["id"] not in pending:
            continue

        item_id = item["id"]
        q = build_query(item)
        print(f"\n[{item_id:3d}/{len(items)}] {q}")
        urls = ddg_image_urls(q)
        if not urls:
            print("  [search] no results")
            continue

        scored: list[dict] = []
        # Keep the bytes alongside the scoring metadata so we don't re-download
        # the winner before piping it through rembg.
        cache: dict[str, bytes] = {}
        for url in urls:
            data = download(url)
            if not data:
                continue
            res = image_resolution(data)
            if res is None:
                continue
            short_side = min(res)
            if short_side < MIN_IMAGE_WIDTH:
                print(f"   skip-lowres  {short_side}px  {url[:80]}")
                continue
            score = clip.score(data, q)
            scored.append({"url": url, "score": score, "res": list(res), "bytes_len": len(data)})
            cache[url] = data
            print(f"   score={score:.3f}  {res[0]}x{res[1]}  {url[:80]}")

        scored.sort(key=lambda r: r["score"], reverse=True)
        best = scored[0] if scored else None

        if best is None or best["score"] < args.threshold:
            print(f"  [reject] best score {best['score']:.3f} < {args.threshold}" if best else "  [reject] no downloadable")
            audit_row = {"id": item_id, "query": q, "candidates": scored, "winner": None}
        else:
            print(f"  [ACCEPT] {best['score']:.3f}  {best['url'][:90]}")
            matched += 1
            if supa is not None:
                # Reuse the bytes we already fetched during scoring; no need
                # to re-hit the source server.
                winner_bytes = cache.get(best["url"]) or download(best["url"])
                if winner_bytes is None:
                    print("  [skip] winner re-download failed")
                else:
                    try:
                        normalized = normalize_to_white_bg(winner_bytes)
                        public_url = supa.upload_image(item_id, normalized)
                        supa.patch_row(item_id, public_url, best["score"])
                        print(f"  [upload] {public_url}  ({len(normalized)//1024} KB)")
                    except Exception as e:
                        print(f"  [upload-error] {e}")
            audit_row = {"id": item_id, "query": q, "candidates": scored, "winner": best}

        # Replace prior audit row for this id
        if item_id in audit_index:
            audit[audit_index[item_id]] = audit_row
        else:
            audit_index[item_id] = len(audit)
            audit.append(audit_row)

        processed += 1
        # Polite delay to keep DDG happy. 1.5s avoids most rate-limit hits.
        time.sleep(1.5)

        # Flush audit log every 10 items so a crash doesn't lose progress.
        if processed % 10 == 0:
            PICKS_JSON.write_text(json.dumps(audit, indent=2))

    PICKS_JSON.write_text(json.dumps(audit, indent=2))
    print(f"\n[done] processed={processed}  matched={matched}  audit={PICKS_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
