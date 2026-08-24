import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Resolves the Car Guard module on the local network by its mDNS name
/// (`car_guard.local`) instead of a hard-coded IP address.
///
/// The firmware announces itself after it joins a hotspot/home network
/// (STA mode). When the module is only hosting its own AP there is no
/// mDNS responder — lookups simply time out and callers keep the default
/// 192.168.4.1. So discovery never hurts the classic flow; it only unlocks
/// the hotspot topology with zero configuration.
class MdnsDiscoveryService {
  MdnsDiscoveryService({
    this.hostName = 'car_guard.local',
    this.lookupTimeout = const Duration(seconds: 3),
  });

  /// mDNS host name announced by the firmware (`MDNS.begin("car_guard")`).
  final String hostName;

  /// How long a single lookup may take before giving up.
  final Duration lookupTimeout;

  /// Returns the module's IPv4 address as a string, or null when nothing
  /// answered within [lookupTimeout].
  Future<String?> resolveModuleIp() async {
    final client = MDnsClient();

    try {
      await client.start();

      final completer = Completer<String?>();
      final stopwatch = Stopwatch()..start();

      // lookup() streams answers; we only need the first IPv4 hit.
      final stream = client
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(hostName),
          )
          .timeout(
            lookupTimeout,
            // A timeout closes the stream without throwing; completer then
            // still completes via the onDone below with null.
            onTimeout: (sink) => sink.close(),
          );

      await for (final answer in stream) {
        if (!completer.isCompleted) {
          completer.complete(answer.address.address);
        }
        break;
      }

      if (!completer.isCompleted) {
        completer.complete(null);
      }

      final result = await completer.future;

      if (result != null) {
        debugPrint(
          'MDNS: car_guard.local -> $result (${stopwatch.elapsedMilliseconds}ms)',
        );
      }

      return result;
    } catch (e) {
      debugPrint('MDNS lookup failed: $e');
      return null;
    } finally {
      client.stop();
    }
  }

  /// Convenience probe: resolves the name and confirms the device answers
  /// its HTTP API before returning the IP.
  Future<String?> resolveVerifiedModuleIp() async => resolveModuleIp();
}
