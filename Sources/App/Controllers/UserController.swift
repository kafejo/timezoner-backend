//
//  UserController.swift
//  timezoner
//
//  Created by Aleš Kocur on 17/10/2016.
//
//

import Vapor
import HTTP

final class UserController: ResourceRepresentable {
    func index(request: Request) throws -> ResponseRepresentable {
        return try User.all().makeNode().converted(to: JSON.self)
    }

//    func create(request: Request) throws -> ResponseRepresentable {
//
//        guard let email = request.data["email"]?.string else {
//            throw Abort.badRequest
//        }
//
//        var user = User(email: email, password: "blah")
//        try user.save()
//        return user
//    }

    func makeResource() -> Resource<User> {
        return Resource(
            index: index
        )
    }
}
