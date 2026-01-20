import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/expense_screen.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/income_screen.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transfer_screen.dart';

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
  final _expenseFormKey = GlobalKey<ExpenseScreenState>();
  final _incomeFormKey = GlobalKey<IncomeScreenState>();
  final _transferFormKey = GlobalKey<TransferScreenState>();
  final _editExpenseKey = GlobalKey<ExpenseScreenState>();
  final _editIncomeKey = GlobalKey<IncomeScreenState>();

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

  void _saveTransaction(String currencyCode, {bool stayOnPage = false}) {
    if (_isEditing) {
      if (widget.transaction!.type == 'expense') {
        _editExpenseKey.currentState?.save(currencyCode);
      } else {
        _editIncomeKey.currentState?.save(currencyCode);
      }
    } else {
      switch (_tabController.index) {
        case 0:
          _expenseFormKey.currentState?.save(
            currencyCode,
            stayOnPage: stayOnPage,
          );
          break;
        case 1:
          _incomeFormKey.currentState?.save(
            currencyCode,
            stayOnPage: stayOnPage,
          );
          break;
        case 2:
          _transferFormKey.currentState?.save(
            currencyCode,
            stayOnPage: stayOnPage,
          );
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
            ? (widget.transaction!.type == 'expense'
                  ? ExpenseScreen(
                      key: _editExpenseKey,
                      transaction: widget.transaction,
                    )
                  : IncomeScreen(
                      key: _editIncomeKey,
                      transaction: widget.transaction,
                    ))
            : TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ExpenseScreen(
                    key: _expenseFormKey,
                    initialAmount: widget.initialAmount,
                    initialDate: widget.initialDate,
                    smsTransactionId: widget.smsTransactionId,
                    initialPaymentMethod: widget.initialPaymentMethod,
                    initialBankName: widget.initialBankName,
                    initialAccountNumber: widget.initialAccountNumber,
                    initialPayee: widget.initialPayee,
                    initialCategory: widget.initialCategory,
                    initialPerson: widget.initialPerson,
                    initialIsLoan: widget.initialIsLoan,
                    initialLoanSubtype: widget.initialLoanSubtype,
                  ),
                  IncomeScreen(
                    key: _incomeFormKey,
                    initialAmount: widget.initialAmount,
                    initialDate: widget.initialDate,
                    smsTransactionId: widget.smsTransactionId,
                    initialPaymentMethod: widget.initialPaymentMethod,
                    initialBankName: widget.initialBankName,
                    initialAccountNumber: widget.initialAccountNumber,
                    initialPayee: widget.initialPayee,
                    initialCategory: widget.initialCategory,
                    initialPerson: widget.initialPerson,
                    initialIsLoan: widget.initialIsLoan,
                    initialLoanSubtype: widget.initialLoanSubtype,
                  ),
                  TransferScreen(key: _transferFormKey),
                ],
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Consumer<TransactionProvider>(
          builder: (context, txProvider, _) {
            final currencyCode = Provider.of<SettingsProvider>(
              context,
              listen: false,
            ).currencyCode;

            if (_isEditing) {
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
                  onPressed: txProvider.isSaving
                      ? null
                      : () => _saveTransaction(currencyCode),
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
                          'Save Changes',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: txProvider.isSaving
                          ? null
                          : () => _saveTransaction(
                              currencyCode,
                              stayOnPage: true,
                            ),
                      child: Text(
                        'Add Another',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        elevation: 4,
                        shadowColor: theme.colorScheme.primary.withAlpha(100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: txProvider.isSaving
                          ? null
                          : () => _saveTransaction(currencyCode),
                      child: txProvider.isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
