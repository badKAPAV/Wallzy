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

  // Step 2 State (Tagging)
  List<String> _smsTokens = [];
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

    // Tokenize SMS for highlighting (split by spaces)
    setState(() {
      _smsTokens = _smsBodyController.text.trim().split(RegExp(r'\s+'));
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

  void _submit() async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) return;

    // Construct the tagged map for backend
    // e.g., "amount": "1500", "payee": "Zomato"
    final Map<String, dynamic> taggedValues = {};

    _taggedIndices.forEach((index, type) {
      if (index < _smsTokens.length) {
        final word = _smsTokens[index];
        // If multiple words are tagged as 'payee', join them?
        // For simple MVP, let's just store specific values or join later.
        // Better: Store exact token value.

        // Append if key exists (for multi-word payee "Starbucks Coffee")
        if (taggedValues.containsKey(type)) {
          taggedValues[type] = "${taggedValues[type]} $word";
        } else {
          taggedValues[type] = word;
        }
      }
    });

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
        taggedData: taggedValues,
      );

      setState(() {
        _isSuccess = true;
      });
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "One report is for one SMS only",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(label: "BANK DETAILS"),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bankController,
            decoration: _inputDecoration(theme, "Bank Name", "e.g. HDFC, SBI"),
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _senderController,
            decoration: _inputDecoration(theme, "Sender ID", "e.g. AD-HDFCBK"),
            validator: (v) => v!.isEmpty ? "Required" : null,
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "For privacy, please replace sensitive numbers (Account No, Ref No) with '5555'. Keep the format exactly same.",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _smsBodyController,
            maxLines: 6,
            decoration: _inputDecoration(
              theme,
              "Paste SMS here",
              "",
            ).copyWith(alignLabelWithHint: true),
            validator: (v) => v!.length < 10 ? "SMS looks too short" : null,
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
              _LegendChip(label: "Amount", color: theme.colorScheme.primary),
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
              if (tagType == 'amount') tagColor = theme.colorScheme.primary;
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
      ],
    );
  }

  void _showTagSelectionSheet(int index, String token) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tag '$token' as...",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedMoney03,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text("Amount"),
              onTap: () {
                Navigator.pop(ctx);
                _toggleTag(index, 'amount');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store_rounded, color: Colors.orange),
              title: const Text("Payee / Merchant Name"),
              onTap: () {
                Navigator.pop(ctx);
                _toggleTag(index, 'payee');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.credit_card_rounded,
                color: Colors.purple,
              ),
              title: const Text("Account Number"),
              onTap: () {
                Navigator.pop(ctx);
                _toggleTag(index, 'account');
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: const Text("Clear Tag"),
              onTap: () {
                Navigator.pop(ctx);
                _toggleTag(index, 'none');
              },
            ),
          ],
        ),
      ),
    );
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
}

// --- SUB-WIDGETS ---

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                    color: Theme.of(context).colorScheme.primaryContainer,
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }
}
