"""
Excel to MySQL loader for the Gestion Comercial Analytics project.

This script:
- Reads the raw Excel file.
- Cleans and standardizes the source data.
- Loads the cleaned data into MySQL tables.
- Validates loaded row counts.
"""

import re
import unicodedata

import pandas as pd
from sqlalchemy import text

from src.config import RAW_EXCEL_FILE, get_engine


def normalize_text(value: str) -> str:
    """
    Normalize text values for consistent matching.

    Example:
        "  Abraham Navarro " -> "ABRAHAM NAVARRO"
    """
    if pd.isna(value):
        return ""

    value = str(value).strip()
    value = re.sub(r"\s+", " ", value)

    return value.upper()


def normalize_column_name(column_name: str) -> str:
    """
    Normalize column names to snake_case without accents.

    Example:
        "Fecha Operación" -> "fecha_operacion"
        "No. Cliente" -> "no_cliente"
        "Ingreso Operación" -> "ingreso_operacion"
    """
    column_name = str(column_name).strip().lower()

    column_name = unicodedata.normalize("NFKD", column_name)
    column_name = "".join(
        character
        for character in column_name
        if not unicodedata.combining(character)
    )

    column_name = re.sub(r"[^a-z0-9]+", "_", column_name)
    column_name = re.sub(r"_+", "_", column_name)
    column_name = column_name.strip("_")

    return column_name


def standardize_column_names(df: pd.DataFrame) -> pd.DataFrame:
    """
    Standardize all DataFrame column names.
    """
    df = df.copy()
    df.columns = [normalize_column_name(column) for column in df.columns]

    return df


def validate_required_columns(
    df: pd.DataFrame,
    required_columns: list[str],
    dataframe_name: str,
) -> None:
    """
    Validate that a DataFrame contains all required columns.

    Raises:
        KeyError: If one or more required columns are missing.
    """
    missing_columns = [
        column
        for column in required_columns
        if column not in df.columns
    ]

    if missing_columns:
        raise KeyError(
            f"Missing columns in {dataframe_name}: {missing_columns}. "
            f"Available columns: {list(df.columns)}"
        )


def remove_leading_code(value: str) -> str:
    """
    Remove leading numeric code from seller names.

    Example:
        "28 ABRAHAM NAVARRO" -> "ABRAHAM NAVARRO"
    """
    value = normalize_text(value)

    return re.sub(r"^\d+\s+", "", value)


def invert_two_part_name(value: str) -> str:
    """
    Invert two-part seller names when needed.

    Example:
        "HERNANDEZ IRVING" -> "IRVING HERNANDEZ"

    Note:
        This works for two-word names. More complex names may require
        a manual mapping table in a future improvement.
    """
    value = normalize_text(value)
    parts = value.split()

    if len(parts) == 2:
        return f"{parts[1]} {parts[0]}"

    return value


def read_excel_sheets() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Read required sheets from the raw Excel file.

    Returns:
        Tuple containing operations, seller-region, and budget DataFrames.
    """
    if not RAW_EXCEL_FILE.exists():
        raise FileNotFoundError(
            f"Raw Excel file not found: {RAW_EXCEL_FILE}. "
            "Place the file in data/raw/caso_practico.xlsx"
        )

    operations_df = pd.read_excel(RAW_EXCEL_FILE, sheet_name="BD")
    seller_region_df = pd.read_excel(RAW_EXCEL_FILE, sheet_name="Ciudad-Region")
    budget_df = pd.read_excel(RAW_EXCEL_FILE, sheet_name="Presupuesto")

    return operations_df, seller_region_df, budget_df


def clean_operations(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean the operations table from the BD sheet.
    """
    df = standardize_column_names(df)

    required_columns = [
        "guia",
        "fecha_operacion",
        "no_cliente",
        "vendedor",
        "ingreso_operacion",
        "tipo_cliente",
    ]

    validate_required_columns(
        df=df,
        required_columns=required_columns,
        dataframe_name="BD",
    )

    df = df[required_columns].copy()

    df["fecha_operacion"] = pd.to_datetime(df["fecha_operacion"]).dt.date
    df["vendedor"] = df["vendedor"].apply(normalize_text)

    df["guia"] = df["guia"].astype(int)
    df["no_cliente"] = df["no_cliente"].astype(int)
    df["ingreso_operacion"] = df["ingreso_operacion"].astype(float)
    df["tipo_cliente"] = df["tipo_cliente"].astype(int)

    return df


