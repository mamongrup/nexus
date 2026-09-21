-- Chinese yuan (CNY) is a supported settlement and display currency.
INSERT INTO core.currencies(code,minor_digits) VALUES ('CNY',2)
ON CONFLICT(code) DO NOTHING;
INSERT INTO core.locales(code,label,direction) VALUES ('zh','简体中文','ltr')
ON CONFLICT(code) DO UPDATE SET label=excluded.label,direction=excluded.direction;
UPDATE settings.fields
SET choices=CASE
 WHEN choices IS NULL OR choices='' THEN 'CNY'
 WHEN position('CNY' in choices)>0 THEN choices
 ELSE choices||',CNY'
END
WHERE key IN ('site.default_currency','payment.currency');
