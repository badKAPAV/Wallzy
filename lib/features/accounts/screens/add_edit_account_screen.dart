import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/transaction/screens/add_transaction_screen.dart'; // For StyledTextField

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

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _bankNameController.text = widget.account!.bankName;
      _accountNumberController.text = widget.account!.accountNumber;
      _accountHolderNameController.text = widget.account!.accountHolderName;
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user!.uid;

    if (widget.isEditing) {
      final updatedAccount = widget.account!.copyWith(
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountHolderName: _accountHolderNameController.text.trim(),
      );
      await accountProvider.updateAccount(updatedAccount);
    } else {
      final newAccount = Account(
        id: const Uuid().v4(), // This is just for local, Firestore will generate its own
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountHolderName: _accountHolderNameController.text.trim(),
        userId: userId,
      );
      await accountProvider.addAccount(newAccount);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
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
            StyledTextField(
              controller: _bankNameController,
              label: 'Bank Name (e.g., HDFC, SBI)',
              icon: Icons.account_balance_rounded,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberController,
              decoration: const InputDecoration(
                labelText: 'Last 4 Digits of Account Number',
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
              label: 'Account Holder Name',
              icon: Icons.person_rounded,
            ),
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