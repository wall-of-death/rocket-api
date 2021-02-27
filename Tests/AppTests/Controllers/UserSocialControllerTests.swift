import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class UserSocialControllerTests: XCTestCase {
    var app: Application!
    var appClient: AppClient!

    override func setUp() {
        app = Application(.testing)
        DotEnvFile.load(path: dotEnvPath.path)
        XCTAssertNoThrow(try configure(app))
        appClient = AppClient(application: app, cognito: CognitoClient())
    }

    override func tearDown() {
        app.shutdown()
    }

    func testFollow() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let body = try! Stub.make(Endpoint.FollowGroup.Request.self) {
            $0.set(\.id, value: groupX.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/follow_group", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testUnfollow() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)

        try appClient.follow(group: groupX, with: userB)

        let body = try! Stub.make(Endpoint.UnfollowGroup.Request.self) {
            $0.set(\.id, value: groupX.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/unfollow_group", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testGetFollowings() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let groupY = try appClient.createGroup(with: userA)

        try appClient.follow(group: groupX, with: userB)
        try appClient.follow(group: groupY, with: userB)

        try app.test(
            .GET, "user_social/following_groups/\(userB.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(FollowingGroups.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }

    func testGetFollowers() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)

        try appClient.follow(group: groupX, with: userB)
        try appClient.follow(group: groupX, with: userA)

        try app.test(
            .GET, "user_social/group_followers/\(groupX.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(GroupFollowers.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }
    
    func testFollowUser() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let body = try! Stub.make(Endpoint.FollowUser.Request.self) {
            $0.set(\.id, value: userA.user.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/follow_user", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testUnfollowUser() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()

        try appClient.followUser(target: userA, with: userB)

        let body = try! Stub.make(Endpoint.UnfollowUser.Request.self) {
            $0.set(\.id, value: userA.user.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/unfollow_user", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }
    
    func testGetFollowingUsers() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser(role: .artist(Artist(part: "bass")))

        try appClient.followUser(target: userB, with: userA)
        try appClient.followUser(target: userC, with: userA)

        try app.test(
            .GET, "user_social/following_users/\(userA.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(FollowingUsers.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }

    func testGetUserFollowers() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser(role: .artist(Artist(part: "bass")))

        try appClient.followUser(target: userA, with: userB)
        try appClient.followUser(target: userA, with: userC)

        try app.test(
            .GET, "user_social/user_followers/\(userA.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(UserFollowers.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }

    func testGetUpcomingLives() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        _ = try appClient.createLive(hostGroup: groupX, with: userA)
        try appClient.follow(group: groupX, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/upcoming_lives?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetUpcomingLives.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }

    func testGetFollowingGroupFeeds() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        _ = try appClient.createArtistFeed(with: userA)
        try appClient.follow(group: groupX, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/group_feeds?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetFollowingGroupFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }

    func testGetFollowingGroupFeedsForDuplicatedArtist() throws {
        let artistA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let groupX = try appClient.createGroup(with: artistA)
        let groupY = try appClient.createGroup(with: artistA)
        _ = try appClient.createArtistFeed(with: artistA)

        let userB = try appClient.createUser()
        try appClient.follow(group: groupX, with: userB)
        try appClient.follow(group: groupY, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/group_feeds?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetFollowingGroupFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 1, String(describing: responseBody.items))
        }
    }
    
    func testGetFollowingUserFeeds() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        _ = try appClient.createUserFeed(with: userA)
        _ = try appClient.createUserFeed(with: userB)
        _ = try appClient.createUserFeed(with: userC)
        try appClient.followUser(target: userA, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/following_user_feeds?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetFollowingUserFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
        }
    }

    func testLikeLive() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let liveA = try appClient.createLive(hostGroup: groupX, with: userA)
        try appClient.follow(group: groupX, with: userB)

        try appClient.like(live: liveA, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/upcoming_lives?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetUpcomingLives.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
            let item = try XCTUnwrap(responseBody.items.first)
            XCTAssertTrue(item.isLiked)
        }
        try appClient.unlike(live: liveA, with: userB)
        try app.test(.GET, "user_social/upcoming_lives?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetUpcomingLives.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
            let item = try XCTUnwrap(responseBody.items.first)
            XCTAssertFalse(item.isLiked)
        }
    }
}
