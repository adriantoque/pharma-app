#!/usr/bin/env python3
"""Convert a pharmacy inventory workbook into the app's medicine seed.

    python tool/import_medicine_inventory.py [file.xlsx] [--write]

Without ``--write`` the converted list is written to
``tool/out/medicines_seed.preview.json`` so the mapping can be reviewed before
it replaces the catalogue the app ships. With ``--write`` it replaces
``assets/data/medicines_seed.json``, which is the file bundled into the app and
uploaded by ``tool/seed_firestore.dart``.

The workbook is read by header name, not by fixed columns, because inventory
sheets grow and reorder columns between exports. A column that is not found is
written as null rather than guessed at.

Recognised headers (case and punctuation ignored):

    product id              -> productId
    product name            -> name
    unit price (php)        -> priceCentavos   (pesos x 100)
    stock quantity          -> stock
    packaging / unit type   -> packageType     (optional)
    usage / indication      -> usageIndication (optional)
    category                -> category        (optional)
    kids (0-11)             -> ageGuidance.kids
    teens (12-17)           -> ageGuidance.teens
    adults (18-59)          -> ageGuidance.adults
    seniors (60+)           -> ageGuidance.seniors
    how often               -> dosageInfo      (first half)
    when to take            -> dosageInfo      (second half)
    notes / cautions        -> cautions        (optional)

``Suitable For`` is recalculated from the four age columns rather than copied,
so the display label and the filters cannot disagree. The sheet's own value is
compared against the recalculated one and any difference is reported.

The age ratings and directions in the pharmacy workbook are general guidance,
not verified clinical advice. They are imported as written and shown in the app
next to a prompt to check the product label or ask the pharmacist.

This is Python rather than Dart because the ``excel`` Dart package cannot open
workbooks that store strings inline instead of in ``sharedStrings.xml``; this
inventory export is one of them. ``openpyxl`` reads both layouts.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import openpyxl
except ImportError:  # pragma: no cover - a setup problem, not a data problem
    sys.exit(
        "openpyxl is required: pip install openpyxl\n"
        "(it is only needed to run this import tool, never by the app)"
    )

DEFAULT_SOURCE = (
    "new_merging_feature _delete_later/"
    "medicine_inventory_with_age_groups-1 (1).xlsx"
)
SEED_FILE = "assets/data/medicines_seed.json"
PREVIEW_FILE = "tool/out/medicines_seed.preview.json"
OVERRIDES_FILE = "tool/medicine_overrides.json"

#: How many rows are searched for the header before giving up. Inventory
#: exports often carry a merged title row above the real header.
HEADER_SEARCH_ROWS = 15


def normalise(value: object) -> str:
    """Lower case, single spaces, no punctuation.

    ``Unit Price (PHP)`` and ``unit price php`` are one header.
    """
    return re.sub(r"[^a-z0-9]+", " ", str(value).lower()).strip()


def cell_text(value: object) -> str | None:
    """A cell as text, or None for an empty cell."""
    if value is None:
        return None
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    text = str(value).strip()
    return text or None


def cell_number(value: object) -> float | None:
    """A number in a cell, tolerating currency symbols and separators."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    cleaned = re.sub(r"[^0-9.]", "", str(value))
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def clean_id(value: object) -> str | None:
    """An id exactly as written, without a trailing ``.0``."""
    text = cell_text(value)
    if text is None:
        return None
    number = cell_number(text)
    if number is not None and number == int(number):
        return str(int(number))
    return text


def is_product_name(header: str) -> bool:
    return header in {
        "product name",
        "medicine name",
        "item name",
        "name",
        "product",
    }


def is_product_id(header: str) -> bool:
    return header in {"product id", "id", "sku", "code"}


def is_price(header: str) -> bool:
    return "price" in header or "unit cost" in header or header == "cost"


def is_stock(header: str) -> bool:
    return (
        "stock" in header
        or "quantity" in header
        or header in {"qty", "on hand"}
    )


def is_age(header: str) -> str | None:
    """The age group a header names, if it names one."""
    for group in ("kids", "teens", "adults", "seniors"):
        if header.startswith(group):
            return group
    return None


