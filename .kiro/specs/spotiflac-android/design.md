# Design Document: SpotiFLAC Android

## Overview

SpotiFLAC Android adalah port dari aplikasi desktop SpotiFLAC ke platform Android. Aplikasi ini memungkinkan pengguna mengunduh track Spotify dalam format FLAC dari layanan streaming Tidal, Qobuz, dan Amazon Music.

Arsitektur menggunakan **Flutter** untuk UI dan **Go backend** yang di-compile menggunakan **gomobile** sebagai native library. Pendekatan ini memungkinkan reuse logic backend dari versi desktop sambil mendapatkan UI native Android yang responsif.

---

## API Fix Design (v2.0)

### Problem Statement

Port Android mengalami error "All services failed. Last error: failed to get download URL: all 3 Amazon APIs failed" karena perbedaan implementasi HTTP request dengan versi PC:

1. **Missing User-Agent headers** - API servers menolak request tanpa User-Agent
2. **Timeout terlalu pendek** - 15 detik vs 120 detik di versi PC
3. **Tidak ada rate limiting** - SongLink API membatasi 10 req/menit
4. **Parallel requests** - Menyebabkan race condition dan rate limiting
5. **Tidak ada retry logic** - Request gagal langsung error

### Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HTTP Client Layer                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │              httputil.go (NEW)                          ││
│  │  - getRandomUserAgent()                                 ││
│  │  - NewHTTPClientWithTimeout(timeout)                    ││
│  │  - DoRequestWithRetry(req, maxRetries)                  ││
│  │  - DoRequestWithUserAgent(req)                          ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │              ratelimit.go (NEW)                         ││
│  │  - RateLimiter struct                                   ││
│  │  - NewRateLimiter(maxRequests, window)                  ││
│  │  - Wait() - blocks until request allowed                ││
│  │  - TryAcquire() - non-blocking check                    ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│                    Service Layer (Modified)                 │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────┐  │
│  │ songlink  │ │  amazon   │ │  qobuz    │ │   tidal     │  │
│  │  .go      │ │   .go     │ │   .go     │ │    .go      │  │
│  │ +UserAgent│ │ +UserAgent│ │ +UserAgent│ │ +UserAgent  │  │
│  │ +RateLimit│ │ +Timeout  │ │ +Timeout  │ │ +Timeout    │  │
│  │ +Retry    │ │ +Sequential│ │ +Sequential│ │ +Sequential│  │
│  └───────────┘ └───────────┘ └───────────┘ └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### New Components

#### 1. httputil.go - HTTP Utility Functions

```go
package gobackend

import (
    "fmt"
    "io"
    "math/rand"
    "net/http"
    "time"
)

// getRandomUserAgent generates a random browser-like User-Agent string
func getRandomUserAgent() string {
    // Randomize Chrome version (80-105), OS version, WebKit version
    return fmt.Sprintf(
        "Mozilla/5.0 (Linux; Android %d; SM-G%d) AppleWebKit/%d.%d "+
        "(KHTML, like Gecko) Chrome/%d.0.%d.%d Mobile Safari/%d.%d",
        rand.Intn(4)+10,           // Android 10-13
        rand.Intn(900)+100,        // Samsung model
        rand.Intn(7)+530,          // WebKit major
        rand.Intn(7)+30,           // WebKit minor
        rand.Intn(25)+80,          // Chrome major
        rand.Intn(1500)+3000,      // Chrome build
        rand.Intn(65)+60,          // Chrome patch
        rand.Intn(7)+530,          // Safari major
        rand.Intn(6)+30,           // Safari minor
    )
}

// NewHTTPClientWithTimeout creates an HTTP client with specified timeout
func NewHTTPClientWithTimeout(timeout time.Duration) *http.Client {
    return &http.Client{
        Timeout: timeout,
    }
}

// DoRequestWithUserAgent executes request with random User-Agent
func DoRequestWithUserAgent(client *http.Client, req *http.Request) (*http.Response, error) {
    req.Header.Set("User-Agent", getRandomUserAgent())
    return client.Do(req)
}

// DoRequestWithRetry executes request with retry logic and exponential backoff
func DoRequestWithRetry(client *http.Client, req *http.Request, maxRetries int) (*http.Response, error) {
    var lastErr error
    
    for i := 0; i < maxRetries; i++ {
        req.Header.Set("User-Agent", getRandomUserAgent())
        
        resp, err := client.Do(req)
        if err != nil {
            lastErr = err
            // Exponential backoff: 1s, 2s, 4s
            time.Sleep(time.Duration(1<<i) * time.Second)
            continue
        }
        
        // Handle rate limiting
        if resp.StatusCode == 429 {
            resp.Body.Close()
            
            // Check Retry-After header
            retryAfter := resp.Header.Get("Retry-After")
            waitTime := 60 * time.Second // Default 60s
            if retryAfter != "" {
                if seconds, err := time.ParseDuration(retryAfter + "s"); err == nil {
                    waitTime = seconds
                }
            }
            
            time.Sleep(waitTime)
            lastErr = fmt.Errorf("rate limited (429)")
            continue
        }
        
        return resp, nil
    }
    
    return nil, fmt.Errorf("all %d retries failed: %w", maxRetries, lastErr)
}

// ReadResponseBody reads entire response body and returns it
func ReadResponseBody(resp *http.Response) ([]byte, error) {
    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, fmt.Errorf("failed to read response: %w", err)
    }
    if len(body) == 0 {
        return nil, fmt.Errorf("empty response body")
    }
    return body, nil
}
```

