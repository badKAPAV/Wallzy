enum HomeWidgetType {
  folderWatchlist,
  spendograph,
  goalsWatchlist,
  categoryWatchlist,
} // Extensible

class HomeWidgetModel {
  final String id;
  final HomeWidgetType type;
  int width; // 1 to 4 (The grid has 4 columns)
  int height; // Usually 2 for your specification
  List<String> configIds; // IDs of selected folders/items

  HomeWidgetModel({
    required this.id,
    required this.type,
    this.width = 4, // Default to 4x2
    this.height = 2,
    this.configIds = const [],
  });

  // Helper to check if setup is needed
  bool get needsSetup => configIds.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'width': width,
    'height': height,
    'configIds': configIds,
  };

  factory HomeWidgetModel.fromJson(Map<String, dynamic> json) {
    return HomeWidgetModel(
      id: json['id'],
      type: HomeWidgetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HomeWidgetType.folderWatchlist,
      ),
      width: json['width'] ?? 4,
      height: json['height'] ?? 2,
      configIds: List<String>.from(json['configIds'] ?? []),
    );
  }
}
