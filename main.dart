import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const BLEApp());
}

class BLEApp extends StatelessWidget {
  const BLEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BLEHome(),
    );
  }
}

class BLEHome extends StatefulWidget {
  const BLEHome({super.key});

  @override
  State<BLEHome> createState() => _BLEHomeState();
}

class _BLEHomeState extends State<BLEHome> {
  List<ScanResult> devices = [];
  StreamSubscription<List<ScanResult>>? scanSub;

  BluetoothDevice? selectedDevice;
  BluetoothCharacteristic? rxChar;

  bool scanning = false;
  bool connected = false;

  String? lastSent;
  DateTime? lastSentTime;

  final TextEditingController customNameController =
      TextEditingController();

  final List<String> presetNames = [
    "Alice",
    "Bob",
    "Charlie",
    "Diana",
    "Evan",
    "Fiona",
    "George",
    "Hannah"
  ];

  // ---------------- SCAN ----------------
  Future<void> startScan() async {
    setState(() {
      scanning = true;
      devices.clear();
    });

    try {
      await FlutterBluePlus.adapterState.firstWhere(
        (s) => s == BluetoothAdapterState.on,
      );

      await scanSub?.cancel();
      await FlutterBluePlus.stopScan();

      scanSub = FlutterBluePlus.scanResults.listen((results) {
        setState(() => devices = results);
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint("SCAN ERROR: $e");
    }

    setState(() => scanning = false);
  }

  // ---------------- CONNECT (FIXED BINDING) ----------------
  Future<void> connect(BluetoothDevice d) async {
    try {
      await FlutterBluePlus.stopScan();

      await d.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      selectedDevice = d;
      rxChar = null;

      final services = await d.discoverServices();

      for (final s in services) {
        for (final c in s.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();

          debugPrint("CHAR FOUND: $uuid");

          // 🔴 STRICT MATCH ONLY (NO CONTAINS)
          if (uuid ==
              "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
            if (c.properties.write ||
                c.properties.writeWithoutResponse) {
              rxChar = c;
              debugPrint("✅ RX CHARACTERISTIC LOCKED");
            }
          }
        }
      }

      if (rxChar == null) {
        debugPrint("❌ RX CHARACTERISTIC NOT FOUND");
      }

      setState(() {
        connected = true;
      });

      debugPrint("CONNECTED: ${d.platformName}");
    } catch (e) {
      debugPrint("CONNECT ERROR: $e");
      setState(() => connected = false);
    }
  }

  // ---------------- SEND ----------------
  Future<void> sendName(String name) async {
    final clean = name.trim();

    if (clean.isEmpty || rxChar == null) return;

    try {
      debugPrint("WRITING TO: ${rxChar!.uuid}");
      debugPrint("DATA: $clean");

      await rxChar!.write(
        clean.codeUnits,
        withoutResponse: false,
      );

      setState(() {
        lastSent = clean;
        lastSentTime = DateTime.now();
      });
    } catch (e) {
      debugPrint("SEND ERROR: $e");
    }
  }

  // ---------------- DISCONNECT ----------------
  Future<void> disconnect() async {
    if (selectedDevice != null) {
      await selectedDevice!.disconnect();
    }

    setState(() {
      connected = false;
      selectedDevice = null;
      rxChar = null;
      lastSent = null;
    });
  }

  @override
  void dispose() {
    scanSub?.cancel();
    customNameController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final connectedState = selectedDevice != null && connected;

    return Scaffold(
      appBar: AppBar(title: const Text("BLE Nametag")),

      body: Column(
        children: [
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: scanning ? null : startScan,
                child: Text(scanning ? "Scanning..." : "Rescan"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: connectedState ? disconnect : null,
                child: const Text("Disconnect"),
              ),
            ],
          ),

          const Divider(),

          if (lastSent != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text("LAST SENT"),
                  const SizedBox(height: 4),
                  Text(
                    lastSent!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(),

          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, i) {
                final d = devices[i];

                return ListTile(
                  title: Text(
                    d.device.platformName.isEmpty
                        ? "(no name)"
                        : d.device.platformName,
                  ),
                  subtitle: Text(d.device.remoteId.toString()),
                  onTap: () => connect(d.device),
                );
              },
            ),
          ),

          const Divider(),

          Wrap(
            spacing: 8,
            children: presetNames.map((n) {
              final active = lastSent == n;

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      active ? Colors.green : null,
                ),
                onPressed:
                    connectedState ? () => sendName(n) : null,
                child: Text(n),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: customNameController,
              decoration: const InputDecoration(
                labelText: "Custom Name",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: connectedState
                ? () => sendName(customNameController.text)
                : null,
            child: const Text("Send Custom Name"),
          ),

          const SizedBox(height: 15),
        ],
      ),
    );
  }
}