import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const SparkCatcherApp());
}

class SparkCatcherApp extends StatelessWidget {
  const SparkCatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spark Catcher',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  double playerX = 0.0;
  double sparkX = 0.0;
  double sparkY = -1.0;
  int score = 0;
  int highScore = 0;
  int lives = 3;
  bool isPlaying = false;
  double speed = 0.025;
  Timer? gameTimer;
  final Random random = Random();

  void startGame() {
    setState(() {
      score = 0;
      lives = 3;
      speed = 0.025;
      sparkY = -1.0;
      sparkX = (random.nextDouble() * 1.6) - 0.8;
      isPlaying = true;
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      updateGame();
    });
  }

  void updateGame() {
    setState(() {
      sparkY += speed;

      if (sparkY >= 0.75 && sparkY <= 0.90) {
        if ((sparkX - playerX).abs() < 0.28) {
          score += 10;
          if (score > highScore) {
            highScore = score;
          }
          if (speed < 0.07) {
            speed += 0.0015;
          }
          resetSpark();
        }
      }

      if (sparkY > 1.1) {
        lives--;
        if (lives <= 0) {
          isPlaying = false;
          gameTimer?.cancel();
        } else {
          resetSpark();
        }
      }
    });
  }

  void resetSpark() {
    sparkY = -1.0;
    sparkX = (random.nextDouble() * 1.6) - 0.8;
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (!isPlaying) return;
            setState(() {
              double screenWidth = MediaQuery.of(context).size.width;
              playerX += (details.delta.dx / (screenWidth / 2));
              playerX = playerX.clamp(-0.85, 0.85);
            });
          },
          child: Stack(
            children: [
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '⚡ الرصيد: $score W',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        3,
                        (index) => Icon(
                          index < lives ? Icons.favorite : Icons.favorite_border,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPlaying)
                Align(
                  alignment: Alignment(sparkX, sparkY),
                  child: const Icon(
                    Icons.bolt,
                    color: Colors.yellowAccent,
                    size: 48,
                  ),
                ),
              Align(
                alignment: Alignment(playerX, 0.85),
                child: Container(
                  width: 90,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade700,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.battery_charging_full, color: Colors.white),
                  ),
                ),
              ),
              if (!isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amberAccent, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.electric_bolt, color: Colors.amber, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          lives <= 0 ? 'انتهت الطاقة! 🪫' : 'صائد الشرارات ⚡',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'أعلى رصيد: $highScore W',
                          style: const TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                          ),
                          onPressed: startGame,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            lives <= 0 ? 'إعادة الشحن (العب مجدداً)' : 'ابدأ اللعب الآن',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
 
