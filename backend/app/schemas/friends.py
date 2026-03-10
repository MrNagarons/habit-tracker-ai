from pydantic import BaseModel
from datetime import datetime


class FriendRequestCreate(BaseModel):
    friend_id: int


class FriendshipResponse(BaseModel):
    id: int
    user_id: int
    friend_id: int
    friend_username: str
    friend_avatar_url: str | None = None
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class FriendProgressResponse(BaseModel):
    user_id: int
    username: str
    avatar_url: str | None = None
    total_habits: int
    active_habits: int
    best_streak: int
    overall_completion_rate: float
    today_completed: int
    today_total: int

