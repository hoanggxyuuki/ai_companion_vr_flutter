import 'package:flutter/material.dart';
import 'package:ai_companion_vr_flutter/core/tts_service.dart';
import 'package:ai_companion_vr_flutter/core/stt_service.dart';

class VoiceTestWidget extends StatefulWidget {
  @override
  _VoiceTestWidgetState createState() => _VoiceTestWidgetState();
}

class _VoiceTestWidgetState extends State<VoiceTestWidget> {
  bool ttsReady = false;
  bool sttReady = false;
  bool isListening = false;
  bool isSpeaking = false;
  String recognizedText = '';
  String statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      statusMessage = 'Initializing voice services...';
    });

    await TTSService.initialize();
    await TTSService.setOptimalVoiceForQuest();
    
    bool sttResult = await STTService.initializeWithRetry();
    if (sttResult) {
      await STTService.optimizeForQuest();
    }
    
    setState(() {
      ttsReady = TTSService.isInitialized;
      sttReady = sttResult;
      statusMessage = 'TTS: ${ttsReady ? '✅' : '❌'} | STT: ${sttReady ? '✅' : '❌'}';
    });
  }

  Future<void> _testTTS() async {
    if (!ttsReady) return;
    
    setState(() {
      isSpeaking = true;
    });
    
    await TTSService.speak("Xin chào! Đây là test tiếng Việt trên Quest 3S");
    
    setState(() {
      isSpeaking = false;
    });
  }

  Future<void> _testDetectionTTS() async {
    if (!ttsReady) return;
    
    List<Map<String, dynamic>> testDetections = [
      {'name': 'person', 'confidence': 0.95},
      {'name': 'chair', 'confidence': 0.87},
      {'name': 'table', 'confidence': 0.79}
    ];
    
    await TTSService.speakMultipleDetections(testDetections);
  }

  Future<void> _startListening() async {
    if (!sttReady || isListening) return;
    
    setState(() {
      isListening = true;
      recognizedText = '';
      statusMessage = 'Listening... Speak in Vietnamese or English';
    });
    
    await STTService.startListening(
      onResult: (result) {
        setState(() {
          recognizedText = result;
          isListening = false;
          statusMessage = 'Voice recognition complete';
        });
        
        if (STTService.isVoiceCommand(result)) {
          String command = STTService.processVoiceCommand(result);
          TTSService.speak("Lệnh nhận được: $command");
        }
      },
      onPartialResult: (partial) {
        setState(() {
          recognizedText = partial;
        });
      },
      listenFor: Duration(seconds: 10),
      localeId: 'vi-VN',
    );
  }

  Future<void> _stopListening() async {
    await STTService.stopListening();
    setState(() {
      isListening = false;
      statusMessage = 'Voice services ready';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Test - Quest 3S'),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                color: Colors.grey[850],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Voice Services Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        statusMessage,
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              Card(
                color: Colors.grey[850],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Speech Recognition',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 80,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isListening ? Colors.red : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          isListening 
                              ? (recognizedText.isEmpty ? 'Listening...' : recognizedText)
                              : (recognizedText.isEmpty ? 'Press microphone to start' : recognizedText),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              Text(
                'Text-to-Speech Tests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: ttsReady && !isSpeaking ? _testTTS : null,
                    icon: Icon(isSpeaking ? Icons.volume_up : Icons.play_arrow),
                    label: Text('Test Vietnamese'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: ttsReady && !isSpeaking ? _testDetectionTTS : null,
                    icon: Icon(Icons.visibility),
                    label: Text('Test Detection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              Text(
                'Speech-to-Text Tests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: sttReady && !isListening ? _startListening : _stopListening,
                    icon: Icon(isListening ? Icons.mic : Icons.mic_none),
                    label: Text(isListening ? 'Stop Listening' : 'Start Listening'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isListening ? Colors.red : Colors.purple,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: recognizedText.isNotEmpty && ttsReady 
                        ? () => TTSService.speak(recognizedText) : null,
                    icon: Icon(Icons.volume_up),
                    label: Text('Speak Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              Card(
                color: Colors.grey[850],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Voice Commands (Vietnamese)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try saying:\n• "Bắt đầu" (Start)\n• "Dừng lại" (Stop)\n• "Kết nối" (Connect)\n• "Trợ giúp" (Help)',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              Spacer(),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: ttsReady ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('TTS', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: sttReady ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('STT', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isListening ? Colors.orange : 
                                isSpeaking ? Colors.blue : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        isListening ? 'Listening' : 
                        isSpeaking ? 'Speaking' : 'Ready',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    STTService.dispose();
    TTSService.stop();
    super.dispose();
  }
}