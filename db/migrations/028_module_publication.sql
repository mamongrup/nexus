UPDATE cms.pages p SET published=jsonb_build_object('title',p.title,'summary',p.summary,'body',p.body),version=version+1
WHERE p.published IS NULL AND EXISTS(SELECT 1 FROM onboarding.product_modules m WHERE m.page_slug=p.slug AND m.active);
