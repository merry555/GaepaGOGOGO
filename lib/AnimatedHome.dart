import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:file/local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voice_recorder/Painters/CurvePainter.dart';
import 'package:voice_recorder/Painters/StopPainter.dart';
import './Painters/TrianglePainter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';                  // json 관련


Future uploadVideo(File videoFile) async{
  var uri = Uri.parse("http://f39bd73fd4f4.ngrok.io/result");
  var request = new MultipartRequest("POST", uri);

  var multipartFile = await MultipartFile.fromPath("video", videoFile.path);
  print(multipartFile);
  request.files.add(multipartFile);
  StreamedResponse response = await request.send();
  response.stream.transform(utf8.decoder).listen((value) {
    print(value);
  });
  if(response.statusCode==200){
    print("Video uploaded");
  }else{
    print("Video upload failed");
  }
}



class AnimatedHome extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new AnimatedHomeState();
}

class AnimatedHomeState extends State<AnimatedHome>
    with TickerProviderStateMixin {
  AnimationController animationController;
  // DataKind mKind;

  String mResult = '다시 말해주세요ㅠ_ㅠ';



  final LocalFileSystem localFileSystem = LocalFileSystem();
  Timer timer;
  bool _isRecording = false;
  Random random = new Random();
  FlutterAudioRecorder _recorder;
  Recording _current;
  RecordingStatus _currentStatus = RecordingStatus.Unset;

  var height;
  var width;
  String text = "00:00:00";

  @override
  Widget build(BuildContext context) {
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.blueGrey],
        ),
      ),
      child: CustomPaint(
        painter: CurvePainter(
          color1: Colors.orange,
          color2: Colors.deepOrange,
          color3: Colors.deepOrange,
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 35 / 100 * height,
              ),
              Center(
                child: GestureDetector(
                  onTap: () {
                    makeChanges();
                  },
                  child: returnAppChild(
                    150,
                    250,
                  ),
                ),
              ),
              SizedBox(
                height: 20 / 100 * height,
              ),
              Text(text,
                  style: GoogleFonts.raleway(
                    fontSize: 40.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )),
              SizedBox(
                height: 20.0,
              )
            ]),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    getPermits();
    _init();

    animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  void makeChanges() {
    if (!(_isRecording)) {
      _start();
    } else {
      _stop();
    }
  }

  Widget returnAppChild(double height, double width) {
    Widget returnVal;

    if (!_isRecording) {
      //Not recording
      returnVal = Container(
        height: height,
        width: width,
        color: Colors.transparent,
        child: CustomPaint(
          painter: TrianglePainter(),
        ),
      );
    } else {
      returnVal = AnimatedBuilder(
        animation: animationController,
        builder: (BuildContext context, Widget child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationX(animationController.value * 6.4),
            child: Container(
              height: height,
              width: width,
              color: Colors.transparent,
              child: CustomPaint(
                painter: StopPainter(),
              ),
            ),
          );
        },
      );
    }
    return returnVal;
  }

  void getPermits() async {
    if (await Permission.storage.request().isGranted &&
        await Permission.microphone.isGranted) {
      print("제 말을 알아들으시려면 접근 권한이 필요해요 >_<");
    } else {
      [
        Permission.microphone,
        Permission.storage,
      ].request();
    }
  }

  void _init() async {
    try {
      if (await FlutterAudioRecorder.hasPermissions) {
        String customPath = '/flutter_audio_player';
        Directory appDocDirectory;

        appDocDirectory = await getExternalStorageDirectory();

        customPath = appDocDirectory.path +
            customPath +
            DateTime.now().millisecondsSinceEpoch.toString();
        _recorder =
            FlutterAudioRecorder(customPath, audioFormat: AudioFormat.WAV);

        await _recorder.initialized;
      } else {
        Scaffold.of(context).showSnackBar(new SnackBar(
          content: new Text(
            "제 말을 알아들으시려면 접근 권한이 필요해요 >_<",
            style: GoogleFonts.raleway(color: Colors.black),
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.white,
        ));
      }
    } catch (e) {
      print(e);
    }
  }

  String _getDuration(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _start() async {
    animationController.forward();
    animationController.repeat();

    try {
      await _recorder.start();
      var recording = await _recorder.current(channel: 0);
      setState(() {
        _current = recording;
      });

      const tick = const Duration(milliseconds: 50);

      timer = Timer.periodic(tick, (Timer t) async {
        if (_currentStatus == RecordingStatus.Stopped) {
          t.cancel();
        }

        var current = await _recorder.current(channel: 0);
        // print(current.status);

        setState(() {
          text = _getDuration(current.duration);
          _current = current;
          _currentStatus = _current.status;
        });
      });

      var current = await _recorder.current(channel: 0);
      setState(() {
        _isRecording = true;
        _current = current;
        _currentStatus = _current.status;
      });
    } catch (e) {
      print(e);
    }
  }

  void _stop() async {
    timer.cancel();

    if (animationController.isCompleted) {
      animationController.stop();
    } else {
      animationController.reset();
      animationController.stop();
    }

    var result = await _recorder.stop(); // server upload
    File file = localFileSystem.file(result.path);
    uploadVideo(file);



    Scaffold.of(context).showSnackBar(
      new SnackBar(
        content: new Text(
          mResult,
          // "Saved the file at : ${file.path}",
          style: GoogleFonts.raleway(color: Colors.black),
        ),
        duration: Duration(seconds: 10),
        backgroundColor: Colors.white,
      ),
    );

    setState(() {
      _init();
      _isRecording = false;
      _current = new Recording();
      _currentStatus = RecordingStatus.Unset;
      text = "00:00:00";
    });
  }
}
