import json
import math

def haversine_m(lat1, lng1, lat2, lng2):
    R = 6371000
    p = math.pi / 180
    a = (math.sin((lat2 - lat1) * p / 2) ** 2 +
         math.cos(lat1 * p) * math.cos(lat2 * p) *
         math.sin((lng2 - lng1) * p / 2) ** 2)
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))

with open('bulan_roads.geojson', 'r', encoding='utf-8') as f:
    data = json.load(f)

segments = []
for feature in data.get('features', []):
    coords = feature.get('geometry', {}).get('coordinates', [])
    for i in range(len(coords) - 1):
        lng1, lat1 = coords[i]
        lng2, lat2 = coords[i + 1]
        dist = haversine_m(lat1, lng1, lat2, lng2)
        if dist < 5:        # skip duplicate points
            continue
        if dist > 2000:     # skip unrealistically long segments
            continue
        segments.append({
            "start_lat": round(lat1, 7),
            "start_lng": round(lng1, 7),
            "end_lat":   round(lat2, 7),
            "end_lng":   round(lng2, 7),
            "base_distance": round(dist, 1)
        })

output = {
    "_comment": "Real Bulan, Sorsogon road network from OpenStreetMap.",
    "segments": segments
}

with open('mock_data/mock_road_network.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2)

print(f"Done. {len(segments)} segments written to mock_data/mock_road_network.json")