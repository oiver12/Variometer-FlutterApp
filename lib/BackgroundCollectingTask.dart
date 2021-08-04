import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:crclib/crclib.dart';

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
  double pressure;
  DateTime timestamp;

  DataSample({
    this.pressure,
    this.timestamp,
  });
}

enum arduinoPacketTypes
{
  startPacket,
  updateState,
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
  start,
  stop,
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

  List<DataSample> samples = List<DataSample>();
  bool inProgress = false;

  var _arduinoPackets = [
    //+3 für startByte + indexByte + crcByte = 3
    arduinoPackets(type: arduinoPacketTypes.startPacket, lengthPacket: (2 * 4 + 3)),
    arduinoPackets(type: arduinoPacketTypes.updateState, lengthPacket: (2 * 4 + 3)),
  ];

  var _flutterPackets = [
    flutterPackets(type:flutterPacketTypes.start, lengthPacket: 4+3),
    flutterPackets(type:flutterPacketTypes.stop, lengthPacket: 3)
  ];

  BackgroundCollectingTask._fromConnection(this._connection) {
    _connection.input.listen((data) {
      _buffer += data;
      bool result = true;
      //Packete abarbeiten bis kein neues Packet
      while(result && _buffer.length > 0)
      {
        result = getResultFormBuffer(_buffer);
        log("Done once");
      }
    }).onDone(() {
      inProgress = false;
      notifyListeners();
    });
  }

  bool getResultFormBuffer(List<int> buffer)
  {
    int startIndex = 0;
    int endIndex  = 0;
    bool startedPackage = false;
    for(int i = 0; i < _buffer.length; i++)
    {
      if(_buffer[i] == startByte && i != _buffer.length-1 && _buffer[i+1] != startByte)
      {
        //ganzes Packet ist angekommen
        if(_buffer.length - i >= _arduinoPackets[_buffer[i+1]].lengthPacket)
        {
          startIndex = i;
          //index ist falsch Packet fallen lassen -->Packet verpasst aber wird schon nächstes kommen...
          if(buffer[i+1] >= _arduinoPackets.length)
          {
            log("Index zu Gross von Packet! Packet verloren");
            _buffer.removeAt(i);
            return true;
          }
          endIndex = startIndex + _arduinoPackets[_buffer[i+1]].lengthPacket - 1;
          startedPackage = true;
          break;
        }
      }
    }
    if(!startedPackage)
      return false;
    var _packet = Uint8List.fromList(_buffer.sublist(startIndex+1, endIndex));
    int crcValue = _buffer[endIndex];
    _buffer.removeRange(startIndex, endIndex + 1);
    /*for(int i = 0; i < _packet.length; i++)
        {
          log("Packet at: " + i.toString() + " is " + _packet[i].toString());
        }*/
    //log("StartIndex: " + startIndex.toString() + "crc: " + Crc8Arduino().convert(_packet).toString());
    //log(Crc8Arduino().convert(_packet).toString() + "  " + crcValue.toString());
    if(Crc8Arduino().convert(_packet) == crcValue)
    {
      if(_packet[0] == arduinoPacketTypes.updateState.index)
      {
        log("StartPacket");
        var result = _packet.sublist(1).buffer.asFloat32List();
        double startPressure = result[0].toDouble();
        double startTemp = result[1].toDouble();
      }
      else if(_packet[0] == arduinoPacketTypes.updateState.index)
      {
        log("UpdateState");
        var result = _packet.sublist(1).buffer.asFloat32List();
        double velocity = result[0].toDouble();
        double height = result[1].toDouble();
      }
    }
    else
    {
      log("Crc was wrong");
    }
    return true;
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
    _connection.dispose();
  }

  Future<void> startVario(double height) async
  {
    Uint8List sendBuffer = Uint8List(_flutterPackets[0].lengthPacket);
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
    Uint8List sendBuffer = Uint8List(_flutterPackets[1].lengthPacket);
    int indexBuffer = 0;

    sendBuffer[indexBuffer] = startByte;
    indexBuffer++;
    sendBuffer[indexBuffer] = flutterPacketTypes.stop.index;
    indexBuffer++;
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
    _connection.output.add(ascii.encode('ccc'));
    await _connection.finish();
  }

  Future<void> reasume() async {
    inProgress = false;
    notifyListeners();
    _connection.output.add(ascii.encode('ccc'));
    await _connection.finish();
  }

  Future<void> pause() async {
    inProgress = false;
    notifyListeners();
    _connection.output.add(ascii.encode('ccc'));
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
