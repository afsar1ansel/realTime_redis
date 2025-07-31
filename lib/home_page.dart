// lib/home_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        Provider.of<AppState>(context, listen: false).fetchOnlineUsers();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().addListener(_handleStateChanges);
    });
  }

  void _handleStateChanges() {
    _showChallengeDialog();
    _navigateToAcceptedGame();
  }


  String _createDeterministicGameId(String userId1, String userId2) {

    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('-'); // Join with a separator for a clean ID
  }

  void _showChallengeDialog() {
    final appState = context.read<AppState>();
    if (_isDialogShowing || appState.incomingChallengeFromId == null) return;

    setState(() {
      _isDialogShowing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚔️ Incoming Challenge!'),
        content: Text(
          '${appState.incomingChallengeFromUsername ?? 'Someone'} wants to play!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              appState.clearChallenge();
              Navigator.of(context).pop();
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              final challenger = AppUser(
                id: appState.incomingChallengeFromId!,
                username: appState.incomingChallengeFromUsername!,
              );
              appState.acceptChallenge(challenger);

              // --- FIX: Create and pass the deterministic game ID ---
              final gameId = _createDeterministicGameId(
                challenger.id,
                appState.currentUser!.id,
              );

              Navigator.of(context).pop();
              // Pass a map containing both the opponent and the game ID
              Navigator.pushNamed(
                context,
                '/game',
                arguments: {'opponent': challenger, 'gameId': gameId},
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isDialogShowing = false;
        });
      }
    });
  }

  void _navigateToAcceptedGame() {
    final appState = context.read<AppState>();
    if (appState.acceptedGameOpponent != null) {
      final opponent = appState.acceptedGameOpponent!;
      appState.clearAcceptedGame();

      // --- FIX: Create and pass the deterministic game ID ---
      final gameId = _createDeterministicGameId(
        opponent.id,
        appState.currentUser!.id,
      );

      // Pass a map containing both the opponent and the game ID
      Navigator.pushNamed(
        context,
        '/game',
        arguments: {'opponent': opponent, 'gameId': gameId},
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (mounted) {
      context.read<AppState>().removeListener(_handleStateChanges);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome, ${context.select((AppState s) => s.currentUser?.username ?? '')}',
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return appState.onlineUsers.isEmpty
              ? const Center(
                  child: Text('Waiting for other players to come online...'),
                )
              : ListView.builder(
                  itemCount: appState.onlineUsers.length,
                  itemBuilder: (context, index) {
                    final user = appState.onlineUsers[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(user.username),
                      subtitle: Text('ID: ${user.id.substring(0, 8)}...'),
                      trailing: ElevatedButton(
                        child: const Text('Challenge 🤺'),
                        onPressed: () {
                          appState.challengeUser(user.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Challenge sent to ${user.username}!',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}
