# Requirements Document: SpotiFLAC Android - API Fix

## Introduction

Dokumen ini berisi requirements untuk memperbaiki error download di SpotiFLAC Android. Error utama adalah "All services failed. Last error: failed to get download URL: all 3 Amazon APIs failed" yang disebabkan oleh perbedaan implementasi HTTP request antara versi PC dan port Android.

Berdasarkan analisis komparatif dengan repository asli (https://github.com/afkarxyz/SpotiFLAC), ditemukan beberapa fitur kritis yang hilang di port Android:
1. User-Agent headers tidak ada
2. Rate limiting tidak diimplementasikan
3. Retry logic tidak ada
4. Timeout terlalu pendek
5. Sequential API fallback diganti dengan parallel requests yang bermasalah

## Glossary

- **Go_Backend**: Komponen backend yang ditulis dalam Go dan di-compile menggunakan gomobile
- **HTTP_Client**: HTTP client yang digunakan untuk melakukan request ke API eksternal
- **User_Agent**: Header HTTP yang mengidentifikasi client ke server
- **Rate_Limiter**: Mekanisme untuk membatasi jumlah request per waktu tertentu
- **Retry_Logic**: Mekanisme untuk mencoba ulang request yang gagal
- **API_Fallback**: Mekanisme untuk mencoba API alternatif ketika API utama gagal
- **SongLink_API**: API untuk mendapatkan link streaming dari berbagai layanan
- **Amazon_API**: API untuk mendapatkan download URL dari Amazon Music
- **Qobuz_API**: API untuk mendapatkan download URL dari Qobuz
- **Tidal_API**: API untuk mendapatkan download URL dari Tidal

## Requirements

### Requirement 1: User-Agent Headers

**User Story:** As a user, I want the app to properly identify itself to API servers, so that my download requests are not rejected as bot traffic.

#### Acceptance Criteria

1. WHEN the Go_Backend makes an HTTP request to any external API, THE HTTP_Client SHALL include a valid User-Agent header
2. THE User_Agent SHALL be randomized to mimic legitimate browser traffic
3. THE User_Agent format SHALL follow standard browser User-Agent patterns (e.g., Mozilla/5.0 Chrome format)
4. WHEN making requests to SongLink_API, THE HTTP_Client SHALL include the User-Agent header
5. WHEN making requests to Amazon_API, THE HTTP_Client SHALL include the User-Agent header
6. WHEN making requests to Qobuz_API, THE HTTP_Client SHALL include the User-Agent header
7. WHEN making requests to Tidal_API, THE HTTP_Client SHALL include the User-Agent header

### Requirement 2: Rate Limiting for SongLink API

**User Story:** As a user, I want the app to respect API rate limits, so that my requests are not blocked due to excessive usage.

#### Acceptance Criteria

1. THE Go_Backend SHALL implement rate limiting for SongLink_API requests
2. THE Rate_Limiter SHALL allow maximum 9 requests per minute to SongLink_API
3. WHEN the rate limit is reached, THE Go_Backend SHALL wait until the next minute before making additional requests
4. THE Rate_Limiter SHALL reset the request counter every minute
5. WHEN a 429 (Too Many Requests) response is received, THE Go_Backend SHALL wait and retry the request

### Requirement 3: Retry Logic

**User Story:** As a user, I want the app to automatically retry failed requests, so that temporary network issues don't cause download failures.

#### Acceptance Criteria

1. WHEN an HTTP request fails, THE Go_Backend SHALL retry the request up to 3 times
2. THE Go_Backend SHALL implement exponential backoff between retries (1s, 2s, 4s)
3. WHEN a 429 response is received, THE Go_Backend SHALL wait based on Retry-After header if present
4. IF no Retry-After header is present, THE Go_Backend SHALL wait 60 seconds before retry
5. WHEN all retries are exhausted, THE Go_Backend SHALL return a descriptive error message

### Requirement 4: HTTP Timeout Configuration

**User Story:** As a user, I want the app to have appropriate timeout settings, so that slow API responses don't cause premature failures.

#### Acceptance Criteria

1. THE HTTP_Client for Amazon_API SHALL have a timeout of at least 60 seconds
2. THE HTTP_Client for Qobuz_API SHALL have a timeout of at least 60 seconds
3. THE HTTP_Client for Tidal_API SHALL have a timeout of at least 60 seconds
4. THE HTTP_Client for SongLink_API SHALL have a timeout of at least 30 seconds
5. THE HTTP_Client for download operations SHALL have a timeout of at least 120 seconds

### Requirement 5: Sequential API Fallback

**User Story:** As a user, I want the app to try APIs one by one instead of all at once, so that rate limiting and connection issues are minimized.

#### Acceptance Criteria

1. WHEN downloading from Amazon, THE Go_Backend SHALL try APIs sequentially instead of in parallel
2. WHEN downloading from Qobuz, THE Go_Backend SHALL try APIs sequentially instead of in parallel
3. WHEN downloading from Tidal, THE Go_Backend SHALL try APIs sequentially instead of in parallel
4. WHEN an API fails, THE Go_Backend SHALL immediately try the next API in the list
5. THE Go_Backend SHALL track and report which API was successful or all errors if all fail

### Requirement 6: Error Handling and Logging

**User Story:** As a user, I want clear error messages when downloads fail, so that I can understand what went wrong.

#### Acceptance Criteria

1. WHEN an API request fails, THE Go_Backend SHALL log the API URL, status code, and error message
2. WHEN all APIs fail, THE Go_Backend SHALL return a comprehensive error listing all attempted APIs and their errors
3. THE Go_Backend SHALL include the HTTP status code in error messages
4. IF the response body contains an error message, THE Go_Backend SHALL include it in the error
5. WHEN a timeout occurs, THE Go_Backend SHALL clearly indicate it was a timeout error

### Requirement 7: Response Validation

**User Story:** As a user, I want the app to properly validate API responses, so that malformed responses don't cause crashes.

#### Acceptance Criteria

1. WHEN receiving an API response, THE Go_Backend SHALL validate the Content-Type header
2. WHEN parsing JSON responses, THE Go_Backend SHALL read the entire response body before parsing
3. IF the JSON response contains an error field, THE Go_Backend SHALL treat it as an error
4. WHEN the response body is empty, THE Go_Backend SHALL return an appropriate error message
5. WHEN the response is not valid JSON, THE Go_Backend SHALL return an error with the raw response preview

