import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const RobotApp());
}

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BUÜ Otonom Araç',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050A18),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      home: const RobotControllerPage(),
    );
  }
}

class RobotControllerPage extends StatefulWidget {
  const RobotControllerPage({super.key});

  @override
  State<RobotControllerPage> createState() => _RobotControllerPageState();
}

class _RobotControllerPageState extends State<RobotControllerPage> {
  late FlutterBluetoothClassic bluetooth;

  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;

  StreamSubscription<BluetoothConnectionState>? connectionSub;
  StreamSubscription<BluetoothData>? dataSub;
  StreamSubscription<BluetoothState>? stateSub;

  bool isSupported = true;
  bool isEnabled = false;
  bool isConnected = false;
  bool isLoading = false;

  int speedLevel = 5;
  double? distance;
  String distanceStatus = 'Veri bekleniyor';
  String statusText = 'Sistem hazır';
  String currentMode = 'M';

  Offset joystickOffset = Offset.zero;
  String lastJoystickCommand = 'S';
  String lastSentCommand = '';
  DateTime lastCommandTime = DateTime.fromMillisecondsSinceEpoch(0);

  final StringBuffer serialBuffer = StringBuffer();

  @override
  void initState() {
    super.initState();
    bluetooth = FlutterBluetoothClassic();
    initBluetooth();
  }

