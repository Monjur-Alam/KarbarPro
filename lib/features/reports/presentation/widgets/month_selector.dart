import 'package:flutter/material.dart';

class MonthSelector extends StatelessWidget {
  final String month;
  final bool isSelected;
  final VoidCallback onTap;

  const MonthSelector({
    Key? key,
    required this.month,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(
                    color: Color(0xFF2196F3),
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Text(
          month,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF757575),
          ),
        ),
      ),
    );
  }
}
