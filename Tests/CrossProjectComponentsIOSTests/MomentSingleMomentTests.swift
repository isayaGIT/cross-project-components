import XCTest
@testable import CrossProjectComponentsIOS

final class MomentSingleMomentTests: XCTestCase {
    private let author = MomentSingleMoment.Person(id: "author", name: "莓莓")

    func testModelPreservesPostContentAndInteractionState() {
        let liker = MomentSingleMoment.Person(id: "liker", name: "小明")
        let comment = MomentSingleMoment.Comment(id: "comment", author: liker, text: "好看！")
        let model = MomentSingleMoment.Model(author: author, text: "周末快乐", location: "公园", isLikedByCurrentUser: true, likes: [liker], comments: [comment])
        XCTAssertEqual(model.author.name, "莓莓")
        XCTAssertEqual(model.text, "周末快乐")
        XCTAssertEqual(model.location, "公园")
        XCTAssertTrue(model.isLikedByCurrentUser)
        XCTAssertEqual(model.likes.map(\.id), ["liker"])
        XCTAssertEqual(model.comments.first?.text, "好看！")
    }

    func testMediaListIsCappedAtNineForMomentsGrid() {
        let media = (0..<12).compactMap { index in
            URL(string: "https://example.com/\(index).jpg").map { MomentSingleMoment.Media(id: "photo-\(index)", url: $0) }
        }
        let model = MomentSingleMoment.Model(author: author, text: "Nine grid", media: media)
        XCTAssertEqual(model.media.count, 9)
        XCTAssertEqual(model.media.first?.id, "photo-0")
        XCTAssertEqual(model.media.last?.id, "photo-8")
    }

    func testCommentSupportsReplyTargetAndOptionalTimestamp() {
        let replyTarget = MomentSingleMoment.Person(id: "target", name: "小红")
        let comment = MomentSingleMoment.Comment(author: author, text: "回复内容", replyTo: replyTarget)
        XCTAssertEqual(comment.replyTo?.id, "target")
        XCTAssertNil(comment.createdAt)
    }
}
