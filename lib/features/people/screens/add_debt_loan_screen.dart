import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';

class AddDebtLoanScreen extends StatefulWidget {
  final Person? initialPerson;

  const AddDebtLoanScreen({super.key, this.initialPerson});

  @override
  State<AddDebtLoanScreen> createState() => _AddDebtLoanScreenState();
}

class _AddDebtLoanScreenState extends State<AddDebtLoanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Record Payment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              splashBorderRadius: BorderRadius.circular(25),
              tabs: const [
                Tab(
                  child: _TabLabel(title: "Debt", subtitle: "You'll owe them"),
                ),
                Tab(
                  child: _TabLabel(title: "Loan", subtitle: "They'll owe you"),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          _DebtLoanForm(isDebt: true, initialPerson: widget.initialPerson),
          _DebtLoanForm(isDebt: false, initialPerson: widget.initialPerson),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TabLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.normal),
        ),
      ],
    );
  }
}

class _DebtLoanForm extends StatefulWidget {
  final bool isDebt;
  final Person? initialPerson;

  const _DebtLoanForm({required this.isDebt, this.initialPerson});

  @override
  State<_DebtLoanForm> createState() => _DebtLoanFormState();
}

class _DebtLoanFormState extends State<_DebtLoanForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Person? _selectedPerson;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.initialPerson;
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPerson == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a person.')));
      return;
    }

    setState(() => _isSaving = true);
    final peopleProvider = Provider.of<PeopleProvider>(context, listen: false);

    // Calculate Debt Simplification
    final amount = double.parse(_amountController.text);
    Person p = _selectedPerson!;

    // Net amount: +ve means I owe them (YouOwe), -ve means They owe me (OwesYou)
    double currentNet = p.youOwe - p.owesYou;

    // Impact of this transaction
    // If it's a Debt (I owe them), we ADD to the net.
    // If it's a Loan (They owe me), we SUBTRACT from the net.
    double change = widget.isDebt ? amount : -amount;

    double newNet = currentNet + change;

    double newYouOwe = newNet > 0 ? newNet : 0;
    double newOwesYou = newNet < 0 ? newNet.abs() : 0;

    final updatedPerson = p.copyWith(youOwe: newYouOwe, owesYou: newOwesYou);

    try {
      await peopleProvider.updatePerson(updatedPerson);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _pickContact() async {
    FocusScope.of(context).unfocus();
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      final fc.Contact? contact = await fc.FlutterContacts.openExternalPick();
      if (contact != null && mounted) {
        final peopleProvider = Provider.of<PeopleProvider>(
          context,
          listen: false,
        );
        final newPerson = await peopleProvider.addPerson(
          Person(
            id: '',
            fullName: contact.displayName,
            email: contact.emails.isNotEmpty
                ? contact.emails.first.address
                : null,
          ),
        );
        setState(() {
          _selectedPerson = newPerson;
        });
        return true;
      }
    }
    return false;
  }

  void _showPersonPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = "";
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
              return Consumer<PeopleProvider>(
                builder: (context, peopleProvider, _) {
                  final people = peopleProvider.people;
                  final filtered = people
                      .where(
                        (p) => p.fullName.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList();
                  return Container(
                    padding: const EdgeInsets.all(16),
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Column(
                      children: [
                        Text(
                          'Select Person',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Search...",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.contacts),
                              onPressed: () async {
                                final picked = await _pickContact();
                                if (picked && mounted) Navigator.pop(ctx);
                              },
                            ),
                          ),
                          onChanged: (val) => setModalState(() => query = val),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length + 1,
                            itemBuilder: (listCtx, i) {
                              if (i < filtered.length) {
                                final person = filtered[i];
                                return ListTile(
                                  title: Text(person.fullName),
                                  onTap: () {
                                    setState(() {
                                      _selectedPerson = person;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              } else if (query.isNotEmpty &&
                                  !people.any(
                                    (p) =>
                                        p.fullName.toLowerCase() ==
                                        query.toLowerCase(),
                                  )) {
                                return ListTile(
                                  title: Text("Add \"$query\""),
                                  leading: const Icon(Icons.add),
                                  onTap: () async {
                                    final newPerson = await peopleProvider
                                        .addPerson(
                                          Person(id: '', fullName: query),
                                        );
                                    setState(() {
                                      _selectedPerson = newPerson;
                                    });
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
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isDebt
        ? theme.extension<AppColors>()!.expense
        : theme.extension<AppColors>()!.income;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                _AmountInputHero(controller: _amountController, color: color),
                // const SizedBox(height: 20),
                // Center(
                //   child: _DatePill(
                //     selectedDate: _selectedDate,
                //     onTap: _pickDate,
                //   ),
                // ),
                const SizedBox(height: 32),

                _FunkyPickerTile(
                  icon: Icons.person_outline_rounded,
                  label: "With Person",
                  value: _selectedPerson?.fullName,
                  onTap: _showPersonPicker,
                ),
                // const SizedBox(height: 24),
                // _FunkyTextField(
                //   controller: _descController,
                //   label: "Note (Optional)",
                //   icon: Icons.notes_rounded,
                // ),
              ],
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 4,
                  shadowColor: color.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        widget.isDebt ? 'Record Debt' : 'Record Loan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// --- STYLE WIDGETS (COPIED FOR CONSISTENCY) ---
// --------------------------------------------------------------------------

class _AmountInputHero extends StatelessWidget {
  final TextEditingController controller;
  final Color color;

  const _AmountInputHero({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.8),
                height: 1.2,
              ),
            ),
            const SizedBox(width: 4),
            IntrinsicWidth(
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) =>
                    v == null || v.isEmpty || double.tryParse(v) == 0
                    ? ''
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;

  const _DatePill({required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM d, yyyy').format(selectedDate),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunkyPickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isError;
  final bool isCompact;

  const _FunkyPickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isError = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: isError
              ? Border.all(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? "Select",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: value == null
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class _FunkyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _FunkyTextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.outline),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

// Helper classes for modal
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
                                        ? baseColor.withOpacity(0.8)
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
