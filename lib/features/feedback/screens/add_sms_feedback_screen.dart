import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/feedback/provider/sms_feedback_provider.dart';

class AddSmsTemplateScreen extends StatefulWidget {
  const AddSmsTemplateScreen({super.key});

  @override
  State<AddSmsTemplateScreen> createState() => _AddSmsTemplateScreenState();
}

class _AddSmsTemplateScreenState extends State<AddSmsTemplateScreen> {
  // Page Control
  int _currentStep = 1;
  bool _isSuccess = false;

  // Step 1 Controllers
  final _formKey = GlobalKey<FormState>();
  final _bankController = TextEditingController();
  final _senderController = TextEditingController();
  final _smsBodyController = TextEditingController();
  String _transactionType = 'expense'; // 'expense' or 'income'
  String _selectedPaymentMethod = 'UPI'; // Default

  // Step 2 State (Tagging)
  List<String> _smsTokens = [];
  List<Match> _smsTokenMatches = [];
  String _rawSmsContent = "";
  // Maps token INDEX to a Tag Type (e.g. 3 -> 'amount')
  final Map<int, String> _taggedIndices = {};

  @override
  void dispose() {
    _bankController.dispose();
    _senderController.dispose();
    _smsBodyController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---

  void _goToStep2() {
    if (!_formKey.currentState!.validate()) return;

    final text = _smsBodyController.text;
    // Regex matches words (\w+) or any individual symbol/punctuation that isn't whitespace.
    // This allows symbols like - , ; . to be individual selectable tokens.
    final tokenRegex = RegExp(r'\w+|[^\s\w]');
    final matches = tokenRegex.allMatches(text).toList();

    setState(() {
      _rawSmsContent = text;
      _smsTokenMatches = matches;
      _smsTokens = matches.map((m) => m.group(0)!).toList();
      _currentStep = 2;
    });
  }

  void _toggleTag(int index, String type) {
    setState(() {
      // If already tagged with this type, remove it
      if (_taggedIndices[index] == type) {
        _taggedIndices.remove(index);
      } else {
        // Remove any existing tag on this index first
        _taggedIndices[index] = type;
      }
    });
  }

  void _submit() {
    final Map<String, List<int>> typeToIndices = {};
    _taggedIndices.forEach((index, type) {
      if (type != 'none' && index < _smsTokens.length) {
        typeToIndices.putIfAbsent(type, () => []).add(index);
      }
    });

    // 1. Validate mandatory tags (Only Amount is mandatory)
    if (!typeToIndices.containsKey('amount')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please tag the Amount before submitting."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // 2. Extract values
    final Map<String, dynamic> taggedValues = {};
    typeToIndices.forEach((type, indices) {
      indices.sort();
      String result = "";
      int? lastTokenIndex;
      int? runStartIndex;

      for (int i = 0; i < indices.length; i++) {
        final currentTokenIndex = indices[i];
        if (lastTokenIndex == null) {
          runStartIndex = currentTokenIndex;
        } else if (currentTokenIndex == lastTokenIndex + 1) {
          // Continue
        } else {
          final runText = _rawSmsContent.substring(
            _smsTokenMatches[runStartIndex!].start,
            _smsTokenMatches[lastTokenIndex].end,
          );
          result += (result.isEmpty ? "" : " ") + runText;
          runStartIndex = currentTokenIndex;
        }
        lastTokenIndex = currentTokenIndex;
      }

      if (runStartIndex != null && lastTokenIndex != null) {
        final runText = _rawSmsContent.substring(
          _smsTokenMatches[runStartIndex].start,
          _smsTokenMatches[lastTokenIndex].end,
        );
        result += (result.isEmpty ? "" : " ") + runText;
      }
      taggedValues[type] = result;
    });

    // 3. Show Confirmation Dialog
    _showSubmitConfirmation(taggedValues);
  }

  void _showSubmitConfirmation(Map<String, dynamic> taggedData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text("Confirm Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please verify the information:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _ConfirmationItem(
              label: "Bank",
              value: _bankController.text,
              icon: Icons.account_balance_rounded,
            ),
            _ConfirmationItem(
              label: "Type",
              value: _transactionType.toUpperCase(),
              valueColor: _transactionType == 'expense'
                  ? Colors.redAccent
                  : Colors.green,
              icon: Icons.swap_horiz_rounded,
            ),
            const Divider(height: 24),
            _ConfirmationItem(
              label: "Amount",
              value: taggedData['amount'] ?? "---",
              icon: Icons.payments_rounded,
              color: Colors.blue,
            ),
            _ConfirmationItem(
              label: "Payee",
              value: taggedData['payee'] ?? "---",
              icon: Icons.store_rounded,
              color: Colors.orange,
            ),
            _ConfirmationItem(
              label: "Account",
              value: taggedData['account'] ?? "---",
              icon: Icons.credit_card_rounded,
              color: Colors.purple,
            ),
            _ConfirmationItem(
              label: "Payment Method",
              value: _selectedPaymentMethod,
              icon: Icons.payment_rounded,
              color: Colors.teal,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Wait, Go Back"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performFinalSubmit(taggedData);
            },
            child: const Text("Looks Good"),
          ),
        ],
      ),
    );
  }

  void _performFinalSubmit(Map<String, dynamic> taggedData) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) return;

    try {
      await Provider.of<SmsFeedbackProvider>(
        context,
        listen: false,
      ).submitSmsTemplate(
        userId: userId,
        bankName: _bankController.text.trim(),
        senderId: _senderController.text.trim(),
        rawSms: _smsBodyController.text.trim(),
        transactionType: _transactionType,
        paymentMethod: _selectedPaymentMethod,
        taggedData: taggedData,
      );

      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) return const _SuccessView();

    final theme = Theme.of(context);
    final provider = Provider.of<SmsFeedbackProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 1 ? "Report SMS Issue" : "Highlight Data"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress Indicator
                LinearProgressIndicator(
                  value: _currentStep / 2,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                  minHeight: 4,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _currentStep == 1
                        ? _buildStep1(theme)
                        : _buildStep2(theme),
                  ),
                ),
                // Bottom Actions
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _currentStep == 1 ? _goToStep2 : _submit,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentStep == 1
                            ? "Next: Highlight Data"
                            : "Submit Report",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- STEP 1: DATA INPUT ---
  Widget _buildStep1(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _noteBuilder(
            theme,
            "One report is for one SMS only. Read the instructions properly before filling.",
            isWarning: true,
          ),
          const SizedBox(height: 24),
          _SectionLabel(label: "BANK DETAILS"),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bankController,
            decoration: _inputDecoration(theme, "Bank Name", "e.g. HDFC, SBI"),
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 8),
          _noteBuilder(theme, "Ignore 'bank' after HDFC or in similar cases."),
          const SizedBox(height: 16),
          TextFormField(
            controller: _senderController,
            decoration: _inputDecoration(theme, "Sender ID", "e.g. AD-HDFCBK"),
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 8),
          _noteBuilder(theme, "Full sender ID is ideal for better detection."),
          const SizedBox(height: 24),
          _SectionLabel(label: "PAYMENT METHOD"),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showPaymentMethodPicker,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedPaymentMethod == 'UPI'
                        ? Icons.qr_code_rounded
                        : (_selectedPaymentMethod == 'Card'
                              ? Icons.credit_card_rounded
                              : (_selectedPaymentMethod == 'Net banking'
                                    ? Icons.account_balance_rounded
                                    : Icons.payment_rounded)),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "METHOD",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Text(
                          _selectedPaymentMethod,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionLabel(label: "TRANSACTION TYPE"),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _TypeTab(
                  label: "Expense (Debit)",
                  isSelected: _transactionType == 'expense',
                  onTap: () => setState(() => _transactionType = 'expense'),
                  color: Colors.redAccent,
                ),
                _TypeTab(
                  label: "Income (Credit)",
                  isSelected: _transactionType == 'income',
                  onTap: () => setState(() => _transactionType = 'income'),
                  color: Colors.green,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _SectionLabel(label: "SMS CONTENT"),
          const SizedBox(height: 12),
          TextFormField(
            controller: _smsBodyController,
            maxLines: 6,
            decoration: _inputDecoration(
              theme,
              "Paste the full SMS body here",
              "",
            ).copyWith(alignLabelWithHint: true),
            validator: (v) => v!.length < 10 ? "SMS looks too short" : null,
          ),
          const SizedBox(height: 8),
          _noteBuilder(
            theme,
            "For privacy, please replace sensitive numbers (Account no., Ref no.) with '5555' and names with 'John Doe' for example.\nKeep the body exactly as it is - whitespaces, numbers, symbols and text alike.",
          ),
        ],
      ),
    );
  }

  // --- STEP 2: HIGHLIGHT UX ---
  Widget _buildStep2(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Help us understand this message.",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Tap the words below to tag them. This trains our parser.",
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // LEGEND
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _LegendChip(label: "Amount", color: Colors.blue),
              const SizedBox(width: 8),
              _LegendChip(label: "Payee/Merchant", color: Colors.orange),
              const SizedBox(width: 8),
              _LegendChip(label: "Account No.", color: Colors.purple),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // INTERACTIVE TOKEN WRAP
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 10,
            children: List.generate(_smsTokens.length, (index) {
              final token = _smsTokens[index];
              final tagType = _taggedIndices[index];

              Color? tagColor;
              if (tagType == 'amount') tagColor = Colors.blue;
              if (tagType == 'payee') tagColor = Colors.orange;
              if (tagType == 'account') tagColor = Colors.purple;

              return GestureDetector(
                onTap: () => _showTagSelectionSheet(index, token),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tagColor ?? theme.colorScheme.outlineVariant,
                    ),
                    boxShadow: tagColor != null
                        ? [
                            BoxShadow(
                              color: tagColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    token,
                    style: TextStyle(
                      color: tagColor != null
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: tagColor != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),
        _noteBuilder(
          theme,
          "For example, for 'Rs.340.20' tag '340', '.' (dot), '20' separately as 'Amount'. Repeat the process for the other tags as well. Make sure all the parts are tagged correctly.",
        ),
        const SizedBox(height: 8),
        _noteBuilder(
          theme,
          "If both Account number and Card number are present in the same SMS, tag only Account number.",
        ),
      ],
    );
  }

  void _showTagSelectionSheet(int index, String token) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      backgroundColor: Colors.transparent, // Important for the custom border
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Drag Handle
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 2. Header & Token Preview
            Text(
              "Identify this data",
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                token,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'inter',
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),

            // 3. Selection Grid
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6, // Wider cards
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _TagOptionCard(
                    label: "Amount",
                    icon: HugeIcons.strokeRoundedMoney03,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleTag(index, 'amount');
                    },
                  ),
                  _TagOptionCard(
                    label: "Payee / Merchant",
                    icon: HugeIcons.strokeRoundedStore01,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleTag(index, 'payee');
                    },
                  ),
                  _TagOptionCard(
                    label: "Account / Card no.",
                    icon: HugeIcons.strokeRoundedCreditCard,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleTag(index, 'account');
                    },
                  ),
                  _TagOptionCard(
                    label: "Clear Tag",
                    icon: HugeIcons.strokeRoundedEraser01,
                    color: colorScheme.error,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleTag(index, 'none');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodPicker() async {
    final methods = ["UPI", "Card", "Net banking", "Other"];
    final String? selected = await _showModernPickerSheet(
      context: context,
      title: 'Select Method',
      items: methods
          .map(
            (m) => PickerItem(
              id: m,
              label: m,
              icon: m == 'UPI'
                  ? Icons.qr_code_rounded
                  : (m == 'Card'
                        ? Icons.credit_card_rounded
                        : (m == 'Net banking'
                              ? Icons.account_balance_rounded
                              : Icons.payment_rounded)),
            ),
          )
          .toList(),
      selectedId: _selectedPaymentMethod,
    );
    if (selected != null) {
      setState(() {
        _selectedPaymentMethod = selected;
      });
    }
  }

  InputDecoration _inputDecoration(ThemeData theme, String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
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

// --- SUB-WIDGETS ---

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    size: 60,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Thanks for helping Ledgr!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "We will review this format and update our parser soon.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 30),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: const Text("Close", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

class _TagOptionCard extends StatelessWidget {
  final String label;
  final List<List<dynamic>> icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const _TagOptionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isDestructive
          ? colorScheme.errorContainer.withAlpha(100)
          : color.withAlpha(200),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: isDestructive ? colorScheme.errorContainer : color,
        highlightColor: color.withOpacity(0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive ? Colors.transparent : Colors.white30,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(icon: icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDestructive ? color : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final Color? valueColor;

  const _ConfirmationItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.outline,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
