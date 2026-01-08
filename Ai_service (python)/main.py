from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Astra AI Service")  # 👈 THIS LINE IS REQUIRED

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

    high_risk_words = [
    "scared", "fear", "help", "unsafe",
    "follow", "stalker", "stalking" "panic", "threat",
    "kill", "attack", "hurt", "die", "knife", "gun", "rape", "kidnap"
    "danger", "weapon", "chasing"
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
            "I’m with you. You’re doing okay. "
            "Tell me where you are and I’ll guide you."
        )
    }
