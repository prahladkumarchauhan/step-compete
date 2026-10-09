import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StepCompeteApp());
}

class AppColors {
  static const bg = Color(0xFF0B0F0E);
  static const card = Color(0xFF171D1A);
  static const green = Color(0xFFB6F36B);
  static const muted = Color(0xFF9AA69D);
}

class StepCompeteApp extends StatelessWidget {
  const StepCompeteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Step & Compete',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.green,
            surface: AppColors.card,
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: AppColors.card,
            indicatorColor: Color(0xFF34452B),
          ),
        ),
        home: const Dashboard(),
      );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _tab = 0;
  int _todaySteps = 0;
  int? _lastSensorTotal;
  String _status = 'Connecting to step sensor…';
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  static const int dailyGoal = 8000;

  @override
  void initState() {
    super.initState();
    _loadToday();
    _listenToSensor();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString('saved_date') != today) {
      await prefs.setString('saved_date', today);
      await prefs.setInt('today_steps', 0);
      await prefs.remove('sensor_baseline');
      if (mounted) setState(() => _todaySteps = 0);
    } else {
      if (!mounted) return;
      setState(() {
        _todaySteps = prefs.getInt('today_steps') ?? 0;
        _lastSensorTotal = prefs.getInt('sensor_baseline');
      });
    }
  }

  void _listenToSensor() {
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (_) {
          if (mounted) setState(() => _status = 'Step sensor unavailable');
        },
      );
      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
        (event) {
          if (mounted) setState(() => _status = 'Activity: ${event.status}');
        },
        onError: (_) {
          if (mounted) setState(() => _status = 'Step counter ready');
        },
      );
    } catch (_) {
      if (mounted) setState(() => _status = 'Sensor unavailable on this device');
    }
  }

  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString('saved_date') != today) {
      await prefs.setString('saved_date', today);
      await prefs.setInt('today_steps', 0);
      await prefs.remove('sensor_baseline');
      _lastSensorTotal = null;
      _todaySteps = 0;
    }

    final previous = _lastSensorTotal;
    // Sensor totals can be cumulative since reboot. First reading becomes
    // the baseline; later readings add only their positive difference.
    if (previous == null || event.steps < previous) {
      _lastSensorTotal = event.steps;
      await prefs.setInt('sensor_baseline', event.steps);
    } else {
      final delta = event.steps - previous;
      if (delta > 0) _todaySteps += delta;
      _lastSensorTotal = event.steps;
      await prefs.setInt('sensor_baseline', event.steps);
      await prefs.setInt('today_steps', _todaySteps);
    }

    if (mounted) {
      setState(() {
        if (_status.startsWith('Connecting')) _status = 'Step sensor connected';
      });
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(steps: _todaySteps, goal: dailyGoal, status: _status),
      const SimplePage(title: 'Leaderboard', subtitle: 'Connect accounts and cloud sync to see real friends rankings.', icon: Icons.leaderboard),
      const SimplePage(title: 'Challenges', subtitle: 'Create daily and weekly walking challenges.', icon: Icons.emoji_events),
      const SimplePage(title: 'Friends & Groups', subtitle: 'Invite codes and groups will be connected next.', icon: Icons.group),
      const SimplePage(title: 'Your Profile', subtitle: 'Account, daily goal and activity history.', icon: Icons.person),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_walk), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Ranking'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Challenges'),
          NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final int steps;
  final int goal;
  final String status;
  const HomePage({super.key, required this.steps, required this.goal, required this.status});

  @override
  Widget build(BuildContext context) {
    final progress = (steps / goal).clamp(0.0, 1.0);
    final km = steps * 0.00075;
    final calories = steps * 0.04;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      children: [
        const Text('STEP & COMPETE', style: TextStyle(color: AppColors.green, letterSpacing: 3, fontWeight: FontWeight.bold)),
        const SizedBox(height: 26),
        const Text('Keep moving.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        const Text('Every step counts.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(28)),
          child: Column(children: [
            const Text("TODAY'S STEPS", style: TextStyle(color: AppColors.muted, letterSpacing: 2)),
            const SizedBox(height: 22),
            SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(
                value: progress, strokeWidth: 12, backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$steps', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                Text('of $goal steps', style: const TextStyle(color: AppColors.muted)),
              ]),
            ])),
            const SizedBox(height: 18),
            Text('${(progress * 100).round()}% of your daily goal', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(status, style: const TextStyle(color: AppColors.muted, fontSize: 12), textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: StatCard(title: 'Distance*', value: '${km.toStringAsFixed(2)} km', icon: Icons.route)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(title: 'Calories*', value: '${calories.toStringAsFixed(0)} kcal', icon: Icons.local_fire_department)),
        ]),
        const SizedBox(height: 12),
        const Text('*Estimates only; stride length and calories vary by person.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 24),
        const Text('Your goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            Icon(Icons.flag_outlined, color: AppColors.green, size: 30),
            SizedBox(width: 12),
            Expanded(child: Text('Walk a little more today. Your friends challenge features can be connected next.')),
          ]),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const StatCard({super.key, required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.green),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    ]),
  );
}

class SimplePage extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const SimplePage({super.key, required this.title, required this.subtitle, required this.icon});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 58, color: AppColors.green),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(subtitle, style: const TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
      ]),
    ),
  );
}
