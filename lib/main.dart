import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:variomete_app/Speedometer.dart';

import './BackgroundCollectingTask.dart';
import './SelectBondedDevicePage.dart';

void main() {
  runApp(MyApp());
}

class percentageScreen
{
  static double width;
  static double height;
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Variometer',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Variometer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  String _address = "...";
  String _name = "...";

  Timer _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  BackgroundCollectingTask _collectingTask;

  final heightTextFieldController = TextEditingController();

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
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _collectingTask?.dispose();
    _discoverableTimeoutTimer?.cancel();
    heightTextFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    percentageScreen.width = MediaQuery.of(context).size.width;
    percentageScreen.height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: ListView(
          children: <Widget>[
            SizedBox(
              height: percentageScreen.height*0.05,
            ),
            ListTile(
              title: RaisedButton(
                color: Colors.white,
                child: ((_collectingTask != null)
                    ? const Text('Disconnect and stop background collecting')
                    : const Text('Connect to device')),
                onPressed: () async {
                  if (_collectingTask != null) {
                    await _collectingTask.cancel();
                    setState(() {
                      _collectingTask = null;
                      /* Update for `_collectingTask == null` */
                    });
                  } else {
                    final BluetoothDevice selectedDevice =
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return SelectBondedDevicePage(
                              checkAvailability: false);
                        },
                      ),
                    );
                    if (selectedDevice != null) {
                      await _startBackgroundTask(context, selectedDevice);
                      setState(() {
                        /* Update for `_collectingTask != null` */
                      });
                    }
                  }
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(percentageScreen.width*0.2, 0, percentageScreen.width*0.2, 0),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: heightTextFieldController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                    enabledBorder: new OutlineInputBorder(
                      borderRadius: new BorderRadius.circular(25.0),
                      borderSide:  BorderSide(color: Colors.white ),
                    ),
                    focusedBorder: new OutlineInputBorder(
                      borderRadius: new BorderRadius.circular(25.0),
                      borderSide:  BorderSide(color: Colors.lightBlueAccent ),
                    ),
                    hintText: 'Start height',
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
              ),
            ),
            ListTile(
              title: RaisedButton(
                color: Colors.white,
                disabledColor: Colors.white54,
                child: ((_collectingTask != null && _collectingTask.inProgress)
                ? const Text("Stop Variometer")
                : const Text("Start Variometer")
                ),
                onPressed: ((_collectingTask != null)
                  ? () {
                  if(_collectingTask.inProgress)
                    _collectingTask.stopVario();
                  else
                    _collectingTask.startVario(double.parse(heightTextFieldController.text));

                  setState(() {
                    /* Update for `_collectingTask.inProgress` */
                  });
                }
                :null),
              ),
            ),
            ((_collectingTask != null && _collectingTask.inProgress)
                ? ScopedModel<BackgroundCollectingTask>(
                  model: _collectingTask,
                  child: Speedometer(),
                )
                : Container()
            ),
            /*ListTile(
              title: RaisedButton(
                child: const Text('View background collected data'),
                onPressed: (_collectingTask != null && _collectingTask.inProgress)
                    ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return ScopedModel<BackgroundCollectingTask>(
                          model: _collectingTask,
                          child: BackgroundCollectedPage(),
                        );
                      },
                    ),
                  );
                }
                    : null,
              ),
            ),*/
          ],
        ),
        ),// This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> _startBackgroundTask(
      BuildContext context,
      BluetoothDevice server,
      ) async {
    try {
      _collectingTask = await BackgroundCollectingTask.connect(server);
      await _collectingTask.start();
    } catch (ex) {
      if (_collectingTask != null) {
        _collectingTask.cancel();
      }
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error occured while connecting'),
            content: Text("${ex.toString()}"),
            actions: <Widget>[
              new FlatButton(
                child: new Text("Close"),
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
