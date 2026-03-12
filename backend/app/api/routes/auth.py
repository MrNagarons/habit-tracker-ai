from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, Token, GoogleAuthRequest, UserUpdate, ChangePasswordRequest
from app.api.auth_utils import get_password_hash, verify_password, create_access_token, get_current_user
from app.config import get_settings
import logging
import os
import uuid

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])

AVATAR_DIR = "/app/data/avatars"


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    # Check if username or email already exists
    result = await db.execute(
        select(User).where((User.username == user_data.username) | (User.email == user_data.email))
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username or email already registered",
        )

    user = User(
        username=user_data.username,
        email=user_data.email,
        password_hash=get_password_hash(user_data.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == form_data.username))
    user = result.scalar_one_or_none()

    if not user or not user.password_hash or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": user.id})
    return Token(access_token=access_token)


@router.post("/google", response_model=Token)
async def google_auth(data: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    """
    Authenticate via Google. Frontend sends the id_token from Google Sign-In.
    If user doesn't exist — auto-register.
    """
    settings = get_settings()
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=501, detail="Google auth not configured on server")

    try:
        from google.oauth2 import id_token
        from google.auth.transport import requests as google_requests
        idinfo = id_token.verify_oauth2_token(
            data.id_token,
            google_requests.Request(),
            settings.GOOGLE_CLIENT_ID,
        )
    except Exception as e:
        logger.error(f"Google token verification failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid Google token")

    google_id = idinfo["sub"]
    email = idinfo.get("email", "")
    name = idinfo.get("name", email.split("@")[0])
    picture = idinfo.get("picture")

    # Find by google_id first
    result = await db.execute(select(User).where(User.google_id == google_id))
    user = result.scalar_one_or_none()

    if not user:
        # Find by email — link existing account
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            user.google_id = google_id
            if picture:
                user.avatar_url = picture
            await db.commit()
        else:
            # Create new user
            # Ensure unique username
            base_username = name.replace(" ", "_").lower()[:40]
            username = base_username
            counter = 1
            while True:
                result = await db.execute(select(User).where(User.username == username))
                if not result.scalar_one_or_none():
                    break
                username = f"{base_username}_{counter}"
                counter += 1

            user = User(
                username=username,
                email=email,
                google_id=google_id,
                avatar_url=picture,
                password_hash=None,
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)

    access_token = create_access_token(data={"sub": user.id})
    return Token(access_token=access_token)


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=UserResponse)
async def update_profile(
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update current user's profile."""
    update_data = data.model_dump(exclude_unset=True)

    if "username" in update_data:
        # Check uniqueness
        result = await db.execute(
            select(User).where(User.username == update_data["username"], User.id != current_user.id)
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Username already taken")

    if "email" in update_data:
        result = await db.execute(
            select(User).where(User.email == update_data["email"], User.id != current_user.id)
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Email already taken")

    for field, value in update_data.items():
        setattr(current_user, field, value)

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.post("/me/avatar", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload user avatar image."""
    # Validate file type
    allowed_types = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Разрешены только изображения (JPEG, PNG, WebP, GIF)")

    # Read and check size (max 5MB)
    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Файл слишком большой (максимум 5 МБ)")

    # Create directory
    os.makedirs(AVATAR_DIR, exist_ok=True)

    # Delete old avatar file if exists
    if current_user.avatar_url and "/data/avatars/" in (current_user.avatar_url or ""):
        old_filename = current_user.avatar_url.split("/")[-1]
        old_path = os.path.join(AVATAR_DIR, old_filename)
        if os.path.exists(old_path):
            os.remove(old_path)

    # Save new file
    ext = file.filename.split(".")[-1] if file.filename and "." in file.filename else "jpg"
    filename = f"{current_user.id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(AVATAR_DIR, filename)

    with open(filepath, "wb") as f:
        f.write(content)

    # Update user
    current_user.avatar_url = f"/data/avatars/{filename}"
    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.post("/change-password")
async def change_password(
    data: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Change user password."""
    if not current_user.password_hash:
        raise HTTPException(status_code=400, detail="Аккаунт использует Google авторизацию")

    if not verify_password(data.current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Текущий пароль неверный")

    current_user.password_hash = get_password_hash(data.new_password)
    await db.commit()
    return {"message": "Пароль успешно изменён"}


