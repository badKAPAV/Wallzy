import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

// --- DATA MODELS ---
class TipData {
  final String title;
  final String description;
  final dynamic icon; // Fixed type mismatch
  final Color color;

  TipData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class GuideData {
  final String title;
  final dynamic icon; // Fixed type mismatch
  final List<String> steps;

  GuideData({required this.title, required this.icon, required this.steps});
}

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  // ---------------------------------------------------------------------------
  // 1. CONFIGURE YOUR TIPS HERE
  // ---------------------------------------------------------------------------
  static final List<TipData> _tips = [
    TipData(
      title: "Privacy First",
      description:
          "Ledgr is offline-first. Works everywhere evertime without fail. We don't see your bank balance, only what you track.",
      icon: HugeIcons.strokeRoundedSecurityCheck,
      color: Colors.green,
    ),
    TipData(
      title: "Magic Automation",
      description:
          "Enable 'AutoSave' in Settings. We use your transaction SMS alerts and save the details for you instantly.",
      icon: HugeIcons.strokeRoundedAiMagic,
      color: Colors.purple,
    ),
    TipData(
      title: "Smart Folders",
      description:
          "Use Folders to group expenses across categories. A 'Bali Trip' folder can contain Food, Flight, and Shopping expenses all in one place. \nNo more searching for expenses aimlessly.",
      icon: HugeIcons.strokeRoundedFolder01,
      color: Colors.amber,
    ),
    TipData(
      title: "Currency converter",
      description:
          "Traveling? Use the Currency Converter in Settings to check rates offline based on the last time you had internet.",
      icon: HugeIcons.strokeRoundedGlobal,
      color: Colors.blue,
    ),
  ];

  // ---------------------------------------------------------------------------
  // 2. CONFIGURE YOUR GUIDES HERE
  // ---------------------------------------------------------------------------
  static final List<GuideData> _guides = [
    GuideData(
      title: "Setting up Accounts",
      icon: HugeIcons.strokeRoundedWallet02,
      steps: [
        "Go to the 'Accounts' screen or tap '+ Create' > 'Account'.",
        "Add your Bank, Credit Card, or Cash wallet.",
        "Set the initial balance. This is crucial for accurate net worth tracking.",
      ],
    ),
    GuideData(
      title: "Tracking Transactions",
      icon: HugeIcons.strokeRoundedInvoice03,
      steps: [
        "Tap the big '+ Create' button on the home screen.",
        "Choose Income, Expense, or Transfer (moving money between accounts).",
        "Attach a photo of the receipt if you want to keep proof.",
      ],
    ),
    GuideData(
      title: "Recurring Payments",
      icon: HugeIcons.strokeRoundedCalendar03,
      steps: [
        "Perfect for Netflix, Rent, or EMIs.",
        "Set the frequency (e.g., Monthly) and the next due date.",
        "Ledgr will remind you before the money leaves your account.",
      ],
    ),
    GuideData(
      title: "Managing Debts and Loans",
      icon: HugeIcons.strokeRoundedUserGroup,
      steps: [
        "Lent money to a friend? Split a dinner bill?",
        "Create a transaction and link a 'Person' to it.",
        "Check the 'Debts' tab to see a running total of who owes you what.",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Using Ledgr the right way"),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: PRO TIPS CAROUSEL ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text(
                "PRO TIPS",
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            SizedBox(
              height: 180, // Height of the cards
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _tips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _TipCard(tip: _tips[index]),
              ),
            ),

            const SizedBox(height: 32),

            // --- SECTION 2: THE BASICS (MANUAL) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "THE BASICS",
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._guides.map((guide) => _GuideTile(guide: guide)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGET: Tip Card (The colorful horizontal cards)
// ---------------------------------------------------------------------------
class _TipCard extends StatelessWidget {
  final TipData tip;

  const _TipCard({required this.tip});

  void _showTipDetails(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow it to be taller if text is long
      backgroundColor: theme.colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tip.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: tip.icon, size: 48, color: tip.color),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                tip.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                tip.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Close Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: tip.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Got it!",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? tip.color.withAlpha(30)
        : tip.color.withAlpha(20);
    final borderColor = tip.color.withAlpha(50);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      // Use Material & InkWell for the tap effect without breaking rounded corners
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTipDetails(context),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tip.color.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: tip.icon,
                        color: tip.color,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons
                          .open_in_full_rounded, // Changed icon to indicate action
                      size: 18,
                      color: tip.color.withOpacity(0.6),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  tip.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGET: Guide Tile (The expandable list items)
// ---------------------------------------------------------------------------
class _GuideTile extends StatelessWidget {
  final GuideData guide;

  const _GuideTile({required this.guide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias, // IMPORTANT for rounded ripple
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: HugeIcon(
                icon: guide.icon,
                color: theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            title: Text(
              guide.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(guide.steps.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${index + 1}.",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            guide.steps[index],
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
