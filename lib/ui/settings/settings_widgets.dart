import 'package:flutter/material.dart';

import '../../core/config/design_tokens.dart';

/// A titled group of setting tiles, drawn as a soft card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: DesignTokens.accent,
                fontFamily: DesignTokens.fontDisplay,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// A labeled slider row.
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.valueLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: DesignTokens.ink)),
              Text(
                valueLabel ?? value.toStringAsFixed(2),
                style: const TextStyle(
                  color: DesignTokens.dim,
                  fontFamily: DesignTokens.fontMono,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A labeled on/off row with an optional subtitle.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: DesignTokens.ink)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: DesignTokens.dim)),
      value: value,
      activeTrackColor: DesignTokens.accent,
      onChanged: onChanged,
    );
  }
}

/// A labeled single-line text field that commits on submit. `obscure` hides the
/// value (API keys) with a reveal toggle.
class SettingsTextTile extends StatefulWidget {
  const SettingsTextTile({
    super.key,
    required this.label,
    required this.value,
    required this.onSubmitted,
    this.obscure = false,
    this.hint,
  });

  final String label;
  final String value;
  final ValueChanged<String> onSubmitted;
  final bool obscure;
  final String? hint;

  @override
  State<SettingsTextTile> createState() => _SettingsTextTileState();
}

class _SettingsTextTileState extends State<SettingsTextTile> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  late bool _hidden = widget.obscure;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _controller,
        obscureText: _hidden,
        style: const TextStyle(color: DesignTokens.ink),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: const TextStyle(color: DesignTokens.dim),
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _hidden ? Icons.visibility : Icons.visibility_off,
                    color: DesignTokens.dim,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
