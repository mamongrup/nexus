UPDATE settings.fields
SET description='Boş bırakılırsa aylık AI bütçesi sınırsız olur. Değer girilirse USD cent cinsinden kota uygulanır.'
WHERE key='ai.monthly_budget_minor';

UPDATE settings.fields
SET description='Boş bırakılırsa günlük AI bütçesi sınırsız olur. Değer girilirse USD cent cinsinden kota uygulanır.'
WHERE key='ai.daily_budget_minor';
