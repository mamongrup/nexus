-- Guardrails for the self-managing operating loop. These are admin-editable settings.
INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
 ('ai.autonomy_mode','Yapay zekâ yönetişimi','Çalışma modu','select','assist,supervised,autonomous','Assist yalnızca önerir; supervised onay bekler; autonomous yalnızca düşük riskli görevleri kendi yürütür.',100,'nexus'),
 ('ai.require_human_approval','Yapay zekâ yönetişimi','Kritik işlemlerde insan onayı','select','yes,no','Fiyat, yayın, ödeme ve dış sistem işlemleri için güvenlik katmanı.',101,'nexus'),
 ('ai.daily_budget_minor','Yapay zekâ yönetişimi','Günlük AI bütçesi (USD cent)','number','','Bütçe aşılırsa yeni görevler kuyruğa alınır.',102,'nexus'),
 ('ai.worker_interval_seconds','Yapay zekâ yönetişimi','Worker kontrol aralığı (saniye)','number','','Önerilen değer: 60.',103,'nexus'),
 ('ai.max_retries','Yapay zekâ yönetişimi','Başarısız görev tekrar sayısı','number','','Hatalı entegrasyonlarda sonsuz tekrar oluşmasını engeller.',104,'nexus'),
 ('ai.alert_email','Yapay zekâ yönetişimi','Operasyon uyarı e-postası','email','','Kritik hata ve bütçe uyarıları bu adrese gönderilir.',105,'nexus')
ON CONFLICT (key) DO UPDATE SET section=EXCLUDED.section,label=EXCLUDED.label,kind=EXCLUDED.kind,choices=EXCLUDED.choices,description=EXCLUDED.description,position=EXCLUDED.position,workspace=EXCLUDED.workspace;
