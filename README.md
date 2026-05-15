# 🍳 Reciplease (formerly PantryPal)
**Cook What You Have.**

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/reciplease-cook-what-you-have/id6758684271)

Reciplease is an intelligent iOS application that helps you minimize food waste and maximize your culinary creativity. By keeping track of what’s in your pantry, Reciplease generates delicious recipes tailored strictly to the ingredients you already own. Say goodbye to the dreaded "what's for dinner?" question and hello to effortless, smart meal planning.

## ✨ Features
* **Pantry Management:** Easily add and manage the ingredients you currently have at home.
* **AI Recipe Generation:** Generate custom recipes based on your exact pantry inventory.
* **Smart Meal Planning:** Automatically generate meal plans covering breakfast, lunch, dinner, snacks, and dessert.
* **Cookbook & Web Scanning:** Digitize your physical cookbooks using the camera or import recipes directly from web URLs.
* **Nutrition Estimates:** Automatically estimate the nutritional value of your meals.
* **Shopping Lists:** Seamlessly convert meal plans and individual recipes into consolidated grocery lists.

## 🛠️ Tech Stack
* **Language:** Swift 6
* **UI Framework:** SwiftUI
* **Architecture:** MVVM
* **In-App Purchases:** RevenueCat (Reciplease Pro)
* **Backend Integration:** Custom REST APIs (Recipe Generation, Image Generation, Nutrition)
* **Security & Auth:** Firebase App Check, Keychain for secure storage

## 🚀 Setup & Installation

To run this project locally, you will need to provide your own configuration files, as sensitive keys are purposely omitted from this repository.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/Reciplease.git
   cd Reciplease
   ```

2. **Configure Environments:**
   Create the following files in the root directory (they are ignored by `.gitignore`):
   
   * `EnvProd.plist` and `EnvSandbox.plist` containing your API bases and RevenueCat keys:
     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
         <key>RECIPE_API_BASE_URL</key>
         <string>https://your-api-url.com/</string>
         <key>RECIPLEASE_API_BASE_URL</key>
         <string>https://your-api-url.com/</string>
         <key>REVENUECAT_API_KEY</key>
         <string>your_revenuecat_api_key</string>
         <key>MAX_SCAN_PHOTOS</key>
         <string>4</string>
         <key>TRIAL_MAX_INTERACTIONS</key>
         <string>5</string>
         <key>PRO_MAX_INTERACTIONS</key>
         <string>100</string>
         <key>USAGE_LIMITS_ENABLED</key>
         <string>true</string>
     </dict>
     </plist>
     ```

3. **Configure Firebase:**
   Add your `GoogleService-Info.plist` to the `PantryPal/` directory.

4. **Open & Build:**
   Open `PantryPal.xcodeproj` in Xcode 16+. Select your development team and hit `Cmd + R` to run on the simulator or your physical device.

## 📱 App Architecture Highlights
* **Services:** Handles all external integrations (`RecipeAPIService`, `RevenueCatService`, `TipOfDayService`).
* **ViewModels:** Drives the views (`PantryViewModel` handles the core ingredient interactions).
* **Views:** Built entirely in SwiftUI, featuring interactive carousels, floating action buttons, and beautiful transition animations.
* **Helpers:** Custom UI components, standardized buttons, and specific visual treatments (e.g. `GIFView`, `EnhancedLoadingView`).

## 📄 License
All rights reserved. This source code is provided for portfolio viewing purposes. No license is granted for commercial reproduction.