  @override
  void dispose() {
    connectionSub?.cancel();
    dataSub?.cancel();
    stateSub?.cancel();
    bluetooth.disconnect();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> initBluetooth() async {
    await requestPermissions();

    stateSub = bluetooth.onStateChanged.listen((state) {
      setState(() {
        isEnabled = state.isEnabled;
      });

      if (state.isEnabled) {
        loadPairedDevices();
      }
    });

    connectionSub = bluetooth.onConnectionChanged.listen((state) {
      setState(() {
        isConnected = state.isConnected;

        if (!state.isConnected) {
          selectedDevice = null;
          statusText = 'Bağlantı kesildi';
          joystickOffset = Offset.zero;
          lastJoystickCommand = 'S';
          lastSentCommand = '';
        }
      });
    });

    dataSub = bluetooth.onDataReceived.listen((data) {
      handleData(data.asString());
    });

    await checkBluetooth();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> checkBluetooth() async {
    try {
      final supported = await bluetooth.isBluetoothSupported();
      final enabled = await bluetooth.isBluetoothEnabled();

      setState(() {
        isSupported = supported;
        isEnabled = enabled;
      });

      if (supported && enabled) {
        await loadPairedDevices();
      }
    } catch (e) {
      setState(() {
        statusText = 'Bluetooth kontrol hatası';
      });
    }
  }

  Future<void> enableBluetooth() async {
    try {
      await bluetooth.enableBluetooth();
      await checkBluetooth();
    } catch (e) {
      showMessage('Bluetooth açılamadı');
    }
  }

  Future<void> loadPairedDevices() async {
    try {
      final paired = await bluetooth.getPairedDevices();

      setState(() {
        devices = paired;
      });
    } catch (e) {
      showMessage('Cihazlar okunamadı');
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      statusText = '${device.name} bağlanıyor...';
    });

    try {
      await bluetooth.connect(device.address);

      setState(() {
        selectedDevice = device;
        isConnected = true;
        statusText = '${device.name} bağlı';
        lastSentCommand = '';
      });

      await sendCommand('M', force: true);
      await Future.delayed(const Duration(milliseconds: 120));
      await sendCommand(speedLevel.toString(), force: true);
    } catch (e) {
      setState(() {
        statusText = 'Bağlantı kurulamadı';
      });
      showMessage('Bağlantı hatası');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> disconnectDevice() async {
    try {
      await sendCommand('S', force: true);
      await bluetooth.disconnect();

      setState(() {
        selectedDevice = null;
        isConnected = false;
        distance = null;
        distanceStatus = 'Veri bekleniyor';
        statusText = 'Bağlantı kesildi';
        joystickOffset = Offset.zero;
        lastJoystickCommand = 'S';
        lastSentCommand = '';
      });
    } catch (e) {
      showMessage('Bağlantı kesilemedi');
    }
  }

  Future<void> sendCommand(String command, {bool force = false}) async {
    if (!isConnected) return;

    final now = DateTime.now();
    final diff = now.difference(lastCommandTime).inMilliseconds;

    if (!force && command == lastSentCommand && command != 'S' && diff < 120) {
      return;
    }

    try {
      await bluetooth.sendString(command);
      lastSentCommand = command;
      lastCommandTime = now;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusText = 'Komut gönderilemedi';
      });
    }
  }

  void handleData(String data) {
    serialBuffer.write(data);

    final content = serialBuffer.toString();

    if (!content.contains('\n')) return;

    final lines = content.split('\n');
    serialBuffer.clear();

    if (lines.last.trim().isNotEmpty) {
      serialBuffer.write(lines.last);
    }

    for (int i = 0; i < lines.length - 1; i++) {
      processLine(lines[i].trim());
    }
  }

  void processLine(String line) {
    if (!line.startsWith('D:')) return;

    final rawValue = line.replaceFirst('D:', '').trim().replaceAll(',', '.');
    final value = double.tryParse(rawValue);

    if (value == null) return;

    setState(() {
      if (value >= 999.0) {
        distance = null;
        distanceStatus = 'Veri yok';
      } else {
        distance = value;

        if (value <= 15.0) {
          distanceStatus = 'ENGEL ALGILANDI';
        } else if (value <= 30.0) {
          distanceStatus = 'Yakın mesafe';
        } else {
          distanceStatus = 'Güvenli';
        }
      }
    });
  }

  void setManualMode() {
    currentMode = 'M';
    sendCommand('M', force: true);

    setState(() {
      statusText = 'Mod: Manuel';
      joystickOffset = Offset.zero;
      lastJoystickCommand = 'S';
    });
  }

  void setAutoMode() {
    currentMode = 'A';
    sendCommand('A', force: true);

    setState(() {
      statusText = 'Mod: Otomatik';
      joystickOffset = Offset.zero;
      lastJoystickCommand = 'S';
    });
  }

  void updateSpeed(double value) {
    final level = value.round();

    setState(() {
      speedLevel = level;
    });

    sendCommand(level.toString(), force: true);
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Color get distanceColor {
    if (distance == null) return const Color(0xFF94A3B8);
    if (distance! <= 15.0) return const Color(0xFFEF4444);
    if (distance! <= 30.0) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  int get pwmValue {
    return 90 + ((speedLevel / 9) * 90).round();
  }

  @override
  Widget build(BuildContext context) {
    if (!isSupported) {
      return Scaffold(
        body: Center(
          child: Text(
            'Bluetooth desteklenmiyor',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (!isEnabled) {
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, c) {
            return Container(
              width: c.maxWidth,
              height: c.maxHeight,
              color: const Color(0xFF050A18),
              child: Center(
                child: SizedBox(
                  width: c.maxWidth * 0.35,
                  height: c.maxHeight * 0.45,
                  child: responsiveCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth,
                          size: c.maxHeight * 0.12,
                          color: const Color(0xFF6366F1),
                        ),
                        SizedBox(height: c.maxHeight * 0.03),
                        Text(
                          'Bluetooth kapalı',
                          style: TextStyle(
                            fontSize: c.maxHeight * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: c.maxHeight * 0.03),
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: enableBluetooth,
                              child: Text(
                                'Bluetooth Aç',
                                style: TextStyle(
                                  fontSize: c.maxHeight * 0.03,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Container(
            width: w,
            height: h,
            padding: EdgeInsets.all(w * 0.012),
            color: const Color(0xFF050A18),
            child: Column(
              children: [
                Expanded(flex: 10, child: topBarResponsive(w, h)),
                SizedBox(height: h * 0.015),
                Expanded(
                  flex: 90,
                  child: Row(
                    children: [
                      Expanded(flex: 38, child: analogControlPanel(w, h)),
                      SizedBox(width: w * 0.012),
                      Expanded(flex: 27, child: centerPanel(w, h)),
                      SizedBox(width: w * 0.012),
                      Expanded(flex: 35, child: rightPanel(w, h)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget topBarResponsive(double w, double h) {
    return responsiveCard(
      child: Row(
        children: [
          Icon(
            Icons.directions_car_filled,
            color: const Color(0xFF6366F1),
            size: h * 0.045,
          ),
          SizedBox(width: w * 0.012),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BURSA ULUDAĞ ÜNİVERSİTESİ',
                    style: TextStyle(
                      fontSize: h * 0.022,
                      color: const Color(0xFF818CF8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Doğrusal Hat İzleyen Otonom Araç',
                    style: TextStyle(
                      fontSize: h * 0.032,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: loadPairedDevices,
            icon: Icon(Icons.refresh, size: h * 0.045),
          ),
        ],
      ),
    );
  }

  Widget centerPanel(double w, double h) {
    return Column(
      children: [
        Expanded(flex: 58, child: connectionPanel(w, h)),
        SizedBox(height: h * 0.015),
        Expanded(flex: 42, child: modePanel(w, h)),
      ],
    );
  }

  Widget rightPanel(double w, double h) {
    return Column(
      children: [
        Expanded(flex: 45, child: distancePanel(w, h)),
        SizedBox(height: h * 0.015),
        Expanded(flex: 35, child: speedPanel(w, h)),
        SizedBox(height: h * 0.015),
        Expanded(flex: 20, child: statusPanel(w, h)),
      ],
    );
  }

  Widget connectionPanel(double w, double h) {
    return responsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitleResponsive('BAĞLANTI', Icons.bluetooth, h),
          Expanded(
            child: selectedDevice == null
                ? devices.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Eşleşmiş cihaz bulunamadı',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: h * 0.025),
                            ),
                            SizedBox(height: h * 0.02),
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: loadPairedDevices,
                                  child: FittedBox(
                                    child: Text(
                                      'YENİLE',
                                      style: TextStyle(
                                        fontSize: h * 0.025,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        )
                      : ListView.builder(
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            final isHC = device.name.toUpperCase().contains(
                              'HC',
                            );

                            return Container(
                              margin: EdgeInsets.only(bottom: h * 0.012),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(w * 0.018),
                                border: Border.all(
                                  color: isHC
                                      ? const Color(0xFF6366F1)
                                      : Colors.transparent,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.bluetooth_connected,
                                  color: isHC
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF94A3B8),
                                  size: h * 0.04,
                                ),
                                title: Text(
                                  device.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: h * 0.025,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  device.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: h * 0.02),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => connectToDevice(device),
                                  child: Text(
                                    isLoading ? '...' : 'BAĞLAN',
                                    style: TextStyle(fontSize: h * 0.02),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedDevice?.name ?? 'Cihaz',
                                style: TextStyle(
                                  fontSize: h * 0.035,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                selectedDevice?.address ?? '',
                                style: TextStyle(
                                  fontSize: h * 0.023,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: disconnectDevice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              'KES',
                              style: TextStyle(
                                fontSize: h * 0.025,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget modePanel(double w, double h) {
    return responsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitleResponsive('SÜRÜŞ MODU', Icons.settings_remote, h),
          SizedBox(height: h * 0.015),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: modeButtonResponsive(
                    'MANUEL',
                    currentMode == 'M',
                    const Color(0xFFF59E0B),
                    setManualMode,
                    h,
                  ),
                ),
                SizedBox(width: w * 0.01),
                Expanded(
                  child: modeButtonResponsive(
                    'OTOMATİK',
                    currentMode == 'A',
                    const Color(0xFF10B981),
                    setAutoMode,
                    h,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget distancePanel(double w, double h) {
    return responsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitleResponsive('MESAFE', Icons.social_distance, h),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(
                      distance == null
                          ? '--- cm'
                          : '${distance!.toStringAsFixed(2)} cm',
                      style: TextStyle(
                        fontSize: h * 0.09,
                        fontWeight: FontWeight.bold,
                        color: distanceColor,
                      ),
                    ),
                    Text(
                      distanceStatus,
                      style: TextStyle(
                        fontSize: h * 0.03,
                        fontWeight: FontWeight.bold,
                        color: distanceColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget speedPanel(double w, double h) {
    return responsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitleResponsive('HIZ KONTROLÜ', Icons.speed, h),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seviye $speedLevel',
                style: TextStyle(
                  fontSize: h * 0.035,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'PWM $pwmValue',
                style: TextStyle(
                  fontSize: h * 0.025,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          Slider(
            value: speedLevel.toDouble(),
            min: 0,
            max: 9,
            divisions: 9,
            label: speedLevel.toString(),
            onChanged: updateSpeed,
          ),
        ],
      ),
    );
  }

  Widget statusPanel(double w, double h) {
    return responsiveCard(
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.info,
            color: isConnected
                ? const Color(0xFF10B981)
                : const Color(0xFF94A3B8),
            size: h * 0.04,
          ),
          SizedBox(width: w * 0.01),
          Expanded(
            child: Text(
              statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: h * 0.025,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget analogControlPanel(double w, double h) {
    final disabled = !isConnected || currentMode != 'M';

    return responsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitleResponsive('ANALOG KONTROL', Icons.gamepad, h),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final size = math.min(c.maxWidth * 0.82, c.maxHeight * 0.82);
                final baseRadius = size / 2;
                final knobSize = size * 0.28;
                final maxMove = baseRadius - (knobSize / 2) - (size * 0.04);

                return Center(
                  child: GestureDetector(
                    onPanStart: disabled
                        ? null
                        : (details) {
                            handleJoystick(
                              details.localPosition,
                              size,
                              maxMove,
                            );
                          },
                    onPanUpdate: disabled
                        ? null
                        : (details) {
                            handleJoystick(
                              details.localPosition,
                              size,
                              maxMove,
                            );
                          },
                    onPanEnd: disabled
                        ? null
                        : (_) {
                            resetJoystick();
                          },
                    onPanCancel: disabled
                        ? null
                        : () {
                            resetJoystick();
                          },
                    child: Opacity(
                      opacity: disabled ? 0.35 : 1,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF111827),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                  width: size * 0.012,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: size * 0.08,
                                    offset: Offset(0, size * 0.035),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: size * 0.68,
                              height: size * 0.68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1E293B),
                                  width: size * 0.01,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.add,
                              size: size * 0.45,
                              color: const Color(0xFF334155),
                            ),
                            Transform.translate(
                              offset: joystickOffset,
                              child: Container(
                                width: knobSize,
                                height: knobSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: lastJoystickCommand == 'S'
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF6366F1),
                                  border: Border.all(
                                    color: const Color(0xFF818CF8),
                                    width: knobSize * 0.045,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    lastJoystickCommand,
                                    style: TextStyle(
                                      fontSize: knobSize * 0.28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void handleJoystick(Offset localPosition, double size, double maxMove) {
    final center = Offset(size / 2, size / 2);
    Offset delta = localPosition - center;

    final distanceFromCenter = delta.distance;

    if (distanceFromCenter > maxMove) {
      delta = Offset(
        delta.dx / distanceFromCenter * maxMove,
        delta.dy / distanceFromCenter * maxMove,
      );
    }

    final dx = delta.dx;
    final dy = delta.dy;
    final deadZone = maxMove * 0.28;

    String command = 'S';

    if (dy < -deadZone && dx > deadZone) {
      command = 'G';
    } else if (dy < -deadZone && dx < -deadZone) {
      command = 'I';
    } else if (dy < -deadZone) {
      command = 'F';
    } else if (dy > deadZone) {
      command = 'B';
    } else if (dx < -deadZone) {
      command = 'L';
    } else if (dx > deadZone) {
      command = 'R';
    }

    final oldCommand = lastJoystickCommand;

    setState(() {
      joystickOffset = delta;
      lastJoystickCommand = command;
    });

    if (command != oldCommand) {
      sendCommand(command, force: command == 'S');
    }
  }

  void resetJoystick() {
    setState(() {
      joystickOffset = Offset.zero;
      lastJoystickCommand = 'S';
    });

    sendCommand('S', force: true);
  }

  Widget modeButtonResponsive(
    String text,
    bool active,
    Color color,
    VoidCallback onTap,
    double h,
  ) {
    return ElevatedButton(
      onPressed: isConnected ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? color : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(h * 0.035),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(fontSize: h * 0.027, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget responsiveCard({required Widget child}) {
    return LayoutBuilder(
      builder: (context, c) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(c.maxWidth * 0.04),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(c.maxWidth * 0.04),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: child,
        );
      },
    );
  }

  Widget sectionTitleResponsive(String title, IconData icon, double h) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: h * 0.035),
        SizedBox(width: h * 0.015),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF818CF8),
              fontSize: h * 0.025,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}
