import NIO

public protocol UserRepository {
    func create(
        cognitoId: User.CognitoID, email: String, name: String,
        biography: String?, thumbnailURL: String?, role: Domain.RoleProperties
    ) -> EventLoopFuture<Domain.User>
    func find(by foreignId: User.CognitoID) -> EventLoopFuture<User?>
    func isExists(by id: User.ID) -> EventLoopFuture<Bool>
}
