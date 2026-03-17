-- ============================================================
-- AI Customer Support Automation — PostgreSQL Schema
-- Portfolio Project | Automation Engineer
-- ============================================================

-- Enable UUID extension (optional, we use custom ticket IDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── TICKETS TABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tickets (
    id              SERIAL PRIMARY KEY,
    ticket_id       VARCHAR(30)  NOT NULL UNIQUE,    -- TKT-<timestamp>
    source          VARCHAR(20)  NOT NULL,            -- email | whatsapp | webhook
    from_contact    VARCHAR(255) NOT NULL,
    subject         VARCHAR(500),
    message         TEXT         NOT NULL,

    -- AI Classification
    category        VARCHAR(50),   -- billing, technical, account, complaint, general, sales, refund, shipping
    urgency         VARCHAR(20),   -- low, medium, high, critical
    sentiment       VARCHAR(20),   -- positive, neutral, negative, very_negative
    complexity      VARCHAR(20),   -- simple, moderate, complex
    language        VARCHAR(10),   -- ISO 639-1 (en, es, pt, ...)
    summary         TEXT,
    confidence_score DECIMAL(4,3), -- 0.000 - 1.000
    needs_human     BOOLEAN        DEFAULT false,

    -- Response
    auto_response   TEXT,
    auto_responded  BOOLEAN        DEFAULT false,
    status          VARCHAR(30)    DEFAULT 'open',    -- open, auto-resolved, escalated, closed

    -- Timestamps
    created_at      TIMESTAMPTZ    DEFAULT NOW(),
    updated_at      TIMESTAMPTZ    DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

-- ── TICKET EVENTS (audit trail) ───────────────────────────
CREATE TABLE IF NOT EXISTS ticket_events (
    id          SERIAL PRIMARY KEY,
    ticket_id   VARCHAR(30)  REFERENCES tickets(ticket_id) ON DELETE CASCADE,
    event_type  VARCHAR(50)  NOT NULL,  -- created, classified, auto_responded, escalated, assigned, resolved
    actor       VARCHAR(100) DEFAULT 'n8n-automation',
    payload     JSONB,
    created_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- ── AGENTS TABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agents (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    slack_id    VARCHAR(50),
    is_active   BOOLEAN      DEFAULT true,
    created_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- ── TICKET ASSIGNMENTS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS ticket_assignments (
    id          SERIAL PRIMARY KEY,
    ticket_id   VARCHAR(30)  REFERENCES tickets(ticket_id) ON DELETE CASCADE,
    agent_id    INTEGER      REFERENCES agents(id),
    assigned_at TIMESTAMPTZ  DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- ── INDEXES ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tickets_status    ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_urgency   ON tickets(urgency);
CREATE INDEX IF NOT EXISTS idx_tickets_category  ON tickets(category);
CREATE INDEX IF NOT EXISTS idx_tickets_source    ON tickets(source);
CREATE INDEX IF NOT EXISTS idx_tickets_created   ON tickets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ticket_events_tid ON ticket_events(ticket_id);

-- ── AUTO-UPDATE updated_at ────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tickets_updated_at
    BEFORE UPDATE ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ── DASHBOARD VIEW ────────────────────────────────────────
CREATE OR REPLACE VIEW ticket_stats_24h AS
SELECT
    COUNT(*)                                        AS total_tickets,
    COUNT(*) FILTER (WHERE auto_responded = true)   AS auto_resolved,
    COUNT(*) FILTER (WHERE urgency = 'critical')    AS critical_tickets,
    COUNT(*) FILTER (WHERE urgency = 'high')        AS high_tickets,
    COUNT(*) FILTER (WHERE status = 'escalated')    AS escalated,
    ROUND(
        COUNT(*) FILTER (WHERE auto_responded = true)::decimal
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS automation_rate_pct,
    ROUND(AVG(confidence_score) * 100, 1)           AS avg_confidence_pct
FROM tickets
WHERE created_at >= NOW() - INTERVAL '24 hours';

-- ── SAMPLE SEED DATA ──────────────────────────────────────
INSERT INTO agents (name, email, slack_id) VALUES
    ('Ana García',   'ana@company.com',   'U0001'),
    ('Carlos López', 'carlos@company.com','U0002'),
    ('Diana Chen',   'diana@company.com', 'U0003')
ON CONFLICT DO NOTHING;

-- ============================================================
-- DONE. Run this script once before starting the n8n workflow.
-- ============================================================
