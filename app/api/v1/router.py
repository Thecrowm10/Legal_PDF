from fastapi import APIRouter

from app.api.v1 import admin_auth, auth, department, document_type, pdf, role, tag, user

router = APIRouter(prefix="/api/v1")
router.include_router(auth.router)
router.include_router(admin_auth.router)
router.include_router(role.router)
router.include_router(department.router)
router.include_router(document_type.router)
router.include_router(tag.router)
router.include_router(user.router)
router.include_router(pdf.router)
