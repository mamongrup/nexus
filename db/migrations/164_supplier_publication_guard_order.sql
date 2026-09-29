-- Check supplier approval before contract-field diagnostics for a publish action.
ALTER TRIGGER supplier_publication_status_guard ON catalog.properties
  RENAME TO a_supplier_publication_status_guard;
