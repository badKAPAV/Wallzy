import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';

class PendingSmsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;

  // CHANGED: Returns a Future<bool> to indicate success/failure
  final Function(Map<String, dynamic>) onAdd;
  final Function(Map<String, dynamic>) onDismiss;
  final Function(Map<String, dynamic>) onUndo;

  const PendingSmsScreen({
    super.key,
    required this.transactions,
    required this.onAdd,
    required this.onDismiss,
    required this.onUndo,
  });

  @override
  State<PendingSmsScreen> createState() => _PendingSmsScreenState();
}

class _PendingSmsScreenState extends State<PendingSmsScreen> {
  late List<Map<String, dynamic>> _transactions;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
  }

  // --- Single Item Logic ---
  void _dismissItem(int index, Map<String, dynamic> tx) {
    HapticFeedback.selectionClick();

    // 1. Remove from UI immediately for "Ignore"
    final removedItem = _transactions.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(
          opacity: animation,
          child: _TransactionRow(tx: tx),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );

    // 2. Trigger Callback
    widget.onDismiss(removedItem);

    // 3. Show Snackbar with Undo
    _showUndoSnackbar(
      message: "Transaction ignored",
      onUndo: () {
        setState(() {
          _transactions.insert(index, removedItem);
        });
        _listKey.currentState?.insertItem(index);
        widget.onUndo(removedItem);
      },
    );
  }

  Future<void> _trackItem(int index, Map<String, dynamic> tx) async {
    HapticFeedback.mediumImpact();

    // CHANGED: We do NOT remove the item yet.
    // We wait for the parent to tell us if it was successful.
    final bool success = await widget.onAdd(tx);

    // Only remove if the operation was successful (e.g. User clicked "Save")
    if (success && mounted) {
      // Check if index is still valid (list might have changed)
      if (index < _transactions.length && _transactions[index] == tx) {
        final removedItem = _transactions.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: const SizedBox.shrink(), // Instant shrink
          ),
          duration: const Duration(milliseconds: 200),
        );
      }
    }
  }

  // --- Bulk Logic ---
  Future<void> _handleClearAll() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text(
          "This will ignore all pending transactions in this list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final List<Map<String, dynamic>> backupList = List.from(_transactions);
      final int count = backupList.length;

      for (var tx in _transactions) {
        widget.onDismiss(tx);
      }

      for (int i = _transactions.length - 1; i >= 0; i--) {
        final item = _transactions[i];
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: _TransactionRow(tx: item),
          ),
          duration: const Duration(milliseconds: 300),
        );
      }
      setState(() {
        _transactions.clear();
      });

      _showUndoSnackbar(
        message: "Inbox cleared ($count items)",
        onUndo: () {
          setState(() {
            _transactions.addAll(backupList);
          });
          for (int i = 0; i < backupList.length; i++) {
            _listKey.currentState?.insertItem(i);
            widget.onUndo(backupList[i]);
          }
        },
      );
    }
  }

  void _showUndoSnackbar({
    required String message,
    required VoidCallback onUndo,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Theme.of(context).colorScheme.inversePrimary,
          onPressed: () {
            HapticFeedback.lightImpact();
            onUndo();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Inbox"),
            Text(
              "${_transactions.length} pending",
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_transactions.isNotEmpty)
            TextButton.icon(
              onPressed: _handleClearAll,
              icon: Icon(
                Icons.clear_all_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                "Clear All",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _transactions.isEmpty
          ? const EmptyReportPlaceholder(
              message: "No pending transactions",
              icon: HugeIcons.strokeRoundedInboxCheck,
            )
          : AnimatedList(
              key: _listKey,
              padding: const EdgeInsets.symmetric(vertical: 8),
              initialItemCount: _transactions.length,
              itemBuilder: (context, index, animation) {
                if (index >= _transactions.length)
                  return const SizedBox.shrink();

                final tx = _transactions[index];
                return SizeTransition(
                  sizeFactor: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _TransactionRow(
                        tx: tx,
                        onTrack: () => _trackItem(index, tx),
                        onIgnore: () => _dismissItem(index, tx),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback? onTrack;
  final VoidCallback? onIgnore;

  const _TransactionRow({required this.tx, this.onTrack, this.onIgnore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final amount = (tx['amount'] as num).toDouble();
    final merchant = tx['payee'] ?? tx['merchant'] ?? 'Unknown';
    DateTime date;
    if (tx['timestamp'] != null && tx['timestamp'] is int) {
      date = DateTime.fromMillisecondsSinceEpoch(tx['timestamp']);
    } else {
      date = DateTime.tryParse(tx['date'] ?? '') ?? DateTime.now();
    }

    final isIncome = (tx['type'] == 'income');
    final color = isIncome ? Colors.green : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(80),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM').format(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                Text(
                  DateFormat('d').format(date),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${isIncome ? '+' : ''} ${NumberFormat.simpleCurrency(name: 'INR').format(amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: onIgnore,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Ignore',
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: onTrack,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: 'Track',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
