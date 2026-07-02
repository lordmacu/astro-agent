import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/llm_models.dart';

/// A free model offered by the Kilo gateway, as shown in the model picker.
class KiloModel {
  const KiloModel({required this.id, required this.name});

  final String id;
  final String name;
}

/// Kilo's public models endpoint. No authentication required.
const String kKiloModelsEndpoint = 'https://api.kilo.ai/api/gateway/models';

/// Tool-capable free models known at build time. Used as a fallback when the
/// live list can't be fetched (offline, first paint, tests). The live list from
/// [fetchKiloFreeModels] supersedes it whenever available.
const List<KiloModel> kSeedFreeModels = [
  KiloModel(
    id: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
    name: 'NVIDIA Nemotron 3 Nano',
  ),
  KiloModel(id: 'poolside/laguna-m.1:free', name: 'Poolside Laguna M.1'),
  KiloModel(id: 'poolside/laguna-xs.2:free', name: 'Poolside Laguna XS.2'),
  KiloModel(id: 'stepfun/step-3.7-flash:free', name: 'StepFun Step 3.7 Flash'),
  KiloModel(id: 'cohere/north-mini-code:free', name: 'Cohere North Mini Code'),
];

/// Parse Kilo's `/models` response, keeping only free (`:free`) models that
/// support tool use — Astro is agentic, so a model without `tools` is useless
/// to it (e.g. the content-safety classifier is dropped). Pure, so it can be
/// unit-tested without a network call. Returns models sorted by display name.
List<KiloModel> parseKiloFreeModels(String body) {
  final decoded = jsonDecode(body);
  final list = decoded is Map<String, dynamic>
      ? (decoded['data'] as List? ?? const [])
      : (decoded is List ? decoded : const []);

  final out = <KiloModel>[];
  for (final raw in list) {
    if (raw is! Map<String, dynamic>) continue;
    final id = (raw['id'] as String?)?.trim() ?? '';
    if (!isFreeModel(id)) continue;
    final params =
        (raw['supported_parameters'] as List?)?.whereType<String>().toSet() ??
        const <String>{};
    // Needs function calling to drive Astro's tools.
    if (!params.contains('tools') && !params.contains('tool_choice')) continue;
    final name = (raw['name'] as String?)?.trim();
    out.add(KiloModel(id: id, name: name?.isNotEmpty == true ? name! : id));
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// Fetch the live tool-capable free-model list from Kilo (no auth). Falls back
/// to [kSeedFreeModels] on any network/parse error or empty result, so the
/// picker always has options.
Future<List<KiloModel>> fetchKiloFreeModels({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final resp = await c
        .get(Uri.parse(kKiloModelsEndpoint))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode >= 400) return kSeedFreeModels;
    final parsed = parseKiloFreeModels(resp.body);
    return parsed.isEmpty ? kSeedFreeModels : parsed;
  } catch (_) {
    return kSeedFreeModels;
  } finally {
    if (client == null) c.close();
  }
}

/// Live list of tool-capable free Kilo models for the model picker. Auto-caches
/// for the provider's lifetime; falls back to the seed list on failure.
final kiloFreeModelsProvider = FutureProvider<List<KiloModel>>(
  (ref) => fetchKiloFreeModels(),
);
