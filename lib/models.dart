class CardSearchResult {
  const CardSearchResult({
    required this.id,
    required this.name,
    required this.setCode,
    required this.collectorNumber,
    this.imageUri,
  });

  final String id;
  final String name;
  final String setCode;
  final String collectorNumber;
  final String? imageUri;

  String get subtitleLabel {
    final setLabel = setCode.toUpperCase();
    return collectorNumber.isEmpty ? setLabel : '$setLabel  $collectorNumber';
  }

  String get displayLabel {
    if (setCode.isEmpty && collectorNumber.isEmpty) {
      return name;
    }
    return '$name (${subtitleLabel})';
  }
}

class CollectionInfo {
  const CollectionInfo({
    required this.id,
    required this.name,
    required this.cardCount,
  });

  final int id;
  final String name;
  final int cardCount;
}

class CollectionCardEntry {
  const CollectionCardEntry({
    required this.cardId,
    required this.name,
    required this.setCode,
    required this.setName,
    required this.collectorNumber,
    required this.rarity,
    required this.quantity,
    required this.foil,
    required this.altArt,
    this.imageUri,
    this.cardJson,
  });

  final String cardId;
  final String name;
  final String setCode;
  final String setName;
  final String collectorNumber;
  final String rarity;
  final int quantity;
  final bool foil;
  final bool altArt;
  final String? imageUri;
  final String? cardJson;

  String get subtitleLabel {
    final setLabel = setCode.toUpperCase();
    return collectorNumber.isEmpty ? setLabel : '$setLabel  $collectorNumber';
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
