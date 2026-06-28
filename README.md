# Çizgi İzleyen Otonom Araç (Autonomous AGV) 🚗🤖

An advanced autonomous line-following vehicle (AGV) engineered with a hardware-level safety protocol, a Python-based desktop telemetry dashboard, and a Flutter Android companion app.

Developed as an engineering project at **Bursa Uludağ University (BUÜ)**, this system bridges embedded hardware logic with multi-platform software engineering to provide real-time monitoring and dynamic Bluetooth control.

## ✨ Key Features

- **PID Navigation:** Ensures precise and smooth navigation along defined paths using a custom-designed 4-channel sensor module.
- **Hardware-Level Safe-Stop:** Utilizes an ultrasonic sensor to physically cut motor power when an obstacle is detected within a 15 cm threshold, overriding any software commands for maximum safety.
- **Computer-Based Telemetry:** A desktop GUI built with Python (`Tkinter` & `pyserial`) that parses incoming serial data every 200ms to display precise distance metrics and safety status.
- **Flutter Mobile App:** A custom Android application featuring a virtual joystick, real-time status updates, and seamless mode-switching.
- **Dynamic Modding:** Instantaneous switching between Autonomous mode (A) and Manual mode (M) via either the desktop dashboard or the mobile app.

## 🛠️ Hardware Components

- **Microcontroller:** Arduino Uno (with Sensor Shield V5.0)
- **Motor Driver:** L298N Dual H-Bridge
- **Actuators:** 4x DC Gear Motors (TT Motors) in a 4WD configuration
- **Sensors:** \* 1x HC-SR04 Ultrasonic Sensor (Obstacle detection)
  - 1x 4-Channel IR Line Tracking Module
- **Connectivity:** HC-05 Bluetooth Module (Serial Communication)
- **Alert System:** Active Buzzer
- **Power:** 2x 18650 Li-ion Batteries

## 📐 Circuit Diagram

The entire hardware topology has been meticulously mapped. All software pin definitions match the physical layout below.

![Circuit Diagram](Hardware_Design/Circuit%20Diagram.png)

## 💻 Software Architecture & Repositories

This project is divided into three main components:

1. 📁 **`Arduino_Firmware/`**: Written in C++, handling hardware interrupts, PID calculations, sensor polling, and Bluetooth data transmission.
2. 📁 **`Python_Dashboard/`**: The desktop control center. Run `python main.py` to establish a serial connection and monitor the AGV's telemetry.
3. 📁 **`Flutter_Android_App/`**: The mobile controller source code. Includes Bluetooth Classic integration for seamless wireless command execution.

## 🚀 Installation & Usage

### 1. Hardware Setup

- Assemble the chassis and wire the components strictly according to the circuit diagram.
- Pair your computer and/or Android phone's Bluetooth with the HC-05 module (Default PIN: `0000` or `1234`).

### 2. Firmware (Arduino)

- Open the `.ino` file in the Arduino IDE.
- Select the Arduino Uno board and the correct COM port, then upload the code.

### 3. Desktop Dashboard (Python)

- Navigate to the `Python_Dashboard` directory.
- Install dependencies: `pip install pyserial`
- Launch the UI: `python main.py`
- Select your Bluetooth COM port from the dropdown and click **Connect**.

### 4. Mobile App (Android)

- **Quick Install:** Download the latest `BUU_Otonom_Arac_v1.0.apk` from the [Releases](../../releases) tab and install it on your Android device.
- **For Developers:** Open the `Flutter_Android_App` folder in VS Code or Android Studio, run `flutter pub get`, and deploy it to your device using `flutter run`.

---

_Bridging Embedded Systems with Modern Software Engineering._
