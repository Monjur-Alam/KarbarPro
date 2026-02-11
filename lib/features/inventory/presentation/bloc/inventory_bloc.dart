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

class LoadProducts extends InventoryEvent {}
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
  List<Object> get props => [];
}

class InventoryInitial extends InventoryState {}
class InventoryLoading extends InventoryState {}
class InventoryLoaded extends InventoryState {
  final List<Product> products;
  const InventoryLoaded(this.products);
  @override
  List<Object> get props => [products];
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
    emit(InventoryLoading());
    try {
      final products = await _repository.getProducts();
      emit(InventoryLoaded(products));
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
      add(LoadProducts());
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
      add(LoadProducts());
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
      add(LoadProducts());
      _syncService.performSync(); // Trigger sync
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }
}
