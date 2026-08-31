#!/bin/bash
# Solar Manager - Setup Script
# Run this after cloning the repository

echo "🌞 Solar Manager Setup"
echo "====================="

# 1. Install Flutter dependencies
echo "📦 Installing dependencies..."
flutter pub get

# 2. Generate database code (required for Drift ORM)
echo "🔧 Generating database code..."
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run tests
echo "🧪 Running tests..."
flutter test

# 4. Analyze code
echo "🔍 Analyzing code..."
flutter analyze

echo ""
echo "✅ Setup complete! You can now run:"
echo "   flutter run"
