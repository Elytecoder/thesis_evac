"""Normalize and validate Sorsogon barangay / municipality strings."""

from __future__ import annotations

# ---------------------------------------------------------------------------
# Official Sorsogon barangay dataset
# Mirrors the canonical Flutter PhilippineAddressData so that the backend can
# validate and normalise address strings saved to the database.
# ---------------------------------------------------------------------------

SORSOGON_MUNICIPALITIES: list[str] = [
    "Barcelona",
    "Bulan",
    "Bulusan",
    "Casiguran",
    "Castilla",
    "Donsol",
    "Gubat",
    "Irosin",
    "Juban",
    "Magallanes",
    "Matnog",
    "Pilar",
    "Prieto Diaz",
    "Santa Magdalena",
    "Sorsogon City",
]

SORSOGON_BARANGAYS: dict[str, list[str]] = {
    "Barcelona": [
        "Alejandro", "Ariman", "Bagacay", "Barcelona (Pob.)", "Bayawas",
        "Binisitahan", "Burabod", "Caladgao", "Calapi", "Calomagon", "Casili",
        "Cogon", "Dolos", "Gabon", "Lago", "Lapinig", "Lourdes", "Mabuhay",
        "Magroyong", "Maharlika", "Muladbucad Grande", "Muladbucad Pequeño",
        "Nato", "Pandan", "Parana", "Rizal", "San Pascual", "Santa Cruz",
        "Sawanga", "Serrano (Pob.)", "Tiris", "Togbongon", "Tomalaytay",
    ],
    "Bulan": [
        "A. Bonifacio", "Alatawan", "Antipolo", "Aquino (Balocawe)", "Bagacay",
        "Bagatao Island", "Bagumbayan", "Bical", "Buraburan", "Calomagon",
        "Calpi", "Camagong", "Camcaman", "Cogon", "Danao", "E. Quirino",
        "Fabrica", "Gamot", "Gate", "Imelda (Cagtalaba)", "Inang-ugan",
        "J. Gerona", "Jupi", "Lajong", "Libertad", "Magsaysay", "Maria Cristina",
        "Marinab", "Nasuje", "Obrero", "Omon", "Osme", "Otavi", "Padre Santos",
        "Palale", "Pangpang", "Port Area", "Rizal", "Sagrada", "Sagurong",
        "Salvacion", "San Francisco (Pob.)", "San Isidro", "San Juan Bag-o",
        "San Ramon", "San Vicente", "Santa Cruz", "Santa Remedios", "Sevilla",
        "Sumapoc", "Talisay", "Ticol",
        "Zone 1 (Pob.)", "Zone 2 (Pob.)", "Zone 3 (Pob.)", "Zone 4 (Pob.)",
        "Zone 5 (Pob.)", "Zone 6 (Pob.)", "Zone 7 (Pob.)", "Zone 8 (Pob.)",
    ],
    "Bulusan": [
        "Bacolod", "Bolos", "Buenavista", "Bulusan (Pob.)", "Cogon",
        "Dancalan", "East Bulusan", "Intusan", "Maagnas", "Mabini", "Olangon",
        "San Bernardo", "San Francisco", "San Juan", "San Pedro", "San Roque",
        "Santa Barbara", "Sapngan", "Santo Domingo", "Tinampo",
    ],
    "Casiguran": [
        "Adovis", "Agcawilan", "Aroganga", "Bagalaya", "Bagumbayan",
        "Balungay", "Bogtong (Pob.)", "Buenavista", "Burgos", "Cabugao",
        "Caditaan", "Casiguran (Pob.)", "Colambis", "Dorobong", "Gabao",
        "Gatbo", "Imelda", "Jupi", "Lagta", "Lajong", "Lungib", "Pawa",
        "Salvacion", "San Antonio", "Tinago", "Tindog", "Trece Martires",
    ],
    "Castilla": [
        "Bagacay", "Bagsangan", "Castilla (Pob.)", "Cumadcad", "Dorog",
        "Flordeliz", "Hamorocon", "Inlagadian", "Lungib", "Mabini", "Maybog",
        "Maysalay", "Minarog", "Nagsiya", "Oroc", "Pacao", "Poctol", "Punta",
        "Sabang", "San Isidro", "San Juan", "Sua", "Tubog",
    ],
    "Donsol": [
        "Alin", "Aroroy", "Awao", "Ayugan", "Bangate", "Bonbon", "Buenavista",
        "Cogon", "Dancalan", "Donsol (Pob.)", "Felicidad", "Ferreras", "Fianza",
        "Gabao", "Gate", "Gogon Centro", "Gogon Sirangan", "Iba", "Jereza",
        "Lung-ag", "Mapaso", "Marilim", "Pandan", "Pinamanaan", "Sabang",
        "Sugcad",
    ],
    "Gubat": [
        "Ariman", "Bagamanoc", "Balud (Pob.)", "Bentuco", "Beriran", "Biga",
        "Burabod", "Cabigaan", "Caditaan", "Calatagan", "Camp Gana", "Cogon",
        "Embarcadero (Pob.)", "Estrella", "Gabao", "Gate", "Hamoraw", "Kagdi",
        "Kalayaan", "Libtong", "Lungib", "Manapao", "Mangurangen", "Matolba",
        "Nato", "North Centro (Pob.)", "North Villahermosa", "Palanas",
        "Payawin", "Punta", "Quirapi", "Rizal", "San Pedro", "Somogod",
        "South Centro (Pob.)", "South Villahermosa", "Sugod", "Tabog",
        "Tiris", "Tughan",
    ],
    "Irosin": [
        "Bagsangan", "Batang", "Bolos", "Buenavista", "Casini", "Cogon",
        "Gulang-gulang", "Gumabao", "Irosin (Pob.)", "Liang", "Macawayan",
        "Mapaso", "Monbon", "Namo", "Patag", "San Agustin", "San Juan",
        "San Pedro", "Tabon-tabon", "Tinampo", "Tongco",
    ],
    "Juban": [
        "Abuyog", "Bagacay", "Buraburan", "Cabigaan", "Calabog", "Candawon",
        "Casuruan", "Dangcalan", "Guruyan", "Intol", "Juban (Pob.)", "Lipata",
        "Lon-oy", "Mabini", "Mabreto", "Macalidong", "San Vicente",
        "Santa Cruz", "Tagdon",
    ],
    "Magallanes": [
        "Baaga", "Bugtong", "Busay", "Calawag", "Cogon", "Dasmariñas",
        "Itulan", "Lanang", "Magallanes (Pob.)", "Magtangol", "Marogong",
        "Olod", "Panganiban", "Patag", "San Juan", "San Pascual", "Sawanga",
        "Sumaro",
    ],
    "Matnog": [
        "Ariman", "Bagatao", "Banogbanog", "Batong Paloway", "Bonga",
        "Bulusan", "Busay", "Calintaan", "Camachiles", "Catanagan", "Hidhid",
        "Labnig", "Matnog (Pob.)", "Nagtangkalan", "Palupi", "Port Jamboree",
        "San Antonio", "San Francisco", "San Isidro", "San Rafael", "Tinampo",
    ],
    "Pilar": [
        "Arado", "Cabigaan", "Cawayan", "Escuela", "Itangon", "Laboy",
        "Lajong", "Mabini", "Maglatawa", "Magroyong", "Olandia", "Pilar (Pob.)",
        "Pinugusan", "Poctol", "Salvacion", "Sampaloc", "Santa Cruz", "Tinampo",
    ],
    "Prieto Diaz": [
        "Agdao", "Almendras (Pob.)", "Buenavista", "Cabigaan", "Caditaan",
        "Calao", "Calpi", "Hidhid", "Lungib", "Managanaga", "Panganiban",
        "Prieto Diaz (Pob.)", "Salvacion", "San Nicolas", "Trece Martires",
        "Tulapos", "Tupas",
    ],
    "Santa Magdalena": [
        "Almendras", "Balang-balang", "Barobaybay", "Bolod", "Buenavista",
        "Burabod", "Cabigaan", "Calao", "Cogon", "Escuela", "Manga", "Putiao",
        "Rizal", "Sagnay", "San Juan", "Santa Magdalena (Pob.)", "Tabon-tabon",
    ],
    "Sorsogon City": [
        "Abuyog", "Almendras", "Anibong", "Añog", "Apdo", "Bagalaya",
        "Bagsangan", "Balete", "Balogo", "Basud", "Bibincahan", "Bitan-o (Pob.)",
        "Bon-ot", "Bucal", "Buenavista", "Burabod", "Cabid-an", "Cambulaga",
        "Capuy", "Cogon", "East District (Pob.)", "Gimaloto", "Guinlajon",
        "Guruyan", "Igang", "Macabog", "Maningcay de Oro", "Maningcay de Pobre",
        "North District (Pob.)", "Ogod", "Olangon", "Osiao", "Paguriran",
        "Pangdan", "Panlayaan", "Piot", "Polvorista", "Putiao", "Rawis",
        "Rizal (Pob.)", "Salog", "Sampaloc (Pob.)", "San Isidro", "San Juan (Pob.)",
        "San Pascual", "San Roque", "Sapi-an", "Sirangan", "Sulucan", "Talisay",
        "Tugos", "West District (Pob.)",
    ],
}

