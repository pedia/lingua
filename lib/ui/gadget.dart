import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullScreen extends StatefulWidget {
  const FullScreen({this.on = true, required this.child, super.key});
  final bool on;
  final Widget child;

  @override
  State<FullScreen> createState() => _FullScreenState();
}

class _FullScreenState extends State<FullScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.on) {
      // Hide status bar when entering this screen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
    }
  }

  @override
  void dispose() {
    if (widget.on) {
      // Restore regular status bar and bottom navigation when leaving this screen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class InfoScreen extends StatelessWidget {
  const InfoScreen(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Error')),
      body: Center(
        child: Padding(padding: EdgeInsets.all(16), child: Text(text)),
      ),
    );
  }
}
