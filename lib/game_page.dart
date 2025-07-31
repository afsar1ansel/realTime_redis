// lib/game_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'app_state.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late String _gameId;
  AppUser? _opponent;
  int _myScore = 0;

  @override
  void initState() {
    super.initState();
    // A unique ID for this game session
    _gameId = Uuid().v4();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get opponent data passed from the home page
      _opponent = ModalRoute.of(context)!.settings.arguments as AppUser?;

      final appState = Provider.of<AppState>(context, listen: false);
      appState.listenToGameScores(_gameId);
      setState(() {});
    });
  }

  void _incrementScore() {
    setState(() {
      _myScore++;
    });
    Provider.of<AppState>(
      context,
      listen: false,
    ).updateMyScore(_gameId, _myScore);
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes in the AppState
    final appState = context.watch<AppState>();
    final currentUser = appState.currentUser;

    // Get scores from the state
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
            // Score Display
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

            // Action Button
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
