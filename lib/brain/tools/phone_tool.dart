import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import 'astro_tool.dart';

/// Places calls and sends messages (WhatsApp or SMS). Contact resolution and the
/// call/message effects are injected, so the tool is decoupled from the device
/// plugins and testable. Mutating — placing a call reaches the outside world, so
/// the brain gates it behind a voice confirmation.
class PhoneTool extends AstroTool {
  PhoneTool({
    required Future<String?> Function(String name) resolveContact,
    required Future<bool> Function(String number) call,
    required Future<bool> Function(String number, String text, bool viaWhatsApp)
    message,
    AppLang Function() lang = _defaultLang,
  }) : _resolve = resolveContact,
       _call = call,
       _message = message,
       _lang = lang;

  static AppLang _defaultLang() => AppLang.es;

  final Future<String?> Function(String name) _resolve;
  final Future<bool> Function(String number) _call;
  final Future<bool> Function(String number, String text, bool viaWhatsApp)
  _message;
  final AppLang Function() _lang;

  @override
  bool get mutates => true;

  @override
  String get name => 'phone';

  @override
  String get description =>
      'Call someone or send them a message. action "call" dials the contact; '
      'action "message" opens WhatsApp (or SMS) with the text ready. "contact" '
      'is a saved name or a phone number.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['call', 'message'],
      },
      'contact': {
        'type': 'string',
        'description': 'Saved contact name (e.g. "mamá") or a phone number.',
      },
      'text': {'type': 'string', 'description': 'For "message": what to say.'},
      'channel': {
        'type': 'string',
        'enum': ['whatsapp', 'sms'],
        'description': 'For "message": defaults to whatsapp.',
      },
    },
    'required': ['action', 'contact'],
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final action = (args['action'] as String?)?.trim().toLowerCase() ?? '';
    final contact = (args['contact'] as String?)?.trim() ?? '';
    if (contact.isEmpty) return const ToolResult.error('contact is empty');

    // The UI may resolve the contact and inject the exact number (with [contact]
    // set to the real contact name) — use it directly so we dial the right
    // person and report their real name.
    final injected = (args['number'] as String?)?.trim();
    final number = (injected != null && injected.isNotEmpty)
        ? injected
        : await _numberFor(contact);
    if (number == null || number.isEmpty) {
      return ToolResult(Strings.contactNotFound(contact, _lang()));
    }

    switch (action) {
      case 'call':
        final ok = await _call(number);
        return ok
            ? ToolResult(Strings.callingNow(contact, _lang()))
            : ToolResult(Strings.callFailed(_lang()));
      case 'message':
        final text = (args['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) return const ToolResult.error('text is empty');
        final viaWhatsApp =
            (args['channel'] as String?)?.trim().toLowerCase() != 'sms';
        final ok = await _message(number, text, viaWhatsApp);
        return ok
            ? ToolResult(Strings.messageReady(contact, _lang()))
            : ToolResult(Strings.messageOpenFailed(_lang()));
      default:
        return ToolResult.error('unknown action: "$action"');
    }
  }

  /// A raw phone number passes through; anything else is looked up by name.
  Future<String?> _numberFor(String contact) {
    final looksLikeNumber = RegExp(
      r'^[+0-9][0-9\s\-()]{4,}$',
    ).hasMatch(contact);
    if (looksLikeNumber) {
      return Future.value(contact.replaceAll(RegExp(r'[\s\-()]'), ''));
    }
    return _resolve(contact);
  }
}
