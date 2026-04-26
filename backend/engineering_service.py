import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Any, Dict, List, Optional


class SourceUnavailableError(Exception):
    pass


@dataclass
class EngineeringResult:
    id: str
    title: str
    authors: str
    abstract: str
    source: str
    pdf_url: str
    has_full_text: bool
    journal: str = ""
    date: str = ""
    link: str = ""
    identifier_label: str = "Identifier"
    identifier_value: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "authors": self.authors,
            "abstract": self.abstract,
            "source": self.source,
            "pdf_url": self.pdf_url,
            "has_full_text": self.has_full_text,
            "journal": self.journal,
            "date": self.date,
            "link": self.link,
            "identifier_label": self.identifier_label,
            "identifier_value": self.identifier_value,
        }


class EngineeringService:
    CORE_SEARCH_URL = "https://api.core.ac.uk/v3/search/works/"
    DOAJ_SEARCH_URL = "https://doaj.org/api/search/articles/{query}"
    ARXIV_SEARCH_URL = "http://export.arxiv.org/api/query"

    def __init__(self) -> None:
        self.core_api_key = os.getenv("CORE_API_KEY", "").strip()

    def search_core(self, query: str, limit: int = 15) -> List[Dict[str, Any]]:
        if not self.core_api_key:
            raise SourceUnavailableError("CORE_API_KEY is not configured.")

        params = {"q": query, "limit": str(limit)}
        headers = {}
        headers["Authorization"] = f"Bearer {self.core_api_key}"

        data = self._fetch_json(self.CORE_SEARCH_URL, params=params, headers=headers)
        items = data.get("results") or data.get("data") or []
        results: List[EngineeringResult] = []

        for item in items:
            if not isinstance(item, dict):
                continue

            title = self._clean_text(item.get("title"))
            abstract = self._clean_text(
                item.get("abstract") or item.get("description") or item.get("summary")
            )
            authors = self._parse_core_authors(item.get("authors"))
            pdf_url = self._pick_first_url(
                [
                    item.get("downloadUrl"),
                    item.get("fullTextLink"),
                    item.get("pdfUrl"),
                    self._search_link_collection(item.get("links"), "pdf"),
                    self._search_link_collection(item.get("sourceFulltextUrls"), ""),
                ]
            )
            landing_url = self._pick_first_url(
                [
                    item.get("fullTextLink"),
                    item.get("downloadUrl"),
                    item.get("doi"),
                    self._search_link_collection(item.get("links"), "doi"),
                    self._search_link_collection(item.get("links"), "html"),
                ]
            )
            journal = self._clean_text(
                item.get("publisher") or item.get("journals") or item.get("repository")
            )
            identifier_value = self._clean_text(
                item.get("doi") or item.get("id") or item.get("_id")
            )

            if not title:
                continue

            results.append(
                EngineeringResult(
                    id=self._stable_id("core", identifier_value or title),
                    title=title,
                    authors=authors,
                    abstract=abstract or "No abstract available.",
                    source="CORE",
                    pdf_url=pdf_url,
                    has_full_text=bool(pdf_url),
                    journal=journal,
                    date=self._clean_text(item.get("yearPublished") or item.get("publishedDate")),
                    link=landing_url or pdf_url,
                    identifier_label="DOI" if identifier_value.startswith("10.") else "CORE ID",
                    identifier_value=identifier_value or self._stable_id("core", title),
                )
            )

        return [result.to_dict() for result in results]

    def search_doaj(self, query: str, limit: int = 15) -> List[Dict[str, Any]]:
        url = self.DOAJ_SEARCH_URL.format(
            query=urllib.parse.quote(query, safe="")
        )
        data = self._fetch_json(
            url,
            params={"page": "1", "pageSize": str(limit)},
        )
        items = data.get("results") or []
        results: List[EngineeringResult] = []

        for item in items:
            if not isinstance(item, dict):
                continue

            bibjson = item.get("bibjson") if isinstance(item.get("bibjson"), dict) else {}
            title = self._clean_text(bibjson.get("title"))
            authors = self._parse_doaj_authors(bibjson.get("author"))
            abstract = self._clean_text(bibjson.get("abstract")) or "No abstract available."
            links = bibjson.get("link") if isinstance(bibjson.get("link"), list) else []
            pdf_url = self._pick_first_url(
                [
                    self._search_link_collection(links, "pdf"),
                    self._search_link_collection(links, "fulltext"),
                    self._search_link_collection(links, "html"),
                ]
            )
            article_url = self._pick_first_url(
                [
                    self._search_link_collection(links, "html"),
                    self._search_link_collection(links, "fulltext"),
                    pdf_url,
                    self._extract_doaj_record_url(item),
                ]
            )
            identifier_value = self._clean_text(
                bibjson.get("doi")
                or self._extract_identifier_by_type(bibjson.get("identifier"), "doi")
                or item.get("id")
                or title
            )
            date_parts = [
                self._clean_text((bibjson.get("year") or "")),
                self._clean_text((bibjson.get("month") or "")),
            ]
            date = " ".join(part for part in date_parts if part)

            if not title:
                continue

            results.append(
                EngineeringResult(
                    id=self._stable_id("doaj", identifier_value or title),
                    title=title,
                    authors=authors,
                    abstract=abstract,
                    source="DOAJ",
                    pdf_url=pdf_url,
                    has_full_text=bool(pdf_url or article_url),
                    journal=self._clean_text(
                        (bibjson.get("journal") or {}).get("title")
                        if isinstance(bibjson.get("journal"), dict)
                        else ""
                    ),
                    date=date,
                    link=article_url,
                    identifier_label="DOI" if identifier_value.startswith("10.") else "DOAJ ID",
                    identifier_value=identifier_value,
                )
            )

        return [result.to_dict() for result in results]

    def search_arxiv(self, query: str, limit: int = 15) -> List[Dict[str, Any]]:
        data = self._fetch_text(
            self.ARXIV_SEARCH_URL,
            params={
                "search_query": f"all:{query}",
                "start": "0",
                "max_results": str(limit),
            },
        )

        namespace = {"atom": "http://www.w3.org/2005/Atom"}
        root = ET.fromstring(data)
        results: List[EngineeringResult] = []

        for entry in root.findall("atom:entry", namespace):
            title = self._clean_text(entry.findtext("atom:title", "", namespace))
            abstract = self._clean_text(entry.findtext("atom:summary", "", namespace))
            authors = ", ".join(
                self._clean_text(author.findtext("atom:name", "", namespace))
                for author in entry.findall("atom:author", namespace)
                if self._clean_text(author.findtext("atom:name", "", namespace))
            )
            entry_id = self._clean_text(entry.findtext("atom:id", "", namespace))
            pdf_url = ""
            landing_url = entry_id

            for link in entry.findall("atom:link", namespace):
                href = (link.attrib.get("href") or "").strip()
                title_attr = (link.attrib.get("title") or "").strip().lower()
                type_attr = (link.attrib.get("type") or "").strip().lower()

                if title_attr == "pdf" or type_attr == "application/pdf":
                    pdf_url = href
                elif not landing_url and href:
                    landing_url = href

            identifier_value = entry_id.rsplit("/", 1)[-1]

            if not title:
                continue

            results.append(
                EngineeringResult(
                    id=self._stable_id("arxiv", identifier_value or title),
                    title=title,
                    authors=authors,
                    abstract=abstract or "No abstract available.",
                    source="arXiv",
                    pdf_url=pdf_url,
                    has_full_text=bool(pdf_url),
                    journal="arXiv",
                    date=self._clean_text(entry.findtext("atom:published", "", namespace)),
                    link=landing_url or pdf_url,
                    identifier_label="arXiv",
                    identifier_value=identifier_value,
                )
            )

        return [result.to_dict() for result in results]

    def combined_search(self, query: str, limit_per_source: int = 15) -> List[Dict[str, Any]]:
        sources = [
            ("CORE", lambda: self.search_core(query, limit=limit_per_source)),
            ("DOAJ", lambda: self.search_doaj(query, limit=limit_per_source)),
            ("arXiv", lambda: self.search_arxiv(query, limit=limit_per_source)),
        ]

        collected: List[Dict[str, Any]] = []
        successful_sources = 0

        for _, fetcher in sources:
            try:
                collected.extend(fetcher())
                successful_sources += 1
            except SourceUnavailableError:
                continue

        if successful_sources == 0:
            raise SourceUnavailableError("All engineering sources are unavailable.")

        return self._deduplicate_results(collected)

    def _deduplicate_results(self, items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        deduped: List[Dict[str, Any]] = []

        for candidate in sorted(items, key=self._candidate_rank, reverse=True):
            title = self._normalize_title(str(candidate.get("title", "")))
            if not title:
                continue

            match_index: Optional[int] = None
            for index, existing in enumerate(deduped):
                existing_title = self._normalize_title(str(existing.get("title", "")))
                if title == existing_title:
                    match_index = index
                    break

                similarity = SequenceMatcher(None, title, existing_title).ratio()
                if similarity >= 0.92:
                    match_index = index
                    break

            if match_index is None:
                deduped.append(candidate)
            else:
                deduped[match_index] = self._prefer_richer_result(
                    deduped[match_index],
                    candidate,
                )

        return deduped

    def _prefer_richer_result(
        self,
        existing: Dict[str, Any],
        candidate: Dict[str, Any],
    ) -> Dict[str, Any]:
        existing_score = self._candidate_rank(existing)
        candidate_score = self._candidate_rank(candidate)
        if candidate_score > existing_score:
            return candidate

        merged = dict(existing)
        if not merged.get("pdf_url") and candidate.get("pdf_url"):
            merged["pdf_url"] = candidate["pdf_url"]
            merged["has_full_text"] = candidate.get("has_full_text", False)
        if not merged.get("abstract") and candidate.get("abstract"):
            merged["abstract"] = candidate["abstract"]
        if not merged.get("authors") and candidate.get("authors"):
            merged["authors"] = candidate["authors"]
        if not merged.get("link") and candidate.get("link"):
            merged["link"] = candidate["link"]
        return merged

    def _candidate_rank(self, item: Dict[str, Any]) -> int:
        source = str(item.get("source", "")).upper()
        source_bonus = {"DOAJ": 30, "CORE": 20, "ARXIV": 10}.get(source, 0)
        pdf_bonus = 20 if item.get("has_full_text") else 0
        abstract_bonus = min(len(str(item.get("abstract", ""))) // 50, 20)
        return source_bonus + pdf_bonus + abstract_bonus

    def _fetch_json(
        self,
        url: str,
        *,
        params: Optional[Dict[str, str]] = None,
        headers: Optional[Dict[str, str]] = None,
    ) -> Dict[str, Any]:
        raw = self._fetch_text(url, params=params, headers=headers)
        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            raise SourceUnavailableError(f"Unexpected JSON response from {url}") from exc

    def _fetch_text(
        self,
        url: str,
        *,
        params: Optional[Dict[str, str]] = None,
        headers: Optional[Dict[str, str]] = None,
    ) -> str:
        full_url = url
        if params:
            query_string = urllib.parse.urlencode(params)
            separator = "&" if "?" in url else "?"
            full_url = f"{url}{separator}{query_string}"

        request_headers = {"User-Agent": "NeuroLit-Engineering/1.0"}
        if headers:
            request_headers.update(headers)

        request = urllib.request.Request(
            full_url,
            headers=request_headers,
        )

        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                return response.read().decode("utf-8", errors="replace")
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as exc:
            raise SourceUnavailableError(str(exc)) from exc

    def _clean_text(self, value: Any) -> str:
        text = str(value or "").replace("\n", " ").replace("\r", " ").strip()
        return re.sub(r"\s+", " ", text)

    def _parse_core_authors(self, authors: Any) -> str:
        if not isinstance(authors, list):
            return ""

        names: List[str] = []
        for author in authors:
            if isinstance(author, dict):
                name = self._clean_text(
                    author.get("name")
                    or author.get("fullName")
                    or author.get("author")
                )
            else:
                name = self._clean_text(author)

            if name:
                names.append(name)

        return ", ".join(names)

    def _parse_doaj_authors(self, authors: Any) -> str:
        if not isinstance(authors, list):
            return ""

        names: List[str] = []
        for author in authors:
            if isinstance(author, dict):
                name = self._clean_text(author.get("name"))
            else:
                name = self._clean_text(author)

            if name:
                names.append(name)

        return ", ".join(names)

    def _search_link_collection(self, items: Any, needle: str) -> str:
        if not isinstance(items, list):
            return ""

        needle = needle.lower()
        for item in items:
            if isinstance(item, str):
                value = item.strip()
                if value:
                    if not needle or needle in value.lower():
                        return value
                continue

            if not isinstance(item, dict):
                continue

            candidates = [
                item.get("url"),
                item.get("href"),
                item.get("link"),
            ]
            text = " ".join(
                self._clean_text(item.get(key))
                for key in ("type", "content_type", "title")
            ).lower()

            if needle and needle not in text:
                continue

            picked = self._pick_first_url(candidates)
            if picked:
                return picked

        return ""

    def _extract_identifier_by_type(self, items: Any, identifier_type: str) -> str:
        if not isinstance(items, list):
            return ""

        wanted = identifier_type.lower()
        for item in items:
            if not isinstance(item, dict):
                continue

            if self._clean_text(item.get("type")).lower() != wanted:
                continue

            value = self._clean_text(item.get("id"))
            if value:
                return value

        return ""

    def _pick_first_url(self, values: List[Any]) -> str:
        for value in values:
            candidate = self._clean_text(value)
            if candidate.startswith("http://") or candidate.startswith("https://"):
                return candidate
            if candidate.startswith("10."):
                return f"https://doi.org/{candidate}"
        return ""

    def _extract_doaj_record_url(self, item: Dict[str, Any]) -> str:
        record_id = self._clean_text(item.get("id"))
        if record_id:
            return f"https://doaj.org/article/{record_id}"
        return ""

    def _stable_id(self, prefix: str, seed: str) -> str:
        normalized = re.sub(r"[^a-zA-Z0-9]+", "-", seed.lower()).strip("-")
        if not normalized:
            normalized = "result"
        return f"{prefix}-{normalized[:120]}"

    def _normalize_title(self, title: str) -> str:
        lowered = title.lower().strip()
        lowered = re.sub(r"[^a-z0-9]+", " ", lowered)
        return re.sub(r"\s+", " ", lowered).strip()
