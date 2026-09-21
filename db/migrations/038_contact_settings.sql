INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
 ('contact.phone','İletişim sayfası','Telefon','text','','',70,'nexus'),
 ('contact.whatsapp','İletişim sayfası','WhatsApp numarası','text','','Ülke koduyla yazın.',71,'nexus'),
 ('contact.email','İletişim sayfası','İletişim e-postası','email','','',72,'nexus'),
 ('contact.address','İletişim sayfası','Adres','text','','',73,'nexus'),
 ('contact.linkedin','İletişim sayfası','LinkedIn bağlantısı','https','','',74,'nexus'),
 ('contact.instagram','İletişim sayfası','Instagram bağlantısı','https','','',75,'nexus'),
 ('contact.map_url','İletişim sayfası','Harita bağlantısı','https','','',76,'nexus') ON CONFLICT(key) DO NOTHING;
