import 'package:flutter/material.dart';

/// A premium, cohesive color palette inspired by deep coastal marine tones.
/// Designed for high-contrast dark UIs with crisp, clean utility systems.
class AppColors {
  AppColors._(); // Prevents instantiation

  // ===========================================================================
  // Master Brand Identifiers
  // ===========================================================================
  /// Deep Teal Canvas used for dominant brand surfaces and backgrounds.
  static const Color brandPrimary = Color(0xFF102A30);
  
  /// Pale Ice White used for clean, high-contrast light pages or typography.
  static const Color appBackground = Color(0xFFF0F5F5);

  // ===========================================================================
  // Dashboard 60/30/10 Palette (High-Contrast Sea Slate System)
  // ===========================================================================
  /// 60% Dominant: Dark Abyss background for primary dashboard views.
  static const Color dashboardCanvas = Color(0xFF0A1D21); 
  
  /// 30% Structural: Subdued Sea Slate color to elevate cards and containers.
  static const Color dashboardCard = Color(0xFF1B3F47); 
  
  /// 10% Typography: Soft Marine layout text optimized for secondary reading.
  static const Color dashboardText = Color(0xFFE1ECEE); 
  
  /// 10% Focal Point: Warm Butterscotch highlight for CTAs and interactive states.
  static const Color dashboardAccent = Color(0xFFF4C47C); 

  // ===========================================================================
  // Revenue System (Clean, Positive Coastal Greens)
  // ===========================================================================
  /// Crisp Mint Green for positive actions, success metrics, and gains.
  static const Color revenue = Color(0xFF2DD4BF); 
  
  /// Deep Teal-Green tailored specifically for text overlay on light alerts.
  static const Color revenueDark = Color(0xFF0F766E); 
  
  /// Very soft, pale sage tint ideal for alert/chip background containers.
  static const Color revenueSoft = Color(0xFFCCFBF1); 
  
  /// Solid chart color calibrated for data visualizations and bars.
  static const Color revenueBar = Color(0xFF14B8A6); 

  // ===========================================================================
  // Expense System (Urgent, Clean Warm Terracottas)
  // ===========================================================================
  /// Coral-Red calibrated to signal errors, expenses, or negative trends cleanly.
  static const Color expense = Color(0xFFFB7185); 
  
  /// Deep Maroon-Crimson for highly legible text inside light rose alerts.
  static const Color expenseDark = Color(0xFF9F1239); 
  
  /// Light, washed-out blush tint for background alert containers.
  static const Color expenseSoft = Color(0xFFFFE4E6); 
  
  /// Solid coral chart color optimized for clear data visual plotting.
  static const Color expenseBar = Color(0xFFF43F5E); 
  
  /// Dark accent red for critical, high-level structural reports.
  static const Color expenseReport = Color(0xFFBE123C); 

  // ===========================================================================
  // Net Status Gradients (Linear Interpolation Matched)
  // ===========================================================================
  /// Start color for positive trend gradients.
  static const Color netPositiveStart = Color(0xFF0D9488); 
  
  /// End color for positive trend gradients.
  static const Color netPositiveEnd = Color(0xFF99F6E4); 
  
  /// Start color for negative trend gradients.
  static const Color netNegativeStart = Color(0xFFFDA4AF); 
  
  /// End color for negative trend gradients.
  static const Color netNegativeEnd = Color(0xFFFFE4E6); 

  // ===========================================================================
  // Component UI Cards & Indicators
  // ===========================================================================
  /// Pale sea-spray tint for upcoming schedule card surfaces.
  static const Color upcomingCard = Color(0xFFE0F2FE); 
  
  /// Soft ice-blue base color for placeholder avatars and icons.
  static const Color upcomingAvatar = Color(0xFFBAE6FD); 
  
  /// Translucent green-tinted success pill for completed milestones.
  static const Color upcomingIndicator = Color(0xFFD1FAE5); 
  
  /// Flat, neutral slate-gray pill color for past transaction histories.
  static const Color historyIndicator = Color(0xFFE2E8F0); 
  
  /// Balanced, dark mid-tone navy-gray for universal timeline icons.
  static const Color historyIcon = Color(0xFF334155); 

  // ===========================================================================
  // Universal Typography System
  // ===========================================================================
  /// Ultra-dark deep charcoal navy for supreme body text legibility on light screens.
  static const Color textStrong = Color(0xFF0F172A); 
}
