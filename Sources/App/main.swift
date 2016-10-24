import Vapor
import VaporPostgreSQL
import Auth
import Turnstile
import HTTP
import Foundation

let drop = Droplet()

let host = drop.config["postgresql", "host"]?.string ?? "localhost"
let port = drop.config["postgresql", "port"]?.int ?? 5432
let dbname = drop.config["postgresql", "database"]?.string ?? "timezoner"
let password = drop.config["postgresql", "password"]?.string ?? "kofejn"
let user = drop.config["postgresql", "user"]?.string ?? "admin"

try drop.addProvider(VaporPostgreSQL.Provider(host: host, port: port, dbname: dbname, user: user, password: password))
drop.preparations = [User.self, Timezone.self]

let auth = AuthMiddleware(user: User.self)
drop.middleware.append(auth)

drop.group("users") { users in

    users.post("signup") { request in
        guard let username = request.data["username"]?.string, let password = request.data["password"]?.string else {
            throw Abort.custom(status: .badRequest, message: "Missing credentials")
        }

        let credentials = UsernamePassword(username: username, password: password)

        let authuser = try User.register(credentials: credentials)
        try request.auth.login(credentials)

        guard var user = authuser as? User else {
            throw Abort.serverError
        }

        try user.save()

        return user
    }

    users.post("signin") { request in
        guard let username = request.data["username"]?.string, let password = request.data["password"]?.string else {
            throw Abort.custom(status: .badRequest, message: "Missing credentials")
        }

        let credentials = UsernamePassword(username: username, password: password)
        try request.auth.login(credentials)

        guard let user = try request.auth.user() as? User else {
            throw Abort.serverError
        }

        return user
    }
}

let protectMiddleware = ProtectMiddleware(error: Abort.custom(status: .unauthorized, message: "Unauthorized"))

drop.grouped(BearerAuthenticationMiddleware(), protectMiddleware).group("me") { me in
    me.get() { request in
        return try request.user()
    }

    me.patch() { request in
        var user = try request.user()

        if let roleValue = request.data["role"]?.string, let role = User.Role(rawValue: roleValue) {
            user.role = role
            try user.save()
        }

        return user
    }

    me.group("timezones") { timezones in
        timezones.get() { request in
            let timezones = try request.user().timezones()

            return try JSON(node: timezones.all())
        }

        timezones.post() { request in
            guard let name = request.data["name"]?.string, let identifier = request.data["identifier"]?.string else {
                throw Abort.badRequest
            }

            if !TimeZone.knownTimeZoneIdentifiers.contains(identifier) {
                throw Abort.custom(status: .badRequest, message: "Invalid timezone identifier")
            }

            let user = try request.user()
            var timezone = try Timezone(name: name, identifier: identifier, user: user)
            try timezone.save()

            return timezone
        }

        timezones.put(":id") { request in
            let user = try request.user()

            guard let timezone_id = request.parameters["id"]?.int else {
                throw Abort.badRequest
            }

            let filtered = try user.timezones().all().filter { $0.id == Node.number(Node.Number(timezone_id)) }

            guard var timezone = filtered.first else {
                throw Abort.custom(status: .notFound, message: "Timezone wasn't found")
            }

            guard let name = request.data["name"]?.string, let identifier = request.data["identifier"]?.string else {
                throw Abort.badRequest
            }

            if !TimeZone.knownTimeZoneIdentifiers.contains(identifier) {
                throw Abort.custom(status: .badRequest, message: "Invalid timezone identifier")
            }

            timezone.identifier = identifier
            timezone.name = name
            try timezone.save()

            return timezone
        }

        timezones.delete(":id") { (request) in
            let user = try request.user()

            guard let timezone_id = request.parameters["id"]?.int else {
                throw Abort.badRequest
            }


            let filtered = try user.timezones().all().filter { $0.id == Node.number(Node.Number(timezone_id)) }

            if let timezone = filtered.first {
                try timezone.delete()
                return try Response(status: .ok, json: JSON(node: [:]))
            } else {
                throw Abort.custom(status: .notFound, message: "Timezone wasn't found")
            }
        }
    }
}

let managerMiddleware = RoleMiddleware(accessibleRoles: [.manager, .admin])
let adminMiddleware = RoleMiddleware(accessibleRoles: [.admin])
drop.grouped(BearerAuthenticationMiddleware(), protectMiddleware, managerMiddleware).group("users") { users in
    users.get() { request in
        return try JSON(node: User.all())
    }

    users.grouped(adminMiddleware).delete(User.self) { request, user in
        try user.delete()

        return try Response(status: .ok, json: JSON(node: [:]))
    }

    users.grouped(adminMiddleware).get(":id", "timezones") { (request) -> ResponseRepresentable in
        guard let id = request.parameters["id"]?.int, let user = try User.query().filter("id", id).first() else {
            throw Abort.badRequest
        }
        return try JSON(node: user.timezones().all())
    }

    users.grouped(adminMiddleware).post(User.self, "timezones") { (request, user) -> ResponseRepresentable in
        guard let name = request.data["name"]?.string, let identifier = request.data["identifier"]?.string else {
            throw Abort.badRequest
        }

        if !TimeZone.knownTimeZoneIdentifiers.contains(identifier) {
            throw Abort.custom(status: .badRequest, message: "Invalid timezone identifier")
        }

        var timezone = try Timezone(name: name, identifier: identifier, user: user)
        try timezone.save()

        return timezone
    }

    users.grouped(adminMiddleware).get(":id", "timezones", ":timezone_id") { (request) -> ResponseRepresentable in
        guard let id = request.parameters["id"]?.int, let user = try User.query().filter("id", id).first() else {
            throw Abort.badRequest
        }
        guard let timezone_id = request.parameters["timezone_id"]?.int else {
            throw Abort.badRequest
        }
        
        let filteredTimezones = try user.timezones().all().filter { $0.id == Node.number(Node.Number(timezone_id)) }

        if let first = filteredTimezones.first {
            return first
        } else {
            throw Abort.notFound
        }
    }

    users.grouped(adminMiddleware).delete(":id", "timezones", ":timezone_id") { (request) -> ResponseRepresentable in
        guard let id = request.parameters["id"]?.int, let user = try User.query().filter("id", id).first() else {
            throw Abort.badRequest
        }
        guard let timezone_id = request.parameters["timezone_id"]?.int else {
            throw Abort.badRequest
        }
        
        let filteredTimezones = try user.timezones().all().filter { $0.id == Node.number(Node.Number(timezone_id)) }

        if let first = filteredTimezones.first {
            try first.delete()
            return try Response(status: .ok, json: JSON(node: [:]))
        } else {
            throw Abort.notFound
        }
    }
}

drop.run()
