import 'package:flutter/material.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tips and Hints"),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero / Intro Section
              _buildIntroSection(theme),
              const SizedBox(height: 24),

              // 2. Guide Sections
              _GuideSection(
                icon: Icons.account_balance_wallet_rounded,
                title: "Managing Accounts",
                accentColor: Colors.blueAccent,
                children: const [
                  _GuideStep(
                    isLast: false,
                    number: 1,
                    text:
                        "Go to the 'Accounts' screen or long press '+ Create' on the dashboard.",
                  ),
                  _GuideStep(
                    isLast: false,
                    number: 2,
                    text: "Tap '+ Account' to add a debit or credit account.",
                  ),
                  _GuideStep(
                    isLast: true,
                    number: 3,
                    text:
                        "Enter your current balance. The app will now auto-detect transactions from SMS (if enabled).",
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _GuideSection(
                icon: Icons.swap_horiz_rounded,
                title: "Tracking Transactions",
                accentColor: Colors.green,
                children: const [
                  _GuideStep(
                    isLast: false,
                    number: 1,
                    text:
                        "Tap the floating '+ Create' button on the dashboard.",
                  ),
                  _GuideStep(
                    isLast: false,
                    number: 2,
                    text: "Select 'Expense', 'Income', or 'Transfer'.",
                  ),
                  _GuideStep(
                    isLast: true,
                    number: 3,
                    text:
                        "Enable 'Auto Save' in settings to magically log transactions from SMS.",
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- RENAMED: Subscriptions -> Recurring Payments ---
              _GuideSection(
                icon: Icons.event_repeat_rounded, // Changed Icon
                title: "Recurring Payments", // Changed Title
                accentColor: Colors.tealAccent,
                children: const [
                  _GuideStep(
                    isLast: false,
                    number: 1,
                    text:
                        "Go to 'Recurring Payments' from the drawer to track regular bills like rent, Netflix, or EMIs.",
                  ),
                  _GuideStep(
                    isLast: false,
                    number: 2,
                    text:
                        "Set up the frequency (e.g., Monthly), amount, and the next due date.",
                  ),
                  _GuideStep(
                    isLast: true,
                    number: 3,
                    text:
                        "Get notified before a payment is due so you never miss a date.",
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- RENAMED: Tags -> Folders ---
              _GuideSection(
                icon: Icons.folder_rounded, // Changed Icon
                title: "Using Folders", // Changed Title
                accentColor: Colors.amber, // Changed color to distinct it
                children: const [
                  _GuideStep(
                    isLast: false,
                    number: 1,
                    text:
                        "Folders help you organize transactions (e.g., 'London Trip') across different categories.",
                  ),
                  _GuideStep(
                    isLast: false,
                    number: 2,
                    text:
                        "Add a transaction to a folder while creating it, or manage your folders in the dedicated tab.",
                  ),
                  _GuideStep(
                    isLast: true,
                    number: 3,
                    text:
                        "Filter reports by specific folders to see total spending for specific projects or events.",
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _GuideSection(
                icon: Icons.people_rounded,
                title: "People & Debts",
                accentColor: Colors.orange,
                children: const [
                  _GuideStep(
                    isLast: false,
                    number: 1,
                    text: "Track who owes you money or who you owe.",
                  ),
                  _GuideStep(
                    isLast: false,
                    number: 2,
                    text:
                        "Select a person when logging a transaction to link it to them.",
                  ),
                  _GuideStep(
                    isLast: true,
                    number: 3,
                    text:
                        "Check the 'Debts & Loans' tab for a net summary of all your peer-to-peer finances.",
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _GuideSection(
                icon: Icons.pie_chart_rounded,
                title: "Reports & Insights",
                accentColor: Colors.purpleAccent,
                children: const [
                  _GuideStep(
                    isLast: false,
                    number: 1,
                    text:
                        "Visit the 'Reports' tab to visualize your cash flow.",
                  ),
                  _GuideStep(
                    isLast: true,
                    number: 2,
                    text:
                        "Filter by Date, Category, or Account to find exactly where your money went.",
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                "Welcome to ledgr",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'momo',
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Learn how to make the most out of ledgr and make your financial life easier and easier to understand.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reused Widgets (Keep these in the file or import them if separated)
// ---------------------------------------------------------------------------

class _GuideSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final List<Widget> children;

  const _GuideSection({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: children,
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int number;
  final String text;
  final bool isLast;

  const _GuideStep({
    required this.number,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Column
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Text(
                  number.toString(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.surfaceContainerHighest,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0, bottom: 16.0),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
