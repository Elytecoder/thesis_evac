// Canonical Philippine address data for Sorsogon Province.
//
// This is the SINGLE source of truth used by all screens:
//   - Registration screen  (imported via lib/data/philippine_address_data.dart)
//   - Admin: Add / Edit Evacuation Center screens
//
// Data: Official PSA / COMELEC barangay lists for all 15 municipalities /
// cities in Sorsogon province. Barangay names are title-cased and sorted
// alphabetically within each municipality so the dropdown is easy to scan.
//
// Helpers:
//   fuzzyMatchMunicipality()  — normalise a raw Nominatim string to a known
//                               dropdown label (used after reverse geocoding).
//   fuzzyMatchBarangay()      — same, within a given municipality.

class PhilippineAddressData {
  // ── Province list ────────────────────────────────────────────────────────

  static const List<String> provinces = ['Sorsogon'];

  // ── Municipalities ───────────────────────────────────────────────────────

  static const Map<String, List<String>> municipalities = {
    'Sorsogon': [
      'Barcelona',
      'Bulan',
      'Bulusan',
      'Casiguran',
      'Castilla',
      'Donsol',
      'Gubat',
      'Irosin',
      'Juban',
      'Magallanes',
      'Matnog',
      'Pilar',
      'Prieto Diaz',
      'Santa Magdalena',
      'Sorsogon City',
    ],
  };
  
  // ── Barangays ────────────────────────────────────────────────────────────
  // Sorted alphabetically within each municipality.
  // Source: PSA PSGC 2023 / COMELEC official lists.

