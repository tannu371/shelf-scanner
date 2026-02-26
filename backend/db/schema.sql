-- ============================================================
--  ShelfScanner — PostgreSQL Schema
--  Requires: pgvector extension  (CREATE EXTENSION vector)
--  Run:  psql -U postgres -d shelfscanner -f db/schema.sql
-- ============================================================

-- Enable the pgvector extension for embedding storage/search
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- for gen_random_uuid()

-- -------------------------------------------------------
-- Books table
-- Stores metadata + SBERT embedding for every known book
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS books (
    isbn         TEXT PRIMARY KEY,
    title        TEXT NOT NULL,
    authors      TEXT[]          DEFAULT '{}',
    publisher    TEXT            DEFAULT '',
    year         TEXT            DEFAULT '',
    description  TEXT            DEFAULT '',
    categories   TEXT[]          DEFAULT '{}',
    cover_url    TEXT            DEFAULT '',
    avg_rating   REAL,
    rating_count INT,
    -- SBERT all-mpnet-base-v2 produces 768-dim vectors
    embedding    vector(768),
    created_at   TIMESTAMPTZ     DEFAULT NOW(),
    updated_at   TIMESTAMPTZ     DEFAULT NOW()
);

-- HNSW index for ultra-fast approximate KNN search
-- (better recall than IVFFlat at this scale)
CREATE INDEX IF NOT EXISTS books_embedding_hnsw
    ON books USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- -------------------------------------------------------
-- Users table
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    user_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    preferences  TEXT            DEFAULT '',    -- free-text preference description
    embedding    vector(768),                   -- NLP embedding of preferences
    created_at   TIMESTAMPTZ     DEFAULT NOW()
);

-- -------------------------------------------------------
-- Feedback Log — HITL retraining data source
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS feedback_log (
    id              SERIAL PRIMARY KEY,
    user_id         UUID            REFERENCES users(user_id) ON DELETE SET NULL,
    isbn            TEXT            REFERENCES books(isbn) ON DELETE SET NULL,
    action          TEXT NOT NULL   CHECK (action IN ('confirm', 'like', 'skip')),
    ocr_raw_text    TEXT,           -- original OCR output (for model retraining)
    spine_image_b64 TEXT,           -- base64 spine crop (for HITL CRAFT/Tesseract)
    created_at      TIMESTAMPTZ     DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS feedback_log_user_idx ON feedback_log (user_id);
CREATE INDEX IF NOT EXISTS feedback_log_isbn_idx ON feedback_log (isbn);
