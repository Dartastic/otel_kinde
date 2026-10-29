// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_kinde/otel_kinde.dart';

/// Traces Kinde calls with OpenTelemetry.
///
/// `otel_kinde` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Kinde call in
/// [tracedKinde]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'kinde-example');

  // Wraps a Kinde API call in a CLIENT span.
  final kindeId = await tracedKinde<String>(
    operation: 'organizations.create',
    subdomain: 'example',
    invoke: () async {
      // Make the Kinde call here, then report what it returned.
      const id = 'kinde_8f3a2c';
      return const KindeCallResult(
          value: id,
          result: KindeResult(
              userId: 'user_8f3a2c',
              organizationCode: 'org_code',
              billingPlan: 'example',
              permissionsCsv: 'example',
              featureFlagsHit: 'example',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedKinde organizations.create returned $kindeId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutKindeInstrumentationAsync.
  await runWithoutKindeInstrumentationAsync(
    () => tracedKinde<String>(
      operation: 'organizations.create',
      subdomain: 'example',
      invoke: () async {
        const id = 'kinde_8f3a2c';
        return const KindeCallResult(
            value: id,
            result: KindeResult(
                userId: 'user_8f3a2c',
                organizationCode: 'org_code',
                billingPlan: 'example',
                permissionsCsv: 'example',
                featureFlagsHit: 'example',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
