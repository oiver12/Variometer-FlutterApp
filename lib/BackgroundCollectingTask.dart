import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;
import 'dart:typed_data';
import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:crclib/crclib.dart';
import 'package:variomete_app/BeforeStartPage.dart';
import 'package:variomete_app/chartSlider.dart';

class Crc8Arduino extends ParametricCrc {
  Crc8Arduino()
      : super(
      8,
      0x07,
      0x00,
      0x00,
      inputReflected: false,
      outputReflected: false);
}

class DataSample {
  double height;
  DateTime timestamp;

  DataSample({
    this.height,
    this.timestamp,
  });
}

enum arduinoPacketTypes
{
  WelcomResponsePacket,
  StartVarioPacket,
  updateState ,
}

class arduinoPackets
{
  arduinoPacketTypes type;
  int lengthPacket;
  arduinoPackets({
    this.type,
    this.lengthPacket,
  });
}

enum flutterPacketTypes
{
  welcomePacket,
  start,
  stop,
  soundSetting,
  kalmanSettings
}

class flutterPackets
{
  flutterPacketTypes type;
  int lengthPacket;
  flutterPackets({
    this.type,
    this.lengthPacket,
  });
}

class BackgroundCollectingTask extends Model {
  static BackgroundCollectingTask of(
      BuildContext context, {
        bool rebuildOnChange = false,
      }) =>
      ScopedModel.of<BackgroundCollectingTask>(
        context,
        rebuildOnChange: rebuildOnChange,
      );
  final BluetoothConnection _connection;
  List<int> _buffer = new List<int>();
  int startByte = 254;

  double startHeight;
  double reduzierterLuftdruck;
  double startTemp;
  double tempSeaLevel; //in K!!
  double lastVelocity = 0;
  double lastHeight = 0;
  List<DataSample> samples = List<DataSample>();
  bool inProgress = false;

  var _arduinoPackets = [
    //+3 für startByte + indexByte + crcByte = 3
    arduinoPackets(type: arduinoPacketTypes.WelcomResponsePacket, lengthPacket: (3+4+3)),
    arduinoPackets(type: arduinoPacketTypes.StartVarioPacket, lengthPacket:  (2*4 + 3)),
    arduinoPackets(type: arduinoPacketTypes.updateState, lengthPacket: (2 * 4 + 3)),
  ];

  var _flutterPackets = [
    flutterPackets(type:flutterPacketTypes.welcomePacket, lengthPacket: 3),
    flutterPackets(type:flutterPacketTypes.start, lengthPacket: 4 + 1  + 1 + 3),
    flutterPackets(type:flutterPacketTypes.stop, lengthPacket: 3),
    flutterPackets(type:flutterPacketTypes.soundSetting, lengthPacket: 15*4 + 3),
    flutterPackets(type:flutterPacketTypes.kalmanSettings, lengthPacket: 4 * 3 + 3)
  ];

  BackgroundCollectingTask._fromConnection(this._connection) {
    _connection.input.listen((data) {
      _buffer += data;
      bool result = true;
      //Packete abarbeiten bis kein neues Packet
      while(result && _buffer.length > 0)
      {
        result = getResultFormBuffer(_buffer);
      }
    }).onDone(() {
      inProgress = false;
      notifyListeners();
    });
  }

