// lib/app_state.dart
// FIXED: The call to challengeUser now correctly passes all three required arguments.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'redis_service.dart';

class AppUser {
  final String id;
  final String username;
  AppUser({required this.id, required this.username});
}

class AppState extends ChangeNotifier {
  final RedisService _redisService = RedisService();
  AppUser? currentUser;
  List<AppUser> onlineUsers = [];

  String? incomingChallengeFromId;
  String? incomingChallengeFromUsername;
  AppUser? acceptedGameOpponent;

  StreamSubscription? _challengeSubscription;
  StreamSubscription? _acceptedChallengeSubscription;
  StreamSubscription? _scoreSubscription;

  Map<String, int> scores = {};

  AppState() {
    _redisService.connect();
  }

  Future<void> login(String username) async {
    await _redisService.connect();
    final userId = const Uuid().v4();
    currentUser = AppUser(id: userId, username: username);
    await _redisService.setUserOnline(currentUser!.id, currentUser!.username);
    await fetchOnlineUsers();
    _setupAllListeners();
    notifyListeners();
  }

  Future<void> fetchOnlineUsers() async {
    final usersData = await _redisService.getOnlineUsers();
    onlineUsers = usersData
        .where((userData) => userData['id'] != currentUser?.id)
        .map(
          (userData) =>
              AppUser(id: userData['id']!, username: userData['username']!),
        )
        .toList();
    notifyListeners();
  }

  // --- THE FIX IS HERE ---
  // The call to the Redis service now includes the current user's username.
  Future<void> challengeUser(String opponentId) async {
    if (currentUser == null) return;
    // This now correctly passes all 3 required arguments.
    await _redisService.challengeUser(
      currentUser!.id,
      currentUser!.username,
      opponentId,
    );
  }

  Future<void> acceptChallenge(AppUser challenger) async {
    if (currentUser == null) return;
    await _redisService.acceptChallenge(
      challenger.id,
      currentUser!.id,
      currentUser!.username,
    );
    clearChallenge();
  }

  void _setupAllListeners() {
    if (currentUser == null) return;

    _redisService.subscribeToChallenges(currentUser!.id);
    _redisService.subscribeToAcceptedChallenges(currentUser!.id);

    _challengeSubscription?.cancel();
    _challengeSubscription = _redisService.challengeStream.listen((payload) {
      final parts = payload.split(':');
      if (parts.length < 2) return;

      incomingChallengeFromId = parts[0];
      incomingChallengeFromUsername = parts.sublist(1).join(':');
      notifyListeners();
    });

    _acceptedChallengeSubscription?.cancel();
    _acceptedChallengeSubscription = _redisService.acceptedChallengeStream
        .listen((payload) {
          final parts = payload.split(':');
          if (parts.length < 2) return;

          final opponentId = parts[0];
          final opponentUsername = parts.sublist(1).join(':');

          acceptedGameOpponent = AppUser(
            id: opponentId,
            username: opponentUsername,
          );
          notifyListeners();
        });
  }

  void clearChallenge() {
    incomingChallengeFromId = null;
    incomingChallengeFromUsername = null;
    notifyListeners();
  }

  void clearAcceptedGame() {
    acceptedGameOpponent = null;
  }

  void listenToGameScores(String gameId) {
    _redisService.subscribeToGameScores(gameId);
    _scoreSubscription?.cancel();
    _scoreSubscription = _redisService.scoreStream.listen((scoreData) {
      final parts = scoreData.split(':');
      final playerId = parts[0];
      final score = int.tryParse(parts[1]) ?? 0;
      scores[playerId] = score;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (currentUser != null) {
      _redisService.setUserOffline(currentUser!.id);
    }
    _challengeSubscription?.cancel();
    _acceptedChallengeSubscription?.cancel();
    _scoreSubscription?.cancel();
    _redisService.dispose();
    super.dispose();
  }

  Future<void> addDummyBot() async {
    await _redisService.setUserOnline(
      'bot-${DateTime.now().millisecondsSinceEpoch}',
      'DummyBot',
    );
    await fetchOnlineUsers();
  }

  Future<void> updateMyScore(String gameId, int newScore) async {
    if (currentUser == null) return;
    scores[currentUser!.id] = newScore;
    await _redisService.publishScore(gameId, currentUser!.id, newScore);
    notifyListeners();
  }
}
