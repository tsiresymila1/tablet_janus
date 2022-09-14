import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:tablet_janus/core/utils/utils.dart';
import 'package:tablet_janus/presentation/pages/call.dart';
import 'package:wakelock/wakelock.dart';
import 'package:janus_client/janus_client.dart';
import 'package:tablet_janus/presentation/bloc/call/call_bloc.dart';

import '../../injector.dart';

class IncomingCallScreen extends StatefulWidget {
  final String caller;
  final RTCSessionDescription? jsep;

  const IncomingCallScreen({Key? key, required this.caller, this.jsep})
      : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();
  MediaStream? remoteVideoStream;
  bool front = true;
  bool isIncoming = true;
  JanusVideoCallPlugin? videoCallPlugin;

  Future initializeRemoteVideo() async {
    await _remoteVideoRenderer.initialize();
    MediaStream? tempVideo = await createLocalMediaStream('remoteVideoStream');
    setState(() {
      remoteVideoStream = tempVideo;
    });
  }

  Future<void> cleanUpWebRTCStuff() async {
    setState(() {
      _localRenderer.srcObject = null;
      _remoteVideoRenderer.srcObject = null;
    });
    _localRenderer.dispose();
    _remoteVideoRenderer.dispose();
  }

  Future destroy() async {
    Get.offAll(() => const MakeCallScreen());
  }

  @override
  void initState() {
    Wakelock.enable();
    super.initState();
  }

  @override
  void dispose() async {
    Wakelock.disable();
    super.dispose();
    cleanUpWebRTCStuff();
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
        bloc: sl.get<CallBloc>()..add(CallGetVideoRoomEvent()),
        listener: (ctx, state) async {
          if (state is CallVideoRoomState) {
            setState(() {
              videoCallPlugin = state.videoCallPlugin;
            });
          } else if (state is CallInitializedMediaState) {
            setState(() {
              videoCallPlugin = state.videoCallPlugin;
              _localRenderer.srcObject =
                  state.videoCallPlugin.webRTCHandle?.localStream;
            });
            context
                .read<CallBloc>()
                .add(CallAcceptedEvent(name: widget.caller, jsep: widget.jsep));
          } else if (state is CallRemoteTrackState) {
            await initializeRemoteVideo();
            remoteVideoStream?.addTrack(state.event.track!);
            setState(() {
              _remoteVideoRenderer.srcObject = remoteVideoStream;
            });
          } else if (state is CallHangupState) {
            destroy();
          } else if (state is CallRotatedCameraState) {
            if (videoCallPlugin != null) {
              setState(() {
                _localRenderer.srcObject =
                    videoCallPlugin?.webRTCHandle?.localStream;
              });
            }
          }
        },
        builder: (context, state) => Scaffold(
              body: Stack(children: [
                isIncoming
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Incoming call from ...',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(widget.caller),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          Stack(
                            children: [
                              Container(
                                color: Colors.black,
                                child: RTCVideoView(
                                  _remoteVideoRenderer,
                                  mirror: true,
                                  filterQuality: FilterQuality.medium,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                ),
                              )
                            ],
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SizedBox(
                                height: 180,
                                width: 120,
                                child: RTCVideoView(
                                  _localRenderer,
                                  mirror: true,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isIncoming
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  radius: 30,
                                  child: IconButton(
                                      icon: const Icon(Icons.call),
                                      color: Colors.white,
                                      onPressed: () {
                                        logWarning(widget.jsep);
                                        _localRenderer
                                            .initialize()
                                            .then((value) {
                                          context
                                              .read<CallBloc>()
                                              .add(CallInitMediaEvent());
                                          setState(() {
                                            isIncoming = false;
                                          });
                                        });
                                      })),
                            )
                          : const SizedBox(
                              width: 0,
                              height: 0,
                            ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircleAvatar(
                            backgroundColor: Colors.red,
                            radius: 30,
                            child: IconButton(
                                icon: const Icon(Icons.call_end),
                                color: Colors.white,
                                onPressed: () {
                                  context
                                      .read<CallBloc>()
                                      .add(CallHangupEvent());
                                })),
                      ),
                      isIncoming
                          ? const SizedBox(
                              width: 0,
                              height: 0,
                            )
                          : Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  radius: 30,
                                  child: IconButton(
                                      icon: const Icon(
                                          Icons.flip_camera_android_sharp),
                                      color: Colors.white,
                                      onPressed: () async {
                                        context.read<CallBloc>().add(
                                            CallRotateCameraEvent(
                                                front: !front));
                                        setState(() {
                                          front = !front;
                                        });
                                      })),
                            ),
                    ],
                  ),
                )
              ]),
            ));
  }
}
