import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

enum TransactionMode { expense, income, transfer }

class AddEditTransactionScreen extends StatefulWidget {
  final TransactionMode initialMode;
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

  const AddEditTransactionScreen({
    super.key,
    this.initialMode = TransactionMode.expense,
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
  });

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _expenseFormKey = GlobalKey<__TransactionFormState>();
  final _incomeFormKey = GlobalKey<__TransactionFormState>();
  final _transferFormKey = GlobalKey<__TransferFormState>();
  final _editFormKey = GlobalKey<__TransactionFormState>();

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _isEditing
          ? (widget.transaction!.type == 'expense' ? 0 : 1)
          : widget.initialMode.index,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    if (_isEditing) {
      _editFormKey.currentState?.save();
    } else {
      switch (_tabController.index) {
        case 0:
          _expenseFormKey.currentState?.save();
          break;
        case 1:
          _incomeFormKey.currentState?.save();
          break;
        case 2:
          _transferFormKey.currentState?.save();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Details' : 'New Transaction',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: _isEditing
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    splashBorderRadius: BorderRadius.circular(25),
                    tabs: const [
                      Tab(text: 'Expense'),
                      Tab(text: 'Income'),
                      Tab(text: 'Transfer'),
                    ],
                  ),
                ),
              ),
      ),
      body: SafeArea(
        child: _isEditing
            ? _TransactionForm(
                key: _editFormKey,
                mode: widget.transaction!.type == 'expense'
                    ? TransactionMode.expense
                    : TransactionMode.income,
                transaction: widget.transaction,
                widget: widget,
              )
            : TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _TransactionForm(
                    key: _expenseFormKey,
                    mode: TransactionMode.expense,
                    widget: widget,
                  ),
                  _TransactionForm(
                    key: _incomeFormKey,
                    mode: TransactionMode.income,
                    widget: widget,
                  ),
                  _TransferForm(key: _transferFormKey),
                ],
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Consumer<TransactionProvider>(
          builder: (context, txProvider, _) {
            return SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: txProvider.isSaving ? null : _saveTransaction,
                child: txProvider.isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Confirm Transaction',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TransferForm extends StatefulWidget {
  const _TransferForm({super.key});

  @override
  __TransferFormState createState() => __TransferFormState();
}

class __TransferFormState extends State<_TransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  Account? _fromAccount;
  Account? _toAccount;
  DateTime _selectedDate = DateTime.now();
  double? _creditDue;

  // --- Logic Methods (Unchanged) ---
  void save() async {
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
      currency: 'INR',
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
      currency: 'INR',
    );

    await txProvider.addTransfer(fromTransaction, toTransaction);
    if (mounted) Navigator.of(context).pop();
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
            child: _AmountInputHero(
              controller: _amountController,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          // Date Pill
          Center(
            child: _DatePill(selectedDate: _selectedDate, onTap: _pickDate),
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
                        _FunkyPickerTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: "From Account",
                          value: _fromAccount?.displayName,
                          onTap: () => _showAccountPicker(true),
                          isCompact: false,
                        ),
                        const SizedBox(height: 20),
                        _FunkyPickerTile(
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
                            color: Colors.black.withOpacity(0.1),
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
                          ).colorScheme.errorContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Outstanding Due: ₹${_creditDue!.toStringAsFixed(2)}',
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

                _FunkyTextField(
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

  // --- Logic Helpers (Unchanged) ---
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showAccountPicker(bool isFromAccount) {
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    final accounts = accountProvider.accounts;
    _showCustomAccountModal(context, accounts, (acc) {
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
}

class _TransactionForm extends StatefulWidget {
  final TransactionMode mode;
  final AddEditTransactionScreen? widget;
  final TransactionModel? transaction;

  const _TransactionForm({
    super.key,
    required this.mode,
    this.widget,
    this.transaction,
  });

  @override
  __TransactionFormState createState() => __TransactionFormState();
}

class __TransactionFormState extends State<_TransactionForm> {
  static const _platform = MethodChannel('com.example.wallzy/sms');

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  final List<Tag> _selectedTags = [];
  Person? _selectedPerson;
  bool _isLoan = false;
  String _loanSubtype = 'new'; // 'new' vs 'repayment'
  DateTime? _reminderDate;
  String? _selectedSubscriptionId;
  Account? _selectedAccount;
  bool _isDirty = false;
  final _nonCashPaymentMethods = ["Card", "UPI", "Net banking", "Other"];
  final _cashPaymentMethods = ["Cash", "Other"];

  // --- Icon Mappings ---
  static final Map<String, IconData> _categoryIcons = {
    'Food': Icons.fastfood_rounded,
    'Travel': Icons.flight_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'People': Icons.person_rounded,
    'Bills': Icons.receipt_long_rounded,
    'Entertainment': Icons.movie_rounded,
    'Grocery': Icons.local_grocery_store_rounded,
    'Transport': Icons.directions_car_rounded,
    'Health': Icons.medical_services_rounded,
    'Education': Icons.school_rounded,
    'Investment': Icons.trending_up_rounded,
    'Salary': Icons.attach_money_rounded,
    'Rent': Icons.home_rounded,
    'Utilities': Icons.lightbulb_rounded,
    'Insurance': Icons.security_rounded,
    'Tax': Icons.account_balance_rounded,
    'Others': Icons.category_rounded,
  };

  static final Map<String, IconData> _paymentMethodIcons = {
    'Cash': Icons.money_rounded,
    'UPI': Icons.qr_code_rounded,
    'Card': Icons.credit_card_rounded,
    'Net banking': Icons.account_balance_rounded,
    'Other': Icons.payment_rounded,
  };

  IconData _getCategoryIcon(String name) {
    return _categoryIcons[name] ?? Icons.category_outlined;
  }

  IconData _getMethodIcon(String name) {
    return _paymentMethodIcons[name] ?? Icons.payment_outlined;
  }

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    // [Logic for init state preserved exactly from original]
    if (_isEditing) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _descController.text = tx.description;
      _selectedCategory = tx.category;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedDate = tx.timestamp;
      _selectedTags.addAll(tx.tags ?? []);
      _selectedPerson = tx.people?.isNotEmpty == true ? tx.people!.first : null;
      _isLoan = tx.people?.isNotEmpty == true && tx.isCredit != null;
      _reminderDate = tx.reminderDate;
      _selectedSubscriptionId = tx.subscriptionId;
    } else if (widget.widget?.initialAmount != null) {
      _amountController.text =
          double.tryParse(widget.widget!.initialAmount!)?.toStringAsFixed(0) ??
          '';
      _selectedDate = widget.widget!.initialDate ?? DateTime.now();
      _selectedPaymentMethod = widget.widget!.initialPaymentMethod;
      if (widget.widget!.initialCategory != null) {
        final validCategories = widget.mode == TransactionMode.expense
            ? TransactionCategories.expense
            : TransactionCategories.income;
        if (validCategories.contains(widget.widget!.initialCategory)) {
          _selectedCategory = widget.widget!.initialCategory;
        }
      }

      // Default to "Others" if no category selected
      _selectedCategory ??= 'Others';
      if (widget.widget!.initialPayee != null &&
          widget.widget!.initialPayee!.isNotEmpty) {
        _descController.text = widget.widget!.initialPayee!;
      }
      if (widget.widget!.initialPerson != null) {
        _selectedPerson = widget.widget!.initialPerson;
      }
    }
    _initializeAccount();
    _amountController.addListener(_markAsDirty);
    _descController.addListener(_markAsDirty);
    _tagController.addListener(_markAsDirty);
  }

  // --- Logic Methods Preserved (Collapsed for brevity but functional) ---
  Future<void> _initializeAccount() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );
      Account? foundAccount;
      if (_isEditing) {
        if (widget.transaction?.accountId != null) {
          try {
            foundAccount = accountProvider.accounts.firstWhere(
              (acc) => acc.id == widget.transaction!.accountId,
            );
          } catch (_) {}
        }
      } else if (widget.widget!.initialAccountNumber != null &&
          widget.widget!.initialAccountNumber!.isNotEmpty) {
        foundAccount = await accountProvider.findOrCreateAccount(
          bankName: widget.widget!.initialBankName ?? 'Unknown Bank',
          accountNumber: widget.widget!.initialAccountNumber!,
        );
      } else {
        foundAccount = await accountProvider.getPrimaryAccount();
      }
      if (foundAccount != null) {
        if (!_isEditing) {
          final isCashAccount = foundAccount.bankName.toLowerCase() == 'cash';
          String? finalPaymentMethod = _selectedPaymentMethod;
          if (isCashAccount) {
            finalPaymentMethod = 'Cash';
          } else {
            if (finalPaymentMethod == null || finalPaymentMethod == 'Cash') {
              finalPaymentMethod = 'UPI';
            }
          }
          setState(() => _selectedPaymentMethod = finalPaymentMethod);
        }
        setState(() => _selectedAccount = foundAccount);
      }
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_markAsDirty);
    _descController.removeListener(_markAsDirty);
    _tagController.removeListener(_markAsDirty);
    _amountController.dispose();
    _descController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  bool _validateCustomFields() {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return false;
    }
    if (_selectedCategory == 'People' && _selectedPerson == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a person.')));
      return false;
    }
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method.')),
      );
      return false;
    }
    return true;
  }

  void save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || !_validateCustomFields()) return;
    setState(() => _isDirty = false);

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final peopleProvider = Provider.of<PeopleProvider>(context, listen: false);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    bool? isCreditForModel;
    if (_selectedCategory == 'People' && _isLoan) {
      isCreditForModel = (widget.mode == TransactionMode.expense);
    }
    final isCreditAccount = _selectedAccount?.accountType == 'credit';
    final purchaseType =
        (isCreditAccount && widget.mode == TransactionMode.expense)
        ? 'credit'
        : 'debit';

    // [Preserved Save Logic - Copy Paste from original to ensure functionality]
    if (_isEditing) {
      final updatedTransaction = widget.transaction!.copyWith(
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        tags: _selectedTags.isNotEmpty ? _selectedTags : [],
        people: _selectedPerson != null ? [_selectedPerson!] : [],
        isCredit: isCreditForModel,
        reminderDate: _reminderDate,
        subscriptionId: () => _selectedSubscriptionId,
        accountId: () => _selectedAccount?.id,
        purchaseType: purchaseType,
      );
      await txProvider.updateTransaction(updatedTransaction);

      // Update Person Debts
      if (_selectedPerson != null && _isLoan) {
        Person updatedPerson = _selectedPerson!;
        if (widget.mode == TransactionMode.expense) {
          // EXPENSE
          if (_loanSubtype == 'new') {
            // Loan Given -> They Owe Me (owesYou increases)
            updatedPerson = updatedPerson.copyWith(
              owesYou: updatedPerson.owesYou + amount,
            );
          } else {
            // Repayment -> I am paying back (youOwe decreases)
            double newYouOwe = updatedPerson.youOwe - amount;
            if (newYouOwe < 0) newYouOwe = 0;
            updatedPerson = updatedPerson.copyWith(youOwe: newYouOwe);
          }
        } else {
          // INCOME
          if (_loanSubtype == 'new') {
            // Loan Taken -> I Owe Them (youOwe increases)
            updatedPerson = updatedPerson.copyWith(
              youOwe: updatedPerson.youOwe + amount,
            );
          } else {
            // Repayment -> They are paying back (owesYou decreases)
            double newOwesYou = updatedPerson.owesYou - amount;
            if (newOwesYou < 0) newOwesYou = 0;
            updatedPerson = updatedPerson.copyWith(owesYou: newOwesYou);
          }
        }

        // --- SIMPLIFY DEBT (NET OFF) ---
        if (updatedPerson.owesYou > 0 && updatedPerson.youOwe > 0) {
          final overlap = updatedPerson.owesYou < updatedPerson.youOwe
              ? updatedPerson.owesYou
              : updatedPerson.youOwe;
          updatedPerson = updatedPerson.copyWith(
            owesYou: updatedPerson.owesYou - overlap,
            youOwe: updatedPerson.youOwe - overlap,
          );
        }

        await peopleProvider.updatePerson(updatedPerson);
      }
      if (widget.widget?.smsTransactionId != null) {
        try {
          _platform
              .invokeMethod('removePendingSmsTransaction', {
                'id': widget.widget!.smsTransactionId,
              })
              .timeout(const Duration(seconds: 1));
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final newTransaction = TransactionModel(
        transactionId: const Uuid().v4(),
        type: widget.mode == TransactionMode.expense ? 'expense' : 'income',
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
        people: _selectedPerson != null ? [_selectedPerson!] : null,
        isCredit: isCreditForModel,
        reminderDate: _reminderDate,
        subscriptionId: _selectedSubscriptionId,
        accountId: _selectedAccount?.id,
        currency: 'INR',
        purchaseType: purchaseType,
      );
      await txProvider.addTransaction(newTransaction);

      // Update Person Debts
      if (_selectedPerson != null && _isLoan) {
        Person updatedPerson = _selectedPerson!;
        if (widget.mode == TransactionMode.expense) {
          // EXPENSE
          if (_loanSubtype == 'new') {
            // Loan Given -> They Owe Me (owesYou increases)
            updatedPerson = updatedPerson.copyWith(
              owesYou: updatedPerson.owesYou + amount,
            );
          } else {
            // Repayment -> I am paying back (youOwe decreases)
            double newYouOwe = updatedPerson.youOwe - amount;
            if (newYouOwe < 0) newYouOwe = 0;
            updatedPerson = updatedPerson.copyWith(youOwe: newYouOwe);
          }
        } else {
          // INCOME
          if (_loanSubtype == 'new') {
            // Loan Taken -> I Owe Them (youOwe increases)
            updatedPerson = updatedPerson.copyWith(
              youOwe: updatedPerson.youOwe + amount,
            );
          } else {
            // Repayment -> They are paying back (owesYou decreases)
            double newOwesYou = updatedPerson.owesYou - amount;
            if (newOwesYou < 0) newOwesYou = 0;
            updatedPerson = updatedPerson.copyWith(owesYou: newOwesYou);
          }
        }

        // --- SIMPLIFY DEBT (NET OFF) ---
        if (updatedPerson.owesYou > 0 && updatedPerson.youOwe > 0) {
          final overlap = updatedPerson.owesYou < updatedPerson.youOwe
              ? updatedPerson.owesYou
              : updatedPerson.youOwe;
          updatedPerson = updatedPerson.copyWith(
            owesYou: updatedPerson.owesYou - overlap,
            youOwe: updatedPerson.youOwe - overlap,
          );
        }

        await peopleProvider.updatePerson(updatedPerson);
      }
      if (widget.widget?.smsTransactionId != null) {
        try {
          _platform
              .invokeMethod('removePendingSmsTransaction', {
                'id': widget.widget!.smsTransactionId,
              })
              .timeout(const Duration(seconds: 1));
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final heroColor = widget.mode == TransactionMode.expense
        ? appColors.expense
        : appColors.income;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, res) async {
        if (didPop) return;
        final bool shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // 1. HERO AMOUNT & DATE
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: _AmountInputHero(
                controller: _amountController,
                color: heroColor,
              ),
            ),

            // 2. DATE PILL
            Center(
              child: _DatePill(selectedDate: _selectedDate, onTap: _pickDate),
            ),

            const SizedBox(height: 24),

            // 3. FORM BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                children: [
                  // Category Card
                  _FunkyPickerTile(
                    icon: Icons.category_rounded,
                    label: "Category",
                    value: _selectedCategory,
                    onTap: _showCategoryPicker,
                    isError: _selectedCategory == null,
                  ),

                  // Conditional People Logic
                  if (_selectedCategory == 'People') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _FunkyPickerTile(
                            icon: Icons.person_rounded,
                            label: "Select Person",
                            value: _selectedPerson?.fullName,
                            onTap: _showPeopleModal,
                            isCompact: true,
                            isError: _selectedPerson == null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Track as Loan?",
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Switch.adaptive(
                                value: _isLoan,
                                onChanged: (v) => setState(() {
                                  _isLoan = v;
                                  _markAsDirty();
                                }),
                              ),
                            ],
                          ),
                          if (_isLoan) ...[
                            const SizedBox(height: 12),
                            // Loan Subtype Selection
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    title: Text(
                                      widget.mode == TransactionMode.expense
                                          ? "Loan Given"
                                          : "Loan Taken",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      widget.mode == TransactionMode.expense
                                          ? "They owe you"
                                          : "You owe them",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    value: 'new',
                                    groupValue: _loanSubtype,
                                    visualDensity: VisualDensity.compact,
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    onChanged: (val) => setState(() {
                                      _loanSubtype = val!;
                                      _markAsDirty();
                                    }),
                                  ),
                                  Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withOpacity(0.2),
                                  ),
                                  RadioListTile<String>(
                                    title: Text(
                                      "Repayment",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      widget.mode == TransactionMode.expense
                                          ? "Paying back what I owe"
                                          : "Collecting what they owe",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    value: 'repayment',
                                    groupValue: _loanSubtype,
                                    visualDensity: VisualDensity.compact,
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    onChanged: (val) => setState(() {
                                      _loanSubtype = val!;
                                      _markAsDirty();
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_isLoan) ...[
                              const SizedBox(height: 12),
                              _FunkyPickerTile(
                                icon: Icons.alarm_rounded,
                                label: "Reminder",
                                value: _reminderDate != null
                                    ? DateFormat('MMM d').format(_reminderDate!)
                                    : "Set Date",
                                onTap: _pickReminderDate,
                                isCompact: true,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Account & Method Split Pill
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                final provider = Provider.of<AccountProvider>(
                                  context,
                                  listen: false,
                                );
                                _showCustomAccountModal(
                                  context,
                                  provider.accounts,
                                  (acc) {
                                    setState(() {
                                      _selectedAccount = acc;
                                      final isCash =
                                          acc.bankName.toLowerCase() == 'cash';
                                      if (isCash) {
                                        _selectedPaymentMethod = 'Cash';
                                      } else if (_selectedPaymentMethod ==
                                              'Cash' ||
                                          _selectedPaymentMethod == null) {
                                        _selectedPaymentMethod = 'UPI';
                                      }
                                      _markAsDirty();
                                    });
                                  },
                                  selectedId: _selectedAccount?.id,
                                );
                              },
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "ACCOUNT",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedAccount?.displayName ?? "Select",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            color: Theme.of(context).dividerColor,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _showPaymentMethodPicker,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "METHOD",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedPaymentMethod ?? "Select",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  _FunkyTextField(
                    controller: _descController,
                    label: "Add a note...",
                    icon: Icons.edit_note_rounded,
                  ),

                  const SizedBox(height: 16),

                  // Tags
                  _buildTagsSection(context),

                  const SizedBox(height: 16),

                  // Subscription Link
                  if (widget.mode == TransactionMode.expense)
                    ExpansionTile(
                      title: const Text(
                        'Link Subscription',
                        style: TextStyle(fontSize: 14),
                      ),
                      leading: const Icon(Icons.link_rounded, size: 20),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      children: [
                        Consumer<SubscriptionProvider>(
                          builder: (context, subProvider, _) {
                            final sub = subProvider.subscriptions
                                .where((s) => s.id == _selectedSubscriptionId)
                                .firstOrNull;
                            return _FunkyPickerTile(
                              icon: Icons.autorenew_rounded,
                              label: "Select Subscription",
                              value: sub?.name,
                              onTap: () => _showSubscriptionPicker(
                                subProvider.subscriptions,
                              ),
                              isCompact: true,
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Modals (Preserved Logic, updated visuals) ---
  void _showCategoryPicker() async {
    final categories = widget.mode == TransactionMode.expense
        ? TransactionCategories.expense
        : TransactionCategories.income;
    final String? selected = await _showModernPickerSheet(
      context: context,
      title: 'Select Category',
      items: categories
          .map((c) => PickerItem(id: c, label: c, icon: _getCategoryIcon(c)))
          .toList(),
      selectedId: _selectedCategory,
    );
    if (selected != null) {
      setState(() {
        _selectedCategory = selected;
        if (selected != 'People') _selectedPerson = null;
        _markAsDirty();
      });
      if (selected == 'People') _showPeopleModal();
    }
  }

  void _showPaymentMethodPicker() async {
    final isCashAccount = _selectedAccount?.bankName.toLowerCase() == 'cash';
    final methods = isCashAccount
        ? _cashPaymentMethods
        : _nonCashPaymentMethods;
    final String? selected = await _showModernPickerSheet(
      context: context,
      title: 'Select Method',
      items: methods
          .map((m) => PickerItem(id: m, label: m, icon: _getMethodIcon(m)))
          .toList(),
      selectedId: _selectedPaymentMethod,
    );
    if (selected != null)
      setState(() {
        _selectedPaymentMethod = selected;
        _markAsDirty();
      });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (picked != null)
      setState(() {
        _selectedDate = picked;
        _markAsDirty();
      });
  }

  Future<void> _pickReminderDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _reminderDate ?? DateTime.now(),
    );
    if (picked != null)
      setState(() {
        _reminderDate = picked;
        _markAsDirty();
      });
  }

  // ... [Contact Picking & Tag Logic Preserved exactly as original] ...
  Future<bool> _pickContact() async {
    FocusScope.of(context).unfocus();
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      final fc.Contact? contact = await fc.FlutterContacts.openExternalPick();
      if (contact != null && mounted) {
        final peopleProvider = Provider.of<PeopleProvider>(
          context,
          listen: false,
        );
        final newPerson = await peopleProvider.addPerson(
          Person(
            id: '',
            fullName: contact.displayName,
            email: contact.emails.isNotEmpty
                ? contact.emails.first.address
                : null,
          ),
        );
        setState(() {
          _selectedPerson = newPerson;
          _markAsDirty();
        });
        return true;
      }
    }
    return false;
  }

  Future<void> _showPeopleModal() async {
    // [Logic preserved from original]
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = "";
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
              return Consumer<PeopleProvider>(
                builder: (context, peopleProvider, _) {
                  final people = peopleProvider.people;
                  final filtered = people
                      .where(
                        (p) => p.fullName.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList();
                  return Container(
                    padding: const EdgeInsets.all(16),
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Column(
                      children: [
                        Text(
                          'Select Person',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Search...",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.contacts),
                              onPressed: () async {
                                final picked = await _pickContact();
                                if (picked && mounted) Navigator.pop(ctx);
                              },
                            ),
                          ),
                          onChanged: (val) => setModalState(() => query = val),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length + 1,
                            itemBuilder: (listCtx, i) {
                              if (i < filtered.length) {
                                final person = filtered[i];
                                return ListTile(
                                  title: Text(person.fullName),
                                  onTap: () {
                                    setState(() {
                                      _selectedPerson = person;
                                      _markAsDirty();
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              } else if (query.isNotEmpty &&
                                  !people.any(
                                    (p) =>
                                        p.fullName.toLowerCase() ==
                                        query.toLowerCase(),
                                  )) {
                                return ListTile(
                                  title: Text("Add \"$query\""),
                                  leading: const Icon(Icons.add),
                                  onTap: () async {
                                    final newPerson = await peopleProvider
                                        .addPerson(
                                          Person(id: '', fullName: query),
                                        );
                                    setState(() {
                                      _selectedPerson = newPerson;
                                      _markAsDirty();
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showSubscriptionPicker(List<Subscription> subscriptions) {
    // [Logic preserved from original]
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create New'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSubscriptionScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ...subscriptions.map(
              (sub) => ListTile(
                title: Text(sub.name),
                onTap: () {
                  setState(() {
                    _selectedSubscriptionId = sub.id;
                    _markAsDirty();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('None'),
              onTap: () {
                setState(() {
                  _selectedSubscriptionId = null;
                  _markAsDirty();
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    return Consumer<MetaProvider>(
      builder: (ctx, metaProvider, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._selectedTags.map(
              (tag) => Chip(
                label: Text(tag.name),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(4),
                onDeleted: () => setState(() {
                  _selectedTags.remove(tag);
                  _markAsDirty();
                }),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add Tag'),
              onPressed: () => _showTagEditor(metaProvider),
            ),
          ],
        );
      },
    );
  }

  // Tag Editor & Unsaved Dialog logic preserved...
  void _showTagEditor(MetaProvider metaProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final suggestions = metaProvider.searchTags(_tagController.text);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tags', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _FunkyTextField(
                    controller: _tagController,
                    label: 'Tag name',
                    icon: Icons.label_outline,
                    onChanged: (v) => setModalState(() {}),
                    onFieldSubmitted: (v) {
                      if (v.isNotEmpty) {
                        _addTag(v);
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  if (_tagController.text.isNotEmpty)
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ...suggestions.map(
                            (tag) => ListTile(
                              title: Text(tag.name),
                              onTap: () {
                                _addTag(tag.name);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                          if (!suggestions.any(
                            (t) =>
                                t.name.toLowerCase() ==
                                _tagController.text.trim().toLowerCase(),
                          ))
                            ListTile(
                              leading: const Icon(Icons.add),
                              title: Text("Add \"${_tagController.text}\""),
                              onTap: () {
                                _addTag(_tagController.text.trim());
                                Navigator.pop(ctx);
                              },
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addTag(String tagName) async {
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final existing = metaProvider.tags.where(
      (t) => t.name.toLowerCase() == tagName.toLowerCase(),
    );
    Tag tagToAdd = existing.isNotEmpty
        ? existing.first
        : await metaProvider.addTag(tagName);
    setState(() {
      if (!_selectedTags.any((t) => t.id == tagToAdd.id)) {
        _selectedTags.add(tagToAdd);
        _markAsDirty();
      }
      _tagController.clear();
    });
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text('Unsaved changes will be lost.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        )) ??
        false;
  }
}

// --- VISUAL WIDGETS (THE FUNKY PARTS) ---

class _AmountInputHero extends StatelessWidget {
  final TextEditingController controller;
  final Color color;

  const _AmountInputHero({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.8),
                height: 1.2,
              ),
            ),
            const SizedBox(width: 4),
            IntrinsicWidth(
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) =>
                    v == null || v.isEmpty || double.tryParse(v) == 0
                    ? ''
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;

  const _DatePill({required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM d, yyyy').format(selectedDate),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunkyPickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isError;
  final bool isCompact;

  const _FunkyPickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isError = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: isError
              ? Border.all(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? "Select",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: value == null
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class _FunkyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const _FunkyTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.outline),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

class PickerItem {
  final String id;
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color? color;

  PickerItem({
    required this.id,
    required this.label,
    required this.icon,
    this.subtitle,
    this.color,
  });
}

Future<String?> _showModernPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerItem> items,
  String? selectedId,
  bool showCreateNew = false,
  VoidCallback? onCreateNew,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, controller) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (showCreateNew && onCreateNew != null)
                      IconButton.filledTonal(
                        onPressed: onCreateNew,
                        icon: const Icon(Icons.add),
                        tooltip: 'Create New',
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    controller: controller,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final isSelected = item.id == selectedId;
                      final baseColor =
                          item.color ?? Theme.of(context).colorScheme.primary;

                      return InkWell(
                        onTap: () => Navigator.pop(ctx, item.id),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? baseColor.withOpacity(0.15)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? baseColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? baseColor
                                      : Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: isSelected ? Colors.white : baseColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? baseColor
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? baseColor.withOpacity(0.8)
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showCustomAccountModal(
  BuildContext context,
  List<Account> accounts,
  Function(Account) onSelect, {
  String? selectedId,
}) async {
  final resultId = await _showModernPickerSheet(
    context: context,
    title: 'Select Account',
    showCreateNew: true,
    onCreateNew: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddEditAccountScreen()),
      );
    },
    items: accounts
        .map(
          (acc) => PickerItem(
            id: acc.id,
            label: acc.bankName,
            subtitle: acc.accountNumber,
            icon: acc.bankName.toLowerCase() == 'cash'
                ? Icons.payments_rounded
                : Icons.account_balance_rounded,
            color: acc.accountType == 'credit'
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        )
        .toList(),
    selectedId: selectedId,
  );

  if (resultId != null) {
    final acc = accounts.firstWhere((a) => a.id == resultId);
    onSelect(acc);
  }
}
