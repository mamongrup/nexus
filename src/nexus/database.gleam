import gleam/bool
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import nexus/domain.{type Draft, type Property, type Session, Property, Session}
import pog

fn text_decoder() {
  decode.optional(
    decode.one_of(decode.string, or: [
      decode.int |> decode.map(int.to_string),
      decode.float |> decode.map(float.to_string),
      decode.bool |> decode.map(bool.to_string),
    ]),
  )
  |> decode.map(fn(opt) { option.unwrap(opt, "") })
}

pub fn row5() {
  use c0 <- decode.field(0, text_decoder())
  use c1 <- decode.field(1, text_decoder())
  use c2 <- decode.field(2, text_decoder())
  use c3 <- decode.field(3, text_decoder())
  use c4 <- decode.field(4, text_decoder())
  decode.success([c0, c1, c2, c3, c4])
}

pub fn row6() {
  use c0 <- decode.field(0, text_decoder())
  use c1 <- decode.field(1, text_decoder())
  use c2 <- decode.field(2, text_decoder())
  use c3 <- decode.field(3, text_decoder())
  use c4 <- decode.field(4, text_decoder())
  use c5 <- decode.field(5, text_decoder())
  decode.success([c0, c1, c2, c3, c4, c5])
}

pub fn row7() {
  use c0 <- decode.field(0, text_decoder())
  use c1 <- decode.field(1, text_decoder())
  use c2 <- decode.field(2, text_decoder())
  use c3 <- decode.field(3, text_decoder())
  use c4 <- decode.field(4, text_decoder())
  use c5 <- decode.field(5, text_decoder())
  use c6 <- decode.field(6, text_decoder())
  decode.success([c0, c1, c2, c3, c4, c5, c6])
}

pub fn row8() {
  use c0 <- decode.field(0, text_decoder())
  use c1 <- decode.field(1, text_decoder())
  use c2 <- decode.field(2, text_decoder())
  use c3 <- decode.field(3, text_decoder())
  use c4 <- decode.field(4, text_decoder())
  use c5 <- decode.field(5, text_decoder())
  use c6 <- decode.field(6, text_decoder())
  use c7 <- decode.field(7, text_decoder())
  decode.success([c0, c1, c2, c3, c4, c5, c6, c7])
}

pub fn row9() {
  use c0 <- decode.field(0, text_decoder())
  use c1 <- decode.field(1, text_decoder())
  use c2 <- decode.field(2, text_decoder())
  use c3 <- decode.field(3, text_decoder())
  use c4 <- decode.field(4, text_decoder())
  use c5 <- decode.field(5, text_decoder())
  use c6 <- decode.field(6, text_decoder())
  use c7 <- decode.field(7, text_decoder())
  use c8 <- decode.field(8, text_decoder())
  decode.success([c0, c1, c2, c3, c4, c5, c6, c7, c8])
}

pub fn row10() {
  use c0 <- decode.field(0, text_decoder())
  use c1 <- decode.field(1, text_decoder())
  use c2 <- decode.field(2, text_decoder())
  use c3 <- decode.field(3, text_decoder())
  use c4 <- decode.field(4, text_decoder())
  use c5 <- decode.field(5, text_decoder())
  use c6 <- decode.field(6, text_decoder())
  use c7 <- decode.field(7, text_decoder())
  use c8 <- decode.field(8, text_decoder())
  use c9 <- decode.field(9, text_decoder())
  decode.success([c0, c1, c2, c3, c4, c5, c6, c7, c8, c9])
}

pub fn row13() {
  use c0 <- decode.field(0, text_decoder())
  use c1 <- decode.field(1, text_decoder())
  use c2 <- decode.field(2, text_decoder())
  use c3 <- decode.field(3, text_decoder())
  use c4 <- decode.field(4, text_decoder())
  use c5 <- decode.field(5, text_decoder())
  use c6 <- decode.field(6, text_decoder())
  use c7 <- decode.field(7, text_decoder())
  use c8 <- decode.field(8, text_decoder())
  use c9 <- decode.field(9, text_decoder())
  use c10 <- decode.field(10, text_decoder())
  use c11 <- decode.field(11, text_decoder())
  use c12 <- decode.field(12, text_decoder())
  decode.success([c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12])
}

fn property_decoder() {
  use id <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use locality <- decode.field(2, decode.string)
  use description <- decode.field(3, decode.string)
  use capacity <- decode.field(4, decode.int)
  use amount <- decode.field(5, decode.int)
  use currency <- decode.field(6, decode.string)
  use status <- decode.field(7, decode.string)
  use version <- decode.field(8, decode.int)
  use moderation_status <- decode.field(9, decode.string)
  use review_note <- decode.field(10, decode.string)
  use freshness <- decode.field(11, decode.string)
  decode.success(Property(
    id,
    title,
    locality,
    description,
    capacity,
    amount,
    currency,
    status,
    version,
    moderation_status,
    review_note,
    freshness,
  ))
}

fn session_decoder() {
  use tenant <- decode.field(0, decode.string)
  use id <- decode.field(1, decode.string)
  use name <- decode.field(2, decode.string)
  use role <- decode.field(3, decode.string)
  use workspace <- decode.field(4, decode.string)
  decode.success(Session(tenant, id, name, role, workspace))
}

