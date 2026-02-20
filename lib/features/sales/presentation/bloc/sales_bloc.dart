import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';
import 'package:amar_dokan/features/customers/domain/customer.dart';
import '../../../inventory/domain/product.dart';
import 'package:amar_dokan/core/services/sync_service.dart';

enum SalesMode { single, multiple }
enum PaymentType { cash, credit }

// Events
abstract class SalesEvent extends Equatable {
  const SalesEvent();
  @override
  List<Object?> get props => [];
}

class LoadSalesInitialData extends SalesEvent {}

class ToggleSalesMode extends SalesEvent {
  final SalesMode mode;
  const ToggleSalesMode(this.mode);
  @override
  List<Object?> get props => [mode];
}

class TogglePaymentType extends SalesEvent {
  final PaymentType type;
  const TogglePaymentType(this.type);
  @override
  List<Object?> get props => [type];
}

class SelectCustomer extends SalesEvent {
  final Customer? customer;
  const SelectCustomer(this.customer);
  @override
  List<Object?> get props => [customer];
}

class AddToCart extends SalesEvent {
  final Product product;
  final int quantity;
  const AddToCart(this.product, {this.quantity = 1});
  @override
  List<Object?> get props => [product, quantity];
}

class RemoveFromCart extends SalesEvent {
  final int productId;
  const RemoveFromCart(this.productId);
  @override
  List<Object?> get props => [productId];
}

class UpdateCartQuantity extends SalesEvent {
  final int productId;
  final int quantity;
  const UpdateCartQuantity(this.productId, this.quantity);
  @override
  List<Object?> get props => [productId, quantity];
}

class CheckoutSale extends SalesEvent {
  final double discount;
  final double paidAmount;
  final String? notes;

  const CheckoutSale({
    this.discount = 0.0,
    required this.paidAmount,
    this.notes,
  });

  @override
  List<Object?> get props => [discount, paidAmount, notes];
}

class ClearCart extends SalesEvent {}

class SearchProducts extends SalesEvent {
  final String query;
  const SearchProducts(this.query);
  @override
  List<Object?> get props => [query];
}

class ChangeSalesTab extends SalesEvent {
  final String tab; // 'all', 'cash', 'credit'
  const ChangeSalesTab(this.tab);
  @override
  List<Object?> get props => [tab];
}

class UpdateSalesFilters extends SalesEvent {
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? sortBy;
  final String? selectedDateFilterLabel;
  final bool clearStartDate;
  final bool clearEndDate;

  const UpdateSalesFilters({
    this.searchQuery,
    this.startDate,
    this.endDate,
    this.sortBy,
    this.selectedDateFilterLabel,
    this.clearStartDate = false,
    this.clearEndDate = false,
  });

  @override
  List<Object?> get props => [searchQuery, startDate, endDate, sortBy, selectedDateFilterLabel, clearStartDate, clearEndDate];
}

// States
class CartItem extends Equatable {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get subTotal => product.sellingPrice * quantity;
  double get profit => (product.sellingPrice - product.purchasePrice) * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [product, quantity];
}

