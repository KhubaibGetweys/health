import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

final health = Health();
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StepsApp());
}

class StepsApp extends StatelessWidget {
  const StepsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, fontFamily: 'Arial'),
      home: const StepsScreen(),
    );
  }
}

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  int _steps = 0;
  bool _isLoading = false;

  Future<void> _fetchSteps() async {
    setState(() => _isLoading = true);

    try {
      log("Fetching steps...");
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Request permission
      bool granted = await health.requestAuthorization(
        [HealthDataType.STEPS],
      );
      int? steps1 = await health.getTotalStepsInInterval(midnight, now);
      log("step1: $steps1");
      if (granted) {
        log("✅ Health permissions granted");
        int? steps = await health.getTotalStepsInInterval(midnight, now);
        setState(() {
          _steps = steps ?? 0;
        });
      } else {
        log("$_steps Health permissions not granted");
        setState(() => _steps = 0);
      }
    } catch (e, stack) {
      final errorDetails = {
        "error": e.toString(),
        "stack": stack.toString(),
        "time": DateTime.now().toIso8601String(),
      };

      log("❌ Error fetching steps: $e");

      // Send error to webhook
      testing(errorDetails);

      setState(() => _steps = 0);
    }

    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _fetchSteps();
  }

  Future<void> _addSteps(int stepsToAdd) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 5));
    final end = now;

    try {
      // Request READ & WRITE permissions
      bool granted = await health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ_WRITE],
      );

      if (!granted) {
        log("✅ WRITE permission not granted");
        return;
      }

      // Write step data
      bool success = await health.writeHealthData(
        value: stepsToAdd.toDouble(),
        type: HealthDataType.STEPS,
        startTime: start,
        endTime: end,
      );

      if (success) {
        log("✅ Successfully wrote $stepsToAdd steps to Health");
        _fetchSteps();
      } else {
        log("❌ Failed to write steps");
      }
    } catch (e, stack) {
      log("Error writing steps: $e\n$stack");
    }
  }

  Future<void> testing(Map<String, String> payload) async {
    const url = 'https://webhook.site/21cf0e9d-0511-4d77-b1c4-d5ab00c189d7';

    try {
      await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending test webhook: \\${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: const Text("Step Counter"),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          _addSteps(10);
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_walk,
                          size: 80,
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Today's Steps",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "$_steps",
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchSteps,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Refresh"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
