"""
Achievement model — достижения пользователей.
Небольшой набор без чрезмерной геймификации.
"""
from datetime import datetime, timezone
from sqlalchemy import Integer, String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base
import enum


class AchievementType(str, enum.Enum):
    FIRST_HABIT = "first_habit"           # Создал первую привычку
    STREAK_7 = "streak_7"                 # Серия 7 дней
    STREAK_30 = "streak_30"               # Серия 30 дней
    STREAK_100 = "streak_100"             # Серия 100 дней
    WEEK_PERFECT = "week_perfect"         # Неделя 100% выполнения
    MONTH_PERFECT = "month_perfect"       # Месяц 100% выполнения
    TOTAL_100_LOGS = "total_100_logs"     # 100 записей в логах
    FIVE_HABITS = "five_habits"           # 5 активных привычек


# Метаданные достижений для отображения
ACHIEVEMENT_META: dict[str, dict] = {
    "first_habit": {
        "title": "Первый шаг",
        "description": "Создай свою первую привычку",
        "icon": "🌱",
    },
    "streak_7": {
        "title": "Неделя огня",
        "description": "Серия 7 дней подряд",
        "icon": "🔥",
    },
    "streak_30": {
        "title": "Месяц дисциплины",
        "description": "Серия 30 дней подряд",
        "icon": "💎",
    },
    "streak_100": {
        "title": "Легенда",
        "description": "Серия 100 дней подряд",
        "icon": "👑",
    },
    "week_perfect": {
        "title": "Идеальная неделя",
        "description": "100% выполнение за 7 дней",
        "icon": "⭐",
    },
    "month_perfect": {
        "title": "Идеальный месяц",
        "description": "100% выполнение за 30 дней",
        "icon": "🏆",
    },
    "total_100_logs": {
        "title": "Сотня",
        "description": "100 выполненных записей",
        "icon": "💯",
    },
    "five_habits": {
        "title": "Мультитрекер",
        "description": "5 активных привычек одновременно",
        "icon": "🎯",
    },
}


class Achievement(Base):
    __tablename__ = "achievements"
    __table_args__ = (
        UniqueConstraint("user_id", "achievement_type", name="uq_user_achievement"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    achievement_type: Mapped[str] = mapped_column(String(50), nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    user = relationship("User", back_populates="achievements")

