import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert';

class NfcModule{
    final void Function(String value) setValueFromTag;
    final void Function(bool listenerRunning) listenerStatusCallback;
    final void Function(bool writeMode) writeStatusCallback;
    bool isNfcAvailable = false;
    bool listenerRunning = false;
    bool writeMode = false;
    String value = "";

    NfcModule({required this.setValueFromTag, required this.listenerStatusCallback, required this.writeStatusCallback});

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

    //START NFC info
    String _getTechListString(NfcTag tag) {
        final techList = <String>[];
        if (tag.data.containsKey('nfca'))
            techList.add('NfcA');
        if (tag.data.containsKey('nfcb'))
            techList.add('NfcB');
        if (tag.data.containsKey('nfcf'))
            techList.add('NfcF');
        if (tag.data.containsKey('nfcv'))
            techList.add('NfcV');
        if (tag.data.containsKey('isodep'))
            techList.add('IsoDep');
        if (tag.data.containsKey('mifareclassic'))
            techList.add('MifareClassic');
        if (tag.data.containsKey('mifareultralight'))
            techList.add('MifareUltralight');
        if (tag.data.containsKey('ndef'))
            techList.add('Ndef');
        if (tag.data.containsKey('ndefformatable'))
            techList.add('NdefFormatable');
        return techList.join(', ');
    }

    String _getNdefType(String code) {
        switch (code) {
            case 'org.nfcforum.ndef.type1':
            return 'NFC Forum Tag Type 1';
            case 'org.nfcforum.ndef.type2':
            return 'NFC Forum Tag Type 2';
            case 'org.nfcforum.ndef.type3':
            return 'NFC Forum Tag Type 3';
            case 'org.nfcforum.ndef.type4':
            return 'NFC Forum Tag Type 4';
            default:
            return 'Unknown';
        }
    }

    String toHexString(var arr){
        String hexData = "0x";
        print(arr);
        for (int i = 0; i < arr.length; i++) {
            hexData += arr[i].toRadixString(16);
        }
        return hexData;
    }
    //END NFC info

    Future<void> writeToNfc() async {
        writeStatusCallback(true);
        if (Platform.isAndroid && !writeMode || Platform.isIOS) {
            if (Platform.isAndroid) {
                listenerRunning = true;
                writeMode = true;
                writeStatusCallback(true);
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
                            writeMode = false;
                            listenerStatusCallback(false);
                            writeStatusCallback(false);
                            setValueFromTag(value);
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
        if(writeMode){
            return;
        }
        if (Platform.isAndroid && listenerRunning == false || Platform.isIOS) {
            if (Platform.isAndroid) {
                listenerRunning = true;
                listenerStatusCallback(true);
            }

            NfcManager.instance.startSession(
                onDiscovered: (NfcTag tag) async {
                    bool success = false;
                    final ndefTag = Ndef.from(tag);
                    final tagData = json.decode(json.encode(tag.data));
                    if (ndefTag != null) {
                        if (ndefTag.cachedMessage != null) {
                            var ndefMessage = ndefTag.cachedMessage!;
                            print(
                                json.encode({
                                    "serialNumber": toHexString(tagData["ndef"]["identifier"]),
                                    "techList": _getTechListString(tag),
                                    "type": _getNdefType(ndefTag.additionalData['type']),
                                    "size": '${ndefMessage?.byteLength ?? 0} / ${ndefTag.maxSize} bytes',
                                    "writeable": ndefTag.isWritable,
                                    //"atqa": toHexString(tagData["nfca"]["atqa"]),
                                })
                            );
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