  static const Map<String, List<String>> barangays = {
    // ── Barcelona ────────────────────────────────────────────────────────
    'Barcelona': [
      'Alejandro',
      'Ariman',
      'Bagacay',
      'Barcelona (Pob.)',
      'Bayawas',
      'Binisitahan',
      'Burabod',
      'Caladgao',
      'Calapi',
      'Calomagon',
      'Casili',
      'Cogon',
      'Dolos',
      'Gabon',
      'Lago',
      'Lapinig',
      'Lourdes',
      'Mabuhay',
      'Magroyong',
      'Maharlika',
      'Muladbucad Grande',
      'Muladbucad Pequeño',
      'Nato',
      'Pandan',
      'Parana',
      'Rizal',
      'San Pascual',
      'Santa Cruz',
      'Sawanga',
      'Serrano (Pob.)',
      'Tiris',
      'Togbongon',
      'Tomalaytay',
    ],

    // ── Bulan (primary focus municipality) ───────────────────────────────
    'Bulan': [
      'A. Bonifacio',
      'Alatawan',
      'Antipolo',
      'Aquino (Balocawe)',
      'Bagacay',
      'Bagatao Island',
      'Bagumbayan',
      'Bical',
      'Buraburan',
      'Calomagon',
      'Calpi',
      'Camagong',
      'Camcaman',
      'Cogon',
      'Danao',
      'E. Quirino',
      'Fabrica',
      'Gamot',
      'Gate',
      'Imelda (Cagtalaba)',
      'Inang-ugan',
      'J. Gerona',
      'Jupi',
      'Lajong',
      'Libertad',
      'Magsaysay',
      'Maria Cristina',
      'Marinab',
      'Nasuje',
      'Obrero',
      'Omon',
      'Osme',
      'Otavi',
      'Padre Santos',
      'Palale',
      'Pangpang',
      'Port Area',
      'Rizal',
      'Sagrada',
      'Sagurong',
      'Salvacion',
      'San Francisco (Pob.)',
      'San Isidro',
      'San Juan Bag-o',
      'San Ramon',
      'San Vicente',
      'Santa Cruz',
      'Santa Remedios',
      'Sevilla',
      'Sumapoc',
      'Talisay',
      'Ticol',
      'Zone 1 (Pob.)',
      'Zone 2 (Pob.)',
      'Zone 3 (Pob.)',
      'Zone 4 (Pob.)',
      'Zone 5 (Pob.)',
      'Zone 6 (Pob.)',
      'Zone 7 (Pob.)',
      'Zone 8 (Pob.)',
    ],

    // ── Bulusan ──────────────────────────────────────────────────────────
    'Bulusan': [
      'Bacolod',
      'Bolos',
      'Buenavista',
      'Bulusan (Pob.)',
      'Cogon',
      'Dancalan',
      'East Bulusan',
      'Intusan',
      'Maagnas',
      'Mabini',
      'Olangon',
      'San Bernardo',
      'San Francisco',
      'San Juan',
      'San Pedro',
      'San Roque',
      'Santa Barbara',
      'Sapngan',
      'Santo Domingo',
      'Tinampo',
    ],

    // ── Casiguran ────────────────────────────────────────────────────────
    'Casiguran': [
      'Adovis',
      'Agcawilan',
      'Aroganga',
      'Bagalaya',
      'Bagumbayan',
      'Balungay',
      'Bogtong (Pob.)',
      'Buenavista',
      'Burgos',
      'Cabugao',
      'Caditaan',
      'Casiguran (Pob.)',
      'Colambis',
      'Dorobong',
      'Gabao',
      'Gatbo',
      'Imelda',
      'Jupi',
      'Lagta',
      'Lajong',
      'Lungib',
      'Pawa',
      'Salvacion',
      'San Antonio',
      'Tinago',
      'Tindog',
      'Trece Martires',
    ],

    // ── Castilla ─────────────────────────────────────────────────────────
    'Castilla': [
      'Bagacay',
      'Bagsangan',
      'Castilla (Pob.)',
      'Cumadcad',
      'Dorog',
      'Flordeliz',
      'Hamorocon',
      'Inlagadian',
      'Lungib',
      'Mabini',
      'Maybog',
      'Maysalay',
      'Minarog',
      'Nagsiya',
      'Oroc',
      'Pacao',
      'Poctol',
      'Punta',
      'Sabang',
      'San Isidro',
      'San Juan',
      'Sua',
      'Tubog',
    ],

    // ── Donsol ───────────────────────────────────────────────────────────
    'Donsol': [
      'Alin',
      'Aroroy',
      'Awao',
      'Ayugan',
      'Bangate',
      'Bonbon',
      'Buenavista',
      'Cogon',
      'Dancalan',
      'Donsol (Pob.)',
      'Felicidad',
      'Ferreras',
      'Fianza',
      'Gabao',
      'Gate',
      'Gogon Centro',
      'Gogon Sirangan',
      'Iba',
      'Jereza',
      'Lung-ag',
      'Mapaso',
      'Marilim',
      'Pandan',
      'Pinamanaan',
      'Sabang',
      'Sugcad',
    ],

    // ── Gubat ────────────────────────────────────────────────────────────
    'Gubat': [
      'Ariman',
      'Bagamanoc',
      'Balud (Pob.)',
      'Bentuco',
      'Beriran',
      'Biga',
      'Burabod',
      'Cabigaan',
      'Caditaan',
      'Calatagan',
      'Camp Gana',
      'Cogon',
      'Embarcadero (Pob.)',
      'Estrella',
      'Gabao',
      'Gate',
      'Hamoraw',
      'Kagdi',
      'Kalayaan',
      'Libtong',
      'Lungib',
      'Manapao',
      'Mangurangen',
      'Matolba',
      'Nato',
      'North Centro (Pob.)',
      'North Villahermosa',
      'Palanas',
      'Payawin',
      'Punta',
      'Quirapi',
      'Rizal',
      'San Pedro',
      'Somogod',
      'South Centro (Pob.)',
      'South Villahermosa',
      'Sugod',
      'Tabog',
      'Tiris',
      'Tughan',
    ],

    // ── Irosin ───────────────────────────────────────────────────────────
    'Irosin': [
      'Bagsangan',
      'Batang',
      'Bolos',
      'Buenavista',
      'Casini',
      'Cogon',
      'Gulang-gulang',
      'Gumabao',
      'Irosin (Pob.)',
      'Liang',
      'Macawayan',
      'Mapaso',
      'Monbon',
      'Namo',
      'Patag',
      'San Agustin',
      'San Juan',
      'San Pedro',
      'Tabon-tabon',
      'Tinampo',
      'Tongco',
    ],

    // ── Juban ────────────────────────────────────────────────────────────
    'Juban': [
      'Abuyog',
      'Bagacay',
      'Buraburan',
      'Cabigaan',
      'Calabog',
      'Candawon',
      'Casuruan',
      'Dangcalan',
      'Guruyan',
      'Intol',
      'Juban (Pob.)',
      'Lipata',
      'Lon-oy',
      'Mabini',
      'Mabreto',
      'Macalidong',
      'San Vicente',
      'Santa Cruz',
      'Tagdon',
    ],

    // ── Magallanes ───────────────────────────────────────────────────────
    'Magallanes': [
      'Baaga',
      'Bugtong',
      'Busay',
      'Calawag',
      'Cogon',
      'Dasmariñas',
      'Itulan',
      'Lanang',
      'Magallanes (Pob.)',
      'Magtangol',
      'Marogong',
      'Olod',
      'Panganiban',
      'Patag',
      'San Juan',
      'San Pascual',
      'Sawanga',
      'Sumaro',
    ],

    // ── Matnog ───────────────────────────────────────────────────────────
    'Matnog': [
      'Ariman',
      'Bagatao',
      'Banogbanog',
      'Batong Paloway',
      'Bonga',
      'Bulusan',
      'Busay',
      'Calintaan',
      'Camachiles',
      'Catanagan',
      'Hidhid',
      'Labnig',
      'Matnog (Pob.)',
      'Nagtangkalan',
      'Palupi',
      'Port Jamboree',
      'San Antonio',
      'San Francisco',
      'San Isidro',
      'San Rafael',
      'Tinampo',
    ],

    // ── Pilar ────────────────────────────────────────────────────────────
    'Pilar': [
      'Arado',
      'Cabigaan',
      'Cawayan',
      'Escuela',
      'Itangon',
      'Laboy',
      'Lajong',
      'Mabini',
      'Maglatawa',
      'Magroyong',
      'Olandia',
      'Pilar (Pob.)',
      'Pinugusan',
      'Poctol',
      'Salvacion',
      'Sampaloc',
      'Santa Cruz',
      'Tinampo',
    ],

    // ── Prieto Diaz ──────────────────────────────────────────────────────
    'Prieto Diaz': [
      'Agdao',
      'Almendras (Pob.)',
      'Buenavista',
      'Cabigaan',
      'Caditaan',
      'Calao',
      'Calpi',
      'Hidhid',
      'Lungib',
      'Managanaga',
      'Panganiban',
      'Prieto Diaz (Pob.)',
      'Salvacion',
      'San Nicolas',
      'Trece Martires',
      'Tulapos',
      'Tupas',
    ],

    // ── Santa Magdalena ──────────────────────────────────────────────────
    'Santa Magdalena': [
      'Almendras',
      'Balang-balang',
      'Barobaybay',
      'Bolod',
      'Buenavista',
      'Burabod',
      'Cabigaan',
      'Calao',
      'Cogon',
      'Escuela',
      'Manga',
      'Putiao',
      'Rizal',
      'Sagnay',
      'San Juan',
      'Santa Magdalena (Pob.)',
      'Tabon-tabon',
    ],

    // ── Sorsogon City ────────────────────────────────────────────────────
    'Sorsogon City': [
      'Abuyog',
      'Almendras',
      'Anibong',
      'Añog',
      'Apdo',
      'Bagalaya',
      'Bagsangan',
      'Balete',
      'Balogo',
      'Basud',
      'Bibincahan',
      'Bitan-o (Pob.)',
      'Bon-ot',
      'Bucal',
      'Buenavista',
      'Burabod',
      'Cabid-an',
      'Cambulaga',
      'Capuy',
      'Cogon',
      'East District (Pob.)',
      'Gimaloto',
      'Guinlajon',
      'Guruyan',
      'Igang',
      'Macabog',
      'Maningcay de Oro',
      'Maningcay de Pobre',
      'North District (Pob.)',
      'Ogod',
      'Olangon',
      'Osiao',
      'Paguriran',
      'Pangdan',
      'Panlayaan',
      'Piot',
      'Polvorista',
      'Putiao',
      'Rawis',
      'Rizal (Pob.)',
      'Salog',
      'Sampaloc (Pob.)',
      'San Isidro',
      'San Juan (Pob.)',
      'San Pascual',
      'San Roque',
      'Sapi-an',
      'Sirangan',
      'Sulucan',
      'Talisay',
      'Tugos',
      'West District (Pob.)',
    ],
  };