abstract class SalesState extends Equatable {
  const SalesState();
  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesDataLoaded extends SalesState {
  final List<CartItem> cart;
  final SalesMode mode;
  final PaymentType paymentType;
  final Customer? selectedCustomer;
  final double todayTotalSales;
  final double totalAmount;
  final bool isSubmitting;
  final List<Product> searchResults;
  final bool isSearching;

  // New Fields for Redesign
  final List<Sale> salesHistory;
  final Map<String, dynamic> statistics;
  final String activeTab;
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortBy;
  final String selectedDateFilterLabel;

  const SalesDataLoaded({
    required this.cart,
    required this.mode,
    required this.paymentType,
    this.selectedCustomer,
    required this.todayTotalSales,
    required this.totalAmount,
    this.isSubmitting = false,
    this.searchResults = const [],
    this.isSearching = false,
    this.salesHistory = const [],
    this.statistics = const {},
    this.activeTab = 'all',
    this.searchQuery,
    this.startDate,
    this.endDate,
    this.sortBy = 'date_desc',
    this.selectedDateFilterLabel = 'সব',
  });

  SalesDataLoaded copyWith({
    List<CartItem>? cart,
    SalesMode? mode,
    PaymentType? paymentType,
    Customer? selectedCustomer,
    bool clearCustomer = false,
    double? todayTotalSales,
    double? totalAmount,
    bool? isSubmitting,
    List<Product>? searchResults,
    bool? isSearching,
    List<Sale>? salesHistory,
    Map<String, dynamic>? statistics,
    String? activeTab,
    String? searchQuery,
    bool clearSearch = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? sortBy,
    String? selectedDateFilterLabel,
  }) {
    return SalesDataLoaded(
      cart: cart ?? this.cart,
      mode: mode ?? this.mode,
      paymentType: paymentType ?? this.paymentType,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      todayTotalSales: todayTotalSales ?? this.todayTotalSales,
      totalAmount: totalAmount ?? this.totalAmount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      salesHistory: salesHistory ?? this.salesHistory,
      statistics: statistics ?? this.statistics,
      activeTab: activeTab ?? this.activeTab,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      sortBy: sortBy ?? this.sortBy,
      selectedDateFilterLabel: selectedDateFilterLabel ?? this.selectedDateFilterLabel,
    );
  }

  @override
  List<Object?> get props => [
    cart,
    mode,
    paymentType,
    selectedCustomer,
    todayTotalSales,
    totalAmount,
    isSubmitting,
    searchResults,
    isSearching,
    // New fields
    salesHistory,
    statistics,
    activeTab,
    searchQuery,
    startDate,
    endDate,
    sortBy,
    selectedDateFilterLabel,
  ];
}

class SalesSuccess extends SalesState {
  final Sale sale;
  const SalesSuccess(this.sale);
  @override
  List<Object?> get props => [sale];
}

class SalesError extends SalesState {
  final String message;
  const SalesError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository _repository;
  final SyncService _syncService;

  SalesBloc({
    required SalesRepository repository,
    required SyncService syncService,
  })  : _repository = repository,
        _syncService = syncService,
        super(SalesInitial()) {
    on<LoadSalesInitialData>(_onLoadSalesInitialData);
    on<ToggleSalesMode>(_onToggleSalesMode);
    on<TogglePaymentType>(_onTogglePaymentType);
    on<SelectCustomer>(_onSelectCustomer);
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<UpdateCartQuantity>(_onUpdateCartQuantity);
    on<CheckoutSale>(_onCheckoutSale);
    on<ClearCart>(_onClearCart);
    on<SearchProducts>(_onSearchProducts);
    on<ChangeSalesTab>(_onChangeSalesTab);
    on<UpdateSalesFilters>(_onUpdateSalesFilters);
  }

  Future<void> _onLoadSalesInitialData(LoadSalesInitialData event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      final stats = await _repository.getSalesStatistics();
      final sales = await _repository.getFilteredSales();

      emit(SalesDataLoaded(
        cart: const [],
        mode: SalesMode.single,
        paymentType: PaymentType.cash,
        todayTotalSales: stats['today']['total'],
        totalAmount: 0.0,
        statistics: stats,
        salesHistory: sales,
        activeTab: 'all',
        selectedDateFilterLabel: 'সব',
      ));
    } catch (e) {
      emit(SalesError('ডাটা লোড করতে সমস্যা হয়েছে: ${e.toString()}'));
    }
  }

  Future<void> _onChangeSalesTab(ChangeSalesTab event, Emitter<SalesState> emit) async {
    if (state is SalesDataLoaded) {
      final s = state as SalesDataLoaded;
      emit(s.copyWith(activeTab: event.tab));
    }
  }

