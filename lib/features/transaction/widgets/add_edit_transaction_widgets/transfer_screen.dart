import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => TransferScreenState();
}

class TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  Account? _fromAccount;
  Account? _toAccount;
  DateTime _selectedDate = DateTime.now();
  double? _creditDue;

  void reset() {
    setState(() {
      _amountController.clear();
      _descController.clear();
      _selectedDate = DateTime.now();
      _fromAccount = null;
      _toAccount = null;
      _creditDue = null;
    });
  }

  Future<void> save(String currencyCode, {bool stayOnPage = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccount == null || _toAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both accounts.')),
      );
      return;
    }

    if (_fromAccount!.id == _toAccount!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('From and To accounts cannot be the same.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final transferGroupId = const Uuid().v4();

    final fromTransaction = TransactionModel(
      transactionId: const Uuid().v4(),
      type: 'expense',
      amount: amount,
      timestamp: _selectedDate,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : 'Transfer to ${_toAccount!.bankName}',
      paymentMethod: 'Transfer',
      category: 'Transfer',
      accountId: _fromAccount!.id,
      purchaseType: _fromAccount!.accountType == 'credit' ? 'credit' : 'debit',
      transferGroupId: transferGroupId,
      currency: currencyCode,
    );

    final isCreditRepayment = _toAccount?.accountType == 'credit';

    final toTransaction = TransactionModel(
      transactionId: const Uuid().v4(),
      type: isCreditRepayment ? 'transfer' : 'income',
      amount: amount,
      timestamp: _selectedDate,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : 'Transfer from ${_fromAccount!.bankName}',
      paymentMethod: 'Transfer',
      category: isCreditRepayment ? 'Credit Repayment' : 'Transfer',
      accountId: _toAccount!.id,
      purchaseType: 'debit',
      transferGroupId: transferGroupId,
      currency: currencyCode,
    );

    await txProvider.addTransfer(fromTransaction, toTransaction);
    if (!mounted) return;

    if (stayOnPage) {
      reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer saved! Record another.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _showAccountPicker(bool isFromAccount) {
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    final accounts = accountProvider.accounts;
    showCustomAccountModal(context, accounts, (acc) {
      setState(() {
        if (isFromAccount) {
          _fromAccount = acc;
        } else {
          _toAccount = acc;
          if (acc.accountType == 'credit') {
            _creditDue = Provider.of<TransactionProvider>(
              context,
              listen: false,
            ).getCreditDue(acc.id);
          } else {
            _creditDue = null;
          }
        }
      });
    }, selectedId: isFromAccount ? _fromAccount?.id : _toAccount?.id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Amount Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AmountInputHero(
              controller: _amountController,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          // Date Pill
          Center(
            child: DatePill(selectedDate: _selectedDate, onTap: _pickDate),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                // Transfer Visualization
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        FunkyPickerTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: "From Account",
                          value: _fromAccount?.displayName,
                          onTap: () => _showAccountPicker(true),
                          isCompact: false,
                        ),
                        const SizedBox(height: 20),
                        FunkyPickerTile(
                          icon: Icons.savings_outlined,
                          label: "To Account",
                          value: _toAccount?.displayName,
                          onTap: () => _showAccountPicker(false),
                          isCompact: false,
                        ),
                      ],
                    ),
                    // The Arrow
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                if (_creditDue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.errorContainer.withAlpha(128),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Outstanding Due: ${Provider.of<SettingsProvider>(context).currencySymbol}${_creditDue!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                FunkyTextField(
                  controller: _descController,
                  label: "Description (Optional)",
                  icon: Icons.notes_rounded,
                ),

                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
        ],
      ),
    );
  }
}
