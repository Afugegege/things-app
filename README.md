# MyNote

**A minimalist, glass-morphic LifeOS for managing notes, tasks, and expenses.**

MyNote is designed to be your personal dashboard for life, combining efficiency with a premium, aesthetic user experience. Built with a focus on "Glass Minimalist" design principles, it offers a clutter-free environment to organize your thoughts and day-to-day activities.

## Features

- **Glass-Morphic Design**: A stunning, modern UI featuring frosted glass effects and dynamic backgrounds.
- **Quilted Grid Layout**: A flexible and visually appealing dashboard layout for your widgets and content.
- **Multi-Select Functionality**: Efficiently manage your notes and tasks with intuitive multi-select controls.
- **Audio & Podcasting**: Integrated audio features powered by `just_audio` for recording thoughts or listening to content.
- **Secure & Cloud-Synced**: Built with Supabase for reliable data syncing and authentication.

## Tech Stack

- **Framework**: Flutter & Dart
- **State Management**: Provider
- **Backend**: Supabase (`supabase_flutter`)
- **Visualization**: `fl_chart` for beautiful data representation
- **Audio**: `just_audio`
- **UI Components**: `flutter_staggered_grid_view`, `glass_kit` (custom implementation)

## UI Showcase

Nothing tells the story better than seeing it in action.

_(Add your screenshots or GIFs here. You can drag and drop images into the `assets` folder and link them here, or use an external image host.)_

> **Tip**: Capturing a GIF of the dashboard interactions or the Quilted Grid transition will really make this section pop!

## Getting Started

This project is a Flutter application.

### Prerequisites

- Flutter SDK (Latest Stable)
- Dart SDK

### Installation

1.  **Clone the repository**

    ```bash
    git clone https://github.com/yourusername/mynote.git
    cd mynote
    ```

2.  **Environment Setup**
    - Create a `.env` file in the root directory.
    - Add your Supabase URL and Anon Key:
      ```env
      SUPABASE_URL=your_supabase_url
      SUPABASE_ANON_KEY=your_supabase_anon_key
      ```
    - _Note: The `.env` file is git-ignored for security._

3.  **Install Dependencies**

    ```bash
    flutter pub get
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## Resources

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
