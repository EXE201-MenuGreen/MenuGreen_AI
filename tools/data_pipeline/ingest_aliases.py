import argparse


def run(csv_path: str):
    raise RuntimeError(
        f"Alias ingest is disabled for {csv_path}: the PostgreSQL schema does not define a food_aliases table."
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to aliases CSV")
    args = parser.parse_args()
    run(args.csv)
