import pandas as pd
import numpy as np

# Define the weapon data
weapon_data = [
    # MA7 Weapon Data
    {"weapon": "MA7", "charge": 0, "min_range": 250, "max_range": 750, "min_mil": 1427, "max_mil": 800, "min_flight_time": 18.3, "max_flight_time": 13.1},
    {"weapon": "MA7", "charge": 1, "min_range": 500, "max_range": 1550, "min_mil": 1437, "max_mil": 800, "min_flight_time": 25.3, "max_flight_time": 18.2},
    {"weapon": "MA7", "charge": 2, "min_range": 800, "max_range": 2150, "min_mil": 1408, "max_mil": 952, "min_flight_time": 25.9, "max_flight_time": 18.6},
    {"weapon": "MA7", "charge": 3, "min_range": 1000, "max_range": 2900, "min_mil": 1421, "max_mil": 800, "min_flight_time": 40.2, "max_flight_time": 28.8},
    {"weapon": "MA7", "charge": 4, "min_range": 1300, "max_range": 3480, "min_mil": 1405, "max_mil": 800, "min_flight_time": 46.1, "max_flight_time": 33.1},
    {"weapon": "MA7", "charge": 5, "min_range": 1600, "max_range": 4050, "min_mil": 1394, "max_mil": 800, "min_flight_time": 51.5, "max_flight_time": 37.2},
    {"weapon": "MA7", "charge": 6, "min_range": 1800, "max_range": 4600, "min_mil": 1395, "max_mil": 800, "min_flight_time": 57, "max_flight_time": 41},

    # MA8 Weapon Data
    {"weapon": "MA8", "charge": 0, "min_range": 200, "max_range": 550, "min_mil": 1410, "max_mil": 800, "min_flight_time": 14, "max_flight_time": 10},
    {"weapon": "MA8", "charge": 1, "min_range": 400, "max_range": 1125, "min_mil": 1414, "max_mil": 800, "min_flight_time": 21, "max_flight_time": 15.1},
    {"weapon": "MA8", "charge": 2, "min_range": 600, "max_range": 1650, "min_mil": 1410, "max_mil": 800, "min_flight_time": 27.2, "max_flight_time": 17.6},
    {"weapon": "MA8", "charge": 3, "min_range": 900, "max_range": 2700, "min_mil": 1427, "max_mil": 800, "min_flight_time": 36.4, "max_flight_time": 26.1},
    {"weapon": "MA8", "charge": 4, "min_range": 1300, "max_range": 3550, "min_mil": 1409, "max_mil": 800, "min_flight_time": 44.2, "max_flight_time": 45},
    {"weapon": "MA8", "charge": 5, "min_range": 1600, "max_range": 4400, "min_mil": 1412, "max_mil": 868, "min_flight_time": 51.1, "max_flight_time": 39.1},
    {"weapon": "MA8", "charge": 6, "min_range": 2100, "max_range": 5150, "min_mil": 1387, "max_mil": 800, "min_flight_time": 57.8, "max_flight_time": 41.8},
    {"weapon": "MA8", "charge": 7, "min_range": 2400, "max_range": 5800, "min_mil": 1382, "max_mil": 800, "min_flight_time": 62.9, "max_flight_time": 45.5},
    {"weapon": "MA8", "charge": 8, "min_range": 2400, "max_range": 6350, "min_mil": 1402, "max_mil": 800, "min_flight_time": 68.6, "max_flight_time": 49.4}
]

# Calculate interpolated values for every 50 meters
rows = []
for data in weapon_data:
    ranges = np.arange(data["min_range"], data["max_range"] + 50, 50)
    mils = np.interp(ranges, [data["min_range"], data["max_range"]], [data["min_mil"], data["max_mil"]])
    flight_times = np.interp(ranges, [data["min_range"], data["max_range"]], [data["min_flight_time"], data["max_flight_time"]])
    for r, m, t in zip(ranges, mils, flight_times):
        rows.append({
            "Weapon": data["weapon"],
            "Charge": data["charge"],
            "Range (m)": r,
            "Mil": round(m, 2),
            "Flight Time (s)": round(t, 2)
        })

# Create a DataFrame and save as CSV
df = pd.DataFrame(rows)
file_path = "/mnt/data/weapon_details_interpolated.csv"
df.to_csv(file_path, index=False)
file_path
