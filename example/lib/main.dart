import 'package:face_liveness_detection_example/face_liveness_detection_controller_demo.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: MyHome()));

class MyHome extends StatelessWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Demo Home Page')),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const FaceLivenessDetectionControllerDemo(),
                ),
              );
            },
            child: const Text('MobileScanner with List Controller'),
          ),
        ]),
      ),
    );
  }
}
