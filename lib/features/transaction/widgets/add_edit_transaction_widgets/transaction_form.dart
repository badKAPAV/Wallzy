import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/currency_convert/widgets/currency_convert_modal_sheet.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/people/widgets/person_picker_sheet.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/services/receipt_service.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';
import 'package:wallzy/features/transaction/widgets/add_receipt_modal_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

class TransactionForm extends StatefulWidget {
  final TransactionMode mode;
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

  const TransactionForm({
    super.key,
    required this.mode,
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
  TransactionFormState createState() => TransactionFormState();
}

class TransactionFormState extends State<TransactionForm> {
  static const _platform = MethodChannel('com.kapav.wallzy/sms');

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  // Core Fields
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Account? _selectedAccount;

  // Conditional Fields
  Person? _selectedPerson;
  bool _isLoan = false;
  String _loanSubtype = 'new'; // 'new' vs 'repayment'

  // Power Fields (Hidden by default)
  List<Tag> _selectedFolders = [];
  String? _selectedSubscriptionId;
  DateTime? _reminderDate;
  Uint8List? _newReceiptData;
  String? _existingReceiptUrl;
  bool _isDeletingReceipt = false;

  // View State for Power Fields
  bool _showFolders = false;
  bool _showSubscription = false;
  bool _showReceipt = false;

  bool _isDirty = false;
  bool _isLoadingAccount = true;

  // Lists
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
    _initializeData();
    _initializeAccount();
    _checkAutoAddFolders();
    _amountController.addListener(_markAsDirty);
    _descController.addListener(_markAsDirty);
  }

  void _initializeData() {
    if (_isEditing) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _descController.text = tx.description;
      _selectedCategory = tx.category;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedDate = tx.timestamp;
      _selectedTime = TimeOfDay.fromDateTime(tx.timestamp);

      // Load Tags & Toggle Visibility
      if (tx.tags != null && tx.tags!.isNotEmpty) {
        try {
          _selectedFolders = List<Tag>.from(tx.tags!.whereType<Tag>());
          _showFolders = true;
        } catch (_) {}
      }

      // Load Person
      if (tx.people?.isNotEmpty == true) {
        _selectedPerson = tx.people!.first;
        _isLoan = tx.isCredit != null;
      }

      _reminderDate = tx.reminderDate;

      // Load Subscription
      if (tx.subscriptionId != null) {
        _selectedSubscriptionId = tx.subscriptionId;
        _showSubscription = true;
      }

      // Load Receipt
      if (tx.receiptUrl != null) {
        _existingReceiptUrl = tx.receiptUrl;
        _showReceipt = true;
      }
    } else {
      // New Transaction Logic
      if (widget.initialAmount != null) {
        _amountController.text =
            double.tryParse(widget.initialAmount!)?.toStringAsFixed(0) ?? '';
      }
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
      _selectedPaymentMethod = widget.initialPaymentMethod;

      if (widget.initialCategory != null) {
        final validCategories = widget.mode == TransactionMode.expense
            ? TransactionCategories.expense
            : TransactionCategories.income;
        if (validCategories.contains(widget.initialCategory)) {
          _selectedCategory = widget.initialCategory;
        }
      }
      _selectedCategory ??= 'Others';

      if (widget.initialPayee != null && widget.initialPayee!.isNotEmpty) {
        _descController.text = widget.initialPayee!;
      }
      if (widget.initialPerson != null) {
        _selectedPerson = widget.initialPerson;
      }
      _isLoan = widget.initialIsLoan;
      _loanSubtype = widget.initialLoanSubtype;

      _existingReceiptUrl = null;
    }
  }

  void reset() {
    setState(() {
      _amountController.clear();
      _descController.clear();

      // Reset to defaults
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);

      // Re-initialize category based on mode
      final validCategories = widget.mode == TransactionMode.expense
          ? TransactionCategories.expense
          : TransactionCategories.income;
      _selectedCategory = 'Others';
      if (!validCategories.contains(_selectedCategory)) {
        _selectedCategory = validCategories.first;
      }

      // Reset Power Fields
      _selectedFolders = [];
      _selectedPerson = null;
      _isLoan = false;
      _loanSubtype = 'new';
      _selectedSubscriptionId = null;
      _reminderDate = null;
      _newReceiptData = null;
      _existingReceiptUrl = null;
      _isDeletingReceipt = false;

      // Reset View State
      _showFolders = false;
      _showSubscription = false;
      _showReceipt = false;

      _isDirty = false;
    });

