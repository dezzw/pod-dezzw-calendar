import Darwin
import Foundation

// MARK: - Debug Logger
func log(_ msg: String) {
    if let data = ("[pod-log] " + msg + "\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

func describeBencode() -> Bencode {
    return .dict([
        "format": .string("json"),
        "namespaces": .list([
            .dict([
                "name": .string("calendar"),
                "vars": .list([
                    .dict(["name": .string("add-event")]),
                    .dict(["name": .string("list-events")]),
                ]),
            ])
        ]),
        "ops": .dict(["shutdown": .dict([:])]),
    ])
}

func writeBencode(_ value: Bencode) {
    let encoded = value.encode()
    FileHandle.standardOutput.write(encoded)
    fflush(stdout)
}

func encodeJSON<T: Encodable>(_ obj: T) -> String {
    let data = try! JSONEncoder().encode(obj)
    return String(data: data, encoding: .utf8)!
}

// MARK: - Main Loop
while true {
    var buffer = Data()
    var parsed: Bencode? = nil

    while true {
        let byte = FileHandle.standardInput.readData(ofLength: 1)
        if byte.isEmpty { break }  // EOF
        buffer.append(byte)

        var parser = BencodeParser(buffer)
        parsed = parser.parse()

        if parsed != nil {
            break  // ✅ 成功解析，跳出读取循环
        }
    }

    guard let top = parsed else {
        log("❌ Failed to parse complete bencode message")
        continue
    }

    guard case .dict(let msg) = top else {
        log("parsed value not dict: \(top)")
        continue
    }

    log("parsed msg keys:")
    for (k, v) in msg {
        log("  \(k): \(v)")
    }

    let op = msg["op"]?.string ?? "nil"
    log("received op: \(op)")

    switch op {
    case "describe":
        log("sending describe response")
        writeBencode(describeBencode())

    case "invoke":
        guard let id = msg["id"]?.string else {
            log("missing id")
            continue
        }

        guard let opName = msg["var"]?.string else {
            log("Missing var (operation name)")
            continue
        }

        guard let argsStr = msg["args"]?.string else {
            log("missing or non-string args")
            continue
        }
        log("argsStr: \(argsStr)")

        guard let argsData = argsStr.data(using: .utf8) else {
            log("argsStr is not valid UTF-8")
            continue
        }

        switch opName {

        case "calendar/add-event":

            do {
                let argsArray = try JSONDecoder().decode([InvokeArgs].self, from: argsData)
                let args = argsArray.first!
                log("decoded args: \(args)")

                try addEvent(args: args)
                writeBencode(
                    .dict([
                        "id": .string(id),
                        "status": .list([.string("done")]),
                        "value": .string("\"ok\""),
                    ]))

            } catch {
                log("addEvent or decode failed: \(error.localizedDescription)")
                writeBencode(
                    .dict([
                        "id": .string(id),
                        "status": .list([.string("done"), .string("error")]),
                        "ex-message": .string(error.localizedDescription),
                    ]))
            }

        case "calendar/list-events":
            do {
                let argsArray = try JSONDecoder().decode([ListArgs].self, from: argsData)
                guard let args = argsArray.first else {
                    log("Missing arguments")
                    continue
                }

                let events = try listEvents(args: args)
                writeBencode(
                    .dict([
                        "id": .string(id),
                        "status": .list([.string("done")]),
                        "value": .string(encodeJSON(events)),
                    ]))
            } catch {
                log("listEvent or decode failed: \(error.localizedDescription)")
                writeBencode(
                    .dict([
                        "id": .string(id),
                        "status": .list([.string("done"), .string("error")]),
                        "ex-message": .string(error.localizedDescription),
                    ]))
            }

        case "calendar/search-events":
            let argsArray = try JSONDecoder().decode([SearchArgs].self, from: argsData)
            guard let args = argsArray.first else {
                log("Missing arguments")
                continue
            }
            let result = try searchEvents(args: args)
            writeSuccess(id: id, value: result)

        default:
            log("Unknown var: \(opName)")

        }

    case "shutdown":
        log("received shutdown")
        exit(0)

    default:
        log("unknown op: \(op)")
    }
}