def find_columns(sheet) -> dict | None:
    """Locate the header row and the columns this tool understands."""
    for row_index, row in enumerate(
        sheet.iter_rows(min_row=1, max_row=HEADER_SEARCH_ROWS, values_only=True)
    ):
        headers = [normalise(cell) if cell is not None else "" for cell in row]
        columns: dict[str, int] = {}
        for index, header in enumerate(headers):
            if not header:
                continue
            if is_product_name(header):
                columns["name"] = index
            elif is_product_id(header):
                columns["id"] = index
            elif is_price(header):
                columns["price"] = index
            elif is_stock(header):
                columns["stock"] = index
            elif "packag" in header:
                columns["packageType"] = index
            elif "usage" in header or "indication" in header:
                columns["usageIndication"] = index
            elif header in {"category", "shelf", "section"}:
                columns["category"] = index
            elif (age := is_age(header)) is not None:
                columns[f"age.{age}"] = index
            elif "suitable" in header:
                columns["suitableFor"] = index
            elif "how often" in header or "frequency" in header:
                columns["dosageFrequency"] = index
            elif "when to take" in header or "with food" in header:
                columns["dosageTiming"] = index
            elif "notes" in header or "caution" in header:
                columns["cautions"] = index
        if "name" in columns:
            columns["headerRow"] = row_index
            return columns
    return None


def load_overrides() -> dict:
    """Cleaning rules keyed by the raw name in the workbook.

    Kept in a separate file so a pharmacist can fix a spelling or add an
    indication without editing the importer. A missing file means no cleaning,
    which is a usable import rather than a failed one.
    """
    path = Path(OVERRIDES_FILE)
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"{OVERRIDES_FILE} must contain an object keyed by name")
    return data


def inferred_package(name: str) -> str | None:
    """Rough packaging from the words in a product name.

    Only shapes the name actually states: a syrup or a lotion is a bottle, a
    roll-on is a roll-on. Everything else is sold by the piece.
    """
    lowered = name.lower()
    if any(word in lowered for word in ("syrup", "lotion", "oil", "drops")):
        return "Bottle"
    if "alcohol" in lowered:
        return "Bottle"
    if "roll" in lowered:
        return "Roll-On"
    if "vaporub" in lowered or "ointment" in lowered:
        return "Jar"
    return "Piece (Dosage)"


AGE_GROUPS = ("kids", "teens", "adults", "seniors")
AGE_LABELS = {
    "kids": "Kids",
    "teens": "Teens",
    "adults": "Adults",
    "seniors": "Seniors",
}
AGE_VALUES = {"yes", "caution", "no"}

#: Antibiotics, blood-pressure and diabetes medicines are prescription-only in
#: the Philippines, as the workbook's own legend says.
PRESCRIPTION_CATEGORIES = {"antibiotics", "hypertension", "diabetes"}


def age_guidance(values: dict[str, object]) -> dict[str, str] | None:
    """The four age ratings, or None if any of them is missing or unreadable.

    A partly filled row is not guessed at: "not recorded" has to stay
    distinguishable from "suitable", or the filter would offer a medicine to a
    group nobody cleared it for.
    """
    readings = {
        group: normalise(values.get(group))
        for group in AGE_GROUPS
    }
    if any(value not in AGE_VALUES for value in readings.values()):
        return None
    return readings


def age_group_for(ratings: dict[str, str] | None) -> str:
    """The two-value age filter the app already understands.

    ``both`` means the line is offered to the child and adult lists. A
    ``Caution`` rating still counts as offered, because the counter should see
    it and the caution, not have the line disappear from the child list.
    """
    if ratings is None:
        return "both"
    kids = ratings["kids"] != "no"
    older = any(ratings[group] != "no" for group in ("teens", "adults", "seniors"))
    if kids and older:
        return "both"
    if kids:
        return "child"
    return "adult"


