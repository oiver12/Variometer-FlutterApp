import 'dart:async';
import 'dart:developer';
import 'dart:math';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:sound_generator/sound_generator.dart';
import 'package:sound_generator/waveTypes.dart';
import 'package:variomete_app/main.dart';

class SliderLine extends StatefulWidget {
  static List<charts.Series> seriesList = _createSampleData();
  static List<ToneFrequency> pointsOfSlide;
  final bool animate;

  SliderLine({this.animate});

  /// Creates a [LineChart] with sample data and no transition.
  factory SliderLine.withSampleData() {
    return new SliderLine(
      animate: false,
    );
  }


  // We need a Stateful widget to build the selection details with the current
  // selection as the state.
  @override
  State<StatefulWidget> createState() => new SliderCallbackState();

  /// Create one series with sample hard coded data.
  static List<charts.Series<ToneFrequency, double>> _createSampleData() {
    pointsOfSlide = [
      new ToneFrequency(120, 0, -4),
      new ToneFrequency(120, 0, -2.5),
      new ToneFrequency(0, 0, -2.49),
      new ToneFrequency(0, 0, 0.149),
      new ToneFrequency(700, 750, 0.15),
      new ToneFrequency(850, 540, 1.5),
      new ToneFrequency(1000, 300, 3.5),
      new ToneFrequency(1600, 90, 10),
    ];

    return [
      new charts.Series<ToneFrequency, double>(
        id: 'Frequenz',
        domainFn: (ToneFrequency point, _) => point.velocity,
        measureFn: (ToneFrequency point, _) => point.frequeny,
        data: pointsOfSlide,
      ),
      new charts.Series<ToneFrequency, double>(
        id: 'Tonelänge',
        domainFn: (ToneFrequency point, _) => point.velocity,
        measureFn: (ToneFrequency point, _) => point.lengthTone,
        data: pointsOfSlide
      )..setAttribute(charts.measureAxisIdKey, 'secondaryMeasureAxisId')
    ];
  }
}

class SliderCallbackState extends State<SliderLine> {
  waveTypes waveType = waveTypes.SINUSOIDAL;
  int sampleRate = 9600;
  bool BeepOn = false;
  bool isPlaying = true;
  int lengthTone = 750;
  double frequency = 700;
  Timer timer;
  bool isLow = false;
  bool isEqual = false;
  double velocity = 0.15;

  // Handles callbacks when the user drags the slider.
  _onSliderChange(Point<int> point, dynamic domain, String roleId,
      charts.SliderListenerDragState dragState) {
    // Request a build.
    void rebuild(_) {
      if (dragState == charts.SliderListenerDragState.end) {
        print("Rebuild");
        for (int i = 0; i < SliderLine.pointsOfSlide.length; i++) {
          if (domain >= SliderLine.pointsOfSlide[i].velocity &&
              domain <= SliderLine.pointsOfSlide[i + 1].velocity) {
            if (i + 1 == SliderLine.pointsOfSlide.length) {
              setState(() {
                frequency = SliderLine.pointsOfSlide[i].frequeny;
                velocity = domain;
              });
              return;
            }
            if (i == 0 || i == 1) {
              print("Low");
              if (timer != null)
                timer.cancel();
              isLow = true;
              isEqual = false;
              SoundGenerator.setFrequency(frequency);
              setState(() {
                lengthTone = 1000;
                frequency = SliderLine.pointsOfSlide[1].frequeny;
                velocity = domain;
              });
              if (BeepOn)
                SoundGenerator.play();
              return;
            }
            else if (i == 2 || i == 3) {
              print("Equal");
              if (timer != null)
                timer.cancel();
              isLow = false;
              isEqual = true;
              setState(() {
                velocity = domain;
                frequency = 0;
                lengthTone = 0;
              });
              SoundGenerator.stop();
              return;
            }
            double factor = (domain - SliderLine.pointsOfSlide[i].velocity) /
                (SliderLine.pointsOfSlide[i + 1].velocity -
                    SliderLine.pointsOfSlide[i].velocity);
            setState(() {
              velocity = domain;
              frequency = factor * (SliderLine.pointsOfSlide[i + 1].frequeny -
                  SliderLine.pointsOfSlide[i].frequeny) +
                  SliderLine.pointsOfSlide[i].frequeny;
              lengthTone = (factor *
                  (SliderLine.pointsOfSlide[i + 1].lengthTone -
                      SliderLine.pointsOfSlide[i].lengthTone) +
                  SliderLine.pointsOfSlide[i].lengthTone).round();
              print(frequency.toString());
            });
            SoundGenerator.setFrequency(frequency);
            isLow = false;
            isEqual = false;
            if (BeepOn) {
              if (timer != null)
                timer.cancel();

              timer = Timer.periodic(
                  Duration(milliseconds: lengthTone), (Timer t) => Beep());
            }
            return;
          }
        }
      }
    }

    SchedulerBinding.instance.addPostFrameCallback(rebuild);
  }

  @override
  void initState() {
    super.initState();
    SoundGenerator.init(sampleRate);

    SoundGenerator.setAutoUpdateOneCycleSample(false);
    SoundGenerator.setWaveType(waveType);
    SoundGenerator.setFrequency(frequency);
    SoundGenerator.setVolume(1);
  }

  void Beep() {
    if (isPlaying) {
      SoundGenerator.stop();
      isPlaying = false;
    }
    else {
      SoundGenerator.play();
      isPlaying = true;
    }
  }

