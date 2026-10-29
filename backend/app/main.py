import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import get_settings
from .database import check_connection, init_db
from .routers import auth, climate, farms, predictions, productivity
from .services.ml import ModelError
from .services.weather import WeatherError

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("app")


@asynccontextmanager
async def lifespan(_: FastAPI):
    if get_settings().auto_create_tables:
        init_db()
    yield


app = FastAPI(
    title="Random Forest Regression-Based Climate and Crop Productivity Monitoring "
          "and Decision Support System for Farmers",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(get_settings().cors_origins),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

for module in (auth, farms, climate, productivity, predictions):
    app.include_router(module.router)


@app.exception_handler(WeatherError)
async def weather_error_handler(_: Request, exc: WeatherError):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(ModelError)
async def model_error_handler(_: Request, exc: ModelError):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_handler(_: Request, exc: RequestValidationError):
    """Return a readable one-line `detail` (the mobile app shows it directly)."""
    messages = []
    for err in exc.errors():
        field = ".".join(str(p) for p in err["loc"] if p not in ("body", "query"))
        messages.append(f"{field}: {err['msg']}" if field else err["msg"])
    return JSONResponse(
        status_code=422,
        content={"detail": "; ".join(messages) or "Invalid request.", "errors": jsonable(exc)},
    )


def jsonable(exc: RequestValidationError):
    return [{"loc": list(e["loc"]), "msg": e["msg"], "type": e["type"]} for e in exc.errors()]


@app.exception_handler(Exception)
async def unexpected_error_handler(request: Request, exc: Exception):
    # Log the details server-side; never leak internals (SQL, paths) to clients.
    log.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(status_code=500, content={"detail": "Something went wrong on the server."})


@app.get("/", tags=["Health"])
def home():
    return {"message": "Climate and Crop Productivity API is running", "docs": "/docs"}


@app.get("/health", tags=["Health"])
def health():
    try:
        check_connection()
    except Exception:
        log.exception("Database health check failed")
        return JSONResponse(status_code=503, content={"status": "error", "database": "unreachable"})
    return {"status": "ok", "database": "connected"}
