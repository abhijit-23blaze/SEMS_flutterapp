import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEMS',
      debugShowCheckedModeBanner: false,  // Removes debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LightControlPage(),
    );
  }
}

class LightControlPage extends StatefulWidget {
  const LightControlPage({super.key});

  @override
  _LightControlPageState createState() => _LightControlPageState();
}

class _LightControlPageState extends State<LightControlPage> {
  WebSocketChannel? channel;
  bool isConnected = false;
  String lightStatus = "LIGHT OFF";
  Timer? reconnectionTimer;
  Timer? heartbeatTimer;

  // Server IP address
  final String serverIp = "192.168.1.100"; // Replace with your server's IP

  @override
  void initState() {
    super.initState();
    startConnectionAttempts();
  }

  void startConnectionAttempts() {
    // Try to connect immediately
    connectToServer();

    // Setup reconnection timer
    reconnectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isConnected) {
        connectToServer();
      }
    });
  }

  void connectToServer() {
    try {
      channel = IOWebSocketChannel.connect('ws://$serverIp:8765');

      channel!.stream.listen(
            (message) {
          final data = jsonDecode(message);

          setState(() {
            isConnected = true;

            if (data['type'] == 'status') {
              lightStatus = data['status'];
            }
          });
        },
        onError: (error) {
          print("WebSocket error: $error");
          handleDisconnection();
        },
        onDone: () {
          print("WebSocket connection closed");
          handleDisconnection();
        },
      );

      // Setup heartbeat
      heartbeatTimer?.cancel();
      heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (isConnected) {
          channel?.sink.add(json.encode({
            "type": "heartbeat",
            "timestamp": DateTime.now().toIso8601String()
          }));
        }
      });

    } catch (e) {
      print("Connection attempt failed: $e");
      handleDisconnection();
    }
  }

  void handleDisconnection() {
    setState(() {
      isConnected = false;
      lightStatus = "LIGHT OFF";
    });

    channel?.sink.close();
    heartbeatTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SEMS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,  // Centers the title
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              lightStatus == "LIGHT ON" ? Icons.lightbulb : Icons.lightbulb_outline,
              size: 100,
              color: lightStatus == "LIGHT ON" ? Colors.yellow : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              lightStatus,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              isConnected ? 'Connected to server' : 'Disconnected - Trying to reconnect...',
              style: TextStyle(
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Server: $serverIp',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close();
    reconnectionTimer?.cancel();
    heartbeatTimer?.cancel();
    super.dispose();
  }
}