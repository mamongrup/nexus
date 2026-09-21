-- Supplier panel module contract v1.1.0.
-- These module codes come from contracts/supplier-listing-contract.v1.json
-- and must remain aligned with the agency project.

WITH modules(code, family, name, slug, description, page_slug) AS (
  VALUES
    ('dashboard','other','Genel Bakış','modul-panel-dashboard','Tedarikçinin günlük operasyon, uyarı ve performans özeti.','modul-panel-dashboard'),
    ('company_profile','other','Şirket Profili','modul-panel-company-profile','Kuruluş, vergi, iletişim ve ticari profil yönetimi.','modul-panel-company-profile'),
    ('documents','other','Belgeler','modul-panel-documents','Zorunlu belge, onay ve yenileme süreçleri.','modul-panel-documents'),
    ('catalog','other','Katalog','modul-panel-catalog','İlan, ürün ve hizmet içerik yönetimi.','modul-panel-catalog'),
    ('availability','hotel','Müsaitlik','modul-panel-availability','Takvim, stok, kontenjan ve uygunluk yönetimi.','modul-panel-availability'),
    ('pricing','hotel','Fiyatlandırma','modul-panel-pricing','Fiyat, sezon, komisyon ve promosyon yönetimi.','modul-panel-pricing'),
    ('reservations','hotel','Rezervasyonlar','modul-panel-reservations','Talep, opsiyon, onay, iptal ve konaklama akışı.','modul-panel-reservations'),
    ('offers','other','Teklifler','modul-panel-offers','Kurumsal teklif, özel fiyat ve paket akışı.','modul-panel-offers'),
    ('customers','other','Müşteriler','modul-panel-customers','Misafir, müşteri ve ilişki kayıtları.','modul-panel-customers'),
    ('messages','other','Mesajlar','modul-panel-messages','Acente, müşteri ve operasyon mesajlaşması.','modul-panel-messages'),
    ('tasks','other','İş Takibi','modul-panel-tasks','Görev, kontrol listesi ve operasyon takipleri.','modul-panel-tasks'),
    ('staff','erp','Personel','modul-panel-staff','Kullanıcı, rol, vardiya ve ekip yönetimi.','modul-panel-staff'),
    ('accounting','erp','Muhasebe','modul-panel-accounting','Cari, tahsilat, fatura ve finans görünürlüğü.','modul-panel-accounting'),
    ('payments','erp','Ödemeler','modul-panel-payments','Ödeme, iade, teminat ve mutabakat işlemleri.','modul-panel-payments'),
    ('reports','other','Raporlar','modul-panel-reports','Operasyon, satış ve finans raporları.','modul-panel-reports'),
    ('integrations','other','Entegrasyonlar','modul-panel-integrations','Harici servis, kanal ve sağlayıcı bağlantıları.','modul-panel-integrations'),
    ('settings','other','Ayarlar','modul-panel-settings','Tedarikçi panel ayarları ve çalışma kuralları.','modul-panel-settings')
), pages AS (
  INSERT INTO cms.pages(slug, title, summary, body)
  SELECT page_slug, name, description, description
  FROM modules
  ON CONFLICT (slug) DO UPDATE
    SET title = excluded.title,
        summary = excluded.summary,
        body = excluded.body
  RETURNING slug
)
INSERT INTO onboarding.product_modules(code, family, name, slug, description, page_slug, active)
SELECT code, family, name, slug, description, page_slug, true
FROM modules
ON CONFLICT (code) DO UPDATE
  SET family = excluded.family,
      name = excluded.name,
      slug = excluded.slug,
      description = excluded.description,
      page_slug = excluded.page_slug,
      active = true;
