// lib/all_expenses_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'home_page.dart'; // Import your HomePage's model

class AllExpensesPage extends StatefulWidget {
  final List<Expense> expenses;

  const AllExpensesPage({super.key, required this.expenses});

  @override
  // ignore: library_private_types_in_public_api
  _AllExpensesPageState createState() => _AllExpensesPageState();
}

class _AllExpensesPageState extends State<AllExpensesPage> {
  DateTime _selectedDate = DateTime.now();
  List<Expense> _filteredExpenses = [];

  @override
  void initState() {
    super.initState();
    _filterExpensesByDate(_selectedDate);
  }

  void _filterExpensesByDate(DateTime date) {
    setState(() {
      _filteredExpenses = widget.expenses.where((expense) {
        return expense.date.year == date.year &&
            expense.date.month == date.month &&
            expense.date.day == date.day;
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _filterExpensesByDate(_selectedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Expenses'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expenses for: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Select Date'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredExpenses.isEmpty
                ? const Center(child: Text('No expenses for the selected date.'))
                : ListView.builder(
                    itemCount: _filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = _filteredExpenses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Icon(_getCategoryIcon(expense.category)), // Use your icon function
                          title: Text(expense.category),
                          subtitle: Text('Rs. ${expense.amount.toStringAsFixed(2)}'),
                          trailing: Text(DateFormat('dd-MMM-yyyy').format(expense.date)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // You'll need to copy this function from your HomePage or make it accessible
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'groceries':
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
      case 'travel':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
      case 'utilities':
        return Icons.receipt;
      case 'rent':
      case 'home':
        return Icons.home;
      case 'entertainment':
        return Icons.movie;
      case 'clothing':
        return Icons.checkroom;
      case 'health':
      case 'medical':
        return Icons.health_and_safety;
      default:
        return Icons.money;
    }
  }
}