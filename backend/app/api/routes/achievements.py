"""
Achievements routes — достижения пользователя.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.db.database import get_db
from app.models.user import User
from app.models.achievement import Achievement, AchievementType, ACHIEVEMENT_META
from app.schemas.achievements import AchievementResponse, AchievementCheckResponse
from app.api.auth_utils import get_current_user
from app.services.achievement_checker import check_and_unlock

router = APIRouter(prefix="/achievements", tags=["achievements"])


@router.get("/", response_model=list[AchievementResponse])
async def get_achievements(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all achievements with unlock status for current user."""
    # Get user's unlocked achievements
    result = await db.execute(
        select(Achievement).where(Achievement.user_id == current_user.id)
    )
    unlocked = {a.achievement_type: a for a in result.scalars().all()}

    # Build full list with all possible achievements
    achievements = []
    for achievement_type in AchievementType:
        meta = ACHIEVEMENT_META.get(achievement_type.value, {})
        user_achievement = unlocked.get(achievement_type.value)
        achievements.append(AchievementResponse(
            achievement_type=achievement_type.value,
            title=meta.get("title", achievement_type.value),
            description=meta.get("description", ""),
            icon=meta.get("icon", "🏅"),
            unlocked=user_achievement is not None,
            unlocked_at=user_achievement.unlocked_at if user_achievement else None,
        ))

    return achievements


@router.post("/check", response_model=AchievementCheckResponse)
async def check_achievements(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Manually trigger achievement check."""
    newly_unlocked = await check_and_unlock(db, current_user.id)
    await db.commit()

    total_res = await db.execute(
        select(func.count(Achievement.id)).where(
            Achievement.user_id == current_user.id
        )
    )
    total = total_res.scalar() or 0

    return AchievementCheckResponse(
        newly_unlocked=newly_unlocked,
        total_unlocked=total,
    )

