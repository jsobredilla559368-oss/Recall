# Recall — Study & Review App Design Spec
**Date:** 2026-08-31  
**Approach:** A — Feature-First Modular Architecture  
**Stack:** Flutter + Firebase (Firestore, Auth, Storage) + AI API (PDF/DOCX card generation)

---

## Overview

Recall is a cross-platform study and review app for students, self-learners, and educators. Users import documents (PDF/DOCX) and the app auto-generates MCQ quizzes and flashcard decks using an AI API. Study progress is tracked with streaks, spaced repetition, and a social leaderboard. Decks can be shared publicly or with friends.

---

## Design System — "Premium Ink"

### Color Tokens
| Token | Hex | Usage |
|---|---|---|
| `colorBackground` | `#0D1B2A` | Deep navy — primary background |
| `colorSurface` | `#142232` | Slightly lighter navy — cards/surfaces |
| `colorAccent` | `#00E5C8` | Electric teal — primary CTA, active states |
| `colorAmber` | `#F5A623` | Warm amber — streaks, achievements, #1 rank |
| `colorTextPrimary` | `#F0F4F8` | Off-white — primary text |
| `colorTextMuted` | `#8AA0B8` | Muted blue-grey — labels, subtitles |
| `colorError` | `#FF6B6B` | Soft red — error states |
| `colorSuccess` | `#00C896` | Teal-green — correct answers |

### Typography
- **Display:** `Inter` Bold/ExtraBold — headings, screen titles
- **Body:** `Inter` Regular/Medium — body text, labels, form fields
- **Mono:** `JetBrains Mono` — answer options

### Spacing & Shape
- Border radius: `12px` (cards), `8px` (fields), `50px` (pills/buttons)
- Base spacing unit: `8px` (multiples: 8, 16, 24, 32)
- Elevation: subtle `0 4px 16px rgba(0,0,0,0.3)` shadows on cards

---

## Folder Structure

```
lib/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_typography.dart
│   ├── widgets/
│   │   ├── recall_field.dart       # Dynamic buildField() text input
│   │   ├── recall_button.dart      # Primary/secondary/ghost buttons
│   │   ├── deck_card.dart
│   │   ├── flash_card.dart         # 3D-flip flashcard widget
│   │   ├── mcq_option.dart         # State-aware MCQ answer tile
│   │   └── stat_block.dart
│   ├── services/
│   │   ├── auth_service.dart       # Email + Google auth
│   │   ├── deck_service.dart       # Firestore CRUD for decks/cards
│   │   ├── storage_service.dart    # Firebase Storage (file upload)
│   │   ├── ai_service.dart         # AI API card generation
│   │   └── api_key_service.dart    # Secure env-based API key access
│   └── utils/
│       ├── spaced_repetition.dart  # SM-2 algorithm
│       ├── date_utils.dart         # Streak helpers
│       └── validators.dart         # Form validators
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   └── auth_controller.dart
│   ├── decks/
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── deck_detail_screen.dart
│   │   │   ├── create_deck_screen.dart
│   │   │   └── import_screen.dart
│   │   └── deck_controller.dart
│   ├── study/
│   │   ├── screens/
│   │   │   ├── study_mode_screen.dart
│   │   │   ├── flashcard_session.dart
│   │   │   ├── mcq_session.dart
│   │   │   └── results_screen.dart
│   │   └── study_controller.dart
│   ├── social/
│   │   ├── screens/
│   │   │   ├── explore_screen.dart
│   │   │   └── leaderboard_screen.dart
│   │   └── social_controller.dart
│   └── profile/
│       ├── screens/
│       │   └── profile_screen.dart
│       └── profile_controller.dart
├── firebase_options.dart
└── main.dart
```

---

## State Management

**Provider** — each feature has a `*Controller` (ChangeNotifier) registered via `MultiProvider` at root. Keeps state well-encapsulated without BLoC boilerplate.

---

## Reusable Widget System

### `RecallField` (dynamic form field)
Accepts: `controller`, `label`, `isObscure`, `validator`, `keyboardType`.
Styled from AppTheme tokens — teal border on focus, navy fill, off-white text.

### `RecallButton`
Accepts: `variant` (primary | secondary | ghost), `label`, `onPressed`, optional `icon`.

### `DeckCard`
Accepts: deck data, tap callback, `showShare` toggle. Teal/amber accent corners.

### `FlashCard`
AnimatedContainer 3D flip — front (question) / back (answer). Tap to flip.

### `MCQOption`
States: `idle | selected | correct | incorrect`. Color-coded via AppColors tokens.

---

## Firebase Schema (Firestore)

```
users/{uid}
  displayName, email, photoUrl
  streakCount, lastStudyDate
  totalCardsStudied, accuracy

decks/{deckId}
  title, description, createdBy (uid)
  isPublic, tags[], createdAt, updatedAt
  cards/ (subcollection)
    {cardId}
      question, answer
      type: "flashcard" | "mcq"
      options[] (MCQ only), correctIndex (MCQ only)
      interval, easeFactor, dueDate, repetitions (spaced repetition)

sessions/{sessionId}
  userId, deckId, mode, score, totalCards, accuracy, completedAt

leaderboard/{uid}
  displayName, photoUrl, score, streakCount
```

---

## Firebase Storage

- Path: `uploads/{uid}/{timestamp}-{filename}`
- Supported: `.pdf`, `.docx` — max 10MB
- After upload → AI service receives download URL → returns card JSON

---

## API Key Management

Keys stored in `.env` (gitignored), loaded via `flutter_dotenv`. Accessed via `ApiKeyService.aiKey`. Never hardcoded.

---

## AI Card Generation Flow

1. User picks file → `StorageService.uploadFile()` → download URL
2. `AiService.generateCards(url)` → AI API call
3. AI returns: `[{ question, answer, type, options?, correctIndex? }]`
4. Cards saved to Firestore `decks/{deckId}/cards/`
5. Navigate to `DeckDetailScreen`

---

## Navigation (GoRouter)

```
/splash → /login → /register
/home
/deck/:deckId
/deck/:deckId/study
/deck/create
/deck/import
/explore
/leaderboard
/profile
```

Persistent bottom nav: Home · Explore · Leaderboard · Profile

---

## Spaced Repetition (SM-2)

After each flashcard, user rates recall (0–5). `spaced_repetition.dart` updates `interval`, `easeFactor`, `dueDate` in Firestore. Due cards surfaced prominently on Home.

---

## Screen Inventory (13 MVP Screens)

| # | Screen | Feature |
|---|---|---|
| 1 | Splash | auth |
| 2 | Login | auth |
| 3 | Register | auth |
| 4 | Home | decks |
| 5 | Deck Detail | decks |
| 6 | Import (PDF/DOCX + AI) | decks |
| 7 | Study Mode Select | study |
| 8 | Flashcard Session | study |
| 9 | MCQ Session | study |
| 10 | Results | study |
| 11 | Explore (public decks) | social |
| 12 | Leaderboard | social |
| 13 | Profile | profile |

---

## Key Dependencies

```yaml
dependencies:
  firebase_core, firebase_auth, cloud_firestore, firebase_storage
  google_sign_in
  provider
  go_router
  flutter_dotenv      # API key management
  file_picker         # PDF/DOCX selection
  http                # AI API calls
  google_fonts        # Inter font
  lottie              # Streak / achievement animations
  shared_preferences  # Local caching
```