#### 2. ratelimit.go - Rate Limiter

```go
package gobackend

import (
    "sync"
    "time"
)

// RateLimiter implements a sliding window rate limiter
type RateLimiter struct {
    maxRequests  int
    window       time.Duration
    requests     []time.Time
    mu           sync.Mutex
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(maxRequests int, window time.Duration) *RateLimiter {
    return &RateLimiter{
        maxRequests: maxRequests,
        window:      window,
        requests:    make([]time.Time, 0, maxRequests),
    }
}

// Wait blocks until a request is allowed
func (r *RateLimiter) Wait() {
    r.mu.Lock()
    defer r.mu.Unlock()
    
    now := time.Now()
    
    // Remove expired requests
    cutoff := now.Add(-r.window)
    validRequests := make([]time.Time, 0, len(r.requests))
    for _, t := range r.requests {
        if t.After(cutoff) {
            validRequests = append(validRequests, t)
        }
    }
    r.requests = validRequests
    
    // If at limit, wait until oldest request expires
    if len(r.requests) >= r.maxRequests {
        waitTime := r.requests[0].Add(r.window).Sub(now)
        if waitTime > 0 {
            r.mu.Unlock()
            time.Sleep(waitTime)
            r.mu.Lock()
        }
        // Remove the oldest request
        r.requests = r.requests[1:]
    }
    
    // Record this request
    r.requests = append(r.requests, time.Now())
}

// Global rate limiter for SongLink API (9 requests per minute)
var songLinkRateLimiter = NewRateLimiter(9, time.Minute)
```

### Modified Components

#### 3. amazon.go - Sequential API with User-Agent

```go
// Key changes:
// 1. Add User-Agent to all requests
// 2. Change from parallel to sequential API tries
// 3. Increase timeout to 60 seconds
// 4. Add retry logic

const (
    amazonAPITimeout = 60 * time.Second
    amazonMaxRetries = 3
)

// getAmazonDownloadURLSequential tries APIs one by one (not parallel)
func getAmazonDownloadURLSequential(apis []string, amazonURL string, quality string) (string, string, error) {
    if len(apis) == 0 {
        return "", "", fmt.Errorf("no APIs available")
    }

    client := NewHTTPClientWithTimeout(amazonAPITimeout)
    var errors []string

    for _, apiURL := range apis {
        reqURL := fmt.Sprintf("%s/track/?url=%s&quality=%s", apiURL, amazonURL, quality)
        
        req, err := http.NewRequest("GET", reqURL, nil)
        if err != nil {
            errors = append(errors, fmt.Sprintf("%s: %v", apiURL, err))
            continue
        }

        resp, err := DoRequestWithRetry(client, req, amazonMaxRetries)
        if err != nil {
            errors = append(errors, fmt.Sprintf("%s: %v", apiURL, err))
            continue
        }

        body, err := ReadResponseBody(resp)
        resp.Body.Close()
        if err != nil {
            errors = append(errors, fmt.Sprintf("%s: %v", apiURL, err))
            continue
        }

        if resp.StatusCode != 200 {
            preview := string(body)
            if len(preview) > 100 {
                preview = preview[:100] + "..."
            }
            errors = append(errors, fmt.Sprintf("%s: HTTP %d - %s", apiURL, resp.StatusCode, preview))
            continue
        }

        var result struct {
            URL   string `json:"url"`
            Error string `json:"error,omitempty"`
        }
        if err := json.Unmarshal(body, &result); err != nil {
            errors = append(errors, fmt.Sprintf("%s: invalid JSON - %v", apiURL, err))
            continue
        }

        if result.Error != "" {
            errors = append(errors, fmt.Sprintf("%s: API error - %s", apiURL, result.Error))
            continue
        }

        if result.URL != "" {
            return apiURL, result.URL, nil
        }

        errors = append(errors, fmt.Sprintf("%s: no download URL in response", apiURL))
    }

    return "", "", fmt.Errorf("all %d Amazon APIs failed:\n%s", len(apis), strings.Join(errors, "\n"))
}
```

