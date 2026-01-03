import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/people/widgets/debts_loans_view.dart';
import 'package:wallzy/features/people/widgets/payments_view.dart';
import 'package:wallzy/features/people/screens/add_debt_loan_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  Future<void> _addPersonManually() async {
    String? fullName;
    String? email;
    String? nickname;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Full Name*'),
              onChanged: (value) => fullName = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Email (Optional)'),
              onChanged: (value) => email = value,
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nickname (Optional)',
              ),
              onChanged: (value) => nickname = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (fullName != null && fullName!.isNotEmpty) {
                final peopleProvider = Provider.of<PeopleProvider>(
                  context,
                  listen: false,
                );
                final newPerson = Person(
                  id: const Uuid().v4(), // Generate a new ID
                  fullName: fullName!,
                  email: email,
                  nickname: nickname,
                );
                await peopleProvider.addPerson(newPerson);
                if (mounted) Navigator.pop(context);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Full Name is required.')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          IconButton(
            onPressed: _addPersonManually,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            icon: const Icon(Icons.import_contacts),
            onPressed: _importContacts,
          ),
        ],
        bottom: TabBar(
          unselectedLabelStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal),
          indicatorWeight: 5,
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(25),
          ),
          indicatorPadding: const EdgeInsets.fromLTRB(0, 45, 0, 0),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          controller: _tabController,
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withAlpha(150),
          tabs: const [
            Tab(text: 'Debts & Loans'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: const [DebtsLoansView(), PaymentsView()],
      ),
      floatingActionButton: _buildGlassFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildGlassFab(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDebtLoanScreen()),
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "Loan/Debt",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                    letterSpacing: 0.5,
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
