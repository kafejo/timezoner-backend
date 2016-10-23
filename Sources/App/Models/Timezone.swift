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
    var identifier: String
    var name: String
    var userId: Node

    var exists: Bool = false

    init(name: String, identifier: String, user: User) throws {
        self.name = name
        self.identifier = identifier

        if let id = user.id {
            self.userId = id
        } else {
            throw Abort.serverError
        }
    }

    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        identifier = try node.extract("identifier")
        name = try node.extract("name")
        userId = try node.extract("user_id")
    }

    func makeNode(context: Context) throws -> Node {
         return try Node(node: [
            "id": id,
            "name": name,
            "identifier": identifier,
            "user_id": userId
            ])
    }

    static func prepare(_ database: Database) throws {
        try database.create("timezones") { timezones in
            timezones.id()
            timezones.string("name")
            timezones.string("identifier")
            timezones.parent(User.self, optional: false)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete("timezones")
    }
}
