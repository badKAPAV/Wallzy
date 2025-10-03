import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/styled_form_fields.dart'; // For Styled Widgets

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? subscription;

  const AddSubscriptionScreen({super.key, this.subscription});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  SubscriptionFrequency _selectedFrequency = SubscriptionFrequency.monthly;
  DateTime _selectedDate = DateTime.now();
  SubscriptionCreationMode _creationMode = SubscriptionCreationMode.manual;
  SubscriptionNotificationTiming _notificationTiming =
      SubscriptionNotificationTiming.onDueDate;
  bool _createFirstTransaction = true;
  Person? _selectedPerson;

  bool get _isEditing => widget.subscription != null;
  final _paymentMethods = ["Cash", "Card", "UPI", "Net banking", "Other"];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final sub = widget.subscription!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toStringAsFixed(0);
      _selectedCategory = sub.category;
      _selectedPaymentMethod = sub.paymentMethod;
      _selectedFrequency = sub.frequency;
      _selectedDate = sub.nextDueDate;
      _creationMode = sub.creationMode;
      _notificationTiming = sub.notificationTiming;
      _selectedPerson = sub.people?.isNotEmpty == true ? sub.people!.first : null;
      _createFirstTransaction = false; // Don't re-create transaction on edit
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;

    final subProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final subscription = Subscription(
      id: _isEditing ? widget.subscription!.id : const Uuid().v4(),
      name: _nameController.text.trim(),
      amount: amount,
      category: _selectedCategory!,
      paymentMethod: _selectedPaymentMethod!,
      frequency: _selectedFrequency,
      nextDueDate: _selectedDate,
      creationMode: _creationMode,
      notificationTiming: _notificationTiming,
      people: _selectedPerson != null ? [_selectedPerson!] : null,
    );

    if (_isEditing) {
      await subProvider.updateSubscription(subscription);
    } else {
      await subProvider.addSubscription(subscription);
      if (_createFirstTransaction) {
        final newTransaction = TransactionModel(
          transactionId: const Uuid().v4(),
          type: 'expense',
          amount: subscription.amount,
          timestamp: subscription.nextDueDate,
          description: subscription.name,
          paymentMethod: subscription.paymentMethod,
          category: subscription.category,
          subscriptionId: subscription.id,
          people: subscription.people,
          currency: 'INR',
        );
        await txProvider.addTransaction(newTransaction);
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Subscription' : 'New Subscription'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StyledTextField(
              controller: _nameController,
              label: 'Subscription Name (e.g., Netflix)',
              icon: Icons.description_rounded,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
            ),
            const SizedBox(height: 16),
            StyledPickerField(
              icon: Icons.category_rounded,
              label: 'Category',
              value: _selectedCategory,
              onTap: () => _showPicker(
                title: 'Select Category',
                items: TransactionCategories.expense,
                selectedValue: _selectedCategory,
                onSelected: (val) {
                  setState(() {
                    _selectedCategory = val;
                    if (val == 'People') {
                      _showPeopleModal();
                    } else {
                      _selectedPerson = null;
                    }
                  });
                },
              ),
            ),
            if (_selectedCategory == 'People') ...[
              const SizedBox(height: 16),
              StyledPickerField(
                icon: Icons.person_rounded,
                label: 'Select a person',
                value: _selectedPerson?.fullName,
                onTap: _showPeopleModal,
                isError: _selectedPerson == null,
              ),
            ],
            const SizedBox(height: 16),
            StyledPickerField(
              icon: Icons.credit_card_rounded,
              label: 'Payment Method',
              value: _selectedPaymentMethod,
              onTap: () => _showPicker(
                title: 'Select Payment Method',
                items: _paymentMethods,
                selectedValue: _selectedPaymentMethod,
                onSelected: (val) => setState(() => _selectedPaymentMethod = val),
              ),
            ),
            const SizedBox(height: 16),
            StyledPickerField(
              icon: Icons.repeat_rounded,
              label: 'Frequency',
              value: _selectedFrequency.displayName,
              onTap: () => _showPicker(
                title: 'Select Frequency',
                items: SubscriptionFrequency.values.map((e) => e.displayName).toList(),
                selectedValue: _selectedFrequency.displayName,
                onSelected: (val) => setState(() => _selectedFrequency =
                    SubscriptionFrequency.values.firstWhere((e) => e.displayName == val)),
              ),
            ),
            const SizedBox(height: 16),
            StyledPickerField(
              icon: Icons.calendar_today_rounded,
              label: 'First/Next Due Date',
              value: DateFormat('d MMMM, yyyy').format(_selectedDate),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            Text('Options', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            StyledPickerField(
              icon: Icons.auto_awesome_rounded,
              label: 'Creation Mode',
              value: _creationMode.displayName,
              onTap: () => _showPicker(
                title: 'Select Creation Mode',
                items: SubscriptionCreationMode.values.map((e) => e.displayName).toList(),
                selectedValue: _creationMode.displayName,
                onSelected: (val) => setState(() => _creationMode = SubscriptionCreationMode.values.firstWhere((e) => e.displayName == val)),
              ),
            ),
            const SizedBox(height: 16),
            StyledPickerField(
              icon: Icons.notifications_active_rounded,
              label: 'Reminder Timing',
              value: _notificationTiming.displayName,
              onTap: () => _showPicker(
                title: 'Select Reminder Timing',
                items: SubscriptionNotificationTiming.values.map((e) => e.displayName).toList(),
                selectedValue: _notificationTiming.displayName,
                onSelected: (val) => setState(() => _notificationTiming = SubscriptionNotificationTiming.values.firstWhere((e) => e.displayName == val)),
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Create first transaction'),
                value: _createFirstTransaction,
                onChanged: (val) => setState(() => _createFirstTransaction = val),
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _saveSubscription,
          child: Text(_isEditing ? 'Save Changes' : 'Save Subscription'),
        ),
      ),
    );
  }

  Future<void> _showPicker({
    required String title,
    required List<String> items,
    required ValueChanged<String> onSelected,
    String? selectedValue,
  }) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index];
                  final isSelected = item == selectedValue;
                  return ListTile(
                    title: Text(item),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : null,
                    tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                    onTap: () => Navigator.pop(ctx, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      onSelected(selected);
    }
  }

  // Returns true if a contact was picked and a person was created.
  Future<bool> _pickContact() async {
    // Hide keyboard before opening picker
    FocusScope.of(context).unfocus();

    final status = await Permission.contacts.request();

    if (status.isGranted) {
      final fc.Contact? contact = await fc.FlutterContacts.openExternalPick();

      if (contact != null) {
        if (!mounted) return false;
        final peopleProvider =
            Provider.of<PeopleProvider>(context, listen: false);
        final newPerson = await peopleProvider.addPerson(Person(
          id: '',
          fullName: contact.displayName,
          email:
              contact.emails.isNotEmpty ? contact.emails.first.address : null,
        ));
        setState(() => _selectedPerson = newPerson);
        return true;
      }
    } else if (status.isDenied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact permission was denied.')),
      );
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Contact permission permanently denied. Please enable it in settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }
    return false;
  }

  Future<void> _showPeopleModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = "";

        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
              return Consumer<PeopleProvider>(
                builder: (context, peopleProvider, _) {
                  final people = peopleProvider.people;
                  final filtered = people
                      .where((p) =>
                          p.fullName.toLowerCase().contains(query.toLowerCase()))
                      .toList();
                  return Container(
                    padding: const EdgeInsets.all(16),
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Column(
                      children: [
                        Text('Select Person',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                              hintText: "Search or add people...",
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.contact_phone_rounded),
                                tooltip: 'Import from contacts',
                                onPressed: () async {
                                  final picked = await _pickContact();
                                  if (picked && mounted) {
                                    Navigator.pop(ctx);
                                  }
                                },
                              ),
                              prefixIcon: const Icon(Icons.search)),
                          onChanged: (val) {
                            setModalState(() {
                              query = val;
                            });
                          },
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length + 1,
                            itemBuilder: (listCtx, i) {
                              if (i < filtered.length) {
                                final person = filtered[i];
                                final isSelected =
                                    _selectedPerson?.id == person.id;
                                return ListTile(
                                  title: Text(person.fullName),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        )
                                      : null,
                                  tileColor: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.5)
                                      : null,
                                  onTap: () {
                                    setState(() => _selectedPerson = person);
                                    Navigator.pop(ctx);
                                  },
                                );
                              } else if (query.isNotEmpty &&
                                  !people.any((p) =>
                                      p.fullName.toLowerCase() ==
                                      query.toLowerCase())) {
                                return ListTile(
                                  title: Text("Add \"$query\""),
                                  leading: const Icon(Icons.add),
                                  onTap: () async {
                                    final newPerson =
                                        await peopleProvider.addPerson(
                                            Person(id: '', fullName: query));
                                    setState(() => _selectedPerson = newPerson);
                                    Navigator.pop(ctx);
                                  },
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}