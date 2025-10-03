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
import 'package:wallzy/features/transaction/screens/styled_form_fields.dart';

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
  _AddEditTransactionScreenState createState() =>
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        bottom: _isEditing
            ? null
            : TabBar(
                unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(
                      fontWeight: FontWeight.normal,
                      // color: Theme.of(context).colorScheme.primary,
                    ),
                indicatorWeight: 5,
                indicator: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary, // indicator color
                  borderRadius: BorderRadius.circular(25), // rounded edges
                ),
                indicatorPadding: EdgeInsets.fromLTRB(0, 45, 0, 0),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                // controller: _tabController,
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withAlpha(150),
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Expense'),
                  Tab(text: 'Income'),
                  Tab(text: 'Transfer'),
                ],
              ),
      ),
      body: _isEditing
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<TransactionProvider>(
          builder: (context, txProvider, _) {
            return FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : Text(_isEditing ? 'Save Changes' : 'Add Transaction'),
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

  void save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // final appColors = Theme.of(context).extension<AppColors>()!;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: "0",
                      border: InputBorder.none,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty || double.tryParse(v) == 0) {
                        return "Enter amount";
                      }
                      if (_creditDue != null) {
                        final amount = double.tryParse(v);
                        if (amount != null && amount > _creditDue!) {
                          return 'Amount cannot be more than credit due.';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StyledPickerField(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'From Account',
                  value: _fromAccount?.displayName,
                  onTap: () => _showAccountPicker(true),
                ),
                const SizedBox(height: 16),
                StyledPickerField(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'To Account',
                  value: _toAccount?.displayName,
                  onTap: () => _showAccountPicker(false),
                ),
                if (_creditDue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                    child: Text(
                      'Credit Due: ₹${_creditDue!.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                StyledPickerField(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: DateFormat('d MMMM, yyyy').format(_selectedDate),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                StyledTextField(
                  controller: _descController,
                  label: 'Description (Optional)',
                  icon: Icons.notes_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAccountPicker(bool isFromAccount) {
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    final accounts = accountProvider.accounts;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Create New Account'),
              onTap: () {
                Navigator.pop(ctx); // Close the modal
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditAccountScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            if (accounts.isNotEmpty)
              ...accounts.map((acc) {
                final currentSelectedAccount =
                    isFromAccount ? _fromAccount : _toAccount;
                final isSelected = acc.id == currentSelectedAccount?.id;
                return ListTile(
                  title: Text(acc.displayName),
                  subtitle: Text(
                    acc.isPrimary
                        ? '${acc.accountType == 'debit' ? 'Debit' : 'Credit'} · Primary'
                        : acc.accountType == 'debit'
                            ? 'Debit'
                            : 'Credit',
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  tileColor: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.5)
                      : null,
                  onTap: () {
                    setState(() {
                      if (isFromAccount) {
                        _fromAccount = acc;
                      } else {
                        _toAccount = acc;
                        if (acc.accountType == 'credit') {
                          _creditDue = Provider.of<TransactionProvider>(context, listen: false).getCreditDue(acc.id);
                        } else {
                          _creditDue = null;
                        }
                      }
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
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
  // bool _isCredit = false;
  bool _isLoan = false;
  DateTime? _reminderDate;

  String? _selectedSubscriptionId;
  Account? _selectedAccount;
  // Account? _repaymentTargetAccount;

  bool _isDirty = false;

  final _nonCashPaymentMethods = ["Card", "UPI", "Net banking", "Other"];
  final _cashPaymentMethods = ["Cash", "Other"];

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _descController.text = tx.description;
      _selectedCategory = tx.category;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedDate = tx.timestamp;
      _selectedTags.addAll(tx.tags ?? []);
      _selectedPerson = tx.people?.isNotEmpty == true ? tx.people!.first : null;
      // A transaction with a person and a non-null isCredit value is considered a loan.
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
          } catch (e) {
            // The account associated with the transaction might have been deleted.
            // In this case, `foundAccount` will remain null and the user will have to select a new one.
          }
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

        setState(() {
          _selectedAccount = foundAccount;
        });
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
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
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

    if (!_formKey.currentState!.validate() || !_validateCustomFields()) {
      return;
    }

    setState(() {
      _isDirty = false;
    });

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final peopleProvider = Provider.of<PeopleProvider>(context, listen: false);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    // Determine the value for the 'isCredit' field in the model.
    // null = not a loan, true = person owes user, false = user owes person.
    bool? isCreditForModel;
    if (_selectedCategory == 'People' && _isLoan) {
      // If it's an expense, it's a "credit" for the user (person owes them).
      isCreditForModel = (widget.mode == TransactionMode.expense);
    }

    final isCreditAccount = _selectedAccount?.accountType == 'credit';
    final purchaseType =
        (isCreditAccount && widget.mode == TransactionMode.expense)
        ? 'credit'
        : 'debit';

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
      // Update person's owe/owesYou
      // WARNING: This logic is flawed for edits as it doesn't calculate the delta
      // from the original amount. It's kept consistent with the old buggy behavior
      // to avoid unintended side-effects. A proper fix would require more state.
      if (_selectedPerson != null && _isLoan) {
        Person updatedPerson = _selectedPerson!;
        if (isCreditForModel == true) { // Person owes user
          updatedPerson = updatedPerson.copyWith(
              owesYou: (updatedPerson.owesYou ?? 0) + amount);
        } else if (isCreditForModel == false) { // User owes person
          updatedPerson = updatedPerson.copyWith(
              youOwe: (updatedPerson.youOwe ?? 0) + amount);
        }
        await peopleProvider.updatePerson(updatedPerson);
      }
      if (widget.widget?.smsTransactionId != null) {
        try {
          await _platform.invokeMethod('removePendingSmsTransaction', {'id': widget.widget!.smsTransactionId});
        } on PlatformException catch (e) {
          debugPrint("Failed to remove pending SMS transaction: '${e.message}'.");
        }
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
      // Update person's owe/owesYou
      if (_selectedPerson != null && _isLoan) {
        Person updatedPerson = _selectedPerson!;
        if (isCreditForModel == true) { // Person owes user
          updatedPerson = updatedPerson.copyWith(
              owesYou: (updatedPerson.owesYou ?? 0) + amount);
        } else if (isCreditForModel == false) { // User owes person
          updatedPerson = updatedPerson.copyWith(
              youOwe: (updatedPerson.youOwe ?? 0) + amount);
        }
        await peopleProvider.updatePerson(updatedPerson);
      }
      if (widget.widget?.smsTransactionId != null) {
        try {
          await _platform.invokeMethod('removePendingSmsTransaction', {'id': widget.widget!.smsTransactionId});
        } on PlatformException catch (e) {
          debugPrint("Failed to remove pending SMS transaction: '${e.message}'.");
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _showCategoryPicker() async {
    final categories = widget.mode == TransactionMode.expense
        ? TransactionCategories.expense
        : TransactionCategories.income;
    final String? selected = await _showCustomModalSheet(
      context: context,
      title: 'Select Category',
      items: categories,
      selectedValue: _selectedCategory,
    );

    if (selected != null) {
      setState(() {
        _selectedCategory = selected;
        if (selected != 'People') {
          _selectedPerson = null;
        }
        _markAsDirty();
      });
      if (selected == 'People') {
        _showPeopleModal();
      }
    }
  }

  // Returns true if a contact was picked and a person was created.
  Future<bool> _pickContact() async {
    // Hide keyboard before opening picker
    FocusScope.of(context).unfocus();

    final status = await Permission.contacts.request();

    if (status.isGranted) {
      final fc.Contact? contact = await fc.FlutterContacts.openExternalPick();

      if (contact != null) {
        if (!mounted) return false;
        final peopleProvider =
            Provider.of<PeopleProvider>(context, listen: false);
        final newPerson = await peopleProvider.addPerson(Person(
          id: '',
          fullName: contact.displayName,
          email:
              contact.emails.isNotEmpty ? contact.emails.first.address : null,
        ));
        setState(() {
          _selectedPerson = newPerson;
          _markAsDirty();
        });
        return true;
      }
    } else if (status.isDenied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact permission was denied.')),
      );
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Contact permission permanently denied. Please enable it in settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }
    return false;
  }

  void _showPaymentMethodPicker() async {
    final isCashAccount = _selectedAccount?.bankName.toLowerCase() == 'cash';
    final methodsToShow =
        isCashAccount ? _cashPaymentMethods : _nonCashPaymentMethods;
    final String? selected = await _showCustomModalSheet(
      context: context,
      title: 'Select Payment Method',
      items: methodsToShow,
      selectedValue: _selectedPaymentMethod,
    );
    if (selected != null) {
      setState(() {
        _selectedPaymentMethod = selected;
        _markAsDirty();
      });
    }
  }

  Future<void> _showPeopleModal() async {
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
                            hintText: "Search or add people...",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.contact_phone_rounded),
                              tooltip: 'Import from contacts',
                              onPressed: () async {
                                final picked = await _pickContact();
                                if (picked && mounted) {
                                  Navigator.pop(ctx);
                                }
                              },
                            ),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              query = val;
                            });
                          },
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length + 1,
                            itemBuilder: (listCtx, i) {
                              if (i < filtered.length) {
                                final person = filtered[i];
                                final isSelected =
                                    _selectedPerson?.id == person.id;
                                return ListTile(
                                  title: Text(person.fullName),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        )
                                      : null,
                                  tileColor: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withAlpha(125)
                                      : null,
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
                                    final newPerson =
                                        await peopleProvider.addPerson(
                                            Person(id: '', fullName: query));
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _markAsDirty();
      });
    }
  }

  Future<void> _pickReminderDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _reminderDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _reminderDate = picked;
        _markAsDirty();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, res) async {
        if (didPop) {
          return;
        }
        final bool shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: widget.mode == TransactionMode.expense
                          ? appColors.expense
                          : appColors.income,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      autofocus: widget.widget?.initialAmount == null,
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: "0",
                        border: InputBorder.none,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty || double.tryParse(v) == 0
                              ? "Enter amount"
                              : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  StyledTextField(
                    controller: _descController,
                    label: 'Add a description',
                    icon: Icons.notes_rounded,
                  ),
                  const SizedBox(height: 16),
                  StyledPickerField(
                    icon: Icons.category_rounded,
                    label: 'Select a category',
                    value: _selectedCategory,
                    onTap: _showCategoryPicker,
                  ),

                  if (_selectedCategory == 'People') ...[
                    const SizedBox(height: 16),
                    StyledPickerField(
                      icon: Icons.person_rounded,
                      label: 'Select a person',
                      value: _selectedPerson?.fullName,
                      onTap: _showPeopleModal,
                      isError: _selectedPerson == null,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      title: const Text('Track as a loan'),
                      subtitle: Text(
                        widget.mode == TransactionMode.expense
                            ? 'The selected person will owe you this amount.'
                            : 'You will owe the selected person this amount.',
                      ),
                      value: _isLoan,
                      onChanged: (value) {
                        setState(() {
                          _isLoan = value;
                          _markAsDirty();
                        });
                      },
                      tileColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(height: 16),
                    StyledPickerField(
                      icon: Icons.calendar_today_rounded,
                      label: 'Reminder Date (Optional)',
                      value: _reminderDate != null
                          ? DateFormat('d MMMM, yyyy').format(_reminderDate!)
                          : 'None',
                      onTap: _pickReminderDate,
                    ),
                  ],
                  const SizedBox(height: 16),
                  StyledPickerField(
                    icon: Icons.credit_card_rounded,
                    label: 'Payment Method',
                    value: _selectedPaymentMethod,
                    onTap: _showPaymentMethodPicker,
                  ),
                  const SizedBox(height: 16),
                  StyledPickerField(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: DateFormat('d MMMM, yyyy').format(_selectedDate),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 16),
                  _buildAccountSection(),
                  const SizedBox(height: 16),
                  _buildSubscriptionSection(),
                  widget.mode == TransactionMode.expense
                      ? const SizedBox(height: 16)
                      : const SizedBox.shrink(),
                  _buildTagsSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Consumer<AccountProvider>(
      builder: (context, accountProvider, _) {
        return StyledPickerField(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Account',
          value: _selectedAccount?.bankName,
          onTap: () => _showAccountPicker(accountProvider.accounts),
          isError: _selectedAccount == null,
        );
      },
    );
  }

  void _showAccountPicker(List<Account> accounts) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Create New Account'),
              onTap: () {
                Navigator.pop(ctx); // Close the modal
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditAccountScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            if (accounts.isNotEmpty)
              ...accounts.map((acc) {
                final isSelected = acc.id == _selectedAccount?.id;
                return ListTile(
                  title: Text(
                    '${acc.bankName} ${acc.bankName == 'Cash' ? '' : '·'} ${acc.accountNumber}',
                  ),
                  subtitle: Text(
                    acc.isPrimary
                        ? '${acc.accountType == 'debit' ? 'Debit' : 'Credit'} · Primary'
                        : acc.accountType == 'debit'
                        ? 'Debit'
                        : 'Credit',
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  tileColor: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.5)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedAccount = acc;
                      final isCashAccount =
                          acc.bankName.toLowerCase() == 'cash';
                      if (isCashAccount) {
                        _selectedPaymentMethod = 'Cash';
                      } else {
                        if (_selectedPaymentMethod == 'Cash' ||
                            _selectedPaymentMethod == null) {
                          _selectedPaymentMethod = 'UPI';
                        }
                      }
                      _markAsDirty();
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    if (widget.mode != TransactionMode.expense) return const SizedBox.shrink();

    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, child) {
        final subscriptions = subProvider.subscriptions;
        final selectedSub = subscriptions
            .where((s) => s.id == _selectedSubscriptionId)
            .firstOrNull;

        return StyledPickerField(
          icon: Icons.sync_alt_rounded,
          label: 'Link to a subscription',
          value: selectedSub?.name,
          onTap: () => _showSubscriptionPicker(subscriptions),
        );
      },
    );
  }

  void _showSubscriptionPicker(List<Subscription> subscriptions) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Create New Subscription'),
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
            if (subscriptions.isNotEmpty)
              ...subscriptions.map((sub) {
                final isSelected = sub.id == _selectedSubscriptionId;
                return ListTile(
                  title: Text(sub.name),
                  subtitle: Text(
                    '₹${sub.amount.toStringAsFixed(0)} / ${sub.frequency.name}',
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  tileColor: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.5)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedSubscriptionId = sub.id;
                      _markAsDirty();
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link_off_rounded),
              title: const Text('None (Not a subscription)'),
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
        final suggestions = metaProvider.searchTags(_tagController.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StyledTextField(
              controller: _tagController,
              label: 'Tags',
              icon: Icons.label_rounded,
              onFieldSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _addTag(val.trim());
                }
              },
              onChanged: (val) => setState(() {}),
            ),
            if (_tagController.text.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView(
                  children: [
                    ...suggestions.map(
                      (tag) => ListTile(
                        title: Text(tag.name),
                        onTap: () => _addTag(tag.name),
                      ),
                    ),
                    if (!suggestions.any(
                      (t) =>
                          t.name.toLowerCase() ==
                          _tagController.text.trim().toLowerCase(),
                    ))
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: Text("Add ${_tagController.text.trim()}"),
                        onTap: () => _addTag(_tagController.text.trim()),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedTags
                  .map(
                    (tag) => Chip(
                      label: Text(tag.name),
                      onDeleted: () {
                        setState(() {
                          _selectedTags.remove(tag);
                          _markAsDirty();
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  void _addTag(String tagName) async {
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final existing = metaProvider.tags.where(
      (t) => t.name.toLowerCase() == tagName.toLowerCase(),
    );
    Tag tagToAdd;
    if (existing.isNotEmpty) {
      tagToAdd = existing.first;
    } else {
      tagToAdd = await metaProvider.addTag(tagName);
    }
    setState(() {
      if (!_selectedTags.any((t) => t.id == tagToAdd.id)) {
        _selectedTags.add(tagToAdd);
        _markAsDirty();
      }
      _tagController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
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
    );
    return shouldPop ?? false;
  }
}

Future<String?> _showCustomModalSheet({
  required BuildContext context,
  required String title,
  required List<String> items,
  String? selectedValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  height: 6,
                  width: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final isSelected = item == selectedValue;
                    return ListTile(
                      title: Text(item),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      tileColor: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.5)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx, item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
