import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/customer_repository.dart';
import '../../domain/customer.dart';

// Events
abstract class CustomerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCustomers extends CustomerEvent {}

class SearchCustomer extends CustomerEvent {
  final String query;
  SearchCustomer(this.query);
  @override
  List<Object?> get props => [query];
}

class AddCustomer extends CustomerEvent {
  final Customer customer;
  AddCustomer(this.customer);
  @override
  List<Object?> get props => [customer];
}

// States
abstract class CustomerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CustomerInitial extends CustomerState {}
class CustomerLoading extends CustomerState {}
class CustomerLoaded extends CustomerState {
  final List<Customer> customers;
  final List<Customer> filteredCustomers;
  CustomerLoaded(this.customers, {List<Customer>? filtered}) 
      : filteredCustomers = filtered ?? customers;
  @override
  List<Object?> get props => [customers, filteredCustomers];
}
class CustomerError extends CustomerState {
  final String message;
  CustomerError(this.message);
  @override
  List<Object?> get props => [message];
}

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository _repository;

  CustomerBloc({required CustomerRepository repository})
      : _repository = repository,
        super(CustomerInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<SearchCustomer>(_onSearchCustomer);
    on<AddCustomer>(_onAddCustomer);
  }

  Future<void> _onLoadCustomers(LoadCustomers event, Emitter<CustomerState> emit) async {
    emit(CustomerLoading());
    try {
      final customers = await _repository.getActiveCustomers();
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  void _onSearchCustomer(SearchCustomer event, Emitter<CustomerState> emit) {
    if (state is CustomerLoaded) {
      final s = state as CustomerLoaded;
      final filtered = s.customers.where((c) => 
        c.name.toLowerCase().contains(event.query.toLowerCase()) || 
        c.phone.contains(event.query)
      ).toList();
      emit(CustomerLoaded(s.customers, filtered: filtered));
    }
  }

  Future<void> _onAddCustomer(AddCustomer event, Emitter<CustomerState> emit) async {
    try {
      await _repository.createCustomer(event.customer);
      add(LoadCustomers()); // Reload
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }
}
