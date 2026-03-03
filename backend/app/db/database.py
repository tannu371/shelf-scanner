"""
ShelfScanner — Async PostgreSQL connection pool
Uses psycopg3 (psycopg) with pgvector support.
"""
import os
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool
from pgvector.psycopg import register_vector_async
import logging

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Build the connection string from environment variables
# ---------------------------------------------------------------------------
def _get_dsn() -> str:
    return (
        f"host={os.getenv('DB_HOST', 'localhost')} "
        f"port={os.getenv('DB_PORT', '5432')} "
        f"dbname={os.getenv('DB_NAME', 'shelfscanner')} "
        f"user={os.getenv('DB_USER', 'postgres')} "
        f"password={os.getenv('DB_PASSWORD', 'postgres')}"
    )

# ---------------------------------------------------------------------------
# Global connection pool — initialised once at application startup
# ---------------------------------------------------------------------------
_pool: AsyncConnectionPool | None = None


async def get_pool() -> AsyncConnectionPool:
    global _pool
    if _pool is None:
        raise RuntimeError("Database pool not initialised. Call init_db() first.")
    return _pool


async def init_db() -> None:
    """Create the connection pool and register the pgvector type."""
    global _pool
    dsn = _get_dsn()
    logger.info("Connecting to PostgreSQL …")
    _pool = AsyncConnectionPool(
        conninfo=dsn,
        min_size=2,
        max_size=10,
        kwargs={"row_factory": dict_row},
        open=False,
    )
    await _pool.open()

    # Register the pgvector type on every fresh connection
    async with _pool.connection() as conn:
        await register_vector_async(conn)

    logger.info("Database pool ready.")


async def close_db() -> None:
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
