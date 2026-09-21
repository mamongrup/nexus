-- Update 5 published test listings with luxury villa names and valid Unsplash photos
UPDATE catalog.properties SET
  title = 'Kaş Panorama Sonsuzluk Havuzlu Lüks Villa',
  locality = 'Kaş / Kalkan, Antalya',
  description = 'Akdeniz''in büyüleyici maviliklerine ve Meis Adası''na bakan sonsuzluk havuzu, geniş güneşlenme terası, jakuzili süiti ve modern mimarisiyle unutulmaz bir tatil deneyimi sunar.',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1613977257363-707ba9348227?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = '1ca5af5c-3f37-4a49-8c6a-0220d588e467';

UPDATE catalog.properties SET
  title = 'Kalkan Kördere Deniz & Gün Batımı Villası',
  locality = 'Kalkan / Kördere, Antalya',
  description = 'Kalkan Kördere yamaçlarında kesintisiz deniz ve gün batımı panoramasına hakim, ısıtmalı kapalı havuzu, saunası ve modern tasarımıyla 4 mevsim lüks konaklama imkanı.',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = '675f7bb4-166b-402f-861d-d274cd5599a1';

UPDATE catalog.properties SET
  title = 'Fethiye Ölüdeniz Özel Havuzlu Doğa Villası',
  locality = 'Ölüdeniz / Ovacık, Muğla',
  description = 'Babadağ''ın eteklerinde, yemyeşil çam ormanlarıyla çevrili ferah bahçesi, korunaklı özel yüzme havuzu ve şömineli geniş salonuyla doğayla iç içe huzurlu bir tatil.',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = 'e42e82a4-f7cf-43ef-a5b3-bb39da3e6d04';

UPDATE catalog.properties SET
  title = 'Bodrum Yalıkavak Marina Manzaralı Modern Villa',
  locality = 'Yalıkavak / Bodrum, Muğla',
  description = 'Dünyaca ünlü Yalıkavak Marina''ya sadece birkaç dakika mesafede, ödüllü mimarisi, akıllı ev otomasyonu, taş taşma havuzu ve özel peyzajlı tropik bahçesi ile elit bir yaşam.',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = 'd09143e5-4c45-479a-a9b4-876528d5cd43';

UPDATE catalog.properties SET
  title = 'Çeşme Alaçatı Taş Mimari Özel Havuzlu Konak',
  locality = 'Alaçatı / Çeşme, İzmir',
  description = 'Alaçatı''nın tarihi dokusuna sadık kalınarak el yapımı doğal taşlarla inşa edilmiş, cumbalı süitleri, zeytin ağaçlarıyla süslü avlusu ve müstakil havuzuyla göz alıcı bir konak.',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = '20a7bbd7-7c88-40b4-b43c-7cfbdf04a829';

-- Update remaining test/draft listings
UPDATE catalog.properties SET
  title = 'Antalya Belek Lüks Golf & Spa Villası',
  locality = 'Belek / Serik, Antalya',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1540541338287-41700207dee6?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = '63cbda18-f6a8-4d30-acf2-1f9404b90da7';

UPDATE catalog.properties SET
  title = 'Bodrum Göltürkbükü Özel İskeleli Malikane',
  locality = 'Göltürkbükü / Bodrum, Muğla',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = 'c6c4fb6c-5d9c-4d27-b08a-b5889e2e8962';

UPDATE catalog.properties SET
  title = 'Marmaris Bozburun Butik Deniz Manzaralı Taş Villa',
  locality = 'Bozburun / Marmaris, Muğla',
  media = jsonb_build_array(
    'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80'
  )
WHERE id = 'b88127f0-be8b-43e0-b198-4c1a798e36d4';

UPDATE catalog.properties SET
  media = jsonb_build_array('https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80')
WHERE media IS NULL OR media = '[]'::jsonb OR media::text = '""';
