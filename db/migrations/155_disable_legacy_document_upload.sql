-- The four-argument upload path cannot require an expiry date and must not
-- remain callable after the renewal workflow became mandatory.
REVOKE ALL ON FUNCTION onboarding.register_document(text,text,text,text) FROM PUBLIC, nexus_app;
