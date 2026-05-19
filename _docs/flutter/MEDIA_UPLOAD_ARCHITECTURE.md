# Media Upload and Result Retrieval - Architecture Diagrams

## System Architecture Overview

```mermaid
graph TB
    subgraph "UI Layer"
        MP[MediaPickerPage]
        PS[ProcessingScreen]
        MR[MediaResultPage]
    end
    
    subgraph "State Management"
        MUC[MediaUploadController]
    end
    
    subgraph "Services"
        MPS[MediaPickerService]
        MAS[MediaApiService]
    end
    
    subgraph "Models"
        UR[UploadResponse]
        PS_M[ProcessingStatus]
        AR[AnalysisResult]
    end
    
    subgraph "Backend API"
        UP[POST /upload]
        ST[GET /results/{id}/status]
        RES[GET /results/{id}]
    end
    
    MP -->|Pick file| MPS
    MP -->|Upload| MUC
    MUC -->|Upload file| MAS
    MAS -->|Multipart request| UP
    UP -->|Return file_id| MAS
    MAS -->|Poll status| ST
    ST -->|Return status| MAS
    MAS -->|Get result| RES
    RES -->|Return analysis| MAS
    MAS -->|Update state| MUC
    MUC -->|Navigate| PS
    MUC -->|Navigate| MR
    PS -->|Show progress| MUC
    MR -->|Display result| MUC
    
    style MP fill:#e1f5ff
    style PS fill:#fff4e1
    style MR fill:#e8f5e9
    style MUC fill:#f3e5f5
    style MPS fill:#fce4ec
    style MAS fill:#e0f2f1
```

## User Flow Diagram

```mermaid
sequenceDiagram
    participant User
    participant MP as MediaPickerPage
    participant MPS as MediaPickerService
    participant MUC as MediaUploadController
    participant MAS as MediaApiService
    participant API as Backend API
    participant PS as ProcessingScreen
    participant MR as MediaResultPage
    
    User->>MP: Open Upload Page
    User->>MP: Click "Pick Media"
    MP->>MPS: pickMedia()
    MPS-->>MP: Return file path
    
    User->>MP: Click "Upload and Analyze"
    MP->>MUC: uploadAndProcess(filePath, fileType)
    MUC->>PS: Navigate to ProcessingScreen
    
    MUC->>MAS: uploadFile(filePath, fileType)
    MAS->>API: POST /upload (multipart)
    API-->>MAS: Return file_id
    MAS-->>MUC: UploadResponse
    
    loop Poll until complete
        MUC->>MAS: getProcessingStatus(fileId)
        MAS->>API: GET /results/{fileId}/status
        API-->>MAS: Return status
        MAS-->>MUC: ProcessingStatus
        MUC->>PS: Update progress
    end
    
    alt Status = "completed"
        MUC->>MAS: getAnalysisResult(fileId)
        MAS->>API: GET /results/{fileId}
        API-->>MAS: Return analysis
        MAS-->>MUC: AnalysisResult
        MUC->>MR: Navigate to ResultPage
        MR->>User: Display AI/Human label
    else Status = "failed"
        MUC->>PS: Show error message
        PS->>User: Display error with retry
    end
```

## State Management Flow

```mermaid
stateDiagram-v2
    [*] --> Idle
    
    Idle --> Uploading : User clicks upload
    Uploading --> Processing : Upload complete
    Uploading --> Failed : Upload error
    
    Processing --> Completed : Status = completed
    Processing --> Failed : Status = failed
    Processing --> Processing : Poll status
    
    Completed --> Idle : User clicks "Upload New"
    Failed --> Idle : User clicks "Retry"
    Failed --> Idle : User clicks "Cancel"
    
    state Uploading {
        [*] --> SendingFile
        SendingFile --> TrackingProgress
        TrackingProgress --> SendingFile : Progress update
    }
    
    state Processing {
        [*] --> Polling
        Polling --> Waiting : Wait 2s
        Waiting --> Polling : Timeout
    }
```

## Data Flow Diagram

```mermaid
graph LR
    subgraph "Input"
        F[File Path]
        FT[File Type]
    end
    
    subgraph "Validation"
        V1[Size Check<br/>Max 20MB]
        V2[Duration Check<br/>Max 60s]
    end
    
    subgraph "Upload"
        U1[Multipart Request]
        U2[Progress Tracking]
    end
    
    subgraph "Processing"
        P1[Poll Status]
        P2[Get Result]
    end
    
    subgraph "Output"
        O1[Label: AI/Human]
        O2[Confidence: 0.85]
        O3[Probabilities]
    end
    
    F --> V1
    FT --> V2
    V1 --> U1
    V2 --> U1
    U1 --> U2
    U2 --> P1
    P1 --> P2
    P2 --> O1
    P2 --> O2
    P2 --> O3
```

## Component Interaction Diagram

