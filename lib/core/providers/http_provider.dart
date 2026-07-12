import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/http_service.dart';

/// Riverpod provider for exposing the HTTP infrastructure service contract.
///
/// Consumers can depend on this provider without coupling to a concrete
/// implementation.
/// TODO: Update this wiring when a concrete HTTP client is introduced.
final httpProvider = Provider<HttpService>((ref) => ref.watch(httpServiceProvider));
