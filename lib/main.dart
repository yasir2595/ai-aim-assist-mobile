import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AimTrainerApp());
}

class TrainingSettings {
  final int roundSeconds;
  final double targetSize;
  final bool vibration;
  final bool sound;
  final String difficulty;

  const TrainingSettings({
    this.roundSeconds = 60,
    this.targetSize = 54,
    this.vibration = true,
    this.sound = false,
    this.difficulty = 'Balanced',
  });

  TrainingSettings copyWith({
    int? roundSeconds,
    double? targetSize,
    bool? vibration,
    bool? sound,
    String? difficulty,
  }) {
    return TrainingSettings(
      roundSeconds: roundSeconds ?? this.roundSeconds,
      targetSize: targetSize ?? this.targetSize,
      vibration: vibration ?? this.vibration,
      sound: sound ?? this.sound,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}

class TrainingStats {
  final int sessions;
  final int hits;
  final int shots;
  final int bestScore;
  final int bestReactionMs;
  final int totalTimeSeconds;

  const TrainingStats({
    this.sessions = 0,
    this.hits = 0,
    this.shots = 0,
    this.bestScore = 0,
    this.bestReactionMs = 0,
    this.totalTimeSeconds = 0,
  });

  double get accuracy => shots == 0 ? 0 : hits / shots * 100;
  int get averageReactionMs => hits == 0 ? 0 : bestReactionMs;

  TrainingStats copyWith({
    int? sessions,
    int? hits,
    int? shots,
    int? bestScore,
    int? bestReactionMs,
    int? totalTimeSeconds,
  }) {
    return TrainingStats(
      sessions: sessions ?? this.sessions,
      hits: hits ?? this.hits,
      shots: shots ?? this.shots,
      bestScore: bestScore ?? this.bestScore,
      bestReactionMs: bestReactionMs ?? this.bestReactionMs,
      totalTimeSeconds: totalTimeSeconds ?? this.totalTimeSeconds,
    );
  }
}

class TrainerController extends ChangeNotifier {
  TrainerController() {
    _load();
  }

  final Random _random = Random();
  Timer? _timer;
  SharedPreferences? _prefs;
  TrainingSettings settings = const TrainingSettings();
  TrainingStats stats = const TrainingStats();
  bool isRunning = false;
  bool isPaused = false;
  int remainingSeconds = 60;
  int score = 0;
  int hits = 0;
  int misses = 0;
  int reactionMs = 0;
  Offset target = const Offset(.5, .42);
  DateTime? _targetShownAt;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    settings = settings.copyWith(
      roundSeconds: p.getInt('roundSeconds') ?? 60,
      targetSize: p.getDouble('targetSize') ?? 54,
      vibration: p.getBool('vibration') ?? true,
      sound: p.getBool('sound') ?? false,
      difficulty: p.getString('difficulty') ?? 'Balanced',
    );
    stats = stats.copyWith(
      sessions: p.getInt('sessions') ?? 0,
      hits: p.getInt('hits') ?? 0,
      shots: p.getInt('shots') ?? 0,
      bestScore: p.getInt('bestScore') ?? 0,
      bestReactionMs: p.getInt('bestReactionMs') ?? 0,
      totalTimeSeconds: p.getInt('totalTimeSeconds') ?? 0,
    );
    remainingSeconds = settings.roundSeconds;
    notifyListeners();
  }

  void start() {
    if (isRunning && isPaused) {
      isPaused = false;
      _startTimer();
      notifyListeners();
      return;
    }
    _timer?.cancel();
    isRunning = true;
    isPaused = false;
    remainingSeconds = settings.roundSeconds;
    score = 0;
    hits = 0;
    misses = 0;
    reactionMs = 0;
    _placeTarget();
    _startTimer();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    isPaused = true;
    _timer?.cancel();
    notifyListeners();
  }

  void restart() => start();

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 1) {
        remainingSeconds = 0;
        finish();
      } else {
        remainingSeconds--;
        notifyListeners();
      }
    });
  }

  void finish() {
    _timer?.cancel();
    if (!isRunning) return;
    isRunning = false;
    isPaused = false;
    final completed = stats.copyWith(
      sessions: stats.sessions + 1,
      hits: stats.hits + hits,
      shots: stats.shots + hits + misses,
      bestScore: max(stats.bestScore, score),
      bestReactionMs: reactionMs == 0
          ? stats.bestReactionMs
          : (stats.bestReactionMs == 0 ? reactionMs : min(stats.bestReactionMs, reactionMs)),
      totalTimeSeconds: stats.totalTimeSeconds + settings.roundSeconds,
    );
    stats = completed;
    _saveStats();
    notifyListeners();
  }

  void tapTarget(Offset normalizedPosition) {
    if (!isRunning || isPaused) return;
    final distance = (normalizedPosition - target).distance;
    final radius = (settings.targetSize / 2) / 300;
    if (distance <= radius) {
      final now = DateTime.now();
      reactionMs = now.difference(_targetShownAt ?? now).inMilliseconds;
      final bonus = max(10, 100 - reactionMs ~/ 15);
      score += bonus;
      hits++;
      _placeTarget();
    } else {
      misses++;
    }
    notifyListeners();
  }

  void _placeTarget() {
    final margin = .12;
    target = Offset(
      margin + _random.nextDouble() * (1 - margin * 2),
      margin + _random.nextDouble() * (1 - margin * 2),
    );
    _targetShownAt = DateTime.now();
  }

  Future<void> updateSettings(TrainingSettings value) async {
    settings = value;
    remainingSeconds = value.roundSeconds;
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setInt('roundSeconds', value.roundSeconds);
    await p.setDouble('targetSize', value.targetSize);
    await p.setBool('vibration', value.vibration);
    await p.setBool('sound', value.sound);
    await p.setString('difficulty', value.difficulty);
    notifyListeners();
  }

  Future<void> _saveStats() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setInt('sessions', stats.sessions);
    await p.setInt('hits', stats.hits);
    await p.setInt('shots', stats.shots);
    await p.setInt('bestScore', stats.bestScore);
    await p.setInt('bestReactionMs', stats.bestReactionMs);
    await p.setInt('totalTimeSeconds', stats.totalTimeSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class AimTrainerApp extends StatelessWidget {
  const AimTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TrainerController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AimLab Mobile',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xff0b1018),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff6c63ff),
            brightness: Brightness.dark,
          ),
          fontFamily: 'sans',
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final pages = const [DashboardPage(), TrainingPage(), StatsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.ads_click_rounded), label: 'Train'),
          NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageTitle(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.58))),
        ]),
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TrainerController>();
    return ListView(padding: EdgeInsets.zero, children: [
      const PageTitle('AimLab Mobile', 'Fair-play practice for sharper aim'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Card(
          color: const Color(0xff171d2b),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.bolt_rounded, color: Color(0xff8c83ff), size: 32),
              const SizedBox(height: 12),
              const Text('ONE-TAP TRAINING', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4)),
              const SizedBox(height: 8),
              const Text('Build reaction speed, precision, and crosshair discipline with short focused drills.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FullTrainingScreen())),
                icon: const Icon(Icons.play_arrow_rounded), label: const Text('START SESSION'),
              ),
            ]),
          ),
        ),
      ),
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        _Metric(label: 'BEST SCORE', value: '${c.stats.bestScore}'),
        const SizedBox(width: 12),
        _Metric(label: 'ACCURACY', value: '${c.stats.accuracy.toStringAsFixed(0)}%'),
        const SizedBox(width: 12),
        _Metric(label: 'SESSIONS', value: '${c.stats.sessions}'),
      ])),
      const SectionHeader('Training focus'),
      const _Feature(icon: Icons.speed_rounded, title: 'Reaction time', text: 'Tap targets as soon as they appear.'),
      const _Feature(icon: Icons.center_focus_strong_rounded, title: 'Head-level discipline', text: 'Keep your crosshair aligned with the target line.'),
      const _Feature(icon: Icons.gps_fixed_rounded, title: 'Sensitivity control', text: 'Find a comfortable, repeatable swipe speed.'),
    ]);
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: const Color(0xff151b28), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white54))]),
      ));
}

