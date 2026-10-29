"""Rule-based planting advice. Pure functions: easy to test and to tune.

The thresholds are preliminary and should be validated with local
agricultural guidance (e.g. PhilRice / the municipal agriculture office).
"""
from dataclasses import dataclass

SUITABLE = "SUITABLE"
CAUTION = "CAUTION"
NOT_SUITABLE = "NOT SUITABLE"


@dataclass(frozen=True)
class Thresholds:
    rain_mm_not_suitable: float = 50   # forecast rainfall over ~24h
    rain_mm_caution: float = 20
    pop_not_suitable: float = 80       # max rain probability, %
    pop_caution: float = 50
    temp_not_suitable: float = 38      # average, deg C
    temp_caution: float = 35


DEFAULT_THRESHOLDS = Thresholds()


def assess_planting(
    avg_temperature: float,
    rainfall_mm: float,
    rain_probability: float,
    has_thunderstorm: bool = False,
    t: Thresholds = DEFAULT_THRESHOLDS,
) -> tuple[str, str]:
    if rainfall_mm >= t.rain_mm_not_suitable or rain_probability >= t.pop_not_suitable:
        return NOT_SUITABLE, (
            "High forecast rainfall or rain probability. Check field drainage and "
            "local conditions before planting rice."
        )
    if has_thunderstorm:
        return CAUTION, (
            "Thunderstorms are forecast. Monitor the weather and wait for safer "
            "conditions before field work."
        )
    if avg_temperature >= t.temp_not_suitable:
        return NOT_SUITABLE, (
            "Very high forecast temperature. Check water availability and local "
            "agricultural guidance."
        )
    if (
        rainfall_mm >= t.rain_mm_caution
        or rain_probability >= t.pop_caution
        or avg_temperature >= t.temp_caution
    ):
        return CAUTION, (
            "Rainfall or temperature may affect planting. Check soil moisture, "
            "field drainage, and the next forecast before deciding."
        )
    return SUITABLE, (
        "No major weather warning was detected by these rules. Confirm field "
        "water and soil conditions before planting rice."
    )


def evaluate_harvest(sold_sacks: int, price_per_sack: float, production_cost: float):
    """Return (total_sales, profit, status, message, message_en)."""
    sold_sacks = float(sold_sacks)
    price_per_sack = float(price_per_sack)
    production_cost = float(production_cost)
    
    total_sales = round(sold_sacks * price_per_sack, 2)
    profit = round(total_sales - production_cost, 2)
    
    if profit > 0:
        return total_sales, profit, "GOOD", "Naka-ginansya ang harvest.", "This harvest was profitable."
    if profit == 0:
        return (total_sales, profit, "BREAK EVEN",
                "Nabawi ang gasto, walay net profit.", "Costs were recovered; no net profit.")
    return total_sales, profit, "NOT GOOD", "Nalugi ang harvest.", "This harvest made a loss."
