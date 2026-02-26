# Sefirot

A Flutter application built with Firebase, Riverpod, and Google Maps.

## Features

- **Authentication**: Secure login using Firebase Authentication and Google Sign-In.
- **State Management**: Robust and scalable state management using Riverpod (`flutter_riverpod`).
- **Database & Storage**: Remote data storage and real-time updates via Cloud Firestore and Firebase Storage.
- **Maps Integration**: Location features and interactive maps using Google Maps Flutter.
- **Interactive UI**: Engaging user interface with customizable swipeable cards (`flutter_card_swiper`).
- **Routing**: Clean and scalable navigation using Go Router.

## Prerequisites

Before you begin, ensure you have met the following requirements:
* You have installed the latest version of the [Flutter SDK](https://docs.flutter.dev/get-started/install).
* You have a code editor installed (e.g., VS Code or Android Studio).
* You have set up a Firebase project and configured the appropriate Firebase platforms (iOS, Android, Web) for this application.

## Getting Started

To get a local copy up and running, follow these simple steps:

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   ```

2. **Navigate to the project directory:**
   ```bash
   cd sefirot
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

## Architecture & Technologies

* **[Flutter](https://flutter.dev/)**: Cross-platform UI Toolkit.
* **[Firebase](https://firebase.google.com/)**: Backend services (Auth, Firestore, Storage).
* **[Riverpod](https://riverpod.dev/)**: Reactive State Management.
* **[Go Router](https://pub.dev/packages/go_router)**: Declarative Routing.
