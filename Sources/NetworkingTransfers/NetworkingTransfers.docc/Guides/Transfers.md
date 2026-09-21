# File transfers

## Foreground uploads and downloads

`TransferClient` supports file-based upload and download using either `HTTPRequest` or an explicit `URLRequest`.

```swift
let transfer = TransferClient(httpClient: client)
let result = try await transfer.upload(
    HTTPRequest(method: .post, pathSegments: ["uploads"]),
    from: localFile,
    progress: { progress in
        // The callback runs on the transport queue; return promptly.
        _ = progress.fractionCompleted
    }
)
```

Uploads use a regular file that must remain stable and accessible until completion. Downloads stream to a temporary system file and move a successful 2xx result to the requested destination. The destination must be a file URL and must not already exist. After success, the application owns and eventually removes the file.

The default foreground transport uses an isolated ephemeral URLSession, performs one send, rejects redirects, and does not automatically retry or recover after 401. It enforces HTTPS unless explicit loopback HTTP is enabled. `TransferOptions.resourceTimeout` applies to the transport resource, not to credential preparation.

Default foreground limits are 500 MiB for uploads and downloads and five minutes for the resource timeout. Progress callbacks are synchronous and `Sendable`; dispatch UI work and return promptly.

## Multipart form data

`MultipartForm` writes fields and file parts to a destination file without loading entire files into memory. File data is copied in chunks, while framing also counts toward `maximumBytes`. Names, filenames, and content types reject control characters, quotes, and backslashes to prevent header injection.

```swift
var form = MultipartForm()
try form.addField(name: "title", value: "Example")
try form.addFile(name: "attachment", fileURL: localFile, contentType: "application/octet-stream")
let encoded = try form.write(to: multipartFile)
```

Retain the encoded file until upload finishes. For background work, store it in a persistent private directory rather than a disposable temporary location.

## Explicit and presigned URLs

The `URLRequest` overload preserves the explicit URL and query without adding base headers or credentials. The application signer owns header and signing policy. Automatic redirects remain disabled in foreground transfer; request a newly approved URL instead of following an unexpected location.

## System background transfers

`BackgroundTransferManager` is an application lifecycle component, not an async function that keeps a UI task alive. Create one manager per stable, account-scoped identifier and directory. Recreate it for operating-system relaunch events and recover results from persistent receipts.

Apple background sessions follow redirects automatically and do not provide the same pre-send redirect enforcement as foreground transfer. The manager therefore requires the explicit `systemManagedForTrustedServers` contract, supports HTTPS only, and rejects bearer, API-key, cookie, and arbitrary custom headers. Use trusted, narrowly scoped presigned URLs.

Uploads and downloads return a job ID after the system task starts. The manager exposes active tasks, cancellation, graceful invalidation, and cancel invalidation. A server may have processed an upload before local cancellation.

Receipts are stored atomically. Successful downloads remain in the receipt directory until acknowledged. Receipt bodies and files may contain sensitive data, so the application owns data protection and retention. Corrupt receipts remain available for inspection and do not block healthy receipts.

On iOS, bridge `application(_:handleEventsForBackgroundURLSession:completionHandler:)` to the correct manager. Invoke the operating-system completion handler only after the session's background-events-finished callback, not after one file completes. Verify relaunch behavior, force quit, URL expiry, connectivity changes, and receipt recovery in a real application on a physical device.
