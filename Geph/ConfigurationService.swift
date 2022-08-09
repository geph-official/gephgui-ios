// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

//  Modified for geph

//  ConfigurationService.swift
//  geph
//
//  Created by Eric Dong on 3/26/22.
//

import Foundation
import Combine
import NetworkExtension
import UIKit


public final class VPNConfigurationService: ObservableObject {
    @Published private(set) var isStarted = false

    /// If not nil, the tunnel is displayed.
    @Published private(set) var manager: NETunnelProviderManager?

    static let shared = VPNConfigurationService()

    private var observer: AnyObject?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
        }
    }

    private func refresh() {
        refresh { _ in }
    }

    func refresh(_ completion: @escaping (Result<Void, Error>) -> Void) {
        // Read all of the VPN configurations created by the app that have
        // previously been saved to the Network Extension preferences.
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }

            // There is only one VPN configuration the app provides
            self.manager = managers?.first
            if let error = error {
                completion(.failure(error))
            } else {
                self.isStarted = true
                completion(.success(()))
            }
        }
    }

    func installProfile(_ completion: @escaping (Result<Void, Error>) -> Void) {
        let tunnel = makeManager()
        tunnel.saveToPreferences { [weak self] error in
            if let error = error {
                return completion(.failure(error))
            }

            // See https://forums.developer.apple.com/thread/25928
            tunnel.loadFromPreferences { [weak self] error in
                self?.manager = tunnel
                completion(.success(()))
            }
        }
    }

    private func makeManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "geph-daemon"
        
        let proto = NETunnelProviderProtocol()

        // WARNING: This must match the bundle identifier of the app extension
        // containing packet tunnel provider.
        proto.providerBundleIdentifier = "geph.io.daemon"
        proto.serverAddress = "123.123.123.123"
        manager.protocolConfiguration = proto

        // Enable the manager by default.
        eprint("EEEEEEEnabling manager!!!")
        manager.isEnabled = true
        assert(self.manager!.isEnabled)
        
        return manager
    }

    
    func removeProfile(_ completion: @escaping (Result<Void, Error>) -> Void) {
        assert(manager != nil, "Tunnel is missing")
        manager?.removeFromPreferences { error in
            if let error = error {
                return completion(.failure(error))
            }
            self.manager = nil
            completion(.success(()))
        }
    }
}


/// Make NEVPNStatus convertible to a string
extension NEVPNStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .invalid: return "Invalid"
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnecting: return "Disconnecting"
        case .reasserting: return "Reconnecting"
        @unknown default: return "Unknown"
        }
    }
}
