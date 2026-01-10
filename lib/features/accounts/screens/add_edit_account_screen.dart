import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
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

class _AddEditAccountScreenState extends State<AddEditAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _billingCycleDayController = TextEditingController(text: '1');
  final _initialBalanceController = TextEditingController();
  final _cardNumberController = TextEditingController();

  // State
  late TabController _tabController;
  bool _isLoading = false;

  // To track the type without relying solely on TabController index for logic
  String _accountType = 'debit';

  @override
  void initState() {
    super.initState();

    // Initialize Tab Controller
    _tabController = TabController(length: 2, vsync: this);

    // logic to sync tab controller with account type
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _accountType = _tabController.index == 0 ? 'debit' : 'credit';
        });
      }
    });

    if (widget.isEditing) {
      final acc = widget.account!;
      _bankNameController.text = acc.bankName;
      _accountNumberController.text = acc.accountNumber;
      _accountHolderNameController.text = acc.accountHolderName;
      _accountType = acc.accountType;

      // Set initial tab index
      _tabController.index = _accountType == 'debit' ? 0 : 1;

      if (_accountType == 'credit') {
        _creditLimitController.text = acc.creditLimit?.toStringAsFixed(0) ?? '';
        _billingCycleDayController.text =
            acc.billingCycleDay?.toString() ?? '1';
      } else {
        _cardNumberController.text = acc.cardNumber ?? '';
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderNameController.dispose();
    _creditLimitController.dispose();
    _billingCycleDayController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    final settingsProvider = context.read<SettingsProvider>();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
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
          cardNumber: _accountType == 'debit'
              ? _cardNumberController.text.trim()
              : null,
          accountHolderName: _accountHolderNameController.text.trim(),
          accountType: _accountType,
          creditLimit: creditLimit,
          billingCycleDay: billingDay,
        );
        await accountProvider.updateAccount(updatedAccount);
      } else {
        final newAccount = Account(
          id: const Uuid().v4(),
          bankName: _bankNameController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          cardNumber: _accountType == 'debit'
              ? _cardNumberController.text.trim()
              : null,
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
            // Tag Logic (Simplified)
            final tagName = "balance money";
            Tag? balanceTag;
            try {
              balanceTag = metaProvider.tags.firstWhere(
                (t) => t.name.toLowerCase() == tagName,
              );
            } catch (e) {
              // Tag doesn't exist
            }

            if (balanceTag == null) {
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
              accountId: createdAccount.id,
              category: 'Income',
              tags: [balanceTag],
              currency: settingsProvider.currencyCode,
            );

            await transactionProvider.addTransaction(transaction);
          }
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebit = _accountType == 'debit';

    // Dynamic Color Theme
    // final appColors = theme.extension<AppColors>();
    final activeColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Account' : 'New Account',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        // The Tab Bar in the AppBar bottom slot
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => HapticFeedback.selectionClick(),
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
              labelColor: activeColor,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              splashBorderRadius: BorderRadius.circular(25),
              tabs: const [
                Tab(
                  child: _TabLabel(
                    title: "Debit",
                    subtitle: "Savings & Checking",
                  ),
                ),
                Tab(
                  child: _TabLabel(title: "Credit", subtitle: "Cards & Loans"),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // --- Initial Balance Hero (Only for New Debit Accounts) ---
                    if (!widget.isEditing && isDebit) ...[
                      Text(
                        'CURRENT BALANCE',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: activeColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AmountInputHero(
                        controller: _initialBalanceController,
                        color: activeColor,
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      const SizedBox(height: 12),
                    ],

                    // --- Form Fields ---
                    _FunkyTextField(
                      controller: _bankNameController,
                      label: isDebit
                          ? 'Account Name (e.g. HDFC)'
                          : 'Card name (e.g. Swiggy) HDFC',
                      icon: Icons.account_balance_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),

                    const SizedBox(height: 8),
                    _noteBuilder(
                      theme,
                      "Don't include 'bank' in 'HDFC' or similar cases.",
                    ),

                    const SizedBox(height: 16),

                    _FunkyTextField(
                      controller: _accountNumberController,
                      label: isDebit
                          ? 'Last 4 digits of Debit Account'
                          : 'Last 4 digits of Credit Card',
                      icon: Icons.pin_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        if (val.length > 4) {
                          _accountNumberController.text = val.substring(0, 4);
                          _accountNumberController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: 4),
                              );
                        }
                      },
                    ),

                    if (isDebit) ...[
                      const SizedBox(height: 8),
                      _noteBuilder(
                        theme,
                        "The account number of your debit account will be used to identify your account - not your card number.",
                      ),
                    ],

                    const SizedBox(height: 16),

                    if (isDebit) ...[
                      _FunkyTextField(
                        controller: _cardNumberController,
                        label: 'Last 4 digits of Debit Card',
                        icon: Icons.pin_rounded,
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          if (val.length > 4) {
                            _cardNumberController.text = val.substring(0, 4);
                            _cardNumberController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: 4),
                                );
                          }
                        },
                      ),

                      const SizedBox(height: 8),

                      _noteBuilder(
                        theme,
                        "This is the card number - helps Ledgr track your account transactions more accurately.",
                      ),

                      const SizedBox(height: 16),
                    ],

                    _FunkyTextField(
                      controller: _accountHolderNameController,
                      label: 'Account Holder Name',
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),

                    // --- Credit Specific Fields ---
                    if (!isDebit) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _FunkyTextField(
                              controller: _creditLimitController,
                              label: 'Limit',
                              icon: Icons.speed_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _FunkyTextField(
                              controller: _billingCycleDayController,
                              label: 'Bill Day',
                              icon: Icons.calendar_today_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 100), // Bottom spacer
                  ],
                ),
              ),

              // --- Save Button ---
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveAccount,
                    style: FilledButton.styleFrom(
                      backgroundColor: activeColor,
                      elevation: 4,
                      shadowColor: activeColor.withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.isEditing
                                ? 'Save Changes'
                                : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noteBuilder(ThemeData theme, String note, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning
            ? theme.colorScheme.errorContainer.withAlpha(76)
            : theme.colorScheme.primaryContainer.withAlpha(76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWarning
              ? theme.colorScheme.error.withAlpha(50)
              : theme.colorScheme.primary.withAlpha(50),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: isWarning
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12,
                color: isWarning
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// --- STYLE WIDGETS (Consistent with AddDebtLoan & AddSubscription) ---
// --------------------------------------------------------------------------

class _TabLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TabLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.normal),
        ),
      ],
    );
  }
}

class _AmountInputHero extends StatelessWidget {
  final TextEditingController controller;
  final Color color;

  const _AmountInputHero({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currencySymbol = settingsProvider.currencySymbol;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currencySymbol,
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
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FunkyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final Function(String)? onChanged;

  const _FunkyTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
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
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText:
              label, // Using labelText allowing it to float is often better UX
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.outline),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
