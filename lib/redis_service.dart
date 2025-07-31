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

  final _challengeController = StreamController<String>.broadcast();
  final _acceptedChallengeController = StreamController<String>.broadcast();
  final _scoreController = StreamController<String>.broadcast();

  Stream<String> get challengeStream => _challengeController.stream;
  Stream<String> get acceptedChallengeStream =>
      _acceptedChallengeController.stream;
  Stream<String> get scoreStream => _scoreController.stream;

  final String _host = 'redis-15966.c92.us-east-1-3.ec2.redns.redis-cloud.com';
  final int _port = 15966;
  final String _password = 'ffc44nFVb9KNKWc3mON9SlEZnHDyzY4y';

  Future<void> connect() async {
    if (_isConnected) {
      try {
        if (await redisCmd.send_object(['PING']) == 'PONG') return;
      } catch (e) {
        _isConnected = false;
      }
    }
    try {
      redisCmd = await RedisConnection().connect(_host, _port)
        ..send_object(['AUTH', _password]);
      pubSubCmd = await RedisConnection().connect(_host, _port)
        ..send_object(['AUTH', _password]);
      _pubSub = PubSub(pubSubCmd);
      _isConnected = true;
      _listenToPubSub();
      print("✅ Successfully connected to Redis.");
    } catch (e) {
      print("❌ Redis connection failed: $e");
      _isConnected = false;
    }
  }

  void _listenToPubSub() {
    _pubSub.getStream()!.listen((message) {
      if (message[0] != 'message') return;
      final channel = message[1] as String;
      final payload = message[2] as String;

      if (channel.startsWith('challenges:')) {
        _challengeController.add(payload);
      } else if (channel.startsWith('challenge-accepted:')) {
        _acceptedChallengeController.add(payload);
      } else if (channel.startsWith('game:')) {
        _scoreController.add(payload);
      }
    });
  }

  void subscribeToChallenges(String userId) =>
      _pubSub.subscribe(['challenges:$userId']);
  void subscribeToAcceptedChallenges(String userId) =>
      _pubSub.subscribe(['challenge-accepted:$userId']);
  void subscribeToGameScores(String gameId) =>
      _pubSub.subscribe(['game:$gameId']);

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
      final username = await redisCmd.send_object([
        'HGET',
        'user:$id',
        'username',
      ]);
      if (username != null) {
        users.add({'id': id, 'username': username.toString()});
      }
    }
    return users;
  }

  // --- FIX: The payload now includes the challenger's name ---
  Future<void> challengeUser(
    String challengerId,
    String challengerUsername,
    String opponentId,
  ) async {
    final payload = '$challengerId:$challengerUsername';
    await redisCmd.send_object(['PUBLISH', 'challenges:$opponentId', payload]);
  }

  Future<void> acceptChallenge(
    String challengerId,
    String myId,
    String myUsername,
  ) async {
    final payload = '$myId:$myUsername';
    await redisCmd.send_object([
      'PUBLISH',
      'challenge-accepted:$challengerId',
      payload,
    ]);
  }

  Future<void> publishScore(String gameId, String playerId, int score) async {
    await redisCmd.send_object(['PUBLISH', 'game:$gameId', '$playerId:$score']);
  }

  void dispose() {
    _challengeController.close();
    _acceptedChallengeController.close();
    _scoreController.close();
    redisCmd.get_connection().close();
    pubSubCmd.get_connection().close();
    _isConnected = false;
  }
}
