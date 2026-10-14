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
      title: 'صائد الشرارات',
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
  double playerX = 0.0; // موقع اللاعب من -1 (يسار) إلى 1 (يمين)
  double sparkX = 0.0;  // موقع الشرارة أفقياً
  double sparkY = -1.0; // موقع الشرارة عمودياً
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

      // التحقق من التقاط الشرارة عند وصولها لمستوى البطارية
      if (sparkY >= 0.75 && sparkY <= 0.90) {
        if ((sparkX - playerX).abs() < 0.28) {
          score += 10;
          if (score > highScore) highScore = score;
          // زيادة السرعة تدريجياً
          if (speed < 0.07) speed += 0.0015;
          resetSpark();
        }
      }

      
