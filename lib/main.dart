import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kge/global.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:native_exif/native_exif.dart';

void trackingData() async {
  date = DateFormat("MMMM, dd, yyyy").format(DateTime.now());
  time = DateFormat("hh:mm:ss a").format(DateTime.now());
  Position? currentPosition;
  String? currentAddress;
  Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
      .then((position) {
    currentPosition = position;
    placemarkFromCoordinates(
            currentPosition?.latitude ?? 0, currentPosition?.longitude ?? 0)
        .then((List<Placemark> placemarks) {
      Placemark place = placemarks[0];

      currentAddress =
          '${place.street}, ${place.subLocality}, ${place.subAdministrativeArea}, ${place.postalCode}';
    }).catchError((e) {
      debugPrint(e);
    });
  }).catchError((e) {
    print(e);
  });
}

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PermissionHandlerScreen(),
    );
  }
}

class PermissionHandlerScreen extends StatefulWidget {
  const PermissionHandlerScreen({super.key});

  @override
  _PermissionHandlerScreenState createState() =>
      _PermissionHandlerScreenState();
}

class _PermissionHandlerScreenState extends State<PermissionHandlerScreen> {
  @override
  void initState() {
    super.initState();
    permissionServiceCall();
  }

  permissionServiceCall() async {
    await permissionServices().then(
      (value) {
        if (value[Permission.camera]!.isGranted &&
            value[Permission.locationWhenInUse]!.isGranted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MyHomePage()),
          );
        }
      },
    );
  }

  Future<Map<Permission, PermissionStatus>> permissionServices() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();

    if (statuses[Permission.camera]!.isPermanentlyDenied) {
      openAppSettings();
    } else {
      if (statuses[Permission.camera]!.isDenied) {
        permissionServiceCall();
      }
    }
    if (statuses[Permission.locationWhenInUse]!.isPermanentlyDenied) {
      openAppSettings();
    } else {
      if (statuses[Permission.locationWhenInUse]!.isDenied) {
        openAppSettings();
      }
    }
    if (statuses[Permission.locationWhenInUse]!.isGranted) {
      await Permission.locationAlways.request();
    } else {
      if (statuses[Permission.locationAlways]!.isDenied) {
        await openAppSettings();
      }
    }
    return statuses;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        SystemNavigator.pop();
        return Future.value(false);
      },
      child: Scaffold(
        body: Center(
          child: InkWell(
              onTap: () {
                permissionServiceCall();
              },
              child: const Text("Click on Allow all the time")),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getLocation();
  }

  Position? currentPosition;
  String? currentAddress;
  _getLocation() async {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
        .then((position) {
      currentPosition = position;
    }).catchError((e) {
      print(e);
    });
  }

  File? image;
  _getFromCamera() async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (pickedFile != null) {
      setState(() {
        image = File(pickedFile.path);
      });
    }
    final dateFormat = DateFormat('yyyy:MM:dd HH:mm:ss');
    final exif = await Exif.fromPath(pickedFile!.path);
    await exif.writeAttributes({
      'GPSLatitude': currentPosition?.latitude ?? 0.0,
      'GPSLongitude': currentPosition?.longitude ?? 0.0,
      'DateTimeOriginal': dateFormat.format(DateTime.now()),
    });
  }

  bool start = false;
  Exif? exif;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
            title: const Text(
              'KGE Technologies',
              style: TextStyle(fontFamily: 'helvetica'),
            ),
            centerTitle: true,
            leading: Image.network(
                'https://raw.githubusercontent.com/kgetechnologies/kgesitecdn/kgetechnologies-com/images/KgeMain.png')),
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 450,
                alignment: Alignment.center,
                child: (image != null)
                    ? Image.file(image!)
                    : const Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                      ),
              ),
              MaterialButton(
                onPressed: () {
                  (image == null)
                      ? _getFromCamera()
                      : GallerySaver.saveImage(image!.path);
                },
                color: Colors.lightBlueAccent,
                child: (image == null)
                    ? const Text('Take Picture')
                    : const Text('Save Picture'),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              start = !start;
              if (start == true) {
                AndroidAlarmManager.periodic(
                    const Duration(minutes: 5), 0, trackingData);
              } else {
                AndroidAlarmManager.cancel(0);
              }
            });
          },
          child: (start == false)
              ? const Icon(Icons.play_arrow)
              : const Icon(Icons.stop),
        ),
      ),
    );
  }
}
