import 'package:permission_handler/permission_handler.dart';

/// Structural metadata for a brain tool the driver can turn on/off from
/// Settings, plus the single OS permission it needs (if any) so Settings can
/// request it there. The user-facing label/subtitle are localized in `Strings`
/// (keyed by [name]); the permission's human name is localized there too (keyed
/// by [permissionKey]).
///
/// Kept central (keyed by the tool's `name`) instead of on each tool class, so
/// the tool implementations stay decoupled from the UI and a rename is a
/// one-line change here. [name] must match the tool's `AstroTool.name`.
class ToolInfo {
  const ToolInfo({required this.name, this.permission, this.permissionKey});

  /// The tool id, matching `AstroTool.name`. Also the key for its localized
  /// label/subtitle in `Strings.toolLabel` / `Strings.toolSubtitle`.
  final String name;

  /// OS permission the tool needs to work, or null when it needs none.
  final Permission? permission;

  /// Language-neutral key for the permission's human name, localized in
  /// `Strings.permissionName` (e.g. 'camera', 'location'). Null when no
  /// permission is needed.
  final String? permissionKey;
}

/// Core tools that are always on and never shown in the toggle list — Astro's
/// basic behaviour depends on them. `get_context` is the situational awareness
/// (time, speed, location, battery) the model needs on almost every turn.
const Set<String> kCoreTools = {'get_context'};

/// Every toggleable tool, in display order. Tools not listed here (the core set
/// above) are always on.
const List<ToolInfo> kToolCatalog = [
  ToolInfo(name: 'music'),
  ToolInfo(
    name: 'take_photo',
    permission: Permission.camera,
    permissionKey: 'camera',
  ),
  ToolInfo(
    name: 'calendar',
    permission: Permission.calendarWriteOnly,
    permissionKey: 'calendar',
  ),
  ToolInfo(
    name: 'comunicacion',
    permission: Permission.contacts,
    permissionKey: 'contacts',
  ),
  ToolInfo(name: 'device'),
  ToolInfo(
    name: 'mapa',
    permission: Permission.locationWhenInUse,
    permissionKey: 'location',
  ),
  ToolInfo(
    name: 'clima',
    permission: Permission.locationWhenInUse,
    permissionKey: 'location',
  ),
  ToolInfo(name: 'timer'),
  ToolInfo(name: 'phone', permission: Permission.phone, permissionKey: 'phone'),
  ToolInfo(name: 'web_search'),
  ToolInfo(name: 'noticias'),
  ToolInfo(name: 'remember_fact'),
];
