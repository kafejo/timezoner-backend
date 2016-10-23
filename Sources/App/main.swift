import Vapor
import VaporPostgreSQL
import Auth
import Turnstile

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
        let user = try request.user()

        if let roleValue = request.data["role"]?.string, let role = User.Role(rawValue: roleValue) {
            user.role = role
        }

        return user
    }

    me.group("timezones") { timezones in
        timezones.get() { request in
            let timezones = try request.user().timezones()

            return try JSON(node: timezones.all())
        }

        timezones.post() { request in
            guard let name = request.data["name"]?.string, let secondsFromGMT = request.data["sec_gmt"]?.int else {
                throw Abort.badRequest
            }

            let user = try request.user()
            var timezone = try Timezone(name: name, secondsFromGMT: secondsFromGMT, user: user)
            try timezone.save()

            return timezone
        }
    }
}

drop.grouped(BearerAuthenticationMiddleware(), protectMiddleware).group("users") { me in
    
}

drop.run()
