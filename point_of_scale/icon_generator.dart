import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// This script generates an app icon with "TE" letters
void main() async {
  // Initialize binding
  WidgetsFlutterBinding.ensureInitialized();

  // Create a widget to render
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // Define the canvas size (1024x1024 is a good size for app icons)
  const size = Size(1024, 1024);
  
  // Draw background (using the green color from your app)
  final Paint bgPaint = Paint()
    ..color = const Color(0xFF6B8E7F)
    ..style = PaintingStyle.fill;
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  
  // Setup text style for "TE"
  const textStyle = TextStyle(
    color: Colors.white,
    fontSize: 480,
    fontWeight: FontWeight.bold,
    fontFamily: 'Roboto',
  );
  
  // Create a text painter
  final textSpan = TextSpan(
    text: 'TE',
    style: textStyle,
  );
  
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  );
  
  // Layout the text
  textPainter.layout(minWidth: 0, maxWidth: size.width);
  
  // Calculate position to center the text
  final xCenter = (size.width - textPainter.width) / 2;
  final yCenter = (size.height - textPainter.height) / 2;
  
  // Draw the text
  textPainter.paint(canvas, Offset(xCenter, yCenter));
  
  // Convert canvas to image
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();
  
  // Save to file
  final File file = File('assets/icon/app_icon.png');
  await file.writeAsBytes(buffer);
  
  print('Icon generated at: ${file.path}');
  exit(0);
}
