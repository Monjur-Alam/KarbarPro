import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';
import '../../domain/customer.dart';
import '../../../inventory/domain/product.dart';

// Events
abstract class SalesEvent extends Equatable {
  const SalesEvent();
  @override
  List<Object> get props => [];
}

class AddToCart extends SalesEvent {
  final Product product;
  const AddToCart(this.product);
  @override
  List<Object> get props => [product];
}

class RemoveFromCart extends SalesEvent {
  final int productId;
  const RemoveFromCart(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateCartQuantity extends SalesEvent {
  final int productId;
  final int quantity;
  const UpdateCartQuantity(this.productId, this.quantity);
  @override
  List<Object> get props => [productId, quantity];
}

class CheckoutSale extends SalesEvent {
  final double discount;
  final double paidAmount;
  final String paymentMethod;
  final Customer? customer;

  const CheckoutSale({
    this.discount = 0.0,
    required this.paidAmount,
    this.paymentMethod = 'cash',
    this.customer,
  });

  @override
  List<Object> get props => [discount, paidAmount, paymentMethod, customer ?? ''];
}

class ClearCart extends SalesEvent {}

// States
class CartItem extends Equatable {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});
  
  double get subTotal => product.sellingPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object> get props => [product, quantity];
}

abstract class SalesState extends Equatable {
  const SalesState();
  @override
  List<Object> get props => [];
}

class SalesInitial extends SalesState {}

class SalesCartUpdate extends SalesState {
  final List<CartItem> items;
  final double totalAmount;

  const SalesCartUpdate({required this.items, required this.totalAmount});

  @override
  List<Object> get props => [items, totalAmount];
}

class SalesLoading extends SalesState {}

class SalesSuccess extends SalesState {
  final String invoiceId;
  const SalesSuccess(this.invoiceId);
  @override
  List<Object> get props => [invoiceId];
}

class SalesError extends SalesState {
  final String message;
  const SalesError(this.message);
  @override
  List<Object> get props => [message];
}


// Bloc
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository _repository;
  final List<CartItem> _cart = [];

  SalesBloc({required SalesRepository repository})
      : _repository = repository,
        super(SalesInitial()) {
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<UpdateCartQuantity>(_onUpdateCartQuantity);
    on<CheckoutSale>(_onCheckoutSale);
    on<ClearCart>(_onClearCart);
  }

  void _onAddToCart(AddToCart event, Emitter<SalesState> emit) {
    final existingIndex = _cart.indexWhere((item) => item.product.id == event.product.id);
    
    if (existingIndex >= 0) {
      _cart[existingIndex] = _cart[existingIndex].copyWith(
        quantity: _cart[existingIndex].quantity + 1,
      );
    } else {
      _cart.add(CartItem(product: event.product, quantity: 1));
    }
    
    _emitCartUpdate(emit);
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<SalesState> emit) {
    _cart.removeWhere((item) => item.product.id == event.productId);
    _emitCartUpdate(emit);
  }

  void _onUpdateCartQuantity(UpdateCartQuantity event, Emitter<SalesState> emit) {
     final index = _cart.indexWhere((item) => item.product.id == event.productId);
     if (index >= 0) {
       if (event.quantity <= 0) {
         _cart.removeAt(index);
       } else {
         _cart[index] = _cart[index].copyWith(quantity: event.quantity);
       }
       _emitCartUpdate(emit);
     }
  }

  void _onClearCart(ClearCart event, Emitter<SalesState> emit) {
    _cart.clear();
    emit(SalesInitial());
  }

  void _emitCartUpdate(Emitter<SalesState> emit) {
    final total = _cart.fold(0.0, (sum, item) => sum + item.subTotal);
    emit(SalesCartUpdate(items: List.from(_cart), totalAmount: total));
  }

  Future<void> _onCheckoutSale(CheckoutSale event, Emitter<SalesState> emit) async {
    if (_cart.isEmpty) {
      emit(const SalesError('Cart is empty'));
      return;
    }

    emit(SalesLoading());
    
    try {
      final totalAmount = _cart.fold(0.0, (sum, item) => sum + item.subTotal);
      final saleId = ''; // Handled by DB
      final invoiceId = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      final saleItems = _cart.map((cartItem) {
        return SaleItem(
          id: '', // Temporary or handled by DB
          saleId: '', // Handled by DB transaction
          productId: cartItem.product.id.toString(),
          productName: cartItem.product.name,
          quantity: cartItem.quantity,
          unitPrice: cartItem.product.sellingPrice,
          subTotal: cartItem.subTotal,
        );
      }).toList();

      final sale = Sale(
        id: saleId,
        invoiceId: invoiceId,
        customerId: event.customer?.id,
        customerName: event.customer?.name,
        totalAmount: totalAmount,
        discount: event.discount,
        paidAmount: event.paidAmount,
        paymentMethod: event.paymentMethod,
        saleDate: DateTime.now(),
        items: saleItems,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.createSale(sale);
      _cart.clear();
      emit(SalesSuccess(invoiceId));
      
    } catch (e) {
      emit(SalesError(e.toString()));
      _emitCartUpdate(emit); // Restore cart state
    }
  }
}
