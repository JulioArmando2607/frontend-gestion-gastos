class Environment {
  static const String serverIP =
      //   "192.168.1.4"; // Cambia esta IP por la de tu servidor backend
      //"161.132.54.249";
      "192.168.1.2";

  static Map<String, dynamic> toJson() {
    return {"serverIP": serverIP};
  }
}
