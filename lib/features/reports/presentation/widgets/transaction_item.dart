import 'package:flutter/material.dart';
import '../../domain/expense_model.dart';
import '../../utils/date_formatter_utils.dart';

class TransactionItem extends StatelessWidget {
  final ShopTransaction transaction;
  final VoidCallback? onTap;

  const TransactionItem({
    Key? key,
    required this.transaction,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.transactionType == 'income';
    final amountColor = isIncome ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final iconBgColor = isIncome 
        ? const Color(0xFFE8F5E9) 
        : const Color(0xFFFFEBEE);
    final iconColor = isIncome 
        ? const Color(0xFF4CAF50) 
        : const Color(0xFFF44336);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(),
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.category ?? (isIncome ? 'টাকা যোগ' : 'খরচ'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatterUtils.formatTransactionDate(transaction.transactionDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatterUtils.formatTime(transaction.transactionDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                  if (transaction.description != null && transaction.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}৳${DateFormatterUtils.toBengaliNumber(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFF9E9E9E),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    final cat = (transaction.category ?? '').toLowerCase();
    if (transaction.transactionType == 'income') {
      if (cat.contains('salary')) {
        return Icons.account_balance_wallet;
      } else if (cat.contains('loan')) {
        return Icons.account_balance;
      }
      return Icons.arrow_downward;
    } else {
      return Icons.arrow_upward;
    }
  }
}
