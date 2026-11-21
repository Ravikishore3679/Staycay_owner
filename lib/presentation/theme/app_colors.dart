import 'package:flutter/material.dart';

/// Shared colors for the light, high-contrast guest-house registry UI.
class AppColors {
  AppColors._(); // Prevents instantiation

  // ===========================================================================
  // Master Brand Identifiers
  // ===========================================================================
  /// Deep teal used for primary actions and branded controls.
  static const Color brandPrimary = Color(0xFF102A30);
  
  /// Soft, cool-white canvas used behind cards and page content.
  static const Color appBackground = Color(0xFFF0F5F5);

  // ===========================================================================
  // Dashboard 60/30/10 Palette (High-Contrast Sea Slate System)
  // ===========================================================================
  /// Light canvas retained for older screen references.
  static const Color dashboardCanvas = appBackground;
  
  /// White card surface retained for older screen references.
  static const Color dashboardCard = Color(0xFFFFFFFF);
  
  /// High-contrast text retained for older screen references.
  static const Color dashboardText = textStrong;
  
  /// Soft teal highlight retained for older screen references.
  static const Color dashboardAccent = Color(0xFFD8EEE8);

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
  static const Color revenueBar = Color.fromARGB(255, 28, 211, 22); 

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
