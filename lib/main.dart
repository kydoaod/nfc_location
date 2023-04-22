import 'dart:io';

import 'package:flutter/material.dart';
//import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert' show utf8;

import 'package:nfc_counter/nfc_module/nfc_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for the line below
  //isNfcAvalible = await NfcManager.instance.isAvailable();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter NFC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter NFC Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool listenerRunning = false;
  bool isDoneLoading = false;
  final locationController = TextEditingController();
  NfcModule? nfcModule;
  String location = '';

  @override
  void initState () {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      nfcModule = new NfcModule(setValueFromTag: setValueFromTag, listenerStatusCallback: listenerStatusCallback);
      nfcModule?.initNfc();
      setState(() {
        isDoneLoading = true;
      });
    });  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 50, vertical: 16),
              child: TextField(
                controller: locationController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter Location:',
                ),
                onChanged: (text) {
                  nfcModule?.setValueToWrite("TA-Location:" + text);
                }
              )
            ),
            Text(
              '$location',
              style: Theme.of(context).textTheme.headline4,
            ),
            _getNfcWidgets(),
          ],
        ),
      ),
    );
  }

  Widget _getNfcWidgets() {
    if(isDoneLoading){
      if (nfcModule!.getNfcAvailability()) {
        final nfcRunning = Platform.isAndroid && listenerRunning;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: nfcRunning ? null : nfcModule?.listenForNFCEvents,
              child: Text(Platform.isAndroid
                  ? listenerRunning
                      ? 'NFC is running'
                      : 'Start NFC listener'
                  : 'Read from tag'),
            ),
            TextButton(
              onPressed: listenerRunning ? null : nfcModule?.writeToNfc,
              child: Text(listenerRunning
                  ? 'Waiting for tag to write'
                  : 'Write to tag'),
            ),
            TextButton(
                onPressed: () => setState(() {
                      location = "";
                      locationController.clear();
                    }),
                child: const Text('Clear all'))
          ],
        );
      } else {
        if (Platform.isIOS) {
          return const Text("Your device doesn't support NFC");
        } else {
          return const Text(
              "Your device doesn't support NFC or it's turned off in the system settings");
        }
      }
    } else {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Module still loading please wait...')
          ]
        );
    }
  }

  void _alert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          location == ""? "No record found" : location
        ),
        duration: const Duration(
          seconds: 2,
        ),
      ),
    );
  }

  //Start Required callback functions for NFC module
  
  void setValueFromTag(String payload){
    location = payload;
    locationController.clear();
    if (location != null) {
        _alert("$location");
        setState(() {
            location = location;
        });
    }
  }

  void listenerStatusCallback(bool _writeCounterOnNextContact){
    setState(() {
      listenerRunning = _writeCounterOnNextContact;
    });
  }

  //End Required callback functions for NFC module

  @override
  void dispose() {
    try {
      locationController.dispose();
      super.dispose();
      //NfcManager.instance.stopSession();
    } catch (_) {
      //We dont care
    }
    super.dispose();
  }
}