  Future<void> _onUpdateSalesFilters(UpdateSalesFilters event, Emitter<SalesState> emit) async {
    SalesDataLoaded s;
    if (state is SalesDataLoaded) {
      s = state as SalesDataLoaded;
    } else {
      // Initialize state first if not yet loaded
      emit(SalesLoading());
      try {
        final initStats = await _repository.getSalesStatistics();
        s = SalesDataLoaded(
          cart: const [],
          mode: SalesMode.single,
          paymentType: PaymentType.cash,
          todayTotalSales: (initStats['today']?['total'] as num?)?.toDouble() ?? 0.0,
          totalAmount: 0.0,
          statistics: initStats,
          salesHistory: const [],
          activeTab: 'all',
        );
      } catch (e) {
        emit(SalesError('ডাটা লোড করতে সমস্যা হয়েছে: ${e.toString()}'));
        return;
      }
    }

    final newSearchQuery = event.searchQuery ?? s.searchQuery;
    final newStartDate = event.clearStartDate ? null : (event.startDate ?? s.startDate);
    final newEndDate = event.clearEndDate ? null : (event.endDate ?? s.endDate);
    final newSortBy = event.sortBy ?? s.sortBy;
    final newLabel = event.selectedDateFilterLabel ?? s.selectedDateFilterLabel;

    emit(s.copyWith(
      searchQuery: newSearchQuery,
      startDate: newStartDate,
      clearStartDate: event.clearStartDate,
      endDate: newEndDate,
      clearEndDate: event.clearEndDate,
      sortBy: newSortBy,
      selectedDateFilterLabel: newLabel,
    ));

    try {
      final sales = await _repository.getFilteredSales(
        paymentType: null,
        searchQuery: newSearchQuery,
        startDate: newStartDate,
        endDate: newEndDate,
        sortBy: newSortBy,
      );

      final stats = await _repository.getFilteredSalesStatistics(
        startDate: newStartDate,
        endDate: newEndDate,
      );

      emit((state as SalesDataLoaded).copyWith(
        salesHistory: sales,
        statistics: {...s.statistics, 'today': stats},
      ));
    } catch (e) {
      print('Sales Filter Error: $e');
      emit(SalesError('ফিল্টার করতে সমস্যা হয়েছে: $e'));
    }
  }

  void _onToggleSalesMode(ToggleSalesMode event, Emitter<SalesState> emit) {
    if (state is SalesDataLoaded) {
      emit((state as SalesDataLoaded).copyWith(mode: event.mode));
    }
  }

  void _onTogglePaymentType(TogglePaymentType event, Emitter<SalesState> emit) {
    if (state is SalesDataLoaded) {
      emit((state as SalesDataLoaded).copyWith(paymentType: event.type));
    }
  }

  void _onSelectCustomer(SelectCustomer event, Emitter<SalesState> emit) {
    if (state is SalesDataLoaded) {
      emit((state as SalesDataLoaded).copyWith(
        selectedCustomer: event.customer,
        clearCustomer: event.customer == null,
      ));
    }
  }

  void _onAddToCart(AddToCart event, Emitter<SalesState> emit) {
    if (state is SalesDataLoaded) {
      final s = state as SalesDataLoaded;

      // Stock Validation
      final existingItemIndex = s.cart.indexWhere((i) => i.product.id == event.product.id);
      int currentInCart = 0;
      if (existingItemIndex >= 0) {
        currentInCart = s.cart[existingItemIndex].quantity;
      }

      if (currentInCart + event.quantity > event.product.currentStock) {
        emit(const SalesError('দুঃখিত, পর্যাপ্ত স্টক নেই!'));
        emit(s);
        return;
      }

      final cart = List<CartItem>.from(s.cart);
      if (existingItemIndex >= 0) {
        cart[existingItemIndex] = cart[existingItemIndex].copyWith(quantity: currentInCart + event.quantity);
      } else {
        cart.add(CartItem(product: event.product, quantity: event.quantity));
      }

      emit(s.copyWith(cart: cart, totalAmount: _calculateTotal(cart)));
    }
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<SalesState> emit) {
    if (state is SalesDataLoaded) {
      final s = state as SalesDataLoaded;
      final cart = List<CartItem>.from(s.cart)..removeWhere((i) => i.product.id == event.productId);
      emit(s.copyWith(cart: cart, totalAmount: _calculateTotal(cart)));
    }
  }

