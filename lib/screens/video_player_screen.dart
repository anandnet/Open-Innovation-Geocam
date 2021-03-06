import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:flutter_polyline_points/flutter_polyline_points.dart";
import "../utils/global_variables.dart" as gv;
import "../screens/video_list_screen.dart";

class VideoPlayerScreen extends StatefulWidget {
  static const routeName = "/video-player-screen";
  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController _videoPlayerController;
  ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    gv.startWatch(timer, watch, updateTime);
    setSourceAndDestinationIcons();
  }

  bool isInit = true;
  String fileName;
  int vidOrientation=0;
  @override
  void didChangeDependencies() {
    if (isInit) {
      final a = ModalRoute.of(context).settings.arguments as Todos;
      var myFile = new File(a.path);
      data = a.mapData;
      fileName = a.fileName;
      source = a.source;
      vidOrientation=a.vidOrientation;
      isMapDataAvailable = a.isMapDataAvailable;
      destination = a.destination;
      _videoPlayerController = VideoPlayerController.file(myFile);
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: vidOrientation==0 ? 3 / 2 : 3/4,
        autoPlay: true,
        looping: false,
        // Try playing around with some of these other options:
        // showControls: false,
        // materialProgressColors: ChewieProgressColors(
        //   playedColor: Colors.red,
        //   handleColor: Colors.blue,
        //   backgroundColor: Colors.grey,
        //   bufferedColor: Colors.lightGreen,
        // ),
        placeholder: Container(
          color: Colors.grey,
        ),
        // autoInitialize: true,
      );
      isInit = false;
    }
    super.didChangeDependencies();
  }

  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    watch.stop();
    if (timer != null) timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CameraPosition initialCameraPosition;
    if (!isMapDataAvailable) {
      initialCameraPosition = CameraPosition(
          zoom: 0,
          tilt: 0,
          bearing: cameraBearing,
          target: LatLng(source[0], source[1]));
    } else {
      initialCameraPosition = CameraPosition(
          zoom: cameraZoom,
          tilt: cameraTilt,
          bearing: cameraBearing,
          target: LatLng(source[0], source[1]));
      if (data[videoPosition] != null && videoPosition != "") {
        initialCameraPosition = CameraPosition(
            target:
                LatLng(data[videoPosition][0], data[videoPosition][1]), //change
            zoom: cameraZoom,
            tilt: cameraTilt,
            bearing: cameraBearing);
      }
    }
      return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: Column(
        children: <Widget>[
          Container(
            height: vidOrientation==0 ? 240 :300,
            child: Stack(
              children: <Widget>[
                Chewie(
                  controller: _chewieController,
                ),
                Container(
                  padding:const EdgeInsets.only(left: 10,top:10),
                  height: 40,
                  width: 120,
                  color: Colors.black12,
                  alignment: Alignment.topLeft,
                  child: Text(
                    //"hello",
                    (data[videoPosition]!=null&&videoPosition!='') ?  "Speed: "+data[videoPosition][3].toString()+" m/s":"Speed: 0.00 m/s",
                    style: TextStyle(
                      fontWeight:FontWeight.bold,
                      color: Colors.white
                      ),
                    ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
                myLocationEnabled: false,
                compassEnabled: true,
                tiltGesturesEnabled: true,
                markers: _markers,
                polylines: _polylines,
                mapType: MapType.normal,
                initialCameraPosition: initialCameraPosition,
                onMapCreated: onMapCreated),
          )
        ],
      ),
    );
  }

  ///Related to timer.........................
  String elapsedTime = "";
  Stopwatch watch = new Stopwatch();
  Timer timer;
  String videoPosition = "";

  updateTime(Timer timer) {
    if (watch.isRunning) {
      if (mounted) {
        setState(() {
          elapsedTime = gv.transformMilliSeconds(watch.elapsedMilliseconds);
          var milliSeconds = _chewieController
              .videoPlayerController.value.position.inMilliseconds;
          videoPosition = gv.transformMilliSeconds(milliSeconds);
          //("$videoPosition: ${data[videoPosition]}");
          if (isMapDataAvailable) {
            try{
              if(data[videoPosition] != null){
                updatePinOnMap();
              }
            }catch(e){

            }
            
          }
        });
      }
    }
  }

//Related to maps.........................................
  bool isMapDataAvailable;
  List<double> source = [];
  List<double> destination = [];
  final double cameraZoom = 16;
  final double cameraTilt = 3;
  final double cameraBearing = 0;
  Map<String, List<double>> data = {};
  Map<PolylineId, Polyline> polylines = {};

  void onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    if (isMapDataAvailable) {
      setMapPins();
      // setPolylines();
    }
  }

  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPIKey = "";
  BitmapDescriptor sourceIcon;
  BitmapDescriptor destinationIcon;
  BitmapDescriptor locationIcon;

  void setMapPins() {
    setState(() {
      _markers.add(Marker(
          markerId: MarkerId('directionPin'),
          position: LatLng(source[0], source[1]),
          icon: locationIcon));
      _markers.add(Marker(
          markerId: MarkerId('sourcePin'),
          position: LatLng(source[0], source[1]),
          icon: sourceIcon));

      _markers.add(Marker(
          markerId: MarkerId('destPin'),
          position: LatLng(destination[0], destination[1]),
          icon: destinationIcon));
    });
  }

  void setSourceAndDestinationIcons() async {
    destinationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), 'assets/destination.png');
    sourceIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), 'assets/source.png');
    locationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), 'assets/pointer.png');
  }

  void setPolylines() async {
    List<PointLatLng> result = await polylinePoints.getRouteBetweenCoordinates(
        googleAPIKey,
        source[0],
        source[1],
        destination[0],
        destination[1] //souce
        ); //destination
    if (result.isNotEmpty) {
      result.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
      setState(() {
        _polylines.add(Polyline(
            width: 5, // set the width of the polylines
            polylineId: PolylineId("poly"),
            color: Color.fromARGB(255, 40, 122, 198),
            points: polylineCoordinates));
      });
    }
  }

  void updatePinOnMap() async {
      CameraPosition cPosition = CameraPosition(
        zoom: cameraZoom,
        tilt: cameraTilt,
        bearing: cameraBearing,
        target: LatLng(data[videoPosition][0], data[videoPosition][1]), //chanfr
      );
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(cPosition));
      var pinPosition =
          LatLng(data[videoPosition][0], data[videoPosition][1]); //change
      _markers.removeWhere((m) => m.markerId.toString() == 'directionPin');
      _markers.add(Marker(
          markerId: MarkerId('directionPin'),
          position: pinPosition, // updated position
          icon: locationIcon,
          rotation: data[videoPosition] != null ? data[videoPosition][2] : 0));
  }
}
