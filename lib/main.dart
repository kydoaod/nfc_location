import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert' show utf8;

/// Global flag if NFC is avalible
bool isNfcAvalible = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for the line below
  isNfcAvalible = await NfcManager.instance.isAvailable();
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
  int _counter = 0;
  bool listenerRunning = false;
  bool writeCounterOnNextContact = false;
  final locationController = TextEditingController();
  String location = '';

  void _incrementCounter() {
    setState(() {
      _counter++;
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
                )
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
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ),
    );
  }

  Widget _getNfcWidgets() {
    if (isNfcAvalible) {
      final nfcRunning = Platform.isAndroid && listenerRunning;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: nfcRunning ? null : _listenForNFCEvents,
            child: Text(Platform.isAndroid
                ? listenerRunning
                    ? 'NFC is running'
                    : 'Start NFC listener'
                : 'Read from tag'),
          ),
          TextButton(
            onPressed: writeCounterOnNextContact ? null : _writeNfcTag,
            child: Text(writeCounterOnNextContact
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

  Future<void> _listenForNFCEvents() async {
    if (Platform.isAndroid && listenerRunning == false || Platform.isIOS) {
      if (Platform.isAndroid) {
        _alert(
          'NFC listener running in background now, approach tag(s)',
        );
        setState(() {
          listenerRunning = true;
        });
      }

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          bool success = false;
          final ndefTag = Ndef.from(tag);
          if (ndefTag != null) {
            if (writeCounterOnNextContact) {
              setState(() {
                writeCounterOnNextContact = false;
              });
              location = "TA-Location:" + locationController.text;
              final ndefRecord = NdefRecord.createText(location);
              final ndefMessage = NdefMessage([ndefRecord]);
              try {
                await ndefTag.write(ndefMessage);
                locationController.clear();
                _alert('$location written to tag');
                success = true;
              } catch (e) {
                _alert("Writting failed, press 'Write to tag' again");
              }
            }
            else if (ndefTag.cachedMessage != null) {
              var ndefMessage = ndefTag.cachedMessage!;
              if (ndefMessage.records.isNotEmpty &&
                  ndefMessage.records.first.typeNameFormat ==
                      NdefTypeNameFormat.nfcWellknown) {
                final wellKnownRecord = ndefMessage.records.first;

                if (wellKnownRecord.payload.first == 0x02) {
                  final languageCodeAndContentBytes =
                      wellKnownRecord.payload.skip(1).toList();
                  final languageCodeAndContentText =
                      utf8.decode(languageCodeAndContentBytes);
                  final payload = languageCodeAndContentText.substring(2);
                  location = payload;
                  locationController.clear();
                  if (location != null) {
                    success = true;
                    _alert("$location");
                    setState(() {
                      location = location;
                    });
                  }
                }
              }
            }
          }
          //Due to the way ios handles nfc we need to stop after each tag
          if (Platform.isIOS) {
            NfcManager.instance.stopSession();
          }
          if (success == false) {
            _alert(
              'Tag was not valid',
            );
          }
        },
        // Required for iOS to define what type of tags should be noticed
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
      );
    }
  }

  @override
  void dispose() {
    try {
      locationController.dispose();
      super.dispose();
      NfcManager.instance.stopSession();
    } catch (_) {
      //We dont care
    }
    super.dispose();
  }

  void _writeNfcTag() {
    setState(() {
      writeCounterOnNextContact = true;
    });

    if (Platform.isAndroid) {
      _alert('Approach phone with tag');
    }
    //Writing a requires to read the tag first, on android this call might do nothing as the listner is already running
    _listenForNFCEvents();
  }
}