pub fn session(db: pog.Connection, token: String) -> Result(Session, Nil) {
  use rows <- result.try(
    pog.query("select * from auth.session($1)")
    |> pog.parameter(pog.text(token))
    |> pog.returning(session_decoder())
    |> pog.execute(db)
    |> result.replace_error(Nil),
  )
  list.first(rows.rows)
}

pub fn login(
  db: pog.Connection,
  email: String,
  password: String,
  token: String,
) -> Bool {
  case
    pog.query("select * from auth.login($1,$2,$3)")
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(password))
    |> pog.parameter(pog.text(token))
    |> pog.returning(decode.dynamic)
    |> pog.execute(db)
  {
    Ok(r) -> r.count == 1
    Error(_) -> False
  }
}

pub fn logout(db: pog.Connection, token: String) {
  pog.query("select auth.logout($1)")
  |> pog.parameter(pog.text(token))
  |> pog.execute(db)
}

pub fn healthy(db: pog.Connection) -> Bool {
  case pog.query("select 1") |> pog.execute(db) {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Rotasyon penceresi durumu: her sır için (secret, state, age_hours,
/// window_hours) — SECRET_KEY_BASE ve NEXUS_CONFIG_KEY tek sorguda.
/// Migration 187 fonksiyonlarindan okunur; format
/// scripts/check-secret-hygiene.ps1'in kullandigi pipe bicimiyle aynidir.
/// DB hatasi veya fonksiyon yoksa Error — /health servis durumunu
/// etkilemeden raporlamayi "unavailable" yapar.
pub fn rotation_window(
  db: pog.Connection,
) -> Result(List(#(String, String, String, String)), Nil) {
  case
    pog.query(
      "select s.name || '|' || "
      <> "events.rotation_window_state(s.name) || '|' || "
      <> "coalesce(events.latest_rotation_age_hours(s.name)::text, '-') || '|' || "
      <> "events.rotation_window_hours(s.name)::text "
      <> "from (values ('SECRET_KEY_BASE'), ('NEXUS_CONFIG_KEY')) as s(name)",
    )
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  {
    Ok(r) -> Ok(parse_window_rows(r.rows, []))
    Error(_) -> Error(Nil)
  }
}

fn parse_window_rows(
  rows: List(String),
  acc: List(#(String, String, String, String)),
) -> List(#(String, String, String, String)) {
  case rows {
    [] -> list.reverse(acc)
    [row, ..rest] -> {
      let parsed = case string.split(row, "|") {
        [secret, state, age, window] -> Ok(#(secret, state, age, window))
        _ -> Error(Nil)
      }
      case parsed {
        Ok(tuple) -> parse_window_rows(rest, [tuple, ..acc])
        Error(_) -> parse_window_rows(rest, acc)
      }
    }
  }
}

pub fn published(db: pog.Connection) -> Result(List(Property), Nil) {
  pog.query("select * from catalog.published()")
  |> pog.returning(property_decoder())
  |> pog.execute(db)
  |> result.map(fn(r) { r.rows })
  |> result.replace_error(Nil)
}

pub fn scope(
  db: pog.Connection,
  s: Session,
  run: fn(pog.Connection) -> Result(a, pog.QueryError),
) -> Result(a, Nil) {
  pog.transaction(db, fn(tx) {
    use _ <- result.try(
      pog.query(
        "select set_config('app.tenant_id',$1,true),set_config('app.actor_id',$2,true)",
      )
      |> pog.parameter(pog.text(s.tenant))
      |> pog.parameter(pog.text(s.user_id))
      |> pog.execute(tx),
    )
    run(tx)
  })
  |> result.replace_error(Nil)
}

pub fn properties(
  db: pog.Connection,
  s: Session,
) -> Result(List(Property), Nil) {
  case s.workspace {
    "nexus" ->
      scope(db, s, fn(tx) {
        pog.query("select * from catalog.all_properties_for_admin()")
        |> pog.returning(property_decoder())
        |> pog.execute(tx)
        |> result.map(fn(r) { r.rows })
      })
    _ ->
      scope(db, s, fn(tx) {
        pog.query(
          "select id::text,title,locality,description,capacity,nightly_minor,currency::text,status,version,moderation_status,review_note,case when last_confirmed_at is null then 'never' when last_confirmed_at<now()-interval '30 days' then 'stale' else 'current' end from catalog.properties order by updated_at desc limit 100",
        )
        |> pog.returning(property_decoder())
        |> pog.execute(tx)
        |> result.map(fn(r) { r.rows })
      })
  }
}

pub fn create(db: pog.Connection, s: Session, d: Draft) -> Result(Nil, Nil) {
  create_with_seo(db, s, d, "", "")
}

pub fn create_with_seo(
  db: pog.Connection,
  s: Session,
  d: Draft,
  seo_title: String,
  seo_description: String,
) -> Result(Nil, Nil) {
  create_category(
    db,
    s,
    d,
    seo_title,
    seo_description,
    // holiday_home is the canonical code for villa, apart and the other
    // standalone property types. Writing "villa" would store a retired code
    // that the supplier approval trigger cannot match.
    "holiday_home",
    "{}",
    "[]",
    False,
  )
}

pub fn create_category(
  db: pog.Connection,
  s: Session,
  d: Draft,
  seo_title: String,
  seo_description: String,
  category: String,
  attributes: String,
  media: String,
  managed: Bool,
) -> Result(Nil, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "insert into catalog.properties(tenant_id,title,locality,description,capacity,nightly_minor,currency,seo_title,seo_description,category_code,attributes,media,schema_managed) values($1::uuid,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12::jsonb,$13)",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(d.title))
    |> pog.parameter(pog.text(d.locality))
    |> pog.parameter(pog.text(d.description))
    |> pog.parameter(pog.int(d.capacity))
    |> pog.parameter(pog.int(d.nightly_minor))
    |> pog.parameter(pog.text(d.currency))
    |> pog.parameter(pog.text(seo_title))
    |> pog.parameter(pog.text(seo_description))
    |> pog.parameter(pog.text(category))
    |> pog.parameter(pog.text(attributes))
    |> pog.parameter(pog.text(media))
    |> pog.parameter(pog.bool(managed))
    |> pog.execute(tx)
    |> result.map(fn(_) { Nil })
  })
}

pub fn publish(
  db: pog.Connection,
  s: Session,
  id: String,
  version: Int,
  status: String,
) -> Result(Bool, Nil) {
  case s.workspace {
    "nexus" ->
      scope(db, s, fn(tx) {
        pog.query("select catalog.admin_publish($1, $2, $3)")
        |> pog.parameter(pog.text(id))
        |> pog.parameter(pog.int(version))
        |> pog.parameter(pog.text(status))
        |> pog.returning(decode.field(0, decode.bool, decode.success))
        |> pog.execute(tx)
        |> result.map(fn(r) { list.first(r.rows) |> result.unwrap(False) })
      })
    _ ->
      scope(db, s, fn(tx) {
        pog.query(
          "update catalog.properties set status=$1,version=version+1,updated_at=now() where id::text=$2 and version=$3",
        )
        |> pog.parameter(pog.text(status))
        |> pog.parameter(pog.text(id))
        |> pog.parameter(pog.int(version))
        |> pog.execute(tx)
        |> result.map(fn(r) { r.count == 1 })
      })
  }
}

pub fn marketplace_listings(
  db: pog.Connection,
  q: String,
  category: String,
  locality: String,
) -> Result(List(List(String)), Nil) {
  pog.query("select * from catalog.marketplace_listings($1, $2, $3)")
  |> pog.parameter(pog.text(q))
  |> pog.parameter(pog.text(category))
  |> pog.parameter(pog.text(locality))
  |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { r.rows })
  |> result.replace_error(Nil)
}

pub fn marketplace_listing_detail(
  db: pog.Connection,
  id: String,
) -> Result(List(String), Nil) {
  pog.query("select * from catalog.marketplace_listing_detail($1)")
  |> pog.parameter(pog.text(id))
  |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap([]) })
  |> result.replace_error(Nil)
}

