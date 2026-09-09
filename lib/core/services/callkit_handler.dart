// lib/core/services/callkit_handler.dart
//
// Deprecated: call handling now lives in background_service.dart and
// main.dart. This class is intentionally left empty to avoid a duplicate
// FlutterCallkitIncoming.onEvent listener, which previously caused
// double-join Agora errors (-17).
class CallKitHandler {
  static final CallKitHandler _instance = CallKitHandler._internal();
  factory CallKitHandler() => _instance;
  CallKitHandler._internal();
}