  //auswerten eines Pakets
  bool getResultFormBuffer(List<int> buffer)
  {
    int startIndex = 0;
    int endIndex  = 0;
    bool startedPackage = false;
    for(int i = 0; i < _buffer.length; i++)
    {
      if(_buffer[i] == startByte && i != _buffer.length-1/* && _buffer[i+1] != startByte*/)
      {
        //index ist falsch Packet fallen lassen -->Packet verpasst aber wird schon nächstes kommen...
        if(buffer[i+1] >= _arduinoPackets.length)
        {
          log("Index zu Gross von Packet! Packet verloren");
          _buffer.removeAt(i);
          return true;
        }
        //ganzes Packet ist angekommen
        if(_buffer.length - i >= _arduinoPackets[_buffer[i+1]].lengthPacket)
        {
          startIndex = i;
          endIndex = startIndex + _arduinoPackets[_buffer[i+1]].lengthPacket - 1;
          startedPackage = true;
          break;
        }
      }
    }
    if(!startedPackage)
      return false;
    log("packet");
   // log(buffer.length.toString());
    var _packet = Uint8List.fromList(_buffer.sublist(startIndex+1, endIndex));
    int crcValue = _buffer[endIndex];
    _buffer.removeRange(startIndex, endIndex + 1);
    //wenn CRC richtig, dann Paket auswerten je nach Index
    if(Crc8Arduino().convert(_packet) == crcValue)
    {
      if(_packet[0] == arduinoPacketTypes.StartVarioPacket.index)
      {
        var result = _packet.sublist(1).buffer.asFloat32List();
        double startPressure = result[0].toDouble();
        startTemp = result[1].toDouble();
        double L =  0.0065;
        tempSeaLevel = startTemp + 0.0065*startHeight + 273.15;
        reduzierterLuftdruck = startPressure / pow(1 + (-L/tempSeaLevel) * startHeight, 5.255876);
        //log(startHeight.toString() + "  " + startPressure.toString() + "  " +startTemp.toString());
        log("redLuftdruck: " + reduzierterLuftdruck.toString() + ", startDruck: " + startPressure.toString());
        lastHeight = getHeight(startPressure);
        log(lastHeight.toString());
        notifyListeners();
      }
      else if(_packet[0] == arduinoPacketTypes.updateState.index)
      {
        var result = _packet.sublist(1).buffer.asFloat32List();
        lastVelocity = result[0].toDouble();
        double pressure = result[1].toDouble();
        lastHeight = getHeight(pressure);
        notifyListeners();
      }
      else if(_packet[0] == arduinoPacketTypes.WelcomResponsePacket.index)
        {
          //log("DPS310:" + _packet[1].toString());
          //log("MPU9250:" + _packet[2].toString());
          //log("SDCard:" + _packet[3].toString());
          var result = _packet.sublist(4).buffer.asFloat32List();
          double SdCardSize = result[0]; //in Kb
          String sdCardSizeString = SdCardSize.toStringAsFixed(2) + "KB";
          if(SdCardSize / 1024 > 1) {
            SdCardSize /= 1024;
            sdCardSizeString = SdCardSize.toStringAsFixed(2) + "MB";
          }
          if(SdCardSize / 1024 > 1) {
            SdCardSize /= 1024;
            sdCardSizeString = SdCardSize.toStringAsFixed(2) + "GB";
          }
          log("SDCard Size: " + SdCardSize.toString());
          BeforeStartPage.state.setState(() {
            BeforeStartPage.state.recievedResponse = true;
            BeforeStartPage.state.dps310work = _packet[1] == 1;
            BeforeStartPage.state.mpu9250work = _packet[2] == 1;
            BeforeStartPage.state.sdCardwork = _packet[3] == 1;
            if(_packet[3] == 1)
              BeforeStartPage.state.sdCardVolume = sdCardSizeString;
          });
        }
    }
    else
    {
      log("Crc was wrong");
    }
    return true;
  }

  double getHeight(double pressure)
  {
     return (tempSeaLevel/-0.0065) * (pow(pressure/ reduzierterLuftdruck, 0.190263) -1);
  }
  
  Uint8List getBytesFromDouble(double value)
  {
    var valueFloat = new Float32List(1);
    valueFloat[0] = value;
    return valueFloat.buffer.asUint8List();
  }

  static Future<BackgroundCollectingTask> connect(
      BluetoothDevice server) async {
    final BluetoothConnection connection =
    await BluetoothConnection.toAddress(server.address);
    return BackgroundCollectingTask._fromConnection(connection);
  }

  void dispose() {
    log("Dispose");
    _connection.dispose();
  }

  Future<void> sendWelcomeMessage() async
  {
    log("SendWelcome");
    Uint8List sendBuffer = Uint8List(_flutterPackets[0].lengthPacket);
    int indexBuffer = 0;
    sendBuffer[indexBuffer] = startByte;
    indexBuffer++;
    sendBuffer[indexBuffer] = flutterPacketTypes.welcomePacket.index;
    indexBuffer++;
    sendBuffer[indexBuffer] = int.parse(Crc8Arduino().convert(sendBuffer.sublist(1, indexBuffer)).toString());
    indexBuffer++;
    _connection.output.add(sendBuffer);
    await _connection.output.allSent;
  }

  Future<void> startVario(double height, bool useXCTrack, bool soundON) async
  {
    startHeight = height;
    Uint8List sendBuffer = Uint8List(_flutterPackets[1].lengthPacket);
    int indexBuffer = 0;
    sendBuffer[indexBuffer] = startByte;
    indexBuffer++;
    sendBuffer[indexBuffer] = flutterPacketTypes.start.index;
    indexBuffer++;
    var bytesHeight = getBytesFromDouble(height);
    for(int i = 0; i< bytesHeight.length; i++)
    {
      sendBuffer[indexBuffer] = bytesHeight[i];
      indexBuffer++;
    }
    sendBuffer[indexBuffer] = useXCTrack ? 1: 0;
    indexBuffer++;
    sendBuffer[indexBuffer] = soundON ? 1: 0;
    indexBuffer++;
    sendBuffer[indexBuffer] = int.parse(Crc8Arduino().convert(sendBuffer.sublist(1, indexBuffer)).toString());
    indexBuffer++;
    _connection.output.add(sendBuffer);
    inProgress = true;
    notifyListeners();
    await _connection.output.allSent;
  }

