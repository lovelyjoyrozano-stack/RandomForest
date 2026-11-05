"""OpenWeather client with a small TTL cache and one place that parses forecasts."""
import time
from dataclasses import dataclass, field
from threading import Lock

import httpx

from ..config import get_settings

FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"
CURRENT_URL = "https://api.openweathermap.org/data/2.5/weather"
PERIODS_24H = 8  # 3-hour steps -> 24 hours

# Keep everything near-realtime. 60s is still well inside the free-tier quota
# (the app refreshes once a minute per user).
CURRENT_CACHE_SECONDS = 60
FORECAST_CACHE_SECONDS = 60


class WeatherError(Exception):
    def __init__(self, detail: str, status_code: int = 502):
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


@dataclass
class ForecastSummary:
    city: str
    periods: list[dict]
    avg_temperature: float
    avg_humidity: float
    total_rainfall: float
    max_rain_probability: float
    weather_condition: str
    main_conditions: list[str] = field(default_factory=list)
    conditions_24h: list[str] = field(default_factory=list)


_cache: dict[tuple[str, str], tuple[float, dict]] = {}
_cache_lock = Lock()


def clear_cache() -> None:
    with _cache_lock:
        _cache.clear()


def _request(
    url: str,
    city: str,
    settings,
    latitude: float | None = None,
    longitude: float | None = None,
) -> dict:
    params = {
        "appid": settings.openweather_api_key,
        "units": "metric",
    }

    if latitude is not None and longitude is not None:
        params["lat"] = latitude
        params["lon"] = longitude
    else:
        params["q"] = f"{city},{settings.default_country}"

    try:
        response = httpx.get(
            url,
            params=params,
            timeout=15,
        )
        response.raise_for_status()

    except httpx.HTTPStatusError as exc:
        if exc.response.status_code == 404:
            raise WeatherError(
                f"City '{city}' was not found.", 404
            )
        raise WeatherError(
            "The weather service returned an error. Try again shortly."
        )

    except httpx.HTTPError:
        raise WeatherError(
            "Could not connect to the weather service."
        )

    return response.json()
   
def get_current_weather(
    city: str,
    latitude: float | None = None,
    longitude: float | None = None,
) -> dict:
    """Fetch current weather conditions from OpenWeather (cached 60s)."""
    settings = get_settings()
    if not settings.openweather_api_key:
        raise WeatherError(
            "Weather service is not configured (missing OPENWEATHER_API_KEY).",
            503,
        )

    if latitude is not None and longitude is not None:
        location_key = f"{latitude:.5f},{longitude:.5f}"
    else:
        location_key = city.strip().lower()

    now = time.monotonic()
    cache_key = ("current:" + location_key, settings.default_country)

    with _cache_lock:
        hit = _cache.get(cache_key)
        if hit and now - hit[0] < CURRENT_CACHE_SECONDS:
            return hit[1]

    data = _request(
        CURRENT_URL,
        city,
        settings,
        latitude,
        longitude,
    )
    print("WEATHER DEBUG")
    print("Requested city:", city)
    print("Latitude:", latitude)
    print("Longitude:", longitude)
    print("API city:", data.get("name"))
    print("API coordinates:", data.get("coord"))
    print("API weather:", data.get("weather"))
    print("API temperature:", (data.get("main") or {}).get("temp"))
    print("API rainfall:", data.get("rain"))
    print("API observation time:", data.get("dt"))
    
    
    main = data.get("main") or {}
    weather_data = (data.get("weather") or [{}])[0]
    wind = data.get("wind") or {}

    result = {
        "city": data.get("name") or city,
        "weather_main": weather_data.get("main", "Unknown"),
        "weather_condition": weather_data.get("description", "Unknown"),
        "temperature_celsius": main.get("temp"),
        "feels_like_celsius": main.get("feels_like"),
        "humidity_percent": main.get("humidity"),
        "wind_speed_ms": wind.get("speed"),
        "rainfall_mm": float((data.get("rain") or {}).get("1h", 0) or 0),
        "observed_at": data.get("dt"),
        "source": "OpenWeather current weather",
    }

    with _cache_lock:
        _cache[cache_key] = (now, result)

    return result

def fetch_forecast(
    city: str,
    latitude: float | None = None,
    longitude: float | None = None,
) -> dict:
    """Return the raw OpenWeather forecast payload (cached 60s)."""
    settings = get_settings()
    if not settings.openweather_api_key:
        raise WeatherError(
            "Weather service is not configured (missing OPENWEATHER_API_KEY).",
            503,
        )

    if latitude is not None and longitude is not None:
        location_key = f"{latitude:.5f},{longitude:.5f}"
    else:
        location_key = city.strip().lower()

    key = ("forecast:" + location_key, settings.default_country)
    now = time.monotonic()

    ttl = min(settings.weather_cache_seconds, FORECAST_CACHE_SECONDS)

    with _cache_lock:
        hit = _cache.get(key)
        if hit and now - hit[0] < ttl:
            return hit[1]

    data = _request(
        FORECAST_URL,
        city,
        settings,
        latitude,
        longitude,
    )

    with _cache_lock:
        _cache[key] = (now, data)

    return data

def summarize(raw: dict, requested_city: str) -> ForecastSummary:
    items = (raw.get("list") or [])[:PERIODS_24H]
    if not items:
        raise WeatherError("No forecast data available.")

    periods, temps, hums, mains = [], [], [], []
    rainfall = 0.0
    max_pop = 0.0

    for item in items:
        main = item.get("main") or {}
        weather = (item.get("weather") or [{}])[0]
        rain_mm = float((item.get("rain") or {}).get("3h", 0) or 0)
        pop = float(item.get("pop", 0) or 0) * 100

        if "temp" in main:
            temps.append(float(main["temp"]))
        if "humidity" in main:
            hums.append(float(main["humidity"]))
        if weather.get("main"):
            mains.append(str(weather["main"]).lower())

        rainfall += rain_mm
        max_pop = max(max_pop, pop)
        periods.append({
            "date_time": item.get("dt_txt"),
            "weather_main": weather.get("main", "Unknown"),
            "temperature_celsius": main.get("temp"),
            "feels_like_celsius": main.get("feels_like"),
            "wind_speed_ms": (item.get("wind") or {}).get("speed"),
            "humidity_percent": main.get("humidity"),
            "rainfall_mm": rain_mm,
            "weather_condition": weather.get("description", "Unknown"),
            "rain_probability_percent": round(pop),
        })
    if not temps or not hums:
        raise WeatherError("Forecast is missing temperature or humidity.")

    return ForecastSummary(
        city=(raw.get("city") or {}).get("name", requested_city),
        periods=periods,
        avg_temperature=sum(temps) / len(temps),
        avg_humidity=sum(hums) / len(hums),
        total_rainfall=rainfall,
        max_rain_probability=max_pop,
        weather_condition=periods[0]["weather_condition"],
        main_conditions=mains,
        conditions_24h=list(dict.fromkeys(p["weather_condition"] for p in periods)),
    )


def get_summary(
    city: str,
    latitude: float | None = None,
    longitude: float | None = None,
) -> ForecastSummary:
    return summarize(
        fetch_forecast(city, latitude, longitude),
        city,
    )