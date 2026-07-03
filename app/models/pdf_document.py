from datetime import datetime, date, timezone
from sqlalchemy import String, DateTime, ForeignKey, Integer, BigInteger, Text, Date
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class PDFDocument(Base):
    __tablename__ = "pdf_documents"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(String(500), nullable=False)
    file_size: Mapped[int] = mapped_column(BigInteger, nullable=False)

    # Common metadata
    document_name: Mapped[str | None] = mapped_column(String(500), nullable=True)
    issue_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    version_no: Mapped[str | None] = mapped_column(String(50), nullable=True, default="1.0")
    department_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("departments.id"), nullable=True)
    document_type_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("document_types.id"), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Shared across multiple types
    reference_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    effective_from: Mapped[date | None] = mapped_column(Date, nullable=True)
    gazette_reference: Mapped[str | None] = mapped_column(String(500), nullable=True)
    legal_authority: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Act-specific
    short_title: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Circular-specific
    valid_until: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Policy-specific
    sector_domain: Mapped[str | None] = mapped_column(String(255), nullable=True)
    implementing_agency: Mapped[str | None] = mapped_column(String(255), nullable=True)
    next_review_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Rules & Regulations-specific
    rule_making_authority: Mapped[str | None] = mapped_column(String(255), nullable=True)

    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    uploaded_by: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

