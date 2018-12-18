/// Singleton class for storing
class Data {
  static final Data _singleton = Data._internal();

  factory Data() {
    return _singleton;
  }

  Data._internal();

  /// Store reload listeners
  List<Map<String, Function>> reloadListeners = List<Map<String, Function>>();
}
