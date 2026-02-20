// PhotoReceiver.swift
import Foundation
import Network

/// An HTTP server that listens for incoming photo upload requests from the iOS
/// sender app and saves them to disk.
///
/// Mirrors the logic of the Windows ``PhotoPopupReceiver.PhotoReceiver`` class,
/// but uses Apple's ``Network`` framework (``NWListener``) instead of ASP.NET
/// Core / Kestrel.
///
/// Usage:
/// ```swift
/// let receiver = PhotoReceiver()
/// try receiver.start(settings: settings) { savedPath in
///     // show popup, copy to pasteboard, …
/// }
/// // Later:
/// receiver.stop()
/// ```
final class PhotoReceiver {

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.photopopup.receiver",
                                      qos: .userInitiated,
                                      attributes: .concurrent)

    // MARK: - Public API

    /// Starts the HTTP listener on ``settings.port``.
    ///
    /// - Parameters:
    ///   - settings: The current ``AppSettings`` instance.
    ///   - onPhotoSaved: Closure called on the receiver's queue after each
    ///     successfully saved photo.  Receives the full path of the saved file.
    /// - Throws: ``NWError`` when the port cannot be bound.
    func start(settings: AppSettings, onPhotoSaved: @escaping (String) -> Void) throws {
        guard listener == nil else { return }

        // Create the save directory up-front so the first upload never fails.
        try FileManager.default.createDirectory(atPath: settings.saveFolder,
                                                withIntermediateDirectories: true)

        let port = NWEndpoint.Port(rawValue: UInt16(settings.port))!
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let l = try NWListener(using: params, on: port)
        listener = l

        l.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection,
                                   settings: settings,
                                   onPhotoSaved: onPhotoSaved)
        }
        l.start(queue: queue)
    }

    /// Stops the HTTP listener and releases all resources.
    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection,
                                   settings: AppSettings,
                                   onPhotoSaved: @escaping (String) -> Void) {
        connection.start(queue: queue)
        readRequest(from: connection) { [weak self] data in
            guard let self, let data else {
                connection.cancel()
                return
            }
            let response = self.processRequest(data,
                                               settings: settings,
                                               onPhotoSaved: onPhotoSaved)
            let responseData = response.data(using: .utf8) ?? Data()
            connection.send(content: responseData,
                            completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    // MARK: - Buffered reader

    /// Reads chunks from ``connection`` until the complete HTTP request
    /// (headers + body as indicated by Content-Length) has been received,
    /// then calls ``completion`` with the assembled ``Data``.
    private func readRequest(from connection: NWConnection,
                              into buffer: Data = Data(),
                              headerEndOffset: Int = 0,
                              contentLength: Int = 0,
                              headersParsed: Bool = false,
                              completion: @escaping (Data?) -> Void) {

        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 131_072) { data, _, isComplete, error in

            if error != nil {
                completion(nil)
                return
            }

            var buf = buffer
            if let data { buf.append(data) }

            var hEnd = headerEndOffset
            var cLen = contentLength
            var hParsed = headersParsed

            // Locate end of headers on first pass.
            if !hParsed,
               let sepRange = buf.range(of: Data("\r\n\r\n".utf8)) {
                hParsed = true
                hEnd = sepRange.upperBound

                // Extract Content-Length from headers.
                if let headerStr = String(data: buf[..<sepRange.lowerBound], encoding: .utf8) {
                    for line in headerStr.components(separatedBy: "\r\n").dropFirst() {
                        if line.lowercased().hasPrefix("content-length:") {
                            let val = line.dropFirst("content-length:".count)
                                         .trimmingCharacters(in: .whitespaces)
                            cLen = Int(val) ?? 0
                        }
                    }
                }
            }

            // Check whether the full body has arrived.
            if hParsed, (buf.count - hEnd) >= cLen {
                completion(buf)
                return
            }

            if isComplete {
                // Connection closed before all data arrived; deliver what we have.
                completion(buf.isEmpty ? nil : buf)
                return
            }

            // Need more data – recurse.
            self.readRequest(from: connection,
                             into: buf,
                             headerEndOffset: hEnd,
                             contentLength: cLen,
                             headersParsed: hParsed,
                             completion: completion)
        }
    }

    // MARK: - HTTP request processing

    /// Parses a raw HTTP request, authenticates it, extracts the uploaded file,
    /// saves it to disk, and returns a formatted HTTP/1.1 response string.
    private func processRequest(_ data: Data,
                                 settings: AppSettings,
                                 onPhotoSaved: @escaping (String) -> Void) -> String {

        // Split headers and body.
        guard let sepRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return httpResponse(status: 400, body: "Bad request")
        }
        let headersData = data[..<sepRange.lowerBound]
        let bodyData    = data[sepRange.upperBound...]

        guard let headersStr = String(data: headersData, encoding: .utf8) else {
            return httpResponse(status: 400, body: "Bad request")
        }

        let lines = headersStr.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return httpResponse(status: 400, body: "Bad request")
        }

        // Parse: "POST /push-photo?token=xxx HTTP/1.1"
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return httpResponse(status: 400, body: "Bad request") }
        let method    = parts[0]
        let rawTarget = parts[1]

        guard method == "POST", rawTarget.hasPrefix("/push-photo") else {
            return httpResponse(status: 404, body: "Not found")
        }

        // Parse header key-value pairs.
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key   = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        // Parse query parameters.
        var queryParams: [String: String] = [:]
        if let qIdx = rawTarget.firstIndex(of: "?") {
            let qs = String(rawTarget[rawTarget.index(after: qIdx)...])
            for pair in qs.components(separatedBy: "&") {
                let kv = pair.components(separatedBy: "=")
                if kv.count == 2 {
                    queryParams[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                }
            }
        }

        // --- Authorisation: token ---
        let tokenProvided = queryParams["token"] ?? ""
        guard tokenProvided == settings.token else {
            return httpResponse(status: 401, body: "Unauthorized: invalid token.")
        }

        // --- Authorisation: password (optional) ---
        if settings.requirePassword {
            let expected = settings.password.trimmingCharacters(in: .whitespaces)
            guard !expected.isEmpty else {
                return httpResponse(status: 401,
                                    body: "Unauthorized: password required but not configured.")
            }
            let provided = (headers["x-auth"] ?? headers["x-auth-token"] ?? "")
                               .trimmingCharacters(in: .whitespaces)
            guard provided == expected else {
                return httpResponse(status: 401, body: "Unauthorized: invalid password.")
            }
        }

        // --- Content-Type check ---
        guard let contentType = headers["content-type"],
              contentType.lowercased().contains("multipart/form-data") else {
            return httpResponse(status: 400, body: "multipart/form-data expected")
        }

        // --- Extract boundary ---
        guard let boundary = extractBoundary(from: contentType) else {
            return httpResponse(status: 400, body: "Missing multipart boundary")
        }

        // --- Parse multipart body ---
        guard let fileInfo = extractFile(from: Data(bodyData), boundary: boundary),
              !fileInfo.data.isEmpty else {
            return httpResponse(status: 400, body: "file missing")
        }

        // --- Save file ---
        do {
            let dayFmt  = DateFormatter(); dayFmt.dateFormat  = "yyyy-MM-dd"
            let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH-mm-ss_SSS"
            let now     = Date()

            let dayFolder = "\(settings.saveFolder)/\(dayFmt.string(from: now))"
            try FileManager.default.createDirectory(atPath: dayFolder,
                                                    withIntermediateDirectories: true)

            let ext      = (fileInfo.filename as NSString).pathExtension
            let fileExt  = ext.isEmpty ? "jpg" : ext
            let shortUID = String(UUID().uuidString.prefix(8))
            let fileName = "\(timeFmt.string(from: now))_\(shortUID).\(fileExt)"
            let savePath = "\(dayFolder)/\(fileName)"

            try fileInfo.data.write(to: URL(fileURLWithPath: savePath))
            onPhotoSaved(savePath)
            return httpResponse(status: 200, body: "ok")
        } catch {
            return httpResponse(status: 500, body: "Failed to save: \(error.localizedDescription)")
        }
    }

    // MARK: - Multipart helpers

    private struct FileInfo {
        let data: Data
        let filename: String
    }

    /// Extracts the ``boundary`` value from a ``Content-Type`` header value such as
    /// ``multipart/form-data; boundary=Boundary-UUID``.
    private func extractBoundary(from contentType: String) -> String? {
        for component in contentType.components(separatedBy: ";") {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                return String(trimmed.dropFirst("boundary=".count))
            }
        }
        return nil
    }

    /// Finds the first file part in a multipart ``body`` and returns its raw
    /// bytes together with the declared filename.
    private func extractFile(from body: Data, boundary: String) -> FileInfo? {
        let boundaryMarker = Data(("--" + boundary).utf8)
        let crlf           = Data("\r\n".utf8)
        let doubleCRLF     = Data("\r\n\r\n".utf8)
        let finalMarker    = Data("--".utf8)

        var pos = body.startIndex

        while let markerRange = body.range(of: boundaryMarker,
                                            options: [],
                                            in: pos..<body.endIndex) {
            let afterMarker = markerRange.upperBound

            // Check for the final boundary suffix "--".
            if afterMarker + finalMarker.count <= body.endIndex,
               body[afterMarker..<(afterMarker + finalMarker.count)] == finalMarker {
                break
            }

            // Skip the CRLF that follows the boundary line.
            let partStart = afterMarker + crlf.count
            guard partStart < body.endIndex else { break }

            // Find the blank line that separates part headers from part body.
            guard let headerEnd = body.range(of: doubleCRLF,
                                              options: [],
                                              in: partStart..<body.endIndex) else { break }

            let partHeaderStr = String(data: body[partStart..<headerEnd.lowerBound],
                                        encoding: .utf8) ?? ""
            let partBody = body[headerEnd.upperBound...]

            // Only consider parts that declare a filename (i.e. file uploads).
            if partHeaderStr.lowercased().contains("content-disposition"),
               partHeaderStr.lowercased().contains("filename") {

                // Extract filename from Content-Disposition header.
                var filename = "photo.jpg"
                for line in partHeaderStr.components(separatedBy: "\r\n") {
                    if line.lowercased().hasPrefix("content-disposition") {
                        for segment in line.components(separatedBy: ";") {
                            let s = segment.trimmingCharacters(in: .whitespaces)
                            if s.lowercased().hasPrefix("filename=") {
                                filename = String(s.dropFirst("filename=".count))
                                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            }
                        }
                    }
                }

                // Part body ends at the next boundary marker (preceded by CRLF).
                let endMarker = Data(("\r\n--" + boundary).utf8)
                let fileBytes: Data
                if let endRange = partBody.range(of: endMarker) {
                    fileBytes = Data(partBody[..<endRange.lowerBound])
                } else {
                    fileBytes = Data(partBody)
                }

                return FileInfo(data: fileBytes, filename: filename)
            }

            pos = markerRange.upperBound
        }

        return nil
    }

    // MARK: - HTTP response builder

    private func httpResponse(status: Int, body: String) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default:  statusText = "Unknown"
        }
        return "HTTP/1.1 \(status) \(statusText)\r\n"
             + "Content-Type: text/plain; charset=utf-8\r\n"
             + "Content-Length: \(body.utf8.count)\r\n"
             + "Connection: close\r\n"
             + "\r\n"
             + body
    }
}
