//
//  Timezone.swift
//  timezoner
//
//  Created by Aleš Kocur on 22/10/2016.
//
//

import Foundation
import Vapor
import Fluent

final class Timezone: Model {

    var id: Node?
    let secondsFromGMT: Int
    let name: String
    let userId: Node

    var exists: Bool = false

    init(name: String, secondsFromGMT: Int, user: User) throws {
        self.name = name
        self.secondsFromGMT = secondsFromGMT

        if let id = user.id {
            self.userId = id
        } else {
            throw Abort.serverError
        }
    }

    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        secondsFromGMT = try node.extract("sec_gmt")
        name = try node.extract("name")
        userId = try node.extract("user_id")
    }

    func makeNode(context: Context) throws -> Node {
         return try Node(node: [
            "id": id,
            "name": name,
            "sec_gmt": secondsFromGMT,
            "user_id": userId
            ])
    }

    static func prepare(_ database: Database) throws {
        try database.create("timezones") { timezones in
            timezones.id()
            timezones.string("name")
            timezones.int("sec_gmt")
            timezones.parent(User.self, optional: false)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete("timezones")
    }
}