def clean_seller_region(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean the seller-region table from the Ciudad-Region sheet.
    """
    df = standardize_column_names(df)

    if "vendedor" in df.columns:
        df = df.rename(columns={"vendedor": "nombre_original"})
    elif "nombre" in df.columns:
        df = df.rename(columns={"nombre": "nombre_original"})

    required_columns = [
        "nombre_original",
        "ciudad",
        "region",
    ]

    validate_required_columns(
        df=df,
        required_columns=required_columns,
        dataframe_name="Ciudad-Region",
    )

    df = df[required_columns].copy()

    df["nombre_original"] = df["nombre_original"].apply(normalize_text)
    df["vendedor"] = df["nombre_original"].apply(remove_leading_code)
    df["ciudad"] = df["ciudad"].apply(normalize_text)
    df["region"] = df["region"].apply(normalize_text)

    df = df[
        [
            "nombre_original",
            "vendedor",
            "ciudad",
            "region",
        ]
    ].copy()

    return df


def clean_budget(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean the budget table from the Presupuesto sheet.
    """
    df = standardize_column_names(df)

    if "vendedor" in df.columns:
        df = df.rename(columns={"vendedor": "vendedor_original"})

    required_columns = [
        "vendedor_original",
        "presupuesto",
    ]

    validate_required_columns(
        df=df,
        required_columns=required_columns,
        dataframe_name="Presupuesto",
    )

    df = df[required_columns].copy()

    df["vendedor_original"] = df["vendedor_original"].apply(normalize_text)
    df["vendedor"] = df["vendedor_original"].apply(invert_two_part_name)
    df["presupuesto"] = df["presupuesto"].astype(float)

    df = df[
        [
            "vendedor_original",
            "vendedor",
            "presupuesto",
        ]
    ].copy()

    return df


def truncate_tables() -> None:
    """
    Clear target tables before loading new data.

    This keeps the load process idempotent:
    running the script multiple times should not duplicate records.
    """
    engine = get_engine()

    with engine.begin() as connection:
        connection.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))
        connection.execute(text("TRUNCATE TABLE operaciones;"))
        connection.execute(text("TRUNCATE TABLE vendedor_region;"))
        connection.execute(text("TRUNCATE TABLE presupuesto;"))
        connection.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))


def load_dataframes_to_sql(
    operations_df: pd.DataFrame,
    seller_region_df: pd.DataFrame,
    budget_df: pd.DataFrame,
) -> None:
    """
    Load cleaned DataFrames into MySQL tables.
    """
    engine = get_engine()

    operations_df.to_sql(
        name="operaciones",
        con=engine,
        if_exists="append",
        index=False,
    )

    seller_region_df.to_sql(
        name="vendedor_region",
        con=engine,
        if_exists="append",
        index=False,
    )

    budget_df.to_sql(
        name="presupuesto",
        con=engine,
        if_exists="append",
        index=False,
    )


def validate_loaded_counts() -> None:
    """
    Print row counts from loaded SQL tables.
    """
    engine = get_engine()

    queries = {
        "operaciones": "SELECT COUNT(*) FROM operaciones;",
        "vendedor_region": "SELECT COUNT(*) FROM vendedor_region;",
        "presupuesto": "SELECT COUNT(*) FROM presupuesto;",
    }

    with engine.connect() as connection:
        for table_name, query in queries.items():
            count = connection.execute(text(query)).scalar()
            print(f"{table_name}: {count} rows loaded")


def main() -> None:
    """
    Run the full Excel-to-SQL loading process.
    """
    print("Reading Excel file...")
    operations_raw, seller_region_raw, budget_raw = read_excel_sheets()

    print("Cleaning data...")
    operations_df = clean_operations(operations_raw)
    seller_region_df = clean_seller_region(seller_region_raw)
    budget_df = clean_budget(budget_raw)

    print("Clearing target tables...")
    truncate_tables()

    print("Loading data into MySQL...")
    load_dataframes_to_sql(
        operations_df=operations_df,
        seller_region_df=seller_region_df,
        budget_df=budget_df,
    )

    print("Validating loaded data...")
    validate_loaded_counts()

    print("Excel-to-SQL load completed successfully.")


if __name__ == "__main__":
    main()