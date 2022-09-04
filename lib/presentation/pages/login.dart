import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:tablet_janus/core/utils/utils.dart';
import 'package:tablet_janus/presentation/pages/home.dart';

import '../bloc/call/call_bloc.dart';

class LoginQrCodeScanner extends StatefulWidget {
  const LoginQrCodeScanner({Key? key}) : super(key: key);

  @override
  State<LoginQrCodeScanner> createState() => _LoginQrCodeScannerState();
}

class _LoginQrCodeScannerState extends State<LoginQrCodeScanner> {

  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    logInfo('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      logInfo(scanData);
      setState(() {
        result = scanData;
      });
    });
  }


  @override
  Widget build(BuildContext context) {

    var scanArea = (MediaQuery.of(context).size.width < 400 ||
        MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;

    return Scaffold(
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 0,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: scanArea),
            onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(onPressed: (){
                  context.read<CallBloc>().add(CallRegisterEvent(name: "Tsiresy Milà"));
                  Get.to(()=>const HomeScreen());
                }, icon: const Icon(Icons.back_hand, color: Colors.white,)),
                IconButton(onPressed: (){
                  controller?.toggleFlash();
                }, icon: const Icon(Icons.flash_on, color: Colors.white,)),
                IconButton(onPressed: (){
                  controller?.flipCamera();
                }, icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white,))
              ],
            ),
          )
        ],
      )
    );
  }
}
