from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "Legal PDF API"
    SECRET_KEY: str = "dev-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    DB_DRIVER: str = "ODBC Driver 18 for SQL Server"
    DB_SERVER: str = "localhost"
    DB_PORT: int = 1433
    DB_NAME: str = "legal_pdf_db"
    DB_USER: str = "sa"
    DB_PASSWORD: str = "YourStrong@Passw0rd"
    DB_TRUST_CERT: str = "yes"
    DB_ENCRYPT: str = "yes"

    UPLOAD_DIR: str = "uploads"

    # Ollama — local LLM for PDF summarisation
    OLLAMA_HOST:  str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3.2"   # any model pulled via `ollama pull <model>`

    # Tesseract OCR
    TESSERACT_CMD:  str = ""       # blank = use system PATH; Windows: full path to tesseract.exe
    TESSERACT_LANG: str = "eng+hin"    # English + Hindi

    # Email (SMTP) — set in .env for production
    SMTP_HOST:     str = ""
    SMTP_PORT:     int = 587
    SMTP_USER:     str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM:     str = ""

    # Twilio SMS — set in .env for production
    TWILIO_ACCOUNT_SID:  str = ""
    TWILIO_AUTH_TOKEN:   str = ""
    TWILIO_PHONE_NUMBER: str = ""

    @field_validator("SMTP_PORT", mode="before")
    @classmethod
    def _default_smtp_port(cls, v):
        if v == "" or v is None:
            return 587
        return v

    @field_validator("DB_PORT", mode="before")
    @classmethod
    def _default_db_port(cls, v):
        if v == "" or v is None:
            return 1433
        return v

    model_config = {"env_file": ".env"}


settings = Settings()
