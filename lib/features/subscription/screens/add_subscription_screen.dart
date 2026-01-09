import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

// Helper imports
import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/currency_convert/widgets/currency_convert_modal_sheet.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_form_widgets.dart';
import 'package:wallzy/features/people/widgets/person_picker_sheet.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? subscription;

  const AddSubscriptionScreen({super.key, this.subscription});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  SubscriptionFrequency _selectedFrequency = SubscriptionFrequency.monthly;
  SubscriptionCreationMode _creationMode = SubscriptionCreationMode.manual;
  SubscriptionNotificationTiming _notificationTiming =
      SubscriptionNotificationTiming.onDueDate;
  bool _createFirstTransaction = true;
  bool _isLoading = false;
  Person? _selectedPerson;
  Account? _selectedAccount;

  // New Recurrence State
  int _selectedRecurrenceDay = DateTime.now().day; // 1-31
  int _selectedRecurrenceMonth = DateTime.now().month; // 1-12
  int _selectedRecurrenceWeekday = DateTime.now().weekday; // 1-7 (Mon-Sun)

  // Derived state for saving
  DateTime _calculatedNextDueDate = DateTime.now();

  bool get _isEditing => widget.subscription != null;
  final _nonCashPaymentMethods = ["Card", "UPI", "Net banking", "Other"];
  final _cashPaymentMethods = ["Cash", "Other"];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final sub = widget.subscription!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toStringAsFixed(0);
      _selectedCategory = sub.category;
      _selectedPaymentMethod = sub.paymentMethod;
      _selectedFrequency = sub.frequency;

      // Initialize recurrence state from existing subscription
      _calculatedNextDueDate = sub.nextDueDate;
      if (sub.recurrenceDay != null)
        _selectedRecurrenceDay = sub.recurrenceDay!;
      if (sub.recurrenceMonth != null)
        _selectedRecurrenceMonth = sub.recurrenceMonth!;
      _selectedRecurrenceWeekday = sub.nextDueDate.weekday; // Best guess

      _creationMode = sub.creationMode;
      _notificationTiming = sub.notificationTiming;
      _selectedPerson = sub.people?.isNotEmpty == true
          ? sub.people!.first
          : null;
      _createFirstTransaction = false;

      // Initialize Account if exists
      if (sub.accountId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final accountProvider = Provider.of<AccountProvider>(
            context,
            listen: false,
          );
          try {
            final match = accountProvider.accounts.firstWhere(
              (a) => a.id == sub.accountId,
            );
            setState(() {
              _selectedAccount = match;
            });
          } catch (e) {
            // Account might be deleted or not found
          }
        });
      }
    } else {
      _updateCalculatedDate();
    }

    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final accountProvider = Provider.of<AccountProvider>(
          context,
          listen: false,
        );
        final primary = await accountProvider.getPrimaryAccount();
        if (primary != null) {
          setState(() {
            _selectedAccount = primary;
            _updatePaymentMethodsForAccount(primary);
          });
        }
      });
    }
  }

  void _updatePaymentMethodsForAccount(Account account) {
    final isCash = account.bankName.toLowerCase() == 'cash';
    if (isCash) {
      _selectedPaymentMethod = 'Cash';
    } else if (_selectedPaymentMethod == 'Cash' ||
        _selectedPaymentMethod == null) {
      _selectedPaymentMethod = 'UPI';
    }
  }

  // Core logic to find the next occurrence
  void _updateCalculatedDate() {
    final now = DateTime.now();
    DateTime next;

    // Helper to find next target date
    DateTime findNextMonthDate(int targetDay) {
      // If today is before target day, it's this month. Else next month.
      // BUT we also need to handle invalid dates (e.g. Feb 30)

      DateTime candidate = DateTime(
        now.year,
        now.month,
        minCheck(now.year, now.month, targetDay),
      );

      // If candidate is today or past, move to next month
      if (!candidate.isAfter(now) && !isSameDay(candidate, now)) {
        // Move to next month
        int nextMonth = now.month + 1;
        int nextYear = now.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        candidate = DateTime(
          nextYear,
          nextMonth,
          minCheck(nextYear, nextMonth, targetDay),
        );
      } else if (isSameDay(candidate, now)) {
        // If it's today, user likely wants "Today" as the start.
        // So we keep it as today.
      } else if (candidate.isBefore(now)) {
        // Should have been caught by first check, but safety:
        int nextMonth = now.month + 1;
        int nextYear = now.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        candidate = DateTime(
          nextYear,
          nextMonth,
          minCheck(nextYear, nextMonth, targetDay),
        );
      }
      return candidate;
    }

    switch (_selectedFrequency) {
      case SubscriptionFrequency.daily:
        // Start tomorrow? User said "take current date and show next date".
        // Usually implies "Start Now". Next due is current date dependent on payment.
        // Let's default to Tomorrow for "Next Due".
        next = now.add(const Duration(days: 1));
        break;

      case SubscriptionFrequency.weekly:
        // Find next occurrence of _selectedRecurrenceWeekday (1=Mon, 7=Sun)
        int daysToAdd = (_selectedRecurrenceWeekday - now.weekday + 7) % 7;
        if (daysToAdd == 0) {
          // It's today. If time passed? Assume "Today" is valid start.
          // But usually "Next Due" implies future. Let's assume +7 days if today?
          // Let's stick to: If today is Monday and user picks Monday, it's Due Today.
          next = now;
        } else {
          next = now.add(Duration(days: daysToAdd));
        }
        break;

      case SubscriptionFrequency.monthly:
        next = findNextMonthDate(_selectedRecurrenceDay);
        break;

      case SubscriptionFrequency.quarterly:
        // Similar to Yearly but every 3 months.
        // Simply start with the user's chosen "Month" (mapped to relative? No, user chooses Date).
        // User said "choose a month and date".
        // Let's say user picks "Feb 15".
        // If Now is Jan, Next is Feb 15.
        // If Now is Mar, Next is May 15 (Feb+3).
        // To simplify UI for Quarterly: User picks "Start Date" (Month + Day).
        // We find the next occurrence of that Month/Day, or Month+3/Day.
        // Actually, to fully support "Choose Month and Date", we treat it like yearly anchor
        // then find the nearest future quarter match.

        // Reuse Yearly Logic for finding the 'first' one.
        DateTime candidate = DateTime(
          now.year,
          _selectedRecurrenceMonth,
          minCheck(now.year, _selectedRecurrenceMonth, _selectedRecurrenceDay),
        );
        if (candidate.isBefore(now) && !isSameDay(candidate, now)) {
          // Try same year, +3 months loop until future
          while (candidate.isBefore(now) && !isSameDay(candidate, now)) {
            candidate = DateTime(
              candidate.year,
              candidate.month + 3,
              minCheck(
                candidate.year,
                candidate.month + 3,
                _selectedRecurrenceDay,
              ),
            );
          }
        }
        next = candidate;
        break;

      case SubscriptionFrequency.yearly:
        // Next occurrence of Month/Day
        DateTime yCandidate = DateTime(
          now.year,
          _selectedRecurrenceMonth,
          minCheck(now.year, _selectedRecurrenceMonth, _selectedRecurrenceDay),
        );
        if (yCandidate.isBefore(now) && !isSameDay(yCandidate, now)) {
          yCandidate = DateTime(
            now.year + 1,
            _selectedRecurrenceMonth,
            minCheck(
              now.year + 1,
              _selectedRecurrenceMonth,
              _selectedRecurrenceDay,
            ),
          );
        }
        next = yCandidate;
        break;
    }

    setState(() {
      _calculatedNextDueDate = next;
    });
  }

  // Helper to ensure day doesn't exceed month days (e.g. Feb 31 -> Feb 28)
  int minCheck(int year, int month, int day) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return day > daysInMonth ? daysInMonth : day;
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveSubscription() async {
    final settingsProvider = context.read<SettingsProvider>();

    if (_nameController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedPaymentMethod == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an account')));
      return;
    }

    setState(() => _isLoading = true);

    final subProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final newSubscription = Subscription(
      id: _isEditing ? widget.subscription!.id : const Uuid().v4(),
      name: _nameController.text.trim(),
      amount: amount,
      category: _selectedCategory!,
      paymentMethod: _selectedPaymentMethod!,
      frequency: _selectedFrequency,
      recurrenceDay: _selectedRecurrenceDay,
      recurrenceMonth:
          (_selectedFrequency == SubscriptionFrequency.yearly ||
              _selectedFrequency == SubscriptionFrequency.quarterly)
          ? _selectedRecurrenceMonth
          : null,
      nextDueDate: _calculatedNextDueDate,
      isActive: true,
      accountId: _selectedAccount?.id,
      creationMode: _creationMode,
      notificationTiming: _notificationTiming,
      people: _selectedPerson != null ? [_selectedPerson!] : null,
    );

    try {
      if (_isEditing) {
        await subProvider.updateSubscription(newSubscription);
      } else {
        await subProvider.addSubscription(newSubscription);
        if (_createFirstTransaction) {
          final newTransaction = TransactionModel(
            transactionId: const Uuid().v4(),
            type: 'expense',
            amount: newSubscription.amount,
            timestamp: newSubscription.nextDueDate,
            description: newSubscription.name,
            paymentMethod: newSubscription.paymentMethod,
            category: newSubscription.category,
            subscriptionId: newSubscription.id,
            people: newSubscription.people,
            accountId: _selectedAccount?.id,
            currency: settingsProvider.currencyCode,
            purchaseType: _selectedAccount?.accountType == 'credit'
                ? 'credit'
                : 'debit',
          );
          await txProvider.addTransaction(newTransaction);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  void _showAccountPicker() {
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    showCustomAccountModal(context, accountProvider.accounts, (acc) {
      setState(() {
        _selectedAccount = acc;
        _updatePaymentMethodsForAccount(acc);
      });
    }, selectedId: _selectedAccount?.id);
  }

  void _showPaymentMethodPicker() async {
    if (_selectedAccount == null) return;
    final isCashAccount = _selectedAccount!.bankName.toLowerCase() == 'cash';
    final methods = isCashAccount
        ? _cashPaymentMethods
        : _nonCashPaymentMethods;
    final selected = await showModernPickerSheet(
      context: context,
      title: 'Select Payment Method',
      items: methods
          .map((m) => PickerItem(id: m, label: m, icon: Icons.credit_card))
          .toList(),
      selectedId: _selectedPaymentMethod,
    );
    if (selected != null) setState(() => _selectedPaymentMethod = selected);
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
            });
          },
        ),
      ),
    );
  }

  void _openCurrencyConverter() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: CurrencyConverterModal(
          initialFromCurrency: 'USD',
          defaultTargetCurrency: settingsProvider.currencyCode,
          initialAmount: double.tryParse(_amountController.text),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _amountController.text = result.toStringAsFixed(2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Recurring Payment' : 'New Recurring Payment',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: AmountInputHero(
                  controller: _amountController,
                  color: theme.colorScheme.primary,
                ),
              ),

              _Chip(
                icon: Icons.currency_exchange,
                label: "Convert",
                onTap: _openCurrencyConverter,
              ),

              const SizedBox(height: 12),

              // Removed DatePill from here as requested.
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    FunkyTextField(
                      controller: _nameController,
                      label: "Payment Name (e.g. Netflix, EMI)",
                      icon: Icons.description_rounded,
                    ),
                    const SizedBox(height: 16),
                    FunkyPickerTile(
                      icon: Icons.category_rounded,
                      label: "Category",
                      value: _selectedCategory,
                      onTap: () async {
                        final selected = await showModernPickerSheet(
                          context: context,
                          title: 'Select Category',
                          items: TransactionCategories.expense
                              .map(
                                (c) => PickerItem(
                                  id: c,
                                  label: c,
                                  icon: Icons.category,
                                ),
                              )
                              .toList(),
                          selectedId: _selectedCategory,
                        );
                        if (selected != null) {
                          setState(() {
                            _selectedCategory = selected;
                            if (selected != 'People') _selectedPerson = null;
                          });
                          if (selected == 'People') _showPeopleModal();
                        }
                      },
                      isError: _selectedCategory == null,
                    ),
                    if (_selectedCategory == 'People') ...[
                      const SizedBox(height: 16),
                      FunkyPickerTile(
                        icon: Icons.person_rounded,
                        label: "Person",
                        value: _selectedPerson?.fullName,
                        onTap: _showPeopleModal,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Account Split Pill
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
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
                                onTap: _showAccountPicker,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        _selectedAccount?.displayName ??
                                            "Select",
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
                                onTap: _selectedAccount != null
                                    ? _showPaymentMethodPicker
                                    : null,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "METHOD",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedAccount == null
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withAlpha(128)
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.outline,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedPaymentMethod ?? "Select",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _selectedAccount == null
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withAlpha(80)
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
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

                    // Frequency Picker
                    FunkyPickerTile(
                      icon: Icons.repeat_rounded,
                      label: "Frequency",
                      value: _selectedFrequency.displayName,
                      onTap: () async {
                        final selected = await showModernPickerSheet(
                          context: context,
                          title: 'Frequency',
                          items: SubscriptionFrequency.values
                              .map(
                                (e) => PickerItem(
                                  id: e.displayName,
                                  label: e.displayName,
                                  icon: Icons.repeat,
                                ),
                              )
                              .toList(),
                          selectedId: _selectedFrequency.displayName,
                        );
                        if (selected != null) {
                          setState(() {
                            _selectedFrequency = SubscriptionFrequency.values
                                .firstWhere((e) => e.displayName == selected);
                            _updateCalculatedDate();
                          });
                        }
                      },
                      isCompact: true,
                    ),

                    const SizedBox(height: 16),

                    // --- DYNAMIC RECURRENCE SELECTOR ---
                    _buildRecurrenceSelector(theme),

                    const SizedBox(height: 24),

                    Text(
                      'OPTIONS',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        letterSpacing: 3,
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FunkyPickerTile(
                      icon: Icons.auto_awesome_rounded,
                      label: "Creation Mode",
                      value: _creationMode.displayName,
                      onTap: () async {
                        final selected = await showModernPickerSheet(
                          context: context,
                          title: 'Creation Mode',
                          items: SubscriptionCreationMode.values
                              .map(
                                (e) => PickerItem(
                                  id: e.displayName,
                                  label: e.displayName,
                                  icon: Icons.auto_awesome,
                                ),
                              )
                              .toList(),
                          selectedId: _creationMode.displayName,
                        );
                        if (selected != null) {
                          setState(
                            () => _creationMode = SubscriptionCreationMode
                                .values
                                .firstWhere((e) => e.displayName == selected),
                          );
                        }
                      },
                      isCompact: true,
                    ),
                    const SizedBox(height: 12),
                    FunkyPickerTile(
                      icon: Icons.notifications_active_rounded,
                      label: "Reminder Timing",
                      value: _notificationTiming.displayName,
                      onTap: () async {
                        final selected = await showModernPickerSheet(
                          context: context,
                          title: 'Reminder Timing',
                          items: SubscriptionNotificationTiming.values
                              .map(
                                (e) => PickerItem(
                                  id: e.displayName,
                                  label: e.displayName,
                                  icon: Icons.notifications,
                                ),
                              )
                              .toList(),
                          selectedId: _notificationTiming.displayName,
                        );
                        if (selected != null)
                          setState(
                            () => _notificationTiming =
                                SubscriptionNotificationTiming.values
                                    .firstWhere(
                                      (e) => e.displayName == selected,
                                    ),
                          );
                      },
                      isCompact: true,
                    ),

                    if (!_isEditing) ...[
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Create first transaction now'),
                        value: _createFirstTransaction,
                        onChanged: (val) =>
                            setState(() => _createFirstTransaction = val),
                        tileColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isLoading ? null : _saveSubscription,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEditing ? 'Save Changes' : 'Save Recurring Payment',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecurrenceSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_repeat_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "REPEAT",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector UI
          if (_selectedFrequency == SubscriptionFrequency.daily)
            Text(
              "Every Day",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),

          if (_selectedFrequency == SubscriptionFrequency.weekly)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final dayIndex = idx + 1; // 1=Mon
                  final isSelected = _selectedRecurrenceWeekday == dayIndex;
                  final label = DateFormat.E().format(
                    DateTime(2024, 1, dayIndex),
                  ); // Jan 1 2024 was Mon
                  return ChoiceChip(
                    label: Text(label[0]),
                    selected: isSelected,
                    onSelected: (v) {
                      if (v) {
                        setState(() {
                          _selectedRecurrenceWeekday = dayIndex;
                          _updateCalculatedDate();
                        });
                      }
                    },
                    showCheckmark: false,
                  );
                },
              ),
            ),

          if (_selectedFrequency == SubscriptionFrequency.monthly)
            _buildDropdownRow(
              label: "Day of Month",
              value: _selectedRecurrenceDay,
              items: List.generate(31, (i) => i + 1),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedRecurrenceDay = v;
                    _updateCalculatedDate();
                  });
                }
              },
            ),

          if (_selectedFrequency == SubscriptionFrequency.quarterly ||
              _selectedFrequency == SubscriptionFrequency.yearly)
            Row(
              children: [
                Expanded(
                  child: _buildDropdownRow(
                    label: "Month",
                    value: _selectedRecurrenceMonth,
                    items: List.generate(12, (i) => i + 1),
                    displayMap: (i) =>
                        DateFormat.MMM().format(DateTime(2024, i)),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedRecurrenceMonth = v;
                          _updateCalculatedDate();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownRow(
                    label: "Day",
                    value: _selectedRecurrenceDay,
                    items: List.generate(31, (i) => i + 1),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedRecurrenceDay = v;
                          _updateCalculatedDate();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Next Payment:",
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              Text(
                DateFormat.yMMMd().format(_calculatedNextDueDate),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required int value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
    String Function(int)? displayMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        DropdownButton<int>(
          value: value,
          isExpanded: true,
          underline: Container(height: 1, color: Colors.grey.withAlpha(80)),
          icon: const Icon(Icons.arrow_drop_down_rounded),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    displayMap != null ? displayMap(i) : i.toString(),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Chip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
