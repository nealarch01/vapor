import Async
import Service
import Bits
import TLS

extension HTTP2Client {
    /// Opens a new HTTP/2 stream
    func openStream() -> HTTP2Stream {
        return self.streamPool[nextStreamID]
    }
    
    /// Updates the client's settings
    func updateSettings(to settings: HTTP2Settings) {
        self.settings = settings
        self.updatingSettings = true
    }
    
    /// Connects to an HTTP/2 server using the knowledge that it's HTTP/2
    ///
    /// Requires an SSL driver with ALPN on your system
    public static func connect(
        to hostname: String,
        port: UInt16? = nil,
        settings: HTTP2Settings = HTTP2Settings(),
        on container: Container
    ) -> Future<HTTP2Client> {
        return then {
            let tlsClient = try container.make(ALPNSupporting.self, for: HTTP2Client.self)
            tlsClient.ALPNprotocols = ["h2", "http/1.1"]

            let client = HTTP2Client(client: tlsClient)

            // Connect the TLS client
            return try tlsClient.connect(hostname: hostname, port: port ?? 443).map { _ -> HTTP2Client in
                // On successful connection, send the preface
                Constants.staticPreface.withByteBuffer(tlsClient.onInput)

                // Send the settings, next
                client.updateSettings(to: settings)
                return client
            }
        }
    }
    
    /// Closes the HTTP/2 client by cleaning up
    public func close() {
        for stream in streamPool.streams.values {
            stream.close()
        }
        
        self.client.close()
    }
}
