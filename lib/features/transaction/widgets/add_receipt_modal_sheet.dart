import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/common/helpers/image_cropper/image_cropper_screen.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/transaction/services/receipt_service.dart';

class AddReceiptModalSheet extends StatefulWidget {
  final bool uploadImmediately;
  final String? transactionId;
  final Function(String? url, Uint8List? bytes)? onComplete;

  const AddReceiptModalSheet({
    super.key,
    this.uploadImmediately = false,
    this.transactionId,
    this.onComplete,
  });

  @override
  State<AddReceiptModalSheet> createState() => _AddReceiptModalSheetState();
}

class _AddReceiptModalSheetState extends State<AddReceiptModalSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _handleImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;

      // Navigate to Cropper
      final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(imageData: bytes),
        ),
      );

      if (croppedBytes == null || !mounted) return;

      if (widget.uploadImmediately) {
        await _uploadReceipt(croppedBytes);
      } else {
        widget.onComplete?.call(null, croppedBytes);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _uploadReceipt(Uint8List bytes) async {
    setState(() => _isUploading = true);
    try {
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).user!.uid;
      final transactionId = widget.transactionId ?? const Uuid().v4();

      final url = await ReceiptService().uploadReceipt(
        imageData: bytes,
        userId: userId,
        transactionId: transactionId,
      );

      widget.onComplete?.call(url, bytes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload receipt: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Text(
                "Add Receipt",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isUploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Row(
                children: [
                  _OptionTile(
                    icon: Icons.camera_alt_rounded,
                    title: "Take Photo",
                    subtitle: "Capture receipt",
                    onTap: () => _handleImage(ImageSource.camera),
                  ),
                  const SizedBox(width: 12),
                  _OptionTile(
                    icon: Icons.photo_library_rounded,
                    title: "Gallery",
                    subtitle: "Select image",
                    onTap: () => _handleImage(ImageSource.gallery),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: theme.colorScheme.surfaceContainer,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
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
