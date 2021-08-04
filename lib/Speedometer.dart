import 'package:flutter/material.dart';
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
          RadialAxis(startAngle: 270,
              endAngle: 270,
              minimum: 0,
              maximum: 80,
              interval: 10,
              radiusFactor: 0.4,
              showAxisLine: false,
              showLastLabel: false,
              minorTicksPerInterval: 4,
              majorTickStyle: MajorTickStyle(
                  length: 8, thickness: 3, color: Colors.white),
              minorTickStyle: MinorTickStyle(
                  length: 3, thickness: 1.5, color: Colors.grey),
              axisLabelStyle: GaugeTextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              onLabelCreated: labelCreated
          ),
          RadialAxis(minimum: 0,
              maximum: 200,
              labelOffset: 30,
              axisLineStyle: AxisLineStyle(
                  thicknessUnit: GaugeSizeUnit.factor, thickness: 0.03),
              majorTickStyle: MajorTickStyle(
                  length: 6, thickness: 4, color: Colors.white),
              minorTickStyle: MinorTickStyle(
                  length: 3, thickness: 3, color: Colors.white),
              axisLabelStyle: GaugeTextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              ranges: <GaugeRange>[
                GaugeRange(startValue: 0,
                    endValue: 200,
                    sizeUnit: GaugeSizeUnit.factor,
                    startWidth: 0.03,
                    endWidth: 0.03,
                    gradient: SweepGradient(
                        colors: const<Color>[
                          Colors.green,
                          Colors.yellow,
                          Colors.red
                        ],
                        stops: const<double>[0.0, 0.5, 1]))
              ],
              pointers: <GaugePointer>[
                NeedlePointer(value: _value,
                    needleLength: 0.95,
                    enableAnimation: true,
                    animationType: AnimationType.ease,
                    needleStartWidth: 1.5,
                    needleEndWidth: 6,
                    needleColor: Colors.red,
                    knobStyle: KnobStyle(knobRadius: 0.09,sizeUnit: GaugeSizeUnit.factor))
              ],
              annotations: <GaugeAnnotation>[
                GaugeAnnotation(widget: Container(child:
                Column(
                    children: <Widget>[
                      Text(_value.toString(), style: TextStyle(
                          fontSize: 25, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      Text('mph', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold))
                    ]
                )), angle: 90, positionFactor: 0.75)
              ]
          )
        ]
    )
  }
}
