part of 'call_bloc.dart';

@immutable
abstract class CallEvent {}

class CallInitEvent extends CallEvent {}

class CallInitMediaEvent extends CallEvent {}

class CallGetVideoRoomEvent extends CallEvent {}

class CallRemoteTrackEvent extends CallEvent {
  final RemoteTrack event;

  CallRemoteTrackEvent({required this.event});
}

class CallInitializedMediaEvent extends CallEvent {
  final JanusVideoCallPlugin videoCallPlugin;

  CallInitializedMediaEvent({required this.videoCallPlugin});
}

class CallRegisterEvent extends CallEvent {
  final String name ;

  CallRegisterEvent({required this.name});
}

class CallTypedMessageEvent extends CallEvent {
  final Object data ;
  final RTCSessionDescription? jsep;

  CallTypedMessageEvent({required this.data, this.jsep});
}

class CallErrorEvent extends CallEvent {
  final JanusError error ;

  CallErrorEvent({required this.error});
}

class CallStartEvent extends CallEvent {
  final RTCSessionDescription? jsep;
  final String name ;

  CallStartEvent({required this.name, this.jsep});
}

class CallAcceptedEvent extends CallEvent {
  final String name ;
  final RTCSessionDescription? jsep;

  CallAcceptedEvent({required this.name, this.jsep});
}

class CallHangupEvent extends CallEvent {
  final RTCSessionDescription? jsep;

  CallHangupEvent({this.jsep});
}

class CallHangupReleasedEvent extends CallEvent {
  CallHangupReleasedEvent();
}

class CallRotateCameraEvent extends CallEvent{
  final bool front;

  CallRotateCameraEvent({required this.front});

}
class CallRotatedCameraEvent extends CallEvent{

}