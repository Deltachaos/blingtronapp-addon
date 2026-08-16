#!/usr/bin/env python3
"""Fetch BiS data and loot pools from data.blingtron.app.

Writes Data/BisList Lua files and Data/LootPools.lua, then updates
BlingtronApp.toc with the generated file list and optional version.
When an entry has source.type == "item", the token/source id is stored instead of
the transformed item id (that is the item that actually drops). Token sources are
flattened by fetching /gear/item/{id}.json so Lua only stores raid or mythic_plus.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

API_BASE = "https://data.blingtron.app"
USER_AGENT = "BlingtronApp-bis-builder/1.0"
MAX_WORKERS = 12
RETRIES = 3
TIMEOUT = 30
MIN_PCT = 5.0
MIN_AGGREGATED_SCORE = 5.0

ACTIVITIES = ("overall", "raid", "mythic_plus")
SOURCE_IDS = ("wowhead", "archon", "icy-veins", "method")
AGGREGATED_SOURCE = "blingtron"
PERSISTABLE_SOURCE_TYPES = ("raid", "mythic_plus")
SLOT_ALIASES = {"trinkets": "trinket"}
TOKEN_FLAGS = ("token", "is_token", "tset", "is_tset", "tier_token")
TOKEN_CREATED_KEYS = ("creates", "created_items", "token_items")
LOOT_POOLS_TOC_LINE = "Data\\LootPools.lua"

SOURCE_LABELS = {
    "blingtron": "All Average",
    "wowhead": "Wowhead",
    "archon": "Archon",
    "icy-veins": "Icy Veins",
    "method": "Method",
}
ACTIVITY_LABELS = {
    "overall": "overall",
    "raid": "raid",
    "mythic_plus": "M+",
}
SOURCE_ORDER = {
    "blingtron": 1,
    "wowhead": 10,
    "archon": 20,
    "icy-veins": 30,
    "method": 40,
}
ACTIVITY_ORDER = {
    "overall": 0,
    "raid": 1,
    "mythic_plus": 2,
}

# SpecializationID constants that exist in Constants.lua. Specs missing from
# this set are skipped so generated Lua does not reference undefined globals.
SPEC_CONSTANTS = {
    ("death-knight", "blood"): "DEATH_KNIGHT_BLOOD",
    ("death-knight", "frost"): "DEATH_KNIGHT_FROST",
    ("death-knight", "unholy"): "DEATH_KNIGHT_UNHOLY",
    ("demon-hunter", "havoc"): "DEMON_HUNTER_HAVOC",
    ("demon-hunter", "vengeance"): "DEMON_HUNTER_VENGEANCE",
    ("demon-hunter", "devourer"): "DEMON_HUNTER_DEVOURER",
    ("druid", "balance"): "DRUID_BALANCE",
    ("druid", "feral"): "DRUID_FERAL",
    ("druid", "guardian"): "DRUID_GUARDIAN",
    ("druid", "restoration"): "DRUID_RESTORATION",
    ("evoker", "devastation"): "EVOKER_DEVASTATION",
    ("evoker", "preservation"): "EVOKER_PRESERVATION",
    ("evoker", "augmentation"): "EVOKER_AUGMENTATION",
    ("hunter", "beast-mastery"): "HUNTER_BEAST_MASTERY",
    ("hunter", "marksmanship"): "HUNTER_MARKSMANSHIP",
    ("hunter", "survival"): "HUNTER_SURVIVAL",
    ("mage", "arcane"): "MAGE_ARCANE",
    ("mage", "fire"): "MAGE_FIRE",
    ("mage", "frost"): "MAGE_FROST",
    ("monk", "brewmaster"): "MONK_BREWMASTER",
    ("monk", "mistweaver"): "MONK_MISTWEAVER",
    ("monk", "windwalker"): "MONK_WINDWALKER",
    ("paladin", "holy"): "PALADIN_HOLY",
    ("paladin", "protection"): "PALADIN_PROTECTION",
    ("paladin", "retribution"): "PALADIN_RETRIBUTION",
    ("priest", "discipline"): "PRIEST_DISCIPLINE",
    ("priest", "holy"): "PRIEST_HOLY",
    ("priest", "shadow"): "PRIEST_SHADOW",
    ("rogue", "assassination"): "ROGUE_ASSASSINATION",
    ("rogue", "outlaw"): "ROGUE_OUTLAW",
    ("rogue", "subtlety"): "ROGUE_SUBTLETY",
    ("shaman", "elemental"): "SHAMAN_ELEMENTAL",
    ("shaman", "enhancement"): "SHAMAN_ENHANCEMENT",
    ("shaman", "restoration"): "SHAMAN_RESTORATION",
    ("warlock", "affliction"): "WARLOCK_AFFLICTION",
    ("warlock", "demonology"): "WARLOCK_DEMONOLOGY",
    ("warlock", "destruction"): "WARLOCK_DESTRUCTION",
    ("warrior", "arms"): "WARRIOR_ARMS",
    ("warrior", "fury"): "WARRIOR_FURY",
    ("warrior", "protection"): "WARRIOR_PROTECTION",
}

CLASS_ORDER = [
    "death-knight",
    "demon-hunter",
    "druid",
    "evoker",
    "hunter",
    "mage",
    "monk",
    "paladin",
    "priest",
    "rogue",
    "shaman",
    "warlock",
    "warrior",
]

TIMESTAMP_SUFFIX_RE = re.compile(r"-\d{12}$")
VERSION_LINE_RE = re.compile(r"^## Version:\s*(.+?)\s*$", re.M)

ItemEntry = dict[str, Any]
SpecItems = dict[int, ItemEntry]
Tables = dict[tuple[str, str], dict[str, SpecItems]]
LootSource = dict[str, Any]


def source_key(source_id: str, activity: str) -> str:
    return f"{source_id.replace('-', '_')}_{activity}"


def source_label(source_id: str, activity: str) -> str:
    return f"{SOURCE_LABELS.get(source_id, source_id)} ({ACTIVITY_LABELS.get(activity, activity)})"


def source_order(source_id: str, activity: str) -> int:
    return SOURCE_ORDER.get(source_id, 90) + ACTIVITY_ORDER.get(activity, 0)


def normalize_slot(slot: str) -> str:
    return SLOT_ALIASES.get(slot, slot)


def format_pct(pct: float) -> str:
    return f"{pct:.3f}".rstrip("0").rstrip(".")


def persistable_source(src: object) -> dict[str, Any] | None:
    if not isinstance(src, dict):
        return None
    src_type = src.get("type")
    src_id = src.get("id")
    if src_type in PERSISTABLE_SOURCE_TYPES and isinstance(src_id, int):
        return {"type": src_type, "id": src_id}
    return None


def entry_item_id(entry: dict) -> int | None:
    """Item people actually loot. Token/catalyst id when source.type is 'item'."""
    src = entry.get("source")
    if isinstance(src, dict) and src.get("type") == "item":
        token_id = src.get("id")
        if isinstance(token_id, int):
            return token_id
    item_id = entry.get("item_id")
    if isinstance(item_id, int):
        return item_id
    return None


def entry_pct(entry: dict, aggregated: bool) -> float | None:
    if aggregated:
        score = entry.get("score")
        if isinstance(score, (int, float)):
            return float(score)
        return None
    pct = entry.get("recommendation_pct")
    if isinstance(pct, (int, float)):
        return float(pct)
    return None


def should_include(entry: dict, aggregated: bool) -> bool:
    if aggregated:
        score = entry.get("score")
        return isinstance(score, (int, float)) and float(score) >= MIN_AGGREGATED_SCORE
    pct = entry.get("recommendation_pct")
    return isinstance(pct, (int, float)) and float(pct) >= MIN_PCT


def keep_better(current: ItemEntry | None, candidate: ItemEntry) -> ItemEntry:
    if current is None or candidate["pct"] > current["pct"]:
        return candidate
    return current


def merge_entries(
    target: SpecItems,
    entries: list | None,
    aggregated: bool,
    slot: str,
) -> None:
    if not entries:
        return
    slot = normalize_slot(slot)
    for entry in entries:
        if not isinstance(entry, dict) or not should_include(entry, aggregated):
            continue
        item_id = entry_item_id(entry)
        pct = entry_pct(entry, aggregated)
        if item_id is None or pct is None:
            continue
        candidate: ItemEntry = {
            "pct": pct,
            "slot": slot,
            "source": entry.get("source"),
        }
        target[item_id] = keep_better(target.get(item_id), candidate)


def ingest_payload(payload: dict, aggregated: bool) -> SpecItems:
    items: SpecItems = {}
    slots = payload.get("slots") or {}
    if isinstance(slots, dict):
        for slot, entries in slots.items():
            if isinstance(slot, str) and isinstance(entries, list):
                merge_entries(items, entries, aggregated, slot)
    trinkets = payload.get("trinkets")
    if isinstance(trinkets, list):
        merge_entries(items, trinkets, aggregated, "trinket")
    return items


def fetch_json(url: str) -> object | None:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    last_error: Exception | None = None
    for attempt in range(1, RETRIES + 1):
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return None
            last_error = exc
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
        if attempt < RETRIES:
            time.sleep(0.5 * attempt)
    raise RuntimeError(f"Failed to fetch {url}: {last_error}") from last_error


def load_classes(api_base: str) -> list[dict]:
    payload = fetch_json(f"{api_base.rstrip('/')}/wow/classes.json")
    if not isinstance(payload, list):
        raise SystemExit("classes.json did not return a list")
    return payload


def build_jobs(classes: list[dict], api_base: str) -> list[tuple[str, str, str, str]]:
    """Return (url, source_id, activity, spec_const) jobs."""
    base = api_base.rstrip("/")
    jobs: list[tuple[str, str, str, str]] = []
    skipped: list[str] = []
    for wow_class in classes:
        class_id = wow_class.get("id")
        specs = wow_class.get("specs") or []
        if not isinstance(class_id, str) or not isinstance(specs, list):
            continue
        for spec in specs:
            spec_id = spec.get("id") if isinstance(spec, dict) else None
            if not isinstance(spec_id, str):
                continue
            spec_const = SPEC_CONSTANTS.get((class_id, spec_id))
            if not spec_const:
                skipped.append(f"{class_id}/{spec_id}")
                continue
            for activity in ACTIVITIES:
                jobs.append(
                    (
                        f"{base}/gear/bis/{class_id}/{spec_id}/{activity}.json",
                        AGGREGATED_SOURCE,
                        activity,
                        spec_const,
                    )
                )
                for source_id in SOURCE_IDS:
                    jobs.append(
                        (
                            f"{base}/gear/bis/{class_id}/{spec_id}/source/{source_id}/{activity}.json",
                            source_id,
                            activity,
                            spec_const,
                        )
                    )
    if skipped:
        print("Skipping unknown specs:", ", ".join(sorted(set(skipped))), file=sys.stderr)
    return jobs


def fetch_all(jobs: list[tuple[str, str, str, str]]) -> Tables:
    tables: Tables = {}
    done = 0
    total = len(jobs)
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        future_map = {
            pool.submit(fetch_json, url): (source_id, activity, spec_const)
            for url, source_id, activity, spec_const in jobs
        }
        for future in as_completed(future_map):
            source_id, activity, spec_const = future_map[future]
            done += 1
            if done % 50 == 0 or done == total:
                print(f"Fetched {done}/{total}")
            payload = future.result()
            if not isinstance(payload, dict):
                continue
            items = ingest_payload(payload, aggregated=(source_id == AGGREGATED_SOURCE))
            if not items:
                continue
            spec_map = tables.setdefault((source_id, activity), {}).setdefault(spec_const, {})
            for item_id, entry in items.items():
                spec_map[item_id] = keep_better(spec_map.get(item_id), entry)
    return tables


def collect_token_ids(tables: Tables) -> set[int]:
    ids: set[int] = set()
    for spec_items in tables.values():
        for items in spec_items.values():
            for entry in items.values():
                src = entry.get("source")
                if isinstance(src, dict) and src.get("type") == "item":
                    token_id = src.get("id")
                    if isinstance(token_id, int):
                        ids.add(token_id)
    return ids


def fetch_item_cache(api_base: str, item_ids: set[int]) -> dict[int, dict | None]:
    cache: dict[int, dict | None] = {}
    if not item_ids:
        return cache
    base = api_base.rstrip("/")
    print(f"Flattening {len(item_ids)} token item sources")
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        future_map = {
            pool.submit(fetch_json, f"{base}/gear/item/{item_id}.json"): item_id
            for item_id in item_ids
        }
        done = 0
        total = len(future_map)
        for future in as_completed(future_map):
            item_id = future_map[future]
            payload = future.result()
            cache[item_id] = payload if isinstance(payload, dict) else None
            done += 1
            if done % 20 == 0 or done == total:
                print(f"Fetched item sources {done}/{total}")
    return cache


def resolve_source(src: object, item_cache: dict[int, dict | None]) -> dict[str, Any] | None:
    persisted = persistable_source(src)
    if persisted:
        return persisted
    if not isinstance(src, dict) or src.get("type") != "item":
        return None
    token_id = src.get("id")
    if not isinstance(token_id, int):
        return None
    item = item_cache.get(token_id)
    nested = item.get("source") if isinstance(item, dict) else None
    return persistable_source(nested)


def flatten_item_sources(tables: Tables, item_cache: dict[int, dict | None]) -> None:
    for spec_items in tables.values():
        for items in spec_items.values():
            for entry in items.values():
                entry["source"] = resolve_source(entry.get("source"), item_cache)


def class_comment_for_constant(spec_const: str) -> str:
    for class_id in CLASS_ORDER:
        prefix = class_id.replace("-", "_").upper() + "_"
        if spec_const.startswith(prefix):
            return class_id.replace("-", " ").title()
    return spec_const


def spec_sort_key(spec_const: str) -> tuple[int, str]:
    for index, class_id in enumerate(CLASS_ORDER):
        prefix = class_id.replace("-", "_").upper() + "_"
        if spec_const.startswith(prefix):
            return (index, spec_const)
    return (len(CLASS_ORDER), spec_const)


def render_item_line(item_id: int, entry: ItemEntry) -> str:
    pct = format_pct(entry["pct"])
    slot = entry["slot"]
    src = entry.get("source")
    if isinstance(src, dict):
        return (
            f'        [{item_id}] = {{ pct = {pct}, slot = "{slot}", '
            f'source = {{ type = "{src["type"]}", id = {src["id"]} }} }},'
        )
    return f'        [{item_id}] = {{ pct = {pct}, slot = "{slot}" }},'


def render_lua(source_id: str, activity: str, spec_items: dict[str, SpecItems]) -> str:
    key = source_key(source_id, activity)
    label = source_label(source_id, activity)
    order = source_order(source_id, activity)
    lines = [
        "-- Auto-generated by scripts/build_bis_lists.py from https://data.blingtron.app",
        '-- Do not edit by hand. Format: [itemID] = { pct = n, slot = "...", source = { type = "raid"|"mythic_plus", id = n } }',
        "",
        f'BlingtronApp.BisListSources.{key} = {{ label = "{label}", id = "{key}", order = {order} }}',
        "",
        f"BlingtronApp.BisList.{key} = {{",
    ]
    last_class = None
    for spec_const in sorted(spec_items, key=spec_sort_key):
        items = spec_items[spec_const]
        if not items:
            continue
        class_name = class_comment_for_constant(spec_const)
        if class_name != last_class:
            if last_class is not None:
                lines.append("")
            lines.append(f"    -- {class_name}")
            last_class = class_name
        lines.append(f"    [BlingtronApp.{spec_const}] = {{")
        for item_id in sorted(items):
            lines.append(render_item_line(item_id, items[item_id]))
        lines.append("    },")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def bis_item_ids(tables: Tables) -> set[int]:
    return {
        item_id
        for spec_items in tables.values()
        for items in spec_items.values()
        for item_id in items
    }


def is_tier_token(raw: dict[str, Any]) -> bool:
    """Return whether a non-equippable item creates equippable tier gear."""
    if any(raw.get(key) is True for key in TOKEN_FLAGS):
        return True
    for key in TOKEN_CREATED_KEYS:
        created = raw.get(key)
        if not isinstance(created, list):
            continue
        for entry in created:
            if isinstance(entry, int):
                return True
            if isinstance(entry, dict) and (
                entry.get("equippable") is True or isinstance(entry.get("id"), int)
            ):
                return True
    return False


def parse_loot_specs(raw: object) -> tuple[str, ...] | None:
    if not isinstance(raw, list):
        return None
    wanted: set[tuple[str, str]] = set()
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        class_slug = entry.get("class")
        spec_slug = entry.get("spec")
        if isinstance(class_slug, str) and isinstance(spec_slug, str):
            wanted.add((class_slug, spec_slug))
    return tuple(const for key, const in SPEC_CONSTANTS.items() if key in wanted)


def parse_loot_items(raw: object, wanted_item_ids: set[int]) -> list[LootSource]:
    if not isinstance(raw, list):
        return []
    items: list[LootSource] = []
    seen: set[int] = set()
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        item_id = entry.get("id")
        if not isinstance(item_id, int) or item_id in seen:
            continue
        if (
            entry.get("equippable") is False
            and not is_tier_token(entry)
            and item_id not in wanted_item_ids
        ):
            continue
        name = entry.get("name")
        item: LootSource = {
            "id": item_id,
            "name": name if isinstance(name, str) and name else str(item_id),
        }
        loot_specs = parse_loot_specs(entry.get("loot_specs"))
        if loot_specs is not None:
            item["lootSpecs"] = loot_specs
        seen.add(item_id)
        items.append(item)
    items.sort(key=lambda item: item["id"])
    return items


def season_ids(season: dict, key: str, id_key: str) -> set[int]:
    return {
        entry[id_key]
        for entry in season.get(key) or []
        if isinstance(entry, dict) and isinstance(entry.get(id_key), int)
    }


def load_season_sources(api_base: str) -> tuple[list[LootSource], list[LootSource]]:
    base = api_base.rstrip("/")
    season = fetch_json(f"{base}/wow/season.json")
    raw_raids = fetch_json(f"{base}/wow/raids.json")
    raw_dungeons = fetch_json(f"{base}/wow/dungeons.json")
    if not isinstance(season, dict):
        raise SystemExit("season.json did not return an object")
    if not isinstance(raw_raids, list):
        raise SystemExit("raids.json did not return a list")
    if not isinstance(raw_dungeons, list):
        raise SystemExit("dungeons.json did not return a list")

    wanted_raids = season_ids(season, "raids", "id")
    wanted_dungeons = season_ids(season, "mythic_plus", "challenge_mode_id")
    raids: list[LootSource] = []
    for raw in raw_raids:
        if not isinstance(raw, dict) or raw.get("id") not in wanted_raids:
            continue
        raid_id = raw.get("id")
        name = raw.get("name")
        if not isinstance(raid_id, int) or not isinstance(name, str):
            continue
        encounters = []
        for encounter in raw.get("encounters") or []:
            if not isinstance(encounter, dict):
                continue
            encounter_id = encounter.get("id")
            encounter_name = encounter.get("name")
            if isinstance(encounter_id, int) and isinstance(encounter_name, str):
                encounters.append({"id": encounter_id, "name": encounter_name})
        raids.append({"id": raid_id, "name": name, "encounters": encounters})

    dungeons: list[LootSource] = []
    for raw in raw_dungeons:
        if not isinstance(raw, dict) or raw.get("challenge_mode_id") not in wanted_dungeons:
            continue
        dungeon_id = raw.get("id")
        challenge_id = raw.get("challenge_mode_id")
        name = raw.get("name")
        if (
            isinstance(dungeon_id, int)
            and isinstance(challenge_id, int)
            and isinstance(name, str)
        ):
            dungeons.append({
                "id": dungeon_id,
                "challengeModeId": challenge_id,
                "name": name,
            })
    raids.sort(key=lambda raid: raid["id"])
    dungeons.sort(key=lambda dungeon: dungeon["challengeModeId"])
    return raids, dungeons


def fetch_loot_pools(
    api_base: str,
    raids: list[LootSource],
    dungeons: list[LootSource],
    wanted_item_ids: set[int],
) -> None:
    base = api_base.rstrip("/")
    jobs: list[tuple[str, str, LootSource]] = []
    for raid in raids:
        for encounter in raid["encounters"]:
            jobs.append((
                f"{base}/gear/source/raid/encounter/{encounter['id']}.json",
                "raid",
                encounter,
            ))
    for dungeon in dungeons:
        jobs.append((
            f"{base}/gear/source/mythic_plus/{dungeon['challengeModeId']}.json",
            "dungeon",
            dungeon,
        ))
    if not jobs:
        raise SystemExit("No current-season raids or dungeons to fetch")

    print(f"Fetching {len(jobs)} loot pools from {api_base}")
    done = 0
    skipped = 0
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        future_map = {
            pool.submit(fetch_json, url): (kind, target)
            for url, kind, target in jobs
        }
        for future in as_completed(future_map):
            kind, target = future_map[future]
            payload = future.result()
            raw_items = payload.get("items") if isinstance(payload, dict) else None
            raw_count = len(raw_items) if isinstance(raw_items, list) else 0
            items = parse_loot_items(raw_items, wanted_item_ids)
            skipped += raw_count - len(items)
            if isinstance(payload, dict):
                name = payload.get("name")
                if isinstance(name, str) and name:
                    target["name"] = name
            target["items"] = items
            done += 1
            if done % 5 == 0 or done == len(jobs):
                print(f"Fetched {done}/{len(jobs)} {kind} pools")
    if skipped:
        print(f"Excluded {skipped} non-equippable items (tset tokens kept)")


def lua_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped + '"'


def collect_spec_sets(
    raids: list[LootSource],
    dungeons: list[LootSource],
) -> list[tuple[str, ...]]:
    seen: dict[tuple[str, ...], None] = {}
    for raid in raids:
        groups = [encounter.get("items") or [] for encounter in raid.get("encounters") or []]
        for items in groups:
            for item in items:
                specs = item.get("lootSpecs")
                if isinstance(specs, tuple):
                    seen.setdefault(specs, None)
    for dungeon in dungeons:
        for item in dungeon.get("items") or []:
            specs = item.get("lootSpecs")
            if isinstance(specs, tuple):
                seen.setdefault(specs, None)
    return list(seen)


def render_loot_items(
    items: list[LootSource],
    indent: str,
    set_index: dict[tuple[str, ...], str],
) -> list[str]:
    lines = [f"{indent}items = {{"]
    for item in items:
        specs = item.get("lootSpecs")
        extra = f", lootSpecs = {set_index[specs]}" if isinstance(specs, tuple) else ""
        lines.append(
            f"{indent}    {{ id = {item['id']}, name = {lua_string(item['name'])}{extra} }},"
        )
    lines.append(f"{indent}}},")
    return lines


def render_loot_lua(raids: list[LootSource], dungeons: list[LootSource]) -> str:
    spec_sets = collect_spec_sets(raids, dungeons)
    set_index = {specs: f"S{i}" for i, specs in enumerate(spec_sets, start=1)}
    lines = [
        "-- Auto-generated by scripts/build_bis_lists.py from https://data.blingtron.app",
        "-- Do not edit by hand.",
        "-- lootSpecs is a set of eligible SpecializationIDs; omit the field to allow every spec.",
        "",
        "BlingtronApp.LootPools = (function()",
    ]
    for specs, var in set_index.items():
        lines.append(f"    local {var} = {{")
        lines.extend(f"        [BlingtronApp.{const}] = true," for const in specs)
        lines.append("    }")
    lines.extend(["    return {", "        raids = {"])
    for raid in raids:
        lines.append(
            f"            {{ id = {raid['id']}, name = {lua_string(raid['name'])}, encounters = {{"
        )
        for encounter in raid["encounters"]:
            lines.append(
                f"                {{ id = {encounter['id']}, name = {lua_string(encounter['name'])},"
            )
            lines.extend(render_loot_items(encounter.get("items") or [], "                  ", set_index))
            lines.append("                },")
        lines.append("            }},")
    lines.extend(["        },", "        dungeons = {"])
    for dungeon in dungeons:
        lines.append(
            f"            {{ id = {dungeon['id']}, challengeModeId = {dungeon['challengeModeId']}, "
            f"name = {lua_string(dungeon['name'])},"
        )
        lines.extend(render_loot_items(dungeon.get("items") or [], "              ", set_index))
        lines.append("            },")
    lines.extend(["        },", "    }", "end)()", ""])
    return "\n".join(lines)


def semantic_version_from_toc(text: str) -> str:
    match = VERSION_LINE_RE.search(text)
    if not match:
        raise SystemExit("BlingtronApp.toc is missing a ## Version: line")
    current = match.group(1).strip()
    return TIMESTAMP_SUFFIX_RE.sub("", current)


def stamp_version(semver: str, timestamp: str | None = None) -> str:
    if timestamp is None:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M")
    if not re.fullmatch(r"\d{12}", timestamp):
        raise SystemExit(f"timestamp must be yyyymmddhhmm, got {timestamp!r}")
    return f"{semver}-{timestamp}"


def update_toc(toc_path: Path, lua_filenames: list[str], version: str | None) -> None:
    text = toc_path.read_text(encoding="utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    text = text.replace("\r\n", "\n")

    if version:
        text, n = VERSION_LINE_RE.subn(f"## Version: {version}", text, count=1)
        if n != 1:
            raise SystemExit("Failed to update ## Version: in BlingtronApp.toc")

    text = re.sub(r"Data\\TSet\.lua\n", "", text)
    text = re.sub(r"Data\\LootPools\.lua\n", "", text)

    file_lines = [f"Data\\BisList\\{name}" for name in lua_filenames]
    block = "\n".join([*file_lines, LOOT_POOLS_TOC_LINE]) + "\n"

    def replace_bislist(_match: re.Match[str]) -> str:
        return block

    text, n = re.subn(r"(?:Data\\BisList\\[^\n]+\n)+", replace_bislist, text, count=1)
    if n != 1:
        def insert_after_constants(match: re.Match[str]) -> str:
            return match.group(1) + block

        text, n = re.subn(r"(Constants\.lua\n)", insert_after_constants, text, count=1)
        if n != 1:
            raise SystemExit("Failed to insert Data\\BisList entries into BlingtronApp.toc")

    toc_path.write_text(text.replace("\n", newline), encoding="utf-8")


def write_outputs(output_dir: Path, tables: Tables) -> list[str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    wanted = set()
    source_order_ids = [AGGREGATED_SOURCE, *SOURCE_IDS]
    for source_id in source_order_ids:
        for activity in ACTIVITIES:
            spec_items = tables.get((source_id, activity))
            if not spec_items:
                continue
            filename = f"{source_key(source_id, activity)}.lua"
            wanted.add(filename)
            (output_dir / filename).write_text(render_lua(source_id, activity, spec_items), encoding="utf-8")
            written.append(filename)
            print(f"Wrote {filename}")
    for existing in output_dir.glob("*.lua"):
        if existing.name not in wanted:
            existing.unlink()
            print(f"Removed stale {existing.name}")
    return written


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description="Build BiS lists and loot pools from data.blingtron.app")
    parser.add_argument("--api-base", default=API_BASE)
    parser.add_argument("--output-dir", type=Path, default=root / "Data" / "BisList")
    parser.add_argument("--loot-output", type=Path, default=root / "Data" / "LootPools.lua")
    parser.add_argument("--toc", type=Path, default=root / "BlingtronApp.toc")
    parser.add_argument("--version", help="Set ## Version in the TOC (e.g. 1.0.1-202608161358)")
    parser.add_argument(
        "--stamp-version",
        action="store_true",
        help="Set TOC version to <semanticversion>-<utc yyyymmddhhmm>",
    )
    parser.add_argument("--timestamp", help="UTC timestamp for --stamp-version (yyyymmddhhmm)")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    classes = load_classes(args.api_base)
    jobs = build_jobs(classes, args.api_base)
    print(f"Fetching {len(jobs)} BiS payloads from {args.api_base}")
    tables = fetch_all(jobs)
    item_cache = fetch_item_cache(args.api_base, collect_token_ids(tables))
    flatten_item_sources(tables, item_cache)
    lua_files = write_outputs(args.output_dir, tables)
    if not lua_files:
        raise SystemExit("No BiS Lua files were generated")

    raids, dungeons = load_season_sources(args.api_base)
    if not raids and not dungeons:
        raise SystemExit("No current-season raids or dungeons found")
    fetch_loot_pools(args.api_base, raids, dungeons, bis_item_ids(tables))
    args.loot_output.parent.mkdir(parents=True, exist_ok=True)
    args.loot_output.write_text(render_loot_lua(raids, dungeons), encoding="utf-8")
    print(f"Wrote {args.loot_output}")

    version = args.version
    if args.stamp_version:
        toc_text = args.toc.read_text(encoding="utf-8")
        version = stamp_version(semantic_version_from_toc(toc_text), args.timestamp)
    update_toc(args.toc, lua_files, version)
    if version:
        print(f"Updated {args.toc.name} version to {version}")
    else:
        print(f"Updated {args.toc.name} data file list")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
