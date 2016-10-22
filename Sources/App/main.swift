import Vapor
import VaporPostgreSQL
import Auth
import Turnstile

let drop = Droplet()
// try drop.addProvider(VaporPostgreSQL.Provider(dbname: "timezoner", user: "admin", password: "kofejn"))
try drop.addProvider(VaporPostgreSQL.Provider(host: "ec2-54-75-232-66.eu-west-1.compute.amazonaws.com", port: 5432, dbname: "de3v0r08639v98", user: "tbjhbhptvugeeu", password: "9Zba7c5v_7Ah71SnPD41OzjL8x"))
drop.preparations = [User.self]

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
}


drop.resource("u", UserController())

drop.run()
