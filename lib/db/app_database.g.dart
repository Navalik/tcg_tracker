// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oracleIdMeta = const VerificationMeta(
    'oracleId',
  );
  @override
  late final GeneratedColumn<String> oracleId = GeneratedColumn<String>(
    'oracle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setCodeMeta = const VerificationMeta(
    'setCode',
  );
  @override
  late final GeneratedColumn<String> setCode = GeneratedColumn<String>(
    'set_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collectorNumberMeta = const VerificationMeta(
    'collectorNumber',
  );
  @override
  late final GeneratedColumn<String> collectorNumber = GeneratedColumn<String>(
    'collector_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeLineMeta = const VerificationMeta(
    'typeLine',
  );
  @override
  late final GeneratedColumn<String> typeLine = GeneratedColumn<String>(
    'type_line',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manaCostMeta = const VerificationMeta(
    'manaCost',
  );
  @override
  late final GeneratedColumn<String> manaCost = GeneratedColumn<String>(
    'mana_cost',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releasedAtMeta = const VerificationMeta(
    'releasedAt',
  );
  @override
  late final GeneratedColumn<String> releasedAt = GeneratedColumn<String>(
    'released_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrisMeta = const VerificationMeta(
    'imageUris',
  );
  @override
  late final GeneratedColumn<String> imageUris = GeneratedColumn<String>(
    'image_uris',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardFacesMeta = const VerificationMeta(
    'cardFaces',
  );
  @override
  late final GeneratedColumn<String> cardFaces = GeneratedColumn<String>(
    'card_faces',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardJsonMeta = const VerificationMeta(
    'cardJson',
  );
  @override
  late final GeneratedColumn<String> cardJson = GeneratedColumn<String>(
    'card_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    oracleId,
    name,
    setCode,
    collectorNumber,
    rarity,
    typeLine,
    manaCost,
    lang,
    releasedAt,
    imageUris,
    cardFaces,
    cardJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Card> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('oracle_id')) {
      context.handle(
        _oracleIdMeta,
        oracleId.isAcceptableOrUnknown(data['oracle_id']!, _oracleIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('set_code')) {
      context.handle(
        _setCodeMeta,
        setCode.isAcceptableOrUnknown(data['set_code']!, _setCodeMeta),
      );
    }
    if (data.containsKey('collector_number')) {
      context.handle(
        _collectorNumberMeta,
        collectorNumber.isAcceptableOrUnknown(
          data['collector_number']!,
          _collectorNumberMeta,
        ),
      );
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    }
    if (data.containsKey('type_line')) {
      context.handle(
        _typeLineMeta,
        typeLine.isAcceptableOrUnknown(data['type_line']!, _typeLineMeta),
      );
    }
    if (data.containsKey('mana_cost')) {
      context.handle(
        _manaCostMeta,
        manaCost.isAcceptableOrUnknown(data['mana_cost']!, _manaCostMeta),
      );
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    }
    if (data.containsKey('released_at')) {
      context.handle(
        _releasedAtMeta,
        releasedAt.isAcceptableOrUnknown(data['released_at']!, _releasedAtMeta),
      );
    }
    if (data.containsKey('image_uris')) {
      context.handle(
        _imageUrisMeta,
        imageUris.isAcceptableOrUnknown(data['image_uris']!, _imageUrisMeta),
      );
    }
    if (data.containsKey('card_faces')) {
      context.handle(
        _cardFacesMeta,
        cardFaces.isAcceptableOrUnknown(data['card_faces']!, _cardFacesMeta),
      );
    }
    if (data.containsKey('card_json')) {
      context.handle(
        _cardJsonMeta,
        cardJson.isAcceptableOrUnknown(data['card_json']!, _cardJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      oracleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oracle_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      setCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_code'],
      ),
      collectorNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collector_number'],
      ),
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      ),
      typeLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_line'],
      ),
      manaCost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mana_cost'],
      ),
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      ),
      releasedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}released_at'],
      ),
      imageUris: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_uris'],
      ),
      cardFaces: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_faces'],
      ),
      cardJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_json'],
      ),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class Card extends DataClass implements Insertable<Card> {
  final String id;
  final String? oracleId;
  final String name;
  final String? setCode;
  final String? collectorNumber;
  final String? rarity;
  final String? typeLine;
  final String? manaCost;
  final String? lang;
  final String? releasedAt;
  final String? imageUris;
  final String? cardFaces;
  final String? cardJson;
  const Card({
    required this.id,
    this.oracleId,
    required this.name,
    this.setCode,
    this.collectorNumber,
    this.rarity,
    this.typeLine,
    this.manaCost,
    this.lang,
    this.releasedAt,
    this.imageUris,
    this.cardFaces,
    this.cardJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || oracleId != null) {
      map['oracle_id'] = Variable<String>(oracleId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || setCode != null) {
      map['set_code'] = Variable<String>(setCode);
    }
    if (!nullToAbsent || collectorNumber != null) {
      map['collector_number'] = Variable<String>(collectorNumber);
    }
    if (!nullToAbsent || rarity != null) {
      map['rarity'] = Variable<String>(rarity);
    }
    if (!nullToAbsent || typeLine != null) {
      map['type_line'] = Variable<String>(typeLine);
    }
    if (!nullToAbsent || manaCost != null) {
      map['mana_cost'] = Variable<String>(manaCost);
    }
    if (!nullToAbsent || lang != null) {
      map['lang'] = Variable<String>(lang);
    }
    if (!nullToAbsent || releasedAt != null) {
      map['released_at'] = Variable<String>(releasedAt);
    }
    if (!nullToAbsent || imageUris != null) {
      map['image_uris'] = Variable<String>(imageUris);
    }
    if (!nullToAbsent || cardFaces != null) {
      map['card_faces'] = Variable<String>(cardFaces);
    }
    if (!nullToAbsent || cardJson != null) {
      map['card_json'] = Variable<String>(cardJson);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      oracleId: oracleId == null && nullToAbsent
          ? const Value.absent()
          : Value(oracleId),
      name: Value(name),
      setCode: setCode == null && nullToAbsent
          ? const Value.absent()
          : Value(setCode),
      collectorNumber: collectorNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(collectorNumber),
      rarity: rarity == null && nullToAbsent
          ? const Value.absent()
          : Value(rarity),
      typeLine: typeLine == null && nullToAbsent
          ? const Value.absent()
          : Value(typeLine),
      manaCost: manaCost == null && nullToAbsent
          ? const Value.absent()
          : Value(manaCost),
      lang: lang == null && nullToAbsent ? const Value.absent() : Value(lang),
      releasedAt: releasedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(releasedAt),
      imageUris: imageUris == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUris),
      cardFaces: cardFaces == null && nullToAbsent
          ? const Value.absent()
          : Value(cardFaces),
      cardJson: cardJson == null && nullToAbsent
          ? const Value.absent()
          : Value(cardJson),
    );
  }

  factory Card.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      id: serializer.fromJson<String>(json['id']),
      oracleId: serializer.fromJson<String?>(json['oracleId']),
      name: serializer.fromJson<String>(json['name']),
      setCode: serializer.fromJson<String?>(json['setCode']),
      collectorNumber: serializer.fromJson<String?>(json['collectorNumber']),
      rarity: serializer.fromJson<String?>(json['rarity']),
      typeLine: serializer.fromJson<String?>(json['typeLine']),
      manaCost: serializer.fromJson<String?>(json['manaCost']),
      lang: serializer.fromJson<String?>(json['lang']),
      releasedAt: serializer.fromJson<String?>(json['releasedAt']),
      imageUris: serializer.fromJson<String?>(json['imageUris']),
      cardFaces: serializer.fromJson<String?>(json['cardFaces']),
      cardJson: serializer.fromJson<String?>(json['cardJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'oracleId': serializer.toJson<String?>(oracleId),
      'name': serializer.toJson<String>(name),
      'setCode': serializer.toJson<String?>(setCode),
      'collectorNumber': serializer.toJson<String?>(collectorNumber),
      'rarity': serializer.toJson<String?>(rarity),
      'typeLine': serializer.toJson<String?>(typeLine),
      'manaCost': serializer.toJson<String?>(manaCost),
      'lang': serializer.toJson<String?>(lang),
      'releasedAt': serializer.toJson<String?>(releasedAt),
      'imageUris': serializer.toJson<String?>(imageUris),
      'cardFaces': serializer.toJson<String?>(cardFaces),
      'cardJson': serializer.toJson<String?>(cardJson),
    };
  }

  Card copyWith({
    String? id,
    Value<String?> oracleId = const Value.absent(),
    String? name,
    Value<String?> setCode = const Value.absent(),
    Value<String?> collectorNumber = const Value.absent(),
    Value<String?> rarity = const Value.absent(),
    Value<String?> typeLine = const Value.absent(),
    Value<String?> manaCost = const Value.absent(),
    Value<String?> lang = const Value.absent(),
    Value<String?> releasedAt = const Value.absent(),
    Value<String?> imageUris = const Value.absent(),
    Value<String?> cardFaces = const Value.absent(),
    Value<String?> cardJson = const Value.absent(),
  }) => Card(
    id: id ?? this.id,
    oracleId: oracleId.present ? oracleId.value : this.oracleId,
    name: name ?? this.name,
    setCode: setCode.present ? setCode.value : this.setCode,
    collectorNumber: collectorNumber.present
        ? collectorNumber.value
        : this.collectorNumber,
    rarity: rarity.present ? rarity.value : this.rarity,
    typeLine: typeLine.present ? typeLine.value : this.typeLine,
    manaCost: manaCost.present ? manaCost.value : this.manaCost,
    lang: lang.present ? lang.value : this.lang,
    releasedAt: releasedAt.present ? releasedAt.value : this.releasedAt,
    imageUris: imageUris.present ? imageUris.value : this.imageUris,
    cardFaces: cardFaces.present ? cardFaces.value : this.cardFaces,
    cardJson: cardJson.present ? cardJson.value : this.cardJson,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      oracleId: data.oracleId.present ? data.oracleId.value : this.oracleId,
      name: data.name.present ? data.name.value : this.name,
      setCode: data.setCode.present ? data.setCode.value : this.setCode,
      collectorNumber: data.collectorNumber.present
          ? data.collectorNumber.value
          : this.collectorNumber,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      typeLine: data.typeLine.present ? data.typeLine.value : this.typeLine,
      manaCost: data.manaCost.present ? data.manaCost.value : this.manaCost,
      lang: data.lang.present ? data.lang.value : this.lang,
      releasedAt: data.releasedAt.present
          ? data.releasedAt.value
          : this.releasedAt,
      imageUris: data.imageUris.present ? data.imageUris.value : this.imageUris,
      cardFaces: data.cardFaces.present ? data.cardFaces.value : this.cardFaces,
      cardJson: data.cardJson.present ? data.cardJson.value : this.cardJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('oracleId: $oracleId, ')
          ..write('name: $name, ')
          ..write('setCode: $setCode, ')
          ..write('collectorNumber: $collectorNumber, ')
          ..write('rarity: $rarity, ')
          ..write('typeLine: $typeLine, ')
          ..write('manaCost: $manaCost, ')
          ..write('lang: $lang, ')
          ..write('releasedAt: $releasedAt, ')
          ..write('imageUris: $imageUris, ')
          ..write('cardFaces: $cardFaces, ')
          ..write('cardJson: $cardJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    oracleId,
    name,
    setCode,
    collectorNumber,
    rarity,
    typeLine,
    manaCost,
    lang,
    releasedAt,
    imageUris,
    cardFaces,
    cardJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.oracleId == this.oracleId &&
          other.name == this.name &&
          other.setCode == this.setCode &&
          other.collectorNumber == this.collectorNumber &&
          other.rarity == this.rarity &&
          other.typeLine == this.typeLine &&
          other.manaCost == this.manaCost &&
          other.lang == this.lang &&
          other.releasedAt == this.releasedAt &&
          other.imageUris == this.imageUris &&
          other.cardFaces == this.cardFaces &&
          other.cardJson == this.cardJson);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<String> id;
  final Value<String?> oracleId;
  final Value<String> name;
  final Value<String?> setCode;
  final Value<String?> collectorNumber;
  final Value<String?> rarity;
  final Value<String?> typeLine;
  final Value<String?> manaCost;
  final Value<String?> lang;
  final Value<String?> releasedAt;
  final Value<String?> imageUris;
  final Value<String?> cardFaces;
  final Value<String?> cardJson;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.oracleId = const Value.absent(),
    this.name = const Value.absent(),
    this.setCode = const Value.absent(),
    this.collectorNumber = const Value.absent(),
    this.rarity = const Value.absent(),
    this.typeLine = const Value.absent(),
    this.manaCost = const Value.absent(),
    this.lang = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.imageUris = const Value.absent(),
    this.cardFaces = const Value.absent(),
    this.cardJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    this.oracleId = const Value.absent(),
    required String name,
    this.setCode = const Value.absent(),
    this.collectorNumber = const Value.absent(),
    this.rarity = const Value.absent(),
    this.typeLine = const Value.absent(),
    this.manaCost = const Value.absent(),
    this.lang = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.imageUris = const Value.absent(),
    this.cardFaces = const Value.absent(),
    this.cardJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Card> custom({
    Expression<String>? id,
    Expression<String>? oracleId,
    Expression<String>? name,
    Expression<String>? setCode,
    Expression<String>? collectorNumber,
    Expression<String>? rarity,
    Expression<String>? typeLine,
    Expression<String>? manaCost,
    Expression<String>? lang,
    Expression<String>? releasedAt,
    Expression<String>? imageUris,
    Expression<String>? cardFaces,
    Expression<String>? cardJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (oracleId != null) 'oracle_id': oracleId,
      if (name != null) 'name': name,
      if (setCode != null) 'set_code': setCode,
      if (collectorNumber != null) 'collector_number': collectorNumber,
      if (rarity != null) 'rarity': rarity,
      if (typeLine != null) 'type_line': typeLine,
      if (manaCost != null) 'mana_cost': manaCost,
      if (lang != null) 'lang': lang,
      if (releasedAt != null) 'released_at': releasedAt,
      if (imageUris != null) 'image_uris': imageUris,
      if (cardFaces != null) 'card_faces': cardFaces,
      if (cardJson != null) 'card_json': cardJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? id,
    Value<String?>? oracleId,
    Value<String>? name,
    Value<String?>? setCode,
    Value<String?>? collectorNumber,
    Value<String?>? rarity,
    Value<String?>? typeLine,
    Value<String?>? manaCost,
    Value<String?>? lang,
    Value<String?>? releasedAt,
    Value<String?>? imageUris,
    Value<String?>? cardFaces,
    Value<String?>? cardJson,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      oracleId: oracleId ?? this.oracleId,
      name: name ?? this.name,
      setCode: setCode ?? this.setCode,
      collectorNumber: collectorNumber ?? this.collectorNumber,
      rarity: rarity ?? this.rarity,
      typeLine: typeLine ?? this.typeLine,
      manaCost: manaCost ?? this.manaCost,
      lang: lang ?? this.lang,
      releasedAt: releasedAt ?? this.releasedAt,
      imageUris: imageUris ?? this.imageUris,
      cardFaces: cardFaces ?? this.cardFaces,
      cardJson: cardJson ?? this.cardJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (oracleId.present) {
      map['oracle_id'] = Variable<String>(oracleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (setCode.present) {
      map['set_code'] = Variable<String>(setCode.value);
    }
    if (collectorNumber.present) {
      map['collector_number'] = Variable<String>(collectorNumber.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (typeLine.present) {
      map['type_line'] = Variable<String>(typeLine.value);
    }
    if (manaCost.present) {
      map['mana_cost'] = Variable<String>(manaCost.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (releasedAt.present) {
      map['released_at'] = Variable<String>(releasedAt.value);
    }
    if (imageUris.present) {
      map['image_uris'] = Variable<String>(imageUris.value);
    }
    if (cardFaces.present) {
      map['card_faces'] = Variable<String>(cardFaces.value);
    }
    if (cardJson.present) {
      map['card_json'] = Variable<String>(cardJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('oracleId: $oracleId, ')
          ..write('name: $name, ')
          ..write('setCode: $setCode, ')
          ..write('collectorNumber: $collectorNumber, ')
          ..write('rarity: $rarity, ')
          ..write('typeLine: $typeLine, ')
          ..write('manaCost: $manaCost, ')
          ..write('lang: $lang, ')
          ..write('releasedAt: $releasedAt, ')
          ..write('imageUris: $imageUris, ')
          ..write('cardFaces: $cardFaces, ')
          ..write('cardJson: $cardJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionsTable extends Collections
    with TableInfo<$CollectionsTable, Collection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Collection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Collection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Collection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }
}

class Collection extends DataClass implements Insertable<Collection> {
  final int id;
  final String name;
  const Collection({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(id: Value(id), name: Value(name));
  }

  factory Collection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collection(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Collection copyWith({int? id, String? name}) =>
      Collection(id: id ?? this.id, name: name ?? this.name);
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection && other.id == this.id && other.name == this.name);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<int> id;
  final Value<String> name;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  CollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Collection> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  CollectionsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return CollectionsCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $CollectionCardsTable extends CollectionCards
    with TableInfo<$CollectionCardsTable, CollectionCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _foilMeta = const VerificationMeta('foil');
  @override
  late final GeneratedColumn<bool> foil = GeneratedColumn<bool>(
    'foil',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("foil" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _altArtMeta = const VerificationMeta('altArt');
  @override
  late final GeneratedColumn<bool> altArt = GeneratedColumn<bool>(
    'alt_art',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("alt_art" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionId,
    cardId,
    quantity,
    foil,
    altArt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('foil')) {
      context.handle(
        _foilMeta,
        foil.isAcceptableOrUnknown(data['foil']!, _foilMeta),
      );
    }
    if (data.containsKey('alt_art')) {
      context.handle(
        _altArtMeta,
        altArt.isAcceptableOrUnknown(data['alt_art']!, _altArtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, cardId};
  @override
  CollectionCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionCard(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      foil: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}foil'],
      )!,
      altArt: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}alt_art'],
      )!,
    );
  }

  @override
  $CollectionCardsTable createAlias(String alias) {
    return $CollectionCardsTable(attachedDatabase, alias);
  }
}

class CollectionCard extends DataClass implements Insertable<CollectionCard> {
  final int collectionId;
  final String cardId;
  final int quantity;
  final bool foil;
  final bool altArt;
  const CollectionCard({
    required this.collectionId,
    required this.cardId,
    required this.quantity,
    required this.foil,
    required this.altArt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<int>(collectionId);
    map['card_id'] = Variable<String>(cardId);
    map['quantity'] = Variable<int>(quantity);
    map['foil'] = Variable<bool>(foil);
    map['alt_art'] = Variable<bool>(altArt);
    return map;
  }

  CollectionCardsCompanion toCompanion(bool nullToAbsent) {
    return CollectionCardsCompanion(
      collectionId: Value(collectionId),
      cardId: Value(cardId),
      quantity: Value(quantity),
      foil: Value(foil),
      altArt: Value(altArt),
    );
  }

  factory CollectionCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionCard(
      collectionId: serializer.fromJson<int>(json['collectionId']),
      cardId: serializer.fromJson<String>(json['cardId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      foil: serializer.fromJson<bool>(json['foil']),
      altArt: serializer.fromJson<bool>(json['altArt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<int>(collectionId),
      'cardId': serializer.toJson<String>(cardId),
      'quantity': serializer.toJson<int>(quantity),
      'foil': serializer.toJson<bool>(foil),
      'altArt': serializer.toJson<bool>(altArt),
    };
  }

  CollectionCard copyWith({
    int? collectionId,
    String? cardId,
    int? quantity,
    bool? foil,
    bool? altArt,
  }) => CollectionCard(
    collectionId: collectionId ?? this.collectionId,
    cardId: cardId ?? this.cardId,
    quantity: quantity ?? this.quantity,
    foil: foil ?? this.foil,
    altArt: altArt ?? this.altArt,
  );
  CollectionCard copyWithCompanion(CollectionCardsCompanion data) {
    return CollectionCard(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      foil: data.foil.present ? data.foil.value : this.foil,
      altArt: data.altArt.present ? data.altArt.value : this.altArt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionCard(')
          ..write('collectionId: $collectionId, ')
          ..write('cardId: $cardId, ')
          ..write('quantity: $quantity, ')
          ..write('foil: $foil, ')
          ..write('altArt: $altArt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, cardId, quantity, foil, altArt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionCard &&
          other.collectionId == this.collectionId &&
          other.cardId == this.cardId &&
          other.quantity == this.quantity &&
          other.foil == this.foil &&
          other.altArt == this.altArt);
}

class CollectionCardsCompanion extends UpdateCompanion<CollectionCard> {
  final Value<int> collectionId;
  final Value<String> cardId;
  final Value<int> quantity;
  final Value<bool> foil;
  final Value<bool> altArt;
  final Value<int> rowid;
  const CollectionCardsCompanion({
    this.collectionId = const Value.absent(),
    this.cardId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.foil = const Value.absent(),
    this.altArt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionCardsCompanion.insert({
    required int collectionId,
    required String cardId,
    this.quantity = const Value.absent(),
    this.foil = const Value.absent(),
    this.altArt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       cardId = Value(cardId);
  static Insertable<CollectionCard> custom({
    Expression<int>? collectionId,
    Expression<String>? cardId,
    Expression<int>? quantity,
    Expression<bool>? foil,
    Expression<bool>? altArt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (cardId != null) 'card_id': cardId,
      if (quantity != null) 'quantity': quantity,
      if (foil != null) 'foil': foil,
      if (altArt != null) 'alt_art': altArt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionCardsCompanion copyWith({
    Value<int>? collectionId,
    Value<String>? cardId,
    Value<int>? quantity,
    Value<bool>? foil,
    Value<bool>? altArt,
    Value<int>? rowid,
  }) {
    return CollectionCardsCompanion(
      collectionId: collectionId ?? this.collectionId,
      cardId: cardId ?? this.cardId,
      quantity: quantity ?? this.quantity,
      foil: foil ?? this.foil,
      altArt: altArt ?? this.altArt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (foil.present) {
      map['foil'] = Variable<bool>(foil.value);
    }
    if (altArt.present) {
      map['alt_art'] = Variable<bool>(altArt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionCardsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('cardId: $cardId, ')
          ..write('quantity: $quantity, ')
          ..write('foil: $foil, ')
          ..write('altArt: $altArt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $CollectionCardsTable collectionCards = $CollectionCardsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cards,
    collections,
    collectionCards,
  ];
}

typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      required String id,
      Value<String?> oracleId,
      required String name,
      Value<String?> setCode,
      Value<String?> collectorNumber,
      Value<String?> rarity,
      Value<String?> typeLine,
      Value<String?> manaCost,
      Value<String?> lang,
      Value<String?> releasedAt,
      Value<String?> imageUris,
      Value<String?> cardFaces,
      Value<String?> cardJson,
      Value<int> rowid,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<String> id,
      Value<String?> oracleId,
      Value<String> name,
      Value<String?> setCode,
      Value<String?> collectorNumber,
      Value<String?> rarity,
      Value<String?> typeLine,
      Value<String?> manaCost,
      Value<String?> lang,
      Value<String?> releasedAt,
      Value<String?> imageUris,
      Value<String?> cardFaces,
      Value<String?> cardJson,
      Value<int> rowid,
    });

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oracleId => $composableBuilder(
    column: $table.oracleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setCode => $composableBuilder(
    column: $table.setCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectorNumber => $composableBuilder(
    column: $table.collectorNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeLine => $composableBuilder(
    column: $table.typeLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manaCost => $composableBuilder(
    column: $table.manaCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releasedAt => $composableBuilder(
    column: $table.releasedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUris => $composableBuilder(
    column: $table.imageUris,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardFaces => $composableBuilder(
    column: $table.cardFaces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardJson => $composableBuilder(
    column: $table.cardJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oracleId => $composableBuilder(
    column: $table.oracleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setCode => $composableBuilder(
    column: $table.setCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectorNumber => $composableBuilder(
    column: $table.collectorNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeLine => $composableBuilder(
    column: $table.typeLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manaCost => $composableBuilder(
    column: $table.manaCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releasedAt => $composableBuilder(
    column: $table.releasedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUris => $composableBuilder(
    column: $table.imageUris,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardFaces => $composableBuilder(
    column: $table.cardFaces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardJson => $composableBuilder(
    column: $table.cardJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get oracleId =>
      $composableBuilder(column: $table.oracleId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get setCode =>
      $composableBuilder(column: $table.setCode, builder: (column) => column);

  GeneratedColumn<String> get collectorNumber => $composableBuilder(
    column: $table.collectorNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<String> get typeLine =>
      $composableBuilder(column: $table.typeLine, builder: (column) => column);

  GeneratedColumn<String> get manaCost =>
      $composableBuilder(column: $table.manaCost, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get releasedAt => $composableBuilder(
    column: $table.releasedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUris =>
      $composableBuilder(column: $table.imageUris, builder: (column) => column);

  GeneratedColumn<String> get cardFaces =>
      $composableBuilder(column: $table.cardFaces, builder: (column) => column);

  GeneratedColumn<String> get cardJson =>
      $composableBuilder(column: $table.cardJson, builder: (column) => column);
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          Card,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (Card, BaseReferences<_$AppDatabase, $CardsTable, Card>),
          Card,
          PrefetchHooks Function()
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> oracleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> setCode = const Value.absent(),
                Value<String?> collectorNumber = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<String?> typeLine = const Value.absent(),
                Value<String?> manaCost = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> releasedAt = const Value.absent(),
                Value<String?> imageUris = const Value.absent(),
                Value<String?> cardFaces = const Value.absent(),
                Value<String?> cardJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                oracleId: oracleId,
                name: name,
                setCode: setCode,
                collectorNumber: collectorNumber,
                rarity: rarity,
                typeLine: typeLine,
                manaCost: manaCost,
                lang: lang,
                releasedAt: releasedAt,
                imageUris: imageUris,
                cardFaces: cardFaces,
                cardJson: cardJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> oracleId = const Value.absent(),
                required String name,
                Value<String?> setCode = const Value.absent(),
                Value<String?> collectorNumber = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<String?> typeLine = const Value.absent(),
                Value<String?> manaCost = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> releasedAt = const Value.absent(),
                Value<String?> imageUris = const Value.absent(),
                Value<String?> cardFaces = const Value.absent(),
                Value<String?> cardJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                oracleId: oracleId,
                name: name,
                setCode: setCode,
                collectorNumber: collectorNumber,
                rarity: rarity,
                typeLine: typeLine,
                manaCost: manaCost,
                lang: lang,
                releasedAt: releasedAt,
                imageUris: imageUris,
                cardFaces: cardFaces,
                cardJson: cardJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      Card,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (Card, BaseReferences<_$AppDatabase, $CardsTable, Card>),
      Card,
      PrefetchHooks Function()
    >;
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({Value<int> id, required String name});
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({Value<int> id, Value<String> name});

class $$CollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTable,
          Collection,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (
            Collection,
            BaseReferences<_$AppDatabase, $CollectionsTable, Collection>,
          ),
          Collection,
          PrefetchHooks Function()
        > {
  $$CollectionsTableTableManager(_$AppDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => CollectionsCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  CollectionsCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTable,
      Collection,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (
        Collection,
        BaseReferences<_$AppDatabase, $CollectionsTable, Collection>,
      ),
      Collection,
      PrefetchHooks Function()
    >;
typedef $$CollectionCardsTableCreateCompanionBuilder =
    CollectionCardsCompanion Function({
      required int collectionId,
      required String cardId,
      Value<int> quantity,
      Value<bool> foil,
      Value<bool> altArt,
      Value<int> rowid,
    });
typedef $$CollectionCardsTableUpdateCompanionBuilder =
    CollectionCardsCompanion Function({
      Value<int> collectionId,
      Value<String> cardId,
      Value<int> quantity,
      Value<bool> foil,
      Value<bool> altArt,
      Value<int> rowid,
    });

class $$CollectionCardsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionCardsTable> {
  $$CollectionCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get foil => $composableBuilder(
    column: $table.foil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get altArt => $composableBuilder(
    column: $table.altArt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionCardsTable> {
  $$CollectionCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get foil => $composableBuilder(
    column: $table.foil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get altArt => $composableBuilder(
    column: $table.altArt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionCardsTable> {
  $$CollectionCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<bool> get foil =>
      $composableBuilder(column: $table.foil, builder: (column) => column);

  GeneratedColumn<bool> get altArt =>
      $composableBuilder(column: $table.altArt, builder: (column) => column);
}

class $$CollectionCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionCardsTable,
          CollectionCard,
          $$CollectionCardsTableFilterComposer,
          $$CollectionCardsTableOrderingComposer,
          $$CollectionCardsTableAnnotationComposer,
          $$CollectionCardsTableCreateCompanionBuilder,
          $$CollectionCardsTableUpdateCompanionBuilder,
          (
            CollectionCard,
            BaseReferences<
              _$AppDatabase,
              $CollectionCardsTable,
              CollectionCard
            >,
          ),
          CollectionCard,
          PrefetchHooks Function()
        > {
  $$CollectionCardsTableTableManager(
    _$AppDatabase db,
    $CollectionCardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> collectionId = const Value.absent(),
                Value<String> cardId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<bool> foil = const Value.absent(),
                Value<bool> altArt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionCardsCompanion(
                collectionId: collectionId,
                cardId: cardId,
                quantity: quantity,
                foil: foil,
                altArt: altArt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int collectionId,
                required String cardId,
                Value<int> quantity = const Value.absent(),
                Value<bool> foil = const Value.absent(),
                Value<bool> altArt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionCardsCompanion.insert(
                collectionId: collectionId,
                cardId: cardId,
                quantity: quantity,
                foil: foil,
                altArt: altArt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionCardsTable,
      CollectionCard,
      $$CollectionCardsTableFilterComposer,
      $$CollectionCardsTableOrderingComposer,
      $$CollectionCardsTableAnnotationComposer,
      $$CollectionCardsTableCreateCompanionBuilder,
      $$CollectionCardsTableUpdateCompanionBuilder,
      (
        CollectionCard,
        BaseReferences<_$AppDatabase, $CollectionCardsTable, CollectionCard>,
      ),
      CollectionCard,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db, _db.collections);
  $$CollectionCardsTableTableManager get collectionCards =>
      $$CollectionCardsTableTableManager(_db, _db.collectionCards);
}
