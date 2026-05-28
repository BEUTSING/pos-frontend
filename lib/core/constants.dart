// ─────────────────────────────────────────────────────────────────────────────
// FILE: constants.dart
// PURPOSE: App-wide constants — colors, API URL, SharedPreferences keys, theme
//
// This file is imported everywhere in the app.
// If you need to change the color scheme or the API URL, this is the place.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLORS — Green theme for the restaurant POS
// Color(0xFF...) format: 0xFF + 6-digit hex code
// ─────────────────────────────────────────────────────────────────────────────
const Color kPrimary        = Color(0xFF2E7D32); // main dark green
const Color kPrimaryLight   = Color(0xFF4CAF50); // lighter green (accents)
const Color kPrimaryDark    = Color(0xFF1B5E20); // very dark green (sidebar)
const Color kAccent         = Color(0xFF66BB6A); // soft green highlight
const Color kSidebarBg      = Color(0xFF1B5E20); // sidebar background
const Color kSidebarHeader  = Color(0xFF154518); // sidebar top section
const Color kTopbarBg       = Color(0xFF212121); // top navigation bar (dark)
const Color kBackground     = Color(0xFFF5F5F5); // page background (light grey)
const Color kCardBg         = Colors.white;       // card / panel background
const Color kTextPrimary    = Color(0xFF212121); // main text color (near black)
const Color kTextSecondary  = Color(0xFF757575); // secondary / hint text (grey)
const Color kBorderColor    = Color(0xFFE0E0E0); // input field borders
const Color kErrorColor     = Color(0xFFD32F2F); // errors and delete actions (red)
const Color kSuccessColor   = Color(0xFF388E3C); // success messages (green)
const Color kWarningColor   = Color(0xFFF57C00); // warnings (orange)
const Color kInfoColor      = Color(0xFF1976D2); // info / edit actions (blue)

// ─────────────────────────────────────────────────────────────────────────────
// API BASE URL
//
// ⚠️  IMPORTANT — choose the right URL for your platform:
//
//  Flutter WEB (Chrome browser)
//    → NEVER use "localhost" on web — Chrome blocks it
//    → Find your machine's local IP:
//        Windows  →  open CMD → type: ipconfig  → look for "IPv4 Address"
//        Mac/Linux → open Terminal → type: ifconfig → look for "inet 192.168…"
//    → Example: 'http://192.168.1.45:8000/api/v1'
//
//  Android Emulator
//    → 'http://10.0.2.2:8000/api/v1'
//      (10.0.2.2 is the emulator's alias for your computer's localhost)
//
//  Android physical device / iOS physical device
//    → same IP as Flutter Web example above
//    → Example: 'http://192.168.1.45:8000/api/v1'
//
//  iOS Simulator
//    → 'http://localhost:8000/api/v1'
//
// ── CHANGE THIS LINE ────────────────────────────────────────────────────────
const String kBaseUrl = 'http://127.0.0.1:8000/api/v1';
//                               ↑ Replace with your actual local IP address

// ─────────────────────────────────────────────────────────────────────────────
// SHARED PREFERENCES KEYS
// SharedPreferences = local key-value storage on the device (like cookies)
// We use it to save the JWT token and user info between app sessions
// ─────────────────────────────────────────────────────────────────────────────
const String kTokenKey    = 'jwt_token';   // the JWT received after login
const String kUserName    = 'userName';    // logged-in user's display name
const String kUserEmail   = 'userEmail';   // logged-in user's email
const String kUserRole    = 'userRole';    // role label (e.g. 'Manager')
const String kCompanyId   = 'companyId';   // ID of the user's restaurant
const String kCompanyName = 'companyName'; // name of the user's restaurant

// ─────────────────────────────────────────────────────────────────────────────
// APP THEME
// ThemeData tells Flutter how every widget should look by default
// Instead of styling each button/input individually, we define defaults here
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true, // use Material Design 3 (latest version)

    // colorScheme: base color palette derived from kPrimary green
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary:   kPrimary,
      secondary: kAccent,
      error:     kErrorColor,
      surface:   kBackground, // 'surface' replaces deprecated 'background'
    ),

    scaffoldBackgroundColor: kBackground, // default page background

    fontFamily: 'Roboto', // default font for the whole app

    // ── AppBar (top navigation bar) ──────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: kTopbarBg,      // dark background
      foregroundColor: Colors.white,   // white icons and text
      elevation: 0,                    // no shadow
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // ── Card (white panels with rounded corners) ─────────────────────────
    cardTheme: CardThemeData(
      color:       kCardBg,           // white background
      elevation:   2,                 // subtle shadow
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ),

    // ── ElevatedButton (main action buttons) ─────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,       // green background
        foregroundColor: Colors.white,   // white text / icons
        elevation:       0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // ── InputDecoration (text fields / form inputs) ───────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled:      true,
      fillColor:   Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      // Default border (not focused, no error)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      // Border when the field is not focused
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      // Border when the field is focused (green + thicker)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      // Border when there is a validation error (red)
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kErrorColor),
      ),
      // Border when focused AND there is a validation error
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kErrorColor, width: 2),
      ),

      // Text styles inside the input
      labelStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
      // errorStyle controls the red validation message BELOW the field
      // Without this, it might appear inside the label area — that was the bug
      errorStyle:  const TextStyle(color: kErrorColor, fontSize: 12, height: 1.2),
      hintStyle:   const TextStyle(color: kTextSecondary, fontSize: 14),
    ),
  );
}