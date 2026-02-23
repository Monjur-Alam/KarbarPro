import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
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
    final cs = Theme.of(context).colorScheme;
    final amountColor = isIncome ? cs.primary : cs.error;
    final iconBgColor = isIncome
        ? cs.primary.withValues(alpha: 0.15)
        : cs.error.withValues(alpha: 0.15);
    final iconColor = isIncome ? cs.primary : cs.error;
    final muted = cs.onSurfaceVariant;

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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: muted),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatterUtils.formatTransactionDate(transaction.transactionDate),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 12, color: muted),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatterUtils.formatTime(transaction.transactionDate),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                  if (transaction.description != null && transaction.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.description!,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
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
                  '${isIncome ? '+' : '-'}৳${context.l10n.formatAmount(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 20, color: muted),
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
