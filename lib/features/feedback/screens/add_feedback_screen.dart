import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wallzy/common/helpers/image_cropper/image_cropper_screen.dart';
import 'dart:typed_data';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/feedback/provider/feedback_provider.dart';

class AddFeedbackScreen extends StatefulWidget {
  const AddFeedbackScreen({super.key});

  @override
  State<AddFeedbackScreen> createState() => _AddFeedbackScreenState();
}

class _AddFeedbackScreenState extends State<AddFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  // Topic
  final List<String> _topics = [
    'Bug Report',
    'Feature Request',
    'UI/UX',
    'Performance',
    'Other',
  ];
  String _selectedTopic = 'Bug Report';

  // Impact
  double _impactRating = 1.0;

  // Steps
  final List<TextEditingController> _stepControllers = [];

  // Images
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  void _addStep() {
    // Constraint: Can't add if last is empty
    if (_stepControllers.isNotEmpty &&
        _stepControllers.last.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill the empty step first"),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() {
      _stepControllers.add(TextEditingController());
    });
  }

  void _removeStep(int index) {
    setState(() {
      final controller = _stepControllers.removeAt(index);
      controller.dispose();
    });
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100, // High quality for cropping
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    // Navigate to Cropper with free ratio
    final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageCropperScreen(
          imageData: bytes,
          initialAspectRatio: CropAspectRatio.free,
          lockAspectRatio: false,
        ),
      ),
    );

    if (croppedBytes != null && mounted) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/feedback_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(croppedBytes);

      setState(() {
        _selectedImages.add(tempFile);
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<FeedbackProvider>(context, listen: false);
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;

    if (userId == null) return;

    // Combine steps
    final stepsString = _stepControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .join("\n");

    try {
      await provider.submitFeedback(
        userId: userId,
        title: _titleController.text.trim(),
        topic: _selectedTopic,
        impact: _impactRating,
        steps: stepsString,
        images: _selectedImages,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<FeedbackProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Create Feedback")),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic Selector (Chips)
                    Text(
                      "TOPIC",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _topics.map((topic) {
                        final isSelected = _selectedTopic == topic;
                        return ChoiceChip(
                          label: Text(topic),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected)
                              setState(() => _selectedTopic = topic);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      "TITLE",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: "Brief summary of the issue...",
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) => v!.isEmpty ? "Title is required" : null,
                    ),
                    const SizedBox(height: 24),

                    // Impact Slider
                    Text(
                      "IMPACT ON USAGE",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Annoying"),
                              Text(
                                "${_impactRating.toInt()}/10",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text("Unusable"),
                            ],
                          ),
                          Slider(
                            value: _impactRating,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _impactRating.round().toString(),
                            onChanged: (val) =>
                                setState(() => _impactRating = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dynamic Steps
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "STEPS TO REPRODUCE",
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addStep,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text("Add Step"),
                        ),
                      ],
                    ),
                    if (_stepControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          "No steps added.",
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ),
                    ...List.generate(_stepControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _stepControllers[index],
                                decoration: InputDecoration(
                                  hintText: "What happened next?",
                                  isDense: true,
                                  filled: true,
                                  fillColor:
                                      theme.colorScheme.surfaceContainerLow,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => _removeStep(index),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // Images
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ATTACHMENTS (OPTIONAL)",
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          "${_selectedImages.length}/3",
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Add Button
                          if (_selectedImages.length < 3)
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_a_photo_rounded,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          // Image List
                          ..._selectedImages.asMap().entries.map((entry) {
                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    image: DecorationImage(
                                      image: FileImage(entry.value),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedImages.removeAt(entry.key),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Submit Feedback",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
