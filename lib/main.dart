import 'package:flutter/material.dart';
import 'quest_vision_assistant.dart';

void main() {
  runApp(QuestVisionApp());
}

class QuestVisionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest 3S Vision Assistant',
      theme: ThemeData.dark(),
      home: QuestVisionAssistant(),
      debugShowCheckedModeBanner: false,
    );
  }
}