import '../domain/domain_models.dart';

enum FilterValueKind { text, multiSelect, numberRange }

class FilterOptionDefinition {
  const FilterOptionDefinition({required this.value, required this.label});

  final String value;
  final String label;
}

class FilterDefinition {
  const FilterDefinition({
    required this.key,
    required this.kind,
    required this.label,
    this.options = const <FilterOptionDefinition>[],
  });

  final String key;
  final FilterValueKind kind;
  final String label;
  final List<FilterOptionDefinition> options;
}

List<FilterDefinition> filterDefinitionsForGame(TcgGameId gameId) {
  switch (gameId) {
    case TcgGameId.pokemon:
      return const <FilterDefinition>[
        FilterDefinition(
          key: 'query',
          kind: FilterValueKind.text,
          label: 'Name',
        ),
        FilterDefinition(
          key: 'sets',
          kind: FilterValueKind.multiSelect,
          label: 'Set',
        ),
        FilterDefinition(
          key: 'collector_number',
          kind: FilterValueKind.text,
          label: 'Number',
        ),
        FilterDefinition(
          key: 'rarities',
          kind: FilterValueKind.multiSelect,
          label: 'Rarity',
        ),
        FilterDefinition(
          key: 'pokemon.category',
          kind: FilterValueKind.multiSelect,
          label: 'Category',
          options: <FilterOptionDefinition>[
            FilterOptionDefinition(value: 'Pokemon', label: 'Pokemon'),
            FilterOptionDefinition(value: 'Trainer', label: 'Trainer'),
            FilterOptionDefinition(value: 'Energy', label: 'Energy'),
          ],
        ),
        FilterDefinition(
          key: 'types',
          kind: FilterValueKind.multiSelect,
          label: 'Type',
          options: <FilterOptionDefinition>[
            FilterOptionDefinition(value: 'Grass', label: 'Grass'),
            FilterOptionDefinition(value: 'Fire', label: 'Fire'),
            FilterOptionDefinition(value: 'Water', label: 'Water'),
            FilterOptionDefinition(value: 'Lightning', label: 'Lightning'),
            FilterOptionDefinition(value: 'Psychic', label: 'Psychic'),
            FilterOptionDefinition(value: 'Fighting', label: 'Fighting'),
            FilterOptionDefinition(value: 'Darkness', label: 'Darkness'),
            FilterOptionDefinition(value: 'Metal', label: 'Metal'),
            FilterOptionDefinition(value: 'Dragon', label: 'Dragon'),
            FilterOptionDefinition(value: 'Fairy', label: 'Fairy'),
            FilterOptionDefinition(value: 'Colorless', label: 'Colorless'),
          ],
        ),
        FilterDefinition(
          key: 'pokemon.subtypes',
          kind: FilterValueKind.multiSelect,
          label: 'Subtype',
        ),
        FilterDefinition(
          key: 'artist',
          kind: FilterValueKind.text,
          label: 'Illustrator',
        ),
        FilterDefinition(
          key: 'pokemon.regulation_mark',
          kind: FilterValueKind.multiSelect,
          label: 'Regulation mark',
          options: <FilterOptionDefinition>[
            FilterOptionDefinition(value: 'A', label: 'A'),
            FilterOptionDefinition(value: 'B', label: 'B'),
            FilterOptionDefinition(value: 'C', label: 'C'),
            FilterOptionDefinition(value: 'D', label: 'D'),
            FilterOptionDefinition(value: 'E', label: 'E'),
            FilterOptionDefinition(value: 'F', label: 'F'),
            FilterOptionDefinition(value: 'G', label: 'G'),
            FilterOptionDefinition(value: 'H', label: 'H'),
          ],
        ),
        FilterDefinition(
          key: 'colors',
          kind: FilterValueKind.multiSelect,
          label: 'Energy',
        ),
        FilterDefinition(
          key: 'hp',
          kind: FilterValueKind.numberRange,
          label: 'HP',
        ),
        FilterDefinition(
          key: 'pokemon.stage',
          kind: FilterValueKind.multiSelect,
          label: 'Stage',
          options: <FilterOptionDefinition>[
            FilterOptionDefinition(value: 'Basic', label: 'Basic'),
            FilterOptionDefinition(value: 'Stage1', label: 'Stage 1'),
            FilterOptionDefinition(value: 'Stage2', label: 'Stage 2'),
            FilterOptionDefinition(value: 'VMAX', label: 'VMAX'),
            FilterOptionDefinition(value: 'VSTAR', label: 'VSTAR'),
          ],
        ),
        FilterDefinition(
          key: 'attack_energy_cost',
          kind: FilterValueKind.numberRange,
          label: 'Attack energy cost',
        ),
      ];
    case TcgGameId.mtg:
      return const <FilterDefinition>[
        FilterDefinition(
          key: 'query',
          kind: FilterValueKind.text,
          label: 'Name',
        ),
        FilterDefinition(
          key: 'sets',
          kind: FilterValueKind.multiSelect,
          label: 'Set',
        ),
        FilterDefinition(
          key: 'rarities',
          kind: FilterValueKind.multiSelect,
          label: 'Rarity',
        ),
        FilterDefinition(
          key: 'colors',
          kind: FilterValueKind.multiSelect,
          label: 'Color',
        ),
        FilterDefinition(
          key: 'types',
          kind: FilterValueKind.multiSelect,
          label: 'Type',
        ),
        FilterDefinition(
          key: 'artist',
          kind: FilterValueKind.text,
          label: 'Artist',
        ),
        FilterDefinition(
          key: 'mana_value',
          kind: FilterValueKind.numberRange,
          label: 'Mana value',
        ),
      ];
    default:
      return const <FilterDefinition>[];
  }
}
