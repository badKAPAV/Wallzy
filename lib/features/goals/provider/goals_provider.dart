import 'dart:async';
import 'package:flutter/material.dart';
import '../models/goal_model.dart';
import '../services/goals_service.dart';
import '../../auth/provider/auth_provider.dart';

class GoalsProvider with ChangeNotifier {
  final GoalsService _goalsService = GoalsService();
  AuthProvider authProvider;

  List<Goal> _goals = [];
  List<Goal> get goals => _goals;

  StreamSubscription? _goalsSubscription;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  GoalsProvider({required this.authProvider}) {
    if (authProvider.isLoggedIn) {
      _listenToGoals();
    }
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    if (authProvider.isLoggedIn) {
      _listenToGoals();
    } else {
      _goals = [];
      _goalsSubscription?.cancel();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _goalsSubscription?.cancel();
    super.dispose();
  }

  void _listenToGoals() {
    final user = authProvider.user;
    if (user == null) return;

    _isLoading = true;
    // notifyListeners(); // Avoid notifying during build if called from proxy update

    _goalsSubscription?.cancel();
    _goalsSubscription = _goalsService
        .getGoalsStream(user.uid)
        .listen(
          (goalsList) {
            _goals = goalsList;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            debugPrint("Error listening to goals: $e");
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> addGoal(Goal goal) async {
    final user = authProvider.user;
    if (user == null) return;
    await _goalsService.addGoal(user.uid, goal);
  }

  Future<void> updateGoal(Goal goal) async {
    final user = authProvider.user;
    if (user == null) return;
    await _goalsService.updateGoal(user.uid, goal);
  }

  Future<void> deleteGoal(String goalId) async {
    final user = authProvider.user;
    if (user == null) return;
    await _goalsService.deleteGoal(user.uid, goalId);
  }
}
