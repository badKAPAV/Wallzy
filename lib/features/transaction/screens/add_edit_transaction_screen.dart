import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
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
import 'package:wallzy/features/people/widgets/person_picker_sheet.dart';

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
  final bool initialIsLoan;
  final String initialLoanSubtype;

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
    this.initialIsLoan = false,
    this.initialLoanSubtype = 'new',
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
        backgroundColor: theme.colorScheme.surface,
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
                  shadowColor: theme.colorScheme.primary.withAlpha(100),
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
    if (mounted) Navigator.of(context).pop(true);
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
  static const _platform = MethodChannel('com.kapav.wallzy/sms');

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  Tag? _selectedFolder;
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

  bool _isLoadingAccount = true;

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
      _selectedFolder = tx.tags?.firstOrNull;
      _selectedPerson = tx.people?.isNotEmpty == true ? tx.people!.first : null;
      _isLoan = tx.people?.isNotEmpty == true && tx.isCredit != null;
      _reminderDate = tx.reminderDate;
      _selectedSubscriptionId = tx.subscriptionId;
    } else {
      // New Transaction
      final w = widget.widget;
      if (w != null) {
        if (w.initialAmount != null) {
          _amountController.text =
              double.tryParse(w.initialAmount!)?.toStringAsFixed(0) ?? '';
        }
        _selectedDate = w.initialDate ?? DateTime.now();
        _selectedPaymentMethod = w.initialPaymentMethod;

        if (w.initialCategory != null) {
          final validCategories = widget.mode == TransactionMode.expense
              ? TransactionCategories.expense
              : TransactionCategories.income;
          if (validCategories.contains(w.initialCategory)) {
            _selectedCategory = w.initialCategory;
          }
        }

        // Default to "Others" if no category selected
        _selectedCategory ??= 'Others';

        if (w.initialPayee != null && w.initialPayee!.isNotEmpty) {
          _descController.text = w.initialPayee!;
        }
        if (w.initialPerson != null) {
          _selectedPerson = w.initialPerson;
        }
        _isLoan = w.initialIsLoan;
        _loanSubtype = w.initialLoanSubtype;
      }
    }
    _initializeAccount();
    _amountController.addListener(_markAsDirty);
    _descController.addListener(_markAsDirty);
  }

  // --- Logic Methods Preserved (Collapsed for brevity but functional) ---
  Future<void> _initializeAccount() async {
    // Wait for frame to ensure context is available and providers are mounted
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );

      // 🔹 WAITING LOGIC: Wait for accounts to trigger load if empty
      // If accounts are empty, we poll briefly or wait for isLoading to flip.
      // Since we implemented cache-first, this should be fast.
      int retries = 0;
      while (accountProvider.accounts.isEmpty && retries < 20) {
        // Wait 100ms * 20 = 2 seconds max wait for initial cache hit
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        if (!mounted) return;
      }

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
        // If we still didn't find it in local list, try the findOrCreate (which checks cache/db)
        foundAccount = await accountProvider.findOrCreateAccount(
          bankName: widget.widget!.initialBankName ?? 'Unknown Bank',
          accountNumber: widget.widget!.initialAccountNumber!,
        );
      } else {
        foundAccount = await accountProvider.getPrimaryAccount();
      }

      if (mounted) {
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
        // STOP LOADING
        setState(() => _isLoadingAccount = false);
      }
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_markAsDirty);
    _descController.removeListener(_markAsDirty);
    _amountController.dispose();
    _descController.dispose();
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
        tags: _selectedFolder != null ? [_selectedFolder!] : [],
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
      Navigator.of(context).pop(true);
    } else {
      final newTransaction = TransactionModel(
        transactionId: const Uuid().v4(),
        type: widget.mode == TransactionMode.expense ? 'expense' : 'income',
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        tags: _selectedFolder != null ? [_selectedFolder!] : null,
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
      Navigator.pop(context, true);
    }
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccount) {
      return const Center(
        child: CircularProgressIndicator(strokeCap: StrokeCap.round),
      );
    }

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
                        ).colorScheme.primaryContainer.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(25),
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
                                  ).colorScheme.outlineVariant.withAlpha(80),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant.withAlpha(50),
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
                            // const SizedBox(height: 12),
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
                        ).colorScheme.outlineVariant.withAlpha(50),
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

                  // Folder
                  _FunkyPickerTile(
                    icon: Icons.folder_open_rounded,
                    label: "Folder",
                    value: _selectedFolder?.name,
                    onTap: _showFolderPicker,
                  ),

                  const SizedBox(height: 16),

                  // Subscription Link
                  if (widget.mode == TransactionMode.expense)
                    ExpansionTile(
                      title: const Text(
                        'Link a Recurring Payment',
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
                              label: "Select Recurring Payment",
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

  void _showPeopleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => PersonPickerSheet(
          selectedPerson: _selectedPerson,
          scrollController: scrollController,
          onSelected: (person) {
            setState(() {
              _selectedPerson = person;
              _markAsDirty();
            });
          },
        ),
      ),
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

  void _showFolderPicker() {
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _FolderPickerSheet(
          metaProvider: metaProvider,
          txProvider: txProvider,
          selectedFolder: _selectedFolder,
          scrollController: scrollController,
          onSelected: (tag) {
            setState(() {
              _selectedFolder = tag;
              _markAsDirty();
            });
          },
        ),
      ),
    );
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
                color: color.withAlpha(204),
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
  const _FunkyTextField({
    required this.controller,
    required this.label,
    required this.icon,
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
                                        ? baseColor.withAlpha(204)
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

class _FolderPickerSheet extends StatefulWidget {
  final MetaProvider metaProvider;
  final TransactionProvider txProvider;
  final Tag? selectedFolder;
  final ScrollController scrollController;
  final Function(Tag?) onSelected;

  const _FolderPickerSheet({
    required this.metaProvider,
    required this.txProvider,
    this.selectedFolder,
    required this.scrollController,
    required this.onSelected,
  });

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = widget.metaProvider.searchTags(_searchQuery);
    final mostUsed = widget.txProvider.getMostUsedTags(limit: 4);
    final recent = widget.txProvider.getRecentTags(limit: 4);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withAlpha(128),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Folder',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.selectedFolder != null)
                  TextButton.icon(
                    onPressed: () {
                      widget.onSelected(null);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text("Clear"),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search or create folder...",
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 10,
                      strokeWidth: 2,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _createAndSelect(v.trim());
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          Flexible(
            child: ListView(
              controller: widget.scrollController,
              shrinkWrap:
                  false, // Changed for DraggableScrollableSheet compatibility
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                if (_searchQuery.isEmpty) ...[
                  if (recent.isNotEmpty) ...[
                    _buildSectionHeader(theme, "RECENTLY USED"),
                    const SizedBox(height: 8),
                    _FolderChips(tags: recent, onTap: (t) => _selectAndPop(t)),
                    const SizedBox(height: 20),
                  ],
                  if (mostUsed.isNotEmpty) ...[
                    _buildSectionHeader(theme, "MOST USED"),
                    const SizedBox(height: 8),
                    _FolderChips(
                      tags: mostUsed,
                      onTap: (t) => _selectAndPop(t),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildSectionHeader(theme, "ALL FOLDERS"),
                  const SizedBox(height: 8),
                  if (widget.metaProvider.tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No folders created yet",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ...widget.metaProvider.tags.map(
                    (t) => _FolderListTile(
                      tag: t,
                      isSelected: widget.selectedFolder?.id == t.id,
                      onTap: () => _selectAndPop(t),
                    ),
                  ),
                ] else ...[
                  if (suggestions.isNotEmpty)
                    ...suggestions.map(
                      (t) => _FolderListTile(
                        tag: t,
                        onTap: () => _selectAndPop(t),
                      ),
                    ),
                  if (!suggestions.any(
                    (t) =>
                        t.name.toLowerCase() ==
                        _searchQuery.trim().toLowerCase(),
                  ))
                    ListTile(
                      leading: Icon(
                        Icons.add_circle_outline_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        "Create \"$_searchQuery\"",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => _createAndSelect(_searchQuery.trim()),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  void _selectAndPop(Tag tag) {
    widget.onSelected(tag);
    Navigator.pop(context);
  }

  void _createAndSelect(String name) async {
    final newTag = await widget.metaProvider.addTag(name);
    _selectAndPop(newTag);
  }
}

class _FolderChips extends StatelessWidget {
  final List<Tag> tags;
  final Function(Tag) onTap;

  const _FolderChips({required this.tags, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: tags.map((t) {
        final Color? tagColor = t.color != null ? Color(t.color!) : null;
        return ActionChip(
          avatar: Icon(
            Icons.auto_awesome,
            size: 14,
            color: tagColor ?? Theme.of(context).colorScheme.primary,
          ),
          label: Text(t.name),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: tagColor != null
                ? tagColor.withAlpha(230)
                : Theme.of(context).colorScheme.onSurface,
          ),
          padding: EdgeInsets.zero,
          backgroundColor: tagColor != null
              ? tagColor.withOpacity(0.08)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          side: tagColor != null
              ? BorderSide(color: tagColor.withAlpha(50))
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: () => onTap(t),
        );
      }).toList(),
    );
  }
}

class _FolderListTile extends StatelessWidget {
  final Tag tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderListTile({
    required this.tag,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? tagColor = tag.color != null ? Color(tag.color!) : null;
    return ListTile(
      leading: Icon(
        Icons.folder_rounded,
        color: isSelected
            ? (tagColor ?? theme.colorScheme.primary)
            : (tagColor?.withAlpha(179) ?? theme.colorScheme.outline),
        size: 20,
      ),
      title: Text(
        tag.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? (tagColor ?? theme.colorScheme.primary)
              : tagColor?.withAlpha(230),
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              color: tagColor ?? theme.colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}
