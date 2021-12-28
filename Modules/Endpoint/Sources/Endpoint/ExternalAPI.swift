//
//  ExternalAPI.swift
//  App
//
//  Created by Masato TSUTSUMI on 2021/04/25.
//

import Foundation
import CodableURL

public struct ScanGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = [Group]
    public struct URI: CodableURL {
        @StaticPath("external", "groups") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct CheckGlobalIP: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = String
    public struct URI: CodableURL {
        @StaticPath("external", "global_ip") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct NotifyUpcomingLives: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = String
    public struct URI: CodableURL {
        @StaticPath("external", "notify_upcoming_lives") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct NotifyPastLives: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = String
    public struct URI: CodableURL {
        @StaticPath("external", "notify_past_lives") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct SendNotification: EndpointProtocol {
    public struct Request: Codable {
        public let message: String
        public let segment: Segment

        public init(message: String, segment: Segment? = .all) {
            self.message = message
            self.segment = segment ?? .all
        }
    }
    public typealias Response = String
    public struct URI: CodableURL {
        @StaticPath("external", "notification") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}

public enum Segment: String, Codable {
    case all
}

public struct EntryGroup: EndpointProtocol {
    public typealias Request = Group.ID
    public typealias Response = Empty
    
    public struct URI: CodableURL {
        @StaticPath("external", "entry_group") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}
