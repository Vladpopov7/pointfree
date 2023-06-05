

//"Dynamic member lookup" allows you to enhance a type with the ability to accept dot-syntax calls for properties that don’t live directly on the type.

struct User {
    var id: Int
    var name: String
    var bio: String
//    var isAdmin: Bool
}

@dynamicMemberLookup
struct Admin {
    var user: User

    subscript<A>(dynamicMember keyPath: KeyPath<User, A>) -> A {
        self.user[keyPath: keyPath]
    }
}

let adminUser = Admin(user: User(id: 1, name: "Blob", bio: "Blobbed around the world"))
let nonAdminUser = User(id: 2, name: "Blob Jr.", bio: "Blobbed around the world")

func doAdminStuff(admin: Admin) {
//    guard user.isAdmin else { return }
    // we can get name with help of "dynaimc member lookup"
    print("Do admin stuff for \(admin.name)")
}

doAdminStuff(admin: adminUser)
//doAdminStuff(user: nonAdminUser)

adminUser.id
adminUser.name
