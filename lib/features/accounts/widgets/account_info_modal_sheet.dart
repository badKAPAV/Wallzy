import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/common/widgets/tile_data_widgets.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';

class AccountInfoModalSheet extends StatelessWidget {
  final Account account;
  final BuildContext passedContext;
  const AccountInfoModalSheet({
    super.key,
    required this.account,
    required this.passedContext,
  });

  void _showDeleteConfirmation(
    BuildContext context,
    BuildContext passedContext,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => ModernAlertDialog(
        title: "Delete Account",
        description: "Are you sure you want to delete this account?",
        icon: HugeIcons.strokeRoundedDelete02,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Future.delayed(const Duration(milliseconds: 150), () {
                if (context.mounted) {
                  Provider.of<AccountProvider>(
                    context,
                    listen: false,
                  ).deleteAccount(account.id);
                  Navigator.pop(context);
                  Navigator.pop(passedContext);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCashAccount = account.bankName.toLowerCase() == 'cash';
    final isCreditAccount = account.accountType == 'credit';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Visual Card
                  _AccountVisualCard(
                    account: account,
                    isCredit: isCreditAccount,
                    isCash: isCashAccount,
                  ),
                  const SizedBox(height: 24),

                  // 2. Action Buttons
                  if (!isCashAccount || !account.isPrimary) ...[
                    Row(
                      children: [
                        if (!account.isPrimary)
                          Expanded(
                            child: ActionBox(
                              label: "Set Primary",
                              icon: Icons.star_outline_rounded,
                              color: colorScheme.primary,
                              onTap: () {
                                Provider.of<AccountProvider>(
                                  context,
                                  listen: false,
                                ).setPrimaryAccount(account.id);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        if (!account.isPrimary && !isCashAccount)
                          const SizedBox(width: 12),
                        if (!isCashAccount)
                          Expanded(
                            child: ActionBox(
                              label: "Edit",
                              icon: Icons.edit_rounded,
                              color: colorScheme.secondary,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddEditAccountScreen(account: account),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (!isCashAccount) const SizedBox(width: 12),
                        if (!isCashAccount)
                          Expanded(
                            child: ActionBox(
                              label: "Delete",
                              icon: Icons.delete_outline_rounded,
                              color: colorScheme.error,
                              onTap: () => _showDeleteConfirmation(
                                context,
                                passedContext,
                              ),
                              isDestructive: true,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 3. Data Grid (Containers for Data)
                  Text(
                    "Account Details",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 1
                  SizedBox(
                    height: 100, // Fixed height for tiles helps alignment
                    child: Row(
                      children: [
                        Expanded(
                          child: DataTile(
                            label: "Bank Name",
                            value: account.bankName,
                            icon: Icons.account_balance_rounded,
                          ),
                        ),
                        if (!isCashAccount) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: DataTile(
                              label: isCreditAccount
                                  ? "Card Number"
                                  : "Account Number",
                              value: account.accountNumber,
                              icon: isCreditAccount
                                  ? Icons.credit_card_rounded
                                  : Icons.tag_rounded,
                              isCopyable: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 2
                  SizedBox(
                    height: 100,
                    child: Row(
                      children: [
                        Expanded(
                          child: DataTile(
                            label: "Account Holder",
                            value: account.accountHolderName,
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        if (!isCashAccount &&
                            (account.cardNumber?.isNotEmpty ?? false)) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: DataTile(
                              label: "Card Number",
                              value: account.cardNumber!,
                              icon: Icons.credit_card_outlined,
                            ),
                          ),
                        ] else if (isCreditAccount) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: DataTile(
                              label: "Credit Limit",
                              value:
                                  "₹${account.creditLimit?.toStringAsFixed(0)}",
                              icon: Icons.speed_rounded,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Row 3 (Credit Only - Billing Cycle)
                  if (isCreditAccount) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: Row(
                        children: [
                          Expanded(
                            child: DataTile(
                              label: "Billing Cycle",
                              value: "Day ${account.billingCycleDay}",
                              icon: Icons.calendar_today_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Spacer(), // Empty space or another metric
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountVisualCard extends StatelessWidget {
  final Account account;
  final bool isCredit;
  final bool isCash;

  const _AccountVisualCard({
    required this.account,
    required this.isCredit,
    required this.isCash,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    LinearGradient bgGradient;
    Color textColor;
    IconData typeIcon;

    if (isCash) {
      bgGradient = LinearGradient(
        colors: [Colors.green.shade700, Colors.teal.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = Colors.white;
      typeIcon = Icons.account_balance_wallet_rounded;
    } else if (isCredit) {
      bgGradient = LinearGradient(
        colors: [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = Colors.white;
      typeIcon = Icons.credit_card_rounded;
    } else {
      bgGradient = LinearGradient(
        colors: [colorScheme.onSurface, colorScheme.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = colorScheme.onPrimary;
      typeIcon = Icons.account_balance_rounded;
    }

    String displayNum = account.accountNumber;
    if (displayNum.isEmpty) {
      displayNum = "----";
    } else if (displayNum.length <= 4) {
      displayNum = "••$displayNum";
    } else if (displayNum.length > 4 && !isCash) {
      displayNum = "••${displayNum.substring(displayNum.length - 4)}";
    }

    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(typeIcon, color: textColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    account.bankName.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              if (account.isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "PRIMARY",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            isCash ? "CASH WALLET" : displayNum,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontFamily: 'Monospace',
              letterSpacing: isCash ? 1.0 : 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                account.accountHolderName.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.nfc_rounded,
                color: textColor.withOpacity(0.7),
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
