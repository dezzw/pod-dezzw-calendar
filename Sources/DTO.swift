import Foundation

public struct InvokeArgs: Codable {
    let calendar: String
    let title: String
    let start: String
    let end: String
}

public struct ListArgs: Codable {
    let calendar: String
    let start: String
    let end: String
}

public struct SearchArgs: Codable {
    let calendar: String
    let start: String
    let end: String
    let query: String
}

public struct EventDTO: Codable {
    public let id: String
    public let title: String
    public let start: String
    public let end: String
}
