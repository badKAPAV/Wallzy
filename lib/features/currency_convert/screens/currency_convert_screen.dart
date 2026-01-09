import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/settings/screens/currency_selection_screen.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  // Controllers
  final TextEditingController _amountController = TextEditingController();

  // State
  String _fromCurrency = 'USD';
  String _toCurrency = 'INR';
  String? _fromIsoCodeNum = '840'; // Default: USA
  String? _toIsoCodeNum = '356'; // Default: India
  double _exchangeRate = 0.0;
  DateTime? _lastUpdated;
  bool _isLoading = true;

  // Currencies list removed as we use the full selector now

  @override
  void initState() {
    super.initState();
    _loadCachedRates();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// 1. Load data from local storage immediately (Offline First)
  Future<void> _loadCachedRates() async {
    final prefs = await SharedPreferences.getInstance();

    // Load persisted ISO codes
    final cachedFromIso = prefs.getString('convert_from_iso_code_num');
    final cachedToIso = prefs.getString('convert_to_iso_code_num');

    if (cachedFromIso != null || cachedToIso != null) {
      try {
        final String response = await rootBundle.loadString(
          'assets/json/countries.json',
        );
        final List<dynamic> countries = json.decode(response);

        if (cachedFromIso != null) {
          final fromCountry = countries.firstWhere(
            (c) => c['isoCodeNum'] == cachedFromIso,
            orElse: () => null,
          );
          if (fromCountry != null) {
            _fromCurrency = fromCountry['currencyCode'];
            _fromIsoCodeNum = cachedFromIso;
          }
        }

        if (cachedToIso != null) {
          final toCountry = countries.firstWhere(
            (c) => c['isoCodeNum'] == cachedToIso,
            orElse: () => null,
          );
          if (toCountry != null) {
            _toCurrency = toCountry['currencyCode'];
            _toIsoCodeNum = cachedToIso;
          }
        }
      } catch (e) {
        debugPrint("Error loading countries for lookup: $e");
      }
    }

    // Try to load cached rate specifically for this pair
    final cachedRate = prefs.getDouble('${_fromCurrency}_$_toCurrency');
    final lastUpdateMillis = prefs.getInt('currency_last_updated');

    if (cachedRate != null && lastUpdateMillis != null) {
      setState(() {
        _exchangeRate = cachedRate;
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdateMillis);
        _isLoading = false;
      });
    }

    // Fetch fresh data in background
    _fetchRates();
  }

  /// 2. Fetch fresh rates from API
  Future<void> _fetchRates() async {
    try {
      // Using a free open API (Exchangerate-API is reliable for this)
      // Replace with your own key if needed for production limits
      final url = Uri.parse(
        'https://api.exchangerate-api.com/v4/latest/$_fromCurrency',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        final newRate = (rates[_toCurrency] as num).toDouble();
        final now = DateTime.now();

        // Cache the result
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('${_fromCurrency}_$_toCurrency', newRate);
        await prefs.setInt('currency_last_updated', now.millisecondsSinceEpoch);

        if (mounted) {
          setState(() {
            _exchangeRate = newRate;
            _lastUpdated = now;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // If offline, we just rely on cached data.
      // If no cache exists, we stop loading but show 0.
      if (mounted && _exchangeRate == 0) {
        setState(() => _isLoading = false);
      }
      debugPrint("Currency fetch error: $e");
    }
  }

  void _swapCurrencies() async {
    HapticFeedback.mediumImpact();
    setState(() {
      final tempCode = _fromCurrency;
      final tempIso = _fromIsoCodeNum;
      _fromCurrency = _toCurrency;
      _fromIsoCodeNum = _toIsoCodeNum;
      _toCurrency = tempCode;
      _toIsoCodeNum = tempIso;
      _isLoading = true;
    });

    // Save swapped preferences
    final prefs = await SharedPreferences.getInstance();
    if (_fromIsoCodeNum != null) {
      await prefs.setString('convert_from_iso_code_num', _fromIsoCodeNum!);
    }
    if (_toIsoCodeNum != null) {
      await prefs.setString('convert_to_iso_code_num', _toIsoCodeNum!);
    }

    // Reload rates for the reversed pair
    _loadCachedRates();
  }

  Future<void> _openCurrencySelector(bool isFrom) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurrencySelectionScreen(
          isGlobal: false,
          initialCurrencyCode: isFrom ? _fromCurrency : _toCurrency,
          initialIsoCodeNum: isFrom ? _fromIsoCodeNum : _toIsoCodeNum,
        ),
      ),
    );

    if (result != null && result is Map) {
      final code = result['code'];
      final isoCodeNum = result['isoCodeNum']; // Extract isoCodeNum
      if (code != null) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          if (isFrom) {
            _fromCurrency = code;
            _fromIsoCodeNum = isoCodeNum;
            if (isoCodeNum != null) {
              prefs.setString('convert_from_iso_code_num', isoCodeNum);
            }
          } else {
            _toCurrency = code;
            _toIsoCodeNum = isoCodeNum;
            if (isoCodeNum != null) {
              prefs.setString('convert_to_iso_code_num', isoCodeNum);
            }
          }
          _isLoading = true;
        });
        _loadCachedRates();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculation logic
    final inputAmount = double.tryParse(_amountController.text) ?? 1.0;
    final convertedAmount = inputAmount * _exchangeRate;

    // Formatting
    final formatter = NumberFormat("#,##0.00", "en_US");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Currency Converter"),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        actions: [
          IconButton.filledTonal(
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedGlobalRefresh,
              strokeWidth: 2,
              size: 20,
            ),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRates();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- Input Section ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AMOUNT",
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _CurrencyDropdown(
                        value: _fromCurrency,
                        onChanged: (_) => _openCurrencySelector(true),
                      ),
                      const SizedBox(width: 16),
                      // Amount Input
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            hintText: "1.00",
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(
                            () {},
                          ), // Trigger rebuild for calculation
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Swap Button ---
            Stack(
              alignment: Alignment.center,
              children: [
                Divider(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  indent: 20,
                  endIndent: 20,
                ),
                GestureDetector(
                  onTap: _swapCurrencies,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Result Section ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "CONVERTED AMOUNT",
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.7),
                        ),
                      ),
                      _CurrencyDropdown(
                        value: _toCurrency,
                        isLightMode: false, // Use dark/contrast style
                        onChanged: (_) => _openCurrencySelector(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            "${formatter.format(convertedAmount)} $_toCurrency",
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onPrimaryContainer,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHigh,
                            ),
                            onPressed: () => Clipboard.setData(
                              ClipboardData(
                                text: formatter.format(convertedAmount),
                              ),
                            ),
                            icon: Icon(
                              Icons.copy,
                              size: 20,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),
                  Text(
                    "1 $_fromCurrency = $_exchangeRate $_toCurrency",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(
                        0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Last Updated Info ---
            if (_lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedClock01,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Rates updated: ${DateFormat('MMM d, h:mm a').format(_lastUpdated!)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Helper Widget: Funky Dropdown (Now Selectable)
class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  final bool isLightMode;

  const _CurrencyDropdown({
    required this.value,
    required this.onChanged,
    this.isLightMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isLightMode
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.black.withOpacity(0.1);

    final textColor = isLightMode
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onPrimaryContainer;

    return GestureDetector(
      onTap: () => onChanged(null), // Signal to open selector
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 20),
          ],
        ),
      ),
    );
  }
}
