class CardSearchResult {
  const CardSearchResult({
    required this.id,
    required this.name,
    required this.setCode,
    required this.setName,
    required this.collectorNumber,
    required this.rarity,
    required this.typeLine,
    required this.colors,
    required this.colorIdentity,
    this.imageUri,
  });

  final String id;
  final String name;
  final String setCode;
  final String setName;
  final String collectorNumber;
  final String rarity;
  final String typeLine;
  final String colors;
  final String colorIdentity;
  final String? imageUri;

  String get subtitleLabel {
    return _formatSetLabel(
      setName: setName,
      setCode: setCode,
      collectorNumber: collectorNumber,
    );
  }

  String get displayLabel {
    if (setCode.isEmpty && collectorNumber.isEmpty) {
      return name;
    }
    return '$name ($subtitleLabel)';
  }
}

class CollectionInfo {
  const CollectionInfo({
    required this.id,
    required this.name,
    required this.cardCount,
    required this.type,
    this.filter,
  });

  final int id;
  final String name;
  final int cardCount;
  final CollectionType type;
  final CollectionFilter? filter;
}

class CollectionCardEntry {
  const CollectionCardEntry({
    required this.cardId,
    required this.name,
    required this.setCode,
    required this.setName,
    required this.setTotal,
    required this.collectorNumber,
    required this.rarity,
    required this.typeLine,
    required this.manaCost,
    required this.oracleText,
    required this.manaValue,
    required this.lang,
    required this.artist,
    required this.power,
    required this.toughness,
    required this.loyalty,
    required this.colors,
    required this.colorIdentity,
    required this.releasedAt,
    required this.quantity,
    required this.foil,
    required this.altArt,
    this.imageUri,
  });

  final String cardId;
  final String name;
  final String setCode;
  final String setName;
  final int? setTotal;
  final String collectorNumber;
  final String rarity;
  final String typeLine;
  final String manaCost;
  final String oracleText;
  final double? manaValue;
  final String lang;
  final String artist;
  final String power;
  final String toughness;
  final String loyalty;
  final String colors;
  final String colorIdentity;
  final String releasedAt;
  final int quantity;
  final bool foil;
  final bool altArt;
  final String? imageUri;

  String get subtitleLabel {
    return _formatSetLabel(
      setName: setName,
      setCode: setCode,
      collectorNumber: collectorNumber,
    );
  }
}

class SetInfo {
  const SetInfo({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

String _formatSetLabel({
  required String setName,
  required String setCode,
  required String collectorNumber,
}) {
  final label = setName.trim().isNotEmpty ? setName.trim() : setCode.toUpperCase();
  if (label.isEmpty) {
    return collectorNumber.isEmpty ? '' : '#$collectorNumber';
  }
  return collectorNumber.isEmpty ? label : '$label #$collectorNumber';
}
enum CollectionType {
  all,
  set,
  custom,
}

CollectionType collectionTypeFromDb(String? value) {
  switch (value?.toLowerCase()) {
    case 'all':
      return CollectionType.all;
    case 'set':
      return CollectionType.set;
    case 'custom':
    default:
      return CollectionType.custom;
  }
}

String collectionTypeToDb(CollectionType type) {
  switch (type) {
    case CollectionType.all:
      return 'all';
    case CollectionType.set:
      return 'set';
    case CollectionType.custom:
      return 'custom';
  }
}

class CollectionFilter {
  const CollectionFilter({
    this.name,
    this.artist,
    this.manaMin,
    this.manaMax,
    this.sets = const {},
    this.rarities = const {},
    this.colors = const {},
    this.types = const {},
  });

  final String? name;
  final String? artist;
  final int? manaMin;
  final int? manaMax;
  final Set<String> sets;
  final Set<String> rarities;
  final Set<String> colors;
  final Set<String> types;

  Map<String, dynamic> toJson() => {
        'name': name,
        'artist': artist,
        'manaMin': manaMin,
        'manaMax': manaMax,
        'sets': sets.toList(),
        'rarities': rarities.toList(),
        'colors': colors.toList(),
        'types': types.toList(),
      };

  factory CollectionFilter.fromJson(Map<String, dynamic> json) {
    Set<String> types = Set<String>.from(json['types'] as List? ?? const []);
    if (types.isEmpty) {
      final legacyType = json['type'];
      if (legacyType is String && legacyType.trim().isNotEmpty) {
        types = {legacyType};
      }
    }
    return CollectionFilter(
      name: json['name'] as String?,
      artist: json['artist'] as String?,
      manaMin: json['manaMin'] is int ? json['manaMin'] as int : null,
      manaMax: json['manaMax'] is int ? json['manaMax'] as int : null,
      sets: Set<String>.from(json['sets'] as List? ?? const []),
      rarities: Set<String>.from(json['rarities'] as List? ?? const []),
      colors: Set<String>.from(json['colors'] as List? ?? const []),
      types: types,
    );
  }
}
