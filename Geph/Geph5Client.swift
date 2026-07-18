import Foundation
import OSLog

private let clientLog = OSLog(subsystem: "geph.io.app", category: "Geph5Client")

/// Starts the Geph5 client with the provided configuration
/// - Parameter config: JSON string containing client configuration
/// - Throws: Error message if the client fails to start
public func startClient(_ config: String) throws {
	let result = config.withCString { (configCString: UnsafePointer<CChar>) -> Int in
		// iOS drives packets through send_pkt/recv_pkt, not a tun fd, so pass -1
		// (no platform-VPN file descriptor) as the vpn_fd argument.
		return Int(start_client(configCString, -1))
	}
	logPublic("startClient result = \(result)", log: clientLog)
	if result != 0 {
		throw "Failed to start client with error code: \(result)"
	}
}

/// Sends an RPC request to the daemon and returns the response
/// - Parameter request: JSON-RPC request string
/// - Returns: Response string from the daemon
/// - Throws: Error message if the RPC request fails
public func daemonRpc(_ request: String) throws -> String {
	try autoreleasepool {
		return try request.withCString { (requestCString: UnsafePointer<CChar>) -> String in
			// Allocate a buffer to hold the response
			let buflen = 65536
			var buffer = [CChar](repeating: 0, count: buflen)
			
			// Call the C function
			let result = daemon_rpc(requestCString, &buffer, Int32(buflen))
			
			// Check for errors
			if result < 0 {
                let err_msg = "Daemon RPC request failed with code: \(result)"
                eprint(err_msg)
				throw err_msg
			}
			
			// Convert the C string back to a Swift string
			return String(cString: buffer)
		}
	}
}

/// Sends a VPN packet
/// - Parameter packet: Data to send
/// - Throws: Error message if sending the packet fails
public func sendPacket(_ packet: Data) throws {
	let result = packet.withUnsafeBytes { rawBufferPointer in
		guard let baseAddress = rawBufferPointer.baseAddress else {
			return -1
		}
		let pointer = baseAddress.assumingMemoryBound(to: CChar.self)
		return Int(send_pkt(pointer, Int32(packet.count)))
	}
	
	if result != 0 {
		throw "Failed to send packet with error code: \(result)"
    }
}

/// Receives a VPN packet
/// - Returns: Received packet data
/// - Throws: Error message if receiving the packet fails
public func receivePacket() throws -> Data {
	let buflen = 65536
	var buffer = Data(count: buflen)  // Adjust size as needed for your packets
	
	let bytesReceived = buffer.withUnsafeMutableBytes { bufferPointer -> Int32 in
		guard let baseAddress = bufferPointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
			return -1
		}
		return recv_pkt(baseAddress, Int32(buflen))
	}
	
	if bytesReceived < 0 {
		throw "Failed to receive packet with error code: \(bytesReceived)"
	}
	
	// Create Data object from the received bytes
	return buffer.prefix(Int(bytesReceived))
}

//public func receivePacketBuf(_ buffer: Data) throws -> Data {
//	let buflen = buffer.count;
//		let bytesReceived = buffer.withUnsafeMutableBytes { bufferPointer -> Int32 in
//		  guard let baseAddress = bufferPointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
//			return -1
//		  }
//		  return recv_pkt(baseAddress, Int32(buflen))
//		}
//
//		if bytesReceived < 0 {
//		  throw "Failed to receive packet with error code: \(bytesReceived)"
//		}
//
//		// Create Data object from the received bytes
//		return buffer.prefix(Int(bytesReceived))
//}