  // ── Public API ────────────────────────────────────────────────────────────

  /// All provinces (for province dropdown).
  static List<String> getProvinces() => List<String>.from(provinces);

  /// Municipalities for a given province.
  static List<String> getMunicipalities(String province) =>
      List<String>.from(municipalities[province] ?? const []);

  /// Barangays for a given municipality, sorted alphabetically.
  static List<String> getBarangays(String municipality) =>
      List<String>.from(barangays[municipality] ?? const []);

  /// Validate a full address combination.
  static bool isValidAddress({
    required String province,
    required String municipality,
    required String barangay,
  }) {
    if (!provinces.contains(province)) return false;
    if (!getMunicipalities(province).contains(municipality)) return false;
    if (!getBarangays(municipality).contains(barangay)) return false;
    return true;
  }

  // ── Fuzzy matching helpers (used after reverse geocoding) ─────────────────

  /// Normalise a raw Nominatim municipality string to a canonical dropdown label.
  ///
  /// Handles common mismatches:
  /// - "Sorsogon City" stripped to "Sorsogon" (Nominatim quirk) → restored
  /// - "Municipality of Bulan" → "Bulan"
  /// - Case differences
  ///
  /// Returns null if no match is found.
  static String? fuzzyMatchMunicipality(String raw) {
    if (raw.trim().isEmpty) return null;

    // Strip common prefixes/suffixes that Nominatim sometimes adds,
    // but keep "City" so "Sorsogon City" still matches.
    final cleaned = raw
        .replaceAll('Municipality of ', '')
        .replaceAll(' Municipality', '')
        .trim();
    final cleanedLower = cleaned.toLowerCase();

    for (final province in municipalities.values) {
      for (final muni in province) {
        final muniLower = muni.toLowerCase();
        if (muniLower == cleanedLower) return muni; // exact
      }
    }

    // Substring match (e.g. "Irosin" inside "Irosin, Sorsogon")
    for (final province in municipalities.values) {
      for (final muni in province) {
        final muniLower = muni.toLowerCase();
        if (muniLower.contains(cleanedLower) ||
            cleanedLower.contains(muniLower)) {
          return muni;
        }
      }
    }
    return null;
  }

  /// Normalise a raw Nominatim barangay string to a canonical dropdown label.
  ///
  /// Strips common prefixes ("Barangay ", "Brgy. "), then does exact and
  /// partial matching within the given municipality's barangay list.
  ///
  /// Returns null if no match is found.
  static String? fuzzyMatchBarangay(String raw, String municipality) {
    if (raw.trim().isEmpty) return null;

    final stripped = raw
        .replaceAll('Barangay ', '')
        .replaceAll('Brgy. ', '')
        .replaceAll('Brgy ', '')
        .trim();
    final strippedLower = stripped.toLowerCase();

    final list = getBarangays(municipality);

    // Exact match (case-insensitive)
    for (final b in list) {
      if (b.toLowerCase() == strippedLower) return b;
    }

    // Strip parenthetical qualifiers for partial matching
    // e.g. "Cogon" should match "Cogon" in list even if list has plain "Cogon"
    for (final b in list) {
      final baseLower =
          b.toLowerCase().replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
      if (baseLower == strippedLower) return b;
    }

    // Contains match (last resort)
    for (final b in list) {
      final bLower = b.toLowerCase();
      if (bLower.contains(strippedLower) || strippedLower.contains(bLower)) {
        return b;
      }
    }
    return null;
  }
}
