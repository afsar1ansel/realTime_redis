// lib/game_page.dart
// FIXED: Receives and uses the shared game ID from navigation arguments.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  // These will be initialized with data from the navigation arguments
  late String _gameId;
  AppUser? _opponent;

  // This score is local to the user's button presses
  int _myScore = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // --- FIX: Receive a Map of arguments instead of just the opponent ---
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _opponent = args['opponent'] as AppUser;
      _gameId = args['gameId'] as String; // Use the shared gameId

      final appState = Provider.of<AppState>(context, listen: false);
      // Listen for scores on the correct, shared game channel
      appState.listenToGameScores(_gameId);

      // We call setState to ensure the opponent's name renders correctly on the first frame
      setState(() {});
    });
  }

  void _incrementScore() {
    setState(() {
      _myScore++;
    });
    // Publish the score to the correct, shared game channel
    Provider.of<AppState>(
      context,
      listen: false,
    ).updateMyScore(_gameId, _myScore);
  }

  @override
  Widget build(BuildContext context) {
    // Watch for score changes from AppState
    final appState = context.watch<AppState>();
    final currentUser = appState.currentUser;

    // Get scores from the central state map
    final myDisplayScore = appState.scores[currentUser?.id] ?? 0;
    final opponentDisplayScore =
        (_opponent != null ? appState.scores[_opponent!.id] : null) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game On!'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreCard(
                  currentUser?.username ?? 'You',
                  myDisplayScore,
                  Colors.blue,
                ),
                _buildScoreCard(
                  _opponent?.username ?? 'Opponent',
                  opponentDisplayScore,
                  Colors.red,
                ),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add 1 to My Score'),
              onPressed: _incrementScore,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String name, int score, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              '$score',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
