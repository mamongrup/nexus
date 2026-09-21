import gleam/list
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el}

pub fn page(s: Session, csrf: String, rows: List(List(String))) {
  view.shell(
    s,
    csrf,
    "İletişim mesajları",
    el("div", "", [
      el("h1", "", [text("İletişim mesajları")]),
      el("p", "muted", [
        text(
          "Siteden gelen son 200 mesaj. Kuyrukta durumu e-postanın teslim edildiği anlamına gelmez.",
        ),
      ]),
      case rows {
        [] -> el("p", "panel editor-form", [text("Henüz mesaj yok.")])
        _ -> text("")
      },
      ..list.map(rows, fn(r) {
        case r {
          [_, name, email, message, recipient, status, created] ->
            el("article", "panel editor-form", [
              el("h2", "", [text(name)]),
              el("p", "", [text(email)]),
              el("p", "description", [text(message)]),
              el("p", "muted", [
                text("Alıcı: " <> recipient <> " · " <> created),
              ]),
              el("span", "badge", [
                text(case status {
                  "queued" -> "Gönderim kuyruğunda"
                  "sent" -> "Gönderildi"
                  "failed" -> "Gönderim başarısız"
                  _ -> status
                }),
              ]),
            ])
          _ -> text("")
        }
      })
    ]),
  )
}
