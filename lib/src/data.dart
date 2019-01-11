/// Singleton class for storing
class Data {
  static final Data _singleton = Data._internal();

  factory Data() {
    return _singleton;
  }

  Data._internal();
}
