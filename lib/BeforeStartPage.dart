import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import './BackgroundCollectingTask.dart';
import './SelectBondedDevicePage.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'chartSlider.dart';

class BeforeStartPage extends StatefulWidget {
  static _BeforeStartPageState state;
  @override
  _BeforeStartPageState createState(){
    state = new _BeforeStartPageState();
    return state;
  }
}

class _BeforeStartPageState extends State<BeforeStartPage> {

  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  String _address = "...";
  String _name = "...";

  Timer _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  final heightTextFieldController = TextEditingController();
  bool dps310work = false;
  bool mpu9250work = false;
  bool sdCardwork = false;
  String sdCardVolume = "";
  bool recievedResponse = false;
  bool bluetoothConnected = false;
  bool useXCTrack = false;
  bool startedXCTrack = false;

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
    heightTextFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log(startedXCTrack.toString());
    return Scaffold(
      body: Container(
          child: ListView(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.1,
                    percentageScreen.height * 0.05,
                    percentageScreen.width * 0.1,
                    percentageScreen.height * 0.05),
                child: ElevatedButton(
                  onPressed: () async {
                    if (bluetoothConnected) {
                      await BluetoothObjects.collectingTask.cancel();
                      BluetoothObjects.collectingTask = null;
                      setState(() {
                        mpu9250work = false;
                        dps310work = false;
                        bluetoothConnected = false;
                      });
                    }
                    else {
                      BluetoothObjects.selectedDevice =
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) {
                            return SelectBondedDevicePage(
                                checkAvailability: false);
                          },
                        ),
                      );
                      if (BluetoothObjects.selectedDevice != null) {
                        await _startBackgroundTask(
                            context, BluetoothObjects.selectedDevice);
                        if (BluetoothObjects.collectingTask != null) {
                          await BluetoothObjects.collectingTask
                              .sendWelcomeMessage();
                          setState(() {
                            bluetoothConnected = true;
                          });
                        }
                      }
                    }
                  },
                  child: bluetoothConnected
                      ? Text("Disconnect from Variometer")
                      : Text("Connect to Variometer"),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.2, 0,
                    percentageScreen.width * 0.2, 0),
                child: TextField(
                  enabled: bluetoothConnected,
                  keyboardType: TextInputType.number,
                  controller: heightTextFieldController,
                  style: TextStyle(),
                  decoration: InputDecoration(
                    enabledBorder: new OutlineInputBorder(
                      borderRadius: new BorderRadius.circular(25.0),
                      borderSide: BorderSide(),
                    ),
                    focusedBorder: new OutlineInputBorder(
                      borderRadius: new BorderRadius.circular(25.0),
                      borderSide: BorderSide(),
                    ),
                    hintText: 'Start height',
                    hintStyle: TextStyle(),
                  ),
                ),
              ),
              SizedBox(
                height: percentageScreen.height * 0.03,
              ),
              ListTile(
                title: ElevatedButton(
                  //(_collectingTask != null && _collectingTask.inProgress)
                  child: !startedXCTrack ? const Text("Start Variometer") : const Text("Stop Variometer"),
                  onPressed: bluetoothConnected ? () {
                    if(!startedXCTrack) {
                      BluetoothObjects.collectingTask.startVario(double.parse(heightTextFieldController.text), useXCTrack);
                      if (!useXCTrack)
                        Navigator.pushNamed(context, '/VariometerPage');
                      else {
                        setState(() {
                          startedXCTrack = true;
                        });
                      }
                    }
                    else
                      {
                        BluetoothObjects.collectingTask.stopVario();
                        setState(() {
                          startedXCTrack = false;
                          mpu9250work = false;
                          dps310work = false;
                        });
                      }
                  } : null,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.3, percentageScreen.height * 0.03, 0, 0),
                child: Row(
                  children: <Widget>[
                    Text("Use XC Track"),
                    Checkbox(
                        value: useXCTrack,
                        onChanged:(bool){
                          setState(() {
                            useXCTrack = bool;
                          });
                        }
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.03, percentageScreen.height * 0.03, 0, 0),
                child: Text(
                  "Components:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: percentageScreen.height * 0.01,),
              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.03,
                    percentageScreen.height * 0.02,
                    percentageScreen.width * 0.3, 0),
                child: Container(
                  height: percentageScreen.height * 0.06,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    color: bluetoothConnected ? Colors.green : Colors.red,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      //SizedBox(width: percentageScreen.width*0.05,),
                      //SizedBox(height: percentageScreen.height * 0.06),
                      Icon(
                        bluetoothConnected ? Icons.bluetooth_connected : Icons
                            .bluetooth_disabled, size: 35,),
                      //SizedBox(width: percentageScreen.width*0.1,),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            bluetoothConnected ? BluetoothObjects.selectedDevice
                                .name : "Not conected",
                            style: TextStyle(fontSize: 20),),
                          Text(
                            bluetoothConnected ? BluetoothObjects.selectedDevice
                                .address : "",
                            style: TextStyle(fontSize: 10),)
                        ],
                      ),
                      //SizedBox(width: percentageScreen.width * 0.1,),
                      ImageIcon(
                        bluetoothConnected ? AssetImage(
                            'images/connected_icon.png') : AssetImage(
                            'images/not_connected_icon.png'),
                        size: 25,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.03,
                    percentageScreen.height * 0.02,
                    percentageScreen.width * 0.3, 0),
                child: Container(
                  height: percentageScreen.height * 0.06,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    color: dps310work ? Colors.green : Colors.red,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      //SizedBox(width: percentageScreen.width*0.05,),
                      //SizedBox(height: percentageScreen.height * 0.06),
                      ImageIcon(
                        AssetImage('images/pressure_4667.png'),
                        size: 35,
                      ),
                      //SizedBox(width: percentageScreen.width*0.1,),
                      Text("DPS310", style: TextStyle(fontSize: 20),),
                      //SizedBox(width: percentageScreen.width * 0.12,),
                      ImageIcon(
                        dps310work
                            ? AssetImage('images/connected_icon.png')
                            : AssetImage('images/not_connected_icon.png'),
                        size: dps310work ? 25 : 30,
                      )
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.03,
                    percentageScreen.height * 0.02,
                    percentageScreen.width * 0.3, 0),
                child: Container(
                  height: percentageScreen.height * 0.06,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    color: mpu9250work ? Colors.green : Colors.red,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      //SizedBox(width: percentageScreen.width*0.05,),
                      //SizedBox(height: percentageScreen.height * 0.06),
                      ImageIcon(
                        AssetImage('images/favpng_accelerometer-clip-art.png'),
                        size: 35,
                      ),
                      //SizedBox(width: percentageScreen.width*0.09,),
                      Text("MPU-9250", style: TextStyle(fontSize: 20),),
                      //SizedBox(width: percentageScreen.width * 0.07,),
                      ImageIcon(
                        mpu9250work
                            ? AssetImage('images/connected_icon.png')
                            : AssetImage('images/not_connected_icon.png'),
                        size: mpu9250work ? 25 : 30,
                      )
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(percentageScreen.width * 0.03,
                    percentageScreen.height * 0.02,
                    percentageScreen.width * 0.3, 0),
                child: Container(
                  height: percentageScreen.height * 0.06,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    color: sdCardwork ? Colors.green : Colors.red,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      //SizedBox(width: percentageScreen.width*0.05,),
                      //SizedBox(height: percentageScreen.height * 0.1),
                      Icon(Icons.sd_card_rounded, size: 32,),
                      //SizedBox(width: percentageScreen.width*0.08,),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text("SD-Card", style: TextStyle(fontSize: 20),),
                          //SizedBox(height: percentageScreen.height * 0.01,),
                          bluetoothConnected ? Text(sdCardVolume + " full Space", style: TextStyle(fontSize: 13),) : Container(),
                        ],
                      ),
                      //SizedBox(width: sdCardwork ? percentageScreen.width * 0.07 :  percentageScreen.width * 0.14,),
                      ImageIcon(
                        sdCardwork
                            ? AssetImage('images/connected_icon.png')
                            : AssetImage('images/not_connected_icon.png'),
                        size: sdCardwork ? 25 : 30,
                      ),
                    ],
                  ),
                ),
              ),
              SliderLine.withSampleData(),
            ],
          )
      ),
    );
  }

  Future<void> _startBackgroundTask(BuildContext context, BluetoothDevice server,) async
  {
    try {
      BluetoothObjects.collectingTask =
      await BackgroundCollectingTask.connect(server);
      await BluetoothObjects.collectingTask.start();
    }
    catch (ex) {
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


