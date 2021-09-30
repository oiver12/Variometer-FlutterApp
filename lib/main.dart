import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:variomete_app/BeforeStartPage.dart';

import './BackgroundCollectingTask.dart';
import './SelectBondedDevicePage.dart';
import 'BeforeStartPage.dart';
import 'VariometerPage.dart';

void main() {
  runApp(MyApp());
}

class percentageScreen
{
  static double width;
  static double height;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Variometer',
      initialRoute: '/BeforeStart',
      routes: {
        '/': (context) => MyHomePage(),
        '/BeforeStart': (context) => BeforeStartPage(),
        '/VariometerPage': (context) => VariometerPage(),
      },
    );
  }
}

class BluetoothObjects
{
  static BackgroundCollectingTask collectingTask;
  static BluetoothDevice selectedDevice;
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  String _address = "...";
  String _name = "...";

  Timer _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if (await FlutterBluetoothSerial.instance.isEnabled) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        // Discoverable mode is disabled when Bluetooth gets disabled
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  @override
  void dispose() {
    //FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    //_collectingTask?.dispose();
    //_discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    percentageScreen.width = MediaQuery.of(context).size.width;
    percentageScreen.height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        width: percentageScreen.width,
        height: percentageScreen.height,
        child: ListView(
          children: <Widget>[
            SizedBox(height: percentageScreen.height * 0.4,),
            Padding(
              padding: EdgeInsets.only(left: percentageScreen.width*0.1, right: percentageScreen.width*0.1),
              child: RaisedButton(
                color: Colors.blueAccent,
                child: const Text('Connect to device', style: TextStyle(color: Colors.white),),
                onPressed: () async {
                  BluetoothObjects.selectedDevice =
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return SelectBondedDevicePage(
                            checkAvailability: false);
                      },
                    ),
                  );
                  if ( BluetoothObjects.selectedDevice != null) {
                    await _startBackgroundTask(context,  BluetoothObjects.selectedDevice);
                    if(BluetoothObjects.collectingTask != null) {
                      await BluetoothObjects.collectingTask.sendWelcomeMessage();
                      Navigator.pushReplacementNamed(context, '/BeforeStart');
                    }
                  }
                  //}
                },
              ),
            ),
          ],
        ),
        ),
    );
  }

  Future<void> _startBackgroundTask(
      BuildContext context,
      BluetoothDevice server,
      ) async {
    try {
      BluetoothObjects.collectingTask = await BackgroundCollectingTask.connect(server);
      await BluetoothObjects.collectingTask.start();
    } catch (ex) {
      if (BluetoothObjects.collectingTask != null) {
        BluetoothObjects.collectingTask.cancel();
      }
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error occured while connecting'),
            content: Text("${ex.toString()}"),
            actions: <Widget>[
              new FlatButton(
                child: new Text("Schliessen"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
