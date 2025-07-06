# Calendar Pod for Babashka

这是一个用 Swift 实现的 babashka pod，提供日历和时间相关的功能。

## 功能

- `calendar/current-date` - 获取当前日期 (YYYY-MM-DD 格式)
- `calendar/current-time` - 获取当前时间 (HH:mm:ss 格式)  
- `calendar/current-datetime` - 获取当前日期和时间 (YYYY-MM-DD HH:mm:ss 格式)
- `calendar/add-days` - 在指定日期上增加天数
- `calendar/day-of-week` - 获取指定日期是星期几

## 构建

确保你已经安装了 Swift：

```bash
cd pods/pod-dezzw-calendar
swift build
```

## 使用示例

```clojure
#!/usr/bin/env bb

(require '[babashka.pods :as pods])

;; 加载 calendar pod
(pods/load-pod ["swift" "run" "--package-path" "pods/pod-dezzw-calendar"])

;; 获取当前日期
(println "今天是:" (calendar/current-date))

;; 获取当前时间
(println "现在时间:" (calendar/current-time))

;; 计算未来日期
(println "7天后:" (calendar/add-days "2025-06-18" 7))

;; 获取星期几
(println "2025-06-18 是:" (calendar/day-of-week "2025-06-18"))
```

## 测试

运行测试脚本：

```bash
bb test-calendar-pod.clj
```

## 协议实现

这个 pod 实现了标准的 babashka pod protocol：

1. 使用 bencode 格式进行消息序列化
2. 支持 `describe` 操作来列出可用函数
3. 支持 `invoke` 操作来调用函数
4. 支持 `shutdown` 操作来清理资源

## 目录结构

```
pods/pod-dezzw-calendar/
├── Package.swift          # Swift 包配置
├── Sources/
│   ├── main.swift        # 主程序和 pod protocol 实现
│   └── Bencode.swift     # Bencode 编码/解码
└── test.clj              # 测试用例
```
