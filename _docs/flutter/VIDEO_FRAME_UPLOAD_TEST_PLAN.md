# Video Frame Upload Feature - Test Plan

## Overview
This document outlines the test plan for the video frame upload feature that sends extracted frames to the `/upload/video` FastAPI endpoint.

## Test Scenarios

### 1. Normal Video Upload (Happy Path)
**Preconditions:**
- User is logged in
- Video file is available in gallery (10-30 seconds duration)
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a video from gallery (10-30 seconds)
3. Wait for video preview to load
4. Tap "Analyze" button
5. Observe ProcessingScreen showing:
   - "Extracting frames..." with progress indicator
   - Frame count updating (e.g., "15 frames extracted")
   - "Uploading frames..." with progress indicator
   - "Processing..." status
6. Wait for navigation to ResultScreen
7. Verify ResultScreen shows:
   - Aggregated prediction (AI/Human)
   - Confidence percentage
   - Aggregated score
   - Frame count and valid frame count
   - Per-frame predictions list
   - Label distribution

**Expected Result:**
- Video frames are extracted at 1 FPS
- Frames are uploaded to `/upload/video` endpoint
- Aggregated result is displayed correctly
- Per-frame predictions are shown
- Temporary files are cleaned up

---

### 2. Long Video (> 45 seconds)
**Preconditions:**
- User is logged in
- Video file is available (60+ seconds duration)
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a long video from gallery (60+ seconds)
3. Wait for video preview to load
4. Tap "Analyze" button
5. Observe ProcessingScreen showing:
   - "Extracting frames..." with progress indicator
   - Frame count stops at 45 (max limit)
   - "Uploading frames..." with progress indicator
   - "Processing..." status
6. Wait for navigation to ResultScreen
7. Verify ResultScreen shows results for 45 frames

**Expected Result:**
- Only first 45 frames are extracted (45 seconds limit)
- Warning message may be shown about frame limit
- Upload succeeds with 45 frames
- Results are displayed correctly

---

### 3. Very Long Video (> 60 seconds)
**Preconditions:**
- User is logged in
- Video file is available (90+ seconds duration)
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a very long video from gallery (90+ seconds)
3. Wait for video preview to load
4. Tap "Analyze" button
5. Observe ProcessingScreen showing:
   - "Extracting frames..." with progress indicator
   - Frame count stops at 45 (max limit)
   - "Uploading frames..." with progress indicator
   - "Processing..." status
6. Wait for navigation to ResultScreen
7. Verify ResultScreen shows results for 45 frames

**Expected Result:**
- Only first 45 frames are extracted (45 seconds limit)
- Upload succeeds with 45 frames
- Results are displayed correctly

---

### 4. Network Error During Upload
**Preconditions:**
- User is logged in
- Video file is available (10-20 seconds duration)
- Server is NOT accessible (network disabled or server down)

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a video from gallery (10-20 seconds)
3. Wait for video preview to load
4. Disable network connection
5. Tap "Analyze" button
6. Observe ProcessingScreen showing:
   - "Extracting frames..." with progress indicator
   - "Uploading frames..." with progress indicator
   - Error message appears
7. Verify error message is user-friendly

**Expected Result:**
- Frames are extracted successfully
- Upload fails with network error
- User-friendly error message is displayed:
  - "Network error. Please check your internet connection and try again."
- User can retry or go back

---

### 5. Server Error During Upload
**Preconditions:**
- User is logged in
- Video file is available (10-20 seconds duration)
- Server is running but returns error

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a video from gallery (10-20 seconds)
3. Wait for video preview to load
4. Tap "Analyze" button
5. Observe ProcessingScreen showing:
   - "Extracting frames..." with progress indicator
   - "Uploading frames..." with progress indicator
   - Error message appears
6. Verify error message is user-friendly

**Expected Result:**
- Frames are extracted successfully
- Upload fails with server error
- User-friendly error message is displayed
- User can retry or go back

---

### 6. Cancel During Frame Extraction
**Preconditions:**
- User is logged in
- Video file is available (30+ seconds duration)
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a video from gallery (30+ seconds)
3. Wait for video preview to load
4. Tap "Analyze" button
5. Immediately tap "Cancel" button during frame extraction
6. Verify cancellation dialog appears
7. Confirm cancellation
8. Verify user is returned to Media Picker

