from typing import List

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

try:
    from .engineering_service import EngineeringService, SourceUnavailableError
except ImportError:
    from engineering_service import EngineeringService, SourceUnavailableError

app = FastAPI(title="NeuroLit Backend", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

service = EngineeringService()


@app.get("/")
def root() -> dict:
    return {"status": "ok", "service": "NeuroLit Backend"}


@app.get("/engineering/search")
def engineering_search(
    query: str = Query(..., min_length=1, description="Engineering search query"),
) -> List[dict]:
    try:
        return service.search_core(query)
    except SourceUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Source unavailable") from exc


@app.get("/engineering/doaj")
def engineering_doaj(
    query: str = Query(..., min_length=1, description="DOAJ search query"),
) -> List[dict]:
    try:
        return service.search_doaj(query)
    except SourceUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Source unavailable") from exc


@app.get("/engineering/arxiv")
def engineering_arxiv(
    query: str = Query(..., min_length=1, description="arXiv search query"),
) -> List[dict]:
    try:
        return service.search_arxiv(query)
    except SourceUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Source unavailable") from exc


@app.get("/engineering/combined-search")
def engineering_combined_search(
    query: str = Query(..., min_length=1, description="Combined engineering search query"),
) -> List[dict]:
    try:
        return service.combined_search(query)
    except SourceUnavailableError as exc:
        raise HTTPException(
            status_code=503,
            detail="All engineering sources are unavailable",
        ) from exc
