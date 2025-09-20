import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:wallzy/features/transaction/models/person.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final bool isExpense;
  final TransactionModel? transaction;
  final String? initialAmount;
  final DateTime? initialDate;
  final String? smsTransactionId;
  final String? initialPaymentMethod;
  final String? initialBankName;
  final String? initialAccountNumber;
  final String? initialPayee;
  final String? initialCategory;

  const AddTransactionScreen({
    Key? key,
    required this.isExpense,
    this.transaction,
    this.initialAmount,
    this.initialDate,
    this.smsTransactionId,
    this.initialPaymentMethod,
    this.initialBankName,
    this.initialAccountNumber,
    this.initialPayee,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  static const _platform = MethodChannel('com.example.wallzy/sms');

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  final List<Tag> _selectedTags = [];
  Person? _selectedPerson;

  // New state for linking subscriptions
  String? _selectedSubscriptionId;
  String? _selectedAccountId;

  // ADDED: State variable to track if the form has been modified.
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
      _selectedSubscriptionId = tx.subscriptionId;
      _selectedAccountId = tx.accountId;
    } else if (widget.initialAmount != null) {
      // This block is for new transactions, especially from SMS
      _amountController.text =
          double.tryParse(widget.initialAmount!)?.toStringAsFixed(0) ?? '';
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedPaymentMethod = widget.initialPaymentMethod;

      // Pre-fill category if it's valid for the transaction type
      if (widget.initialCategory != null) {
        final validCategories = widget.isExpense
            ? TransactionCategories.expense
            : TransactionCategories.income;
        if (validCategories.contains(widget.initialCategory)) {
          _selectedCategory = widget.initialCategory;
        }
      }

      // Pre-fill description with payee/merchant name if available
      if (widget.initialPayee != null) {
        _descController.text = widget.initialPayee!;
      }

      // Append bank and account info to description
      String extraInfo = '';
      if (widget.initialBankName != null) extraInfo += widget.initialBankName!;
      if (widget.initialAccountNumber != null) extraInfo += ' (${widget.initialAccountNumber})';
      if (extraInfo.isNotEmpty && _descController.text.isEmpty) {
        _descController.text = extraInfo.trim();
      }
      // Initialize account
      _initializeAccount();
    } else {
      // This is a manual new transaction, default to primary account
      _initializeAccount();
    }

    // ADDED: Listeners to detect changes in text fields.
    _amountController.addListener(_markAsDirty);
    _descController.addListener(_markAsDirty);
    _tagController.addListener(_markAsDirty);
  }

  Future<void> _initializeAccount() async {
    // This needs to be called from initState for SMS-based transactions.
    // It needs access to a provider, so we do it in a post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);
      String? accountId;

      // Rule 2: If account number is detected, use it to find/create an account.
      if (widget.initialAccountNumber != null && widget.initialAccountNumber!.isNotEmpty) {
        accountId = await accountProvider.findOrCreateAccount(
          bankName: widget.initialBankName ?? 'Unknown Bank', // Bank name is secondary
          accountNumber: widget.initialAccountNumber!,
        );
      } else {
        // Rule 1 & 3: If only bank name or no details are detected, default to primary.
        final primary = accountProvider.primaryAccount;
        if (primary != null) {
          accountId = primary.id;
        } else {
          // Fallback if no primary account is set (e.g., only Cash exists)
          try {
            accountId = accountProvider.accounts
                .firstWhere((acc) => acc.bankName.toLowerCase() == 'cash').id;
          } catch (e) {
            // This case is rare, means no accounts exist at all.
          }
        }
      }

      if (accountId != null) {
        final selectedAccount = accountProvider.accounts.firstWhere((acc) => acc.id == accountId);
        final isCashAccount = selectedAccount.bankName.toLowerCase() == 'cash';
        String? finalPaymentMethod = _selectedPaymentMethod; // from initState

        if (isCashAccount) {
          finalPaymentMethod = 'Cash';
        } else {
          // If current payment method is null (no SMS) or 'Cash' (invalid for bank), default to UPI.
          if (finalPaymentMethod == null || finalPaymentMethod == 'Cash') {
            finalPaymentMethod = 'UPI';
          }
        }
        
        setState(() {
          _selectedAccountId = accountId;
          _selectedPaymentMethod = finalPaymentMethod;
        });
      }
    });
  }

  @override
  void dispose() {
    // ADDED: Remove listeners to prevent memory leaks.
    _amountController.removeListener(_markAsDirty);
    _descController.removeListener(_markAsDirty);
    _tagController.removeListener(_markAsDirty);
    
    _amountController.dispose();
    _descController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ADDED: A helper method to set the dirty flag.
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
          const SnackBar(content: Text('Please select a category.')));
      return false;
    }
    if (_selectedCategory == 'People' && _selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a person.')));
      return false;
    }
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a payment method.')));
      return false;
    }
    return true;
  }

  Future<void> _saveTransaction() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || !_validateCustomFields()) {
      return;
    }
    
    // ADDED: Set dirty flag to false before leaving the screen, so PopScope doesn't trigger again.
    setState(() {
      _isDirty = false;
    });

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (_isEditing) {
      final updatedTransaction = widget.transaction!.copyWith(
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        tags: _selectedTags.isNotEmpty ? _selectedTags : [],
        people: _selectedPerson != null ? [_selectedPerson!] : [],
        subscriptionId: () => _selectedSubscriptionId,
        accountId: () => _selectedAccountId,
      );
      await txProvider.updateTransaction(updatedTransaction);
      if (widget.smsTransactionId != null) {
        await _platform.invokeMethod(
            'removePendingSmsTransaction', {'id': widget.smsTransactionId});
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final newTransaction = TransactionModel(
        transactionId: const Uuid().v4(),
        type: widget.isExpense ? 'expense' : 'income',
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
        people: _selectedPerson != null ? [_selectedPerson!] : null,
        subscriptionId: _selectedSubscriptionId,
        accountId: _selectedAccountId,
        currency: 'INR',
      );

      await txProvider.addTransaction(newTransaction);
      if (widget.smsTransactionId != null) {
        await _platform.invokeMethod(
            'removePendingSmsTransaction', {'id': widget.smsTransactionId});
      }
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _showCategoryPicker() async {
    final categories =
        widget.isExpense ? TransactionCategories.expense : TransactionCategories.income;
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
        // MODIFIED: Mark form as dirty on change
        _markAsDirty();
      });
      if (selected == 'People') {
        _showPeopleModal();
      }
    }
  }

  void _showPaymentMethodPicker() async {
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    Account? selectedAccount;
    try {
      if (_selectedAccountId != null) {
        selectedAccount = accountProvider.accounts.firstWhere((acc) => acc.id == _selectedAccountId);
      }
    } catch (e) {
      // Account not found, proceed with default (non-cash)
    }

    final isCashAccount = selectedAccount?.bankName.toLowerCase() == 'cash';

    final methodsToShow = isCashAccount ? _cashPaymentMethods : _nonCashPaymentMethods;

    final String? selected = await _showCustomModalSheet(
      context: context,
      title: 'Select Payment Method',
      items: methodsToShow,
      selectedValue: _selectedPaymentMethod,
    );

    if (selected != null) {
      // MODIFIED: Mark form as dirty on change
      setState(() {
        _selectedPaymentMethod = selected;
        _markAsDirty();
      });
    }
  }

  Future<void> _showPeopleModal() async {
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final people = metaProvider.people;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = "";
        List<Person> filtered = people;

        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
              return Container(
                padding: const EdgeInsets.all(16),
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Text('Select Person',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                          hintText: "Search or add people...",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (val) {
                        setModalState(() {
                          query = val;
                          filtered = people
                              .where((p) => p.name
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i < filtered.length) {
                            final person = filtered[i];
                            final isSelected = _selectedPerson?.id == person.id;
                            return ListTile(
                              title: Text(person.name),
                              trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                              tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                              onTap: () {
                                // MODIFIED: Mark form as dirty on change
                                setState(() {
                                  _selectedPerson = person;
                                  _markAsDirty();
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          } else if (query.isNotEmpty &&
                              !people.any((p) =>
                                  p.name.toLowerCase() ==
                                  query.toLowerCase())) {
                            return ListTile(
                              title: Text("Add \"$query\""),
                              leading: const Icon(Icons.add),
                              onTap: () async {
                                final newPerson =
                                    await metaProvider.addPerson(query);
                                // MODIFIED: Mark form as dirty on change
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
      // MODIFIED: Mark form as dirty on change
      setState(() {
        _selectedDate = picked;
        _markAsDirty();
      });
    }
  }

  // ADDED: New method to show the confirmation dialog.
  Future<bool> _showUnsavedChangesDialog() async {
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
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

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    // MODIFIED: Wrapped Scaffold with PopScope
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? "Edit Transaction" : "New Transaction"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('₹',
                          style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold, color: widget.isExpense ? appColors.expense : appColors.income)),
                      const SizedBox(width: 8),
                      IntrinsicWidth(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          autofocus: widget.initialAmount == null,
                          style: const TextStyle(
                              fontSize: 52, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                              hintText: "0", border: InputBorder.none),
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
                          value: _selectedPerson?.name,
                          onTap: _showPeopleModal,
                          isError: _selectedPerson == null,
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
                      // New Account Picker
                      _buildAccountSection(),
                      const SizedBox(height: 16),
                      _buildSubscriptionSection(),
                      widget.isExpense ? const SizedBox(height: 16) : const SizedBox.shrink(),
                      _buildTagsSection(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Consumer<TransactionProvider>(builder: (context, txProvider, _) {
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
          }),
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Consumer<AccountProvider>(
      builder: (context, accountProvider, child) {
        final accounts = accountProvider.accounts;
        final selectedAccount = accounts
            .where((acc) => acc.id == _selectedAccountId)
            .firstOrNull;

        return StyledPickerField(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Account',
          value: selectedAccount?.bankName,
          onTap: () => _showAccountPicker(accounts),
          isError: _selectedAccountId == null,
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
              child: Text('Select Account', style: Theme.of(context).textTheme.titleLarge),
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
              ...accounts.map(
                (acc) {
                  final isSelected = acc.id == _selectedAccountId;
                  return ListTile(
                    title: Text(acc.bankName),
                    subtitle: Text(acc.isPrimary ? '${acc.accountHolderName} · Primary' : acc.accountHolderName),
                    trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                    tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                    onTap: () {
                      setState(() {
                        _selectedAccountId = acc.id;
                        final isCashAccount = acc.bankName.toLowerCase() == 'cash';
                        if (isCashAccount) {
                          _selectedPaymentMethod = 'Cash';
                        } else {
                          if (_selectedPaymentMethod == 'Cash' || _selectedPaymentMethod == null) {
                            _selectedPaymentMethod = 'UPI';
                          }
                        }
                        _markAsDirty();
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    if (!widget.isExpense) return const SizedBox.shrink();

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
                        builder: (_) => const AddSubscriptionScreen()));
              },
            ),
            const Divider(),
            if (subscriptions.isNotEmpty)
              ...subscriptions.map(
                (sub) {
                  final isSelected = sub.id == _selectedSubscriptionId;
                  return ListTile(
                    title: Text(sub.name),
                    subtitle: Text(
                        '₹${sub.amount.toStringAsFixed(0)} / ${sub.frequency.name}'),
                    trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                    tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                    onTap: () {
                      setState(() {
                        _selectedSubscriptionId = sub.id;
                        _markAsDirty();
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
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
                    if (!suggestions.any((t) =>
                        t.name.toLowerCase() ==
                        _tagController.text.trim().toLowerCase()))
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: Text("Add \"${_tagController.text.trim()}\""),
                        onTap: () => _addTag(_tagController.text.trim()),
                      )
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedTags
                  .map((tag) => Chip(
                        label: Text(tag.name),
                        onDeleted: () {
                          // MODIFIED: Mark form as dirty on change
                          setState(() {
                            _selectedTags.remove(tag);
                            _markAsDirty();
                          });
                        },
                      ))
                  .toList(),
            )
          ],
        );
      },
    );
  }

  void _addTag(String tagName) async {
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final existing = metaProvider.tags
        .where((t) => t.name.toLowerCase() == tagName.toLowerCase());
    Tag tagToAdd;
    if (existing.isNotEmpty) {
      tagToAdd = existing.first;
    } else {
      tagToAdd = await metaProvider.addTag(tagName);
    }
    // MODIFIED: Mark form as dirty on change
    setState(() {
      if (!_selectedTags.any((t) => t.id == tagToAdd.id)) {
        _selectedTags.add(tagToAdd);
        _markAsDirty();
      }
      _tagController.clear();
      FocusScope.of(context).unfocus();
    });
  }
}

// ... (No changes needed for StyledTextField, StyledPickerField, or _showCustomModalSheet)
// ... (Your existing code for these widgets is perfect)

class StyledTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Function(String)? onFieldSubmitted;
  final Function(String)? onChanged;

  const StyledTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    this.onFieldSubmitted,
    this.onChanged,
  }) : super(key: key);

  @override
  State<StyledTextField> createState() => _StyledTextFieldState();
}

class _StyledTextFieldState extends State<StyledTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _isFocused? Theme.of(context).colorScheme.surfaceBright : Theme.of(context).colorScheme.surface,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        onFieldSubmitted: widget.onFieldSubmitted,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class StyledPickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isError;

  const StyledPickerField({
    Key? key,
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
    this.isError = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValue = value != null;

    Color displayColor;
    if (isError && value == null) {
      displayColor = colorScheme.error;
    } else if (hasValue) {
      displayColor = colorScheme.onSurface;
    } else {
      displayColor = colorScheme.onSurfaceVariant;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isError && value == null ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  fontSize: 16,
                  color: displayColor,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
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
              const SizedBox(height: 16,),
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
              const SizedBox(height: 16,),
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
                      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                      tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
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