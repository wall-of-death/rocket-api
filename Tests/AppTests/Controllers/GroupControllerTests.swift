import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class GroupControllerTests: XCTestCase {
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

    func testUpdateGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let createdGroup = try appClient.createGroup(with: user)
        let newName = "a new group name"
        let body = try! Stub.make(EditGroup.Request.self) {
            $0.set(\.name, value: newName)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        try app.test(
            .POST, "groups/edit/\(createdGroup.id)", headers: appClient.makeHeaders(for: user),
            body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(EditGroup.Request.self)
            XCTAssertEqual(body.name, newName)
        }
    }

    func testDeleteGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let createdGroup = try appClient.createGroup(with: user)
        let body = try! Stub.make(DeleteGroup.Request.self) {
            $0.set(\.id, value: createdGroup.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        try app.test(
            .DELETE, "groups/delete/", headers: appClient.makeHeaders(for: user),
            body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }

        // try to delete twice
        try app.test(
            .DELETE, "groups/delete/", headers: appClient.makeHeaders(for: user),
            body: bodyData
        ) { res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }

        try app.test(.GET, "groups/\(createdGroup.id)", headers: appClient.makeHeaders(for: user)) {
            res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }
    }

    func testInviteForNonExistingGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let body = try! Stub.make(InviteGroup.Request.self)
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        try app.test(
            .POST, "groups/invite", headers: appClient.makeHeaders(for: user),
            body: bodyData
        ) { res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }
    }

    func testInviteForNonMemberGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let createdGroup = try appClient.createGroup(with: user)
        let nonMemberUser = try appClient.createUser()

        let body = try! Stub.make(InviteGroup.Request.self) {
            $0.set(\.groupId, value: createdGroup.id)
        }

        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        // Try to create an invitation for non-member group
        try app.test(
            .POST, "groups/invite", headers: appClient.makeHeaders(for: nonMemberUser),
            body: bodyData
        ) { res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }
    }

    func testGetGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let createdGroup = try appClient.createGroup(with: user)

        try app.test(.GET, "groups/\(createdGroup.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetGroup.Response.self)
            XCTAssertTrue(response.isMember)
        }
    }

    func testGetAllGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        _ = try appClient.createGroup(with: user)
        _ = try appClient.createGroup(with: user)
        _ = try appClient.createGroup(with: user)

        try app.test(.GET, "groups?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetAllGroups.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 3)
        }
    }

    func testGetMemberships() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupA = try appClient.createGroup(with: user)
        let groupB = try appClient.createGroup(with: user)

        try app.test(.GET, "groups/memberships/\(user.user.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetMemberships.Response.self)
            XCTAssertEqual(Set(response.map(\.id)), Set([groupA.id, groupB.id]))
        }
    }

    func testJoinWithInvalidInvitation() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        _ = try appClient.createGroup(with: user)

        let body = try! Stub.make(JoinGroup.Request.self) {
            let fakeInvitation = UUID()
            $0.set(\.invitationId, value: fakeInvitation.uuidString)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        // Try to join with invalid invitation
        try app.test(.POST, "groups/join", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testJoinTwiceWithSameInvitations() throws {
        // try to create without login
        try app.test(.POST, "groups") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let invitedUser = try appClient.createUser(role: .artist(Artist(part: "foo")))
        let encoder = appClient.encoder

        let createdGroup = try appClient.createGroup(with: user)
        let createdInvitation = try appClient.createInvitation(group: createdGroup, with: user)

        let body = try! Stub.make(JoinGroup.Request.self) {
            $0.set(\.invitationId, value: createdInvitation.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        try app.test(
            .POST, "groups/join", headers: appClient.makeHeaders(for: invitedUser), body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok)
            _ = try res.content.decode(JoinGroup.Response.self)
        }

        // Try to join again with the same invitation
        try app.test(
            .POST, "groups/join", headers: appClient.makeHeaders(for: invitedUser), body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testJoinTwiceWithDifferentInvitations() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let invitedUser = try appClient.createUser(role: .artist(Artist(part: "foo")))
        let createdGroup = try appClient.createGroup(with: user)
        let createdInvitation1 = try appClient.createInvitation(group: createdGroup, with: user)

        let body1 = try! Stub.make(JoinGroup.Request.self) {
            $0.set(\.invitationId, value: createdInvitation1.id)
        }
        let bodyData1 = try ByteBuffer(data: appClient.encoder.encode(body1))
        try app.test(
            .POST, "groups/join", headers: appClient.makeHeaders(for: invitedUser), body: bodyData1
        ) { res in
            XCTAssertEqual(res.status, .ok)
            _ = try res.content.decode(JoinGroup.Response.self)
        }

        let createdInvitation2 = try appClient.createInvitation(group: createdGroup, with: user)
        let body2 = try! Stub.make(JoinGroup.Request.self) {
            $0.set(\.invitationId, value: createdInvitation2.id)
        }
        let bodyData2 = try ByteBuffer(data: appClient.encoder.encode(body2))
        try app.test(
            .POST, "groups/join", headers: appClient.makeHeaders(for: invitedUser), body: bodyData2
        ) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testCreateArtistFeed() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        _ = try appClient.createGroup(with: user)

        let body = try! Stub.make(Endpoint.CreateArtistFeed.Request.self) {
            $0.set(\.feedType, value: .youtube(try! Stub.make()))
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "groups/create_feed", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.CreateArtistFeed.Response.self)
            XCTAssertEqual(responseBody.author.id, user.user.id)
        }
    }

    func testDeleteArtistFeeds() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupX = try appClient.createGroup(with: user)
        let feed = try appClient.createArtistFeed(with: user)
        let body = try! Stub.make(DeleteArtistFeed.Request.self) {
            $0.set(\.id, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.DELETE, "groups/delete_feed", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }

        // try to delete twice
        try app.test(.DELETE, "groups/delete_feed", headers: headers, body: bodyData) { res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }

        try app.test(.GET, "groups/\(groupX.id)/feeds?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetGroupFeed.Response.self)
            XCTAssertEqual(responseBody.items, [])
        }
    }

    func testGetGroupFeeds() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupX = try appClient.createGroup(with: user)
        let feed = try appClient.createArtistFeed(with: user)

        try app.test(.GET, "groups/\(groupX.id)/feeds?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetGroupFeed.Response.self)
            let firstItem = try XCTUnwrap(responseBody.items.first)
            XCTAssertEqual(firstItem.id, feed.id)
            XCTAssertEqual(firstItem.commentCount, 0)
        }
    }

    func testPostCommentOnFeed() throws {
        let artistX = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userY = try appClient.createUser(role: .fan(.init()))
        let feed = try appClient.createArtistFeed(with: artistX)

        let body = try! Stub.make(Endpoint.PostFeedComment.Request.self) {
            $0.set(\.feedId, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        let headers = appClient.makeHeaders(for: userY)
        try app.test(.POST, "user_social/feed_comment", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.PostFeedComment.Response.self)
            XCTAssertEqual(responseBody.author.id, userY.user.id)
        }

        try app.test(.GET, "user_social/feed_comment/\(feed.id)?page=1&per=10", headers: headers) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetFeedComments.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }
}