```mermaid
graph TD
    subgraph "MediaPickerPage"
        PB[Pick Button]
        FB[File Preview]
        UB[Upload Button]
    end
    
    subgraph "MediaUploadController"
        US[Upload State]
        UP_C[Upload Progress]
        PS_C[Processing Status]
        FR[File ID]
        AR_C[Analysis Result]
        EM[Error Message]
    end
    
    subgraph "ProcessingScreen"
        PI[Progress Indicator]
        SM[Status Message]
        FP[File Preview]
        CB[Cancel Button]
    end
    
    subgraph "MediaResultPage"
        RC[Result Card]
        CB_C[Confidence Bar]
        PB_P[Probability Bars]
        EB[Error Box]
        AB[Action Buttons]
    end
    
    PB -->|Trigger| US
    FB -->|Display| FP
    UB -->|Start| US
    
    US -->|Update| PI
    UP_C -->|Update| PI
    PS_C -->|Update| SM
    FR -->|Display| FP
    
    US -->|Navigate| RC
    AR_C -->|Display| RC
    AR_C -->|Display| CB_C
    AR_C -->|Display| PB_P
    EM -->|Display| EB
    
    CB -->|Cancel| US
    AB -->|Retry| US
    AB -->|New Upload| PB
```

## Error Handling Flow

```mermaid
graph TD
    Start[Start Upload] --> Check{Check Network}
    Check -->|No Network| Error1[Show Network Error]
    Check -->|Has Network| Upload[Upload File]
    
    Upload --> UploadResult{Upload Result}
    UploadResult -->|Success| Poll[Start Polling]
    UploadResult -->|Timeout| Error2[Show Timeout Error]
    UploadResult -->|Server Error| Error3[Show Server Error]
    UploadResult -->|Network Error| Retry{Retry Count < 3?}
    
    Retry -->|Yes| Upload
    Retry -->|No| Error4[Show Max Retry Error]
    
    Poll --> PollResult{Poll Result}
    PollResult -->|Processing| Wait[Wait 2s]
    Wait --> Poll
    PollResult -->|Completed| Result[Show Result]
    PollResult -->|Failed| Error5[Show Processing Error]
    PollResult -->|Timeout| Error6[Show Poll Timeout]
    
    Error1 --> RetryBtn[Retry Button]
    Error2 --> RetryBtn
    Error3 --> RetryBtn
    Error4 --> RetryBtn
    Error5 --> RetryBtn
    Error6 --> RetryBtn
    
    RetryBtn --> Start
```

## API Communication Flow

```mermaid
graph LR
    subgraph "Flutter App"
        MAS[MediaApiService]
    end
    
    subgraph "FastAPI Backend"
        UP[Upload Endpoint]
        ST[Status Endpoint]
        RES[Result Endpoint]
    end
    
    MAS -->|1. POST /upload<br/>Content-Type: multipart/form-data<br/>Body: file| UP
    UP -->|2. Response<br/>{file_id: 'abc123'}| MAS
    
    MAS -->|3. GET /results/abc123/status| ST
    ST -->|4. Response<br/>{status: 'processing'}| MAS
    
    MAS -->|5. GET /results/abc123/status| ST
    ST -->|6. Response<br/>{status: 'completed'}| MAS
    
    MAS -->|7. GET /results/abc123| RES
    RES -->|8. Response<br/>{label: 'AI', confidence: 0.85}| MAS
```

## File Structure Diagram

```
lib/
├── models/
│   ├── upload_response.dart          ← Upload response model
│   ├── processing_status.dart        ← Processing status model
│   └── analysis_result.dart          ← Analysis result model
│
├── services/
│   ├── media_picker_service.dart     ← Existing (no changes)
│   └── media_api_service.dart        ← NEW: API communication
│
├── controllers/
│   └── media_upload_controller.dart  ← NEW: State management
│
├── pages/
│   ├── MediaPickerPage.dart          ← UPDATE: Add upload button
│   ├── ProcessingScreen.dart         ← NEW: Show progress
│   └── MediaResultPage.dart          ← UPDATE: Show results
│
└── widgets/
    └── result_card_widget.dart       ← NEW: Result display widget
```

## Key Features Summary

| Feature | Description | Status |
|---------|-------------|--------|
| File Picking | Select image/video from gallery | ✅ Existing |
| File Validation | Check size (20MB) and duration (60s) | ✅ Existing |
| Upload Progress | Show upload percentage | 🆕 New |
| Status Polling | Check processing status every 2s | 🆕 New |
| Result Display | Show AI/Human label with confidence | 🆕 New |
| Error Handling | Network errors, timeouts, retries | 🆕 New |
| Retry Mechanism | Retry failed uploads | 🆕 New |
| Timeout Handling | 5-minute timeout for processing | 🆕 New |

## State Transitions

```
Idle → Uploading → Processing → Completed
  ↓         ↓           ↓          ↓
Failed    Failed      Failed    Show Result
  ↓         ↓           ↓          ↓
Retry     Retry       Retry    Upload New
```
