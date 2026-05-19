/// mDNS service discovery — finds running grod daemons on the LAN by
/// browsing `_grod._tcp.local.` and resolving each PTR record to an IP + port.
///
/// Used by Settings screen to populate host/port without manual entry.
library;

import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

/// A grod daemon found via mDNS.
class DiscoveredServer {
  final String host;
  final int port;
  final String name;
  final bool pinRequired;
  final String version;

  const DiscoveredServer({
    required this.host,
    required this.port,
    required this.name,
    required this.pinRequired,
    required this.version,
  });
}

/// Browse the LAN for grod daemons. Resolves PTR → SRV → A and TXT.
/// Returns once `timeout` elapses or no new records arrive.
///
/// `timeout` should be ≥3s — mDNS responses are bursty and some daemons
/// take a couple of seconds to respond.
Future<List<DiscoveredServer>> discoverServers({
  Duration timeout = const Duration(seconds: 4),
}) async {
  const serviceType = '_grod._tcp.local';
  final client = MDnsClient();
  final results = <DiscoveredServer>[];

  await client.start();
  try {
    final ptrStream = client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(serviceType),
      timeout: timeout,
    );

    await for (final ptr in ptrStream) {
      // Resolve SRV (host:port) for this PTR
      final srvStream = client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
        timeout: timeout,
      );

      await for (final srv in srvStream) {
        // Resolve A record (IP) for the SRV target
        final ipStream = client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
          timeout: timeout,
        );

        String? host;
        await for (final ip in ipStream) {
          host = ip.address.address;
          break; // take first IPv4 hit
        }

        if (host == null) continue;

        // Resolve TXT for metadata
        bool pinRequired = false;
        String version = '';
        final txtStream = client.lookup<TxtResourceRecord>(
          ResourceRecordQuery.text(ptr.domainName),
          timeout: timeout,
        );
        await for (final txt in txtStream) {
          // TXT bodies look like ["pin=0", "version=0.2.4"]
          for (final entry in txt.text.split('\n')) {
            final parts = entry.split('=');
            if (parts.length != 2) continue;
            if (parts[0] == 'pin') pinRequired = parts[1] == '1';
            if (parts[0] == 'version') version = parts[1];
          }
          break;
        }

        // De-duplicate by host:port
        final already = results.any(
          (s) => s.host == host && s.port == srv.port,
        );
        if (!already) {
          results.add(DiscoveredServer(
            host: host,
            port: srv.port,
            name: ptr.domainName.replaceAll('.$serviceType', ''),
            pinRequired: pinRequired,
            version: version,
          ));
        }
      }
    }
  } finally {
    client.stop();
  }

  return results;
}
