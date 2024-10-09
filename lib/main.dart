import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart'; // Import intl package for date formatting

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Download PDF Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    initializeNotification();
  }

  // Initialize notifications
  void initializeNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Create notification channel (required for Android 8.0 and above)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'download_channel', // id
      'Download Notification', // title
      description: 'Notification for download progress',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Handle notification click and open the file
  Future<void> onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    String? filePath = notificationResponse.payload;
    if (filePath != null) {
      await _openFile(filePath); // Open the downloaded file
    }
  }

  // Open the file and show a Snackbar if unable to open
  Future<void> _openFile(String filePath) async {
    try {
      var result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        _showSnackbar('Unable to open file');
      }
    } catch (e) {
      _showSnackbar('Unable to open file');
    }
  }

  // Show or update the download notification
  Future<void> showDownloadNotification(String title, String body, {String? filePath}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'download_channel', 'Download Notification',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Show the notification with the same ID to update it
    await flutterLocalNotificationsPlugin.show(
      0, // Use the same ID for the notification to update it
      title,
      body,
      platformChannelSpecifics,
      payload: filePath, // Pass file path as payload to open it later
    );
  }

  // Function to show a Snackbar message
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Function to download PDF and save to Downloads folder
  Future<void> downloadPDF() async {
    // Request storage permission
    PermissionStatus permissionStatus = await Permission.storage.request();

    if (permissionStatus.isGranted) {
      try {
        var dio = Dio();

        // Create a timestamp for the file name
        String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        String fileName = "annual_report_$timestamp.csv"; // Specify the file name with timestamp
        String url = "https://www.w3schools.com/python/data.csv"; // Provided PDF URL

        // Get the Downloads directory
        Directory downloadsDir = Directory('/storage/emulated/0/Download');

        // Create the full path to save the file
        String savePath = path.join(downloadsDir.path, fileName);

        // Show notification that the download has started
        await showDownloadNotification('Download Started', 'Your download has started.');

        // Start downloading
        await dio.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              double receivedMB = received / (1024 * 1024); // Convert bytes to MB
              double totalMB = total / (1024 * 1024); // Convert bytes to MB
              double progress = (received / total * 100);

              print("Download progress: ${progress.toStringAsFixed(0)}% (${receivedMB.toStringAsFixed(2)} MB of ${totalMB.toStringAsFixed(2)} MB)"); // Log download percentage


            }
          },
        );

        // Update notification when download completes
        await showDownloadNotification('Download Complete', 'Your file is downloaded. Tap to open.', filePath: savePath);
        print("Download completed, file saved at $savePath");
      } catch (e) {
        print("Error: $e");
        await showDownloadNotification('Download Failed', 'An error occurred while downloading the file.');
      }
    } else {
      print("Permission denied.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Download PDF with Notification"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: downloadPDF,
          child: Text("Download PDF"),
        ),
      ),
    );
  }
}
