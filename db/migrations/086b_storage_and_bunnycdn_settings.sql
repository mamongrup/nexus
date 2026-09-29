-- Migration 086: Storage and BunnyCDN Settings

INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
  ('storage.driver','Dosya ve CDN Depolama','Depolama Modu','select','both,local,bunnycdn','Lokal ve/veya BunnyCDN kayıt modu (Varsayılan: both)',55,'nexus'),
  ('storage.local_path','Dosya ve CDN Depolama','Lokal Klasör Yolu','text','','Sunucudaki yerel kayıt dizini (Varsayılan: priv/static/uploads)',56,'nexus'),
  ('storage.local_url_prefix','Dosya ve CDN Depolama','Lokal URL Öneki','text','','Web erişim URL öneki (Varsayılan: /static/uploads)',57,'nexus'),
  ('storage.bunny_zone','Dosya ve CDN Depolama','BunnyCDN Storage Zone','text','','BunnyCDN Storage Zone adı (Örn: nexus-storage)',58,'nexus'),
  ('storage.bunny_api_key','Dosya ve CDN Depolama','BunnyCDN Access Key','secret','','Storage Zone Password / Access Key',59,'nexus'),
  ('storage.bunny_region','Dosya ve CDN Depolama','BunnyCDN Bölgesi','select','storage.bunnycdn.com,ny.storage.bunnycdn.com,la.storage.bunnycdn.com,sg.storage.bunnycdn.com,syd.storage.bunnycdn.com,uk.storage.bunnycdn.com,se.storage.bunnycdn.com,br.storage.bunnycdn.com,jh.storage.bunnycdn.com','BunnyCDN Storage Bölge Hostu',60,'nexus'),
  ('storage.bunny_pull_zone','Dosya ve CDN Depolama','BunnyCDN Pull Zone Adresi','https','','Yayınlanan CDN web adresi (Örn: https://nexus.b-cdn.net)',61,'nexus')
ON CONFLICT (key) DO UPDATE SET
  section=EXCLUDED.section,
  label=EXCLUDED.label,
  kind=EXCLUDED.kind,
  choices=EXCLUDED.choices,
  description=EXCLUDED.description,
  position=EXCLUDED.position,
  workspace=EXCLUDED.workspace;

INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
  ('agency_storage.driver','Acente Dosya ve CDN','Depolama Modu','select','both,local,bunnycdn','Lokal ve/veya BunnyCDN modu',50,'agency'),
  ('agency_storage.local_path','Acente Dosya ve CDN','Lokal Klasör Yolu','text','','Sunucudaki yerel kayıt dizini',51,'agency'),
  ('agency_storage.bunny_zone','Acente Dosya ve CDN','BunnyCDN Storage Zone','text','','BunnyCDN Storage Zone adı',52,'agency'),
  ('agency_storage.bunny_api_key','Acente Dosya ve CDN','BunnyCDN Access Key','secret','','Storage Zone Access Key',53,'agency'),
  ('agency_storage.bunny_pull_zone','Acente Dosya ve CDN','BunnyCDN Pull Zone','https','','CDN web adresi',54,'agency')
ON CONFLICT (key) DO NOTHING;
