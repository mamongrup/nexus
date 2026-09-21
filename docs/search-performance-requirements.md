# Arama ve Rezervasyon Performans Gereksinimleri

Bu proje için arama hızı temel ürün gereksinimidir.

## Kapsam

- Rezervasyon öncesi müsaitlik, fiyat ve kapasite sorguları hızlı sonuç vermelidir.
- İlan adı, kategori, şehir ve bölge adıyla yapılan aramalar hızlı sonuç vermelidir.
- NEXUS'a bağlı acente araması dış sistem yanıtlarını beklememelidir.

## Teknik kurallar

- Liste aramaları yerel katalog okuma modelinden sonuç döndürür.
- Dış servis senkronizasyonu arka planda çalışır.
- Arama ve müsaitlik sorguları sayfalı, sınırlı kolonlu ve zaman aşımı kontrollü olur.
- İlan adı ve bölge araması için PostgreSQL full-text/trigram indeksleri kullanılır.
- Kategori, bölge, yayın durumu, tarih, kapasite ve fiyat alanlarında bileşik indeksler bulunur.
- Müsaitlik sorguları tarih aralığı ve kaynak/ünite kimliği üzerinden indekslenir.
- Kritik sorgular `EXPLAIN ANALYZE` ile doğrulanır.

## Kabul kriterleri

- Arama ekranı dış API yanıtını beklemeden sonuç gösterebilir.
- Sonuç yoksa veya dış bağlantı yavaşsa kullanıcıya anlaşılır durum gösterilir.
- Üretime çıkmadan önce gerçekçi veri hacmiyle arama ve rezervasyon yük testi yapılır.
- Sorgu süreleri ve hata oranları yönetici performans ekranında izlenir.
