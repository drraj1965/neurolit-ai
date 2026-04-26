import argparse
import multiprocessing
import sys
import traceback
from pathlib import Path

import uvicorn

try:
    from .main import app
except ImportError:
    from main import app


def main() -> None:
    multiprocessing.freeze_support()

    parser = argparse.ArgumentParser(description="NeuroLit engineering backend server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
        log_level="warning",
        log_config=None,
        access_log=False,
    )


def _runtime_log_path() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent / "neurolit_backend_runtime.log"

    return Path(__file__).resolve().parent / "neurolit_backend_runtime.log"


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log_path = _runtime_log_path()
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(traceback.format_exc())
            handle.write("\n")
        raise
