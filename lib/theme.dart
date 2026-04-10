import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// COLOR & DESIGN HELPERS
// =============================================================================

/// Gold accent tokens for Disney-esque sparkle elements
class AppColors {
  static const gold = Color(0xFFE8B84B);
  static const goldSurface = Color(0xFFFDF3D7);
  static const goldOnSurface = Color(0xFF6B4A00);
  static const goldDark = Color(0xFFF5CC6A);
  static const goldSurfaceDark = Color(0xFF3D2E00);
}

/// Predefined shadow sets for consistent elevation and depth
class AppShadows {
  /// Subtle ambient card lift — replaces zero-elevation look
  static const List<BoxShadow> cardFloat = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Stronger glow for hero elements (stat card, key CTA)
  static const List<BoxShadow> cardLift = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Primary-colored glow for CTA buttons
  static List<BoxShadow> primaryGlow(Color primary) => [
    BoxShadow(color: primary.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6)),
  ];
}

/// Gradient presets for atmospheric page backgrounds and hero sections
class AppGradients {
  /// Page-level atmospheric gradient (very subtle, nearly imperceptible)
  static const pageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF9F4), Color(0xFFFFFBF8)],
  );

  /// Shell / full-page canvas — **must** follow [ColorScheme]. A fixed light gradient
  /// under dark [ThemeData] made the UI look like two themes stacked.
  static LinearGradient pageBackgroundFor(ColorScheme cs) {
    if (cs.brightness == Brightness.dark) {
      final bottom = cs.surface;
      final top = Color.alphaBlend(cs.primary.withValues(alpha: 0.10), bottom);
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      );
    }
    return pageBackground;
  }

  /// Primary-tinted hero card gradient (for TripHeader, WelcomePage hero)
  static LinearGradient heroCard(Color primary) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary.withValues(alpha: 0.10), primary.withValues(alpha: 0.04)],
  );

  /// Gold shimmer gradient for sparkle badge
  static const goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDF3D7), Color(0xFFF5E0A0)],
  );
}

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

/// Shared layout constants.
///
/// The app is designed primarily for phones, but Dreamflow previews can be wide.
/// Constraining the content keeps alignment consistent and avoids awkward
/// “stretched” rows.
class AppLayout {
  static const double maxContentWidth = 560;
  static const EdgeInsets pagePadding = AppSpacing.paddingMd;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// App-specific surface helpers.
///
/// Many of the app's “cards” are implemented as `Container + BoxDecoration`
/// rather than Flutter's `Card` widget.
///
/// In light mode we want a slightly-solid tinted fill (not translucent), so
/// borders remain visible against the bright background.
///
/// Light: maps to [ColorScheme.surfaceContainer] / Low / High (distinct ladder).
/// Dark: translucent elevated surfaces.
extension AppSurfaceColors on ColorScheme {
  /// Default background for card-like containers.
  Color get appCardBackground =>
      brightness == Brightness.light ? surfaceContainer : surfaceContainerHighest.withValues(alpha: 0.35);

  /// Slightly stronger background for emphasis sections (still subtle).
  Color get appCardBackgroundStrong =>
      brightness == Brightness.light ? surfaceContainerHigh : surfaceContainerHighest.withValues(alpha: 0.40);

  /// Softer / inset background for secondary rows (list tiles, etc.).
  Color get appCardBackgroundSubtle =>
      brightness == Brightness.light ? surfaceContainerLow : surfaceContainerHighest.withValues(alpha: 0.30);
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

/// Modern, neutral color palette for light mode
/// Uses soft grays and blues instead of purple for a contemporary look
class LightModeColors {
  // Whimsical pastel palette (unofficial Disney-esque)
  static const lightPrimary = Color(0xFF7B5CE6); // lilac
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFE9E2FF);
  static const lightOnPrimaryContainer = Color(0xFF2A1C63);

  // Secondary: mint
  static const lightSecondary = Color(0xFF2F9E90);
  static const lightOnSecondary = Color(0xFFFFFFFF);

  // Tertiary: peach
  static const lightTertiary = Color(0xFFE58A72);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Error colors
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);

  // Surface and background: warm scaffold vs cooler “sheet” surfaces for contrast
  static const lightOnSurface = Color(0xFF1B1B1F);
  /// Warm canvas (scaffold + page gradient end) — distinct from [lightSurface].
  static const lightBackground = Color(0xFFFFFBF8);
  /// App bars, nav bar, icon wells — slightly cooler than background so chips read as separate sheets.
  static const lightSurface = Color(0xFFFCFAFE);
  static const lightSurfaceVariant = Color(0xFFF2EEF8);
  static const lightOnSurfaceVariant = Color(0xFF4A4653);