# Build fast-lookup sets (lower-case key → canonical label)
_MUNI_LOWER: dict[str, str] = {m.lower(): m for m in SORSOGON_MUNICIPALITIES}
_BRGY_LOWER: dict[str, dict[str, str]] = {
    muni: {b.lower(): b for b in blist}
    for muni, blist in SORSOGON_BARANGAYS.items()
}


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def normalize_barangay_label(raw: str) -> str:
    """
    Trim whitespace, collapse internal spaces, apply title case.

    Handles common cases:
    - "ZONE 1"         → "Zone 1"
    - "  zone  1  "    → "Zone 1"
    - "Zone 1 (Pob.)"  → "Zone 1 (Pob.)"   (parenthetical preserved)
    - "A. BONIFACIO"   → "A. Bonifacio"
    """
    if not raw:
        return ""
    s = " ".join(str(raw).split())
    return s.title()


def normalize_municipality_label(raw: str) -> str:
    """
    Title-case normalisation for municipality strings.

    Also handles common prefixes returned by geocoders, e.g.
    "Municipality of Bulan" → "Bulan".
    """
    if not raw:
        return ""
    s = " ".join(str(raw).split())
    s = s.replace("Municipality of ", "").replace(" Municipality", "").strip()
    return s.title()


def canonical_municipality(raw: str) -> str | None:
    """
    Return the canonical dropdown label for *raw*, or None if not found.
    Performs exact (case-insensitive) match first, then substring match.
    """
    if not raw:
        return None
    cleaned = normalize_municipality_label(raw).lower()
    if cleaned in _MUNI_LOWER:
        return _MUNI_LOWER[cleaned]
    for key, label in _MUNI_LOWER.items():
        if key in cleaned or cleaned in key:
            return label
    return None


def canonical_barangay(raw: str, municipality: str) -> str | None:
    """
    Return the canonical barangay label for *raw* within *municipality*,
    or None if not found.
    """
    if not raw or not municipality:
        return None
    muni_label = canonical_municipality(municipality) or municipality
    lookup = _BRGY_LOWER.get(muni_label, {})
    cleaned = normalize_barangay_label(raw).lower()
    if cleaned in lookup:
        return lookup[cleaned]
    for key, label in lookup.items():
        base_key = key.split("(")[0].strip()
        if base_key == cleaned or cleaned in key or key in cleaned:
            return label
    return None


def is_valid_combination(municipality: str, barangay: str) -> bool:
    """
    Return True if *barangay* belongs to *municipality* in the official dataset.
    """
    muni = canonical_municipality(municipality)
    if muni is None:
        return False
    brgy = canonical_barangay(barangay, muni)
    return brgy is not None
