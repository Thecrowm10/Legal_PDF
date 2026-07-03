from typing import Optional

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.interfaces.user_repository import IUserRepository
from app.models.department import Department
from app.models.role import Role
from app.models.user import User



class UserRepository(IUserRepository):

    def __init__(self, db: Session):
        self._db = db

    def get_by_id(self, user_id: int) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_id @user_id = :user_id"),
            {"user_id": user_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def get_by_id_for_auth(self, user_id: int) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_id @user_id = :user_id"),
            {"user_id": user_id},
        )
        row = result.mappings().fetchone()
        return self._map_row_auth(row) if row else None

    def get_by_username(self, username: str) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_username @username = :username"),
            {"username": username},
        )
        row = result.mappings().fetchone()
        return self._map_row_auth(row) if row else None

    def get_by_mobile(self, mobile_number: str) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_mobile @mobile_number = :mobile_number"),
            {"mobile_number": mobile_number},
        )
        row = result.mappings().fetchone()
        return self._map_row_auth(row) if row else None

    def get_by_email(self, email: str) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_email @email = :email"),
            {"email": email},
        )
        row = result.mappings().fetchone()
        return self._map_row_auth(row) if row else None

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
        try:
            result = self._db.execute(
                text(
                    "EXEC sp_create_user "
                    "@username = :username, @email = :email, "
                    "@hashed_password = :hashed_password, "
                    "@first_name = :first_name, @last_name = :last_name, "
                    "@role_id = :role_id, @department_id = :department_id, "
                    "@mobile_number = :mobile_number"
                ),
                {
                    "username": username,
                    "email": email,
                    "hashed_password": hashed_password,
                    "first_name": first_name,
                    "last_name": last_name,
                    "role_id": role_id,
                    "department_id": department_id,
                    "mobile_number": mobile_number,
                },
            )
            row = result.mappings().fetchone()
            self._db.commit()
            return self._map_row(row)
        except IntegrityError as e:
            self._db.rollback()
            err = str(e.orig).lower()
            if "uq_users_username" in err:
                raise ValueError("Username is already taken")
            if "uq_users_email" in err:
                raise ValueError("Email is already registered")
            raise ValueError("A user with this username or email already exists")

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
        try:
            result = self._db.execute(
                text(
                    "EXEC sp_update_user "
                    "@user_id = :user_id, @first_name = :first_name, "
                    "@last_name = :last_name, @email = :email, "
                    "@is_active = :is_active, @role_id = :role_id, "
                    "@department_id = :department_id"
                ),
                {
                    "user_id": user_id,
                    "first_name": first_name,
                    "last_name": last_name,
                    "email": email,
                    "is_active": is_active,
                    "role_id": role_id,
                    "department_id": department_id,
                },
            )
            row = result.mappings().fetchone()
            self._db.commit()
            return self._map_row(row) if row else None
        except IntegrityError as e:
            self._db.rollback()
            err = str(e.orig).lower()
            if "uq_users_email" in err:
                raise ValueError("Email is already registered")
            raise ValueError("Update failed due to a conflict")

    def list_all(
        self,
        skip: int = 0,
        limit: int = 100,
        exclude_user_id: Optional[int] = None,
        department_ids: Optional[str] = None,
    ) -> list[User]:
        result = self._db.execute(
            text(
                "EXEC sp_list_users @skip = :skip, @limit = :limit, "
                "@exclude_user_id = :exclude_user_id, @department_ids = :department_ids"
            ),
            {"skip": skip, "limit": limit, "exclude_user_id": exclude_user_id, "department_ids": department_ids},
        )
        return [self._map_row(row) for row in result.mappings().fetchall()]

    def change_password(self, user_id: int, hashed_password: str) -> None:
        self._db.execute(
            text("EXEC sp_change_password @user_id = :user_id, @hashed_password = :hashed_password"),
            {"user_id": user_id, "hashed_password": hashed_password},
        )
        self._db.commit()

    @staticmethod
    def _build_departments(dept_id_str, department_name_raw, department_description):
        """Parse dept_id_str ('1' or '1,2') and pipe-separated names into Department list."""
        if not dept_id_str or not department_name_raw:
            return [], None
        ids = [i.strip() for i in dept_id_str.split(',')]
        names = department_name_raw.split('|')
        departments = []
        for did, dname in zip(ids, names):
            try:
                departments.append(Department(id=int(did), name=dname, description=department_description or None))
            except (ValueError, TypeError):
                pass
        return departments, departments[0] if departments else None

    @staticmethod
    def _map_row(row) -> User:
        row_dict = dict(row)
        user = User(
            id=row_dict["id"],
            username=row_dict["username"],
            email=row_dict["email"],
            hashed_password="",
            is_active=bool(row_dict["is_active"]),
            must_change_password=bool(row_dict.get("must_change_password", True)),
            mobile_number=row_dict.get("mobile_number"),
            password_changed_at=row_dict.get("password_changed_at"),
            first_name=row_dict.get("first_name"),
            last_name=row_dict.get("last_name"),
            role_id=row_dict.get("role_id"),
            department_id=row_dict.get("department_id"),
            created_at=row_dict["created_at"],
            updated_at=row_dict["updated_at"],
        )
        user.last_login = row_dict.get("last_login")
        if row_dict.get("role_id"):
            user.role = Role(
                id=row_dict["role_id"],
                name=row_dict["role_name"],
                description=row_dict["role_description"],
            )
        depts, primary = UserRepository._build_departments(
            row_dict.get("department_id"),
            row_dict.get("department_name"),
            row_dict.get("department_description"),
        )
        user.department = primary
        user.departments = depts
        return user

    @staticmethod
    def _map_row_auth(row) -> User:
        row_dict = dict(row)
        user = User(
            id=row_dict["id"],
            username=row_dict["username"],
            email=row_dict["email"],
            hashed_password=row_dict["hashed_password"],
            is_active=bool(row_dict["is_active"]),
            must_change_password=bool(row_dict.get("must_change_password", True)),
            mobile_number=row_dict.get("mobile_number"),
            password_changed_at=row_dict.get("password_changed_at"),
            first_name=row_dict.get("first_name"),
            last_name=row_dict.get("last_name"),
            role_id=row_dict.get("role_id"),
            department_id=row_dict.get("department_id"),
            created_at=row_dict["created_at"],
            updated_at=row_dict["updated_at"],
        )
        user.last_login = row_dict.get("last_login")
        if row_dict.get("role_id"):
            user.role = Role(
                id=row_dict["role_id"],
                name=row_dict["role_name"],
                description=row_dict["role_description"],
            )
        depts, primary = UserRepository._build_departments(
            row_dict.get("department_id"),
            row_dict.get("department_name"),
            row_dict.get("department_description"),
        )
        user.department = primary
        user.departments = depts
        return user
