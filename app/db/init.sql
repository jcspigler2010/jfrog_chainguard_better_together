-- Seeds the catalog with a handful of rows so the dashboard is not empty
-- on first launch. The API will CREATE the table on startup, so this script
-- is idempotent-friendly (uses ON CONFLICT DO NOTHING for safety).

CREATE TABLE IF NOT EXISTS images (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    tag VARCHAR(128) NOT NULL DEFAULT 'latest',
    base_flavor VARCHAR(32) NOT NULL,
    cves_high INT NOT NULL DEFAULT 0,
    cves_medium INT NOT NULL DEFAULT 0,
    cves_low INT NOT NULL DEFAULT 0,
    last_scanned TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO images (name, tag, base_flavor, cves_high, cves_medium, cves_low) VALUES
    ('catalog-api',       'chainguard', 'chainguard', 0, 0,  1),
    ('catalog-api',       'baseline',   'baseline',  11, 34, 78),
    ('catalog-frontend',  'chainguard', 'chainguard', 0, 0,  0),
    ('catalog-frontend',  'baseline',   'baseline',   7, 22, 41),
    ('postgres',          'chainguard', 'chainguard', 0, 1,  2),
    ('postgres',          'baseline',   'baseline',   4, 18, 37)
ON CONFLICT DO NOTHING;
