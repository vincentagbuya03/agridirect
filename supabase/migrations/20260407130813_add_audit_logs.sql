-- ========================================================================
-- ADD AUDIT_LOGS TABLE
-- ========================================================================
-- Purpose: Track all changes to database records for compliance & debugging
-- Records: table name, operation, record ID, old/new values, user, timestamp
-- ========================================================================

CREATE TABLE audit_logs (
  log_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  operation text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  record_id text NOT NULL,
  old_values jsonb,
  new_values jsonb,
  user_id uuid REFERENCES users(user_id) ON DELETE SET NULL,
  ip_address text,
  user_agent text,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Indexes for efficient querying
CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_record_id ON audit_logs(record_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_operation ON audit_logs(operation);

-- Enable RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can view all audit logs
CREATE POLICY "admins_can_view_audit_logs"
  ON audit_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM admins a
      WHERE a.user_id = auth.uid()
    )
  );

-- Policy: System can insert audit logs
CREATE POLICY "system_can_insert_audit_logs"
  ON audit_logs
  FOR INSERT
  WITH CHECK (true);

-- ========================================================================
-- SUMMARY
-- ========================================================================
-- Table: audit_logs
-- Purpose: Complete audit trail for all database modifications
-- Columns:
--   - log_id: unique identifier
--   - table_name: which table was modified (e.g., 'orders', 'products')
--   - operation: INSERT, UPDATE, or DELETE
--   - record_id: which record was modified
--   - old_values: JSON of previous values (for UPDATE/DELETE)
--   - new_values: JSON of new values (for INSERT/UPDATE)
--   - user_id: who made the change
--   - ip_address: client IP for security
--   - user_agent: browser/app identifier
--   - notes: optional description
--   - created_at: exactly when
-- ========================================================================
