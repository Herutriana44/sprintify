# Plan: Optimisasi Alur Recording → Assessment

## Context
**Permintaan User**: "Jika rekaman sudah selesai, langsung masuk ke penilaian atau assesmen"

**Keputusan**: Tidak perlu perubahan alur — flow saat ini sudah memenuhi requirement.

---

## Current End-to-End Flow (Verified ✓)

```
/test-prep 
  → Select athlete + mode
  → "Lanjut ke rekaman"
    ↓
/recording (RecordingScreen)
  → Rekam video (auto-start/stop via pose detection)
  → Press "Selesai & Analisis"
    ↓
[Loading Dialog] (masih di RecordingScreen)
  → Collect bersedia/berlari scores
  → Create PendingAnalysis object
  → Save to state
    ↓
/processing (ProcessingScreen) ← **ASSESSMENT SCREEN**
  → Pipeline Step 1: Read recording data
  → Pipeline Step 2: Calculate scores (avg bersedia/berlari)
  → Pipeline Step 3: Gemini AI analysis (10 best frames)
  → Pipeline Step 4: Generate recommendations
    ↓
/result (ResultScreen)
  → Display final scores + AI analysis
  → Options: Back to dashboard / Copy JSON / View detailed analysis
```

---

## Why Current Flow is Already Optimal ✓

1. **Direct transition**: RecordingScreen._finish() langsung trigger loading → navigate /processing
   - File: `lib/screens/recording_screen.dart:673-730`
   - No intermediate steps needed

2. **ProcessingScreen IS the assessment screen**:
   - Shows real-time pipeline progress (4 steps with animations)
   - Displays logs + spinner while processing
   - Automatic transition to /result when complete
   - File: `lib/screens/processing_screen.dart`

3. **Orphaned screen already exists**: AssessmentWaitingScreen (unused)
   - Imported but never wired in router
   - ProcessingScreen serves this purpose better (more detailed progress)
   - File: `lib/screens/assessment_waiting_screen.dart` — can keep as reference

---

## Files Involved (No Changes Needed)
- `lib/screens/recording_screen.dart` — ._finish() already optimal
- `lib/screens/processing_screen.dart` — assessment pipeline running
- `lib/models/pending_analysis.dart` — data model between screens
- `lib/providers/t_smart_state.dart` — state management (setPendingAnalysis)
- `lib/router/app_router.dart` — routing already configured

---

## Verification Checklist ✓
- [x] User says flow is correct ("Tidak ubah")
- [x] Recording → Loading → Assessment (ProcessingScreen) flow confirmed
- [x] Assessment shows real-time progress (not orphaned)
- [x] No code changes needed

---

## Conclusion
✓ **Flow requirement is met.** Recording completion triggers immediate assessment without extra steps.