#### 4. songlink.go - Rate Limiting with User-Agent

```go
// Key changes:
// 1. Use global rate limiter
// 2. Add User-Agent to requests
// 3. Improve error messages

func (s *SongLinkClient) CheckTrackAvailability(spotifyTrackID string, isrc string) (*TrackAvailability, error) {
    // Wait for rate limiter
    songLinkRateLimiter.Wait()

    // Build request
    req, err := http.NewRequest("GET", apiURL, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    // Execute with retry and User-Agent
    resp, err := DoRequestWithRetry(s.client, req, 3)
    if err != nil {
        return nil, fmt.Errorf("SongLink API request failed: %w", err)
    }
    defer resp.Body.Close()

    // Read and validate response
    body, err := ReadResponseBody(resp)
    if err != nil {
        return nil, err
    }

    // ... rest of parsing logic
}
```

### Timeout Configuration

| Component | Current | New | Reason |
|-----------|---------|-----|--------|
| Amazon API | 15s | 60s | API processing takes time |
| Qobuz API | 15s | 60s | Search and URL generation |
| Tidal API | 15s | 60s | Manifest parsing |
| SongLink API | 30s | 30s | Already adequate |
| Download | 30s | 120s | Large file downloads |

---

## API Fix Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do.*

### Property 13: User-Agent Header Presence
*For any* HTTP request made by the Go_Backend to external APIs (SongLink, Amazon, Qobuz, Tidal), the request SHALL include a non-empty User-Agent header that follows browser User-Agent format.

**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**

### Property 14: User-Agent Randomization
*For any* two consecutive calls to getRandomUserAgent(), the returned strings SHALL be different (with high probability due to randomization).

**Validates: Requirements 1.2**

### Property 15: Rate Limiter Enforcement
*For any* sequence of N requests where N > maxRequests within the time window, the rate limiter SHALL block until the window resets, ensuring no more than maxRequests are made per window.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

### Property 16: Retry Logic with Exponential Backoff
*For any* failed HTTP request, the retry mechanism SHALL attempt up to maxRetries times with exponentially increasing delays (1s, 2s, 4s).

**Validates: Requirements 3.1, 3.2**

### Property 17: 429 Response Handling
*For any* HTTP response with status code 429, the system SHALL wait for the duration specified in Retry-After header (or 60 seconds if absent) before retrying.

**Validates: Requirements 3.3, 3.4**

### Property 18: Sequential API Fallback
*For any* download request to Amazon/Qobuz/Tidal, the system SHALL try APIs sequentially (not in parallel), moving to the next API only after the current one fails.

**Validates: Requirements 5.1, 5.2, 5.3, 5.4**

### Property 19: Comprehensive Error Reporting
*For any* failed download where all APIs fail, the error message SHALL contain the URL, status code, and error description for each attempted API.

**Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**

### Property 20: Response Validation
*For any* API response, the system SHALL validate that the response body is non-empty and contains valid JSON before processing.

**Validates: Requirements 7.1, 7.3, 7.4, 7.5**

