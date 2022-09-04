import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:janus_client/janus_client.dart';
import 'package:tablet_janus/presentation/bloc/call/call_bloc.dart';

import '../../injector.dart';

class VideoCall extends StatefulWidget {
  const VideoCall({Key? key}) : super(key: key);

  @override
  State<VideoCall> createState() => _VideoCallState();
}

class _VideoCallState extends State<VideoCall> {

  late JanusClient j;
  late WebSocketJanusTransport ws;
  late JanusSession session;
  late JanusVideoCallPlugin videoCallPlugin;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();
  MediaStream? remoteVideoStream;
  AlertDialog? incomingDialog;
  AlertDialog? registerDialog;
  AlertDialog? callDialog;
  bool ringing = false;
  bool front = true;

  initJanusClient() async {
    ws = WebSocketJanusTransport(url: dotenv.get('GATEWAY_URL'));
    j = JanusClient(
        transport: ws,
        iceServers: [
          RTCIceServer(
              urls: "turn:turn.ezway-technology.com:3478",
              username: "skipper",
              credential: "Visio2021")
        ],
        isUnifiedPlan: true);
    session = await j.createSession();
    videoCallPlugin = await session.attach<JanusVideoCallPlugin>();
  }

  initializeRemoteVideo() async {
    await _remoteVideoRenderer.initialize();
    MediaStream? tempVideo = await createLocalMediaStream('remoteVideoStream');
    setState(() {
      remoteVideoStream = tempVideo;
    });
  }

  Future<void> localMediaSetup() async {
    await _localRenderer.initialize();
    await videoCallPlugin.initializeMediaDevices();
    _localRenderer.srcObject = videoCallPlugin.webRTCHandle?.localStream;
  }

  makeCall() async {
    await localMediaSetup();
    var offer = await videoCallPlugin.createOffer(
        audioSend: true, audioRecv: true, videoRecv: true, videoSend: true);
    await videoCallPlugin.call("Tsiresy", offer: offer);
  }


  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await _localRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer(
        bloc: sl.get<CallBloc>(),
        listener: (ctx, state) {
          if(state is CallTypedMessageState){
            switch(state.data){
              case VideoCallRegisteredEvent :
                Fluttertoast.showToast(msg: "User register");
                break;
              case VideoCallIncomingCallEvent :
                Fluttertoast.showToast(msg: "User register");
                break;
            }
          }
          else if(state is CallRemoteTrackState){
            remoteVideoStream?.addTrack(state.event.track!);
            _remoteVideoRenderer.srcObject = remoteVideoStream;
          }
        }, builder: (ctx, state) {
      return Scaffold();
    });
  }
}
