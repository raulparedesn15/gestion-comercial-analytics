"""
Configuration module for the Gestion Comercial Analytics project.

This module centralizes:
- Project paths
- Environment variable loading
- MySQL connection settings
- SQLAlchemy engine creation
"""

import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import URL


# Project root directory
PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Main project paths
DATA_DIR = PROJECT_ROOT / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
PROCESSED_DATA_DIR = DATA_DIR / "processed"
POWER_BI_DIR = DATA_DIR / "power_bi"
REPORTS_DIR = PROJECT_ROOT / "reports"

# Input files
RAW_EXCEL_FILE = RAW_DATA_DIR / "caso_practico.xlsx"

# Load environment variables from .env
load_dotenv(PROJECT_ROOT / ".env")


def get_required_env_var(var_name: str) -> str:
    """
    Get a required environment variable.

    Raises:
        ValueError: If the environment variable is missing.
    """
    value = os.getenv(var_name)

    if value is None or value.strip() == "":
        raise ValueError(f"Missing required environment variable: {var_name}")

    return value


def get_database_url() -> URL:
    """
    Build the SQLAlchemy database URL for MySQL.

    Returns:
        SQLAlchemy URL object.
    """
    return URL.create(
        drivername="mysql+pymysql",
        username=get_required_env_var("DB_USER"),
        password=get_required_env_var("DB_PASSWORD"),
        host=get_required_env_var("DB_HOST"),
        port=int(get_required_env_var("DB_PORT")),
        database=get_required_env_var("DB_NAME"),
    )


def get_engine():
    """
    Create a SQLAlchemy engine for MySQL.

    Returns:
        SQLAlchemy Engine object.
    """
    engine = create_engine(
        get_database_url(),
        pool_pre_ping=True,
    )

    return engine