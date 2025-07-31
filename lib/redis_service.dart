// lib/redis_service.dart

import 'dart:async';
import 'package:redis/redis.dart';

class RedisService {
  static final RedisService _instance = RedisService._internal();
  factory RedisService() => _instance;
  RedisService._internal();

  late Command redisCmd;
  late Command pubSubCmd;
  late PubSub _pubSub;
  bool _isConnected = false;

  final String _host = 'redis-15966.c92.us-east-1-3.ec2.redns.redis-cloud.com';
  final int _port = 15966;
  final String _password = 'ffc44nFVb9KNKWc3mON9SlEZnHDyzY4y';

  Future<void> connect() async {
    if (_isConnected) {
      try {
        final response = await redisCmd.send_object(['PING']);
        if (response == 'PONG') return;
      } catch (e) {
        _isConnected = false;
      }
    }
    final conn = RedisConnection();
    try {
      redisCmd = await conn.connect(_host, _port);
      await redisCmd.send_object(['AUTH', _password]);
      final pubSubConn = RedisConnection();
      pubSubCmd = await pubSubConn.connect(_host, _port);
      await pubSubCmd.send_object(['AUTH', _password]);
      _pubSub = PubSub(pubSubCmd);
      _isConnected = true;
      print("✅ Successfully connected to Redis.");
    } catch (e) {
      print("❌ Redis connection failed: $e");
      _isConnected = false;
    }
  }

  Future<void> setUserOnline(String userId, String username) async {
    await redisCmd.send_object(['SADD', 'online_users', userId]);
    await redisCmd.send_object(['HSET', 'user:$userId', 'username', username]);
  }

  Future<void> setUserOffline(String userId) async {
    await redisCmd.send_object(['SREM', 'online_users', userId]);
  }

  Future<List<Map<String, String>>> getOnlineUsers() async {
    final userIdsResponse = await redisCmd.send_object([
      'SMEMBERS',
      'online_users',
    ]);
    if (userIdsResponse == null || userIdsResponse is! List) return [];
    final List<String> userIds = (userIdsResponse as List)
        .map((id) => id.toString())
        .toList();
    final List<Map<String, String>> users = [];
    for (String id in userIds) {
      final usernameResponse = await redisCmd.send_object([
        'HGET',
        'user:$id',
        'username',
      ]);
      final String? username = usernameResponse?.toString();
      if (username != null) {
        users.add({'id': id, 'username': username});
      }
    }
    return users;
  }

  // --- CHALLENGE FLOW ---

  // 1. A user sends a challenge to an opponent
  Future<void> challengeUser(String challengerId, String opponentId) async {
    await redisCmd.send_object([
      'PUBLISH',
      'challenges:$opponentId',
      challengerId,
    ]);
  }

  // 2. The opponent accepts, publishing a message back to the challenger
  Future<void> acceptChallenge(
    String challengerId,
    String myId,
    String myUsername,
  ) async {
    // The message is the opponent's data, so the challenger knows who they are playing
    final payload = '$myId:$myUsername';
    await redisCmd.send_object([
      'PUBLISH',
      'challenge-accepted:$challengerId',
      payload,
    ]);
  }

  // Listens for incoming challenges on the user-specific channel
  Stream<String> listenToChallenges(String userId) {
    _pubSub.subscribe(['challenges:$userId']);
    return _pubSub
        .getStream()!
        .where((message) => message[0] == 'message')
        .map((message) => message[2] as String);
  }

  // Listens for when a sent challenge has been accepted
  Stream<String> listenToAcceptedChallenges(String userId) {
    _pubSub.subscribe(['challenge-accepted:$userId']);
    return _pubSub
        .getStream()!
        .where((message) => message[0] == 'message')
        .map((message) => message[2] as String);
  }

  // --- SCORE FLOW ---
  Future<void> publishScore(String gameId, String playerId, int score) async {
    await redisCmd.send_object(['PUBLISH', 'game:$gameId', '$playerId:$score']);
  }

  Stream<String> listenToScores(String gameId) {
    _pubSub.subscribe(['game:$gameId']);
    return _pubSub
        .getStream()!
        .where((message) => message[0] == 'message')
        .map((message) => message[2] as String);
  }

  void dispose() {
    redisCmd.get_connection().close();
    pubSubCmd.get_connection().close();
    _isConnected = false;
  }
}
