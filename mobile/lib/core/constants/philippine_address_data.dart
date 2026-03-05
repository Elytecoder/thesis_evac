/// Philippine Address Data for Evacuation Center Management
/// 
/// Provides structured address selection with cascading dropdowns
/// Focused on Sorsogon Province for the Bulan, Sorsogon evacuation system

class PhilippineAddressData {
  // Province list (focused on Sorsogon)
  static const List<String> provinces = [
    'Sorsogon',
  ];
  
  // Municipalities by province
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
  
  // Barangays by municipality (Bulan focus)
  static const Map<String, List<String>> barangays = {
    'Bulan': [
      'Zone 1 (Pob.)',
      'Zone 2 (Pob.)',
      'Zone 3 (Pob.)',
      'Zone 4 (Pob.)',
      'Zone 5 (Pob.)',
      'Zone 6 (Pob.)',
      'Zone 7 (Pob.)',
      'Zone 8 (Pob.)',
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
    ],
    'Sorsogon City': [
      'Abuyog',
      'Balogo',
      'Basud',
      'Bibincahan',
      'Bitan-o (Pob.)',
      'Bucal',
      'Buenavista',
      'Cabid-an',
      'Cambulaga',
      'Capuy',
      'East District (Pob.)',
      'Gimaloto',
      'Macabog',
      'North District (Pob.)',
      'Osiao',
      'Pangdan',
      'Polvorista',
      'Poblacion (Pob.)',
      'Rawis',
      'Rizal Street (Pob.)',
      'Salog',
      'Sampaloc (Pob.)',
      'San Juan (Pob.)',
      'San Roque',
      'Sirangan',
      'Sulucan',
      'Talisay',
      'West District (Pob.)',
    ],
    // Add more municipalities as needed
    'Barcelona': ['Pob. 1', 'Pob. 2', 'Pob. 3', 'Putiao', 'San Andres', 'San Isidro', 'San Jose', 'San Pablo', 'San Rafael', 'San Ramon'],
    'Casiguran': ['Pob. 1', 'Pob. 2', 'Pob. 3', 'Trece Martires', 'Adovis', 'Bogtong', 'Burgos', 'Colambis'],
  };
  
  /// Get municipalities for a given province
  static List<String> getMunicipalities(String province) {
    return municipalities[province] ?? [];
  }
  
  /// Get barangays for a given municipality
  static List<String> getBarangays(String municipality) {
    return barangays[municipality] ?? [];
  }
  
  /// Validate if address combination is valid
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
}
