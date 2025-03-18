import Foundation
import NetworkExtension

/**
 * Bridge between Swift and the Geph5 client C API
 */
class GephDaemonBridge {
    
    /**
     * Starts the Geph5 client with the provided configuration
     */
    static func startClient(config: String) throws -> Int32 {
        NSLog("Starting Geph5 client with config: \(config)")
        let result = start_client(config)
        
        if result != 0 {
            throw "Failed to start Geph5 client. Error code: \(result)"
        }
        
        return result
    }
    
    /**
     * Sends an RPC request to the daemon and returns the response
     */
    static func daemonRpc(request: String) throws -> String {
        let bufLen = 1024 * 128 // 128 KB buffer should be enough for most responses
        var buffer = [CChar](repeating: 0, count: bufLen)
        
        let result = daemon_rpc(request, &buffer, Int32(bufLen))
        
        if result < 0 {
            switch result {
            case -1:
                throw "Daemon not started"
            case -2:
                throw "JSON-RPC error"
            case -3:
                throw "Buffer not big enough for response"
            case -4:
                throw "Error writing to buffer"
            default:
                throw "Unknown error from daemon_rpc: \(result)"
            }
        }
        
        return String(cString: buffer)
    }
    
    /**
     * Sends a VPN packet to the daemon
     */
    static func sendPacket(data: Data) throws {
        let result = data.withUnsafeBytes { 
            send_pkt($0.baseAddress!.assumingMemoryBound(to: CChar.self), Int32(data.count))
        }
        
        if result != 0 {
            throw "Failed to send packet to daemon"
        }
    }
    
    /**
     * Receives a VPN packet from the daemon
     */
    static func receivePacket(maxSize: Int = 2048) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: maxSize)
        
        let result = buffer.withUnsafeMutableBytes { 
            recv_pkt($0.baseAddress!.assumingMemoryBound(to: CChar.self), Int32(maxSize))
        }
        
        if result < 0 {
            throw "Failed to receive packet from daemon"
        }
        
        return Data(bytes: buffer, count: Int(result))
    }
}