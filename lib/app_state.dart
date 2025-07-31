// lib/app_state.dart
// FIXED: Manages the full two-way challenge flow.
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

  // State for incoming challenges
  String? incomingChallengeFromId;
  String? incomingChallengeFromUsername;

  // State for when a challenge you sent is accepted
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
    _listenForChallenges();
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

  // Called when you challenge someone else
  Future<void> challengeUser(String opponentId) async {
    if (currentUser == null) return;
    // Start listening for an acceptance before sending the challenge
    _listenForAcceptedChallenges();
    await _redisService.challengeUser(currentUser!.id, opponentId);
  }

  // Called from the dialog when you accept a challenge
  Future<void> acceptChallenge(AppUser challenger) async {
    if (currentUser == null) return;
    await _redisService.acceptChallenge(
      challenger.id,
      currentUser!.id,
      currentUser!.username,
    );
    clearChallenge();
  }

  // Listens for people challenging you
  void _listenForChallenges() {
    if (currentUser == null) return;
    _challengeSubscription?.cancel();
    _challengeSubscription = _redisService
        .listenToChallenges(currentUser!.id)
        .listen((challengerId) async {
          final username = await _redisService.redisCmd.send_object([
            'HGET',
            'user:$challengerId',
            'username',
          ]);
          incomingChallengeFromId = challengerId;
          incomingChallengeFromUsername = username as String?;
          notifyListeners();
        });
  }

  // Listens for people accepting your challenges
  void _listenForAcceptedChallenges() {
    if (currentUser == null) return;
    _acceptedChallengeSubscription?.cancel();
    _acceptedChallengeSubscription = _redisService
        .listenToAcceptedChallenges(currentUser!.id)
        .listen((payload) {
          final parts = payload.split(':');
          final opponentId = parts[0];
          final opponentUsername = parts[1];
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
    _acceptedChallengeSubscription?.cancel();
  }

  @override
  void dispose() {
    if (currentUser != null) {
      _redisService.setUserOffline(currentUser!.id);
    }
    _challengeSubscription?.cancel();
    _acceptedChallengeSubscription?.cancel();
    _scoreSubscription?.cancel();
    super.dispose();
  }

  // Other methods (addDummyBot, listenToGameScores, etc.) remain the same
  Future<void> addDummyBot() async {
    await _redisService.setUserOnline(
      'bot-${DateTime.now().millisecondsSinceEpoch}',
      'DummyBot',
    );
    await fetchOnlineUsers();
  }


  void listenToGameScores(String gameId) {
    _scoreSubscription?.cancel();
    _scoreSubscription = _redisService.listenToScores(gameId).listen((
      scoreData,
    ) {
      final parts = scoreData.split(':');
      final playerId = parts[0];
      final score = int.tryParse(parts[1]) ?? 0;
      scores[playerId] = score;
      notifyListeners();
    });
  }

  Future<void> updateMyScore(String gameId, int newScore) async {
    if (currentUser == null) return;
    scores[currentUser!.id] = newScore;
    await _redisService.publishScore(gameId, currentUser!.id, newScore);
    notifyListeners();
  }
}
