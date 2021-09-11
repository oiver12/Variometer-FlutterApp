import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:variomete_app/BeforeStartPage.dart';
import 'package:variomete_app/Speedometer.dart';
import 'package:variomete_app/main.dart';
import './BackgroundCollectingTask.dart';
import 'dart:developer';

class VariometerPage extends StatefulWidget {
  @override
  _VariometerPageState createState() => _VariometerPageState();
}

class _VariometerPageState extends State<VariometerPage> {

  @override
  void initState() {
    super.initState();
  }

  Future<Null> _startDelay() async{
    log(BluetoothObjects.collectingTask.inProgress.toString());
    await Future.delayed(const Duration(seconds: 8), () => log(BluetoothObjects.collectingTask.inProgress.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: ListView(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.1, percentageScreen.height*0.1, percentageScreen.width*0.1, percentageScreen.height*0.08),
              child: ElevatedButton(
                  onPressed: () async {
                    await BluetoothObjects.collectingTask.stopVario();
                    await BluetoothObjects.collectingTask.sendWelcomeMessage();
                    //Navigator.pushReplacementNamed(context, '/BeforeStart');
                    Navigator.pop(context);
                  },
                  child: Text("Stop Variometer"),
              ),
            ),
            ScopedModel<BackgroundCollectingTask>(
              model: BluetoothObjects.collectingTask,
              child: Speedometer(),
            ),
          ],
        ),
      ),
    );
  }
}