pub fn create_marketplace_booking(
  db: pog.Connection,
  prop_id: String,
  guest_name: String,
  guest_email: String,
  guest_phone: String,
  tc: String,
  check_in: String,
  check_out: String,
  guests: Int,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.create_marketplace_booking($1, $2, $3, $4, $5, $6, $7, $8)::text",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(guest_name))
  |> pog.parameter(pog.text(guest_email))
  |> pog.parameter(pog.text(guest_phone))
  |> pog.parameter(pog.text(tc))
  |> pog.parameter(pog.text(check_in))
  |> pog.parameter(pog.text(check_out))
  |> pog.parameter(pog.int(guests))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("") })
  |> result.replace_error(Nil)
}

pub fn listing_modules_cockpit(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(String), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_modules_cockpit($1)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap([]) })
  })
}

pub fn listing_pms_units(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_pms_units($1)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn update_unit_status(
  db: pog.Connection,
  s: Session,
  unit_id: String,
  occupancy: String,
  housekeeping: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("select catalog.update_unit_status($1, $2, $3)")
    |> pog.parameter(pog.text(unit_id))
    |> pog.parameter(pog.text(occupancy))
    |> pog.parameter(pog.text(housekeeping))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn listing_kbs_records(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select array[id::text, guest_name, tc_passport, room_code, check_in::text, check_out::text, police_status, dispatch_code, to_char(dispatched_at, 'DD.MM.YYYY HH24:MI')] from catalog.property_kbs_records where property_id::text = $1 order by dispatched_at desc",
    )
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn dispatch_kbs(
  db: pog.Connection,
  prop_id: String,
  guest: String,
  tc: String,
  room: String,
  check_in: String,
  check_out: String,
) -> Result(String, Nil) {
  pog.query("select catalog.dispatch_kbs($1, $2, $3, $4, $5, $6)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(guest))
  |> pog.parameter(pog.text(tc))
  |> pog.parameter(pog.text(room))
  |> pog.parameter(pog.text(check_in))
  |> pog.parameter(pog.text(check_out))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_ota_channels(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select array[id::text, channel_name, remote_id, sync_status, to_char(last_sync_at, 'DD.MM.YYYY HH24:MI'), auto_sync::text] from catalog.property_ota_channels where property_id::text = $1 order by channel_name",
    )
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn sync_ota_channel(
  db: pog.Connection,
  prop_id: String,
  channel: String,
) -> Result(String, Nil) {
  pog.query("select catalog.sync_ota_channel($1, $2)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(channel))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_whatsapp_messages(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select array[id::text, recipient_phone, template_name, content, delivery_status, to_char(sent_at, 'DD.MM.YYYY HH24:MI')] from catalog.property_whatsapp_messages where property_id::text = $1 order by sent_at desc",
    )
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn send_guest_whatsapp(
  db: pog.Connection,
  prop_id: String,
  phone: String,
  tpl: String,
  content: String,
) -> Result(String, Nil) {
  pog.query("select catalog.send_guest_whatsapp($1, $2, $3, $4)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(phone))
  |> pog.parameter(pog.text(tpl))
  |> pog.parameter(pog.text(content))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_invoices(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select array[id::text, invoice_no, recipient_title, (total_minor / 100)::text, (kdv_minor / 100)::text, (konaklama_minor / 100)::text, currency, gib_status, to_char(issued_at, 'DD.MM.YYYY HH24:MI')] from catalog.property_invoices where property_id::text = $1 order by issued_at desc",
    )
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn generate_listing_invoice(
  db: pog.Connection,
  prop_id: String,
  recipient: String,
  amount_minor: Int,
) -> Result(String, Nil) {
  pog.query("select catalog.generate_listing_invoice($1, $2, $3)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(recipient))
  |> pog.parameter(pog.int(amount_minor))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_b2b_agencies(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_b2b_agencies($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn add_b2b_agency(
  db: pog.Connection,
  prop_id: String,
  agency_name: String,
  agency_code: String,
  commission_pct: Float,
  allotment: Int,
  net_rate: Int,
) -> Result(String, Nil) {
  pog.query("select catalog.add_b2b_agency($1::uuid, $2, $3, $4, $5, $6)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(agency_name))
  |> pog.parameter(pog.text(agency_code))
  |> pog.parameter(pog.float(commission_pct))
  |> pog.parameter(pog.int(allotment))
  |> pog.parameter(pog.int(net_rate))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn toggle_agency_stop_sale(
  db: pog.Connection,
  agency_id: String,
) -> Result(String, Nil) {
  pog.query("select catalog.toggle_agency_stop_sale($1::uuid)")
  |> pog.parameter(pog.text(agency_id))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_rate_parity(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_rate_parity($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn run_rate_parity_check(
  db: pog.Connection,
  prop_id: String,
) -> Result(String, Nil) {
  pog.query("select catalog.run_rate_parity_check($1::uuid)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_maintenance_tickets(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_maintenance_tickets($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn create_maintenance_ticket(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
  issue_title: String,
  priority: String,
  technician: String,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.create_maintenance_ticket($1::uuid, $2, $3, $4, $5)",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.parameter(pog.text(issue_title))
  |> pog.parameter(pog.text(priority))
  |> pog.parameter(pog.text(technician))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn resolve_maintenance_ticket(
  db: pog.Connection,
  ticket_id: String,
) -> Result(String, Nil) {
  pog.query("select catalog.resolve_maintenance_ticket($1::uuid)")
  |> pog.parameter(pog.text(ticket_id))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_cash_desk(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_cash_desk($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn add_cash_transaction(
  db: pog.Connection,
  prop_id: String,
  trans_type: String,
  currency: String,
  payment_method: String,
  amount_minor: Int,
  room_code: String,
  notes: String,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.add_cash_transaction($1::uuid, $2, $3, $4, $5, $6, $7)",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(trans_type))
  |> pog.parameter(pog.text(currency))
  |> pog.parameter(pog.text(payment_method))
  |> pog.parameter(pog.int(amount_minor))
  |> pog.parameter(pog.text(room_code))
  |> pog.parameter(pog.text(notes))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_transport_notifications(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_transport_notifications($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn dispatch_transport_notification(
  db: pog.Connection,
  prop_id: String,
  system_name: String,
  plate_code: String,
  driver_name: String,
  guest_name: String,
  tc_passport: String,
  destination: String,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.dispatch_transport_notification($1::uuid, $2, $3, $4, $5, $6, $7)",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(system_name))
  |> pog.parameter(pog.text(plate_code))
  |> pog.parameter(pog.text(driver_name))
  |> pog.parameter(pog.text(guest_name))
  |> pog.parameter(pog.text(tc_passport))
  |> pog.parameter(pog.text(destination))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_guest_concierge_requests(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select * from catalog.listing_guest_concierge_requests($1::uuid)",
    )
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn create_guest_concierge_request(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
  guest_name: String,
  request_type: String,
  details: String,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.create_guest_concierge_request($1::uuid, $2, $3, $4, $5)",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.parameter(pog.text(guest_name))
  |> pog.parameter(pog.text(request_type))
  |> pog.parameter(pog.text(details))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn resolve_concierge_request(
  db: pog.Connection,
  request_id: String,
) -> Result(String, Nil) {
  pog.query("select catalog.resolve_concierge_request($1::uuid)")
  |> pog.parameter(pog.text(request_id))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

// Elite Pillar 1: Live Room Rack
pub fn listing_room_rack(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_room_rack($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn quick_check_in(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
  guest_name: String,
  nights: Int,
  rate_minor: Int,
) -> Result(String, Nil) {
  pog.query("select catalog.quick_check_in($1::uuid, $2, $3, $4, $5)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.parameter(pog.text(guest_name))
  |> pog.parameter(pog.int(nights))
  |> pog.parameter(pog.int(rate_minor))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn quick_check_out(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
) -> Result(String, Nil) {
  pog.query("select catalog.quick_check_out($1::uuid, $2)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn mark_room_clean(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
) -> Result(String, Nil) {
  pog.query("select catalog.mark_room_clean($1::uuid, $2)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

// Elite Pillar 2: Room Folios & Billing
pub fn listing_room_folios(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_room_folios($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn post_room_folio_charge(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
  department: String,
  description: String,
  amount_minor: Int,
) -> Result(String, Nil) {
  pog.query("select catalog.post_room_folio_charge($1::uuid, $2, $3, $4, $5)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.parameter(pog.text(department))
  |> pog.parameter(pog.text(description))
  |> pog.parameter(pog.int(amount_minor))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn settle_room_folio(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
  payment_method: String,
) -> Result(String, Nil) {
  pog.query("select catalog.settle_room_folio($1::uuid, $2, $3)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.parameter(pog.text(payment_method))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

// Elite Pillar 3: Night Audit
pub fn listing_night_audits(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_night_audits($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn run_night_audit(
  db: pog.Connection,
  prop_id: String,
) -> Result(String, Nil) {
  pog.query("select catalog.run_night_audit($1::uuid)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

// Elite Pillar 4: Yield Autopilot & Promo Codes
pub fn listing_yield_rules(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_yield_rules($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn add_yield_rule(
  db: pog.Connection,
  prop_id: String,
  rule_type: String,
  threshold_val: Float,
  adjustment_pct: Float,
) -> Result(String, Nil) {
  pog.query("select catalog.add_yield_rule($1::uuid, $2, $3, $4)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(rule_type))
  |> pog.parameter(pog.float(threshold_val))
  |> pog.parameter(pog.float(adjustment_pct))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn toggle_yield_rule(
  db: pog.Connection,
  rule_id: String,
) -> Result(String, Nil) {
  pog.query("select catalog.toggle_yield_rule($1::uuid)")
  |> pog.parameter(pog.text(rule_id))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn evaluate_yield_autopilot(
  db: pog.Connection,
  prop_id: String,
) -> Result(String, Nil) {
  pog.query("select catalog.evaluate_yield_autopilot($1::uuid)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

pub fn listing_promo_codes(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_promo_codes($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn add_promo_code(
  db: pog.Connection,
  prop_id: String,
  code: String,
  discount_type: String,
  discount_val: Int,
  max_uses: Int,
) -> Result(String, Nil) {
  pog.query("select catalog.add_promo_code($1::uuid, $2, $3, $4, $5)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(code))
  |> pog.parameter(pog.text(discount_type))
  |> pog.parameter(pog.int(discount_val))
  |> pog.parameter(pog.int(max_uses))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

// Elite Pillar 5: Automated Guest Messaging
pub fn listing_automated_messages(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.listing_automated_messages($1::uuid)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn dispatch_guest_automated_message(
  db: pog.Connection,
  prop_id: String,
  room_code: String,
  guest_name: String,
  phone: String,
  trigger_type: String,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.dispatch_guest_automated_message($1::uuid, $2, $3, $4, $5)",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(room_code))
  |> pog.parameter(pog.text(guest_name))
  |> pog.parameter(pog.text(phone))
  |> pog.parameter(pog.text(trigger_type))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  |> result.replace_error(Nil)
}

// =============================================================================
// Supplier Campaigns & Discounts Engine
// =============================================================================

pub fn supplier_campaigns(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.supplier_campaigns()")
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn create_campaign(
  db: pog.Connection,
  s: Session,
  name: String,
  ctype: String,
  discount_type: String,
  discount_val: Int,
  prop_id: String,
  cat_code: String,
  promo_code: String,
  min_stay: Int,
  days_adv: Int,
  start_date: String,
  end_date: String,
  usage_limit: Int,
  badge: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select catalog.create_campaign($1, $2, $3, $4::bigint, nullif($5, '')::uuid, nullif($6, ''), nullif($7, ''), $8, $9, nullif($10, '')::date, nullif($11, '')::date, $12, $13)",
    )
    |> pog.parameter(pog.text(name))
    |> pog.parameter(pog.text(ctype))
    |> pog.parameter(pog.text(discount_type))
    |> pog.parameter(pog.int(discount_val))
    |> pog.parameter(pog.text(prop_id))
    |> pog.parameter(pog.text(cat_code))
    |> pog.parameter(pog.text(promo_code))
    |> pog.parameter(pog.int(min_stay))
    |> pog.parameter(pog.int(days_adv))
    |> pog.parameter(pog.text(start_date))
    |> pog.parameter(pog.text(end_date))
    |> pog.parameter(pog.int(usage_limit))
    |> pog.parameter(pog.text(badge))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn toggle_campaign(
  db: pog.Connection,
  s: Session,
  campaign_id: String,
  active: Bool,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("select catalog.toggle_campaign($1::uuid, $2)")
    |> pog.parameter(pog.text(campaign_id))
    |> pog.parameter(pog.bool(active))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn delete_campaign(
  db: pog.Connection,
  s: Session,
  campaign_id: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("select catalog.delete_campaign($1::uuid)")
    |> pog.parameter(pog.text(campaign_id))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn listing_active_campaigns(
  db: pog.Connection,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  pog.query("select * from catalog.listing_active_campaigns($1::uuid)")
  |> pog.parameter(pog.text(prop_id))
  |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { r.rows })
  |> result.replace_error(Nil)
}

pub fn calculate_booking_discount(
  db: pog.Connection,
  prop_id: String,
  promo_code: String,
  check_in: String,
  check_out: String,
  base_price_minor: Int,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.calculate_booking_discount(nullif($1, '')::uuid, nullif($2, ''), nullif($3, '')::date, nullif($4, '')::date, $5::bigint)::text",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(promo_code))
  |> pog.parameter(pog.text(check_in))
  |> pog.parameter(pog.text(check_out))
  |> pog.parameter(pog.int(base_price_minor))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("{}") })
  |> result.replace_error(Nil)
}

pub fn create_marketplace_booking_with_promo(
  db: pog.Connection,
  prop_id: String,
  guest_name: String,
  guest_email: String,
  guest_phone: String,
  tc: String,
  check_in: String,
  check_out: String,
  guests: Int,
  promo_code: String,
) -> Result(String, Nil) {
  pog.query(
    "select catalog.create_marketplace_booking($1, $2, $3, $4, $5, $6, $7, $8, $9)::text",
  )
  |> pog.parameter(pog.text(prop_id))
  |> pog.parameter(pog.text(guest_name))
  |> pog.parameter(pog.text(guest_email))
  |> pog.parameter(pog.text(guest_phone))
  |> pog.parameter(pog.text(tc))
  |> pog.parameter(pog.text(check_in))
  |> pog.parameter(pog.text(check_out))
  |> pog.parameter(pog.int(guests))
  |> pog.parameter(pog.text(promo_code))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("") })
  |> result.replace_error(Nil)
}

pub fn activate_module_bundle(
  db: pog.Connection,
  s: Session,
  bundle: String,
  supplier_id: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("select onboarding.activate_module_bundle($1, nullif($2, ''))")
    |> pog.parameter(pog.text(bundle))
    |> pog.parameter(pog.text(supplier_id))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn toggle_supplier_module(
  db: pog.Connection,
  s: Session,
  module_code: String,
  status: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("select onboarding.toggle_supplier_module($1, $2)")
    |> pog.parameter(pog.text(module_code))
    |> pog.parameter(pog.text(status))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn all_modules_catalog_for_session(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from onboarding.all_modules_catalog_for_session()")
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn get_or_create_primary_property(
  db: pog.Connection,
  s: Session,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("select catalog.get_or_create_primary_property()")
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("") })
  })
}

// ─── AI Pricing Research ──────────────────────────────

/// Emsal ilanları çeker (aynı kategori, benzer kapasite, aynı para birimi)
pub fn comparable_listings(
  db: pog.Connection,
  s: Session,
  listing_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select * from catalog.comparable_listings_for_display($1::uuid, 15)",
    )
    |> pog.parameter(pog.text(listing_id))
    |> pog.returning(row8())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

/// Fiyat istatistiklerini hesaplar
pub fn price_stats(
  db: pog.Connection,
  s: Session,
  listing_id: String,
) -> Result(List(String), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.compute_price_stats($1::uuid)")
    |> pog.parameter(pog.text(listing_id))
    |> pog.returning(row5())
    |> pog.execute(tx)
    |> result.map(fn(r) {
      list.first(r.rows) |> result.unwrap(["0", "0", "0", "0", "0"])
    })
  })
}

/// Fiyat analizini kaydeder
pub fn save_pricing_analysis(
  db: pog.Connection,
  s: Session,
  listing_id: String,
  target_category: String,
  target_locality: String,
  target_capacity: Int,
  target_price: Int,
  target_currency: String,
  comparable_count: Int,
  avg_price: Int,
  min_price: Int,
  max_price: Int,
  median_price: Int,
  recommended_min: Int,
  recommended_max: Int,
  optimal_price: Int,
  confidence_pct: Int,
  verdict: String,
  reasoning: String,
  comparables_json: String,
) -> Result(Nil, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select catalog.save_pricing_analysis($1::uuid, $2::uuid, $3, $4, $5::int, $6::int, $7, $8::int, $9::int, $10::int, $11::int, $12::int, $13::int, $14::int, $15::int, $16::int, $17, $18, $19)",
    )
    |> pog.parameter(pog.text(listing_id))
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(target_category))
    |> pog.parameter(pog.text(target_locality))
    |> pog.parameter(pog.int(target_capacity))
    |> pog.parameter(pog.int(target_price))
    |> pog.parameter(pog.text(target_currency))
    |> pog.parameter(pog.int(comparable_count))
    |> pog.parameter(pog.int(avg_price))
    |> pog.parameter(pog.int(min_price))
    |> pog.parameter(pog.int(max_price))
    |> pog.parameter(pog.int(median_price))
    |> pog.parameter(pog.int(recommended_min))
    |> pog.parameter(pog.int(recommended_max))
    |> pog.parameter(pog.int(optimal_price))
    |> pog.parameter(pog.int(confidence_pct))
    |> pog.parameter(pog.text(verdict))
    |> pog.parameter(pog.text(reasoning))
    |> pog.parameter(pog.text(comparables_json))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(_) { Nil })
  })
}

/// Geçmiş fiyat analizlerini çeker
pub fn pricing_analysis_history(
  db: pog.Connection,
  s: Session,
  listing_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from catalog.pricing_analysis_history($1::uuid, 10)")
    |> pog.parameter(pog.text(listing_id))
    |> pog.returning(row13())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

/// İlanın fiyatını günceller (AI önerisini uygula)
pub fn apply_suggested_price(
  db: pog.Connection,
  s: Session,
  listing_id: String,
  new_price: Int,
) -> Result(Nil, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "UPDATE catalog.properties SET nightly_minor = $1 WHERE id = $2::uuid",
    )
    |> pog.parameter(pog.int(new_price))
    |> pog.parameter(pog.text(listing_id))
    |> pog.execute(tx)
    |> result.map(fn(_) { Nil })
  })
}

// ─── Kurumsal Modül 1: Muhasebe & Kasa/Banka ─────────

pub fn accounting_summary(
  db: pog.Connection,
  s: Session,
) -> Result(List(String), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from accounting.financial_summary()")
    |> pog.returning(row6())
    |> pog.execute(tx)
    |> result.map(fn(r) {
      list.first(r.rows) |> result.unwrap(["0", "0", "0", "0", "0", "0"])
    })
  })
}

pub fn accounting_transactions(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from accounting.list_transactions(50)")
    |> pog.returning(row10())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn add_transaction(
  db: pog.Connection,
  s: Session,
  tx_type: String,
  category: String,
  title: String,
  description: String,
  amount_minor: Int,
  currency: String,
  payment_method: String,
  invoice_no: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "WITH ensure_cat AS (
         INSERT INTO accounting.categories(code, category_type, name)
         VALUES ($3, $2, $3)
         ON CONFLICT (code) DO NOTHING
       )
       INSERT INTO accounting.transactions(tenant_id, tx_type, category, title, description, amount_minor, currency, payment_method, invoice_no, created_by)
       VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id::text",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(tx_type))
    |> pog.parameter(pog.text(category))
    |> pog.parameter(pog.text(title))
    |> pog.parameter(pog.text(description))
    |> pog.parameter(pog.int(amount_minor))
    |> pog.parameter(pog.text(currency))
    |> pog.parameter(pog.text(payment_method))
    |> pog.parameter(pog.text(invoice_no))
    |> pog.parameter(pog.text(s.name))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn delete_transaction(
  db: pog.Connection,
  s: Session,
  id: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("DELETE FROM accounting.transactions WHERE id = $1::uuid")
    |> pog.parameter(pog.text(id))
    |> pog.execute(tx)
    |> result.map(fn(_) { "ok" })
  })
}

// ─── Kurumsal Modül 2: Sosyal Medya Pazarlama ─────────

pub fn social_posts(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from marketing.list_posts(30)")
    |> pog.returning(row9())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn create_social_post(
  db: pog.Connection,
  s: Session,
  platform: String,
  title: String,
  caption: String,
  media_url: String,
  link_url: String,
  status: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "INSERT INTO marketing.social_posts(tenant_id, platform, title, caption, media_url, link_url, status)
       VALUES ($1::uuid, $2, $3, $4, $5, $6, $7) RETURNING id::text",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(platform))
    |> pog.parameter(pog.text(title))
    |> pog.parameter(pog.text(caption))
    |> pog.parameter(pog.text(media_url))
    |> pog.parameter(pog.text(link_url))
    |> pog.parameter(pog.text(status))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn delete_social_post(
  db: pog.Connection,
  s: Session,
  id: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("DELETE FROM marketing.social_posts WHERE id = $1::uuid")
    |> pog.parameter(pog.text(id))
    |> pog.execute(tx)
    |> result.map(fn(_) { "ok" })
  })
}

// ─── Kurumsal Modül 3: İnsan Kaynakları & Bordro ───────

pub fn hr_employees(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from hr.list_employees(50)")
    |> pog.returning(row9())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn hr_candidates(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from hr.list_candidates(30)")
    |> pog.returning(row8())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn hr_payrolls(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query("select * from hr.list_payrolls(50)")
    |> pog.returning(row9())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn add_employee(
  db: pog.Connection,
  s: Session,
  full_name: String,
  national_id: String,
  phone: String,
  email: String,
  department: String,
  position_title: String,
  salary_minor: Int,
  currency: String,
  iban: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "INSERT INTO hr.employees(tenant_id, full_name, national_id, phone, email, department, position_title, salary_minor, currency, iban)
       VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id::text",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(full_name))
    |> pog.parameter(pog.text(national_id))
    |> pog.parameter(pog.text(phone))
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(department))
    |> pog.parameter(pog.text(position_title))
    |> pog.parameter(pog.int(salary_minor))
    |> pog.parameter(pog.text(currency))
    |> pog.parameter(pog.text(iban))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn add_candidate(
  db: pog.Connection,
  s: Session,
  candidate_name: String,
  position_applied: String,
  phone: String,
  email: String,
  stage: String,
  interview_date: String,
  notes: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "INSERT INTO hr.recruitment_candidates(tenant_id, candidate_name, position_applied, phone, email, stage, interview_date, notes)
       VALUES ($1::uuid, $2, $3, $4, $5, $6, nullif($7, '')::date, $8) RETURNING id::text",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(candidate_name))
    |> pog.parameter(pog.text(position_applied))
    |> pog.parameter(pog.text(phone))
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(stage))
    |> pog.parameter(pog.text(interview_date))
    |> pog.parameter(pog.text(notes))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn add_payroll(
  db: pog.Connection,
  s: Session,
  employee_id: String,
  payment_type: String,
  amount_minor: Int,
  currency: String,
  reference_no: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "INSERT INTO hr.payroll_records(tenant_id, employee_id, payment_type, amount_minor, currency, reference_no)
       VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6) RETURNING id::text",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(employee_id))
    |> pog.parameter(pog.text(payment_type))
    |> pog.parameter(pog.int(amount_minor))
    |> pog.parameter(pog.text(currency))
    |> pog.parameter(pog.text(reference_no))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

// ─── Kurumsal Modül 4: Kat Hizmetleri & Oda Takibi ────

pub fn housekeeping_tasks(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select * from catalog.list_housekeeping_tasks(nullif($1, '')::uuid, 50)",
    )
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(row7())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn room_maintenance_tickets(
  db: pog.Connection,
  s: Session,
  prop_id: String,
) -> Result(List(List(String)), Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "select * from catalog.list_maintenance_tickets(nullif($1, '')::uuid, 30)",
    )
    |> pog.parameter(pog.text(prop_id))
    |> pog.returning(row8())
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn add_housekeeping_task(
  db: pog.Connection,
  s: Session,
  prop_id: String,
  room_code: String,
  assigned_staff: String,
  task_type: String,
  notes: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "INSERT INTO catalog.housekeeping_tasks(tenant_id, property_id, room_code, assigned_staff, task_type, notes)
       VALUES ($1::uuid, nullif($2, '')::uuid, $3, $4, $5, $6) RETURNING id::text",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(prop_id))
    |> pog.parameter(pog.text(room_code))
    |> pog.parameter(pog.text(assigned_staff))
    |> pog.parameter(pog.text(task_type))
    |> pog.parameter(pog.text(notes))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn update_housekeeping_task_status(
  db: pog.Connection,
  s: Session,
  task_id: String,
  status: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "UPDATE catalog.housekeeping_tasks
       SET status = $1, completed_at = CASE WHEN $1 IN ('completed', 'inspected') THEN now() ELSE completed_at END
       WHERE id = $2::uuid",
    )
    |> pog.parameter(pog.text(status))
    |> pog.parameter(pog.text(task_id))
    |> pog.execute(tx)
    |> result.map(fn(_) { "ok" })
  })
}

pub fn add_maintenance_ticket(
  db: pog.Connection,
  s: Session,
  prop_id: String,
  room_code: String,
  issue_title: String,
  description: String,
  priority: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "INSERT INTO catalog.room_maintenance_tickets(tenant_id, property_id, room_code, issue_title, description, priority, reported_by)
       VALUES ($1::uuid, nullif($2, '')::uuid, $3, $4, $5, $6, $7) RETURNING id::text",
    )
    |> pog.parameter(pog.text(s.tenant))
    |> pog.parameter(pog.text(prop_id))
    |> pog.parameter(pog.text(room_code))
    |> pog.parameter(pog.text(issue_title))
    |> pog.parameter(pog.text(description))
    |> pog.parameter(pog.text(priority))
    |> pog.parameter(pog.text(s.name))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn resolve_room_ticket(
  db: pog.Connection,
  s: Session,
  ticket_id: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query(
      "UPDATE catalog.room_maintenance_tickets
       SET status = 'resolved', resolved_at = now()
       WHERE id = $1::uuid",
    )
    |> pog.parameter(pog.text(ticket_id))
    |> pog.execute(tx)
    |> result.map(fn(_) { "ok" })
  })
}

pub fn update_room_clean_status(
  db: pog.Connection,
  s: Session,
  unit_id: String,
  housekeeping_status: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("SELECT catalog.update_property_unit_status($1::uuid, '', $2)")
    |> pog.parameter(pog.text(unit_id))
    |> pog.parameter(pog.text(housekeeping_status))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}

pub fn quick_mark_clean(
  db: pog.Connection,
  s: Session,
  prop_id: String,
  room_code: String,
) -> Result(String, Nil) {
  scope(db, s, fn(tx) {
    pog.query("SELECT catalog.quick_mark_clean(nullif($1, '')::uuid, $2)")
    |> pog.parameter(pog.text(prop_id))
    |> pog.parameter(pog.text(room_code))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("ok") })
  })
}
