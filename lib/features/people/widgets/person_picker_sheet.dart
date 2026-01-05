import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:provider/provider.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';

class PersonPickerSheet extends StatefulWidget {
  final Person? selectedPerson;
  final Function(Person?) onSelected;
  final ScrollController scrollController;

  const PersonPickerSheet({
    super.key,
    this.selectedPerson,
    required this.onSelected,
    required this.scrollController,
  });

  @override
  State<PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<PersonPickerSheet> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  List<fc.Contact> _matchingContacts = [];
  bool _isLoadingContacts = false;
  bool _contactsPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkContactsPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkContactsPermission() async {
    final granted = await fc.FlutterContacts.requestPermission(readonly: true);
    setState(() {
      _contactsPermissionGranted = granted;
    });
  }

  Future<void> _requestContactsPermission() async {
    final granted = await fc.FlutterContacts.requestPermission();
    setState(() {
      _contactsPermissionGranted = granted;
    });
    if (granted) {
      _pickExternalContact();
    }
  }

  Future<void> _pickExternalContact() async {
    FocusScope.of(context).unfocus();
    // Give it a frame to unfocus
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final fc.Contact? contact = await fc.FlutterContacts.openExternalPick();
      if (contact != null) {
        _handleContactPick(contact);
      }
    } catch (e) {
      debugPrint("Error picking contact: $e");
    }
  }

  Future<void> _searchContacts(String query) async {
    if (!_contactsPermissionGranted || query.isEmpty) {
      setState(() {
        _matchingContacts = [];
        _isLoadingContacts = false;
      });
      return;
    }

    setState(() => _isLoadingContacts = true);

    try {
      final contacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
      );
      final filtered = contacts.where((contact) {
        final nameMatch = contact.displayName.toLowerCase().contains(
          query.toLowerCase(),
        );
        return nameMatch;
      }).toList();

      if (mounted) {
        setState(() {
          _matchingContacts = filtered;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peopleProvider = Provider.of<PeopleProvider>(context);
    final existingPeople = peopleProvider.people;

    final filteredExisting = existingPeople.where((p) {
      return p.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Person',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.selectedPerson != null)
                  TextButton.icon(
                    onPressed: () {
                      widget.onSelected(null);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text("Clear"),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search name or contact...",
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = "";
                              _matchingContacts = [];
                            });
                          },
                        )
                      : IconButton(
                          icon: Icon(
                            _contactsPermissionGranted
                                ? Icons.contacts_rounded
                                : Icons.contact_page_outlined,
                            size: 20,
                          ),
                          onPressed: _contactsPermissionGranted
                              ? _pickExternalContact
                              : _requestContactsPermission,
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _searchContacts(v);
                },
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty && filteredExisting.isEmpty) {
                    _createNewAndSelect(v.trim());
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          Flexible(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                if (_searchQuery.isNotEmpty &&
                    !filteredExisting.any(
                      (p) =>
                          p.fullName.toLowerCase() ==
                          _searchQuery.trim().toLowerCase(),
                    ))
                  ListTile(
                    leading: Icon(
                      Icons.add_circle_outline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      "Add \"$_searchQuery\"",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _createNewAndSelect(_searchQuery.trim()),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                if (filteredExisting.isNotEmpty) ...[
                  _buildSectionHeader(theme, "APP CONTACTS"),
                  const SizedBox(height: 8),
                  ...filteredExisting.map(
                    (p) => _PersonListTile(
                      person: p,
                      isSelected: widget.selectedPerson?.id == p.id,
                      onTap: () {
                        widget.onSelected(p);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_searchQuery.isNotEmpty) ...[
                  _buildSectionHeader(theme, "SYSTEM CONTACTS"),
                  const SizedBox(height: 8),
                  if (!_contactsPermissionGranted)
                    _PermissionRequestCard(
                      onRequest: _requestContactsPermission,
                    )
                  else if (_isLoadingContacts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_matchingContacts.isEmpty && _searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No matching system contacts",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  else
                    ..._matchingContacts.map(
                      (contact) => _ContactListTile(
                        contact: contact,
                        onTap: () => _handleContactPick(contact),
                      ),
                    ),
                ],

                if (_searchQuery.isEmpty &&
                    filteredExisting.isEmpty &&
                    !peopleProvider.people.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 64,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Start typing to find or add people",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  void _createNewAndSelect(String name) async {
    final peopleProvider = Provider.of<PeopleProvider>(context, listen: false);
    final newPerson = await peopleProvider.addPerson(
      Person(id: '', fullName: name),
    );
    widget.onSelected(newPerson);
    if (mounted) Navigator.pop(context);
  }

  void _handleContactPick(fc.Contact contact) async {
    final peopleProvider = Provider.of<PeopleProvider>(context, listen: false);
    final newPerson = await peopleProvider.addPerson(
      Person(
        id: '',
        fullName: contact.displayName,
        email: contact.emails.isNotEmpty ? contact.emails.first.address : null,
      ),
    );
    widget.onSelected(newPerson);
    if (mounted) Navigator.pop(context);
  }
}

class _PersonListTile extends StatelessWidget {
  final Person person;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonListTile({
    required this.person,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          person.fullName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        person.fullName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ContactListTile extends StatelessWidget {
  final fc.Contact contact;
  final VoidCallback onTap;

  const _ContactListTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.person_outline, size: 20),
      ),
      title: Text(contact.displayName),
      subtitle: contact.phones.isNotEmpty
          ? Text(contact.phones.first.number, style: theme.textTheme.bodySmall)
          : null,
      trailing: const Icon(Icons.add_rounded, size: 20),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _PermissionRequestCard extends StatelessWidget {
  final VoidCallback onRequest;

  const _PermissionRequestCard({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.contacts_rounded, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            "Access system contacts to find people quickly",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRequest, child: const Text("Allow Access")),
        ],
      ),
    );
  }
}
