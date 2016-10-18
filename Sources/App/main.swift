import Vapor
import VaporPostgreSQL
import Auth
import Turnstile
import TurnstileCrypto

let drop = Droplet()
try drop.addProvider(VaporPostgreSQL.Provider(dbname: "timezoner", user: "admin", password: "kofejn"))
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

        if user.authorizationToken == "" {
            user.authorizationToken = URandom().secureToken
        }

        try user.save()

        return user
    }
}

drop.resource("u", UserController())

drop.run()
