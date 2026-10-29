// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_kinde_suppression.dart';

const _tracerName = 'dartastic_otel_libs_kinde';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class KindeResult {
  /// Creates a result.
  const KindeResult({
    this.userId,
    this.organizationCode,
    this.billingPlan,
    this.permissionsCsv,
    this.featureFlagsHit,
    this.statusCode,
  });

  final String? userId;

  /// `org_code` from Kinde — Kinde's tenant unit.
  final String? organizationCode;

  /// Kinde supports per-org billing plans; common to gate features
  /// by plan.
  final String? billingPlan;
  final String? permissionsCsv;

  /// Feature flag keys evaluated to true during this call (comma).
  /// Kinde uniquely surfaces feature flags through the auth token.
  final String? featureFlagsHit;
  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class KindeCallResult<T> {
  /// Creates a call result.
  const KindeCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final KindeResult? result;
}

/// Wraps a Kinde API call in a CLIENT span. [operation] is the wire
/// op like `oauth.token`, `organizations.create`, `flags.evaluate`,
/// `permissions.check`.
Future<T> tracedKinde<T>({
  required String operation,
  required Future<KindeCallResult<T>> Function() invoke,
  String? subdomain,
}) async {
  if (kindeInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'kinde',
    'rpc.method': operation,
  };
  if (subdomain != null) m['kinde.subdomain'] = subdomain;

  final span = _tracer().startSpan(
    'kinde $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.userId != null) {
        extras.add(OTelAPI.attributeString('user.id', r.result!.userId!));
      }
      if (r.result!.organizationCode != null) {
        extras.add(OTelAPI.attributeString(
          'kinde.organization.code',
          r.result!.organizationCode!,
        ));
      }
      if (r.result!.billingPlan != null) {
        extras.add(OTelAPI.attributeString(
          'kinde.billing.plan',
          r.result!.billingPlan!,
        ));
      }
      if (r.result!.permissionsCsv != null) {
        extras.add(OTelAPI.attributeString(
          'kinde.permissions',
          r.result!.permissionsCsv!,
        ));
      }
      if (r.result!.featureFlagsHit != null) {
        extras.add(OTelAPI.attributeString(
          'kinde.feature_flags',
          r.result!.featureFlagsHit!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Kinde status ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
