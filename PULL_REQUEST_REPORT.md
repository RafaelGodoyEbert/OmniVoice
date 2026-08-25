# Pull Request Report: Audio Post-Processing Enhancements & Fixes

**Repository:** OmniVoice

### 1. Fix: Truncation of Final Phonemes in Audio Output
**Problem:** The text-to-speech engine was often truncating the last letter/phoneme of quiet words (e.g., saying "test" instead of "teste").
**Root Cause:** The `remove_silence` step was overly aggressive on soft sentence tails, padding them by only 100ms, which were then heavily muted by an unconditional 100ms fade-out, dropping the phonetic tail altogether.
**Modifications:**
- In `omnivoice/utils/audio.py`: Reduced `fade_duration` in the `fade_and_pad_audio` hook from `0.1s` (100ms) down to `0.02` (20ms). This safely prevents clicks without silencing actual speech frames.
- In `omnivoice/models/omnivoice.py`: Increased the `trail_sil` cutoff when executing `remove_silence` from `100` to `200` to give more preservation room for natural sound decays.

### 2. Feature: Pre-Silence Removal Gain Normalization
**Problem:** Extremely quiet generations often fell completely under the `-50 dBFS` silence threshold, risking excessive deletion inside `remove_silence`.
**Solution:** Built an option to safely peak-normalize the raw generation prior to calculating the silence gaps.
**Modifications:**
- Added `normalize_before_silence_removal` to `OmniVoiceGenerationConfig` (defaulting to `False`).
- In `omnivoice/models/omnivoice.py` (`_post_process_audio`): Intercepted the tensor right before `remove_silence`. If enabled, checked the max vector, and peak-normalized it up to a 0.99 threshold.
- In `omnivoice/cli/demo.py`: Integrated the switch functionally natively into the "Generation Settings" accordion UI as a new checkbox feature ("Normalize Before Silence Removal"), propagating it backwards to both Voice Design and Voice Clone endpoints.

### 3. Fix: False-Positive Execution of Post-Processing Actions
**Problem:** Deactivating the "Postprocess Output" switch on the client UI generated seemingly no difference.
**Root Cause:** `fade_and_pad_audio` was executed globally inside `_post_process_audio` regardless of the explicit boolean directive restricting post-processing actions.
**Modifications:**
- In `omnivoice/models/omnivoice.py`: Moved the execution call to `fade_and_pad_audio` successfully into the `if postprocess_output:` boundary block. Disabling post-processing is now genuinely literal and respects the bypass of all end padding/fade artifacts.
### 4. Fix: Poetic Stanza Regression (Newline Collapsing)
**Problem:** Double newlines (used as stanza separators in poems) were being collapsed into a single character by a greedy regex, causing subsequent lines to be mis-chunked and omitted in audio generation.
**Modifications:**
- In `omnivoice/models/omnivoice.py` (`_combine_text`): Updated the newline replacement regex from `r"[ \t]*\r?\n[\s]*"` to `r"[ \t]*\r?\n[ \t]*"`. This prevents the substitution from consuming adjacent `\n` characters (which are included in `\s`), ensuring that stanzas produce distinct dots and maintaining proper text chunking.

### 5. Fix: GPU Out-Of-Memory (OOM) on Long Reference Audio
**Problem:** Attempting to use long reference audio files (>20s) for voice cloning often caused immediate `torch.OutOfMemoryError` on consumer GPUs during the tokenization/caching phase.
**Modifications:**
- In `omnivoice/models/omnivoice.py` (`create_voice_clone_prompt`):
    - Added automatic trimming of long audio (>15s) when no reference text is provided.
    - Implemented a hard 30s limit check when reference text *is* provided, raising a clear `ValueError` instead of crashing.
    - Added proactive logging warnings for audio in the 20s-30s range.

### 6. Enhancement: Robust Audio I/O with Fallback Support
**Problem:** `torchaudio` often fails to load or save specific formats (e.g., MP3/AAC) if exact FFmpeg shared libraries are missing from the system path.
**Modifications:**
- In `omnivoice/utils/audio.py`:
    - `load_audio`: Integrated a fallback path using `pydub`/`ffmpeg` when `torchaudio.load` raises an exception.
    - `save_audio`: Implemented a fallback to `soundfile` for saving audio if `torchaudio.save` fails.

### 7. Fix: Offline Tokenizer Fallback
**Problem:** Model initialization would fail in air-gapped or network-restricted environments if the HuggingFace Hub was unreachable, even if files were cached locally.
**Modifications:**
- In `omnivoice/models/omnivoice.py` (`from_pretrained`): Added a `try-except` block around the initial tokenizer load that retries with `local_files_only=True` upon failure, ensuring offline reliability.
