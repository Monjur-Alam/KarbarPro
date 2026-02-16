import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/sync_service.dart';
import '../../data/inventory_repository.dart';
import '../../domain/product.dart';

// Events
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  @override
  List<Object> get props => [];
}

class LoadProducts extends InventoryEvent {
  final String? searchQuery;
  final String? category;
  final String? stockFilter;
  final String sortBy;

  const LoadProducts({
    this.searchQuery,
    this.category,
    this.stockFilter,
    this.sortBy = 'latest',
  });

  @override
  List<Object> get props => [
    searchQuery ?? '',
    category ?? '',
    stockFilter ?? '',
    sortBy,
  ];
}

class AddProduct extends InventoryEvent {
  final Product product;
  const AddProduct(this.product);
  @override
  List<Object> get props => [product];
}
class UpdateProduct extends InventoryEvent {
  final Product product;
  const UpdateProduct(this.product);
  @override
  List<Object> get props => [product];
}
class DeleteProduct extends InventoryEvent {
  final int id;
  const DeleteProduct(this.id);
  @override
  List<Object> get props => [id];
}

// States
abstract class InventoryState extends Equatable {
  const InventoryState();
  @override
  List<Object?> get props => [];
}

class InventoryInitial extends InventoryState {}
class InventoryLoading extends InventoryState {}
class InventoryLoaded extends InventoryState {
  final List<Product> products;
  final String? searchQuery;
  final String? category;
  final String? stockFilter;
  final String sortBy;
  final List<String> allCategories;

  const InventoryLoaded(
    this.products, {
    this.searchQuery,
    this.category,
    this.stockFilter,
    this.sortBy = 'latest',
    this.allCategories = const [],
  });
  
  InventoryLoaded copyWith({
    List<Product>? products,
    String? searchQuery,
    String? category,
    String? stockFilter,
    String sortBy = 'latest',
    List<String>? allCategories,
  }) {
    return InventoryLoaded(
      products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      stockFilter: stockFilter ?? this.stockFilter,
      sortBy: sortBy,
      allCategories: allCategories ?? this.allCategories,
    );
  }

  @override
  List<Object?> get props => [products, searchQuery, category, stockFilter, sortBy, allCategories];
}
class InventoryError extends InventoryState {
  final String message;
  const InventoryError(this.message);
  @override
  List<Object> get props => [message];
}

// Bloc
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository _repository;
  final SyncService _syncService;

  InventoryBloc({
    required InventoryRepository repository,
    required SyncService syncService,
  })  : _repository = repository,
        _syncService = syncService,
        super(InventoryInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<InventoryState> emit,
  ) async {
    // Determine if we are updating existing state or starting fresh
    List<String> categories = [];
    if (state is InventoryLoaded) {
      categories = (state as InventoryLoaded).allCategories;
    } else {
      emit(InventoryLoading());
    }

    try {
      final products = await _repository.getProducts(
        searchQuery: event.searchQuery,
        category: event.category,
        stockFilter: event.stockFilter,
        sortBy: event.sortBy,
      );
      
      // Calculate categories from all products (fetched without filters ideally, but for now we aggregate from result or keep existing)
      // To get ALL categories properly, we might need a separate repo method or just aggregate from what we have if it's the full list
      // For now, let's assume we want categories from the current list if we are just searching, 
      // but if we are filtering, we might lose other categories. 
      // Better approach: If categories are empty (first load), aggregate them.
      if (categories.isEmpty) {
        // Fetch all products once to get categories if needed, or just use current list
        // Optimization: For now just use unique categories from current list
        final uniqueCats = products
            .where((p) => p.category != null && p.category!.isNotEmpty)
            .map((p) => p.category!)
            .toSet()
            .toList();
        uniqueCats.sort();
        categories = ['All', ...uniqueCats];
      }

      emit(InventoryLoaded(
        products,
        searchQuery: event.searchQuery,
        category: event.category,
        stockFilter: event.stockFilter,
        sortBy: event.sortBy,
        allCategories: categories,
      ));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> _onAddProduct(
    AddProduct event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.addProduct(event.product);
      _reloadWithCurrentFilters();
      _syncService.performSync(); // Trigger sync
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> _onUpdateProduct(
    UpdateProduct event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.updateProduct(event.product);
      _reloadWithCurrentFilters();
      _syncService.performSync(); // Trigger sync
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.deleteProduct(event.id);
      _reloadWithCurrentFilters();
      _syncService.performSync(); // Trigger sync
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  void _reloadWithCurrentFilters() {
    String? searchQuery;
    String? category;
    String? stockFilter;
    String sortBy = 'latest';
    
    if (state is InventoryLoaded) {
      final loaded = state as InventoryLoaded;
      searchQuery = loaded.searchQuery;
      category = loaded.category;
      stockFilter = loaded.stockFilter;
      sortBy = loaded.sortBy;
    }
    
    add(LoadProducts(
      searchQuery: searchQuery,
      category: category,
      stockFilter: stockFilter,
      sortBy: sortBy,
    ));
  }
}
