import 'dart:io';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:dartssh2/dartssh2.dart';
import 'package:spotiflac_android/utils/logger.dart';

/// Result of a cloud upload operation
class CloudUploadResult {
  final bool success;
  final String? error;
  final String? remotePath;

  const CloudUploadResult({
    required this.success,
    this.error,
    this.remotePath,
  });

  factory CloudUploadResult.success(String remotePath) => CloudUploadResult(
    success: true,
    remotePath: remotePath,
  );

  factory CloudUploadResult.failure(String error) => CloudUploadResult(
    success: false,
    error: error,
  );
}

/// Parsed SFTP server URL
class SftpServerInfo {
  final String host;
  final int port;
  
  const SftpServerInfo({required this.host, required this.port});
}

/// Service for uploading files to cloud storage (WebDAV, SFTP)
class CloudUploadService {
  static CloudUploadService? _instance;
  static CloudUploadService get instance => _instance ??= CloudUploadService._();

  CloudUploadService._();

  final LogBuffer _log = LogBuffer();

  webdav.Client? _webdavClient;
  String? _currentServerUrl;
  String? _currentUsername;

  void _logInfo(String tag, String message) {
    _log.add(LogEntry(
      timestamp: DateTime.now(),
      level: 'INFO',
      tag: tag,
      message: message,
    ));
  }

  void _logError(String tag, String message, [String? error]) {
    _log.add(LogEntry(
      timestamp: DateTime.now(),
      level: 'ERROR',
      tag: tag,
      message: message,
      error: error,
    ));
  }

  // ============================================================
  // WebDAV Methods
  // ============================================================

