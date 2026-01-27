import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/features/goals/models/goal_model.dart';
import 'package:wallzy/features/goals/provider/goals_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/icon_picker/icon_picker_sheet.dart';
import 'package:wallzy/common/icon_picker/icons.dart';

class AddEditGoalScreen extends StatefulWidget {
  final Goal? goal;
  const AddEditGoalScreen({super.key, this.goal});

  @override
  State<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

class _AddEditGoalScreenState extends State<AddEditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  List<String> _selectedAccountIds = [];
  String _selectedIconKey = GoalIconRegistry.defaultKey;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.goal?.description ?? '',
    );
    _amountController = TextEditingController(
      text: widget.goal != null
          ? widget.goal!.targetAmount.toStringAsFixed(2)
          : '',
    );
    if (widget.goal != null) {
      _targetDate = widget.goal!.targetDate;
      _selectedAccountIds = List.from(widget.goal!.accountsList);
      _selectedIconKey = widget.goal!.iconKey ?? GoalIconRegistry.defaultKey;
    }
  }

  void _pickIcon() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalIconPickerSheet(
        selectedIconKey: _selectedIconKey,
        onIconSelected: (key) {
          setState(() => _selectedIconKey = key);
        },
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final goal = Goal(
        id:
            widget.goal?.id ??
            '', // ID handled by service/firestore for new goals (usually empty or null)
        title: title,
        description: description,
        targetAmount: amount,
        targetDate: _targetDate,
        accountsList: _selectedAccountIds,
        createdAt: widget.goal?.createdAt ?? DateTime.now(),
        iconKey: _selectedIconKey,
      );

      final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);

      if (widget.goal == null) {
        await goalsProvider.addGoal(goal);
      } else {
        await goalsProvider.updateGoal(goal);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountProvider = Provider.of<AccountProvider>(context);
    final accounts = accountProvider.accounts;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 24.0, left: 24, right: 24),
        child: FilledButton(
          onPressed: _isProcessing ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.goal == null ? 'Create Goal' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.goal == null ? 'New Goal' : 'Edit Goal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Icon Picker
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickIcon,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(50),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: GoalIconRegistry.getIcon(_selectedIconKey),
                          size: 40,
                          color: colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickIcon,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Title
            _buildTextField(
              controller: _titleController,
              label: 'Goal Title',
              hint: 'e.g. New Car',
              icon: HugeIcons.strokeRoundedTarget02,
              theme: theme,
              colorScheme: colorScheme,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),

            // Amount
            _buildTextField(
              controller: _amountController,
              label: 'Target Amount',
              hint: '0.00',
              icon: HugeIcons.strokeRoundedDollarCircle,
              theme: theme,
              colorScheme: colorScheme,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Target Date
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(20),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Target Date',
                  filled: true,
                  fillColor: colorScheme.surfaceContainer,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar03,
                      color: colorScheme.outline,
                      size: 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                child: Text(
                  DateFormat('MMMM dd, yyyy').format(_targetDate),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Description (Optional)',
              hint: 'What is this goal for?',
              icon: HugeIcons.strokeRoundedNote01,
              theme: theme,
              colorScheme: colorScheme,
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Accounts Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedWallet01,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Link Accounts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select accounts to track for this goal. Leave empty to track all accounts.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // MODERN ACCOUNT SELECTION
            if (accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(50),
                  ),
                ),
                child: Column(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAlertCircle,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No accounts found. Add an account first.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isSelected = _selectedAccountIds.contains(account.id);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedAccountIds.remove(account.id);
                        } else {
                          _selectedAccountIds.add(account.id);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withAlpha(30)
                            : colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withAlpha(50),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedWallet02,
                                    size: 14,
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.bankName,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 13,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (account.accountNumber.isNotEmpty)
                                        Text(
                                          '**** ${account.accountNumber}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colorScheme.outline,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 10,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required dynamic icon,
    required ThemeData theme,
    required ColorScheme colorScheme,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        hintText: hint,
        fillColor: colorScheme.surfaceContainer,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: HugeIcon(icon: icon, color: colorScheme.outline, size: 20),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
