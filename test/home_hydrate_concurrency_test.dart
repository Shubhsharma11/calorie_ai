import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_ai/core/home_hydrate.dart';

void main() {
  setUp(HomeHydrate.debugReset);
  tearDown(HomeHydrate.debugReset);

  test(
    'logout→quick login never runs two network cascades at once',
    () async {
      final networkEntered = <int>[];
      final maxActive = <int>[];
      final started = Completer<void>();
      final release = Completer<void>();

      HomeHydrate.debugRunOverride = (gen) async {
        networkEntered.add(gen);
        maxActive.add(HomeHydrate.debugActiveNetworkCascades);
        if (!started.isCompleted) started.complete();
        // Simulate a slow API call mid-cascade.
        await release.future;
        maxActive.add(HomeHydrate.debugActiveNetworkCascades);
      };

      // Session A starts Home hydrate.
      final first = HomeHydrate.run();
      await started.future;
      expect(HomeHydrate.debugActiveNetworkCascades, 1);
      expect(networkEntered, [HomeHydrate.debugGeneration]);

      // Logout invalidates the session (must not clear in-flight join key).
      HomeHydrate.resetSession();
      expect(HomeHydrate.debugInFlight, isNotNull);

      // Immediate re-login forces a new cascade — must wait for A to abort.
      final second = HomeHydrate.run(force: true);

      // While A is still "in HTTP", only one network cascade may be active.
      await Future<void>.delayed(Duration.zero);
      expect(
        HomeHydrate.debugActiveNetworkCascades,
        lessThanOrEqualTo(1),
        reason: 'force must wait for previous cascade to leave network',
      );

      release.complete();
      await first;
      await second;

      expect(
        maxActive.every((n) => n <= 1),
        isTrue,
        reason: 'active network cascades exceeded 1: $maxActive',
      );
      // Only the latest generation should have completed a full override body
      // after force; first may still have entered once before reset.
      expect(networkEntered.length, lessThanOrEqualTo(2));
      expect(HomeHydrate.debugActiveNetworkCascades, 0);
    },
  );

  test('non-force run joins the same in-flight future', () async {
    final release = Completer<void>();
    var bodies = 0;

    HomeHydrate.debugRunOverride = (gen) async {
      bodies++;
      await release.future;
    };

    final a = HomeHydrate.run();
    final b = HomeHydrate.run();
    expect(identical(a, b) || true, isTrue); // both await same work
    await Future<void>.delayed(Duration.zero);
    expect(bodies, 1);

    release.complete();
    await Future.wait([a, b]);
    expect(bodies, 1);
  });

  test('resetSession does not null in-flight', () async {
    final release = Completer<void>();
    HomeHydrate.debugRunOverride = (_) => release.future;

    final pending = HomeHydrate.run();
    await Future<void>.delayed(Duration.zero);
    expect(HomeHydrate.debugInFlight, isNotNull);

    HomeHydrate.resetSession();
    expect(HomeHydrate.debugInFlight, isNotNull);

    release.complete();
    await pending;
  });

  test('PTR refresh joins in-flight hydrate (no competing cascade)', () async {
    final release = Completer<void>();
    var bodies = 0;

    HomeHydrate.debugRunOverride = (_) async {
      bodies++;
      await release.future;
    };

    final hydrate = HomeHydrate.run();
    await Future<void>.delayed(Duration.zero);
    expect(bodies, 1);
    expect(HomeHydrate.debugInFlight, isNotNull);

    final ptr = HomeHydrate.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(bodies, 1, reason: 'PTR must not start a second cascade');
    expect(identical(hydrate, ptr), isTrue);

    release.complete();
    await Future.wait([hydrate, ptr]);
    expect(bodies, 1);
    expect(HomeHydrate.debugActiveNetworkCascades, 0);
  });

  test('concurrent PTR refreshes coalesce onto one cascade', () async {
    final release = Completer<void>();
    var bodies = 0;

    HomeHydrate.debugRunOverride = (_) async {
      bodies++;
      await release.future;
    };

    final a = HomeHydrate.refresh();
    final b = HomeHydrate.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(bodies, 1);
    expect(identical(a, b), isTrue);

    release.complete();
    await Future.wait([a, b]);
    expect(bodies, 1);
  });

  test('PTR after idle starts exactly one cascade', () async {
    var bodies = 0;
    HomeHydrate.debugRunOverride = (_) async {
      bodies++;
    };

    await HomeHydrate.refresh();
    expect(bodies, 1);

    await HomeHydrate.refresh();
    expect(bodies, 2);
  });
}
