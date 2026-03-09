class Environment {
  static const String serverIP =
      //   "192.168.1.4"; // Cambia esta IP por la de tu servidor backend
      //     "161.132.54.249";
      "192.168.1.3:8081";
      ///"https://cashlyplus.com";

  static Map<String, dynamic> toJson() {
    return {"serverIP": serverIP};
  }
}
