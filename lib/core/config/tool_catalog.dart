import 'package:permission_handler/permission_handler.dart';

/// UI metadata for a brain tool the driver can turn on/off from Settings, plus
/// the single OS permission it needs (if any) so Settings can request it there.
///
/// Kept central (keyed by the tool's `name`) instead of on each tool class, so
/// the tool implementations stay decoupled from the UI and a rename is a
/// one-line change here. [name] must match the tool's `AstroTool.name`.
class ToolInfo {
  const ToolInfo({
    required this.name,
    required this.label,
    required this.subtitle,
    this.permission,
    this.permissionLabel,
  });

  /// The tool id, matching `AstroTool.name`.
  final String name;

  /// Short Spanish label for the toggle.
  final String label;

  /// One line describing what the tool does.
  final String subtitle;

  /// OS permission the tool needs to work, or null when it needs none.
  final Permission? permission;

  /// Human name of that permission, for the "grant" prompt.
  final String? permissionLabel;
}

/// Core tools that are always on and never shown in the toggle list — Astro's
/// basic behaviour depends on them. `get_context` is the situational awareness
/// (time, speed, location, battery) the model needs on almost every turn.
const Set<String> kCoreTools = {'get_context'};

/// Every toggleable tool, in display order. Tools not listed here (the core set
/// above) are always on.
const List<ToolInfo> kToolCatalog = [
  ToolInfo(
    name: 'music',
    label: 'Música',
    subtitle: 'Poner y controlar la música',
  ),
  ToolInfo(
    name: 'take_photo',
    label: 'Cámara',
    subtitle: 'Tomar fotos y guardarlas en la galería',
    permission: Permission.camera,
    permissionLabel: 'cámara',
  ),
  ToolInfo(
    name: 'calendar',
    label: 'Calendario',
    subtitle: 'Crear eventos y recordatorios',
    permission: Permission.calendarWriteOnly,
    permissionLabel: 'calendario',
  ),
  ToolInfo(
    name: 'comunicacion',
    label: 'Comunicación',
    subtitle: 'Correo y notificaciones',
    permission: Permission.contacts,
    permissionLabel: 'contactos',
  ),
  ToolInfo(
    name: 'device',
    label: 'Dispositivo',
    subtitle: 'Brillo, volumen, linterna y abrir apps',
  ),
  ToolInfo(
    name: 'mapa',
    label: 'Mapas',
    subtitle: 'Navegar y buscar lugares cerca',
    permission: Permission.locationWhenInUse,
    permissionLabel: 'ubicación',
  ),
  ToolInfo(
    name: 'clima',
    label: 'Clima',
    subtitle: 'El tiempo de un lugar',
    permission: Permission.locationWhenInUse,
    permissionLabel: 'ubicación',
  ),
  ToolInfo(name: 'timer', label: 'Temporizador', subtitle: 'Timers y alarmas'),
  ToolInfo(
    name: 'phone',
    label: 'Llamadas',
    subtitle: 'Llamar y enviar mensajes',
    permission: Permission.phone,
    permissionLabel: 'teléfono',
  ),
  ToolInfo(
    name: 'web_search',
    label: 'Búsqueda web',
    subtitle: 'Buscar información en internet',
  ),
  ToolInfo(
    name: 'remember_fact',
    label: 'Memoria',
    subtitle: 'Recordar cosas durables entre viajes',
  ),
];
