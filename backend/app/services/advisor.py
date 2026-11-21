
"""Rule-based planting advice. Pure functions: easy to test and to tune.

The thresholds are preliminary and should be validated with local
agricultural guidance (e.g. PhilRice / the municipal agriculture office).
"""
from dataclasses import dataclass

SUITABLE = "SUITABLE FOR PLANTING"
CAUTION = "PLANT WITH CAUTION"
NOT_SUITABLE = "NOT SUITABLE FOR PLANTING"


@dataclass(frozen=True)
class Thresholds:
    rain_mm_not_suitable: float = 50
    rain_mm_caution: float = 20
    pop_not_suitable: float = 80
    pop_caution: float = 50
    temp_not_suitable: float = 38
    temp_caution: float = 35


DEFAULT_THRESHOLDS = Thresholds()



def assess_planting(
    current_temperature: float,
    forecast_temperature: float,
    current_rainfall: float,
    forecast_rainfall: float,
    rain_probability: float,
    has_thunderstorm: bool = False,
    t: Thresholds = DEFAULT_THRESHOLDS,
) -> tuple[str, str]:

    warnings = []

    # Check current and forecast temperature
    highest_temperature = max(
        current_temperature,
        forecast_temperature,
    )

    # Check current and forecast rainfall
    total_rainfall_indicator = (
        current_rainfall + forecast_rainfall
    )

    # Extreme rainfall
    if total_rainfall_indicator >= t.rain_mm_not_suitable:
        return NOT_SUITABLE, (
            "Current and upcoming rainfall indicate unfavorable "
            "conditions. Consider postponing planting and monitor "
            "field drainage."
        )

    # Thunderstorm detection
    if has_thunderstorm:
        return CAUTION, (
            "Thunderstorms are detected in the current weather or "
            "forecast. Monitor weather conditions and avoid field "
            "activities during thunderstorms."
        )

    # Extreme temperature
    if highest_temperature >= t.temp_not_suitable:
        return NOT_SUITABLE, (
            "Current or forecast temperature is extremely high. "
            "Consider postponing planting until conditions improve."
        )

    # Moderate rainfall
    if total_rainfall_indicator >= t.rain_mm_caution:
        warnings.append(
            "Current and forecast rainfall may affect soil moisture "
            "and field conditions."
        )

    # High probability of rain
    if rain_probability >= t.pop_caution:
        warnings.append(
            "There is a considerable chance of rain within the next 24 hours."
        )

    # High temperature
    if highest_temperature >= t.temp_caution:
        warnings.append(
            "Current or forecast temperature is high and may affect "
            "seed establishment."
        )

    if warnings:
        return CAUTION, " ".join(warnings) + (
            " Monitor weather and soil conditions before planting."
        )

    return SUITABLE, (
        "Current weather and the next 24-hour forecast are favorable "
        "for planting. No major weather-related risks were detected. "
        "Check soil conditions and crop-specific requirements."
    )


def evaluate_harvest(
    sold_sacks: int,
    price_per_sack: float,
    production_cost: float
):
    """Return (total_sales, profit, status, message, message_en)."""
    sold_sacks = float(sold_sacks)
    price_per_sack = float(price_per_sack)
    production_cost = float(production_cost)

    total_sales = round(sold_sacks * price_per_sack, 2)
    profit = round(total_sales - production_cost, 2)

    if profit > 0:
        return (
            total_sales,
            profit,
            "GOOD",
            "Naka-ginansya ang harvest.",
            "This harvest was profitable."
        )

    if profit == 0:
        return (
            total_sales,
            profit,
            "BREAK EVEN",
            "Nabawi ang gasto, walay net profit.",
            "Costs were recovered; no net profit."
        )

    return (
        total_sales,
        profit,
        "NOT GOOD",
        "Nalugi ang harvest.",
        "This harvest made a loss."
    )
