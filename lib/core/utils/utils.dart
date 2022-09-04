import 'package:logger/logger.dart';

var logger = Logger(
  printer: PrettyPrinter(
      methodCount: 0, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: false, // Print an emoji for each log message
      printTime: false // Should each log print contain a timestamp
  ),
);

logInfo(dynamic message){
  logger.i(message);
}
logDebug(dynamic message){
  logger.d(message);
}
logWarning(dynamic message){
  logger.w(message);
}
logFailure(dynamic message){
  logger.wtf(message);
}
logError(dynamic message){
  logger.e(message);
}
logVerbose(dynamic message){
  logger.v(message);
}