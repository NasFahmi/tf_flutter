import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tf_flutter/main.dart';
import 'package:tf_flutter/screen/camera_screen.dart';

class Home extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Home({super.key, required this.cameras});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Container(
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context)=>CameraScreen(cameras: cameras,)));
            },
            child: Text('Open Camera'),
          ),
        ),
      )),
    );
  }
}
