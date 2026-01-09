import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/settings/screens/currency_selection_screen.dart';

class CurrencyConverterModal extends StatefulWidget {
  final double? initialAmount;
  final String initialFromCurrency;

  // You might want to pass the user's "Home" currency as the default target
  final String defaultTargetCurrency;

  const CurrencyConverterModal({
    super.key,
    this.initialAmount,
    required this.initialFromCurrency,
    this.defaultTargetCurrency = 'INR', // Default fallback
  });

  @override
  State<CurrencyConverterModal> createState() => _CurrencyConverterModalState();
}

class _CurrencyConverterModalState extends State<CurrencyConverterModal> {
  // Controllers
  late TextEditingController _amountController;

  // State
  late String _fromCurrency;
  late String _toCurrency;

  // ISO Codes for flagging (optional if your selection screen uses them)
  String? _fromIsoCodeNum;
  String? _toIsoCodeNum;

  double _exchangeRate = 0.0;
  DateTime? _lastUpdated;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Values
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount.toString()
          : '1.00',
    );

    _fromCurrency = widget.initialFromCurrency;
    _toCurrency = widget.defaultTargetCurrency;

    // 2. Avoid converting same currency to same currency by default
    if (_fromCurrency == _toCurrency) {
      _toCurrency = (_fromCurrency == 'USD') ? 'INR' : 'USD';
    }

    // Initialize ISO codes for highlighting
    if (_fromCurrency == 'USD') _fromIsoCodeNum = '840';
    if (_toCurrency == 'INR') _toIsoCodeNum = '356';
    if (_toCurrency == 'USD') _toIsoCodeNum = '840';
    if (_fromCurrency == 'INR') _fromIsoCodeNum = '356';

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

    final cachedRate = prefs.getDouble('${_fromCurrency}_$_toCurrency');
    final lastUpdateMillis = prefs.getInt('currency_last_updated');

    if (cachedRate != null && lastUpdateMillis != null) {
      setState(() {
        _exchangeRate = cachedRate;
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdateMillis);
        _isLoading = false;
      });
    }

    // Fetch fresh data
    _fetchRates();
  }

  /// 2. Fetch fresh rates from API
  Future<void> _fetchRates() async {
    try {
      final url = Uri.parse(
        'https://api.exchangerate-api.com/v4/latest/$_fromCurrency',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        final newRate = (rates[_toCurrency] as num).toDouble();
        final now = DateTime.now();

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
      prefs.setString('convert_from_iso_code_num', _fromIsoCodeNum!);
    }
    if (_toIsoCodeNum != null) {
      prefs.setString('convert_to_iso_code_num', _toIsoCodeNum!);
    }

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
      final isoCodeNum = result['isoCodeNum'];
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

    // Calculation
    final inputAmount = double.tryParse(_amountController.text) ?? 0.0;
    final convertedAmount = inputAmount * _exchangeRate;

    final formatter = NumberFormat("#,##0.00", "en_US");

    return Padding(
      // Handle keyboard overlap
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Handle & Header ---
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Currency Converter",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _fetchRates();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                      "CONVERT FROM",
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
                              hintText: "0.00",
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
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
                          isLightMode: false,
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
                            // --- Action Buttons Row ---
                            Row(
                              children: [
                                // Copy Button
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHigh,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: convertedAmount.toStringAsFixed(
                                          2,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.copy,
                                    size: 20,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 0),

                                // --- THE REQUESTED ARROW BUTTON ---
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        theme.colorScheme.onPrimaryContainer,
                                    // High contrast against container
                                  ),
                                  // Empty onTap as requested
                                  onPressed: () {
                                    Navigator.pop(context, convertedAmount);
                                  },
                                  icon: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: theme.colorScheme.primaryContainer,
                                  ),
                                ),
                              ],
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

              // --- Last Updated ---
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
      ),
    );
  }
}

// Reusing your existing dropdown component
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
      onTap: () => onChanged(null),
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
