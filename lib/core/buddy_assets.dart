/// Gender-aware Buddy mascot asset paths.
abstract final class BuddyAssets {
  static bool usesFemaleBuddy(String? gender) {
    final g = gender?.trim().toLowerCase() ?? '';
    return g == 'female';
  }

  static String waveHello(String? gender) => usesFemaleBuddy(gender)
      ? 'assets/image/buddy/buddy_female_wave_hello.png'
      : 'assets/image/buddy/buddy_wave_hello.png';

  static String giftPose(String? gender, BuddyGiftPose pose) {
    final female = usesFemaleBuddy(gender);
    return switch (pose) {
      BuddyGiftPose.shaker => female
          ? 'assets/image/buddy/buddy_female_with_shaker.png'
          : 'assets/image/buddy/buddy_with_shaker.png',
      BuddyGiftPose.tshirt => female
          ? 'assets/image/buddy/buddy_female_with_tshirt.png'
          : 'assets/image/buddy/buddy_with_tshirt.png',
      BuddyGiftPose.cap => female
          ? 'assets/image/buddy/buddy_female_with_cap.png'
          : 'assets/image/buddy/buddy_with_cap.png',
      BuddyGiftPose.bottle => female
          ? 'assets/image/buddy/buddy_female_with_bottle.png'
          : 'assets/image/buddy/buddy_with_bottle.png',
      BuddyGiftPose.stickers => female
          ? 'assets/image/buddy/buddy_female_with_stickers.png'
          : 'assets/image/buddy/buddy_with_stickers.png',
      BuddyGiftPose.hoodie => female
          ? 'assets/image/buddy/buddy_female_with_hoodie.png'
          : 'assets/image/buddy/buddy_with_hoodie.png',
    };
  }
}

enum BuddyGiftPose { shaker, tshirt, cap, bottle, stickers, hoodie }