  /// M3-style ladder: subtle (inset) → default card → strong emphasis — all distinct in light mode.
  static const lightCardSurfaceSubtle = Color(0xFFF6F1FC);
  static const lightCardSurface = Color(0xFFF1ECFF);
  static const lightCardSurfaceStrong = Color(0xFFEAE4FA);

  // Outline and shadow
  static const lightOutline = Color(0xFF7C7688);
  static const lightShadow = Color(0xFF000000);
  static const lightInversePrimary = Color(0xFFD2C8FF);
}

/// Dark mode colors with good contrast
class DarkModeColors {
  static const darkPrimary = Color(0xFFD2C8FF);
  static const darkOnPrimary = Color(0xFF2A1C63);
  static const darkPrimaryContainer = Color(0xFF3F2E88);
  static const darkOnPrimaryContainer = Color(0xFFE9E2FF);

  static const darkSecondary = Color(0xFF7FE3D8);
  static const darkOnSecondary = Color(0xFF003833);

  static const darkTertiary = Color(0xFFFFB9A7);
  static const darkOnTertiary = Color(0xFF5A1809);

  // Error colors
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  static const darkSurface = Color(0xFF14131A);
  static const darkOnSurface = Color(0xFFF1EFFA);
  static const darkSurfaceVariant = Color(0xFF3B3748);
  static const darkOnSurfaceVariant = Color(0xFFCAC6D8);

  // Outline and shadow
  static const darkOutline = Color(0xFF8F899E);
  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = Color(0xFF7B5CE6);
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with modern, neutral aesthetic
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  splashFactory: InkSparkle.splashFactory,
  highlightColor: Colors.transparent,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerLowest: LightModeColors.lightBackground,
    surfaceContainerLow: LightModeColors.lightCardSurfaceSubtle,
    surfaceContainer: LightModeColors.lightCardSurface,
    surfaceContainerHigh: LightModeColors.lightCardSurfaceStrong,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  // Avoid default pure-white canvas showing through gaps; matches page warmth.
  canvasColor: LightModeColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: LightModeColors.lightCardSurface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: LightModeColors.lightOutline.withValues(alpha: 0.38),
        width: 1,
      ),
    ),
  ),
  dividerTheme: DividerThemeData(
    space: 24,
    thickness: 1,
    color: LightModeColors.lightOutline.withValues(alpha: 0.16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      elevation: 4,
      shadowColor: LightModeColors.lightPrimary.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.28), width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.55),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.26))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.22))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 1.2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 68,
    backgroundColor: LightModeColors.lightSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    indicatorColor: LightModeColors.lightPrimaryContainer,
    indicatorShape: const StadiumBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? LightModeColors.lightPrimary : LightModeColors.lightOnSurface.withValues(alpha: 0.60),
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      return IconThemeData(
        color: states.contains(WidgetState.selected)
            ? LightModeColors.lightPrimary
            : LightModeColors.lightOnSurface.withValues(alpha: 0.50),
      );
    }),
  ),
  textTheme: _buildTextTheme(Brightness.light).apply(
    bodyColor: LightModeColors.lightOnSurface,
    displayColor: LightModeColors.lightOnSurface,
  ),
);

/// Dark theme with good contrast and readability
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  splashFactory: InkSparkle.splashFactory,
  highlightColor: Colors.transparent,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  canvasColor: DarkModeColors.darkSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: DarkModeColors.darkOutline.withValues(alpha: 0.20),
        width: 1,
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      elevation: 4,
      shadowColor: DarkModeColors.darkPrimary.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkSurfaceVariant.withValues(alpha: 0.35),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.20))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.16))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: const BorderSide(color: DarkModeColors.darkPrimary, width: 1.2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 68,
    backgroundColor: DarkModeColors.darkSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    indicatorColor: DarkModeColors.darkPrimaryContainer,
    indicatorShape: const StadiumBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? DarkModeColors.darkPrimary : DarkModeColors.darkOnSurface.withValues(alpha: 0.60),
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      return IconThemeData(
        color: states.contains(WidgetState.selected)
            ? DarkModeColors.darkPrimary
            : DarkModeColors.darkOnSurface.withValues(alpha: 0.50),
      );
    }),
  ),
  textTheme: _buildTextTheme(Brightness.dark).apply(
    bodyColor: DarkModeColors.darkOnSurface,
    displayColor: DarkModeColors.darkOnSurface,
  ),
);

/// Build text theme using Playfair Display for headlines + Nunito for body
TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w700,
    ),
    displaySmall: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.nunito(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.nunito(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.nunito(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.nunito(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.nunito(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    bodyLarge: GoogleFonts.nunito(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.nunito(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );
}