def suitable_for_label(ratings: dict[str, str] | None) -> str | None:
    """The workbook's own ``Suitable For`` wording, rebuilt from H to K."""
    if ratings is None:
        return None
    parts = [
        f"{AGE_LABELS[group]}{'*' if ratings[group] == 'caution' else ''}"
        for group in AGE_GROUPS
        if ratings[group] != "no"
    ]
    return ", ".join(parts) or None


def join_directions(frequency: str | None, timing: str | None) -> str | None:
    """How often + when to take, as the sentences the app shows."""
    parts = [part.strip() for part in (frequency, timing) if part and part.strip()]
    if not parts:
        return None
    return ". ".join(part.rstrip(".") for part in parts) + "."


def generic_key(name: str) -> str | None:
    """The generic a brand is sold under, when the name states it.

    ``Biogesic 500mg Tablet (Paracetamol)`` names paracetamol in brackets;
    ``Paracetamol 500mg (Generic Tablet)`` does not -- its bracket names the
    form, not another drug. Only the former becomes a searchable generic.
    """
    match = re.search(r"\(([^)]+)\)\s*$", name)
    if match is None:
        return None
    key = match.group(1).strip()
    if not key or key.lower().startswith("generic"):
        return None
    return key


def read_products(
    sheet, columns: dict, overrides: dict | None = None
) -> tuple[list[dict], int]:
    """One product per data row, cleaned and sorted the way the app sorts."""
    overrides = overrides or {}
    products: list[dict] = []
    fallback_id = 0
    renamed = 0
    mismatches = 0

    for row in sheet.iter_rows(
        min_row=columns["headerRow"] + 2, values_only=True
    ):
        def at(key: str):
            index = columns.get(key)
            if index is None or index >= len(row):
                return None
            return row[index]

        raw_name = cell_text(at("name"))
        if not raw_name:
            continue
        if is_product_name(normalise(raw_name)):
            continue
        if re.match(r"^(total|grand total|subtotal)", raw_name, re.IGNORECASE):
            continue

        override = overrides.get(raw_name, {})
        name = override.get("name") or raw_name
        if name != raw_name:
            renamed += 1

        fallback_id += 1
        product_id = clean_id(at("id")) or str(fallback_id)

        price = cell_number(at("price"))
        stock = cell_number(at("stock"))

        package_type = (
            override.get("packageType")
            or cell_text(at("packageType"))
            or inferred_package(name)
        )
        usage = override.get("usageIndication") or cell_text(
            at("usageIndication")
        )

        ratings = age_guidance(
            {group: at(f"age.{group}") for group in AGE_GROUPS}
        )
        suitable_for = cell_text(at("suitableFor"))
        if suitable_for and ratings:
            expected = suitable_for_label(ratings)
            if suitable_for.replace(" ", "") != (expected or "").replace(" ", ""):
                mismatches += 1

        category = cell_text(at("category"))
        notes = cell_text(at("cautions"))
        directions = join_directions(
            cell_text(at("dosageFrequency")), cell_text(at("dosageTiming"))
        )
        requires_rx = bool(category and category.lower() in PRESCRIPTION_CATEGORIES)
        if notes and "prescription" in notes.lower():
            requires_rx = True

        # The raw spelling is kept as an alias so a search for the name the
        # counter wrote still finds the cleaned line.
        aliases = []
        if name != raw_name:
            aliases.append(raw_name)
        for alias in override.get("aliases", []):
            if alias and alias not in aliases and alias != name:
                aliases.append(alias)

        products.append(
            {
                "productId": product_id,
                "name": name,
                # Pesos in the sheet, centavos in the app. Rounded rather than
                # truncated so the total stays within a centavo of the sheet.
                "priceCentavos": round((price or 0) * 100),
                # Null rather than 0 when the sheet does not say: the app must
                # not report an invented count as if the shelf was counted.
                "stock": int(stock) if stock is not None else None,
                "expiryDate": None,
                "aliases": aliases,
                "genericKey": override.get("genericKey") or generic_key(name),
                "packageType": package_type,
                "usageIndication": usage,
                "category": category,
                # The structured ratings are what the filter and the details
                # screen read. `ageGroup` stays for older documents and for the
                # two-value filter the app already had.
                "ageGroup": age_group_for(ratings),
                "ageGuidance": ratings,
                "dosageInfo": directions,
                "cautions": notes,
                "requiresRx": requires_rx,
            }
        )

    products.sort(
        key=lambda item: (item["name"].lower(), item["priceCentavos"])
    )
    return products, renamed, mismatches


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "source",
        nargs="?",
        default=DEFAULT_SOURCE,
        help=f"workbook to read (default: {DEFAULT_SOURCE})",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"replace {SEED_FILE} instead of only writing the preview",
    )
    args = parser.parse_args()

    source = Path(args.source)
    if not source.exists():
        print(
            f"Cannot find {source}.\n"
            f"Pass the workbook path, or put it at {DEFAULT_SOURCE}.",
            file=sys.stderr,
        )
        return 1

    workbook = openpyxl.load_workbook(source, data_only=True)

    sheet = None
    columns = None
    for candidate in workbook.worksheets:
        found = find_columns(candidate)
        if found is not None:
            sheet, columns = candidate, found
            break

    if sheet is None or columns is None:
        print(
            f"No sheet in {source} has a product-name header in its first "
            f"{HEADER_SEARCH_ROWS} rows.",
            file=sys.stderr,
        )
        return 1

    overrides = load_overrides()
    products, renamed, suitable_for_mismatches = read_products(
        sheet, columns, overrides
    )
    if not products:
        print("The header was found but no product rows were read.", file=sys.stderr)
        return 1

    payload = json.dumps(products, indent=2, ensure_ascii=False) + "\n"

    preview = Path(PREVIEW_FILE)
    preview.parent.mkdir(parents=True, exist_ok=True)
    preview.write_text(payload, encoding="utf-8")

    counted = sum(1 for item in products if item["stock"] is not None)
    columns_text = ", ".join(
        f"{key}@{index + 1}"
        for key, index in sorted(columns.items())
        if key != "headerRow"
    )

    print(f"Read {source}")
    print(f"  columns  header row {columns['headerRow'] + 1}: {columns_text}")
    print(f"  products {len(products)}")
    print(f"  cleaned  {renamed} renamed, {len(overrides)} override entries loaded")
    with_usage = sum(1 for item in products if item["usageIndication"])
    print(f"  usage    {with_usage} with an indication, {len(products) - with_usage} without")
    print(f"  stock    {counted} counted, {len(products) - counted} uncounted")
    with_age = sum(1 for item in products if item["ageGuidance"])
    with_directions = sum(1 for item in products if item["dosageInfo"])
    with_notes = sum(1 for item in products if item["cautions"])
    rx = sum(1 for item in products if item["requiresRx"])
    child_filter = sum(
        1 for item in products if item["ageGroup"] in {"child", "both"}
    )
    adult_filter = sum(
        1 for item in products if item["ageGroup"] in {"adult", "both"}
    )
    print(
        f"  age      {with_age} rated for all four groups; "
        f"child filter {child_filter}, adult filter {adult_filter}"
    )
    print(
        f"  dosage   {with_directions} with directions, "
        f"{with_notes} with a caution note, {rx} prescription-only"
    )
    if suitable_for_mismatches:
        print(
            f"  warning  {suitable_for_mismatches} Suitable For cells disagreed "
            "with the age columns; the age columns were used"
        )
    print(f"  wrote    {preview}")

    missing = [
        label
        for key, label in (
            ("packageType", "package-type"),
            ("usageIndication", "usage-indication"),
            ("category", "category"),
            ("age.kids", "age groups"),
            ("dosageFrequency", "how-often"),
            ("cautions", "notes"),
        )
        if key not in columns
    ]
    if missing:
        print(
            f"  note     this sheet has no {' or '.join(missing)} column; "
            f"values come from {OVERRIDES_FILE} where recorded, otherwise null."
        )

    if args.write:
        seed = Path(SEED_FILE)
        seed.parent.mkdir(parents=True, exist_ok=True)
        seed.write_text(payload, encoding="utf-8")
        print(f"  replaced {SEED_FILE}")
    else:
        print(f"  dry run  re-run with --write to replace {SEED_FILE}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
