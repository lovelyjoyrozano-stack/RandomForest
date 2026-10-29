"""OpenWeather client with a small TTL cache and one place that parses forecasts."""
import time
from collections import Counter
from dataclasses import dataclass, field
from threading import Lock


import httpx

from ..config import get_settings

FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"
PERIODS_24H = 8  # 3-hour steps -> 24 hours
CURRENT_URL = "https://api.openweathermap.org/data/2.5/weather"
def get_current_weather(city: str) -> dict:
    """Fetch current weather conditions from OpenWeather."""
    settings = get_settings()

    if not settings.openweather_api_key:
        raise WeatherError(
            "Weather service is not configured (missing OPENWEATHER_API_KEY).",
            503,
        )

    key = (city.strip().lower(), settings.default_country)
    now = time.monotonic()

    # Separate cache for current weather.
    with _cache_lock:
        cache_key = ("current:" + key[0], key[1])
        hit = _cache.get(cache_key)

        # Current conditions are cached for at most 60 seconds.
        if hit and now - hit[0] < 60:
            return hit[1]

    try:
        response = httpx.get(
            CURRENT_URL,
            params={
                "q": f"{city},{settings.default_country}",
                "appid": settings.openweather_api_key,
                "units": "metric",
            },
            timeout=15,
        )
    except httpx.HTTPError:
        raise WeatherError("Could not connect to the weather service.")

    if response.status_code == 404:
        raise WeatherError(f"City '{city}' was not found.", 404)

    if response.status_code != 200:
        raise WeatherError(
            "The weather service returned an error. Try again shortly."
        )

    data = response.json()
    main = data.get("main") or {}
    weather_data = (data.get("weather") or [{}])[0]
    wind = data.get("wind") or {}

    result = {
        "city": (data.get("name") or city),
        "weather_main": weather_data.get("main", "Unknown"),
        "weather_condition": weather_data.get("description", "Unknown"),
        "temperature_celsius": main.get("temp"),
        "feels_like_celsius": main.get("feels_like"),
        "humidity_percent": main.get("humidity"),
        "wind_speed_ms": wind.get("speed"),
        "observed_at": data.get("dt"),
        "source": "OpenWeather current weather",
    }

    with _cache_lock:
        _cache[cache_key] = (now, result)

    return result


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


def fetch_forecast(city: str) -> dict:
    """Return the raw OpenWeather payload for `city` (cached for a few minutes,
    which also keeps us well inside the free-tier request quota)."""
    settings = get_settings()
    if not settings.openweather_api_key:
        raise WeatherError("Weather service is not configured (missing OPENWEATHER_API_KEY).", 503)

    key = (city.strip().lower(), settings.default_country)
    now = time.monotonic()
    with _cache_lock:
        hit = _cache.get(key)
        if hit and now - hit[0] < settings.weather_cache_seconds:
            return hit[1]

    try:
        response = httpx.get(
            FORECAST_URL,
            params={
                "q": f"{city},{settings.default_country}",
                "appid": settings.openweather_api_key,
                "units": "metric",
            },
            timeout=15,
        )
    except httpx.HTTPError:
        raise WeatherError("Could not connect to the weather service.")

    if response.status_code == 404:
        raise WeatherError(f"City '{city}' was not found.", 404)
    if response.status_code != 200:
        raise WeatherError("The weather service returned an error. Try again shortly.")

    data = response.json()
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


def get_summary(city: str) -> ForecastSummary:
    return summarize(fetch_forecast(city), city)
