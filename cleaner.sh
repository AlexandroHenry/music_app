#!/bin/bash

echo "🧹 Cleaning Flutter project..."
flutter clean

echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

echo ""
echo "🍎 Installing iOS pods..."
cd ios
pod install
cd ..

echo ""
echo "🤖 Cleaning Android..."
cd android
./gradlew clean
cd ..

echo ""
echo "🚀 Running Flutter app..."
flutter run