import 'package:flutter/material.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_form.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class ExpenseScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final String? initialAmount;
  final DateTime? initialDate;
  final String? smsTransactionId;
  final String? initialPaymentMethod;
  final String? initialBankName;
  final String? initialAccountNumber;
  final String? initialPayee;
  final String? initialCategory;
  final Person? initialPerson;
  final bool initialIsLoan;
  final String initialLoanSubtype;

  const ExpenseScreen({
    super.key,
    this.transaction,
    this.initialAmount,
    this.initialDate,
    this.smsTransactionId,
    this.initialPaymentMethod,
    this.initialBankName,
    this.initialAccountNumber,
    this.initialPayee,
    this.initialCategory,
    this.initialPerson,
    this.initialIsLoan = false,
    this.initialLoanSubtype = 'new',
  });

  @override
  State<ExpenseScreen> createState() => ExpenseScreenState();
}

class ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<TransactionFormState>();

  void save(String currencyCode, {bool stayOnPage = false}) {
    _formKey.currentState?.save(currencyCode, stayOnPage: stayOnPage);
  }

  @override
  Widget build(BuildContext context) {
    return TransactionForm(
      key: _formKey,
      mode: TransactionMode.expense,
      transaction: widget.transaction,
      initialAmount: widget.initialAmount,
      initialDate: widget.initialDate,
      smsTransactionId: widget.smsTransactionId,
      initialPaymentMethod: widget.initialPaymentMethod,
      initialBankName: widget.initialBankName,
      initialAccountNumber: widget.initialAccountNumber,
      initialPayee: widget.initialPayee,
      initialCategory: widget.initialCategory,
      initialPerson: widget.initialPerson,
      initialIsLoan: widget.initialIsLoan,
      initialLoanSubtype: widget.initialLoanSubtype,
    );
  }
}
