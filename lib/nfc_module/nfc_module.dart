import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert' show utf8;

// class NfcModule extends StatefulWidget { // immutable Widget
//     final void Function(String) setValueFromTag;
//     final void Function(bool) listenerStatusCallback;
//     NfcModule(this.setValueFromTag, this.listenerStatusCallback);
//     @override
//     _NfcModule createState() => _NfcModule(this.setValueFromTag, this.listenerStatusCallback);
// }

class NfcModule{
    final void Function(String value) setValueFromTag;
    final void Function(bool listenerRunning) listenerStatusCallback;
    bool isNfcAvailable = false;
    bool listenerRunning = false;
    String value = "";

    NfcModule({required this.setValueFromTag, required this.listenerStatusCallback});

    void initNfc() async {
        isNfcAvailable = await NfcManager.instance.isAvailable();
    }

    bool getNfcAvailability() {
        return isNfcAvailable;
    }

    void setValueToWrite(String val){
        value = val;
    }

    void clearValue(String val){
        value = "";
    }

    bool isListenerRunning(){
        return listenerRunning;
    }

    Future<void> writeToNfc() async {
        if (Platform.isAndroid && listenerRunning == false || Platform.isIOS) {
            if (Platform.isAndroid) {
                listenerRunning = true;
                listenerStatusCallback(true);
            }
            NfcManager.instance.startSession(
                onDiscovered: (NfcTag tag) async {
                    bool success = false;
                    final ndefTag = Ndef.from(tag);
                    if (ndefTag != null) {
                        final ndefRecord = NdefRecord.createText(value);
                        final ndefMessage = NdefMessage([ndefRecord]);
                        try {
                            await ndefTag.write(ndefMessage);
                            print('$value written to tag');
                            NfcManager.instance.stopSession();
                            listenerRunning = false;
                            listenerStatusCallback(false);
                            success = true;
                        } catch (e) {
                            print("Writting failed, press 'Write to tag' again");
                        }
                    }
                    //Due to the way ios handles nfc we need to stop after each tag
                    if (Platform.isIOS) {
                        NfcManager.instance.stopSession();
                    }
                    if (success == false) {
                        print(
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
    
    Future<void> listenForNFCEvents() async {
        if (Platform.isAndroid && listenerRunning == false || Platform.isIOS) {
            if (Platform.isAndroid) {
                listenerRunning = true;
                listenerStatusCallback(true);
            }

            NfcManager.instance.startSession(
                onDiscovered: (NfcTag tag) async {
                    bool success = false;
                    final ndefTag = Ndef.from(tag);
                    if (ndefTag != null) {
                        if (ndefTag.cachedMessage != null) {
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
                                    setValueFromTag(payload);
                                }
                            }
                        }
                    }
                    //Due to the way ios handles nfc we need to stop after each tag
                    if (Platform.isIOS) {
                        NfcManager.instance.stopSession();
                        listenerStatusCallback(false);
                    }
                    if (success == false) {
                        print(
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

    void stopNfcSession(){
        NfcManager.instance.stopSession();
    }
}