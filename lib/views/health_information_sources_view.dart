import 'package:flutter/material.dart';

import '../core/open_external_url.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

/// In-app citations for calorie, macro, and wellness estimates.
/// Shown on iOS for App Store Guideline 1.4.1; not surfaced on Android.
class HealthInformationSourcesView extends StatelessWidget {
  const HealthInformationSourcesView({super.key});

  static const _sources = <_HealthSource>[
    _HealthSource(
      title: 'Resting calorie needs (BMR)',
      summary:
          'Daily calorie targets start from resting energy expenditure '
          'estimated with the Mifflin–St Jeor equation, using your age, '
          'sex, height, and weight.',
      links: [
        _SourceLink(
          label: 'Mifflin et al., Am J Clin Nutr (PubMed)',
          url: 'https://pubmed.ncbi.nlm.nih.gov/2305711/',
        ),
        _SourceLink(
          label: 'NIH — Estimating Energy Needs',
          url: 'https://www.ncbi.nlm.nih.gov/books/NBK278991/',
        ),
      ],
    ),
    _HealthSource(
      title: 'Activity & daily calorie needs',
      summary:
          'Activity multipliers adjust resting needs for lifestyle. Guidance '
          'on calories and weight management is informed by U.S. Dietary '
          'Guidelines and NIH public-health resources.',
      links: [
        _SourceLink(
          label: 'Dietary Guidelines for Americans (ODPHP / HHS)',
          url:
              'https://odphp.health.gov/our-work/nutrition-physical-activity/dietary-guidelines/current-dietary-guidelines',
        ),
        _SourceLink(
          label: 'NHLBI — Aim for a Healthy Weight (Calories)',
          url:
              'https://www.nhlbi.nih.gov/health/educational/lose_wt/eat/calories.htm',
        ),
      ],
    ),
    _HealthSource(
      title: 'Weight-change calorie adjustments',
      summary:
          'Estimated calories needed to lose or gain weight use the common '
          'energy-balance approximation that about 7,700 kcal corresponds to '
          'roughly 1 kg of body weight, alongside gradual-pace guidance.',
      links: [
        _SourceLink(
          label: 'NIH / NIDDK — Treatment for Overweight & Obesity',
          url:
              'https://www.niddk.nih.gov/health-information/weight-management/adult-overweight-obesity/treatment',
        ),
        _SourceLink(
          label: 'NIDDK — Healthy Eating & Physical Activity Tips',
          url:
              'https://www.niddk.nih.gov/health-information/weight-management/healthy-eating-physical-activity-for-life/health-tips-for-adults',
        ),
      ],
    ),
    _HealthSource(
      title: 'Macronutrient ranges',
      summary:
          'Carbohydrate, protein, and fat percentage ranges shown in the app '
          'align with Acceptable Macronutrient Distribution Ranges (AMDRs) '
          'described in U.S. dietary reference guidance.',
      links: [
        _SourceLink(
          label: 'NCBI — Acceptable Macronutrient Distribution Range (AMDR)',
          url: 'https://www.ncbi.nlm.nih.gov/books/NBK610333/',
        ),
        _SourceLink(
          label: 'Dietary Guidelines for Americans, 2020–2025 (PMC)',
          url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC8713704/',
        ),
      ],
    ),
    _HealthSource(
      title: 'Exercise calorie estimates',
      summary:
          'Calories burned for activities are estimated using metabolic '
          'equivalent (MET) values from the Compendium of Physical Activities.',
      links: [
        _SourceLink(
          label: 'Compendium of Physical Activities',
          url: 'https://pacompendium.com/',
        ),
        _SourceLink(
          label: 'WHO — Physical activity fact sheet',
          url:
              'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
        ),
      ],
    ),
    _HealthSource(
      title: 'Healthy weight context',
      summary:
          'General healthy-weight framing draws on BMI category definitions '
          'and gradual weight-change recommendations from NHLBI and WHO. '
          'BMI is a population screening tool, not a diagnosis.',
      links: [
        _SourceLink(
          label: 'NHLBI — Body Mass Index Calculator',
          url:
              'https://www.nhlbi.nih.gov/health/educational/lose_wt/BMI/bmicalc.htm',
        ),
        _SourceLink(
          label: 'WHO — Obesity and overweight',
          url:
              'https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar(title: 'Health Information & Sources'),
      body: ResponsivePage(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DisclaimerCard(r: r),
            SizedBox(height: r.scale(20)),
            Text(
              'Scientific sources',
              style: TextStyle(
                fontSize: r.scale(18, tablet: 20),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            SizedBox(height: r.scale(6)),
            Text(
              'Tap any link to open the source. These references support the '
              'estimates and general wellness information shown in MyCaloriePal.',
              style: TextStyle(
                fontSize: r.scale(14),
                height: 1.45,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            SizedBox(height: r.scale(16)),
            for (final source in _sources) ...[
              _SourceCard(source: source, r: r),
              SizedBox(height: r.scale(12)),
            ],
            SizedBox(height: r.scale(8)),
            Text(
              'Food database references',
              style: TextStyle(
                fontSize: r.scale(16),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            SizedBox(height: r.scale(8)),
            _SourceCard(
              source: const _HealthSource(
                title: 'Packaged food nutrition data',
                summary:
                    'Barcode scanning uses Open Food Facts, an open food '
                    'products database. Always verify labels when accuracy '
                    'matters for your health.',
                links: [
                  _SourceLink(
                    label: 'Open Food Facts',
                    url: 'https://world.openfoodfacts.org/',
                  ),
                ],
              ),
              r: r,
            ),
            SizedBox(
              height: MediaQuery.viewPaddingOf(context).bottom + r.scale(24),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.primary,
                size: r.scale(22),
              ),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: Text(
                  'Important disclaimer',
                  style: TextStyle(
                    fontSize: r.scale(16),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(10)),
          Text(
            'MyCaloriePal provides general wellness and nutrition tracking '
            'estimates for informational and educational purposes only. It is '
            'not medical advice, diagnosis, or treatment, and is not a '
            'substitute for professional care.\n\n'
            'Always consult a qualified healthcare provider before changing '
            'your diet, exercise, or medications—especially if you are '
            'pregnant, nursing, or have a medical condition such as diabetes, '
            'high blood pressure, or high cholesterol.',
            style: TextStyle(
              fontSize: r.scale(13.5),
              height: 1.5,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.r});

  final _HealthSource source;
  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.title,
            style: TextStyle(
              fontSize: r.scale(15),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            source.summary,
            style: TextStyle(
              fontSize: r.scale(13.5),
              height: 1.45,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          SizedBox(height: r.scale(10)),
          for (final link in source.links) ...[
            InkWell(
              onTap: () => openExternalUrl(link.url),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: r.scale(6)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: r.scale(16),
                      color: AppColors.primary,
                    ),
                    SizedBox(width: r.scale(8)),
                    Expanded(
                      child: Text(
                        link.label,
                        style: TextStyle(
                          fontSize: r.scale(13.5),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor:
                              AppColors.primary.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthSource {
  const _HealthSource({
    required this.title,
    required this.summary,
    required this.links,
  });

  final String title;
  final String summary;
  final List<_SourceLink> links;
}

class _SourceLink {
  const _SourceLink({required this.label, required this.url});

  final String label;
  final String url;
}
