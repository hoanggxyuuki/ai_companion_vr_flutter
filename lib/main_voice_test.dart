import 'package:flutter/material.dart';
import 'voice_test_widget.dart';
import 'quest_vision_assistant.dart';

void main() {
  runApp(VoiceTestApp());
}

class VoiceTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest 3S Voice Test',
      theme: ThemeData.dark(),
      home: MainMenu(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🔥 Quest 3S Voice & Vision'),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Title
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.mic,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'AI Voice Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Meta Quest 3S Edition',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 48),
              
              // Main Vision App Button
              Container(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => QuestVisionAssistant()),
                    );
                  },
                  icon: Icon(Icons.visibility, size: 28),
                  label: Text(
                    'Start Vision Assistant',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Voice Test Button
              Container(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => VoiceTestWidget()),
                    );
                  },
                  icon: Icon(Icons.mic_none, size: 28),
                  label: Text(
                    'Test Voice Features',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 32),
              
              // Feature Cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.grey[850],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.volume_up, color: Colors.blue, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'TTS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Vietnamese\nSpeech Synthesis',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: Colors.grey[850],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.mic, color: Colors.red, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'STT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Voice Commands\n& Recognition',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: Colors.grey[850],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.green, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Vision',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Real-time\nObject Detection',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Instructions
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(height: 8),
                    Text(
                      'Instructions for Quest 3S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1. Grant camera and microphone permissions\n'
                      '2. Connect to AI server (IP: 172.20.10.3:8000)\n'
                      '3. Use voice commands: "Bắt đầu", "Dừng", "Kết nối"\n'
                      '4. Point camera at objects for detection',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}