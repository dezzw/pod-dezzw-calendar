(require '[babashka.pods :as pods])

(println "Loading pod...")
(pods/load-pod ["./.build/release/pod-dezzw-calendar"])

(require '[calendar])

;; (def args {:calendar "工作"
;;            :title "测试事件"
;;            :start "2025-06-20 14:00"
;;            :end "2025-06-20 15:00"})

;; (println "Calling calendar/add-event...")
;; (calendar/add-event args) ;; ✅ 传 map，不是 json 字符串

(defn format-event [{:keys [id title start end]}]
  (str "🕒 时间：" start " - " end "\n"
       "📌 标题：" title "\n"
       "🆔 ID：" id))

(defn format-message [events]
  (if (seq events)
    (str "📅 日历事件列表：\n────────────────────────────\n"
         (clojure.string/join
          "\n────────────────────────────\n"
          (map format-event events)))
    "📭 没有找到任何事件。"))

(let [events (calendar/list-events {:calendar "工作"
                                    :start "2025-06-25 00:00"
                                    :end   "2025-06-26 00:00"})]
  (println (format-message events)))
