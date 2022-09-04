import 'package:get_it/get_it.dart';
import 'package:tablet_janus/presentation/bloc/call/call_bloc.dart';
import 'package:tablet_janus/presentation/bloc/janus/janus_bloc.dart';
import 'package:tablet_janus/presentation/bloc/login/login_bloc.dart';

final sl = GetIt.instance;

setupDependency(){
    sl.registerSingleton<JanusBloc>(JanusBloc());
    sl.registerSingleton<LoginBloc>(LoginBloc());
    sl.registerSingleton<CallBloc>(CallBloc());
}