import 'package:hugeicons/hugeicons.dart';

class GoalIconRegistry {
  // The default key if nothing is found or selected
  static const String defaultKey = 'target';

  // The Master Map: Database String -> App Icon
  static final Map<String, dynamic> _icons = {
    // General
    'target': HugeIcons.strokeRoundedTarget02,
    'star': HugeIcons.strokeRoundedStar,
    'fire': HugeIcons.strokeRoundedFire,

    // Transport
    'car': HugeIcons.strokeRoundedCar02,
    'bike': HugeIcons.strokeRoundedMotorbike02,
    'rocket': HugeIcons.strokeRoundedRocket,

    // Housing & Living
    'house': HugeIcons.strokeRoundedHouse03,
    'furniture': HugeIcons.strokeRoundedSofa01,
    'renovation': HugeIcons.strokeRoundedPaintBrush02,
    'garden': HugeIcons.strokeRoundedFlower,

    // Tech & Gadgets
    'phone': HugeIcons.strokeRoundedSmartPhone01,
    'laptop': HugeIcons.strokeRoundedLaptop,
    'camera': HugeIcons.strokeRoundedCamera01,
    'gaming': HugeIcons.strokeRoundedGameController03,
    'headphone': HugeIcons.strokeRoundedHeadphones,

    // Life Events
    'wedding': HugeIcons.strokeRoundedWedding, // Wedding
    'baby': HugeIcons.strokeRoundedBaby01,
    'education': HugeIcons.strokeRoundedMortarboard01,
    'party': HugeIcons.strokeRoundedParty,

    // Travel
    'travel': HugeIcons.strokeRoundedAirplane01,
    'beach': HugeIcons.strokeRoundedSun03,
    'mountain': HugeIcons.strokeRoundedMountain,
    'globe': HugeIcons.strokeRoundedGlobe02,

    // Financial/Wealth
    'piggy': HugeIcons.strokeRoundedPiggyBank,
    'money_bag': HugeIcons.strokeRoundedMoneyBag02,
    'safe': HugeIcons.strokeRoundedSafe,
    'invest': HugeIcons.strokeRoundedTradeUp,

    // Emergency/Health
    'health': HugeIcons.strokeRoundedAmbulance,
    'umbrella': HugeIcons.strokeRoundedUmbrella, // Rainy day fund

    'heart': HugeIcons.strokeRoundedFavourite,
    'love': HugeIcons.strokeRoundedFavouriteCircle,
    'folder': HugeIcons.strokeRoundedFolder02,
  };

  static dynamic getIcon(String? key) {
    return _icons[key] ?? _icons[defaultKey]!;
  }

  static dynamic getFolderIcon(String? key) {
    return getIcon(key ?? 'folder');
  }

  static List<String> get keys => _icons.keys.toList();
}
