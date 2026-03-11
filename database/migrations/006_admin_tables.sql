-- ============================================================================
-- 006_admin_tables.sql
-- Admin moderation and audit logs
-- ============================================================================

-- ============================================================================
-- ARTICLES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS articles (
    article_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    read_time TEXT,
    image_url TEXT,
    published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_articles_author_id ON articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(published);

-- Trigger for auto-update timestamp
CREATE TRIGGER articles_updated_at_trigger
BEFORE UPDATE ON articles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ADMIN_LOGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_logs (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details TEXT,
    target_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON admin_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_target_user_id ON admin_logs(target_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON admin_logs(created_at DESC);

-- ============================================================================
-- REPORTED_CONTENT TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS reported_content (
    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content_type TEXT NOT NULL CHECK (content_type IN ('post', 'comment', 'review', 'product', 'profile')),
    content_id UUID NOT NULL,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    resolved_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_reported_content_reporter_id ON reported_content(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reported_content_status ON reported_content(status);
CREATE INDEX IF NOT EXISTS idx_reported_content_content_type ON reported_content(content_type);

-- ============================================================================
-- USER_SUSPENSIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_suspensions (
    suspension_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    suspended_by UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    suspended_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ,
    is_permanent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_suspensions_user_id ON user_suspensions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_suspensions_suspended_by ON user_suspensions(suspended_by);
CREATE INDEX IF NOT EXISTS idx_user_suspensions_expires_at ON user_suspensions(expires_at);
