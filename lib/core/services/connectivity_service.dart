import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityState { wifi, mobile, none }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectivityState>.broadcast();

  Stream<ConnectivityState> get connectivityStream => _controller.stream;

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen(_updateState);
  }

  Future<ConnectivityState> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return _mapResultsToState(results);
  }

  void _updateState(List<ConnectivityResult> results) {
    _controller.add(_mapResultsToState(results));
  }

  ConnectivityState _mapResultsToState(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) {
      return ConnectivityState.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return ConnectivityState.mobile;
    } else {
      return ConnectivityState.none;
    }
  }

  void dispose() {
    _controller.close();
  }
}
