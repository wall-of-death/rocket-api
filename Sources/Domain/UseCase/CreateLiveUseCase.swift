import Foundation
import NIO

public struct CreateLiveUseCase: UseCase {
    public typealias Request = (
        user: User, input: Endpoint.CreateLive.Request
    )
    public typealias Response = Live

    public enum Error: Swift.Error {
        case fanCannotCreateLive
        case isNotMemberOfHostGroup
    }

    public let groupRepository: GroupRepository
    public let liveRepository: LiveRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        liveRepository: LiveRepository,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.liveRepository = liveRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        guard case .artist = request.user.role else {
            return eventLoop.makeFailedFuture(Error.fanCannotCreateLive)
        }
        let input = request.input
        let precondition = groupRepository.isMember(
            of: input.hostGroupId, member: request.user.id
        )
        .flatMapThrowing {
            guard $0 else { throw Error.isNotMemberOfHostGroup }
            return
        }
        return precondition.flatMap {
            liveRepository.create(
                title: input.title, style: input.style,
                artworkURL: input.artworkURL,
                hostGroupId: input.hostGroupId,
                authorId: request.user.id,
                openAt: input.openAt, startAt: input.startAt, endAt: input.endAt,
                performerGroups: input.performerGroupIds
            )
        }
    }
}
