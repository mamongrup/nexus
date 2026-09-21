import lustre/attribute as a
import lustre/element.{text}
import nexus/icons
import nexus/view.{doc, el}

pub fn page(res_id: String, existing_checkin: List(String), notice: String) {
  doc(
    "Mobil Online Check-In & Akıllı Giriş | NEXUS",
    el("main", "checkin-container p-4", [
      el("div", "max-w-md mx-auto bg-white rounded shadow-lg p-4 border", [
        // Otel & Temassız Giriş Başlığı
        el("div", "text-center mb-4 pb-3 border-bottom", [
          el("span", "badge primary mb-1", [
            text("TEMASSIZ GİRİŞ · MOBİL CHECK-IN · AKILLI KİLİT"),
          ]),
          el("h2", "font-bold text-xl flex items-center justify-center gap-2", [
            icons.hotel(),
            text("NEXUS Mobil Check-In"),
          ]),
          el("p", "text-muted text-sm", [
            text("Rezervasyon No: "),
            el("strong", "text-primary", [text(res_id)]),
          ]),
        ]),

        case notice {
          "" -> text("")
          _ -> el("div", "notice mb-3", [text(notice)])
        },

        // Eğer daha önce check-in yapılmışsa Kapı Şifresi Kartı göster
        case existing_checkin {
          [_rid, name, _tc, _phone, _email, eta, pin, dt] ->
            el("div", "checkin-success-box text-center p-4 bg-light rounded", [
              el(
                "div",
                "text-success mb-2 text-3xl flex items-center justify-center",
                [icons.check()],
              ),
              el("h3", "font-bold text-lg mb-1", [
                text("Online Check-In Başarılı!"),
              ]),
              el("p", "text-muted text-sm mb-3", [
                text("Sayın "),
                el("strong", "", [text(name)]),
                text(
                  ", tesisimize hoş geldiniz. Resepsiyonda beklemeden doğrudan odanıza geçebilirsiniz.",
                ),
              ]),

              // Dijital Kapı Anahtarı / PIN Kartı
              el(
                "div",
                "p-3 bg-white rounded border border-primary mb-3 shadow-sm",
                [
                  el(
                    "span",
                    "badge dark mb-1 flex items-center justify-center gap-1",
                    [
                      icons.key(),
                      text(" DİJİTAL ODA KAPI ŞİFRENİZ"),
                    ],
                  ),
                  el(
                    "div",
                    "font-mono font-bold text-2xl text-primary letter-spacing-2 my-2",
                    [
                      text(pin),
                    ],
                  ),
                  el("p", "text-xs text-muted", [
                    text(
                      "Bu PIN kodu kapıdaki elektronik kilit paneline girildiğinde oda kapınız açılacaktır.",
                    ),
                  ]),
                ],
              ),

              // Konaklama Detayları
              el("div", "text-left text-sm bg-white p-3 rounded border mb-3", [
                el("p", "mb-1", [
                  el("strong", "", [text("Varış Saatiniz: ")]),
                  text(eta),
                ]),
                el("p", "mb-1", [
                  el("strong", "", [text("Check-in Tarihi: ")]),
                  text(dt),
                ]),
                el("p", "mb-1", [
                  el("strong", "", [text("Wi-Fi Ağı: ")]),
                  text("NEXUS-LUXURY-GUEST"),
                ]),
                el("p", "", [
                  el("strong", "", [text("Wi-Fi Şifresi: ")]),
                  text("nexus2026"),
                ]),
              ]),

              el("p", "text-xs text-muted", [
                text(
                  "Herhangi bir sorunuz olursa lütfen WhatsApp concierge hattımızdan bize ulaşın.",
                ),
              ]),
            ])

          _ ->
            // Check-in Formu
            el("div", "", [
              el("p", "text-sm text-muted mb-3 text-center", [
                text(
                  "Hızlı ve temassız giriş için lütfen bilgilerinizi onaylayınız. Tamamlandığında oda kapı şifreniz ve giriş talimatları anında ekranınızda oluşturulacaktır.",
                ),
              ]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute("action", "/checkin/" <> res_id),
                  a.class("form"),
                ],
                [
                  el("div", "form-group mb-2", [
                    element.element("label", [], [text("Ad Soyad *")]),
                    element.element(
                      "input",
                      [
                        a.name("name"),
                        a.class("input"),
                        a.attribute("required", "required"),
                        a.attribute("placeholder", "Örn: Mehmet Özkan"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group mb-2", [
                    element.element("label", [], [
                      text("TC Kimlik No / Pasaport No *"),
                    ]),
                    element.element(
                      "input",
                      [
                        a.name("tc"),
                        a.class("input"),
                        a.attribute("required", "required"),
                        a.attribute(
                          "placeholder",
                          "11 Haneli TCKN veya Pasaport",
                        ),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-row-2 mb-2", [
                    el("div", "form-group", [
                      element.element("label", [], [text("Telefon Numarası *")]),
                      element.element(
                        "input",
                        [
                          a.name("phone"),
                          a.class("input"),
                          a.attribute("required", "required"),
                          a.attribute("placeholder", "+905321112233"),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [text("E-posta")]),
                      element.element(
                        "input",
                        [
                          a.name("email"),
                          a.class("input"),
                          a.attribute("type", "email"),
                          a.attribute("placeholder", "ornek@mail.com"),
                        ],
                        [],
                      ),
                    ]),
                  ]),
                  el("div", "form-row-2 mb-2", [
                    el("div", "form-group", [
                      element.element("label", [], [text("Tahmini Varış Saati")]),
                      element.element(
                        "input",
                        [
                          a.name("eta"),
                          a.class("input"),
                          a.attribute("type", "time"),
                          a.attribute("value", "14:00"),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [text("Özel İstek")]),
                      element.element(
                        "input",
                        [
                          a.name("requests"),
                          a.class("input"),
                          a.attribute(
                            "placeholder",
                            "Late check-in, bebek yatağı",
                          ),
                        ],
                        [],
                      ),
                    ]),
                  ]),

                  // KVKK ve Dijital İmza Onayı
                  el(
                    "div",
                    "p-2 bg-light rounded text-xs text-muted mb-3 border",
                    [
                      el(
                        "label",
                        "flex items-center gap-2 cursor-pointer mb-2",
                        [
                          element.element(
                            "input",
                            [
                              a.attribute("type", "checkbox"),
                              a.attribute("required", "required"),
                              a.attribute("checked", "checked"),
                            ],
                            [],
                          ),
                          text(
                            "KVKK aydınlatma metnini ve konaklama kurallarını okudum, kabul ediyorum.",
                          ),
                        ],
                      ),
                      el("label", "flex items-center gap-2 cursor-pointer", [
                        element.element(
                          "input",
                          [
                            a.attribute("type", "checkbox"),
                            a.name("sig"),
                            a.attribute("required", "required"),
                            a.attribute("checked", "checked"),
                            a.value("VERIFIED_SIGNATURE"),
                          ],
                          [],
                        ),
                        text(
                          "Yukarıdaki kimlik bilgilerinin doğruluğunu dijital olarak imzalıyorum.",
                        ),
                      ]),
                    ],
                  ),

                  element.element(
                    "button",
                    [
                      a.class(
                        "button primary w-100 py-3 font-bold text-md flex items-center justify-center gap-2",
                      ),
                    ],
                    [
                      icons.check(),
                      text("Girişi Tamamla & Kapı Şifremi Al"),
                    ],
                  ),
                ],
              ),
            ])
        },
      ]),
    ]),
  )
}
