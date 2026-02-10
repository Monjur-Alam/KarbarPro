import 'package:equatable/equatable.dart';

class SummaryStats extends Equatable {
  final int salesCount;
  final double totalRevenue;
  final double totalProfit;
  final double averageSale;
  final double? previousRevenue; // For comparison

  const SummaryStats({
    required this.salesCount,
    required this.totalRevenue,
    required this.totalProfit,
    required this.averageSale,
    this.previousRevenue,
  });

  double get profitMargin => totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;
  
  double get revenueGrowth {
    if (previousRevenue == null || previousRevenue == 0) return 0;
    return ((totalRevenue - previousRevenue!) / previousRevenue!) * 100;
  }

  @override
  List<Object?> get props => [salesCount, totalRevenue, totalProfit, averageSale, previousRevenue];
}

class ProductReportItem extends Equatable {
  final int productId;
  final String productName;
  final int quantitySold;
  final double totalRevenue;
  final double totalProfit;

  const ProductReportItem({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalProfit,
  });

  @override
  List<Object?> get props => [productId, productName, quantitySold, totalRevenue, totalProfit];
}

class DailyTrendPoint extends Equatable {
  final DateTime date;
  final double revenue;
  final double profit;

  const DailyTrendPoint({
    required this.date,
    required this.revenue,
    required this.profit,
  });

  @override
  List<Object?> get props => [date, revenue, profit];
}

class SalesReportData extends Equatable {
  final SummaryStats stats;
  final List<ProductReportItem> topProducts;
  final List<DailyTrendPoint> dailyTrend;
  final List<PaymentTypeSummary> paymentSummary;

  const SalesReportData({
    required this.stats,
    required this.topProducts,
    required this.dailyTrend,
    required this.paymentSummary,
  });

  @override
  List<Object?> get props => [stats, topProducts, dailyTrend, paymentSummary];
}

class PaymentTypeSummary extends Equatable {
  final String paymentType;
  final int count;
  final double revenue;

  const PaymentTypeSummary({
    required this.paymentType,
    required this.count,
    required this.revenue,
  });

  @override
  List<Object?> get props => [paymentType, count, revenue];
}
