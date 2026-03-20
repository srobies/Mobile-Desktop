abstract class SessionApi {
  Future<void> reportCapabilities(Map<String, dynamic> capabilities);
  Future<List<Map<String, dynamic>>> getSessions();

  Future<void> sendPlayStateCommand(
    String sessionId,
    String command, {
    int? seekPositionTicks,
  });

  Future<void> sendMessage(
    String sessionId,
    String text, {
    String? header,
    int? timeoutMs,
  });

  Future<void> sendGeneralCommand(
    String sessionId,
    String commandName, {
    Map<String, String>? arguments,
  });
}
