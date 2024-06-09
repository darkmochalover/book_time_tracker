import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reading Time Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: JobListScreen(),
    );
  }
}

class JobListScreen extends StatefulWidget {
  @override
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  List<String> jobs = [];

  @override
  void initState() {
    super.initState();
    jobs = ['Blogging', 'Podcasting', 'Production', 'Marketing', 'Community Engagement'];
  }

  void _addJob(String job) {
    setState(() {
      jobs.add(job);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jobs'),
      ),
      body: ListView.builder(
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(jobs[index]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => JobDetailScreen(job: jobs[index])),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddJobScreen(onAddJob: _addJob)),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddJobScreen extends StatelessWidget {
  final Function(String) onAddJob;
  final TextEditingController _controller = TextEditingController();

  AddJobScreen({required this.onAddJob});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Job'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              onAddJob(_controller.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Job name'),
            ),
          ],
        ),
      ),
    );
  }
}

class JobDetailScreen extends StatefulWidget {
  final String job;

  JobDetailScreen({required this.job});

  @override
  _JobDetailScreenState createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  List<Map<String, DateTime>> readingSessions = [];
  Timer? _timer;
  DateTime? startTime;
  int closedCounter = 0;

  @override
  void initState() {
    super.initState();
    fetchStatus();
  }

  void fetchStatus() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      try {
        final response = await http.get(Uri.parse('http://172.16.37.124:9999/status'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          if (status == 'opened' && startTime == null) {
            setState(() {
              startTime = DateTime.now();
              closedCounter = 0;
            });
          } else if (status == 'closed') {
            setState(() {
              closedCounter += 1;
            });
            if (closedCounter >= 5 && startTime != null) {
              final endTime = DateTime.now();
              final duration = endTime.difference(startTime!);
              setState(() {
                readingSessions.add({
                  'start': startTime!,
                  'end': endTime,
                });
                startTime = null;
                closedCounter = 0;
              });
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Reading Time Recorded'),
                    content: Text('You have read for ${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s!'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('OK'),
                      ),
                    ],
                  );
                },
              );
            }
          } else if (status == 'opened' && startTime != null) {
            setState(() {
              startTime = DateTime.now();
              closedCounter = 0;
            });
          }
        }
      } catch (e) {
        print('Error fetching status: $e');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> shutdownServer() async {
    try {
      final response = await http.post(Uri.parse('http://172.16.37.124:9999/shutdown'));
      if (response.statusCode == 200) {
        print('Server shutting down...');
        setState(() {
          readingSessions = [];
        });
      } else {
        throw Exception('Failed to shut down server');
      }
    } catch (e) {
      print('Error shutting down server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: readingSessions.length,
                itemBuilder: (context, index) {
                  final session = readingSessions[index];
                  final duration = session['end']!.difference(session['start']!);
                  return ListTile(
                    title: Text(formatDateTime(session['start']!)),
                    subtitle: Text(
                        '${formatTime(session['start']!)} - ${formatTime(session['end']!)}'),
                    trailing: Text(formatDuration(duration)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddRecordPage(
                            startTime: session['start']!,
                            endTime: session['end']!,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await shutdownServer();
              },
              child: Text('Stop Recording'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddRecordPage(
                      startTime: startTime ?? DateTime.now(),
                      endTime: DateTime.now(),
                    ),
                  ),
                );
              },
              child: Text('New'),
            ),
          ],
        ),
      ),
    );
  }

  String formatDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('EEE MMM dd, yyyy');
    return formatter.format(dateTime);
  }

  String formatTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(dateTime);
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}h ${twoDigitMinutes}m ${twoDigitSeconds}s";
  }
}

class AddRecordPage extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;

  AddRecordPage({required this.startTime, required this.endTime});

  @override
  _AddRecordPageState createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  final TextEditingController _commentController = TextEditingController();
  late Timer _timer;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startTime;
    _startTime = TimeOfDay.fromDateTime(widget.startTime);
    _endDate = widget.endTime;
    _endTime = TimeOfDay.fromDateTime(widget.endTime);
    _duration = Duration();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _duration = DateTime.now().difference(widget.startTime);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != (isStart ? _startDate : _endDate)) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null && picked != (isStart ? _startTime : _endTime)) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final DateTime endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Record'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Reading Time Recorded'),
                    content: Text('You have read for ${_duration.inHours}h ${_duration.inMinutes.remainder(60)}m ${_duration.inSeconds.remainder(60)}s!'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('OK'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start'),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => _selectDate(context, true),
                              child: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () => _selectTime(context, true),
                              child: Text(_startTime.format(context)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End'),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => _selectDate(context, false),
                              child: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () => _selectTime(context, false),
                              child: Text(_endTime.format(context)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            Text('Duration: ${_duration.inHours}h ${_duration.inMinutes.remainder(60)}m ${_duration.inSeconds.remainder(60)}s'),
            SizedBox(height: 16.0),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
                counterText: '${_commentController.text.length}/50',
              ),
              maxLength: 50,
            ),
          ],
        ),
      ),
    );
  }
}
