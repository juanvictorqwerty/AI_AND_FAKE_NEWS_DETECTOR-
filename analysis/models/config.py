import os
import json
from typing import List
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # Application Configuration
    app_env: str = "development"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    app_debug: bool = True
    max_image_size_mb: int = 20

    # Base de données
    database_url: str = Field(..., validation_alias="DATABASE_URL")

    # AI Model Configuration
    ai_model_name: str = "Organika/sdxl-detector"
    
    # TTL Configuration (in seconds)
    file_ttl: int = 3600
    result_ttl: int = 3600
    
    # Aggregation Configuration
    aggregation_confidence_threshold: float = 0.5
    
    # CORS Configuration
    cors_origins_raw: str = '[*]'
    
    @property
    def cors_origins(self) -> List[str]:
        try:
            return json.loads(self.cors_origins_raw)
        except:
            return [self.cors_origins_raw]

    # Dynamically select the env file based on the APP_ENV system variable
    model_config = SettingsConfigDict(
        env_file=".env.production" if os.getenv("APP_ENV") == "production" else ".env.development",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
