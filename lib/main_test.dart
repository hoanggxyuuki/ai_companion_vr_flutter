import 'package:flutter/material.dart';
import 'simple_camera_test.dart';

void main() {
  runApp(CameraTestApp());
}

class CameraTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest 3S Camera Test',
      theme: ThemeData.dark(),
      home: SimpleCameraTest(),
    );
  }
}