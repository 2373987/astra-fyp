from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from urllib.parse import urlencode
from urllib.request import urlopen, Request
import json
import urllib.parse
import urllib.request
import urllib.error
import socket
import time

app = FastAPI(title="Astra AI Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # dev only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class AnalyzeRequest(BaseModel):
    text: str

@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/analyze")
def analyze(req: AnalyzeRequest):
    text = (req.text or "").lower()

    # FIXED: missing commas in your list were merging strings
    high_risk_words = [
        "scared", "fear", "help", "unsafe",
        "follow", "stalker", "stalking", "panic", "threat",
        "kill", "attack", "hurt", "die", "knife", "gun", "rape", "kidnap",
        "danger", "weapon", "chasing",
    ]

    if any(w in text for w in high_risk_words):
        return {
            "emotion": "fear",
            "risk_level": "high",
            "recommended_action": "offer_sos",
            "response_text": (
                "I’m here with you. If you feel in danger, press SOS now. "
                "Move toward a well-lit area or a place with people."
            )
        }

    return {
        "emotion": "calm",
        "risk_level": "low",
        "response_text": (
            "Hey, I’m with you. You’re doing okay. "
            "Tell me where you are and I’ll guide you."
        )
    }


# -------------------------
# Nearby (Overpass) - FIXED
# -------------------------
OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.openstreetmap.ru/api/interpreter",
]

def _overpass_request(query: str, timeout_s: int = 35) -> dict:
    """
    Try multiple Overpass instances to reduce 504 timeouts.
    """
    headers = {
        "User-Agent": "Astra-FYP/1.0 (Safety App FYP)",
        "Accept": "application/json",
    }

    last_err = None
    for url in OVERPASS_URLS:
        try:
            data = urlencode({"data": query}).encode("utf-8")
            req = Request(url, data=data, headers=headers)
            with urlopen(req, timeout=timeout_s) as resp:
                raw = resp.read().decode("utf-8")
            return json.loads(raw)
        except Exception as e:
            last_err = e
            continue

    raise last_err


@app.get("/nearby")
def nearby(lat: float, lon: float, radius_m: int = 3000):
    """
    Returns nearby police stations + hospitals around (lat, lon) using Overpass (OpenStreetMap).
    Includes node + way + relation (many POIs are ways/relations).
    """
    query = f"""
    [out:json][timeout:25];
    (
      node["amenity"="police"](around:{radius_m},{lat},{lon});
      way["amenity"="police"](around:{radius_m},{lat},{lon});
      relation["amenity"="police"](around:{radius_m},{lat},{lon});

      node["amenity"="hospital"](around:{radius_m},{lat},{lon});
      way["amenity"="hospital"](around:{radius_m},{lat},{lon});
      relation["amenity"="hospital"](around:{radius_m},{lat},{lon});
    );
    out center tags;
    """

    url = "https://overpass-api.de/api/interpreter"
    data = urlencode({"data": query}).encode("utf-8")

    req = Request(url, data=data, headers={"User-Agent": "Astra-FYP/1.0"})
    with urlopen(req, timeout=35) as resp:
        raw = resp.read().decode("utf-8")

    parsed = json.loads(raw)

    results = []
    for el in parsed.get("elements", []):
        tags = el.get("tags", {}) or {}
        amenity = tags.get("amenity", "unknown")
        name = tags.get("name") or ("Police Station" if amenity == "police" else "Hospital")

        # nodes have lat/lon; ways/relations have center
        if "lat" in el and "lon" in el:
            plat, plon = el["lat"], el["lon"]
        else:
            center = el.get("center") or {}
            plat, plon = center.get("lat"), center.get("lon")

        if plat is None or plon is None:
            continue

        results.append({
            "type": amenity,
            "name": name,
            "lat": float(plat),
            "lon": float(plon),
            "phone": tags.get("phone") or tags.get("contact:phone") or "",
        })

    return {"ok": True, "count": len(results), "items": results}

# -------------------------
# Route (OSRM)
# -------------------------
@app.get("/route")
def route(
    start_lat: float,
    start_lon: float,
    end_lat: float,
    end_lon: float,
    profile: str = "foot"
):
    """
    Returns a real route polyline using OSRM public server.
    profile: "foot" (recommended), "driving", "bike" (may vary)
    """
    coords = f"{start_lon},{start_lat};{end_lon},{end_lat}"

    params = {
        "overview": "full",
        "geometries": "geojson",
        "steps": "false",
    }

    url = f"https://router.project-osrm.org/route/v1/{profile}/{coords}?{urllib.parse.urlencode(params)}"

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Astra-FYP/1.0"}
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return {"ok": False, "message": f"OSRM request failed: {e}"}

    if data.get("code") != "Ok" or not data.get("routes"):
        return {"ok": False, "message": "No route found", "raw": data}

    route0 = data["routes"][0]
    geometry = route0["geometry"]

    points = [{"lat": lat, "lon": lon} for lon, lat in geometry["coordinates"]]

    return {
        "ok": True,
        "distance_m": route0.get("distance"),
        "duration_s": route0.get("duration"),
        "points": points,
    }
