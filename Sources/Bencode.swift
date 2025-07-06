import Foundation

public enum Bencode: CustomStringConvertible {
    case int(Int)
    case string(String)
    case list([Bencode])
    case dict([String: Bencode])

    public var description: String {
        switch self {
        case .int(let n):
            return "i\(n)e"
        case .string(let s):
            return "\(s.utf8.count):\(s)"
        case .list(let l):
            return "l" + l.map { $0.description }.joined() + "e"
        case .dict(let d):
            return "d"
                + d.sorted(by: { $0.key < $1.key }).map {
                    Bencode.string($0.key).description + $0.value.description
                }.joined() + "e"
        }
    }

    public func encode() -> Data {
        return description.data(using: .utf8) ?? Data()
    }

    public var string: String? {
        if case .string(let s) = self { return s } else { return nil }
    }

    public var dict: [String: Bencode]? {
        if case .dict(let d) = self { return d } else { return nil }
    }
}

// MARK: - Bencode Minimal Decoder (for simple key-values)
struct BencodeParser {
    let data: [UInt8]
    var pos: Int = 0

    public init(_ data: Data) {
        self.data = [UInt8](data)
    }

    public mutating func parse() -> Bencode? {
        guard pos < data.count else { return nil }
        return parseBencode()
    }

    public mutating func parseBencode() -> Bencode? {
        guard let char = peek() else { return nil }
        switch char {
        case "i":
            return parseInt()
        case "l":
            return parseList()
        case "d":
            return parseDict()
        case "0"..."9":
            return parseString()
        default:
            return nil
        }
    }

    mutating func parseInt() -> Bencode? {
        _ = next()  // consume 'i'
        var numStr = ""
        while let c = peek(), c != "e" {
            numStr.append(c)
            _ = next()
        }
        _ = next()  // consume 'e'
        if let n = Int(numStr) {
            return .int(n)
        }
        return nil
    }

    mutating func parseString() -> Bencode? {
        var lenStr = ""
        while let c = peek(), c.isNumber {
            lenStr.append(c)
            _ = next()
        }
        guard next() == ":", let len = Int(lenStr), pos + len <= data.count else {
            return nil
        }
        let bytes = data[pos..<pos + len]
        pos += len
        if let str = String(bytes: bytes, encoding: .utf8) {
            return .string(str)
        }
        return nil
    }

    mutating func parseList() -> Bencode? {
        _ = next()  // consume 'l'
        var list: [Bencode] = []
        while peek() != "e" {
            guard let item = parseBencode() else { return nil }
            list.append(item)
        }
        _ = next()  // consume 'e'
        return .list(list)
    }

    mutating func parseDict() -> Bencode? {
        _ = next()  // consume 'd'
        var dict: [String: Bencode] = [:]
        while peek() != "e" {
            guard let keyB = parseString(), case let .string(key) = keyB else { return nil }
            guard let val = parseBencode() else { return nil }
            dict[key] = val
        }
        _ = next()  // consume 'e'
        return .dict(dict)
    }

    func peek() -> Character? {
        guard pos < data.count else { return nil }
        return Character(UnicodeScalar(data[pos]))
    }

    mutating func next() -> Character? {
        guard pos < data.count else { return nil }
        defer { pos += 1 }
        return Character(UnicodeScalar(data[pos]))
    }
}
