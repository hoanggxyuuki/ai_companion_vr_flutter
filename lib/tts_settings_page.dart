import 'package:flutter/material.dart';
import 'package:ai_companion_vr_flutter/tts_settings.dart';
import 'package:ai_companion_vr_flutter/openai_tts_service.dart';

class TTSSettingsPage extends StatefulWidget {
  final TTSSettings settings;
  final Function(TTSSettings) onSettingsChanged;

  const TTSSettingsPage({
    Key? key,
    required this.settings,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _TTSSettingsPageState createState() => _TTSSettingsPageState();
}

class _TTSSettingsPageState extends State<TTSSettingsPage> {
  late TTSSettings _settings;
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isTestingApiKey = false;
  bool _apiKeyValid = false;

  @override
  void initState() {
    super.initState();
    _settings = TTSSettings.fromJson(widget.settings.toJson());
    _apiKeyController.text = _settings.openaiApiKey;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testApiKey() async {
    if (_apiKeyController.text.isEmpty) return;
    
    setState(() {
      _isTestingApiKey = true;
    });

    try {
      final ttsService = OpenAITTSService(apiKey: _apiKeyController.text);
      final isValid = await ttsService.validateApiKey();
      
      setState(() {
        _apiKeyValid = isValid;
        _isTestingApiKey = false;
      });

      if (isValid) {
        _settings.openaiApiKey = _apiKeyController.text;
        _showSnackBar('✅ OpenAI API Key hợp lệ!', Colors.green);
        
        await ttsService.speak('Xin chào, OpenAI TTS đã được kết nối thành công!');
      } else {
        _showSnackBar('❌ OpenAI API Key không hợp lệ', Colors.red);
      }
      
      ttsService.dispose();
    } catch (e) {
      setState(() {
        _isTestingApiKey = false;
      });
      _showSnackBar('❌ Lỗi kết nối: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _saveSettings() {
    widget.onSettingsChanged(_settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🔊 TTS Settings'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('🎯 TTS Provider'),
              Card(
                color: Colors.grey[900],
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('Local TTS (Flutter)', style: TextStyle(color: Colors.white)),
                      subtitle: Text('Sử dụng TTS của thiết bị', style: TextStyle(color: Colors.grey)),
                      value: TTSSettings.LOCAL_TTS,
                      groupValue: _settings.provider,
                      onChanged: (value) {
                        setState(() {
                          _settings.provider = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('OpenAI TTS', style: TextStyle(color: Colors.white)),
                      subtitle: Text('Chất lượng cao, cần API key', style: TextStyle(color: Colors.grey)),
                      value: TTSSettings.OPENAI_TTS,
                      groupValue: _settings.provider,
                      onChanged: (value) {
                        setState(() {
                          _settings.provider = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              if (_settings.isOpenAIProvider) ...[
                _buildSectionTitle('🔑 OpenAI Configuration'),
                Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('API Key:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _apiKeyController,
                                decoration: InputDecoration(
                                  hintText: 'sk-...',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.grey[800],
                                ),
                                style: TextStyle(color: Colors.white),
                                obscureText: true,
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isTestingApiKey ? null : _testApiKey,
                              child: _isTestingApiKey 
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text('Test'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _apiKeyValid ? Colors.green : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        Text('Voice:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _settings.openaiVoice,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey[800],
                          ),
                          dropdownColor: Colors.grey[800],
                          style: TextStyle(color: Colors.white),
                          items: OpenAITTSService.voices.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value, style: TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _settings.openaiVoice = value!;
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        
                        Text('Model:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _settings.openaiModel,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey[800],
                          ),
                          dropdownColor: Colors.grey[800],
                          style: TextStyle(color: Colors.white),
                          items: [
                            DropdownMenuItem(value: 'tts-1', child: Text('TTS-1 (Fast)', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'tts-1-hd', child: Text('TTS-1-HD (High Quality)', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _settings.openaiModel = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],

              if (_settings.isLocalProvider) ...[
                _buildSectionTitle('🗣️ Local TTS Configuration'),
                Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Language:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        DropdownButtonFormField<String>(
                          value: _settings.localLanguage,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey[800],
                          ),
                          dropdownColor: Colors.grey[800],
                          style: TextStyle(color: Colors.white),
                          items: [
                            DropdownMenuItem(value: 'vi-VN', child: Text('Vietnamese', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'en-US', child: Text('English (US)', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'en-GB', child: Text('English (UK)', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _settings.localLanguage = value!;
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        
                        _buildSlider('Speech Rate', _settings.speechRate, 0.1, 2.0, (value) {
                          setState(() {
                            _settings.speechRate = value;
                          });
                        }),
                        
                        _buildSlider('Volume', _settings.volume, 0.0, 1.0, (value) {
                          setState(() {
                            _settings.volume = value;
                          });
                        }),
                        
                        _buildSlider('Pitch', _settings.pitch, 0.5, 2.0, (value) {
                          setState(() {
                            _settings.pitch = value;
                          });
                        }),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],

              _buildSectionTitle('⚙️ General Settings'),
              Card(
                color: Colors.grey[900],
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Auto Speak', style: TextStyle(color: Colors.white)),
                      subtitle: Text('Tự động đọc kết quả phát hiện', style: TextStyle(color: Colors.grey)),
                      value: _settings.autoSpeak,
                      onChanged: (value) {
                        setState(() {
                          _settings.autoSpeak = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Speak Detections', style: TextStyle(color: Colors.white)),
                      subtitle: Text('Đọc tên các vật thể phát hiện được', style: TextStyle(color: Colors.grey)),
                      value: _settings.speakDetections,
                      onChanged: (value) {
                        setState(() {
                          _settings.speakDetections = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Speak Descriptions', style: TextStyle(color: Colors.white)),
                      subtitle: Text('Đọc mô tả chi tiết từ AI', style: TextStyle(color: Colors.grey)),
                      value: _settings.speakDescriptions,
                      onChanged: (value) {
                        setState(() {
                          _settings.speakDescriptions = value;
                        });
                      },
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 20,
          onChanged: onChanged,
        ),
        SizedBox(height: 8),
      ],
    );
  }
}