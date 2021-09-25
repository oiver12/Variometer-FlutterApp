import 'dart:async';
import 'dart:developer';
import 'dart:math';
// EXCLUDE_FROM_GALLERY_DOCS_END
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:sound_generator/sound_generator.dart';
import 'package:sound_generator/waveTypes.dart';

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
  State<StatefulWidget> createState() => new _SliderCallbackState();

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
        id: 'Sales',
        domainFn: (ToneFrequency sales, _) => sales.velocity,
        measureFn: (ToneFrequency sales, _) => sales.frequeny,
        data: pointsOfSlide,
      )
    ];
  }
}

class _SliderCallbackState extends State<SliderLine> {
  waveTypes waveType = waveTypes.SQUAREWAVE;
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
      if(dragState == charts.SliderListenerDragState.end) {
        print("Rebuild");
        for (int i = 0; i < SliderLine.pointsOfSlide.length; i++) {
          if (domain >= SliderLine.pointsOfSlide[i].velocity && domain <= SliderLine.pointsOfSlide[i + 1].velocity)
          {
            if (i + 1 == SliderLine.pointsOfSlide.length)
            {
              setState(() {
                frequency = SliderLine.pointsOfSlide[i].frequeny;
                velocity = domain;
              });
              return;
            }
            if (i == 0 || i == 1)
            {
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
              if(BeepOn)
                SoundGenerator.play();
              return;
            }
            else if (i == 2 || i == 3)
            {
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
            double factor = (domain - SliderLine.pointsOfSlide[i].velocity) / (SliderLine.pointsOfSlide[i + 1].velocity - SliderLine.pointsOfSlide[i].velocity);
            setState(() {
              velocity = domain;
              frequency = factor * (SliderLine.pointsOfSlide[i + 1].frequeny - SliderLine.pointsOfSlide[i].frequeny) + SliderLine.pointsOfSlide[i].frequeny;
              lengthTone = (factor * (SliderLine.pointsOfSlide[i + 1].lengthTone - SliderLine.pointsOfSlide[i].lengthTone) + SliderLine.pointsOfSlide[i].lengthTone).round();
              print(frequency.toString());
            });
            SoundGenerator.setFrequency(frequency);
            isLow = false;
            isEqual = false;
            if (BeepOn)
            {
              if (timer != null)
                timer.cancel();

              timer = Timer.periodic(Duration(milliseconds: lengthTone), (Timer t) => Beep());
            }
            return;
          }
        }
      }
    }

    SchedulerBinding.instance.addPostFrameCallback(rebuild);
  }
  @override
  void initState()
  {
    super.initState();
    SoundGenerator.init(sampleRate);

    SoundGenerator.setAutoUpdateOneCycleSample(false);
    SoundGenerator.setWaveType(waveType);
    SoundGenerator.setFrequency(frequency);
    SoundGenerator.setVolume(1);
  }

  void Beep()
  {
    if(isPlaying)
      {
        SoundGenerator.stop();
        isPlaying = false;
      }
    else
      {
        SoundGenerator.play();
        isPlaying = true;
      }
  }

  @override
  Widget build(BuildContext context) {
    print(frequency.toString());
    // The children consist of a Chart and Text widgets below to hold the info.
    final children = <Widget>[
      new SizedBox(
          height: 150.0,
          child: new charts.LineChart(
            SliderLine.seriesList,
            animate: widget.animate,
            // Configures a [Slider] behavior.
            //
            // Available options include:
            //
            // [eventTrigger] configures the type of mouse gesture that controls
            // the slider.
            //
            // [handleRenderer] draws a handle for the slider. Defaults to a
            // rectangle.
            //
            // [initialDomainValue] sets the initial position of the slider in
            // domain units. The default is the center of the chart.
            //
            // [onChangeCallback] will be called when the position of the slider
            // changes during a drag event.
            //
            // [roleId] optional custom role ID for the slider. This can be used to
            // allow multiple [Slider] behaviors on the same chart. Normally, there can
            // only be one slider (per event trigger type) on a chart. This setting
            // allows for configuring multiple independent sliders.
            //
            // [snapToDatum] configures the slider to snap snap onto the nearest
            // datum (by domain distance) when dragged. By default, the slider
            // can be positioned anywhere along the domain axis.
            //
            // [style] takes in a [SliderStyle] configuration object, and
            // configures the color and sizing of the slider line and handle.
            behaviors: [
              new charts.Slider(
                  initialDomainValue: velocity, onChangeCallback: _onSliderChange),
            ],
          )),
    ];
    children.add(
        IconButton(
            icon: Icon(
                BeepOn ? Icons.stop : Icons.play_arrow),
            onPressed: () {
              if(BeepOn)
                {
                  if(timer != null)
                    timer.cancel();

                  SoundGenerator.stop();
                }
            else
              {
                if(isEqual)
                  SoundGenerator.stop();
                else if(isLow)
                  SoundGenerator.play();
                else
                  timer = Timer.periodic(Duration(milliseconds: lengthTone), (Timer t) => Beep());
              }
              setState(() {
                BeepOn = !BeepOn;
              });
            }));
    children.add(Text("Velocity: " + velocity.toStringAsFixed(2)));
    children.add(Text("Frequency: " + frequency.toStringAsFixed(2)));
    children.add(Text("Toneduration: " + lengthTone.toString()));
    return new Column(children: children);
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