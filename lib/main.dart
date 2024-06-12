import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: Text('Book Time Tracker')),
      body: MyApp(),
    ),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DateTime? startTime;
  DateTime? endTime;
  Duration duration = Duration.zero;
  Timer? timer;
  String statusMessage = '';
  String serverTime = '';
  final String serverUrl = 'http://172.16.37.124:9999/status';

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(Duration(seconds: 2), (Timer t) => _getStatus());
  }

  Future<void> _getStatus() async {
    try {
      final response = await http.get(Uri.parse(serverUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];
        final time = data['time'];

        setState(() {
          statusMessage = status;
          serverTime = time;
        });

        if (status == 'opened') {
          if (startTime == null) {
            startTime = DateTime.now();
            timer = Timer.periodic(Duration(seconds: 1), (timer) {
              setState(() {
                duration = DateTime.now().difference(startTime!);
              });
            });
          }
        } else if (status == 'closed') {
          endTime = DateTime.now();
          timer?.cancel();
          _showClosedDialog();
        }
      } else {
        setState(() {
          statusMessage = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error: $e';
      });
    }
  }

  void _showClosedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Closed"),
          content: Text("Duration: ${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s"),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text('Status: $statusMessage'),
        Text('Server Time: $serverTime'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start', style: TextStyle(fontSize: 16)),
                Text(startTime != null
                    ? '${startTime!.toLocal()}'.split(' ')[0]
                    : 'N/A'),
                Text(startTime != null
                    ? '${startTime!.toLocal()}'.split(' ')[1]
                    : 'N/A'),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('End', style: TextStyle(fontSize: 16)),
                Text(endTime != null
                    ? '${endTime!.toLocal()}'.split(' ')[0]
                    : 'N/A'),
                Text(endTime != null
                    ? '${endTime!.toLocal()}'.split(' ')[1]
                    : 'N/A'),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
        Text('Duration: ${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s'),
        SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            labelText: 'Comment',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
      ],
    );
  }
}
