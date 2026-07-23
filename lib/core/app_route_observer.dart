import 'package:flutter/material.dart';

/// Shared observer so [MainView] can freeze tabs while another route (e.g.
/// Settings) is on top — theme toggles then skip rebuilding Home/Profile.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
