import "dart:ui";

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

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
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
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff6d5f98),
      onPrimaryContainer: Color(0xffffffff),
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

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff483a70),
      surfaceTint: Color(0xff64568e),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff6d5f98),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff453f56),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff78718a),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff66304f),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff915576),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff8c0009),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffda342e),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffdf8fd),
      onSurface: Color(0xff1c1b1f),
      onSurfaceVariant: Color(0xff45414b),
      outline: Color(0xff615d67),
      outlineVariant: Color(0xff7d7983),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff313034),
      inversePrimary: Color(0xffcebdfd),
      primaryFixed: Color(0xff7a6ca6),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff61538b),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff78718a),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff5f5870),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff9f6182),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff844969),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffddd8de),
      surfaceBright: Color(0xfffdf8fd),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff7f2f7),
      surfaceContainer: Color(0xfff1ecf2),
      surfaceContainerHigh: Color(0xffece6ec),
      surfaceContainerHighest: Color(0xffe6e1e6),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff26184d),
      surfaceTint: Color(0xff64568e),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff483a70),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff241f34),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff453f56),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff3f0f2d),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff66304f),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff4e0002),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff8c0009),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffdf8fd),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff25232b),
      outline: Color(0xff45414b),
      outlineVariant: Color(0xff45414b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff313034),
      inversePrimary: Color(0xfff1e8ff),
      primaryFixed: Color(0xff483a70),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff312358),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff453f56),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff2f293f),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff66304f),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff4c1a38),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffddd8de),
      surfaceBright: Color(0xfffdf8fd),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff7f2f7),
      surfaceContainer: Color(0xfff1ecf2),
      surfaceContainerHigh: Color(0xffece6ec),
      surfaceContainerHighest: Color(0xffe6e1e6),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
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

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd2c2ff),
      surfaceTint: Color(0xffcebdfd),
      onPrimary: Color(0xff1a0a41),
      primaryContainer: Color(0xff9788c4),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffd0c6e3),
      onSecondary: Color(0xff181327),
      secondaryContainer: Color(0xff958da7),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffffb5da),
      onTertiary: Color(0xff300321),
      tertiaryContainer: Color(0xffbf7c9f),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffbab1),
      onError: Color(0xff370001),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff141317),
      onSurface: Color(0xfffff9ff),
      onSurfaceVariant: Color(0xffcec8d4),
      outline: Color(0xffa6a1ac),
      outlineVariant: Color(0xff86818c),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe6e1e6),
      inversePrimary: Color(0xff4d3f76),
      primaryFixed: Color(0xffe8ddff),
      onPrimaryFixed: Color(0xff15043c),
      primaryFixedDim: Color(0xffcebdfd),
      onPrimaryFixedVariant: Color(0xff3b2d63),
      secondaryFixed: Color(0xffe8defb),
      onSecondaryFixed: Color(0xff130e22),
      secondaryFixedDim: Color(0xffcbc2de),
      onSecondaryFixedVariant: Color(0xff393349),
      tertiaryFixed: Color(0xffffd8e9),
      onTertiaryFixed: Color(0xff2a001b),
      tertiaryFixedDim: Color(0xfffab1d6),
      onTertiaryFixedVariant: Color(0xff582442),
      surfaceDim: Color(0xff141317),
      surfaceBright: Color(0xff3a383d),
      surfaceContainerLowest: Color(0xff0f0e11),
      surfaceContainerLow: Color(0xff1c1b1f),
      surfaceContainer: Color(0xff201f23),
      surfaceContainerHigh: Color(0xff2b292d),
      surfaceContainerHighest: Color(0xff363438),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfffff9ff),
      surfaceTint: Color(0xffcebdfd),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffd2c2ff),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xfffff9ff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffd0c6e3),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xfffff9f9),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffffb5da),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xfffff9f9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffbab1),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff141317),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xfffff9ff),
      outline: Color(0xffcec8d4),
      outlineVariant: Color(0xffcec8d4),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe6e1e6),
      inversePrimary: Color(0xff2e2056),
      primaryFixed: Color(0xffece2ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffd2c2ff),
      onPrimaryFixedVariant: Color(0xff1a0a41),
      secondaryFixed: Color(0xffece2ff),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffd0c6e3),
      onSecondaryFixedVariant: Color(0xff181327),
      tertiaryFixed: Color(0xffffdeec),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffffb5da),
      onTertiaryFixedVariant: Color(0xff300321),
      surfaceDim: Color(0xff141317),
      surfaceBright: Color(0xff3a383d),
      surfaceContainerLowest: Color(0xff0f0e11),
      surfaceContainerLow: Color(0xff1c1b1f),
      surfaceContainer: Color(0xff201f23),
      surfaceContainerHigh: Color(0xff2b292d),
      surfaceContainerHighest: Color(0xff363438),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        textTheme: textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        disabledColor: colorScheme.onPrimaryContainer.withAlpha(97),
        canvasColor: colorScheme.surface,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: colorScheme.surfaceContainerHighest,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.outline,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 8.0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledForegroundColor:
                colorScheme.onPrimaryContainer.withAlpha(97),
          ),
        ),
        cardColor: colorScheme.surfaceContainer,
        cardTheme: CardTheme(
          color: colorScheme.surfaceContainer,
        ),
        dividerColor: colorScheme.onInverseSurface,
        dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
        listTileTheme: ListTileThemeData(
          tileColor: colorScheme.surfaceContainer,
        ),

        // Material page transition is childish
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            for (var platform in TargetPlatform.values)
              platform: const CupertinoPageTransitionsBuilder(),
          },
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
