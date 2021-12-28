import FluentKit

struct CreateSocialTip: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let typeEnum = database.enum("social_tip_type")
            .case("group")
            .case("live")
            .create()
        return typeEnum.flatMap { typeEnum in
            database.schema(SocialTip.schema)
                .id()
                .field("tip", .int64, .required)
                .field("user_id", .uuid, .required)
                .foreignKey("user_id", references: User.schema, .id)
                .field("type", typeEnum, .required)
                .field("group_id", .uuid)
                .foreignKey("group_id", references: Group.schema, .id)
                .field("live_id", .uuid)
                .foreignKey("live_id", references: Live.schema, .id)
                .field("thrown_at", .datetime, .required)
                .create()
            
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(SocialTip.schema).delete()
            .and(database.enum("social_tip_type").delete())
            .map { _ in }
    }
}