**Expected Result:**
- Frame extraction is cancelled
- Temporary files are cleaned up
- User is returned to Media Picker
- No crash or error occurs

---

### 7. Cancel During Upload
**Preconditions:**
- User is logged in
- Video file is available (30+ seconds duration)
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a video from gallery (30+ seconds)
3. Wait for video preview to load
4. Tap "Analyze" button
5. Wait for frame extraction to complete
6. Tap "Cancel" button during upload
7. Verify cancellation dialog appears
8. Confirm cancellation
9. Verify user is returned to Media Picker

**Expected Result:**
- Upload is cancelled
- Temporary files are cleaned up
- User is returned to Media Picker
- No crash or error occurs

---

### 8. Video with No Valid Frames
**Preconditions:**
- User is logged in
- Corrupted or invalid video file is available
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a corrupted video file
3. Wait for video preview to load (may fail)
4. Tap "Analyze" button
5. Observe ProcessingScreen showing error
6. Verify error message is user-friendly

**Expected Result:**
- Frame extraction fails
- User-friendly error message is displayed
- User can retry or go back

---

### 9. Image Upload (Existing Functionality)
**Preconditions:**
- User is logged in
- Image file is available in gallery
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select an image from gallery
3. Wait for image preview to load
4. Tap "Analyze" button
5. Observe ProcessingScreen showing upload progress
6. Wait for navigation to ResultScreen
7. Verify ResultScreen shows analysis result

**Expected Result:**
- Image is uploaded to `/upload` endpoint (existing flow)
- Analysis result is displayed correctly
- No frame extraction occurs

---

### 10. Multiple Rapid Uploads
**Preconditions:**
- User is logged in
- Multiple video files are available
- Server is running and accessible

**Steps:**
1. Open the app and navigate to Media Picker
2. Select a video from gallery
3. Tap "Analyze" button
4. Immediately go back and select another video
5. Tap "Analyze" button again
6. Verify both uploads process correctly

**Expected Result:**
- Both videos are processed independently
- No interference between uploads
- Results are displayed correctly for each

---

## Test Data

### Test Videos
1. **Short Video**: 10 seconds, 720p, MP4 format
2. **Medium Video**: 30 seconds, 1080p, MP4 format
3. **Long Video**: 60 seconds, 1080p, MP4 format
4. **Very Long Video**: 90 seconds, 1080p, MP4 format
5. **Corrupted Video**: Invalid MP4 file

### Test Images
1. **Small Image**: 100KB, JPG format
2. **Large Image**: 5MB, PNG format

---

## Success Criteria

### Functional Requirements
- [ ] Video frames are extracted at 1 FPS
- [ ] Maximum 45 frames are extracted (45 seconds limit)
- [ ] Frames are uploaded to `/upload/video` endpoint
- [ ] Aggregated result is displayed correctly
- [ ] Per-frame predictions are shown
- [ ] Label distribution is displayed
- [ ] Temporary files are cleaned up
- [ ] Error messages are user-friendly

### Non-Functional Requirements
- [ ] Frame extraction is fast (< 5 seconds for 45 frames)
- [ ] Upload progress is shown accurately
- [ ] UI remains responsive during processing
- [ ] No memory leaks or crashes
- [ ] Proper error handling for all scenarios

---

## Test Environment

### Android Device
- Android 10+ (API 29+)
- Minimum 2GB RAM
- Internet connection required

### Server
- FastAPI server running on localhost:8000
- `/upload/video` endpoint available
- `/upload` endpoint available (for images)

---

## Test Execution

### Manual Testing
1. Execute each test scenario manually
2. Document any issues found
3. Verify all success criteria are met

### Automated Testing
1. Unit tests for VideoFrameResult model
2. Integration tests for MediaUploadService
3. UI tests for ProcessingScreen and ResultScreen

---

## Issue Tracking

### Known Issues
- None (initial implementation)

### Bug Reports
- Report bugs with detailed steps to reproduce
- Include device information and logs
- Attach screenshots if applicable

---

## Sign-off

### Test Completion
- [ ] All test scenarios executed
- [ ] All success criteria met
- [ ] No critical bugs remaining
- [ ] Documentation updated

### Approval
- [ ] Developer approval
- [ ] QA approval
- [ ] Product owner approval
