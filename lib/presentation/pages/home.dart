import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:janus_client/janus_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:material_color_gen/material_color_gen.dart';
import 'package:tablet_janus/core/utils/utils.dart';

import '../../core/utils/janus_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  late JanusClient j;
  Map<int, RemoteStream> remoteStreams = {};

  late RestJanusTransport rest;
  late WebSocketJanusTransport ws;
  late JanusSession session;
  late JanusVideoRoomPlugin plugin;
  JanusVideoRoomPlugin? remoteHandle;
  late int myId;
  bool front = true;
  int myRoom = 1234;
  Map<int, dynamic> feedStreams = {};
  Map<int?, dynamic> subscriptions = {};
  Map<int, dynamic> feeds = {};
  Map<String, int> subStreams = {};
  Map<int, MediaStream?> mediaStreams = {};

  initialize() async {
    ws = WebSocketJanusTransport(url: dotenv.get('GATEWAY_URL'));
    j = JanusClient(transport: ws, isUnifiedPlan: true, iceServers: [
      RTCIceServer(
          urls: "stun:stun1.l.google.com:19302", username: "", credential: "")
    ]);
    session = await j.createSession();
    plugin = await session.attach<JanusVideoRoomPlugin>();
  }

  subscribeTo(List<Map<String, dynamic>> sources) async {
    if (sources.isEmpty) return;
    var streams = (sources)
        .map((e) => PublisherStream(mid: e['mid'], feed: e['feed']))
        .toList();
    if (remoteHandle != null) {
      await remoteHandle?.subscribeToStreams(streams);
      return;
    }
    remoteHandle = await session.attach<JanusVideoRoomPlugin>();
    logInfo(sources);
    var start = await remoteHandle?.joinSubscriber(myRoom, streams: streams);
    remoteHandle?.typedMessages?.listen((event) async {
      Object data = event.event.plugindata?.data;
      if (data is VideoRoomAttachedEvent) {
        logInfo('Attached event');
        data.streams?.forEach((element) {
          if (element.mid != null && element.feedId != null) {
            subStreams[element.mid!] = element.feedId!;
          }
          // to avoid duplicate subscriptions
          if (subscriptions[element.feedId] == null) {
            subscriptions[element.feedId] = {};
          }
          subscriptions[element.feedId][element.mid] = true;
        });
        logInfo('substreams');
        logInfo(subStreams);
      }
      if (event.jsep != null) {
        await remoteHandle?.handleRemoteJsep(event.jsep);
        await start!();
      }
    }, onError: (error, trace) {
      if (error is JanusError) {
        logInfo(error.toMap());
      }
    });
    remoteHandle?.remoteTrack?.listen((event) async {
      String mid = event.mid!;
      if (subStreams[mid] != null) {
        int feedId = subStreams[mid]!;
        if (!remoteStreams.containsKey(feedId)) {
          RemoteStream temp = RemoteStream(feedId.toString());
          await temp.init();
          setState(() {
            remoteStreams.putIfAbsent(feedId, () => temp);
          });
        }
        if (event.track != null && event.flowing == true) {
          remoteStreams[feedId]?.video.addTrack(event.track!);
          remoteStreams[feedId]?.videoRenderer.srcObject =
              remoteStreams[feedId]?.video;
          if (kIsWeb) {
            remoteStreams[feedId]?.videoRenderer.muted = false;
          }
        }
      }
    });
    return;
  }

  Future<void> joinRoom() async {
    await plugin.initializeMediaDevices();
    RemoteStream mystr = RemoteStream('0');
    await mystr.init();
    mystr.videoRenderer.srcObject = plugin.webRTCHandle!.localStream;
    setState(() {
      remoteStreams.putIfAbsent(0, () => mystr);
    });
    await plugin.joinPublisher(myRoom, displayName: "Shivansh");
    plugin.typedMessages?.listen((event) async {
      Object data = event.event.plugindata?.data;
      if (data is VideoRoomJoinedEvent) {
        (await plugin.publishMedia(bitrate: 3000000));
        List<Map<String, dynamic>> publisherStreams = [];
        for (Publishers publisher in data.publishers ?? []) {
          for (Streams stream in publisher.streams ?? []) {
            feedStreams[publisher.id!] = {
              "id": publisher.id,
              "display": publisher.display,
              "streams": publisher.streams
            };
            publisherStreams.add({"feed": publisher.id, ...stream.toJson()});
            if (publisher.id != null && stream.mid != null) {
              subStreams[stream.mid!] = publisher.id!;
              logInfo("substreams is:");
              logInfo(subStreams);
            }
          }
        }
        subscribeTo(publisherStreams);
      }
      if (data is VideoRoomNewPublisherEvent) {
        List<Map<String, dynamic>> publisherStreams = [];
        for (Publishers publisher in data.publishers ?? []) {
          feedStreams[publisher.id!] = {
            "id": publisher.id,
            "display": publisher.display,
            "streams": publisher.streams
          };
          for (Streams stream in publisher.streams ?? []) {
            publisherStreams.add({"feed": publisher.id, ...stream.toJson()});
            if (publisher.id != null && stream.mid != null) {
              subStreams[stream.mid!] = publisher.id!;
              logInfo("substreams is:");
              logInfo(subStreams);
            }
          }
        }
        logInfo('got new publishers');
        logInfo(publisherStreams);
        subscribeTo(publisherStreams);
      }
      if (data is VideoRoomLeavingEvent) {
        logInfo('publisher is leaving');
        logInfo(data.leaving);
        unSubscribeStream(data.leaving!);
      }
      if (data is VideoRoomConfigured) {
        logInfo('typed event with jsep${event.jsep}');
        await plugin.handleRemoteJsep(event.jsep);
      }
    }, onError: (error, trace) {
      if (error is JanusError) {
        logError(error.toMap());
      }
    });
  }

  Future<void> unSubscribeStream(int id) async {
// Unsubscribe from this publisher
    var feed = feedStreams[id];
    if (feed == null) return;
    feedStreams.remove(id);
    await remoteStreams[id]?.dispose();
    remoteStreams.remove(id);
    MediaStream? streamRemoved = mediaStreams.remove(id);
    streamRemoved?.getTracks().forEach((element) async {
      await element.stop();
    });
    var unsubscribe = {
      "request": "unsubscribe",
      "streams": [
        {feed: id}
      ]
    };
    if (remoteHandle != null) {
      await remoteHandle?.send(data: {"message": unsubscribe});
    }
    subscriptions.remove(id);
  }

  @override
  void dispose() async {
    super.dispose();
    await remoteHandle?.dispose();
    await plugin.dispose();
    session.dispose();
  }

  callEnd() async {
    await plugin.hangup();
    for (int i = 0; i < feedStreams.keys.length; i++) {
      await unSubscribeStream(feedStreams.keys.elementAt(i));
    }
    remoteStreams.forEach((key, value) async {
      value.dispose();
    });
    setState(() {
      remoteStreams = {};
    });
    //subStreams.clear();
    //subscriptions.clear();
    //await plugin.webRTCHandle!.localStream?.dispose();
    //await plugin.dispose();
    //await remoteHandle?.dispose();
  }

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          remoteStreams.entries.isNotEmpty ? Container(
            width: Get.width,
            color: Colors.transparent,
            child: Stack(
              children: [
                Visibility(
                  visible:false,
                  child: RTCVideoView(remoteStreams.entries.where((element) => element.value.id == '0').first.value.audioRenderer,
                    filterQuality: FilterQuality.none,
                    objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    mirror: false),),
                RTCVideoView(remoteStreams.entries.where((element) => element.value.id == '0').first.value.videoRenderer,
                    filterQuality: FilterQuality.none,
                    objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    mirror: true)
              ],
            ),
          ): const SizedBox(width: 0,height: 0,),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                color: Colors.transparent,
                height: 300,
                margin: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
                child: GridView.builder(
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                    itemCount:
                    remoteStreams.entries.where((element) => element.value.id != '0').map((e) => e.value).toList().length,
                    itemBuilder: (context, index) {
                      List<RemoteStream> items =
                      remoteStreams.entries.where((element) => element.value.id != '0').map((e) => e.value).toList();
                      RemoteStream remoteStream = items[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Visibility(
                            visible:false,
                            child: RTCVideoView(remoteStream.audioRenderer,
                                filterQuality: FilterQuality.none,
                                objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                                mirror: true),
                          ),
                          Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                            ),
                            child: RTCVideoView(remoteStream.videoRenderer,
                                filterQuality: FilterQuality.none,
                                objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                mirror: true),
                          )
                        ],
                      );
                    }),
              ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FloatingActionButton(
                          backgroundColor: Colors.green,
                            heroTag: "btn1",
                            child: const Icon(
                              Icons.call,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              await joinRoom();
                            }),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FloatingActionButton(
                            backgroundColor: Colors.red,
                            heroTag: "btn2",
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              await callEnd();
                            }),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FloatingActionButton(
                            heroTag: "btn3",
                            child: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              setState(() {
                                front = !front;
                              });
                              await plugin.switchCamera(
                                  deviceId: await getCameraDeviceId(front));
                              RemoteStream mystr = RemoteStream('0');
                              await mystr.init();
                              mystr.videoRenderer.srcObject =
                                  plugin.webRTCHandle!.localStream;
                              setState(() {
                                remoteStreams.remove(0);
                                remoteStreams[0] = mystr;
                              });
                            }),
                      )
                    ]
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
