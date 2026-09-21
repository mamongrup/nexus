import envoy
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute as a
import lustre/element.{text}
import nexus/calendar
import nexus/domain.{type Session}
import nexus/view.{el, hidden}
import pog

@external(erlang, "nexus_secrets", "seal")
pub fn seal(value: String, key: String, context: String) -> Result(String, Nil)

@external(erlang, "nexus_secrets", "open")
pub fn open(value: String, key: String, context: String) -> Result(String, Nil)

@external(erlang, "nexus_secrets", "valid_https")
fn valid_https(value: String) -> Bool

pub fn allowed(s: Session) {
  s.role == "owner" && list.contains(["nexus", "agency"], s.workspace)
}

pub fn save(
  db: pog.Connection,
  s: Session,
  key: String,
  value: String,
  version: Int,
  clear: Bool,
) -> String {
  case allowed(s) {
    False -> "forbidden"
    True -> {
      case calendar.rows(db, s, "select * from settings.list()") {
        Error(_) -> "failed"
        Ok(rows) -> {
          let row = list.find(rows, fn(r) { list.first(r) == Ok(key) })
          case row {
            Ok([_, _, _, kind, choices, _, _, _, _]) -> {
              case clear {
                True -> persist(db, s, key, "", version)
                False ->
                  case kind == "secret" && value == "" {
                    True -> "setting_unchanged"
                    False ->
                      case valid(kind, value, choices) {
                        False -> "invalid_setting"
                        True -> {
                          let encoded = case kind {
                            "secret" ->
                              envoy.get("NEXUS_CONFIG_KEY")
                              |> result.replace_error(Nil)
                              |> result.try(fn(k) {
                                seal(value, k, s.tenant <> ":" <> key)
                              })
                            _ -> Ok(value)
                          }
                          case encoded {
                            Ok(stored) -> persist(db, s, key, stored, version)
                            Error(_) -> "encryption_unavailable"
                          }
                        }
                      }
                  }
              }
            }
            _ -> "not_found"
          }
        }
      }
    }
  }
}

pub fn valid(kind: String, value: String, choices: String) {
  string.length(value) <= 4000
  && case kind {
    "https" -> value == "" || valid_https(value)
    "email" ->
      value == ""
      || {
        string.contains(value, "@")
        && !string.contains(value, " ")
        && !string.contains(value, "\n")
        && !string.contains(value, "\r")
      }
    "select" -> value == "" || list.contains(string.split(choices, ","), value)
    "number" ->
      value == ""
      || {
        string.length(value) <= 12
        && list.all(string.to_graphemes(value), fn(c) {
          list.contains(string.to_graphemes("0123456789"), c)
        })
      }
    _ -> True
  }
}

fn persist(
  db: pog.Connection,
  s: Session,
  key: String,
  value: String,
  version: Int,
) {
  calendar.command(db, s, "select settings.save($1,$2,$3)", [
    pog.text(key),
    pog.text(value),
    pog.int(version),
  ])
  |> result.unwrap("failed")
}

pub fn page(
  s: Session,
  csrf: String,
  rows: List(List(String)),
  message: String,
) {
  let sections =
    list.filter_map(rows, fn(row) {
      case row {
        [_, section, ..] -> Ok(section)
        _ -> Error(Nil)
      }
    })
    |> list.unique
  view.shell(
    s,
    csrf,
    "Sistem ayarları",
    el("div", "", [
      el("h1", "", [
        text(case s.workspace {
          "agency" -> "Acente POS ayarları"
          _ -> "Sistem ayarları"
        }),
      ]),
      el("p", "muted", [
        text(
          "Platform, ödeme geçidi (Sanal POS), API anahtarları ve entegrasyon yapılandırmalarını güvenle yönetin. Gizli değerler uçtan uca şifrelenir ve güvenli kasada saklanır.",
        ),
      ]),
      case message {
        "" -> text("")
        _ -> el("p", "notice", [text(message)])
      },
      ..list.map(sections, fn(group) {
        el("details", "panel settings-group", [
          el("summary", "panel-head", [text(group)]),
          ..list.map(
            list.filter(rows, fn(row) {
              case row {
                [_, section, ..] -> section == group
                _ -> False
              }
            }),
            fn(row) {
              case row {
                [
                  key,
                  section,
                  label,
                  kind,
                  choices,
                  description,
                  value,
                  state,
                  version,
                ] ->
                  element.element(
                    "form",
                    [
                      a.class("panel form editor-form"),
                      a.attribute("method", "post"),
                      a.attribute("action", "/admin/settings"),
                    ],
                    [
                      hidden("csrf", csrf),
                      hidden("key", key),
                      hidden("version", version),
                      el("p", "eyebrow", [text(section)]),
                      el("label", "field", [
                        text(label),
                        case kind {
                          "select" ->
                            element.element(
                              "select",
                              [a.name("value")],
                              list.map(
                                ["", ..string.split(choices, ",")],
                                fn(choice) {
                                  element.element(
                                    "option",
                                    [
                                      a.value(choice),
                                      ..case value == choice {
                                        True -> [
                                          a.attribute("selected", "selected"),
                                        ]
                                        False -> []
                                      }
                                    ],
                                    [
                                      text(case choice {
                                        "" -> "Seçilmedi"
                                        _ -> choice
                                      }),
                                    ],
                                  )
                                },
                              ),
                            )
                          _ ->
                            element.element(
                              "input",
                              [
                                a.name("value"),
                                a.value(value),
                                a.attribute("maxlength", "4000"),
                                a.attribute("autocomplete", "new-password"),
                                a.attribute("type", case kind {
                                  "secret" -> "password"
                                  "email" -> "email"
                                  "https" -> "url"
                                  _ -> "text"
                                }),
                              ],
                              [],
                            )
                        },
                      ]),
                      el("p", "muted", [text(description)]),
                      el("p", "muted", [
                        text(case state {
                          "saved" -> "Kayıtlı"
                          _ -> "Tanımlanmadı"
                        }),
                      ]),
                      el("div", "form-actions", [
                        element.element(
                          "button",
                          [
                            a.class("button primary"),
                            a.name("action"),
                            a.value("save"),
                          ],
                          [text("Kaydet")],
                        ),
                        element.element(
                          "button",
                          [
                            a.class("button small"),
                            a.name("action"),
                            a.value("clear"),
                            a.attribute("formnovalidate", "formnovalidate"),
                          ],
                          [text("Kayıtlı değeri sil")],
                        ),
                      ]),
                    ],
                  )
                _ -> text("")
              }
            },
          )
        ])
      })
    ]),
  )
}
