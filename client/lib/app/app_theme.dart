import "package:flutter/material.dart";

class SlideTransitionPageRoute extends PageRouteBuilder {
  final Widget page;

  SlideTransitionPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(1.0, 0.0);
          var end = Offset.zero;
          var tween = Tween(begin: begin, end: end);
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
      );
}

class BorneoTheme {
  final TextTheme textTheme;

  const BorneoTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff493b72),
      surfaceTint: Color(0xff64568e),
      onPrimary: Color(0xffE3D009),
      primaryContainer: Color(0xff6d5f98),
      onPrimaryContainer: Color(0xFFE3D009),
      secondary: Color(0xff625b73),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffe9dffc),
      onSecondaryContainer: Color(0xff4b455c),
      tertiary: Color(0xff683251),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff915576),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff410002),
      surface: Color(0xfff1ecf2),
      onSurface: Color(0xff1c1b1f),
      onSurfaceVariant: Color(0xff48454f),
      outline: Color(0xff797580),
      outlineVariant: Color(0xffcac4d0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff313034),
      inversePrimary: Color(0xffcebdfd),
      primaryFixed: Color(0xffe8ddff),
      onPrimaryFixed: Color(0xff1f1046),
      primaryFixedDim: Color(0xffcebdfd),
      onPrimaryFixedVariant: Color(0xff4c3e75),
      secondaryFixed: Color(0xffe8defb),
      onSecondaryFixed: Color(0xff1e182d),
      secondaryFixedDim: Color(0xffcbc2de),
      onSecondaryFixedVariant: Color(0xff49435a),
      tertiaryFixed: Color(0xffffd8e9),
      onTertiaryFixed: Color(0xff370826),
      tertiaryFixedDim: Color(0xfffab1d6),
      onTertiaryFixedVariant: Color(0xff6b3453),
      surfaceDim: Color(0xffddd8de),
      surfaceBright: Color(0xfffdf8fd),
      surfaceContainerLow: Color(0xffece6ec),
      surfaceContainerLowest: Color(0xffe6e1e6),
      surfaceContainer: Color(0xfffdf8fd),
      surfaceContainerHighest: Color(0xffffffff),
      surfaceContainerHigh: Color(0xfff7f2f7),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffcebdfd),
      surfaceTint: Color(0xffcebdfd),
      onPrimary: Color(0xff35275c),
      primaryContainer: Color(0xff54467e),
      onPrimaryContainer: Color(0xfff3ebff),
      secondary: Color(0xffcbc2de),
      onSecondary: Color(0xff332d43),
      secondaryContainer: Color(0xff423c53),
      onSecondaryContainer: Color(0xffdad0ed),
      tertiary: Color(0xfffab1d6),
      onTertiary: Color(0xff511e3c),
      tertiaryContainer: Color(0xff753d5c),
      onTertiaryContainer: Color(0xffffeaf1),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff141317),
      onSurface: Color(0xffe6e1e6),
      onSurfaceVariant: Color(0xffcac4d0),
      outline: Color(0xff948f9a),
      outlineVariant: Color(0xff48454f),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe6e1e6),
      inversePrimary: Color(0xff64568e),
      primaryFixed: Color(0xffe8ddff),
      onPrimaryFixed: Color(0xff1f1046),
      primaryFixedDim: Color(0xffcebdfd),
      onPrimaryFixedVariant: Color(0xff4c3e75),
      secondaryFixed: Color(0xffe8defb),
      onSecondaryFixed: Color(0xff1e182d),
      secondaryFixedDim: Color(0xffcbc2de),
      onSecondaryFixedVariant: Color(0xff49435a),
      tertiaryFixed: Color(0xffffd8e9),
      onTertiaryFixed: Color(0xff370826),
      tertiaryFixedDim: Color(0xfffab1d6),
      onTertiaryFixedVariant: Color(0xff6b3453),
      surfaceDim: Color(0xff141317),
      surfaceBright: Color(0xff3a383d),
      surfaceContainerLowest: Color(0xff0f0e11),
      surfaceContainerLow: Color(0xff1c1b1f),
      surfaceContainer: Color(0xff201f23),
      surfaceContainerHigh: Color(0xff2b292d),
      surfaceContainerHighest: Color(0xff363438),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(bodyColor: colorScheme.onSurface, displayColor: colorScheme.onSurface),
    scaffoldBackgroundColor: colorScheme.surface,
    disabledColor: colorScheme.onPrimaryContainer.withAlpha(97),
    canvasColor: colorScheme.surface,
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.outline,
      selectedLabelStyle: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
      unselectedLabelStyle: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 8.0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledForegroundColor: colorScheme.onPrimaryContainer.withAlpha(97),
      ),
    ),
    cardColor: colorScheme.surfaceContainer,
    cardTheme: CardThemeData(color: colorScheme.surfaceContainer),
    dividerColor: colorScheme.onInverseSurface,
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    listTileTheme: ListTileThemeData(tileColor: colorScheme.surfaceContainer),

    // Prefer Material page transitions by default; use Cupertino on iOS
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (var platform in TargetPlatform.values) platform: const FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      },
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
    ),
  );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