---

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Screens   │  │   Widgets   │  │   State Management  │  │
│  │  - Home     │  │  - TrackCard│  │  (Provider/Riverpod)│  │
│  │  - Search   │  │  - Queue    │  │                     │  │
│  │  - Settings │  │  - Progress │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Platform Channels                        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Method Channel / FFI                       ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│                    Go Backend (gomobile)                    │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────┐  │
│  │  Spotify  │ │  Tidal    │ │  Qobuz    │ │   Amazon    │  │
│  │  Service  │ │  Download │ │  Download │ │   Download  │  │
│  └───────────┘ └───────────┘ └───────────┘ └─────────────┘  │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────────────┐  │
│  │ SongLink  │ │ Metadata  │ │     File Management       │  │
│  │  Service  │ │  Service  │ │                           │  │
│  └───────────┘ └───────────┘ └───────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Flutter UI Layer

#### 1.1 Screens
- **HomeScreen**: Main screen dengan input URL/search dan track display
- **SearchScreen**: Hasil pencarian Spotify
- **QueueScreen**: Download queue management
- **SettingsScreen**: App configuration

#### 1.2 State Management (Riverpod)
```dart
// Track state
class TrackState {
  final List<Track> tracks;
  final bool isLoading;
  final String? error;
}

// Download queue state
class DownloadQueueState {
  final List<DownloadItem> items;
  final DownloadItem? currentDownload;
  final double progress;
}

// Settings state
class SettingsState {
  final String defaultService;
  final String audioQuality;
  final String filenameFormat;
  final String downloadDirectory;
  final bool autoFallback;
  final bool embedLyrics;
  final bool maxQualityCover;
}
```

### 2. Go Backend Interface

#### 2.1 Exported Functions (via gomobile)
```go
// Spotify functions
func GetSpotifyMetadata(url string) (string, error)
func SearchSpotify(query string, limit int) (string, error)

// Download functions
func DownloadTrack(request string) (string, error)
func CheckAvailability(spotifyID, isrc string) (string, error)

// Queue management
func AddToQueue(itemID, trackName, artistName, albumName, isrc string)
func GetQueueStatus() string
func CancelDownload(itemID string)
func ClearQueue()

// Settings
func SetDownloadDirectory(path string)
func GetDownloadProgress() string
```

#### 2.2 Request/Response JSON Structures
```go
type DownloadRequest struct {
    ISRC           string `json:"isrc"`
    Service        string `json:"service"`
    SpotifyID      string `json:"spotify_id"`
    TrackName      string `json:"track_name"`
    ArtistName     string `json:"artist_name"`
    AlbumName      string `json:"album_name"`
    CoverURL       string `json:"cover_url"`
    OutputDir      string `json:"output_dir"`
    FilenameFormat string `json:"filename_format"`
    EmbedLyrics    bool   `json:"embed_lyrics"`
}

type DownloadResponse struct {
    Success       bool   `json:"success"`
    Message       string `json:"message"`
    File          string `json:"file,omitempty"`
    Error         string `json:"error,omitempty"`
    AlreadyExists bool   `json:"already_exists,omitempty"`
}
```

### 3. Platform Channel Bridge

```dart
class SpotiFLACBridge {
  static const platform = MethodChannel('com.spotiflac/backend');
  
  Future<SpotifyMetadata> getMetadata(String url) async {
    final result = await platform.invokeMethod('getSpotifyMetadata', {'url': url});
    return SpotifyMetadata.fromJson(jsonDecode(result));
  }
  
  Future<DownloadResponse> downloadTrack(DownloadRequest request) async {
    final result = await platform.invokeMethod('downloadTrack', request.toJson());
    return DownloadResponse.fromJson(jsonDecode(result));
  }
  
  Stream<DownloadProgress> get progressStream => _progressController.stream;
}
```

## Data Models

### Track Model
```dart
class Track {
  final String id;
  final String name;
  final String artistName;
  final String albumName;
  final String albumArtist;
  final String coverUrl;
  final String isrc;
  final int duration;
  final int trackNumber;
  final int discNumber;
  final String releaseDate;
  final ServiceAvailability availability;
}

class ServiceAvailability {
  final bool tidal;
  final bool qobuz;
  final bool amazon;
  final String? tidalUrl;
  final String? qobuzUrl;
  final String? amazonUrl;
}
```

### Download Item Model
```dart
enum DownloadStatus { queued, downloading, completed, failed, skipped }

class DownloadItem {
  final String id;
  final Track track;
  final String service;
  final DownloadStatus status;
  final double progress;
  final String? filePath;
  final String? error;
}
```

