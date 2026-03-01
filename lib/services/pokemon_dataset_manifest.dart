class PokemonDatasetSet {
  const PokemonDatasetSet({
    required this.setCode,
    required this.language,
    required this.url,
  });

  final String setCode;
  final String language;
  final String url;
}

class PokemonDatasetManifest {
  const PokemonDatasetManifest._();

  static const String version = 'pokemon_dataset_manifest_v1';

  // Keep starter lightweight; users can opt in to larger profiles.
  static const List<PokemonDatasetSet> starterSets = [
    PokemonDatasetSet(
      setCode: 'base1',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/base1.json',
    ),
    PokemonDatasetSet(
      setCode: 'swsh1',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/swsh1.json',
    ),
    PokemonDatasetSet(
      setCode: 'sv1',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/sv1.json',
    ),
  ];

  static const List<PokemonDatasetSet> standardSets = [
    ...starterSets,
    PokemonDatasetSet(
      setCode: 'sv2',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/sv2.json',
    ),
    PokemonDatasetSet(
      setCode: 'sv3',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/sv3.json',
    ),
    PokemonDatasetSet(
      setCode: 'sv4',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/sv4.json',
    ),
  ];

  static const List<PokemonDatasetSet> expandedSets = [
    ...standardSets,
    PokemonDatasetSet(
      setCode: 'swsh2',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/swsh2.json',
    ),
    PokemonDatasetSet(
      setCode: 'swsh3',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/swsh3.json',
    ),
    PokemonDatasetSet(
      setCode: 'swsh4',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/swsh4.json',
    ),
    PokemonDatasetSet(
      setCode: 'swsh5',
      language: 'en',
      url:
          'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/swsh5.json',
    ),
  ];

  static List<PokemonDatasetSet> setsForProfile(String profile) {
    switch (profile.trim().toLowerCase()) {
      case 'full':
        return const [];
      case 'expanded':
        return expandedSets;
      case 'standard':
        return standardSets;
      case 'starter':
      default:
        return starterSets;
    }
  }
}
