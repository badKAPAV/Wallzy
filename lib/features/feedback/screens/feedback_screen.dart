import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/feedback/models/feedback_model.dart';
import 'package:wallzy/features/feedback/models/sms_feedback_model.dart';
import 'package:wallzy/features/feedback/provider/feedback_provider.dart';
import 'package:wallzy/features/feedback/provider/sms_feedback_provider.dart';
import 'package:wallzy/features/feedback/screens/add_feedback_screen.dart';
import 'package:wallzy/features/feedback/screens/add_sms_feedback_screen.dart';
import 'package:wallzy/features/feedback/widgets/feedback_details_modal_sheet.dart';
import 'package:wallzy/features/feedback/widgets/sms_feedback_details_modal_sheet.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).user?.uid;
      if (userId != null) {
        Provider.of<FeedbackProvider>(
          context,
          listen: false,
        ).fetchUserFeedbacks(userId);
        Provider.of<SmsFeedbackProvider>(
          context,
          listen: false,
        ).fetchUserSmsRequests(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedbackProvider = Provider.of<FeedbackProvider>(context);
    final smsProvider = Provider.of<SmsFeedbackProvider>(context);

    // Combine and sort feedbacks
    final List<dynamic> combinedFeedbacks =
        [...feedbackProvider.feedbacks, ...smsProvider.smsRequests]
          ..sort((a, b) {
            DateTime timeA = (a is FeedbackModel)
                ? a.timestamp
                : (a as SmsFeedbackModel).timestamp;
            DateTime timeB = (b is FeedbackModel)
                ? b.timestamp
                : (b as SmsFeedbackModel).timestamp;
            return timeB.compareTo(timeA);
          });

    final isLoading = feedbackProvider.isLoading || smsProvider.isLoading;

    // No Internet State
    if (!feedbackProvider.hasInternet) {
      return Scaffold(
        appBar: AppBar(title: const Text("Feedback")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedWifiOff01,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                "No Internet Connection",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text("Connect to the internet to view or submit feedback."),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () =>
                    feedbackProvider.checkConnectivity().then((hasNet) {
                      if (hasNet && mounted) {
                        final userId = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).user?.uid;
                        if (userId != null) {
                          feedbackProvider.fetchUserFeedbacks(userId);
                          smsProvider.fetchUserSmsRequests(userId);
                        }
                      }
                    }),
                child: const Text("Try Again"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Your Feedback")),
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          // Big Create Button Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _FeedbackActionTile(
                      title: "Submit Feedback",
                      subtitle: "Bugs & Features",
                      icon: HugeIcons.strokeRoundedMessageDone01,
                      color: theme.colorScheme.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddFeedbackScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeedbackActionTile(
                      title: "Report SMS Issue",
                      subtitle: "Train our Parser",
                      icon: HugeIcons.strokeRoundedMessageQuestion,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddSmsTemplateScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List Title
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                "PREVIOUS SUBMISSIONS",
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          // List Items
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (combinedFeedbacks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyReportPlaceholder(
                message: 'Your feedbacks will appear here',
                icon: HugeIcons.strokeRoundedBubbleChat,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = combinedFeedbacks[index];
                return _FeedbackListTile(item: item);
              }, childCount: combinedFeedbacks.length),
            ),

          SliverToBoxAdapter(child: const SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _FeedbackActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final Color color;
  final VoidCallback onTap;

  const _FeedbackActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackListTile extends StatelessWidget {
  final dynamic item;
  const _FeedbackListTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool isSms = item is SmsFeedbackModel;
    final String title = isSms
        ? (item as SmsFeedbackModel).bankName
        : (item as FeedbackModel).title;
    final String topic = isSms ? "SMS Parsing" : (item as FeedbackModel).topic;
    final String status = isSms
        ? (item as SmsFeedbackModel).status
        : (item as FeedbackModel).status;
    final DateTime timestamp = isSms
        ? (item as SmsFeedbackModel).timestamp
        : (item as FeedbackModel).timestamp;

    // Status Color Logic
    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'reviewed':
        statusColor = Colors.orange;
        statusIcon = Icons.visibility_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(76),
        ),
      ),
      child: ListTile(
        onTap: () {
          if (isSms) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => SmsFeedbackDetailsModalSheet(
                report: item as SmsFeedbackModel,
              ),
            );
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) =>
                  FeedbackDetailsModalSheet(feedback: item as FeedbackModel),
            );
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: HugeIcon(
            icon: isSms
                ? HugeIcons.strokeRoundedMessageQuestion
                : (topic == 'Feature Request'
                      ? HugeIcons.strokeRoundedIdea01
                      : HugeIcons.strokeRoundedBug02),
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                // Type Tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSms
                        ? Colors.orange.withOpacity(0.1)
                        : (topic == 'Bug'
                              ? Colors.red.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    topic.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isSms
                          ? Colors.orange
                          : (topic == 'Bug' ? Colors.red : Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d').format(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