  void _onUpdateCartQuantity(UpdateCartQuantity event, Emitter<SalesState> emit) {
    if (state is SalesDataLoaded) {
      final s = state as SalesDataLoaded;
      final cart = List<CartItem>.from(s.cart);
      final index = cart.indexWhere((i) => i.product.id == event.productId);
      if (index >= 0) {
        if (event.quantity <= 0) {
          cart.removeAt(index);
        } else {
          // Stock Validation
          if (event.quantity > cart[index].product.currentStock) {
            emit(const SalesError('দুঃখিত, পর্যাপ্ত স্টক নেই!'));
            emit(s);
            return;
          }
          cart[index] = cart[index].copyWith(quantity: event.quantity);
        }
        emit(s.copyWith(cart: cart, totalAmount: _calculateTotal(cart)));
      }
    }
  }

  void _onClearCart(ClearCart event, Emitter<SalesState> emit) {
    if (state is SalesDataLoaded) {
      final s = state as SalesDataLoaded;
      emit(s.copyWith(cart: [], totalAmount: 0.0, clearCustomer: true));
    }
  }

  Future<void> _onSearchProducts(SearchProducts event, Emitter<SalesState> emit) async {
    if (state is SalesDataLoaded) {
      final s = state as SalesDataLoaded;
      emit(s.copyWith(isSearching: true));
      emit(s.copyWith(isSearching: false));
    }
  }

  Future<void> _onCheckoutSale(CheckoutSale event, Emitter<SalesState> emit) async {
    if (state is SalesDataLoaded) {
      final s = state as SalesDataLoaded;
      if (s.cart.isEmpty) {
        emit(const SalesError('কার্ট ফাঁকা!'));
        emit(s);
        return;
      }

      if (s.paymentType == PaymentType.credit && s.selectedCustomer == null) {
        emit(const SalesError('বাকি বিক্রির জন্য গ্রাহক নির্বাচন করুন!'));
        emit(s);
        return;
      }

      emit(s.copyWith(isSubmitting: true));

      try {
        final invoiceId = 'INV-${DateTime.now().millisecondsSinceEpoch}';
        final saleItems = s.cart.map((item) => SaleItem(
          id: null,
          saleId: null,
          productId: item.product.id!,
          productName: item.product.name,
          quantity: item.quantity,
          unitPrice: item.product.sellingPrice,
          purchasePrice: item.product.purchasePrice,
          subTotal: item.subTotal,
        )).toList();

        final sale = Sale(
          id: null,
          invoiceId: invoiceId,
          customerId: s.selectedCustomer?.id,
          customerName: s.selectedCustomer?.name,
          totalAmount: s.totalAmount - event.discount,
          discount: event.discount,
          paidAmount: event.paidAmount,
          paymentMethod: s.paymentType == PaymentType.cash ? 'cash' : 'credit',
          saleDate: DateTime.now(),
          items: saleItems,
          notes: event.notes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _repository.createSale(sale);

        // Trigger sync
        _syncService.performSync();

        // Return the full sale object for the success dialog
        emit(SalesSuccess(sale));

        final newStats = await _repository.getSalesStatistics();
        final newSales = await _repository.getFilteredSales(
           paymentType: s.activeTab == 'all' ? null : s.activeTab,
           searchQuery: s.searchQuery,
           startDate: s.startDate,
           endDate: s.endDate,
           sortBy: s.sortBy,
        );

        // Reset state after success
        emit(s.copyWith(
          cart: [],
          totalAmount: 0.0,
          isSubmitting: false,
          todayTotalSales: newStats['today']['total'],
          statistics: newStats,
          salesHistory: newSales,
          clearCustomer: true,
        ));
      } catch (e) {
        emit(SalesError('বিক্রয় সম্পন্ন করতে সমস্যা হয়েছে: ${e.toString()}'));
        emit(s.copyWith(isSubmitting: false));
      }
    }
  }

  double _calculateTotal(List<CartItem> cart) {
    return cart.fold(0.0, (sum, item) => sum + item.subTotal);
  }
}
