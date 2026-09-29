import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import nexus/database
import nexus/domain.{type Session}
import pog

pub fn command(
  db: pog.Connection,
  s: Session,
  sql: String,
  params: List(pog.Value),
) -> Result(String, Nil) {
  database.scope(db, s, fn(tx) {
    list.fold(params, pog.query(sql), pog.parameter)
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("failed") })
  })
}

pub fn days(db: pog.Connection, s: Session) -> Result(List(List(String)), Nil) {
  rows(
    db,
    s,
    "select array[p.title,d.service_date::text,d.nightly_minor::text,d.currency::text,case when d.blocked>0 then 'Kapalı' when d.sold>0 then 'Satıldı' when exists(select 1 from inventory.allocations a join booking.holds h on h.id=a.hold_id and h.tenant_id=a.tenant_id where a.tenant_id=d.tenant_id and a.resource_id=d.resource_id and a.service_date=d.service_date and h.status='active' and h.expires_at>clock_timestamp()) then 'Opsiyonda' else 'Müsait' end] from inventory.days d join inventory.resources r on r.id=d.resource_id and r.tenant_id=d.tenant_id join catalog.properties p on p.id=r.property_id and p.tenant_id=r.tenant_id where d.service_date >= (clock_timestamp() at time zone 'Europe/Istanbul')::date order by d.service_date,p.title limit 120",
  )
}

pub fn holds(
  db: pog.Connection,
  s: Session,
) -> Result(List(List(String)), Nil) {
  rows(
    db,
    s,
    "select array[h.id::text,p.title,h.check_in::text,h.check_out::text,q.total_minor::text,q.currency::text,case when h.status='active' and h.expires_at<=clock_timestamp() then 'expired' else h.status end,to_char(h.expires_at at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI:SS')] from booking.holds h join booking.quotes q on q.id=h.quote_id and q.tenant_id=h.tenant_id join catalog.properties p on p.id=q.property_id and p.tenant_id=q.tenant_id where h.resource_id is not null order by h.created_at desc limit 100",
  )
}

pub fn rows(db: pog.Connection, s: Session, sql: String) {
  rows_with(db, s, sql, [])
}

pub fn rows_with(
  db: pog.Connection,
  s: Session,
  sql: String,
  params: List(pog.Value),
) {
  database.scope(db, s, fn(tx) {
    list.fold(params, pog.query(sql), pog.parameter)
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(tx)
    |> result.map(fn(r) { r.rows })
  })
}

pub fn message(code: String) -> String {
  case string.starts_with(code, "agency_api_key:") {
    True ->
      "Bağlantı onaylandı. Bu API anahtarını şimdi acente ayarlarına kaydedin; güvenlik nedeniyle tekrar gösterilmeyecek: "
      <> string.slice(code, 15, string.length(code))
    False ->
      case string.starts_with(code, "agency_callback_failed:") {
        True ->
          "Acente callback bildirimi gönderilemedi: "
          <> string.slice(code, 23, string.length(code))
        False -> message_code(code)
      }
  }
}

fn message_code(code: String) -> String {
  case code {
    "already_posted" ->
      "Bu rezervasyon daha önce yevmiye defterine çift taraflı kaydedilmiş."
    "invalid_decision" -> "Karar geçersiz. Yalnızca onay veya ret seçilebilir."
    "already_decided" -> "Bu karar daha önce verilmiş ve sonuçlandırılmış."
    "already_queued" ->
      "Bu ilan ve işlem için zaten bekleyen bir AI görevi var."
    "cms_exists" -> "Bu URL adı zaten kullanılıyor. Farklı bir sayfa adı seçin."
    "requirements_incomplete" ->
      "Kimlik doğrulaması ve zorunlu kategori belgeleri tamamlanmadan ilan onaylanamaz."
    "invalid_application" -> "Başvuru bilgileri veya kategori geçersiz."
    "translation_queued" ->
      "Altı dil için AI çeviri işleri kuyruğa alındı. Sonuçlar insan onayından sonra yayınlanır."
    "setting_conflict" ->
      "Bu ayar başka bir oturumda değişmiş. Sayfayı yenileyin."
    "setting_unchanged" -> "Gizli alan boş bırakıldı; kayıtlı değer korundu."
    "invalid_setting" -> "Ayar değeri geçersiz. Alanın biçimini kontrol edin."
    "encryption_unavailable" ->
      "Şifreleme anahtarı kullanılamıyor; gizli değer kaydedilmedi."
    "already_booked" ->
      "Bu talepten daha önce rezervasyon oluşturuldu. Rezervasyon listesini kontrol edin."
    "not_approved" -> "Rezervasyon için önce tedarikçi opsiyon onayı gerekiyor."
    "expired" -> "Opsiyon artık aktif değil. Yeni bir opsiyon talep edin."
    "manual_review" -> "Rezervasyon durumu manuel inceleme gerektiriyor."
    "agency_callback_sent" ->
      "Acente callback bildirimi tekrar gönderildi ve yeni API anahtarı acenteye yazıldı."
    "agency_callback_failed" ->
      "Acente callback bildirimi gönderilemedi. Acente uygulaması veya endpoint ayarını kontrol edin."
    "forbidden" ->
      "Bu işlem için yetki veya aktif tedarikçi-acente bağlantısı bulunamadı."
    "ok" -> "İşlem tamamlandı."
    "deleted" -> "Sayfa silindi."
    "protected" -> "Sistem sayfaları silinemez."
    "occupied" ->
      "Bu aralıkta aktif opsiyon veya satış var. Önce ilgili işlemi çözümleyin."
    "unavailable" -> "Tüm geceler için açık takvim ve müsaitlik bulunamadı."
    "not_found" -> "Ürün veya opsiyon bulunamadı."
    "key_conflict" ->
      "Aynı işlem anahtarı farklı bilgilerle kullanıldı. Sayfayı yenileyin."
    "invalid_dates" | "invalid_range" ->
      "Tarih, fiyat veya süre geçersiz. Geçmiş tarih kullanmayın; çıkış girişten sonra olmalı."
    _ -> "İşlem gerçekleştirilemedi. Sayfayı yenileyip tekrar deneyin."
  }
}
