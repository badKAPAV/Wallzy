import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';

class CurrencySelectionScreen extends StatefulWidget {
  final bool isGlobal;
  final String? initialCurrencyCode;
  final String?
  initialIsoCodeNum; // Added for unique highlighting in non-global mode

  const CurrencySelectionScreen({
    super.key,
    this.isGlobal = true,
    this.initialCurrencyCode,
    this.initialIsoCodeNum,
  });

  @override
  State<CurrencySelectionScreen> createState() =>
      _CurrencySelectionScreenState();
}

class _CurrencySelectionScreenState extends State<CurrencySelectionScreen> {
  List<dynamic> _countries = [];
  List<dynamic> _filteredCountries = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _searchController.addListener(_filterCountries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/json/countries.json',
      );
      final List<dynamic> data = json.decode(response);
      setState(() {
        _countries = data;
        _filteredCountries = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading countries: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterCountries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = _countries;
      } else {
        _filteredCountries = _countries.where((country) {
          final name = (country['name'] ?? '').toString().toLowerCase();
          final phoneCode = (country['phoneCode'] ?? '')
              .toString()
              .toLowerCase();
          final currencyCode = (country['currencyCode'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(query) ||
              phoneCode.contains(query) ||
              currencyCode.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Currency"),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search country or currency...",
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: HugeIcon(icon: HugeIcons.strokeRoundedSearch01),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _filteredCountries.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final currencyCode = country['currencyCode'] ?? '';
                final currencySymbol = country['currency'] ?? '';
                final flag = country['flag'] ?? '';
                final name = country['name'] ?? '';

                final isoCodeNum = country['isoCodeNum'] ?? '';

                final isSelected = widget.isGlobal
                    ? (settingsProvider.currencyCode == currencyCode &&
                          settingsProvider.currencyIsoCodeNum == isoCodeNum)
                    : (widget.initialIsoCodeNum != null
                          ? widget.initialIsoCodeNum == isoCodeNum
                          : widget.initialCurrencyCode == currencyCode);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: ListTile(
                    leading: Text(flag, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "$currencyCode ($currencySymbol)",
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: () {
                      if (widget.isGlobal) {
                        settingsProvider.setCurrency(
                          currencyCode,
                          currencySymbol,
                          country['isoCodeNum'] ?? '',
                        );
                        Navigator.pop(context);
                      } else {
                        Navigator.pop(context, {
                          'code': currencyCode,
                          'symbol': currencySymbol,
                          'flag': flag,
                          'name': name,
                          'isoCodeNum': isoCodeNum,
                        });
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
