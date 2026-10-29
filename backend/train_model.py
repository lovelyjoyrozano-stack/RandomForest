"""Train the Random Forest yield model from the command line.

    python train_model.py              # from real harvest + climate records
    python train_model.py --synthetic  # DEMO ONLY: invented data
"""
import argparse
import json

from app.config import get_settings
from app.database import SessionLocal, init_db
from app.services import ml


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--synthetic", action="store_true", help="train on invented demo data")
    args = parser.parse_args()

    settings = get_settings()
    init_db()

    if args.synthetic:
        X, y = ml.synthetic_dataset()
        bundle = ml.train(X, y, ml.SOURCE_SYNTHETIC, min_samples=1)
    else:
        with SessionLocal() as db:
            X, y = ml.build_training_data(db)
        try:
            bundle = ml.train(X, y, ml.SOURCE_REAL, settings.min_train_samples)
        except ml.ModelError as e:
            raise SystemExit(f"Cannot train: {e.detail}\n(Use --synthetic for a clearly-labelled demo model.)")

    ml.save(bundle, settings.model_path)
    print(f"Saved model to {settings.model_path}")
    print(json.dumps(ml.public_info(bundle), indent=2))


if __name__ == "__main__":
    main()
