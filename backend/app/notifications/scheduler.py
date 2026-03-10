"""
Notification Scheduler — генерирует персонализированные напоминания.
Записывает уведомления в БД (модель Notification).
"""
from datetime import datetime, date, timezone, timedelta
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy import select
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.notification import Notification
from app.config import get_settings
import logging

logger = logging.getLogger(__name__)


async def _add_notification_db(db: AsyncSession, user_id: int, type_: str,
                                title: str, body: str, habit_id: int | None = None):
    """Add a notification to DB, avoiding duplicates for same habit+type today."""
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    existing = await db.execute(
        select(Notification).where(
            Notification.user_id == user_id,
            Notification.type == type_,
            Notification.habit_id == habit_id,
            Notification.created_at >= today_start,
        )
    )
    if existing.scalar_one_or_none():
        return  # Already notified today

    notification = Notification(
        user_id=user_id,
        type=type_,
        title=title,
        body=body,
        habit_id=habit_id,
    )
    db.add(notification)


async def check_and_generate_reminders():
    """Periodic task: check habits and generate reminders."""
    settings = get_settings()
    engine = create_async_engine(settings.DATABASE_URL)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as db:
        today = date.today()
        now = datetime.now(timezone.utc)

        # Get all active habits
        result = await db.execute(select(Habit).where(Habit.is_active == True))
        habits = result.scalars().all()

        for habit in habits:
            # Check if already completed today
            result = await db.execute(
                select(HabitLog).where(
                    HabitLog.habit_id == habit.id,
                    HabitLog.date == today,
                    HabitLog.completed == True,
                )
            )
            if result.scalar_one_or_none():
                continue  # Already done

            # Check if it's time to remind (target_time based)
            if habit.target_time:
                try:
                    target_hour, target_min = map(int, habit.target_time.split(":"))
                    target_dt = now.replace(hour=target_hour, minute=target_min)
                    if now >= target_dt - timedelta(minutes=15) and now <= target_dt + timedelta(minutes=30):
                        await _add_notification_db(
                            db, habit.user_id, "reminder",
                            f"Время для '{habit.name}'!",
                            f"Не забудь выполнить привычку. У тебя отличная серия!",
                            habit.id,
                        )
                except (ValueError, AttributeError):
                    pass

            # Late in the day reminder (after 20:00) for habits without target time
            if not habit.target_time and now.hour >= 20:
                await _add_notification_db(
                    db, habit.user_id, "evening_reminder",
                    "Ещё не поздно!",
                    f"Привычка '{habit.name}' ждёт тебя сегодня.",
                    habit.id,
                )

        await db.commit()

    await engine.dispose()
    logger.info(f"Reminder check completed at {now}")



def create_scheduler() -> AsyncIOScheduler:
    """Create and configure the notification scheduler."""
    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        check_and_generate_reminders,
        "interval",
        minutes=15,
        id="reminder_check",
        replace_existing=True,
    )
    return scheduler

