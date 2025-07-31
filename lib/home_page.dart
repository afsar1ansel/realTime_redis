// lib/home_page.dart
// FIXED: Dialog logic is now smarter and the page listens for accepted challenges.
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
  // Flag to prevent showing multiple dialogs
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        Provider.of<AppState>(context, listen: false).fetchOnlineUsers();
      }
    });

    // Add a single listener to handle all state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().addListener(_handleStateChanges);
    });
  }

  void _handleStateChanges() {
    // Use a single listener to check for different conditions
    _showChallengeDialog();
    _navigateToAcceptedGame();
  }

  void _showChallengeDialog() {
    final appState = context.read<AppState>();
    // Don't show dialog if one is already visible or there's no challenge
    if (_isDialogShowing || appState.incomingChallengeFromId == null) return;

    // Set the flag to true and show the dialog
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
              // Accept the challenge, which notifies the challenger
              appState.acceptChallenge(challenger);
              Navigator.of(context).pop(); // Close the dialog
              // Navigate to the game page
              Navigator.pushNamed(context, '/game', arguments: challenger);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    ).then((_) {
      // This runs after the dialog is closed, so we reset the flag
      setState(() {
        _isDialogShowing = false;
      });
    });
  }

  void _navigateToAcceptedGame() {
    final appState = context.read<AppState>();
    // If a game was accepted by an opponent, navigate to it
    if (appState.acceptedGameOpponent != null) {
      final opponent = appState.acceptedGameOpponent!;
      // Important: Clear the state so we don't navigate again
      appState.clearAcceptedGame();
      Navigator.pushNamed(context, '/game', arguments: opponent);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    context.read<AppState>().removeListener(_handleStateChanges);
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
