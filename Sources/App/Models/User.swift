//
//  User.swift
//  timezoner
//
//  Created by Aleš Kocur on 17/10/2016.
//
//

import Vapor
import Fluent
import Foundation
import Auth
import Turnstile
import HTTP
import TurnstileCrypto

final class User: Model {
    var id: Node?
    var username: String
    var password: String
    var authorizationToken: String = URandom().secureToken

    var exists: Bool = false

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        username = try node.extract("username")
        password = try node.extract("password")
        authorizationToken = try node.extract("token")
    }

    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "username": username,
            "password": password,
            "token": authorizationToken
            ])
    }
}

extension User: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create("users") { users in
            users.id()
            users.string("username")
            users.string("password")
            users.string("token")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("users")
    }
}

extension User: Auth.User {

    static func register(credentials: Credentials) throws -> Auth.User {
        switch credentials {
        case let credentials as UsernamePassword:

            if try User.query().filter("username", credentials.username).first() != nil {
                throw Abort.custom(status: .badRequest, message: "Already registered")
            }

            var user = User(username: credentials.username, password: credentials.password)
            try user.save()
            return user
        default:
            throw AccountTakenError()
        }
    }

    static func authenticate(credentials: Credentials) throws -> Auth.User {

        switch credentials {
        case let credentials as UsernamePassword:
            guard let user = try User.query().filter("username", credentials.username).first() else {
                throw Abort.badRequest
            }

            if user.password != credentials.password {
                throw Abort.custom(status: .forbidden, message: "Wrong password")
            }

            return user
            
        default:
            throw UnsupportedCredentialsError()
        }
    }
}