### Settings Model
```dart
class AppSettings {
  final String defaultService; // 'tidal', 'qobuz', 'amazon'
  final String audioQuality;   // 'LOSSLESS', 'HIRES'
  final String filenameFormat; // '{title} - {artist}', etc.
  final String downloadDirectory;
  final bool autoFallback;
  final bool embedLyrics;
  final bool maxQualityCover;
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Spotify URL Validation
*For any* string input, the URL parser SHALL correctly identify valid Spotify track/album/playlist URLs and reject invalid formats.

**Validates: Requirements 1.1, 1.5**

### Property 2: Service Fallback Chain
*For any* download request with auto-fallback enabled, if service N fails, the system SHALL attempt service N+1 until success or all services exhausted.

**Validates: Requirements 3.4**

### Property 3: File Save Location
*For any* successful download, the resulting file SHALL exist at the user-specified directory path.

**Validates: Requirements 4.4**

### Property 4: Error Message Completeness
*For any* failed download operation, the system SHALL return a non-empty, descriptive error message.

**Validates: Requirements 4.5**

### Property 5: Metadata Round-Trip
*For any* valid metadata (title, artist, album, track number, ISRC, etc.), embedding into a FLAC file then reading back SHALL produce equivalent values.

**Validates: Requirements 5.1, 5.2, 5.3**

### Property 6: Cover Art Round-Trip
*For any* valid image data, embedding as cover art then extracting SHALL produce equivalent image data.

**Validates: Requirements 5.4**

### Property 7: Queue Addition Invariant
*For any* list of N tracks added to queue, the queue length SHALL increase by exactly N.

**Validates: Requirements 6.1**

### Property 8: Queue Processing Order
*For any* queue with items [A, B, C, ...], completing item A SHALL result in item B becoming the current download.

**Validates: Requirements 6.3**

### Property 9: Filename Template Substitution
*For any* metadata and filename template, the resulting filename SHALL contain all placeholder values correctly substituted.

**Validates: Requirements 7.1**

### Property 10: Filename Sanitization
*For any* input string, the sanitized filename SHALL contain no invalid filesystem characters.

**Validates: Requirements 7.2**

### Property 11: Duplicate Detection by ISRC
*For any* ISRC that exists in a file within the output directory, duplicate check SHALL return true.

**Validates: Requirements 8.1, 8.2, 8.3**

### Property 12: Settings Persistence Round-Trip
*For any* valid settings configuration, saving then loading SHALL produce equivalent settings.

**Validates: Requirements 10.1**

## Error Handling

### Network Errors
- Timeout: Retry with exponential backoff (max 3 retries)
- Rate limiting: Wait and retry based on API response headers
- Connection failure: Show offline message, queue for later

### Download Errors
- Service unavailable: Try fallback service if enabled
- Invalid response: Log error, mark as failed
- Partial download: Delete incomplete file, retry

### Storage Errors
- Permission denied: Request permission, show settings link
- Insufficient space: Show warning before download
- Write failure: Retry once, then mark as failed

## Testing Strategy

### Unit Tests
- URL parsing and validation
- Filename template processing
- Filename sanitization
- Settings serialization/deserialization
- Queue management logic
- User-Agent generation format validation
- Rate limiter behavior
- Retry logic timing

### Property-Based Tests (using fast_check for Dart, testing for Go)
- Property 1: URL validation with random valid/invalid URLs
- Property 5: Metadata round-trip with random metadata values
- Property 9: Filename template with random metadata
- Property 10: Filename sanitization with random strings including special characters
- Property 11: ISRC duplicate detection with random ISRCs
- Property 12: Settings persistence with random settings values
- Property 13: User-Agent header presence (Go unit test)
- Property 14: User-Agent randomization (Go unit test)
- Property 15: Rate limiter enforcement (Go unit test)
- Property 16: Retry logic with exponential backoff (Go unit test)
- Property 18: Sequential API fallback (Go integration test)

### Integration Tests
- Spotify API metadata fetching
- SongLink availability checking
- Download from each service (Tidal, Qobuz, Amazon)
- Full download flow with metadata embedding
- API fallback chain verification

### Configuration
- Property tests: minimum 100 iterations per property
- Use `fast_check` library for Dart property-based testing
- Use `testing` package for Go unit tests
- Tag format: **Feature: spotiflac-android, Property {number}: {property_text}**
