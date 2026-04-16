"""Secure Image Catalog API.

A deliberately-small FastAPI service that persists container-image records
to Postgres. Used as the middle tier in the JFrog + Chainguard POC.
"""
from __future__ import annotations

import os
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import (
    Column, DateTime, Integer, String, create_engine, func, select,
)
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://catalog:catalog@postgres:5432/catalog",
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


class Image(Base):
    __tablename__ = "images"
    id = Column(Integer, primary_key=True)
    name = Column(String(256), nullable=False)
    tag = Column(String(128), nullable=False, default="latest")
    base_flavor = Column(String(32), nullable=False)  # chainguard | baseline
    cves_high = Column(Integer, nullable=False, default=0)
    cves_medium = Column(Integer, nullable=False, default=0)
    cves_low = Column(Integer, nullable=False, default=0)
    last_scanned = Column(DateTime(timezone=True), server_default=func.now())


class ImageIn(BaseModel):
    name: str = Field(min_length=1, max_length=256)
    tag: str = Field(default="latest", max_length=128)
    base_flavor: str = Field(pattern="^(chainguard|baseline)$")
    cves_high: int = 0
    cves_medium: int = 0
    cves_low: int = 0


class ImageOut(ImageIn):
    id: int
    last_scanned: Optional[datetime] = None

    class Config:
        from_attributes = True


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Secure Image Catalog", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/api/images", response_model=list[ImageOut])
def list_images():
    with SessionLocal() as s:
        return s.execute(select(Image).order_by(Image.id.desc())).scalars().all()


@app.post("/api/images", response_model=ImageOut, status_code=201)
def create_image(payload: ImageIn):
    with SessionLocal() as s:
        row = Image(**payload.model_dump())
        s.add(row)
        s.commit()
        s.refresh(row)
        return row


@app.delete("/api/images/{image_id}", status_code=204)
def delete_image(image_id: int):
    with SessionLocal() as s:
        row = s.get(Image, image_id)
        if not row:
            raise HTTPException(status_code=404, detail="not found")
        s.delete(row)
        s.commit()


@app.get("/api/stats")
def stats():
    """Aggregate CVE totals by flavor — powers the dashboard cards."""
    with SessionLocal() as s:
        rows = s.execute(
            select(
                Image.base_flavor,
                func.count(Image.id),
                func.coalesce(func.sum(Image.cves_high), 0),
                func.coalesce(func.sum(Image.cves_medium), 0),
                func.coalesce(func.sum(Image.cves_low), 0),
            ).group_by(Image.base_flavor)
        ).all()
    return {
        flavor: {
            "image_count": count,
            "cves_high": int(high),
            "cves_medium": int(med),
            "cves_low": int(low),
        }
        for flavor, count, high, med, low in rows
    }
