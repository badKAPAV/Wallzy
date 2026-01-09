import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/people/screens/person_transactions_screen.dart';

class AllPeopleScreen extends StatefulWidget {
  const AllPeopleScreen({super.key});

  @override
  State<AllPeopleScreen> createState() => _AllPeopleScreenState();
}

class _AllPeopleScreenState extends State<AllPeopleScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _importContacts() async {
    final status = await Permission.contacts.request();

    if (status.isGranted) {
      final fc.Contact? contact = await fc.FlutterContacts.openExternalPick();

      if (contact != null) {
        if (!mounted) return;
        final peopleProvider = Provider.of<PeopleProvider>(
          context,
          listen: false,
        );
        final exists = peopleProvider.people.any(
          (p) => p.fullName.toLowerCase() == contact.displayName.toLowerCase(),
        );

        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${contact.displayName}" already exists.')),
          );
        } else {
          final newPerson = Person(
            id: const Uuid().v4(),
            fullName: contact.displayName,
            email: contact.emails.isNotEmpty
                ? contact.emails.first.address
                : null,
          );
          await peopleProvider.addPerson(newPerson);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${contact.displayName}" to your people.'),
            ),
          );
        }
      }
    } else if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact permission denied.')),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Contact permission permanently denied. Please enable from settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleProvider = Provider.of<PeopleProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final query = _searchController.text.toLowerCase();
    final filteredPeople =
        peopleProvider.people.where((p) {
          return p.fullName.toLowerCase().contains(query) ||
              (p.nickname?.toLowerCase().contains(query) ?? false);
        }).toList()..sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search people...',
                  border: InputBorder.none,
                ),
                style: theme.textTheme.bodyLarge,
              )
            : const Text('All People'),
        actions: [
          IconButton.filledTonal(
            icon: HugeIcon(
              icon: _isSearching
                  ? HugeIcons.strokeRoundedCancel01
                  : HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
              size: 18,
            ),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Import Contacts Container
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: _importContacts,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primaryContainer.withAlpha(100),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.contact_phone_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Import your contacts",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // List of People
          Expanded(
            child: filteredPeople.isEmpty
                ? const EmptyReportPlaceholder(
                    message: "No one found here yet",
                    icon: HugeIcons.strokeRoundedUserMultiple,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredPeople.length,
                    itemBuilder: (context, index) {
                      final person = filteredPeople[index];
                      // Calculate Sent/Received for this person
                      final sent = txProvider.transactions
                          .where(
                            (tx) =>
                                tx.type == 'expense' &&
                                (tx.people?.any((p) => p.id == person.id) ??
                                    false),
                          )
                          .fold(0.0, (sum, tx) => sum + tx.amount);

                      final received = txProvider.transactions
                          .where(
                            (tx) =>
                                tx.type == 'income' &&
                                (tx.people?.any((p) => p.id == person.id) ??
                                    false),
                          )
                          .fold(0.0, (sum, tx) => sum + tx.amount);

                      return _PersonListTile(
                        person: person,
                        sent: sent,
                        received: received,
                        currencySymbol: settingsProvider.currencySymbol,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PersonListTile extends StatelessWidget {
  final Person person;
  final double sent;
  final double received;
  final String currencySymbol;

  const _PersonListTile({
    required this.person,
    required this.sent,
    required this.received,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonTransactionsScreen(
                person: person,
                transactionType: 'expense', // Default to expense
                initialSelectedDate: DateTime.now(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withAlpha(30),
                child: Text(
                  person.fullName.isNotEmpty
                      ? person.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (person.nickname != null && person.nickname!.isNotEmpty)
                      Text(
                        person.nickname!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sent: ",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        currencyFormat.format(sent),
                        style: TextStyle(
                          color:
                              theme.extension<AppColors>()?.expense ??
                              Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Recv: ",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        currencyFormat.format(received),
                        style: TextStyle(
                          color:
                              theme.extension<AppColors>()?.income ??
                              Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outline.withAlpha(100),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