  List<charts.Series<ToneFrequency, double>> returnFromPoint()
  {
    return [new charts.Series<ToneFrequency, double>(
      id: 'Frequenz',
      domainFn: (ToneFrequency point, _) => point.velocity,
      measureFn: (ToneFrequency point, _) => point.frequeny,
      data: SliderLine.pointsOfSlide,
    ),
      new charts.Series<ToneFrequency, double>(
          id: 'Tonelänge',
          domainFn: (ToneFrequency point, _) => point.velocity,
          measureFn: (ToneFrequency point, _) => point.lengthTone,
          data: SliderLine.pointsOfSlide
      )..setAttribute(charts.measureAxisIdKey, 'secondaryMeasureAxisId')];
  }

  void setChartFromPoints()
  {
    SliderLine.seriesList = returnFromPoint();
  }

  @override
  Widget build(BuildContext context) {
    // The children consist of a Chart and Text widgets below to hold the info.
    final children = <Widget>[
      new SizedBox(
          height: 250.0,
          width: percentageScreen.width,
          child: new charts.LineChart(
            SliderLine.seriesList,
            animate: widget.animate,
            primaryMeasureAxis: new charts.NumericAxisSpec(
                tickProviderSpec:
                new charts.BasicNumericTickProviderSpec(desiredTickCount: 4)),
            secondaryMeasureAxis: new charts.NumericAxisSpec(
                tickProviderSpec:
                new charts.BasicNumericTickProviderSpec(desiredTickCount: 4)),
            defaultRenderer: new charts.LineRendererConfig(includePoints: true),
            behaviors: [
              new charts.SeriesLegend(),
              new charts.Slider(
                  initialDomainValue: velocity,
                  onChangeCallback: _onSliderChange),
              new charts.ChartTitle('Geschwindigkeit [m/s]',
                  behaviorPosition: charts.BehaviorPosition.bottom,
                  titleOutsideJustification:
                  charts.OutsideJustification.middleDrawArea),
              new charts.ChartTitle('Frequenz [Hz]',
                  behaviorPosition: charts.BehaviorPosition.start,
                  titleOutsideJustification:
                  charts.OutsideJustification.middleDrawArea),
              new charts.ChartTitle('Tonlänge [ms]',
                  behaviorPosition: charts.BehaviorPosition.end,
                  titleOutsideJustification:
                  charts.OutsideJustification.middleDrawArea),
            ],
          )),
    ];
    children.add(
        IconButton(
            icon: Icon(
                BeepOn ? Icons.stop : Icons.play_arrow),
            onPressed: () {
              if (BeepOn) {
                if (timer != null)
                  timer.cancel();

                SoundGenerator.stop();
              }
              else {
                if (isEqual)
                  SoundGenerator.stop();
                else if (isLow)
                  SoundGenerator.play();
                else
                  timer = Timer.periodic(
                      Duration(milliseconds: lengthTone), (Timer t) => Beep());
              }
              setState(() {
                BeepOn = !BeepOn;
              });
            }));
    children.add(Text("Geschwindigkeit: " + velocity.toStringAsFixed(2)));
    children.add(Text("Frequenz: " + frequency.toStringAsFixed(2)));
    children.add(Text("Tonlänge: " + lengthTone.toString()));
    children.add(DataTable(
      columns: const <DataColumn>[
        DataColumn(
          label: Text(
            'Geschwindigkeit',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        DataColumn(
          label: Text(
            'Frequenz',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        DataColumn(
          label: Text(
            'Tonlänge',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ],
      columnSpacing: percentageScreen.width * 0.1,
      rows: <DataRow>[
        pointDataRow(SliderLine.pointsOfSlide[1]),
        pointDataRow(SliderLine.pointsOfSlide[4]),
        pointDataRow(SliderLine.pointsOfSlide[5]),
        pointDataRow(SliderLine.pointsOfSlide[6]),
        pointDataRow(SliderLine.pointsOfSlide[7]),
      ],
    ));
    return new Column(children: children);
  }


  DataRow pointDataRow(ToneFrequency point) {
    return DataRow(
      cells: <DataCell>[
        DataCell(
          Container(
            width: percentageScreen.width * 0.19,
            child: TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: point.velocity.toStringAsFixed(2),
                labelStyle: TextStyle(fontSize: 14),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (value) {
                setState(() {
                  point.velocity = double.parse(value);
                  setChartFromPoints();
                });
              },
            ),
          ),
        ),
        DataCell(Container(
          width: percentageScreen.width * 0.19,
          child: TextField(
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: point.frequeny.toStringAsFixed(1),
              labelStyle: TextStyle(fontSize: 14),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (value) {
              setState(() {
                point.frequeny = double.parse(value);
                setChartFromPoints();
              });
            },
          ),
        ),),
        DataCell(Container(
          width: percentageScreen.width * 0.19,
          child: TextField(
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: point.lengthTone.toStringAsFixed(1),
              labelStyle: TextStyle(fontSize: 14),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (value) {
              setState(() {
                point.lengthTone = double.parse(value);
                setChartFromPoints();
              });
            },
          ),
        ),),
      ],
    );
  }
}
/// Sample linear data type.
class ToneFrequency {
  double velocity;
  double frequeny;
  double lengthTone;

  ToneFrequency(double freqeuncy, double lengthTone, double velocity)
  {
    this.velocity = velocity;
    this.frequeny = freqeuncy;
    this.lengthTone = lengthTone;
  }
}