INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
 ('payment.provider','ParamPOS ödeme','Sanal POS sağlayıcısı','select','parampos','NEXUS ve acente ödeme akışlarında ParamPOS kullanılır.',17,'nexus'),
 ('payment.three_ds','ParamPOS ödeme','3D Secure','select','required,optional','Kartlı ödemelerde önerilen güvenlik seviyesi.',18,'nexus'),
 ('payment.currency','ParamPOS ödeme','Tahsilat para birimi','select','TRY,EUR,USD,GBP,AED,SAR','ParamPOS hesabınızın desteklediği para birimini seçin.',19,'nexus')
ON CONFLICT (key) DO UPDATE SET section=EXCLUDED.section,label=EXCLUDED.label,kind=EXCLUDED.kind,choices=EXCLUDED.choices,description=EXCLUDED.description,position=EXCLUDED.position,workspace=EXCLUDED.workspace;
