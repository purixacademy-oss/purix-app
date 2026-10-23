# Purix Academy

Official Web App for Purix Academy — High-yield board question banks, timed test simulations & core theory notes.

## Overview
Purix Academy is a learning portal designed for Class 8, Class 9, Class 10th, and Board Special cadets to achieve 95%+ board performance. It provides high-yield MCQ practice simulations, theory revision notes, free blueprints, and secure user synchronization.

## Architecture & Tech Stack
- **Framework:** React 18 with TypeScript & Vite
- **Styling:** Tailwind CSS with Purix Academy dark void sci-fi aesthetic (`#070B14`, `#0B111E`, neon cyan `#00F0FF`, neon green `#00FF66`, gold `#D4AF37`)
- **Icons:** Lucide React
- **Data Backend:** Google Apps Script Web App integrated with real Google Sheets
- **Caching:** 12-hour localStorage cache with force-refresh support
- **Session Security:** Live account status verification and background sync

## Core Features
1. **Google & Cadet Verification Login:**
   - 10-digit WhatsApp number verification
   - Unique Purix ID generation (`PRX-XXXXX`)
   - Instant suspension detection (`DEACTIVE` status check)
2. **Standard / Syllabus Selection:**
   - Class 8 (Foundation, Concepts & Practice)
   - Class 9 (Pre-Board Core Concepts & Notes)
   - Class 10th (Board Exam Mastery, High-Yield Qs)
   - Board Special (Target Crash Course, Formulas & Mock Tests with HOT badge)
3. **Core Modules:**
   - `SEC.01` MCQ Test (Timed Simulations broken into 20-question sets)
   - `SEC.02` Practice Sets (Subject question banks)
   - `SEC.03` Purix Notes (Theory documents & chapter blueprints)
   - `SEC.04` Free Matrix (Direct access to all un-gated study resources)
4. **Interactive Quiz Simulation:**
   - Real-time bilingual toggle (`HIN 🇮🇳` / `ENG 🌐`)
   - Instant visual response (Green for correct, Red for incorrect)
   - Detailed answers with `EXPLANATION / समाधान`
   - Evaluation score HUD and completion tracking
5. **PDF Document Viewer:**
   - Google Drive preview mode integration
   - Pinch-to-zoom and direct view options
6. **PRO Pass & Membership:**
   - Pro Pass status detection (`PRO` / `FREE`)
   - UPI integration (`6201161834@ptyes`) with one-click copy
   - WhatsApp verification submission with cadet details
7. **WhatsApp Help Desk:**
   - Floating assistance button connected directly to Purix Academy support

## Development & Build
- `npm run dev`: Starts local Vite dev server on `http://0.0.0.0:3000`
- `npm run build`: Type-checks and builds optimized production bundle