class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)));
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _Feature({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => ListTile(leading: CircleAvatar(backgroundColor: const Color(0xff25213f), child: Icon(icon, color: const Color(0xffa49eff))), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(text));
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});
  @override
  Widget build(BuildContext context) => Center(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FullTrainingScreen())), icon: const Icon(Icons.play_arrow), label: const Text('OPEN TRAINING')));
}

class FullTrainingScreen extends StatelessWidget {
  const FullTrainingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TrainerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('One-Tap Training'), backgroundColor: Colors.transparent),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _SmallStat('TIME', '${c.remainingSeconds}s'), _SmallStat('SCORE', '${c.score}'), _SmallStat('HITS', '${c.hits}'), _SmallStat('MISS', '${c.misses}'),
        ])),
        Expanded(child: GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final size = box.size;
            c.tapTarget(Offset(local.dx / size.width, local.dy / size.height));
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xff111827), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xff29334a))),
            child: Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: GridPainter())),
              if (!c.isRunning || c.isPaused) Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(c.isPaused ? Icons.pause_circle_outline : Icons.ads_click, size: 58, color: Colors.white70), const SizedBox(height: 12), Text(c.isPaused ? 'PAUSED' : 'READY', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(c.isPaused ? 'Resume when ready' : 'Tap start to begin', style: const TextStyle(color: Colors.white54))]))
              else Positioned(
                left: c.target.dx * MediaQuery.sizeOf(context).width - 16,
                top: c.target.dy * MediaQuery.sizeOf(context).height - 105,
                child: Target(size: c.settings.targetSize),
              ),
            ]),
          ),
        )),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), child: Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: c.isRunning && !c.isPaused ? c.pause : c.start, icon: Icon(c.isRunning && !c.isPaused ? Icons.pause : Icons.play_arrow), label: Text(c.isRunning && !c.isPaused ? 'PAUSE' : 'START'))),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: c.restart, icon: const Icon(Icons.restart_alt), tooltip: 'Restart'),
        ])),
      ]),
    );
  }
}

