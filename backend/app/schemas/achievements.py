from pydantic import BaseModel
from datetime import datetime


class AchievementResponse(BaseModel):
    achievement_type: str
    title: str
    description: str
    icon: str
    unlocked: bool
    unlocked_at: datetime | None = None

    model_config = {"from_attributes": True}


class AchievementCheckResponse(BaseModel):
    newly_unlocked: list[str]
    total_unlocked: int