  /// Initialize WebDAV client with server credentials
  Future<void> initializeWebDAV({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    // Reuse existing client if credentials haven't changed
    if (_webdavClient != null && 
        _currentServerUrl == serverUrl && 
        _currentUsername == username) {
      return;
    }

    _webdavClient = webdav.newClient(
      serverUrl,
      user: username,
      password: password,
      debug: false,
    );

    _currentServerUrl = serverUrl;
    _currentUsername = username;

    _logInfo('CloudUpload', 'WebDAV client initialized for $serverUrl');
  }

  /// Test connection to WebDAV server
  Future<CloudUploadResult> testWebDAVConnection({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    try {
      final client = webdav.newClient(
        serverUrl,
        user: username,
        password: password,
        debug: false,
      );

      // Try to ping/read root directory
      await client.ping();
      
      _logInfo('CloudUpload', 'WebDAV connection test successful: $serverUrl');
      return CloudUploadResult.success('/');
    } catch (e) {
      _logError('CloudUpload', 'WebDAV connection test failed', e.toString());
      return CloudUploadResult.failure(_parseWebDAVError(e));
    }
  }

  /// Upload a file to WebDAV server
  Future<CloudUploadResult> uploadFileWebDAV({
    required String localPath,
    required String remotePath,
    required String serverUrl,
    required String username,
    required String password,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      // Initialize client if needed
      await initializeWebDAV(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );

      final client = _webdavClient!;
      final file = File(localPath);

      if (!await file.exists()) {
        return CloudUploadResult.failure('File not found: $localPath');
      }

      // Extract directory path and ensure it exists
      final remoteDir = remotePath.substring(0, remotePath.lastIndexOf('/'));
      if (remoteDir.isNotEmpty) {
        await _ensureWebDAVDirectoryExists(client, remoteDir);
      }

      // Upload the file
      _logInfo('CloudUpload', 'WebDAV uploading: $localPath -> $remotePath');
      
      await client.writeFromFile(
        localPath,
        remotePath,
        onProgress: onProgress,
      );

      _logInfo('CloudUpload', 'WebDAV upload complete: $remotePath');
      return CloudUploadResult.success(remotePath);
    } catch (e) {
      _logError('CloudUpload', 'WebDAV upload failed', e.toString());
      return CloudUploadResult.failure(_parseWebDAVError(e));
    }
  }

  /// Ensure a directory exists on the WebDAV server, creating it if necessary
  Future<void> _ensureWebDAVDirectoryExists(webdav.Client client, String path) async {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    var currentPath = '';

    for (final part in parts) {
      currentPath += '/$part';
      try {
        await client.mkdir(currentPath);
      } catch (e) {
        // Directory might already exist, ignore error
      }
    }
  }

  /// Parse WebDAV error to user-friendly message
  String _parseWebDAVError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'Authentication failed. Check username and password.';
    }
    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return 'Access denied. Check permissions on the server.';
    }
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'Server path not found. Check the URL.';
    }
    if (errorStr.contains('connection refused') || errorStr.contains('socket')) {
      return 'Cannot connect to server. Check URL and network.';
    }
    if (errorStr.contains('certificate') || errorStr.contains('ssl') || errorStr.contains('tls')) {
      return 'SSL/TLS error. Server certificate may be invalid.';
    }
    if (errorStr.contains('timeout')) {
      return 'Connection timed out. Server may be unreachable.';
    }
    if (errorStr.contains('507') || errorStr.contains('insufficient storage')) {
      return 'Insufficient storage on server.';
    }

    return 'Upload failed: ${error.toString()}';
  }

  // ============================================================
  // SFTP Methods
  // ============================================================

  /// Parse SFTP server URL to extract host and port
  /// Supports formats: 
  ///   - sftp://hostname:port
  ///   - sftp://hostname
  ///   - hostname:port
  ///   - hostname
  SftpServerInfo _parseSftpUrl(String serverUrl) {
    var url = serverUrl.trim();
    
    // Remove sftp:// prefix if present
    if (url.toLowerCase().startsWith('sftp://')) {
      url = url.substring(7);
    }
    
    // Check for port
    final colonIndex = url.lastIndexOf(':');
    if (colonIndex > 0) {
      final host = url.substring(0, colonIndex);
      final portStr = url.substring(colonIndex + 1);
      final port = int.tryParse(portStr) ?? 22;
      return SftpServerInfo(host: host, port: port);
    }
    
    return SftpServerInfo(host: url, port: 22);
  }

  /// Test connection to SFTP server
  Future<CloudUploadResult> testSFTPConnection({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    SSHClient? client;
    try {
      final serverInfo = _parseSftpUrl(serverUrl);
      
      _logInfo('CloudUpload', 'SFTP connecting to ${serverInfo.host}:${serverInfo.port}');
      
      // Connect to SSH server
      final socket = await SSHSocket.connect(
        serverInfo.host,
        serverInfo.port,
        timeout: const Duration(seconds: 10),
      );
      
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      
      // Wait for authentication
      await client.authenticated;
      
      // Test SFTP subsystem
      final sftp = await client.sftp();
      await sftp.listdir('/');
      sftp.close();
      
      _logInfo('CloudUpload', 'SFTP connection test successful: ${serverInfo.host}');
      return CloudUploadResult.success('/');
    } catch (e) {
      _logError('CloudUpload', 'SFTP connection test failed', e.toString());
      return CloudUploadResult.failure(_parseSFTPError(e));
    } finally {
      client?.close();
    }
  }

  /// Upload a file to SFTP server
  Future<CloudUploadResult> uploadFileSFTP({
    required String localPath,
    required String remotePath,
    required String serverUrl,
    required String username,
    required String password,
    void Function(int sent, int total)? onProgress,
  }) async {
    SSHClient? client;
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        return CloudUploadResult.failure('File not found: $localPath');
      }

      final fileSize = await file.length();
      final serverInfo = _parseSftpUrl(serverUrl);
      
      _logInfo('CloudUpload', 'SFTP connecting to ${serverInfo.host}:${serverInfo.port}');
      
      // Connect to SSH server
      final socket = await SSHSocket.connect(
        serverInfo.host,
        serverInfo.port,
        timeout: const Duration(seconds: 30),
      );
      
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      
      // Wait for authentication
      await client.authenticated;
      
      // Open SFTP session
      final sftp = await client.sftp();
      
      // Ensure remote directory exists
      final remoteDir = remotePath.substring(0, remotePath.lastIndexOf('/'));
      if (remoteDir.isNotEmpty) {
        await _ensureSFTPDirectoryExists(sftp, remoteDir);
      }
      
      _logInfo('CloudUpload', 'SFTP uploading: $localPath -> $remotePath');
      
      // Open remote file for writing
      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create | 
              SftpFileOpenMode.write | 
              SftpFileOpenMode.truncate,
      );
      
      // Read local file and write to remote with progress
      final localFileStream = file.openRead();
      int bytesUploaded = 0;
      
      await for (final chunk in localFileStream) {
        await remoteFile.write(Stream.value(Uint8List.fromList(chunk)));
        bytesUploaded += chunk.length;
        onProgress?.call(bytesUploaded, fileSize);
      }
      
      await remoteFile.close();
      sftp.close();
      
      _logInfo('CloudUpload', 'SFTP upload complete: $remotePath');
      return CloudUploadResult.success(remotePath);
    } catch (e) {
      _logError('CloudUpload', 'SFTP upload failed', e.toString());
      return CloudUploadResult.failure(_parseSFTPError(e));
    } finally {
      client?.close();
    }
  }

  /// Ensure a directory exists on the SFTP server, creating it if necessary
  Future<void> _ensureSFTPDirectoryExists(SftpClient sftp, String path) async {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    var currentPath = '';

    for (final part in parts) {
      currentPath += '/$part';
      try {
        await sftp.mkdir(currentPath);
      } catch (e) {
        // Directory might already exist, ignore error
        // SFTP throws exception if directory exists
      }
    }
  }

  /// Parse SFTP error to user-friendly message
  String _parseSFTPError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('authentication') || 
        errorStr.contains('permission denied') ||
        errorStr.contains('auth fail')) {
      return 'Authentication failed. Check username and password.';
    }
    if (errorStr.contains('connection refused')) {
      return 'Connection refused. Check server address and port.';
    }
    if (errorStr.contains('no route to host') || 
        errorStr.contains('network is unreachable')) {
      return 'Cannot reach server. Check network connection.';
    }
    if (errorStr.contains('connection timed out') || 
        errorStr.contains('timeout')) {
      return 'Connection timed out. Server may be unreachable.';
    }
    if (errorStr.contains('host key') || 
        errorStr.contains('fingerprint')) {
      return 'Host key verification failed.';
    }
    if (errorStr.contains('no such file') || 
        errorStr.contains('not found')) {
      return 'Remote path not found.';
    }
    if (errorStr.contains('permission') || 
        errorStr.contains('access denied')) {
      return 'Permission denied. Check folder permissions.';
    }
    if (errorStr.contains('disk full') || 
        errorStr.contains('no space')) {
      return 'Insufficient storage on server.';
    }
    if (errorStr.contains('socket') || 
        errorStr.contains('broken pipe')) {
      return 'Connection lost. Try again.';
    }

    return 'SFTP error: ${error.toString()}';
  }

  // ============================================================
  // Common Methods
  // ============================================================

  /// Get the remote path for a downloaded file
  String getRemotePath({
    required String localFilePath,
    required String baseRemotePath,
    required String downloadDirectory,
  }) {
    // Extract relative path from download directory
    String relativePath;
    if (localFilePath.startsWith(downloadDirectory)) {
      relativePath = localFilePath.substring(downloadDirectory.length);
      if (relativePath.startsWith('/') || relativePath.startsWith('\\')) {
        relativePath = relativePath.substring(1);
      }
    } else {
      // Just use the filename
      relativePath = localFilePath.split(Platform.pathSeparator).last;
    }

    // Normalize path separators
    relativePath = relativePath.replaceAll('\\', '/');

    // Combine with base remote path
    var remotePath = baseRemotePath;
    if (!remotePath.endsWith('/')) {
      remotePath += '/';
    }
    remotePath += relativePath;

    return remotePath;
  }

  /// Dispose resources
  void dispose() {
    _webdavClient = null;
    _currentServerUrl = null;
    _currentUsername = null;
  }
}