class _SmallStat extends StatelessWidget { final String label, value; const _SmallStat(this.label, this.value); @override Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54))]); }

class Target extends StatelessWidget {
  final double size;
  const Target({required this.size, super.key});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xffff4f78), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x889b4dff), blurRadius: 18)]), child: const Center(child: Icon(Icons.add, color: Colors.white, size: 24)));
}

class GridPainter extends CustomPainter {
  const GridPainter();
  @override
  void paint(Canvas canvas, Size size) { final p = Paint()..color = const Color(0xff1b2639)..strokeWidth = 1; for (double x = 0; x < size.width; x += 42) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p); for (double y = 0; y < size.height; y += 42) canvas.drawLine(Offset(0, y), Offset(size.width, y), p); final cross = Paint()..color = const Color(0x335f6dff)..strokeWidth = 1; canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), cross); canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), cross); }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) { final s = context.watch<TrainerController>().stats; return ListView(children: [const PageTitle('Statistics', 'Track consistency, not just high scores'), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [StatRow('Sessions completed', '${s.sessions}'), StatRow('Total hits', '${s.hits}'), StatRow('Total shots', '${s.shots}'), StatRow('Overall accuracy', '${s.accuracy.toStringAsFixed(1)}%'), StatRow('Best score', '${s.bestScore}'), StatRow('Fastest reaction', s.bestReactionMs == 0 ? '--' : '${s.bestReactionMs} ms')])))), const SizedBox(height: 18), const SectionHeader('Practice tip'), const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Keep your wrist relaxed and make small, deliberate movements. Use the same sensitivity for several sessions before changing it.'))]); }
}
class StatRow extends StatelessWidget { final String label, value; const StatRow(this.label, this.value, {super.key}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white70)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))])); }

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) { final c = context.watch<TrainerController>(); final s = c.settings; return ListView(children: [const PageTitle('Settings', 'Tune your practice environment'), const SectionHeader('Session'), ListTile(title: const Text('Round duration'), subtitle: Text('${s.roundSeconds} seconds'), trailing: DropdownButton<int>(value: s.roundSeconds, items: const [30, 60, 90, 120].map((v) => DropdownMenuItem(value: v, child: Text('${v}s'))).toList(), onChanged: (v) { if (v != null) c.updateSettings(s.copyWith(roundSeconds: v)); })), ListTile(title: const Text('Target size'), subtitle: Slider(value: s.targetSize, min: 34, max: 80, divisions: 23, label: '${s.targetSize.round()}', onChanged: (v) => c.updateSettings(s.copyWith(targetSize: v)))), const SectionHeader('Feedback'), SwitchListTile(title: const Text('Vibration on hit'), value: s.vibration, onChanged: (v) => c.updateSettings(s.copyWith(vibration: v))), SwitchListTile(title: const Text('Sound cues'), subtitle: const Text('Reserved for a future audio pack'), value: s.sound, onChanged: (v) => c.updateSettings(s.copyWith(sound: v))), const SectionHeader('About'), const ListTile(leading: Icon(Icons.shield_outlined), title: Text('Standalone fair-play trainer'), subtitle: Text('This app never reads, injects into, or controls external games.'))]); }
}
