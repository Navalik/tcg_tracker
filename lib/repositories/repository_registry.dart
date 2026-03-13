import 'catalog_repository.dart';
import 'collection_repository.dart';
import 'price_repository.dart';
import 'search_repository.dart';
import 'set_repository.dart';

class RepositoryRegistry {
  const RepositoryRegistry({
    required this.catalog,
    required this.sets,
    required this.search,
    required this.collections,
    required this.prices,
  });

  final CatalogRepository catalog;
  final SetRepository sets;
  final SearchRepository search;
  final CollectionRepository collections;
  final PriceRepository prices;
}
