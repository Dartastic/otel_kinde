// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_kinde/otel_kinde.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_kinde-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('oauth.token records org + plan + feature flags', () async {
    await tracedKinde<String>(
      operation: 'oauth.token',
      subdomain: 'acme',
      invoke: () async => const KindeCallResult(
        value: 'ok',
        result: KindeResult(
          userId: 'usr-1',
          organizationCode: 'org_abc',
          billingPlan: 'team',
          permissionsCsv: 'read:projects,write:projects',
          featureFlagsHit: 'beta_ui,ai_assistant',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('kinde oauth.token')!);
    expect(a['kinde.subdomain'], 'acme');
    expect(a['kinde.organization.code'], 'org_abc');
    expect(a['kinde.billing.plan'], 'team');
    expect(a['kinde.feature_flags'], 'beta_ui,ai_assistant');
  });

  test('suppression skips spans', () async {
    await runWithoutKindeInstrumentationAsync(() async {
      await tracedKinde<String>(
        operation: 'oauth.token',
        invoke: () async => const KindeCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('kinde '), isEmpty);
  });
}
