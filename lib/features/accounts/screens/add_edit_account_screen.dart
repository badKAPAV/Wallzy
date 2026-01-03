import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/transaction/screens/styled_form_fields.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/models/tag.dart';

class AddEditAccountScreen extends StatefulWidget {
  final Account? account;
  const AddEditAccountScreen({super.key, this.account});

  bool get isEditing => account != null;

  @override
  State<AddEditAccountScreen> createState() => _AddEditAccountScreenState();
}

class _AddEditAccountScreenState extends State<AddEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _billingCycleDayController = TextEditingController(text: '1');
  final _initialBalanceController = TextEditingController();

  String _accountType = 'debit';

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final acc = widget.account!;
      _bankNameController.text = acc.bankName;
      _accountNumberController.text = acc.accountNumber;
      _accountHolderNameController.text = acc.accountHolderName;
      _accountType = acc.accountType;

      if (_accountType == 'credit') {
        _creditLimitController.text = acc.creditLimit?.toStringAsFixed(0) ?? '';
        _billingCycleDayController.text =
            acc.billingCycleDay?.toString() ?? '1';
      }
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderNameController.dispose();
    _creditLimitController.dispose();
    _billingCycleDayController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(
      context,
      listen: false,
    );
    final userId = authProvider.user!.uid;

    final double? creditLimit = _accountType == 'credit'
        ? double.tryParse(_creditLimitController.text.trim())
        : null;
    final int? billingDay = _accountType == 'credit'
        ? int.tryParse(_billingCycleDayController.text.trim())
        : null;

    if (widget.isEditing) {
      final updatedAccount = widget.account!.copyWith(
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountHolderName: _accountHolderNameController.text.trim(),
        accountType: _accountType,
        creditLimit: creditLimit,
        billingCycleDay: billingDay,
      );
      await accountProvider.updateAccount(updatedAccount);
    } else {
      final newAccount = Account(
        id: const Uuid()
            .v4(), // This is just for local, Firestore will generate its own
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountHolderName: _accountHolderNameController.text.trim(),
        userId: userId,
        accountType: _accountType,
        creditLimit: creditLimit,
        billingCycleDay: billingDay,
      );
      final createdAccount = await accountProvider.addAccount(newAccount);

      // Handle Initial Balance for Debit Accounts
      if (_accountType == 'debit' &&
          _initialBalanceController.text.isNotEmpty) {
        final amount = double.tryParse(_initialBalanceController.text.trim());
        if (amount != null && amount > 0) {
          // Find or create "balance money" tag
          final tagName = "balance money";
          Tag? balanceTag = metaProvider.tags.firstWhere(
            (t) => t.name.toLowerCase() == tagName,
            orElse: () => Tag(id: '', name: ''), // Temporary
          );

          if (balanceTag.id.isEmpty) {
            // ignore: deprecated_member_use
            balanceTag = await metaProvider.addTag(
              tagName,
              color: Colors.green.value,
            );
          }

          final transaction = TransactionModel(
            transactionId: const Uuid().v4(),
            type: 'income',
            amount: amount,
            timestamp: DateTime.now(),
            description: 'Initial Balance',
            paymentMethod: 'Bank',
            accountId: createdAccount.id, // Use the real ID
            category: 'Income',
            tags: [balanceTag],
            currency: 'INR',
          );

          await transactionProvider.addTransaction(transaction);
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildAccountTypeSelector() {
    final theme = Theme.of(context);
    final onPrimaryContainer = theme.colorScheme.onPrimaryContainer;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Container(
        width: 220,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: _accountType == 'debit'
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Container(
                width: 110,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Row(
              children: [
                _buildSelectorOption(
                  'debit',
                  'Debit',
                  onPrimaryContainer,
                  onSurfaceVariant,
                ),
                _buildSelectorOption(
                  'credit',
                  'Credit',
                  onPrimaryContainer,
                  onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorOption(
    String value,
    String text,
    Color selectedColor,
    Color unselectedColor,
  ) {
    final isSelected = _accountType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _accountType = value),
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? selectedColor : unselectedColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Account' : 'Add Account'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAccountTypeSelector(),
            const SizedBox(height: 24),
            StyledTextField(
              controller: _bankNameController,
              label: _accountType == 'debit'
                  ? 'Bank Name (e.g., HDFC, SBI)'
                  : 'Card Issuer (e.g., HDFC, Amex)',
              icon: Icons.account_balance_rounded,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberController,
              decoration: InputDecoration(
                labelText: _accountType == 'debit'
                    ? 'Last 4 Digits of Account Number'
                    : 'Last 4 Digits of Card Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter last 4 digits';
                if (v.length != 4) return 'Must be 4 digits';
                return null;
              },
            ),
            const SizedBox(height: 16),
            StyledTextField(
              controller: _accountHolderNameController,
              label: 'Name on Card',
              icon: Icons.person_rounded,
            ),
            if (!widget.isEditing && _accountType == 'debit') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _initialBalanceController,
                decoration: const InputDecoration(
                  labelText: 'Current Balance (Calculated as Income)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
            if (_accountType == 'credit') ...[
              const SizedBox(height: 16),
              StyledTextField(
                controller: _creditLimitController,
                label: 'Credit Limit',
                icon: Icons.credit_score_rounded,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _billingCycleDayController,
                decoration: const InputDecoration(
                  labelText: 'Billing Day of Month (1-28)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 2,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter billing day';
                  final day = int.tryParse(v);
                  if (day == null || day < 1 || day > 28)
                    return 'Must be between 1-28';
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _saveAccount,
          child: Text(widget.isEditing ? 'Save Changes' : 'Save Account'),
        ),
      ),
    );
  }
}
