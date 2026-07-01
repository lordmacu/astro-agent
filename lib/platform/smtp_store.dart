import 'package:shared_preferences/shared_preferences.dart';

/// Email account settings for the send_email (SMTP) and read_email (IMAP) tools.
/// One account: the same username/password drive both. Generic — works with
/// Gmail (smtp 587 / imap 993 + an app password), Outlook, or a private server.
class SmtpConfig {
  // Defaults to Gmail, so the user only fills in their address + app password.
  const SmtpConfig({
    this.host = 'smtp.gmail.com',
    this.port = 587,
    this.username = '',
    this.password = '',
    this.fromName = '',
    this.imapHost = 'imap.gmail.com',
    this.imapPort = 993,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String fromName;
  final String imapHost;
  final int imapPort;

  /// True when there's enough to send over SMTP.
  bool get isComplete =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty && port > 0;

  /// True when there's enough to read over IMAP.
  bool get canRead =>
      imapHost.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty &&
      imapPort > 0;

  SmtpConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? fromName,
    String? imapHost,
    int? imapPort,
  }) => SmtpConfig(
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
    fromName: fromName ?? this.fromName,
    imapHost: imapHost ?? this.imapHost,
    imapPort: imapPort ?? this.imapPort,
  );
}

/// Persists [SmtpConfig] in SharedPreferences (same store as the other
/// secrets). The password lives on-device only, like the LLM key.
class SmtpStore {
  const SmtpStore();

  static const _host = 'smtp_host';
  static const _port = 'smtp_port';
  static const _user = 'smtp_user';
  static const _pass = 'smtp_pass';
  static const _from = 'smtp_from';
  static const _imapHost = 'imap_host';
  static const _imapPort = 'imap_port';

  Future<SmtpConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SmtpConfig(
      host: prefs.getString(_host) ?? 'smtp.gmail.com',
      port: prefs.getInt(_port) ?? 587,
      username: prefs.getString(_user) ?? '',
      password: prefs.getString(_pass) ?? '',
      fromName: prefs.getString(_from) ?? '',
      imapHost: prefs.getString(_imapHost) ?? 'imap.gmail.com',
      imapPort: prefs.getInt(_imapPort) ?? 993,
    );
  }

  Future<void> save(SmtpConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_host, config.host);
    await prefs.setInt(_port, config.port);
    await prefs.setString(_user, config.username);
    await prefs.setString(_pass, config.password);
    await prefs.setString(_from, config.fromName);
    await prefs.setString(_imapHost, config.imapHost);
    await prefs.setInt(_imapPort, config.imapPort);
  }
}
