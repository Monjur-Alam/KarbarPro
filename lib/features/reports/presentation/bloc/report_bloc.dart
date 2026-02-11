import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/report_repository.dart';
import '../../domain/report_models.dart';
import '../../../sales/domain/sale.dart';

// Events
abstract class ReportEvent extends Equatable {
  const ReportEvent();
  @override
  List<Object?> get props => [];
}

class LoadReports extends ReportEvent {
  final DateTime startDate;
  final DateTime endDate;
  final String paymentType;

  const LoadReports({
    required this.startDate,
    required this.endDate,
    this.paymentType = 'all',
  });

  @override
  List<Object?> get props => [startDate, endDate, paymentType];
}

class RefreshReports extends ReportEvent {}

// States
abstract class ReportState extends Equatable {
  const ReportState();
  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportLoaded extends ReportState {
  final SalesReportData reportData;
  final List<Sale> sales;
  final DateTime startDate;
  final DateTime endDate;
  final String selectedPaymentType;

  const ReportLoaded({
    required this.reportData,
    required this.sales,
    required this.startDate,
    required this.endDate,
    required this.selectedPaymentType,
  });

  @override
  List<Object?> get props => [reportData, sales, startDate, endDate, selectedPaymentType];

  ReportLoaded copyWith({
    SalesReportData? reportData,
    List<Sale>? sales,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedPaymentType,
  }) {
    return ReportLoaded(
      reportData: reportData ?? this.reportData,
      sales: sales ?? this.sales,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedPaymentType: selectedPaymentType ?? this.selectedPaymentType,
    );
  }
}

class ReportError extends ReportState {
  final String message;
  const ReportError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository _repository;

  ReportBloc({required ReportRepository repository})
      : _repository = repository,
        super(ReportInitial()) {
    on<LoadReports>(_onLoadReports);
    on<RefreshReports>(_onRefreshReports);
  }

  Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
    emit(ReportLoading());
    try {
      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        _repository.getSummaryStats(event.startDate, event.endDate),
        _repository.getTopProducts(event.startDate, event.endDate),
        _repository.getDailyTrend(event.startDate, event.endDate),
        _repository.getPaymentSummary(event.startDate, event.endDate),
        _repository.getFilteredSales(event.startDate, event.endDate, paymentType: event.paymentType),
      ]);

      final reportData = SalesReportData(
        stats: results[0] as SummaryStats,
        topProducts: results[1] as List<ProductReportItem>,
        dailyTrend: results[2] as List<DailyTrendPoint>,
        paymentSummary: results[3] as List<PaymentTypeSummary>,
      );

      emit(ReportLoaded(
        reportData: reportData,
        sales: results[4] as List<Sale>,
        startDate: event.startDate,
        endDate: event.endDate,
        selectedPaymentType: event.paymentType,
      ));
    } catch (e) {
      emit(ReportError('রিপোর্ট লোড করতে সমস্যা হয়েছে: ${e.toString()}'));
    }
  }

  Future<void> _onRefreshReports(RefreshReports event, Emitter<ReportState> emit) async {
    if (state is ReportLoaded) {
      final s = state as ReportLoaded;
      add(LoadReports(
        startDate: s.startDate,
        endDate: s.endDate,
        paymentType: s.selectedPaymentType,
      ));
    }
  }
}
