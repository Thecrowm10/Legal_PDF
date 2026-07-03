from abc import ABC, abstractmethod
from typing import Optional

from app.models.user import User


class IUserRepository(ABC):

    @abstractmethod
    def get_by_id(self, user_id: int) -> Optional[User]:
        ...

    @abstractmethod
    def get_by_id_for_auth(self, user_id: int) -> Optional[User]:
        ...

    @abstractmethod
    def get_by_username(self, username: str) -> Optional[User]:
        ...

    @abstractmethod
    def get_by_email(self, email: str) -> Optional[User]:
        ...

    @abstractmethod
    def create(
        self,
        username: str,
        email: str,
        hashed_password: str,
        first_name: Optional[str] = None,
        last_name: Optional[str] = None,
        role_id: Optional[int] = None,
        department_id: Optional[str] = None,
        mobile_number: Optional[str] = None,
    ) -> User:
        ...

    @abstractmethod
    def update(
        self,
        user_id: int,
        first_name: Optional[str] = None,
        last_name: Optional[str] = None,
        email: Optional[str] = None,
        is_active: Optional[bool] = None,
        role_id: Optional[int] = None,
        department_id: Optional[int] = None,
    ) -> Optional[User]:
        ...

    @abstractmethod
    def list_all(
        self,
        skip: int = 0,
        limit: int = 100,
        exclude_user_id: Optional[int] = None,
        department_ids: Optional[str] = None,
    ) -> list[User]:
        ...

    @abstractmethod
    def get_by_mobile(self, mobile_number: str) -> Optional[User]:
        ...

    @abstractmethod
    def change_password(self, user_id: int, hashed_password: str) -> None:
        ...
