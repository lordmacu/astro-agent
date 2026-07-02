import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:astro/brain/llm/kilo_models.dart';

void main() {
  String body(List<Map<String, dynamic>> models) =>
      jsonEncode({'data': models});

  test('keeps only free, tool-capable models', () {
    final json = body([
      {
        'id': 'poolside/laguna-m.1:free',
        'name': 'Poolside Laguna M.1',
        'supported_parameters': ['tools', 'tool_choice', 'temperature'],
      },
      {
        // free but no tool support → dropped
        'id': 'nvidia/nemotron-3.5-content-safety:free',
        'name': 'Content Safety',
        'supported_parameters': ['temperature'],
      },
      {
        // paid → dropped even though it supports tools
        'id': 'anthropic/claude-sonnet-4.6',
        'name': 'Claude Sonnet',
        'supported_parameters': ['tools'],
      },
    ]);

    final free = parseKiloFreeModels(json);
    expect(free.map((m) => m.id), ['poolside/laguna-m.1:free']);
  });

  test('accepts tool_choice alone as tool support', () {
    final free = parseKiloFreeModels(
      body([
        {
          'id': 'x/y:free',
          'name': 'Y',
          'supported_parameters': ['tool_choice'],
        },
      ]),
    );
    expect(free.single.id, 'x/y:free');
  });

  test('sorts by display name and falls back to id when name is missing', () {
    final free = parseKiloFreeModels(
      body([
        {
          'id': 'b/zebra:free',
          'name': 'Zebra',
          'supported_parameters': ['tools'],
        },
        {
          'id': 'a/alpha:free',
          'supported_parameters': ['tools'],
        },
      ]),
    );
    expect(free.map((m) => m.name), ['a/alpha:free', 'Zebra']);
  });

  test('empty / no free models yields an empty list', () {
    expect(parseKiloFreeModels(body([])), isEmpty);
  });
}
