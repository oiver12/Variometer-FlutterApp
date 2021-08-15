//modifiziert von https://github.com/SyncfusionExamples/flutter_speedometer_demo
import 'package:flutter/material.dart';
import 'package:variomete_app/main.dart';
import './BackgroundCollectingTask.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class Speedometer extends StatefulWidget {
  const Speedometer({Key key}) : super(key: key);

  @override
  _SpeedometerState createState() => _SpeedometerState();
}

class _SpeedometerState extends State<Speedometer> {

  @override
  Widget build(BuildContext context) {
    final BackgroundCollectingTask task = BackgroundCollectingTask.of(context, rebuildOnChange: true);
    return SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
              startAngle: 20,
              endAngle: -20,
              minimum: -6,
              maximum: 6,
              interval: 1,
              minorTicksPerInterval: 1,
              labelOffset: 30,
              axisLineStyle: AxisLineStyle(
                  thicknessUnit: GaugeSizeUnit.factor, thickness: 0.03),
              majorTickStyle: MajorTickStyle(
                  length: 15, thickness: 4, color: Colors.white),
              minorTickStyle: MinorTickStyle(
                  length: 10, thickness: 3, color: Colors.white),
              axisLabelStyle: GaugeTextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              ranges: <GaugeRange>[
                GaugeRange(startValue: -8,endValue: 0,color: Colors.red,startWidth: 10,endWidth: 10),
                GaugeRange(startValue: 0,endValue: 8,color: Colors.green,startWidth: 10,endWidth: 10)],
              pointers: <GaugePointer>[
                NeedlePointer(value: task.lastVelocity,
                    needleLength: 0.85,
                    enableAnimation: true,
                    animationType: AnimationType.linear,
                    needleStartWidth: 1,
                    needleEndWidth: 5,
                    needleColor: Colors.red,
                    knobStyle: KnobStyle(knobRadius: 0.035,sizeUnit: GaugeSizeUnit.factor))
              ],
              annotations: <GaugeAnnotation>[
                GaugeAnnotation(widget: Container(child:
                    Row(
                      children: <Widget>[
                        SizedBox(
                          width: percentageScreen.width*0.1,
                        ),
                        Column(
                          children: <Widget>[
                            Text(task.lastHeight.toStringAsFixed(2), style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(height: percentageScreen.height*0.01),
                            Text('AMSL', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))
                          ],
                        ),
                        SizedBox(
                          width: percentageScreen.width*0.22,
                        ),
                        Column(
                            children: <Widget>[
                              Text(task.lastVelocity.toStringAsFixed(2), style: TextStyle(
                                  fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
                              SizedBox(height: percentageScreen.height*0.01),
                              Text('m/s', style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))
                            ]
                        )
                      ],
                    )), angle: 90, positionFactor: 2.2)
              ]
          ),
        ]
    );
  }


  void labelCreated(AxisLabelCreatedArgs args) {
    if (args.text == '0') {
      args.text = 'N';
      args.labelStyle = GaugeTextStyle(
          color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14);
    }
    else if (args.text == '10')
      args.text = '';
    else if (args.text == '20')
      args.text = 'E';
    else if (args.text == '30')
      args.text = '';
    else if (args.text == '40')
      args.text = 'S';
    else if (args.text == '50')
      args.text = '';
    else if (args.text == '60')
      args.text = 'W';
    else if (args.text == '70')
      args.text = '';
    else if(args.text == '80')
      args.text = 'N';
  }
}
