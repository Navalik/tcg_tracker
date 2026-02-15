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
  static const VerificationMeta _setNameMeta = const VerificationMeta(
    'setName',
  );
  @override
  late final GeneratedColumn<String> setName = GeneratedColumn<String>(
    'set_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _setTotalMeta = const VerificationMeta(
    'setTotal',
  );
  @override
  late final GeneratedColumn<int> setTotal = GeneratedColumn<int>(
    'set_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _oracleTextMeta = const VerificationMeta(
    'oracleText',
  );
  @override
  late final GeneratedColumn<String> oracleText = GeneratedColumn<String>(
    'oracle_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cmcMeta = const VerificationMeta('cmc');
  @override
  late final GeneratedColumn<double> cmc = GeneratedColumn<double>(
    'cmc',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorsMeta = const VerificationMeta('colors');
  @override
  late final GeneratedColumn<String> colors = GeneratedColumn<String>(
    'colors',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIdentityMeta = const VerificationMeta(
    'colorIdentity',
  );
  @override
  late final GeneratedColumn<String> colorIdentity = GeneratedColumn<String>(
    'color_identity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _powerMeta = const VerificationMeta('power');
  @override
  late final GeneratedColumn<String> power = GeneratedColumn<String>(
    'power',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toughnessMeta = const VerificationMeta(
    'toughness',
  );
  @override
  late final GeneratedColumn<String> toughness = GeneratedColumn<String>(
    'toughness',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loyaltyMeta = const VerificationMeta(
    'loyalty',
  );
  @override
  late final GeneratedColumn<String> loyalty = GeneratedColumn<String>(
    'loyalty',
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
  static const VerificationMeta _priceUsdMeta = const VerificationMeta(
    'priceUsd',
  );
  @override
  late final GeneratedColumn<String> priceUsd = GeneratedColumn<String>(
    'price_usd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceUsdFoilMeta = const VerificationMeta(
    'priceUsdFoil',
  );
  @override
  late final GeneratedColumn<String> priceUsdFoil = GeneratedColumn<String>(
    'price_usd_foil',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceUsdEtchedMeta = const VerificationMeta(
    'priceUsdEtched',
  );
  @override
  late final GeneratedColumn<String> priceUsdEtched = GeneratedColumn<String>(
    'price_usd_etched',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceEurMeta = const VerificationMeta(
    'priceEur',
  );
  @override
  late final GeneratedColumn<String> priceEur = GeneratedColumn<String>(
    'price_eur',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceEurFoilMeta = const VerificationMeta(
    'priceEurFoil',
  );
  @override
  late final GeneratedColumn<String> priceEurFoil = GeneratedColumn<String>(
    'price_eur_foil',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceTixMeta = const VerificationMeta(
    'priceTix',
  );
  @override
  late final GeneratedColumn<String> priceTix = GeneratedColumn<String>(
    'price_tix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pricesUpdatedAtMeta = const VerificationMeta(
    'pricesUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> pricesUpdatedAt = GeneratedColumn<int>(
    'prices_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    oracleId,
    name,
    setCode,
    setName,
    setTotal,
    collectorNumber,
    rarity,
    typeLine,
    manaCost,
    oracleText,
    cmc,
    colors,
    colorIdentity,
    artist,
    power,
    toughness,
    loyalty,
    lang,
    releasedAt,
    imageUris,
    cardFaces,
    cardJson,
    priceUsd,
    priceUsdFoil,
    priceUsdEtched,
    priceEur,
    priceEurFoil,
    priceTix,
    pricesUpdatedAt,
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
    if (data.containsKey('set_name')) {
      context.handle(
        _setNameMeta,
        setName.isAcceptableOrUnknown(data['set_name']!, _setNameMeta),
      );
    }
    if (data.containsKey('set_total')) {
      context.handle(
        _setTotalMeta,
        setTotal.isAcceptableOrUnknown(data['set_total']!, _setTotalMeta),
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
    if (data.containsKey('oracle_text')) {
      context.handle(
        _oracleTextMeta,
        oracleText.isAcceptableOrUnknown(data['oracle_text']!, _oracleTextMeta),
      );
    }
    if (data.containsKey('cmc')) {
      context.handle(
        _cmcMeta,
        cmc.isAcceptableOrUnknown(data['cmc']!, _cmcMeta),
      );
    }
    if (data.containsKey('colors')) {
      context.handle(
        _colorsMeta,
        colors.isAcceptableOrUnknown(data['colors']!, _colorsMeta),
      );
    }
    if (data.containsKey('color_identity')) {
      context.handle(
        _colorIdentityMeta,
        colorIdentity.isAcceptableOrUnknown(
          data['color_identity']!,
          _colorIdentityMeta,
        ),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('power')) {
      context.handle(
        _powerMeta,
        power.isAcceptableOrUnknown(data['power']!, _powerMeta),
      );
    }
    if (data.containsKey('toughness')) {
      context.handle(
        _toughnessMeta,
        toughness.isAcceptableOrUnknown(data['toughness']!, _toughnessMeta),
      );
    }
    if (data.containsKey('loyalty')) {
      context.handle(
        _loyaltyMeta,
        loyalty.isAcceptableOrUnknown(data['loyalty']!, _loyaltyMeta),
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
    if (data.containsKey('price_usd')) {
      context.handle(
        _priceUsdMeta,
        priceUsd.isAcceptableOrUnknown(data['price_usd']!, _priceUsdMeta),
      );
    }
    if (data.containsKey('price_usd_foil')) {
      context.handle(
        _priceUsdFoilMeta,
        priceUsdFoil.isAcceptableOrUnknown(
          data['price_usd_foil']!,
          _priceUsdFoilMeta,
        ),
      );
    }
    if (data.containsKey('price_usd_etched')) {
      context.handle(
        _priceUsdEtchedMeta,
        priceUsdEtched.isAcceptableOrUnknown(
          data['price_usd_etched']!,
          _priceUsdEtchedMeta,
        ),
      );
    }
    if (data.containsKey('price_eur')) {
      context.handle(
        _priceEurMeta,
        priceEur.isAcceptableOrUnknown(data['price_eur']!, _priceEurMeta),
      );
    }
    if (data.containsKey('price_eur_foil')) {
      context.handle(
        _priceEurFoilMeta,
        priceEurFoil.isAcceptableOrUnknown(
          data['price_eur_foil']!,
          _priceEurFoilMeta,
        ),
      );
    }
    if (data.containsKey('price_tix')) {
      context.handle(
        _priceTixMeta,
        priceTix.isAcceptableOrUnknown(data['price_tix']!, _priceTixMeta),
      );
    }
    if (data.containsKey('prices_updated_at')) {
      context.handle(
        _pricesUpdatedAtMeta,
        pricesUpdatedAt.isAcceptableOrUnknown(
          data['prices_updated_at']!,
          _pricesUpdatedAtMeta,
        ),
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
      setName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_name'],
      ),
      setTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_total'],
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
      oracleText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oracle_text'],
      ),
      cmc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cmc'],
      ),
      colors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colors'],
      ),
      colorIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_identity'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      power: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}power'],
      ),
      toughness: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toughness'],
      ),
      loyalty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loyalty'],
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
      priceUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_usd'],
      ),
      priceUsdFoil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_usd_foil'],
      ),
      priceUsdEtched: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_usd_etched'],
      ),
      priceEur: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_eur'],
      ),
      priceEurFoil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_eur_foil'],
      ),
      priceTix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_tix'],
      ),
      pricesUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prices_updated_at'],
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
  final String? setName;
  final int? setTotal;
  final String? collectorNumber;
  final String? rarity;
  final String? typeLine;
  final String? manaCost;
  final String? oracleText;
  final double? cmc;
  final String? colors;
  final String? colorIdentity;
  final String? artist;
  final String? power;
  final String? toughness;
  final String? loyalty;
  final String? lang;
  final String? releasedAt;
  final String? imageUris;
  final String? cardFaces;
  final String? cardJson;
  final String? priceUsd;
  final String? priceUsdFoil;
  final String? priceUsdEtched;
  final String? priceEur;
  final String? priceEurFoil;
  final String? priceTix;
  final int? pricesUpdatedAt;
  const Card({
    required this.id,
    this.oracleId,
    required this.name,
    this.setCode,
    this.setName,
    this.setTotal,
    this.collectorNumber,
    this.rarity,
    this.typeLine,
    this.manaCost,
    this.oracleText,
    this.cmc,
    this.colors,
    this.colorIdentity,
    this.artist,
    this.power,
    this.toughness,
    this.loyalty,
    this.lang,
    this.releasedAt,
    this.imageUris,
    this.cardFaces,
    this.cardJson,
    this.priceUsd,
    this.priceUsdFoil,
    this.priceUsdEtched,
    this.priceEur,
    this.priceEurFoil,
    this.priceTix,
    this.pricesUpdatedAt,
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
    if (!nullToAbsent || setName != null) {
      map['set_name'] = Variable<String>(setName);
    }
    if (!nullToAbsent || setTotal != null) {
      map['set_total'] = Variable<int>(setTotal);
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
    if (!nullToAbsent || oracleText != null) {
      map['oracle_text'] = Variable<String>(oracleText);
    }
    if (!nullToAbsent || cmc != null) {
      map['cmc'] = Variable<double>(cmc);
    }
    if (!nullToAbsent || colors != null) {
      map['colors'] = Variable<String>(colors);
    }
    if (!nullToAbsent || colorIdentity != null) {
      map['color_identity'] = Variable<String>(colorIdentity);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || power != null) {
      map['power'] = Variable<String>(power);
    }
    if (!nullToAbsent || toughness != null) {
      map['toughness'] = Variable<String>(toughness);
    }
    if (!nullToAbsent || loyalty != null) {
      map['loyalty'] = Variable<String>(loyalty);
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
    if (!nullToAbsent || priceUsd != null) {
      map['price_usd'] = Variable<String>(priceUsd);
    }
    if (!nullToAbsent || priceUsdFoil != null) {
      map['price_usd_foil'] = Variable<String>(priceUsdFoil);
    }
    if (!nullToAbsent || priceUsdEtched != null) {
      map['price_usd_etched'] = Variable<String>(priceUsdEtched);
    }
    if (!nullToAbsent || priceEur != null) {
      map['price_eur'] = Variable<String>(priceEur);
    }
    if (!nullToAbsent || priceEurFoil != null) {
      map['price_eur_foil'] = Variable<String>(priceEurFoil);
    }
    if (!nullToAbsent || priceTix != null) {
      map['price_tix'] = Variable<String>(priceTix);
    }
    if (!nullToAbsent || pricesUpdatedAt != null) {
      map['prices_updated_at'] = Variable<int>(pricesUpdatedAt);
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
      setName: setName == null && nullToAbsent
          ? const Value.absent()
          : Value(setName),
      setTotal: setTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(setTotal),
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
      oracleText: oracleText == null && nullToAbsent
          ? const Value.absent()
          : Value(oracleText),
      cmc: cmc == null && nullToAbsent ? const Value.absent() : Value(cmc),
      colors: colors == null && nullToAbsent
          ? const Value.absent()
          : Value(colors),
      colorIdentity: colorIdentity == null && nullToAbsent
          ? const Value.absent()
          : Value(colorIdentity),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      power: power == null && nullToAbsent
          ? const Value.absent()
          : Value(power),
      toughness: toughness == null && nullToAbsent
          ? const Value.absent()
          : Value(toughness),
      loyalty: loyalty == null && nullToAbsent
          ? const Value.absent()
          : Value(loyalty),
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
      priceUsd: priceUsd == null && nullToAbsent
          ? const Value.absent()
          : Value(priceUsd),
      priceUsdFoil: priceUsdFoil == null && nullToAbsent
          ? const Value.absent()
          : Value(priceUsdFoil),
      priceUsdEtched: priceUsdEtched == null && nullToAbsent
          ? const Value.absent()
          : Value(priceUsdEtched),
      priceEur: priceEur == null && nullToAbsent
          ? const Value.absent()
          : Value(priceEur),
      priceEurFoil: priceEurFoil == null && nullToAbsent
          ? const Value.absent()
          : Value(priceEurFoil),
      priceTix: priceTix == null && nullToAbsent
          ? const Value.absent()
          : Value(priceTix),
      pricesUpdatedAt: pricesUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pricesUpdatedAt),
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
      setName: serializer.fromJson<String?>(json['setName']),
      setTotal: serializer.fromJson<int?>(json['setTotal']),
      collectorNumber: serializer.fromJson<String?>(json['collectorNumber']),
      rarity: serializer.fromJson<String?>(json['rarity']),
      typeLine: serializer.fromJson<String?>(json['typeLine']),
      manaCost: serializer.fromJson<String?>(json['manaCost']),
      oracleText: serializer.fromJson<String?>(json['oracleText']),
      cmc: serializer.fromJson<double?>(json['cmc']),
      colors: serializer.fromJson<String?>(json['colors']),
      colorIdentity: serializer.fromJson<String?>(json['colorIdentity']),
      artist: serializer.fromJson<String?>(json['artist']),
      power: serializer.fromJson<String?>(json['power']),
      toughness: serializer.fromJson<String?>(json['toughness']),
      loyalty: serializer.fromJson<String?>(json['loyalty']),
      lang: serializer.fromJson<String?>(json['lang']),
      releasedAt: serializer.fromJson<String?>(json['releasedAt']),
      imageUris: serializer.fromJson<String?>(json['imageUris']),
      cardFaces: serializer.fromJson<String?>(json['cardFaces']),
      cardJson: serializer.fromJson<String?>(json['cardJson']),
      priceUsd: serializer.fromJson<String?>(json['priceUsd']),
      priceUsdFoil: serializer.fromJson<String?>(json['priceUsdFoil']),
      priceUsdEtched: serializer.fromJson<String?>(json['priceUsdEtched']),
      priceEur: serializer.fromJson<String?>(json['priceEur']),
      priceEurFoil: serializer.fromJson<String?>(json['priceEurFoil']),
      priceTix: serializer.fromJson<String?>(json['priceTix']),
      pricesUpdatedAt: serializer.fromJson<int?>(json['pricesUpdatedAt']),
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
      'setName': serializer.toJson<String?>(setName),
      'setTotal': serializer.toJson<int?>(setTotal),
      'collectorNumber': serializer.toJson<String?>(collectorNumber),
      'rarity': serializer.toJson<String?>(rarity),
      'typeLine': serializer.toJson<String?>(typeLine),
      'manaCost': serializer.toJson<String?>(manaCost),
      'oracleText': serializer.toJson<String?>(oracleText),
      'cmc': serializer.toJson<double?>(cmc),
      'colors': serializer.toJson<String?>(colors),
      'colorIdentity': serializer.toJson<String?>(colorIdentity),
      'artist': serializer.toJson<String?>(artist),
      'power': serializer.toJson<String?>(power),
      'toughness': serializer.toJson<String?>(toughness),
      'loyalty': serializer.toJson<String?>(loyalty),
      'lang': serializer.toJson<String?>(lang),
      'releasedAt': serializer.toJson<String?>(releasedAt),
      'imageUris': serializer.toJson<String?>(imageUris),
      'cardFaces': serializer.toJson<String?>(cardFaces),
      'cardJson': serializer.toJson<String?>(cardJson),
      'priceUsd': serializer.toJson<String?>(priceUsd),
      'priceUsdFoil': serializer.toJson<String?>(priceUsdFoil),
      'priceUsdEtched': serializer.toJson<String?>(priceUsdEtched),
      'priceEur': serializer.toJson<String?>(priceEur),
      'priceEurFoil': serializer.toJson<String?>(priceEurFoil),
      'priceTix': serializer.toJson<String?>(priceTix),
      'pricesUpdatedAt': serializer.toJson<int?>(pricesUpdatedAt),
    };
  }

  Card copyWith({
    String? id,
    Value<String?> oracleId = const Value.absent(),
    String? name,
    Value<String?> setCode = const Value.absent(),
    Value<String?> setName = const Value.absent(),
    Value<int?> setTotal = const Value.absent(),
    Value<String?> collectorNumber = const Value.absent(),
    Value<String?> rarity = const Value.absent(),
    Value<String?> typeLine = const Value.absent(),
    Value<String?> manaCost = const Value.absent(),
    Value<String?> oracleText = const Value.absent(),
    Value<double?> cmc = const Value.absent(),
    Value<String?> colors = const Value.absent(),
    Value<String?> colorIdentity = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    Value<String?> power = const Value.absent(),
    Value<String?> toughness = const Value.absent(),
    Value<String?> loyalty = const Value.absent(),
    Value<String?> lang = const Value.absent(),
    Value<String?> releasedAt = const Value.absent(),
    Value<String?> imageUris = const Value.absent(),
    Value<String?> cardFaces = const Value.absent(),
    Value<String?> cardJson = const Value.absent(),
    Value<String?> priceUsd = const Value.absent(),
    Value<String?> priceUsdFoil = const Value.absent(),
    Value<String?> priceUsdEtched = const Value.absent(),
    Value<String?> priceEur = const Value.absent(),
    Value<String?> priceEurFoil = const Value.absent(),
    Value<String?> priceTix = const Value.absent(),
    Value<int?> pricesUpdatedAt = const Value.absent(),
  }) => Card(
    id: id ?? this.id,
    oracleId: oracleId.present ? oracleId.value : this.oracleId,
    name: name ?? this.name,
    setCode: setCode.present ? setCode.value : this.setCode,
    setName: setName.present ? setName.value : this.setName,
    setTotal: setTotal.present ? setTotal.value : this.setTotal,
    collectorNumber: collectorNumber.present
        ? collectorNumber.value
        : this.collectorNumber,
    rarity: rarity.present ? rarity.value : this.rarity,
    typeLine: typeLine.present ? typeLine.value : this.typeLine,
    manaCost: manaCost.present ? manaCost.value : this.manaCost,
    oracleText: oracleText.present ? oracleText.value : this.oracleText,
    cmc: cmc.present ? cmc.value : this.cmc,
    colors: colors.present ? colors.value : this.colors,
    colorIdentity: colorIdentity.present
        ? colorIdentity.value
        : this.colorIdentity,
    artist: artist.present ? artist.value : this.artist,
    power: power.present ? power.value : this.power,
    toughness: toughness.present ? toughness.value : this.toughness,
    loyalty: loyalty.present ? loyalty.value : this.loyalty,
    lang: lang.present ? lang.value : this.lang,
    releasedAt: releasedAt.present ? releasedAt.value : this.releasedAt,
    imageUris: imageUris.present ? imageUris.value : this.imageUris,
    cardFaces: cardFaces.present ? cardFaces.value : this.cardFaces,
    cardJson: cardJson.present ? cardJson.value : this.cardJson,
    priceUsd: priceUsd.present ? priceUsd.value : this.priceUsd,
    priceUsdFoil: priceUsdFoil.present ? priceUsdFoil.value : this.priceUsdFoil,
    priceUsdEtched: priceUsdEtched.present
        ? priceUsdEtched.value
        : this.priceUsdEtched,
    priceEur: priceEur.present ? priceEur.value : this.priceEur,
    priceEurFoil: priceEurFoil.present ? priceEurFoil.value : this.priceEurFoil,
    priceTix: priceTix.present ? priceTix.value : this.priceTix,
    pricesUpdatedAt: pricesUpdatedAt.present
        ? pricesUpdatedAt.value
        : this.pricesUpdatedAt,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      oracleId: data.oracleId.present ? data.oracleId.value : this.oracleId,
      name: data.name.present ? data.name.value : this.name,
      setCode: data.setCode.present ? data.setCode.value : this.setCode,
      setName: data.setName.present ? data.setName.value : this.setName,
      setTotal: data.setTotal.present ? data.setTotal.value : this.setTotal,
      collectorNumber: data.collectorNumber.present
          ? data.collectorNumber.value
          : this.collectorNumber,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      typeLine: data.typeLine.present ? data.typeLine.value : this.typeLine,
      manaCost: data.manaCost.present ? data.manaCost.value : this.manaCost,
      oracleText: data.oracleText.present
          ? data.oracleText.value
          : this.oracleText,
      cmc: data.cmc.present ? data.cmc.value : this.cmc,
      colors: data.colors.present ? data.colors.value : this.colors,
      colorIdentity: data.colorIdentity.present
          ? data.colorIdentity.value
          : this.colorIdentity,
      artist: data.artist.present ? data.artist.value : this.artist,
      power: data.power.present ? data.power.value : this.power,
      toughness: data.toughness.present ? data.toughness.value : this.toughness,
      loyalty: data.loyalty.present ? data.loyalty.value : this.loyalty,
      lang: data.lang.present ? data.lang.value : this.lang,
      releasedAt: data.releasedAt.present
          ? data.releasedAt.value
          : this.releasedAt,
      imageUris: data.imageUris.present ? data.imageUris.value : this.imageUris,
      cardFaces: data.cardFaces.present ? data.cardFaces.value : this.cardFaces,
      cardJson: data.cardJson.present ? data.cardJson.value : this.cardJson,
      priceUsd: data.priceUsd.present ? data.priceUsd.value : this.priceUsd,
      priceUsdFoil: data.priceUsdFoil.present
          ? data.priceUsdFoil.value
          : this.priceUsdFoil,
      priceUsdEtched: data.priceUsdEtched.present
          ? data.priceUsdEtched.value
          : this.priceUsdEtched,
      priceEur: data.priceEur.present ? data.priceEur.value : this.priceEur,
      priceEurFoil: data.priceEurFoil.present
          ? data.priceEurFoil.value
          : this.priceEurFoil,
      priceTix: data.priceTix.present ? data.priceTix.value : this.priceTix,
      pricesUpdatedAt: data.pricesUpdatedAt.present
          ? data.pricesUpdatedAt.value
          : this.pricesUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('oracleId: $oracleId, ')
          ..write('name: $name, ')
          ..write('setCode: $setCode, ')
          ..write('setName: $setName, ')
          ..write('setTotal: $setTotal, ')
          ..write('collectorNumber: $collectorNumber, ')
          ..write('rarity: $rarity, ')
          ..write('typeLine: $typeLine, ')
          ..write('manaCost: $manaCost, ')
          ..write('oracleText: $oracleText, ')
          ..write('cmc: $cmc, ')
          ..write('colors: $colors, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('artist: $artist, ')
          ..write('power: $power, ')
          ..write('toughness: $toughness, ')
          ..write('loyalty: $loyalty, ')
          ..write('lang: $lang, ')
          ..write('releasedAt: $releasedAt, ')
          ..write('imageUris: $imageUris, ')
          ..write('cardFaces: $cardFaces, ')
          ..write('cardJson: $cardJson, ')
          ..write('priceUsd: $priceUsd, ')
          ..write('priceUsdFoil: $priceUsdFoil, ')
          ..write('priceUsdEtched: $priceUsdEtched, ')
          ..write('priceEur: $priceEur, ')
          ..write('priceEurFoil: $priceEurFoil, ')
          ..write('priceTix: $priceTix, ')
          ..write('pricesUpdatedAt: $pricesUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    oracleId,
    name,
    setCode,
    setName,
    setTotal,
    collectorNumber,
    rarity,
    typeLine,
    manaCost,
    oracleText,
    cmc,
    colors,
    colorIdentity,
    artist,
    power,
    toughness,
    loyalty,
    lang,
    releasedAt,
    imageUris,
    cardFaces,
    cardJson,
    priceUsd,
    priceUsdFoil,
    priceUsdEtched,
    priceEur,
    priceEurFoil,
    priceTix,
    pricesUpdatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.oracleId == this.oracleId &&
          other.name == this.name &&
          other.setCode == this.setCode &&
          other.setName == this.setName &&
          other.setTotal == this.setTotal &&
          other.collectorNumber == this.collectorNumber &&
          other.rarity == this.rarity &&
          other.typeLine == this.typeLine &&
          other.manaCost == this.manaCost &&
          other.oracleText == this.oracleText &&
          other.cmc == this.cmc &&
          other.colors == this.colors &&
          other.colorIdentity == this.colorIdentity &&
          other.artist == this.artist &&
          other.power == this.power &&
          other.toughness == this.toughness &&
          other.loyalty == this.loyalty &&
          other.lang == this.lang &&
          other.releasedAt == this.releasedAt &&
          other.imageUris == this.imageUris &&
          other.cardFaces == this.cardFaces &&
          other.cardJson == this.cardJson &&
          other.priceUsd == this.priceUsd &&
          other.priceUsdFoil == this.priceUsdFoil &&
          other.priceUsdEtched == this.priceUsdEtched &&
          other.priceEur == this.priceEur &&
          other.priceEurFoil == this.priceEurFoil &&
          other.priceTix == this.priceTix &&
          other.pricesUpdatedAt == this.pricesUpdatedAt);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<String> id;
  final Value<String?> oracleId;
  final Value<String> name;
  final Value<String?> setCode;
  final Value<String?> setName;
  final Value<int?> setTotal;
  final Value<String?> collectorNumber;
  final Value<String?> rarity;
  final Value<String?> typeLine;
  final Value<String?> manaCost;
  final Value<String?> oracleText;
  final Value<double?> cmc;
  final Value<String?> colors;
  final Value<String?> colorIdentity;
  final Value<String?> artist;
  final Value<String?> power;
  final Value<String?> toughness;
  final Value<String?> loyalty;
  final Value<String?> lang;
  final Value<String?> releasedAt;
  final Value<String?> imageUris;
  final Value<String?> cardFaces;
  final Value<String?> cardJson;
  final Value<String?> priceUsd;
  final Value<String?> priceUsdFoil;
  final Value<String?> priceUsdEtched;
  final Value<String?> priceEur;
  final Value<String?> priceEurFoil;
  final Value<String?> priceTix;
  final Value<int?> pricesUpdatedAt;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.oracleId = const Value.absent(),
    this.name = const Value.absent(),
    this.setCode = const Value.absent(),
    this.setName = const Value.absent(),
    this.setTotal = const Value.absent(),
    this.collectorNumber = const Value.absent(),
    this.rarity = const Value.absent(),
    this.typeLine = const Value.absent(),
    this.manaCost = const Value.absent(),
    this.oracleText = const Value.absent(),
    this.cmc = const Value.absent(),
    this.colors = const Value.absent(),
    this.colorIdentity = const Value.absent(),
    this.artist = const Value.absent(),
    this.power = const Value.absent(),
    this.toughness = const Value.absent(),
    this.loyalty = const Value.absent(),
    this.lang = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.imageUris = const Value.absent(),
    this.cardFaces = const Value.absent(),
    this.cardJson = const Value.absent(),
    this.priceUsd = const Value.absent(),
    this.priceUsdFoil = const Value.absent(),
    this.priceUsdEtched = const Value.absent(),
    this.priceEur = const Value.absent(),
    this.priceEurFoil = const Value.absent(),
    this.priceTix = const Value.absent(),
    this.pricesUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    this.oracleId = const Value.absent(),
    required String name,
    this.setCode = const Value.absent(),
    this.setName = const Value.absent(),
    this.setTotal = const Value.absent(),
    this.collectorNumber = const Value.absent(),
    this.rarity = const Value.absent(),
    this.typeLine = const Value.absent(),
    this.manaCost = const Value.absent(),
    this.oracleText = const Value.absent(),
    this.cmc = const Value.absent(),
    this.colors = const Value.absent(),
    this.colorIdentity = const Value.absent(),
    this.artist = const Value.absent(),
    this.power = const Value.absent(),
    this.toughness = const Value.absent(),
    this.loyalty = const Value.absent(),
    this.lang = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.imageUris = const Value.absent(),
    this.cardFaces = const Value.absent(),
    this.cardJson = const Value.absent(),
    this.priceUsd = const Value.absent(),
    this.priceUsdFoil = const Value.absent(),
    this.priceUsdEtched = const Value.absent(),
    this.priceEur = const Value.absent(),
    this.priceEurFoil = const Value.absent(),
    this.priceTix = const Value.absent(),
    this.pricesUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Card> custom({
    Expression<String>? id,
    Expression<String>? oracleId,
    Expression<String>? name,
    Expression<String>? setCode,
    Expression<String>? setName,
    Expression<int>? setTotal,
    Expression<String>? collectorNumber,
    Expression<String>? rarity,
    Expression<String>? typeLine,
    Expression<String>? manaCost,
    Expression<String>? oracleText,
    Expression<double>? cmc,
    Expression<String>? colors,
    Expression<String>? colorIdentity,
    Expression<String>? artist,
    Expression<String>? power,
    Expression<String>? toughness,
    Expression<String>? loyalty,
    Expression<String>? lang,
    Expression<String>? releasedAt,
    Expression<String>? imageUris,
    Expression<String>? cardFaces,
    Expression<String>? cardJson,
    Expression<String>? priceUsd,
    Expression<String>? priceUsdFoil,
    Expression<String>? priceUsdEtched,
    Expression<String>? priceEur,
    Expression<String>? priceEurFoil,
    Expression<String>? priceTix,
    Expression<int>? pricesUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (oracleId != null) 'oracle_id': oracleId,
      if (name != null) 'name': name,
      if (setCode != null) 'set_code': setCode,
      if (setName != null) 'set_name': setName,
      if (setTotal != null) 'set_total': setTotal,
      if (collectorNumber != null) 'collector_number': collectorNumber,
      if (rarity != null) 'rarity': rarity,
      if (typeLine != null) 'type_line': typeLine,
      if (manaCost != null) 'mana_cost': manaCost,
      if (oracleText != null) 'oracle_text': oracleText,
      if (cmc != null) 'cmc': cmc,
      if (colors != null) 'colors': colors,
      if (colorIdentity != null) 'color_identity': colorIdentity,
      if (artist != null) 'artist': artist,
      if (power != null) 'power': power,
      if (toughness != null) 'toughness': toughness,
      if (loyalty != null) 'loyalty': loyalty,
      if (lang != null) 'lang': lang,
      if (releasedAt != null) 'released_at': releasedAt,
      if (imageUris != null) 'image_uris': imageUris,
      if (cardFaces != null) 'card_faces': cardFaces,
      if (cardJson != null) 'card_json': cardJson,
      if (priceUsd != null) 'price_usd': priceUsd,
      if (priceUsdFoil != null) 'price_usd_foil': priceUsdFoil,
      if (priceUsdEtched != null) 'price_usd_etched': priceUsdEtched,
      if (priceEur != null) 'price_eur': priceEur,
      if (priceEurFoil != null) 'price_eur_foil': priceEurFoil,
      if (priceTix != null) 'price_tix': priceTix,
      if (pricesUpdatedAt != null) 'prices_updated_at': pricesUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? id,
    Value<String?>? oracleId,
    Value<String>? name,
    Value<String?>? setCode,
    Value<String?>? setName,
    Value<int?>? setTotal,
    Value<String?>? collectorNumber,
    Value<String?>? rarity,
    Value<String?>? typeLine,
    Value<String?>? manaCost,
    Value<String?>? oracleText,
    Value<double?>? cmc,
    Value<String?>? colors,
    Value<String?>? colorIdentity,
    Value<String?>? artist,
    Value<String?>? power,
    Value<String?>? toughness,
    Value<String?>? loyalty,
    Value<String?>? lang,
    Value<String?>? releasedAt,
    Value<String?>? imageUris,
    Value<String?>? cardFaces,
    Value<String?>? cardJson,
    Value<String?>? priceUsd,
    Value<String?>? priceUsdFoil,
    Value<String?>? priceUsdEtched,
    Value<String?>? priceEur,
    Value<String?>? priceEurFoil,
    Value<String?>? priceTix,
    Value<int?>? pricesUpdatedAt,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      oracleId: oracleId ?? this.oracleId,
      name: name ?? this.name,
      setCode: setCode ?? this.setCode,
      setName: setName ?? this.setName,
      setTotal: setTotal ?? this.setTotal,
      collectorNumber: collectorNumber ?? this.collectorNumber,
      rarity: rarity ?? this.rarity,
      typeLine: typeLine ?? this.typeLine,
      manaCost: manaCost ?? this.manaCost,
      oracleText: oracleText ?? this.oracleText,
      cmc: cmc ?? this.cmc,
      colors: colors ?? this.colors,
      colorIdentity: colorIdentity ?? this.colorIdentity,
      artist: artist ?? this.artist,
      power: power ?? this.power,
      toughness: toughness ?? this.toughness,
      loyalty: loyalty ?? this.loyalty,
      lang: lang ?? this.lang,
      releasedAt: releasedAt ?? this.releasedAt,
      imageUris: imageUris ?? this.imageUris,
      cardFaces: cardFaces ?? this.cardFaces,
      cardJson: cardJson ?? this.cardJson,
      priceUsd: priceUsd ?? this.priceUsd,
      priceUsdFoil: priceUsdFoil ?? this.priceUsdFoil,
      priceUsdEtched: priceUsdEtched ?? this.priceUsdEtched,
      priceEur: priceEur ?? this.priceEur,
      priceEurFoil: priceEurFoil ?? this.priceEurFoil,
      priceTix: priceTix ?? this.priceTix,
      pricesUpdatedAt: pricesUpdatedAt ?? this.pricesUpdatedAt,
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
    if (setName.present) {
      map['set_name'] = Variable<String>(setName.value);
    }
    if (setTotal.present) {
      map['set_total'] = Variable<int>(setTotal.value);
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
    if (oracleText.present) {
      map['oracle_text'] = Variable<String>(oracleText.value);
    }
    if (cmc.present) {
      map['cmc'] = Variable<double>(cmc.value);
    }
    if (colors.present) {
      map['colors'] = Variable<String>(colors.value);
    }
    if (colorIdentity.present) {
      map['color_identity'] = Variable<String>(colorIdentity.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (power.present) {
      map['power'] = Variable<String>(power.value);
    }
    if (toughness.present) {
      map['toughness'] = Variable<String>(toughness.value);
    }
    if (loyalty.present) {
      map['loyalty'] = Variable<String>(loyalty.value);
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
    if (priceUsd.present) {
      map['price_usd'] = Variable<String>(priceUsd.value);
    }
    if (priceUsdFoil.present) {
      map['price_usd_foil'] = Variable<String>(priceUsdFoil.value);
    }
    if (priceUsdEtched.present) {
      map['price_usd_etched'] = Variable<String>(priceUsdEtched.value);
    }
    if (priceEur.present) {
      map['price_eur'] = Variable<String>(priceEur.value);
    }
    if (priceEurFoil.present) {
      map['price_eur_foil'] = Variable<String>(priceEurFoil.value);
    }
    if (priceTix.present) {
      map['price_tix'] = Variable<String>(priceTix.value);
    }
    if (pricesUpdatedAt.present) {
      map['prices_updated_at'] = Variable<int>(pricesUpdatedAt.value);
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
          ..write('setName: $setName, ')
          ..write('setTotal: $setTotal, ')
          ..write('collectorNumber: $collectorNumber, ')
          ..write('rarity: $rarity, ')
          ..write('typeLine: $typeLine, ')
          ..write('manaCost: $manaCost, ')
          ..write('oracleText: $oracleText, ')
          ..write('cmc: $cmc, ')
          ..write('colors: $colors, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('artist: $artist, ')
          ..write('power: $power, ')
          ..write('toughness: $toughness, ')
          ..write('loyalty: $loyalty, ')
          ..write('lang: $lang, ')
          ..write('releasedAt: $releasedAt, ')
          ..write('imageUris: $imageUris, ')
          ..write('cardFaces: $cardFaces, ')
          ..write('cardJson: $cardJson, ')
          ..write('priceUsd: $priceUsd, ')
          ..write('priceUsdFoil: $priceUsdFoil, ')
          ..write('priceUsdEtched: $priceUsdEtched, ')
          ..write('priceEur: $priceEur, ')
          ..write('priceEurFoil: $priceEurFoil, ')
          ..write('priceTix: $priceTix, ')
          ..write('pricesUpdatedAt: $pricesUpdatedAt, ')
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('custom'),
  );
  static const VerificationMeta _filterJsonMeta = const VerificationMeta(
    'filterJson',
  );
  @override
  late final GeneratedColumn<String> filterJson = GeneratedColumn<String>(
    'filter_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, type, filterJson];
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
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('filter_json')) {
      context.handle(
        _filterJsonMeta,
        filterJson.isAcceptableOrUnknown(data['filter_json']!, _filterJsonMeta),
      );
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
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      filterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_json'],
      ),
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
  final String type;
  final String? filterJson;
  const Collection({
    required this.id,
    required this.name,
    required this.type,
    this.filterJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || filterJson != null) {
      map['filter_json'] = Variable<String>(filterJson);
    }
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      filterJson: filterJson == null && nullToAbsent
          ? const Value.absent()
          : Value(filterJson),
    );
  }

  factory Collection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collection(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      filterJson: serializer.fromJson<String?>(json['filterJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'filterJson': serializer.toJson<String?>(filterJson),
    };
  }

  Collection copyWith({
    int? id,
    String? name,
    String? type,
    Value<String?> filterJson = const Value.absent(),
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    filterJson: filterJson.present ? filterJson.value : this.filterJson,
  );
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      filterJson: data.filterJson.present
          ? data.filterJson.value
          : this.filterJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('filterJson: $filterJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, filterJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.filterJson == this.filterJson);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> filterJson;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.filterJson = const Value.absent(),
  });
  CollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.type = const Value.absent(),
    this.filterJson = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Collection> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? filterJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (filterJson != null) 'filter_json': filterJson,
    });
  }

  CollectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? filterJson,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      filterJson: filterJson ?? this.filterJson,
    );
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (filterJson.present) {
      map['filter_json'] = Variable<String>(filterJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('filterJson: $filterJson')
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
      Value<String?> setName,
      Value<int?> setTotal,
      Value<String?> collectorNumber,
      Value<String?> rarity,
      Value<String?> typeLine,
      Value<String?> manaCost,
      Value<String?> oracleText,
      Value<double?> cmc,
      Value<String?> colors,
      Value<String?> colorIdentity,
      Value<String?> artist,
      Value<String?> power,
      Value<String?> toughness,
      Value<String?> loyalty,
      Value<String?> lang,
      Value<String?> releasedAt,
      Value<String?> imageUris,
      Value<String?> cardFaces,
      Value<String?> cardJson,
      Value<String?> priceUsd,
      Value<String?> priceUsdFoil,
      Value<String?> priceUsdEtched,
      Value<String?> priceEur,
      Value<String?> priceEurFoil,
      Value<String?> priceTix,
      Value<int?> pricesUpdatedAt,
      Value<int> rowid,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<String> id,
      Value<String?> oracleId,
      Value<String> name,
      Value<String?> setCode,
      Value<String?> setName,
      Value<int?> setTotal,
      Value<String?> collectorNumber,
      Value<String?> rarity,
      Value<String?> typeLine,
      Value<String?> manaCost,
      Value<String?> oracleText,
      Value<double?> cmc,
      Value<String?> colors,
      Value<String?> colorIdentity,
      Value<String?> artist,
      Value<String?> power,
      Value<String?> toughness,
      Value<String?> loyalty,
      Value<String?> lang,
      Value<String?> releasedAt,
      Value<String?> imageUris,
      Value<String?> cardFaces,
      Value<String?> cardJson,
      Value<String?> priceUsd,
      Value<String?> priceUsdFoil,
      Value<String?> priceUsdEtched,
      Value<String?> priceEur,
      Value<String?> priceEurFoil,
      Value<String?> priceTix,
      Value<int?> pricesUpdatedAt,
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

  ColumnFilters<String> get setName => $composableBuilder(
    column: $table.setName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setTotal => $composableBuilder(
    column: $table.setTotal,
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

  ColumnFilters<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cmc => $composableBuilder(
    column: $table.cmc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colors => $composableBuilder(
    column: $table.colors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toughness => $composableBuilder(
    column: $table.toughness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loyalty => $composableBuilder(
    column: $table.loyalty,
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

  ColumnFilters<String> get priceUsd => $composableBuilder(
    column: $table.priceUsd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceUsdFoil => $composableBuilder(
    column: $table.priceUsdFoil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceUsdEtched => $composableBuilder(
    column: $table.priceUsdEtched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceEur => $composableBuilder(
    column: $table.priceEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceEurFoil => $composableBuilder(
    column: $table.priceEurFoil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceTix => $composableBuilder(
    column: $table.priceTix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pricesUpdatedAt => $composableBuilder(
    column: $table.pricesUpdatedAt,
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

  ColumnOrderings<String> get setName => $composableBuilder(
    column: $table.setName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setTotal => $composableBuilder(
    column: $table.setTotal,
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

  ColumnOrderings<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cmc => $composableBuilder(
    column: $table.cmc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colors => $composableBuilder(
    column: $table.colors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toughness => $composableBuilder(
    column: $table.toughness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loyalty => $composableBuilder(
    column: $table.loyalty,
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

  ColumnOrderings<String> get priceUsd => $composableBuilder(
    column: $table.priceUsd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceUsdFoil => $composableBuilder(
    column: $table.priceUsdFoil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceUsdEtched => $composableBuilder(
    column: $table.priceUsdEtched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceEur => $composableBuilder(
    column: $table.priceEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceEurFoil => $composableBuilder(
    column: $table.priceEurFoil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceTix => $composableBuilder(
    column: $table.priceTix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pricesUpdatedAt => $composableBuilder(
    column: $table.pricesUpdatedAt,
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

  GeneratedColumn<String> get setName =>
      $composableBuilder(column: $table.setName, builder: (column) => column);

  GeneratedColumn<int> get setTotal =>
      $composableBuilder(column: $table.setTotal, builder: (column) => column);

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

  GeneratedColumn<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cmc =>
      $composableBuilder(column: $table.cmc, builder: (column) => column);

  GeneratedColumn<String> get colors =>
      $composableBuilder(column: $table.colors, builder: (column) => column);

  GeneratedColumn<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get power =>
      $composableBuilder(column: $table.power, builder: (column) => column);

  GeneratedColumn<String> get toughness =>
      $composableBuilder(column: $table.toughness, builder: (column) => column);

  GeneratedColumn<String> get loyalty =>
      $composableBuilder(column: $table.loyalty, builder: (column) => column);

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

  GeneratedColumn<String> get priceUsd =>
      $composableBuilder(column: $table.priceUsd, builder: (column) => column);

  GeneratedColumn<String> get priceUsdFoil => $composableBuilder(
    column: $table.priceUsdFoil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priceUsdEtched => $composableBuilder(
    column: $table.priceUsdEtched,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priceEur =>
      $composableBuilder(column: $table.priceEur, builder: (column) => column);

  GeneratedColumn<String> get priceEurFoil => $composableBuilder(
    column: $table.priceEurFoil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priceTix =>
      $composableBuilder(column: $table.priceTix, builder: (column) => column);

  GeneratedColumn<int> get pricesUpdatedAt => $composableBuilder(
    column: $table.pricesUpdatedAt,
    builder: (column) => column,
  );
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
                Value<String?> setName = const Value.absent(),
                Value<int?> setTotal = const Value.absent(),
                Value<String?> collectorNumber = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<String?> typeLine = const Value.absent(),
                Value<String?> manaCost = const Value.absent(),
                Value<String?> oracleText = const Value.absent(),
                Value<double?> cmc = const Value.absent(),
                Value<String?> colors = const Value.absent(),
                Value<String?> colorIdentity = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> power = const Value.absent(),
                Value<String?> toughness = const Value.absent(),
                Value<String?> loyalty = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> releasedAt = const Value.absent(),
                Value<String?> imageUris = const Value.absent(),
                Value<String?> cardFaces = const Value.absent(),
                Value<String?> cardJson = const Value.absent(),
                Value<String?> priceUsd = const Value.absent(),
                Value<String?> priceUsdFoil = const Value.absent(),
                Value<String?> priceUsdEtched = const Value.absent(),
                Value<String?> priceEur = const Value.absent(),
                Value<String?> priceEurFoil = const Value.absent(),
                Value<String?> priceTix = const Value.absent(),
                Value<int?> pricesUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                oracleId: oracleId,
                name: name,
                setCode: setCode,
                setName: setName,
                setTotal: setTotal,
                collectorNumber: collectorNumber,
                rarity: rarity,
                typeLine: typeLine,
                manaCost: manaCost,
                oracleText: oracleText,
                cmc: cmc,
                colors: colors,
                colorIdentity: colorIdentity,
                artist: artist,
                power: power,
                toughness: toughness,
                loyalty: loyalty,
                lang: lang,
                releasedAt: releasedAt,
                imageUris: imageUris,
                cardFaces: cardFaces,
                cardJson: cardJson,
                priceUsd: priceUsd,
                priceUsdFoil: priceUsdFoil,
                priceUsdEtched: priceUsdEtched,
                priceEur: priceEur,
                priceEurFoil: priceEurFoil,
                priceTix: priceTix,
                pricesUpdatedAt: pricesUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> oracleId = const Value.absent(),
                required String name,
                Value<String?> setCode = const Value.absent(),
                Value<String?> setName = const Value.absent(),
                Value<int?> setTotal = const Value.absent(),
                Value<String?> collectorNumber = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<String?> typeLine = const Value.absent(),
                Value<String?> manaCost = const Value.absent(),
                Value<String?> oracleText = const Value.absent(),
                Value<double?> cmc = const Value.absent(),
                Value<String?> colors = const Value.absent(),
                Value<String?> colorIdentity = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> power = const Value.absent(),
                Value<String?> toughness = const Value.absent(),
                Value<String?> loyalty = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> releasedAt = const Value.absent(),
                Value<String?> imageUris = const Value.absent(),
                Value<String?> cardFaces = const Value.absent(),
                Value<String?> cardJson = const Value.absent(),
                Value<String?> priceUsd = const Value.absent(),
                Value<String?> priceUsdFoil = const Value.absent(),
                Value<String?> priceUsdEtched = const Value.absent(),
                Value<String?> priceEur = const Value.absent(),
                Value<String?> priceEurFoil = const Value.absent(),
                Value<String?> priceTix = const Value.absent(),
                Value<int?> pricesUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                oracleId: oracleId,
                name: name,
                setCode: setCode,
                setName: setName,
                setTotal: setTotal,
                collectorNumber: collectorNumber,
                rarity: rarity,
                typeLine: typeLine,
                manaCost: manaCost,
                oracleText: oracleText,
                cmc: cmc,
                colors: colors,
                colorIdentity: colorIdentity,
                artist: artist,
                power: power,
                toughness: toughness,
                loyalty: loyalty,
                lang: lang,
                releasedAt: releasedAt,
                imageUris: imageUris,
                cardFaces: cardFaces,
                cardJson: cardJson,
                priceUsd: priceUsd,
                priceUsdFoil: priceUsdFoil,
                priceUsdEtched: priceUsdEtched,
                priceEur: priceEur,
                priceEurFoil: priceEurFoil,
                priceTix: priceTix,
                pricesUpdatedAt: pricesUpdatedAt,
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
    CollectionsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> type,
      Value<String?> filterJson,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String?> filterJson,
    });

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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
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

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
    builder: (column) => column,
  );
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
                Value<String> type = const Value.absent(),
                Value<String?> filterJson = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                type: type,
                filterJson: filterJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> type = const Value.absent(),
                Value<String?> filterJson = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                type: type,
                filterJson: filterJson,
              ),
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
