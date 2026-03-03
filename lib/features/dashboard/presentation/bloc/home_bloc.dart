import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/dashboard_repository.dart';
import '../../../../core/services/sync_service.dart';

// Events
abstract class HomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDashboard extends HomeEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  LoadDashboard({this.startDate, this.endDate});
  @override
  List<Object?> get props => [startDate, endDate];
}

class RefreshDashboard extends HomeEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  RefreshDashboard({this.startDate, this.endDate});
  @override
  List<Object?> get props => [startDate, endDate];
}

class SyncStatusChanged extends HomeEvent {
  final SyncStatus status;
  SyncStatusChanged(this.status);
  @override
  List<Object?> get props => [status];
}

// States
abstract class HomeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}
class HomeLoaded extends HomeState {
  final DashboardSummary summary;
  final SyncStatus syncStatus;
  final DateTime startDate;
  final DateTime endDate;

  HomeLoaded({
    required this.summary, 
    required this.syncStatus,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [summary, syncStatus, startDate, endDate];
}
class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
  @override
  List<Object?> get props => [message];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DashboardRepository _repository;
  final SyncService _syncService;
  StreamSubscription? _syncSubscription;

  HomeBloc({
    required DashboardRepository repository,
    required SyncService syncService,
  }) : _repository = repository,
       _syncService = syncService,
       super(HomeInitial()) {
    
    on<LoadDashboard>(_onLoadDashboard);
    on<RefreshDashboard>(_onRefreshDashboard);
    on<SyncStatusChanged>(_onSyncStatusChanged);

    // Listen to sync status changes
    _syncSubscription = _syncService.statusStream.listen((status) {
      add(SyncStatusChanged(status));
    });
  }

  Future<void> _onLoadDashboard(LoadDashboard event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final summary = await _repository.getDashboardSummary(
        startDate: event.startDate, 
        endDate: event.endDate
      );
      emit(HomeLoaded(
        summary: summary,
        syncStatus: _syncService.currentStatus,
        startDate: event.startDate ?? DateTime.now(),
        endDate: event.endDate ?? DateTime.now(),
      ));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onRefreshDashboard(RefreshDashboard event, Emitter<HomeState> emit) async {
    try {
      final summary = await _repository.getDashboardSummary(
        startDate: event.startDate, 
        endDate: event.endDate
      );
      emit(HomeLoaded(
        summary: summary,
        syncStatus: _syncService.currentStatus,
        startDate: event.startDate ?? DateTime.now(),
        endDate: event.endDate ?? DateTime.now(),
      ));
    } catch (e) {
      // Keep previous state
    }
  }

  void _onSyncStatusChanged(SyncStatusChanged event, Emitter<HomeState> emit) {
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      emit(HomeLoaded(
        summary: currentState.summary,
        syncStatus: event.status,
        startDate: currentState.startDate,
        endDate: currentState.endDate,
      ));
    }
  }

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    return super.close();
  }
}
