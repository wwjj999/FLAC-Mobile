# Implementation Plan: SpotiFLAC Android

## Overview

Implementasi SpotiFLAC Android menggunakan Flutter untuk UI dan Go backend via gomobile. Tasks disusun secara incremental, dimulai dari setup project, kemudian Go backend, lalu Flutter UI, dan terakhir integrasi.

---

## API Fix Tasks (Priority: HIGH)

Perbaikan untuk error "All services failed" dengan menambahkan User-Agent, rate limiting, retry logic, dan sequential API fallback.

- [x] 14. Create HTTP Utility Module
  - [x] 14.1 Create httputil.go with User-Agent generator
    - Implement `getRandomUserAgent()` function
    - Generate random browser-like User-Agent strings
    - Support Android Chrome format
    - _Requirements: 1.1, 1.2, 1.3_
  - [x] 14.2 Implement HTTP client factory
    - Create `NewHTTPClientWithTimeout(timeout)` function
    - Create `DoRequestWithUserAgent(client, req)` function
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  - [x] 14.3 Implement retry logic with exponential backoff
    - Create `DoRequestWithRetry(client, req, maxRetries)` function
    - Implement exponential backoff (1s, 2s, 4s)
    - Handle 429 responses with Retry-After header
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [x] 14.4 Implement response validation
    - Create `ReadResponseBody(resp)` function
    - Validate non-empty response
    - _Requirements: 7.1, 7.4_

- [x] 15. Create Rate Limiter Module
  - [x] 15.1 Create ratelimit.go with sliding window rate limiter
    - Implement `RateLimiter` struct
    - Implement `NewRateLimiter(maxRequests, window)` function
    - Implement `Wait()` method that blocks until request allowed
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - [x] 15.2 Create global SongLink rate limiter
    - Initialize with 9 requests per minute
    - _Requirements: 2.2_

- [x] 16. Update Amazon Downloader
  - [x] 16.1 Change parallel to sequential API requests
    - Replace `getAmazonDownloadURLParallel` with `getAmazonDownloadURLSequential`
    - Try APIs one by one, not all at once
    - _Requirements: 5.1, 5.4_
  - [x] 16.2 Add User-Agent to all requests
    - Use `DoRequestWithRetry` for API requests
    - Use `DoRequestWithUserAgent` for download requests
    - _Requirements: 1.5_
  - [x] 16.3 Increase timeout to 60 seconds
    - Update HTTP client timeout from 15s to 60s
    - _Requirements: 4.1_
  - [x] 16.4 Improve error messages
    - Include API URL, status code, and response preview in errors
    - Check for error field in JSON response
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 7.3_

- [x] 17. Update Qobuz Downloader
  - [x] 17.1 Change parallel to sequential API requests
    - Replace `getQobuzDownloadURLParallel` with sequential version
    - _Requirements: 5.2, 5.4_
  - [x] 17.2 Add User-Agent to all requests
    - Use `DoRequestWithRetry` for API requests
    - _Requirements: 1.6_
  - [x] 17.3 Increase timeout to 60 seconds
    - Update HTTP client timeout from 15s to 60s
    - _Requirements: 4.2_
  - [x] 17.4 Improve error messages
    - Include comprehensive error details
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 18. Update Tidal Downloader
  - [x] 18.1 Change parallel to sequential API requests
    - Replace parallel API requests with sequential version
    - _Requirements: 5.3, 5.4_
  - [x] 18.2 Add User-Agent to all requests
    - Use `DoRequestWithRetry` for API requests
    - _Requirements: 1.7_
  - [x] 18.3 Increase timeout to 60 seconds
    - Update HTTP client timeout from 15s to 60s
    - _Requirements: 4.3_
  - [x] 18.4 Improve error messages
    - Include comprehensive error details
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 19. Update SongLink Client
  - [x] 19.1 Integrate global rate limiter
    - Call `songLinkRateLimiter.Wait()` before each request
    - _Requirements: 2.1, 2.2, 2.3_
  - [x] 19.2 Add User-Agent to requests
    - Use `DoRequestWithRetry` for API requests
    - _Requirements: 1.4_
  - [x] 19.3 Improve 429 handling
    - Wait based on Retry-After header
    - Default to 60 seconds if no header
    - _Requirements: 2.5, 3.3, 3.4_

- [ ] 20. Checkpoint - API Fix Complete
  - Rebuild Go backend with gomobile
  - Generate new AAR file
  - Copy to android/app/libs/
  - Test download functionality
  - Ensure all tests pass, ask the user if questions arise.

---

## Original Tasks (Completed)

- [x] 1. Project Setup
  - [x] 1.1 Setup Flutter project dengan struktur folder
  - [x] 1.2 Setup Go module untuk gomobile

- [x] 2. Go Backend Core
  - [x] 2.1 Implement Spotify URL parser dan validator
  - [x] 2.2 Write property test for URL validation
  - [x] 2.3 Implement Spotify metadata fetcher
  - [x] 2.4 Implement Spotify search

- [x] 3. Download Services
  - [x] 3.1 Implement Tidal downloader
  - [x] 3.2 Implement Qobuz downloader
  - [x] 3.3 Implement Amazon downloader
  - [x] 3.4 Implement service fallback logic

- [x] 4. Metadata and File Management
  - [x] 4.1 Implement metadata embedding
  - [x] 4.3 Implement cover art embedding
  - [x] 4.5 Implement filename builder
  - [x] 4.6 Write property test for filename template
  - [x] 4.7 Implement filename sanitizer
  - [x] 4.8 Write property test for filename sanitization

- [x] 5. Duplicate Detection
  - [x] 5.1 Implement ISRC-based duplicate detection

- [x] 6. Checkpoint - Go Backend Complete

- [x] 7. Flutter Data Models
  - [x] 7.1 Create Track model
  - [x] 7.2 Create DownloadItem model
  - [x] 7.3 Create Settings model
  - [x] 7.4 Write property test for settings persistence

- [x] 8. Flutter Platform Bridge
  - [x] 8.1 Create MethodChannel bridge

- [x] 9. Flutter State Management
  - [x] 9.1 Create TrackProvider
  - [x] 9.2 Create DownloadQueueProvider
  - [x] 9.3 Write property test for queue management
  - [x] 9.4 Create SettingsProvider

- [x] 10. Flutter UI Screens
  - [x] 10.1 Create HomeScreen
  - [x] 10.2 Create SearchResultsScreen
  - [x] 10.3 Create QueueScreen
  - [x] 10.4 Create SettingsScreen

- [x] 11. Android-Specific Features
  - [x] 11.1 Implement storage permissions
  - [x] 11.2 Implement foreground service
  - [x] 11.3 Implement share intent receiver

- [x] 12. Integration and Polish
  - [x] 12.1 Wire all components together

- [ ] 13. Final Checkpoint
  - Ensure all tests pass
  - Build release APK
  - Test on physical device

## Notes

- API Fix tasks (14-20) are HIGH PRIORITY and should be completed first to fix download errors
- Go backend harus di-compile dengan gomobile sebelum bisa digunakan di Flutter
- Setelah API fix selesai, rebuild AAR dengan: `gomobile bind -target=android -o gobackend.aar`