  Future<void> stopVario() async
  {
    inProgress = false;
    notifyListeners();
    Uint8List sendBuffer = Uint8List(_flutterPackets[2].lengthPacket);
    int indexBuffer = 0;
    sendBuffer[indexBuffer] = startByte;
    indexBuffer++;
    sendBuffer[indexBuffer] = flutterPacketTypes.stop.index;
    indexBuffer++;
    sendBuffer[indexBuffer] = int.parse(Crc8Arduino().convert(sendBuffer.sublist(1, indexBuffer)).toString());
    indexBuffer++;
    for(int i = 0; i< sendBuffer.length; i++)
      log(sendBuffer[i].toString());
    _connection.output.add(sendBuffer);
    await _connection.output.allSent;
  }

  Future<void> sendSoundSettings() async
  {
    Uint8List sendBuffer = Uint8List(_flutterPackets[3].lengthPacket);
    int indexBuffer = 0;
    sendBuffer[indexBuffer] = startByte;
    indexBuffer++;
    sendBuffer[indexBuffer] = flutterPacketTypes.soundSetting.index;
    indexBuffer++;
    var bytesPoint = getBytesFromSoundPoint(SliderLine.pointsOfSlide[1]);
    for(int i = 0; i< bytesPoint.length; i++)
    {
      sendBuffer[indexBuffer] = bytesPoint[i];
      indexBuffer++;
    }
    bytesPoint = getBytesFromSoundPoint(SliderLine.pointsOfSlide[4]);
    for(int i = 0; i< bytesPoint.length; i++)
    {
      sendBuffer[indexBuffer] = bytesPoint[i];
      indexBuffer++;
    }
    bytesPoint = getBytesFromSoundPoint(SliderLine.pointsOfSlide[5]);
    for(int i = 0; i< bytesPoint.length; i++)
    {
      sendBuffer[indexBuffer] = bytesPoint[i];
      indexBuffer++;
    }
    bytesPoint = getBytesFromSoundPoint(SliderLine.pointsOfSlide[6]);
    for(int i = 0; i< bytesPoint.length; i++)
    {
      sendBuffer[indexBuffer] = bytesPoint[i];
      indexBuffer++;
    }
    bytesPoint = getBytesFromSoundPoint(SliderLine.pointsOfSlide[7]);
    for(int i = 0; i< bytesPoint.length; i++)
    {
      sendBuffer[indexBuffer] = bytesPoint[i];
      indexBuffer++;
    }
    sendBuffer[indexBuffer] = int.parse(Crc8Arduino().convert(sendBuffer.sublist(1, indexBuffer)).toString());
    indexBuffer++;
    _connection.output.add(sendBuffer);
    await _connection.output.allSent;
  }

  Uint8List getBytesFromSoundPoint(ToneFrequency point)
  {
    var valueFloat = new Float32List(3);
    valueFloat[0] = point.velocity;
    valueFloat[1] = point.frequeny;
    valueFloat[2] = point.lengthTone;
    return valueFloat.buffer.asUint8List();
  }

  Future<void> sendKalmanSetting(double standHeight, double standAcc, double processNoise) async
  {
    Uint8List sendBuffer = Uint8List(_flutterPackets[4].lengthPacket);
    int indexBuffer = 0;
    sendBuffer[indexBuffer] = startByte;
    indexBuffer++;
    sendBuffer[indexBuffer] = flutterPacketTypes.kalmanSettings.index;
    indexBuffer++;
    var bytesDouble = getBytesFromDouble(standHeight);
    for(int i = 0; i< bytesDouble.length; i++)
    {
      sendBuffer[indexBuffer] = bytesDouble[i];
      indexBuffer++;
    }
    bytesDouble = getBytesFromDouble(standAcc);
    for(int i = 0; i< bytesDouble.length; i++)
    {
      sendBuffer[indexBuffer] = bytesDouble[i];
      indexBuffer++;
    }
    bytesDouble = getBytesFromDouble(processNoise);
    for(int i = 0; i< bytesDouble.length; i++)
    {
      sendBuffer[indexBuffer] = bytesDouble[i];
      indexBuffer++;
    }
    sendBuffer[indexBuffer] = int.parse(Crc8Arduino().convert(sendBuffer.sublist(1, indexBuffer)).toString());
    indexBuffer++;
    _connection.output.add(sendBuffer);
    await _connection.output.allSent;
  }
  
  void start() {
    samples.clear();
  }

  Future<void> cancel() async {
    inProgress = false;
    notifyListeners();
    await _connection.finish();
  }

  Iterable<DataSample> getLastOf(Duration duration) {
    DateTime startingTime = DateTime.now().subtract(duration);
    int i = samples.length;
    do {
      i -= 1;
      if (i <= 0) {
        break;
      }
    } while (samples[i].timestamp.isAfter(startingTime));
    return samples.getRange(i, samples.length);
  }
}