    // Re-check auto-folders for today
    _checkAutoAddFolders();
  }

  Future<void> _checkAutoAddFolders() async {
    if (_isEditing && _selectedFolders.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final metaProvider = Provider.of<MetaProvider>(context, listen: false);
      final autoTags = metaProvider.getAutoAddTagsForDate(_selectedDate);
      if (autoTags.isNotEmpty) {
        setState(() {
          _selectedFolders = autoTags;
          _showFolders = true;
        });
      }
    });
  }

  Future<void> _initializeAccount() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );

      // Wait for accounts to load
      int retries = 0;
      while (accountProvider.accounts.isEmpty && retries < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        if (!mounted) return;
      }

      Account? foundAccount;
      if (_isEditing && widget.transaction?.accountId != null) {
        try {
          foundAccount = accountProvider.accounts.firstWhere(
            (acc) => acc.id == widget.transaction!.accountId,
          );
        } catch (_) {}
      } else if (widget.initialAccountNumber != null) {
        foundAccount = await accountProvider.findOrCreateAccount(
          bankName: widget.initialBankName ?? 'Unknown Bank',
          accountNumber: widget.initialAccountNumber!,
        );
      } else {
        foundAccount = await accountProvider.getPrimaryAccount();
      }

      if (mounted) {
        setState(() {
          if (foundAccount != null) {
            _selectedAccount = foundAccount;
            if (!_isEditing) {
              final isCash = foundAccount.bankName.toLowerCase() == 'cash';
              _selectedPaymentMethod ??= (isCash ? 'Cash' : 'UPI');
            }
          }
          _isLoadingAccount = false;
        });
      }
    });
  }

  @override
  void dispose() {
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

  Future<bool> save(String currencyCode, {bool stayOnPage = false}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || !_validateCustomFields()) {
      return false;
    }
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

    // Upload Receipt Logic
    String? finalReceiptUrl = _existingReceiptUrl;
    if (_isDeletingReceipt) {
      finalReceiptUrl = null;
      if (_existingReceiptUrl != null) {
        ReceiptService().deleteReceipt(_existingReceiptUrl!);
      }
    }

    if (_newReceiptData != null) {
      final receiptId = const Uuid().v4();
      try {
        finalReceiptUrl = await ReceiptService().uploadReceipt(
          imageData: _newReceiptData!,
          userId: Provider.of<AuthProvider>(context, listen: false).user!.uid,
          transactionId: receiptId,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload receipt: $e')),
          );
        }
      }
    }

    if (_isEditing) {
      final updatedTransaction = widget.transaction!.copyWith(
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        tags: _selectedFolders.isNotEmpty ? _selectedFolders : [],
        people: _selectedPerson != null ? [_selectedPerson!] : [],
        isCredit: isCreditForModel,
        reminderDate: _reminderDate,
        subscriptionId: () => _selectedSubscriptionId,
        accountId: () => _selectedAccount?.id,
        purchaseType: purchaseType,
        currency: currencyCode,
        receiptUrl: () => finalReceiptUrl,
      );
      await txProvider.updateTransaction(updatedTransaction);

      // Handle Debts
      if (_selectedPerson != null && _isLoan) {
        await _updatePersonDebt(peopleProvider, amount);
      }

      _cleanupSms();
      if (!mounted) return true;
      Navigator.of(context).pop(true);
      return true;
    } else {
      final newTransaction = TransactionModel(
        transactionId: const Uuid().v4(),
        type: widget.mode == TransactionMode.expense ? 'expense' : 'income',
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        tags: _selectedFolders.isNotEmpty ? _selectedFolders : null,
        people: _selectedPerson != null ? [_selectedPerson!] : null,
        isCredit: isCreditForModel,
        reminderDate: _reminderDate,
        subscriptionId: _selectedSubscriptionId,
        accountId: _selectedAccount?.id,
        currency: currencyCode,
        purchaseType: purchaseType,
        receiptUrl: finalReceiptUrl,
      );
      await txProvider.addTransaction(newTransaction);

      if (_selectedPerson != null && _isLoan) {
        await _updatePersonDebt(peopleProvider, amount);
      }

      _cleanupSms();
      if (!mounted) return true;

      if (stayOnPage) {
        reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Transaction saved! Record another.'),
            duration: Duration(seconds: 2),
          ),
        );
        return true;
      } else {
        Navigator.pop(context, true);
        return true;
      }
    }
  }

  Future<void> _updatePersonDebt(PeopleProvider provider, double amount) async {
    Person updatedPerson = _selectedPerson!;
    if (widget.mode == TransactionMode.expense) {
      if (_loanSubtype == 'new') {
        updatedPerson = updatedPerson.copyWith(
          owesYou: updatedPerson.owesYou + amount,
        );
      } else {
        double newYouOwe = updatedPerson.youOwe - amount;
        if (newYouOwe < 0) newYouOwe = 0;
        updatedPerson = updatedPerson.copyWith(youOwe: newYouOwe);
      }
    } else {
      if (_loanSubtype == 'new') {
        updatedPerson = updatedPerson.copyWith(
          youOwe: updatedPerson.youOwe + amount,
        );
      } else {
        double newOwesYou = updatedPerson.owesYou - amount;
        if (newOwesYou < 0) newOwesYou = 0;
        updatedPerson = updatedPerson.copyWith(owesYou: newOwesYou);
      }
    }

    if (updatedPerson.owesYou > 0 && updatedPerson.youOwe > 0) {
      final overlap = updatedPerson.owesYou < updatedPerson.youOwe
          ? updatedPerson.owesYou
          : updatedPerson.youOwe;
      updatedPerson = updatedPerson.copyWith(
        owesYou: updatedPerson.owesYou - overlap,
        youOwe: updatedPerson.youOwe - overlap,
      );
    }
    await provider.updatePerson(updatedPerson);
  }

  void _cleanupSms() {
    if (widget.smsTransactionId != null) {
      try {
        _platform
            .invokeMethod('removePendingSmsTransaction', {
              'id': widget.smsTransactionId,
            })
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
  }

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

    final colorScheme = Theme.of(context).colorScheme;

    final subscriptionProvider = context.read<SubscriptionProvider>();

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
            // 1. HERO AMOUNT
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: AmountInputHero(
                controller: _amountController,
                color: heroColor,
              ),
            ),

            // 2. METADATA ROW (Date + Time + Account)
            SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DatePill(selectedDate: _selectedDate, onTap: _pickDate),
                  const SizedBox(width: 8),
                  TimePill(time: _selectedTime, onTap: _pickTime),
                  const SizedBox(width: 8),
                  CompactAccountPill(
                    accountName: _selectedAccount?.bankName ?? 'Select',
                    methodName: _selectedPaymentMethod ?? 'Method',
                    onTap: _showAccountMethodPicker,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. SCROLLABLE FORM BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                children: [
                  // --- ESSENTIALS ---
                  FunkyPickerTile(
                    icon: Icons.category_rounded,
                    label: "Category",
                    value: _selectedCategory,
                    valueIcon: _selectedCategory != null
                        ? _getCategoryIcon(_selectedCategory!)
                        : null,
                    valueColor: _selectedCategory != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    onTap: _showCategoryPicker,
                    isError: _selectedCategory == null,
                  ),

                  if (_selectedCategory == 'People') ...[
                    const SizedBox(height: 12),
                    _buildPeopleSection(context),
                  ],

                  const SizedBox(height: 12),

                  FunkyTextField(
                    controller: _descController,
                    label: widget.mode == TransactionMode.expense
                        ? "Sent to or payee"
                        : "Received from or payer",
                    icon: Icons.edit_note_rounded,
                  ),

                  const SizedBox(height: 24),

                  // --- POWER OPTION SECTIONS (Animated) ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showFolders
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FunkyPickerTile(
                              icon: Icons.folder_open_rounded,
                              label: "Add to Folders",
                              value: _selectedFolders.isEmpty ? "Select" : null,
                              valueWidget: _selectedFolders.isEmpty
                                  ? null
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: BouncingScrollPhysics(),
                                      child: Row(
                                        children: [
                                          ..._selectedFolders.map(
                                            (folder) => Container(
                                              margin: const EdgeInsets.only(
                                                right: 6,
                                                top: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: folder.color != null
                                                    ? Color(
                                                        folder.color!,
                                                      ).withValues(alpha: 0.15)
                                                    : colorScheme.primary
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: folder.color != null
                                                      ? Color(
                                                          folder.color!,
                                                        ).withValues(alpha: 0.3)
                                                      : colorScheme.primary
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedFolder02,
                                                    size: 14,
                                                    color: folder.color != null
                                                        ? Color(folder.color!)
                                                        : colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    folder.name,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          folder.color != null
                                                          ? Color(folder.color!)
                                                          : colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: InkWell(
                                              onTap: _showFolderPicker,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: colorScheme.primary
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  "+ Add to another Folder",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              onTap: _showFolderPicker,
                              trailingAction: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  child: const Icon(Icons.close, size: 14),
                                  onTap: () => setState(() {
                                    _showFolders = false;
                                    _selectedFolders.clear();
                                  }),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showSubscription
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Consumer<SubscriptionProvider>(
                              builder: (context, subProvider, _) {
                                final sub = subProvider.subscriptions
                                    .where(
                                      (s) => s.id == _selectedSubscriptionId,
                                    )
                                    .firstOrNull;
                                return FunkyPickerTile(
                                  icon: Icons.autorenew_rounded,
                                  label: "Recurring",
                                  value: sub?.name ?? "Select",
                                  leadingValueWidget: sub != null
                                      ? CircleAvatar(
                                          radius: 8,
                                          backgroundColor:
                                              colorScheme.surfaceContainer,
                                          child: Text(
                                            sub.name
                                                .trim()
                                                .split(' ')
                                                .map((l) => l[0])
                                                .take(2)
                                                .join()
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : null,
                                  valueColor: sub != null
                                      ? colorScheme.onSurface
                                      : null,
                                  onTap: () => _showSubscriptionPicker(
                                    subProvider.subscriptions,
                                  ),
                                  trailingAction: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      child: const Icon(Icons.close, size: 14),
                                      onTap: () => setState(() {
                                        _showSubscription = false;
                                        _selectedSubscriptionId = null;
                                      }),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showReceipt
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildReceiptCard(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // 4. ACTION CHIPS DECK
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (!_showFolders)
                      TransactionActionChip(
                        icon: HugeIcons.strokeRoundedFolderAdd,
                        label: "Folder",
                        onTap: () {
                          setState(() => _showFolders = true);
                          _showFolderPicker();
                        },
                      ),
                    if (!_showReceipt)
                      TransactionActionChip(
                        icon: HugeIcons.strokeRoundedCameraAdd01,
                        label: "Receipt",
                        onTap: () {
                          setState(() => _showReceipt = true);
                          _pickReceipt();
                        },
                      ),
                    if (!_showSubscription &&
                        widget.mode == TransactionMode.expense)
                      TransactionActionChip(
                        icon: HugeIcons.strokeRoundedRepeat,
                        label: "Link Recurring",
                        onTap: () {
                          setState(() => _showSubscription = true);
                          _showSubscriptionPicker(
                            subscriptionProvider.subscriptions,
                          );
                        },
                      ),
                    TransactionActionChip(
                      icon: HugeIcons.strokeRoundedMoneyExchange01,
                      label: "Convert",
                      onTap: _openCurrencyConverter,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 74),
          ],
        ),
      ),
    );
  }

  // --- NEW WIDGETS ---
  Widget _buildPeopleSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          FunkyPickerTile(
            icon: Icons.person_rounded,
            label: "Person",
            value: _selectedPerson?.fullName,
            leadingValueWidget: _selectedPerson != null
                ? CircleAvatar(
                    radius: 8,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      _selectedPerson!.fullName
                          .trim()
                          .split(' ')
                          .map((l) => l[0])
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 8, color: Colors.white),
                    ),
                  )
                : null,
            onTap: _showPeopleModal,
            isCompact: true,
            isError: _selectedPerson == null,
          ),
          // const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Track as Loan",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: _isLoan,
                      onChanged: (v) => setState(() {
                        _isLoan = v;
                        _markAsDirty();
                      }),
                    ),
                  ],
                ),
                if (_isLoan) ...[
                  const Divider(height: 24),
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(
                          widget.mode == TransactionMode.expense
                              ? "Loan Given"
                              : "Loan Taken",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          widget.mode == TransactionMode.expense
                              ? "This person will owe you the amount"
                              : "You will owe this person the amount",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: 'new',
                        groupValue: _loanSubtype,
                        onChanged: (v) => setState(() => _loanSubtype = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      // const SizedBox(height: 8),
                      RadioListTile<String>(
                        title: const Text(
                          "Repayment",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          widget.mode == TransactionMode.expense
                              ? "Paying back the amount you owed"
                              : "Collecting back the amount they owed",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: 'repayment',
                        groupValue: _loanSubtype,
                        onChanged: (v) => setState(() => _loanSubtype = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    return Stack(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _newReceiptData != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_newReceiptData!, fit: BoxFit.cover),
                )
              : _existingReceiptUrl != null && !_isDeletingReceipt
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: _existingReceiptUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                )
              : Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text("Upload Image"),
                    onPressed: _pickReceipt,
                  ),
                ),
        ),
        if (_newReceiptData != null ||
            (_existingReceiptUrl != null && !_isDeletingReceipt))
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 14,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () => setState(() {
                  _newReceiptData = null;
                  if (_existingReceiptUrl != null) {
                    _isDeletingReceipt = true;
                  }
                  if (_existingReceiptUrl == null) _showReceipt = false;
                }),
              ),
            ),
          ),
      ],
    );
  }

  // --- Helpers ---
  void _showAccountMethodPicker() {
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    showCustomAccountModal(context, accountProvider.accounts, (acc) {
      setState(() {
        _selectedAccount = acc;
        _markAsDirty();
      });
      _showPaymentMethodPicker();
    }, selectedId: _selectedAccount?.id);
  }

  void _showCategoryPicker() async {
    final categories = widget.mode == TransactionMode.expense
        ? TransactionCategories.expense
        : TransactionCategories.income;
    final selected = await showModernPickerSheet(
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
    final isCash = _selectedAccount?.bankName.toLowerCase() == 'cash';
    final methods = isCash ? _cashPaymentMethods : _nonCashPaymentMethods;
    final selected = await showModernPickerSheet(
      context: context,
      title: 'Select Method',
      items: methods
          .map((m) => PickerItem(id: m, label: m, icon: _getMethodIcon(m)))
          .toList(),
      selectedId: _selectedPaymentMethod,
    );
    if (selected != null) {
      setState(() {
        _selectedPaymentMethod = selected;
        _markAsDirty();
      });
    }
  }

  void _showPeopleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        builder: (_, c) => PersonPickerSheet(
          selectedPerson: _selectedPerson,
          scrollController: c,
          onSelected: (p) => setState(() {
            _selectedPerson = p;
            _markAsDirty();
          }),
        ),
      ),
    );
  }

  void _showFolderPicker() {
    final meta = Provider.of<MetaProvider>(context, listen: false);
    final tx = Provider.of<TransactionProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        builder: (_, c) => FolderPickerSheet(
          metaProvider: meta,
          txProvider: tx,
          selectedFolders: _selectedFolders,
          scrollController: c,
          onSelected: (tags) => setState(() {
            _selectedFolders = tags;
            _markAsDirty();
          }),
        ),
      ),
    );
  }

  void _showSubscriptionPicker(List<Subscription> subs) {
    showModernPickerSheet(
      context: context,
      title: "Recurring Payments",
      items: subs
          .map(
            (s) => PickerItem(id: s.id, label: s.name, icon: Icons.autorenew),
          )
          .toList(),
      showCreateNew: true,
      onCreateNew: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
      ),
      selectedId: _selectedSubscriptionId,
    ).then((id) {
      if (id != null) {
        setState(() {
          _selectedSubscriptionId = id;
          _markAsDirty();
        });
      }
    });
  }

  void _pickReceipt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReceiptModalSheet(
        uploadImmediately: false,
        onComplete: (_, bytes) {
          if (bytes != null) {
            setState(() {
              _newReceiptData = bytes;
              _isDeletingReceipt = false;
              _markAsDirty();
            });
          }
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        _markAsDirty();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
        _markAsDirty();
      });
    }
  }

  void _openCurrencyConverter() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CurrencyConverterModal(
        initialFromCurrency: 'USD',
        defaultTargetCurrency: settings.currencyCode,
        initialAmount: double.tryParse(_amountController.text),
      ),
    );
    if (result != null) {
      setState(() {
        _amountController.text = result.toStringAsFixed(2);
        _markAsDirty();
      });
    }
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
