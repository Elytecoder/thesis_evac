"""
Train Naive Bayes classifier for hazard report validation.

# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available

Features:
    Text input = hazard_type + ' ' + description (combined)
    Vectorized with CountVectorizer (bag-of-words)
    Trained with MultinomialNB

Output:
    models/naive_bayes_model.pkl
    models/vectorizer.pkl
    naive_bayes_dataset.csv   (generated if not exists)

Run:
    python ml_data/train_naive_bayes.py
    OR: python manage.py train_ml_models
"""
import csv
import os
import pickle
import sys
from pathlib import Path

ML_DATA_DIR = Path(__file__).parent
MODELS_DIR = ML_DATA_DIR / 'models'
CSV_PATH = ML_DATA_DIR / 'naive_bayes_dataset.csv'

# ─── Synthetic Dataset ───────────────────────────────────────────────────────
# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available
#
# Format: (hazard_type, description, is_valid)
# is_valid=1 → MDRRMO approved (credible report)
# is_valid=0 → MDRRMO rejected (spam, vague, false, or off-topic)

VALID_EXAMPLES = [
    # ── flooded_road ──
    ('flooded_road', 'Road flooded knee deep, vehicles cannot pass', 1),
    ('flooded_road', 'Baha na daan halos hanggang tuhod ang tubig', 1),
    ('flooded_road', 'Severe flooding on main road, water level still rising', 1),
    ('flooded_road', 'Flooded road near bridge, impassable for small vehicles', 1),
    ('flooded_road', 'Flash flood hit road after heavy rain, very dangerous', 1),
    ('flooded_road', 'Water level approximately 60cm on road, do not cross', 1),
    ('flooded_road', 'Road submerged, cannot see the pavement anymore', 1),
    ('flooded_road', 'Bumabaha na agad ang daan matapos ang malakas na ulan', 1),
    ('flooded_road', 'Flooding with strong current on the road, avoid area', 1),
    ('flooded_road', 'Road underwater estimated 80cm deep near evacuation center', 1),
    ('flooded_road', 'Flooded road causing vehicles to stall, dangerous area', 1),
    ('flooded_road', 'Storm caused severe flooding on road, waist deep in parts', 1),
    ('flooded_road', 'Malakas na ulan nagdulot ng baha sa buong kalsada', 1),

    # ── landslide ──
    ('landslide', 'Landslide blocking the road, boulders and soil everywhere', 1),
    ('landslide', 'Gumuho ang lupa sa bundok naharang ang kalsada', 1),
    ('landslide', 'Fresh landslide covering road completely, cannot pass', 1),
    ('landslide', 'Large rocks and mud from landslide blocking entire road', 1),
    ('landslide', 'Landslide from mountainside road is completely impassable', 1),
    ('landslide', 'Half of road covered by landslide debris, very dangerous', 1),
    ('landslide', 'Mudslide blocking passage, area still unstable and shifting', 1),
    ('landslide', 'Gumuho ang gilid ng bundok malaking bato at lupa sa daan', 1),
    ('landslide', 'Landslide with large boulders road blocked cannot pass', 1),
    ('landslide', 'Collapsed hillside covering road, rescue team needed', 1),
    ('landslide', 'Fresh mudslide from heavy rain blocked road completely', 1),
    ('landslide', 'Landslide 3 meters deep covering road completely', 1),

    # ── fallen_tree ──
    ('fallen_tree', 'Large tree fell across road blocking both lanes of traffic', 1),
    ('fallen_tree', 'Puno natumba sa gitna ng daan hindi malusot ang sasakyan', 1),
    ('fallen_tree', 'Big tree fell due to strong winds blocking the entire road', 1),
    ('fallen_tree', 'Multiple trees down on road after typhoon, road closed', 1),
    ('fallen_tree', 'Fallen tree covering full width of road, cannot pass at all', 1),
    ('fallen_tree', 'Tree fell on road chainsaw needed to clear the blockage', 1),
    ('fallen_tree', 'Strong wind knocked large tree across road blocking traffic', 1),
    ('fallen_tree', 'Malaking puno natumba naharang ang daan pati sidewalk', 1),
    ('fallen_tree', 'Tree fallen with large roots blocking road completely', 1),
    ('fallen_tree', 'Several trees fell blocking road after strong typhoon hit', 1),
    ('fallen_tree', 'Large fallen tree on road, traffic cannot pass both ways', 1),

    # ── road_damage ──
    ('road_damage', 'Large pothole causing serious damage to passing vehicles', 1),
    ('road_damage', 'Road surface badly cracked and dangerous for all vehicles', 1),
    ('road_damage', 'Sira ang kalsada may malaking butas sa gitna ng daan', 1),
    ('road_damage', 'Road collapsed partially on the side, very dangerous', 1),
    ('road_damage', 'Severe road damage from flooding, deep cracks appeared', 1),
    ('road_damage', 'Multiple large potholes making road very dangerous to use', 1),
    ('road_damage', 'Road foundation damaged, surface is sinking into ground', 1),
    ('road_damage', 'Matinding sira ang daan hindi ligtas ang dumaan dito', 1),
    ('road_damage', 'Road crumbling at edges, risk of vehicle falling off', 1),
    ('road_damage', 'Heavy damage on road surface needs immediate repair now', 1),
    ('road_damage', 'Cracks on road getting wider, dangerous for all vehicles', 1),

    # ── fallen_electric_post ──
    ('fallen_electric_post', 'Electric post fallen on road with live wires on pavement', 1),
    ('fallen_electric_post', 'Poste ng kuryente natumba may live wire na mapanganib', 1),
    ('fallen_electric_post', 'Fallen power pole blocking road, live wires danger', 1),
    ('fallen_electric_post', 'Electric post down after typhoon, electrocution risk', 1),
    ('fallen_electric_post', 'Power post fell across road cannot pass safely at all', 1),
    ('fallen_electric_post', 'Live wires on road surface very dangerous do not approach', 1),
    ('fallen_electric_post', 'Fallen electricity pole with transformer landed on road', 1),
    ('fallen_electric_post', 'Nahulog ang poste may live wire sparks visible on ground', 1),
    ('fallen_electric_post', 'Electric post with wires down sparks visible from afar', 1),
    ('fallen_electric_post', 'Fallen power line on road, electrocution risk high', 1),
    ('fallen_electric_post', 'Electric pole fell, wires blocking entire road entrance', 1),

    # ── road_blocked ──
    ('road_blocked', 'Road completely blocked by flood debris and large boulders', 1),
    ('road_blocked', 'Daan naharang ng malaking bato mula sa bundok sa tabi', 1),
    ('road_blocked', 'Road blocked by fallen trees and flood debris, impassable', 1),
    ('road_blocked', 'Large boulders from rockslide blocking the main road', 1),
    ('road_blocked', 'Road closed, all vehicles stopped unable to proceed', 1),
    ('road_blocked', 'Debris and mud blocking road completely from landslide', 1),
    ('road_blocked', 'Harang ang daan hindi makalusot kahit motorsiklo', 1),
    ('road_blocked', 'Multiple blockages on road, completely impassable now', 1),
    ('road_blocked', 'Road blocked by collapsed concrete wall from flooding', 1),
    ('road_blocked', 'Road closed by local authorities due to extreme hazard', 1),
    ('road_blocked', 'Road blocked by construction debris and fallen materials', 1),

    # ── bridge_damage ──
    ('bridge_damage', 'Bridge cracked and not safe for any heavy vehicles', 1),
    ('bridge_damage', 'Tulay sira at mapanganib ang pagtawid ng anumang sasakyan', 1),
    ('bridge_damage', 'Bridge surface cracking, needs immediate closure now', 1),
    ('bridge_damage', 'Bridge with visible structural damage after the flood', 1),
    ('bridge_damage', 'Bridge shaking dangerously when any vehicle passes over', 1),
    ('bridge_damage', 'Bridge railing completely damaged, risk of falling into river', 1),
    ('bridge_damage', 'One lane of bridge collapsed, avoid crossing at all cost', 1),
    ('bridge_damage', 'Bridge foundation damaged by strong water current', 1),
    ('bridge_damage', 'Cracks on bridge surface getting wider, do not cross', 1),
    ('bridge_damage', 'Bridge damaged by large debris from flood water', 1),
    ('bridge_damage', 'Bridge cannot support heavy trucks or buses anymore', 1),

    # ── storm_surge ──
    ('storm_surge', 'Strong storm surge pushing seawater onto coastal road', 1),
    ('storm_surge', 'Storm surge flooding coastal road, dangerous large waves', 1),
    ('storm_surge', 'Malakas na alon sumalpak sa kalsada dahil sa bagyo', 1),
    ('storm_surge', 'Coastal road flooded by storm surge, evacuate immediately', 1),
    ('storm_surge', 'Storm surge reaching 2 meters height, road is submerged', 1),
    ('storm_surge', 'Strong waves from typhoon hitting and flooding coastal road', 1),
    ('storm_surge', 'Storm surge advancing rapidly, road very dangerous to cross', 1),
    ('storm_surge', 'Coastal area flooded by strong storm surge from typhoon', 1),
    ('storm_surge', 'High storm surge blocking coastal road, do not enter', 1),
    ('storm_surge', 'Storm surge with strong current flooding the entire road', 1),

    # ── other ──
    ('other', 'Unknown debris blocking the road, cannot identify source', 1),
    ('other', 'Possible hazard on road, needs verification and inspection', 1),
    ('other', 'Road condition appears extremely dangerous, needs inspection', 1),
    ('other', 'Debris of unknown origin blocking entire road passage', 1),
    ('other', 'Unusual obstruction on road, type unclear, needs checking', 1),
    ('other', 'Something blocking road passage, not sure what it is', 1),
    ('other', 'Road hazard detected, cannot determine the exact cause', 1),
    ('other', 'Obstruction on road, may be very dangerous to pass through', 1),
    ('other', 'May nakaharang sa daan hindi malinaw kung ano ito', 1),
    ('other', 'Road is not passable, reason unclear, needs inspection', 1),
    ('other', 'Hazardous road condition, cause cannot be identified', 1),
]

INVALID_EXAMPLES = [
    # ── Nonsense / keyboard spam ──
    ('flooded_road', 'test', 0),
    ('landslide', 'asdf', 0),
    ('road_blocked', 'hi', 0),
    ('fallen_tree', 'ok', 0),
    ('road_damage', 'wala', 0),
    ('flooded_road', '123', 0),
    ('landslide', 'aaa', 0),
    ('fallen_electric_post', 'xxx', 0),
    ('bridge_damage', 'no', 0),
    ('storm_surge', 'yes', 0),
    ('other', 'hmm', 0),
    ('flooded_road', '.', 0),
    ('road_blocked', '???', 0),
    ('landslide', 'abc', 0),
    ('fallen_tree', 'asdfghjkl', 0),
    ('road_damage', 'qwerty', 0),
    ('flooded_road', 'zxcv', 0),
    ('other', '1234', 0),
    ('bridge_damage', 'test123', 0),
    ('storm_surge', 'hello', 0),
    ('fallen_electric_post', 'flood', 0),
    ('road_blocked', 'tree', 0),
    ('road_damage', 'road', 0),
    ('landslide', 'x', 0),
    ('other', 'a', 0),

    # ── Vague / meaningless phrases ──
    ('flooded_road', 'wala lang', 0),
    ('landslide', 'basta lang', 0),
    ('road_damage', 'hindi ko alam', 0),
    ('fallen_tree', 'test lang to', 0),
    ('road_blocked', 'checking', 0),
    ('bridge_damage', 'sige na lang', 0),
    ('storm_surge', 'baka siguro', 0),
    ('fallen_electric_post', 'hindi ko sure', 0),
    ('other', 'ganyan lang', 0),
    ('flooded_road', 'paki check', 0),
    ('landslide', 'may bagay', 0),
    ('road_damage', 'may nakita', 0),
    ('fallen_tree', 'tingnan ninyo', 0),
    ('road_blocked', 'blah blah', 0),
    ('bridge_damage', 'lorem ipsum', 0),
    ('storm_surge', 'idk', 0),
    ('fallen_electric_post', 'lol', 0),
    ('other', 'haha', 0),
    ('flooded_road', 'ok lang', 0),
    ('landslide', 'basta', 0),
    ('road_damage', 'siguro', 0),
    ('fallen_tree', 'ano ba', 0),
    ('road_blocked', 'ewan', 0),
    ('bridge_damage', 'di ko alam', 0),
    ('storm_surge', 'meh', 0),

    # ── Contradictory / false reports ──
    ('flooded_road', 'clear road no problem here at all', 0),
    ('landslide', 'road is perfectly fine no issues detected', 0),
    ('road_damage', 'nice smooth road everything is okay', 0),
    ('fallen_tree', 'no trees blocking road here at all', 0),
    ('road_blocked', 'road is completely open and clear to pass', 0),
    ('bridge_damage', 'bridge is perfectly fine and safe to cross', 0),
    ('storm_surge', 'calm sea no problem today', 0),
    ('fallen_electric_post', 'all posts standing no wires down', 0),
    ('other', 'everything is normal no hazard here', 0),
    ('flooded_road', 'no flooding in this area at all', 0),
    ('landslide', 'hill is very stable no movement at all', 0),
    ('road_damage', 'road surface is good and perfectly smooth', 0),
    ('fallen_tree', 'all trees intact no fallen branches anywhere', 0),
    ('road_blocked', 'road is open and fully passable for all', 0),
    ('bridge_damage', 'bridge is safe and structurally sound today', 0),
    ('storm_surge', 'no waves sea is very calm today', 0),
    ('fallen_electric_post', 'all power lines intact and working fine', 0),
    ('other', 'no hazard nothing to report here', 0),
    ('flooded_road', 'walang baha maayos ang daan', 0),
    ('landslide', 'walang guho tahimik ang bundok', 0),
    ('road_damage', 'walang sira maayos ang kalsada', 0),
    ('fallen_tree', 'walang natumba na puno dito', 0),
    ('road_blocked', 'bukas ang daan walang harang', 0),
    ('bridge_damage', 'ok ang tulay ligtas dumaan', 0),
    ('storm_surge', 'maayos ang dagat walang alon', 0),

    # ── Spam / word repetition ──
    ('flooded_road', 'flood flood flood flood flood', 0),
    ('landslide', 'landslide landslide landslide landslide', 0),
    ('fallen_tree', 'tree tree tree tree tree fallen', 0),
    ('road_damage', 'damage damage damage damage road', 0),
    ('road_blocked', 'block block block block road', 0),
    ('bridge_damage', 'bridge bridge bridge bridge bridge', 0),
    ('storm_surge', 'surge surge surge surge storm', 0),
    ('fallen_electric_post', 'electric electric electric electric', 0),
    ('other', 'hazard hazard hazard hazard hazard', 0),
    ('flooded_road', 'baha baha baha baha baha baha', 0),
    ('landslide', 'guho guho guho guho guho guho', 0),
    ('road_damage', 'sira sira sira sira sira sira', 0),
    ('fallen_tree', 'puno puno puno puno puno puno', 0),
    ('road_blocked', 'harang harang harang harang harang', 0),
    ('other', 'test test test test test test', 0),

    # ── Off-topic / unrelated ──
    ('flooded_road', 'weather is nice today no problem', 0),
    ('landslide', 'good morning everyone have a nice day', 0),
    ('road_damage', 'have a nice day everyone stay safe', 0),
    ('fallen_tree', 'hello po kayo kumain na kayo', 0),
    ('road_blocked', 'kumain na kayo ingat sa labas', 0),
    ('bridge_damage', 'take care everyone today stay healthy', 0),
    ('storm_surge', 'magbihis na kayo umaga na po', 0),
    ('fallen_electric_post', 'happy birthday to you today', 0),
    ('other', 'nothing to report here everything fine', 0),
    ('flooded_road', 'I am just testing this reporting application', 0),
]


def generate_csv(path: Path = CSV_PATH) -> None:
    """Write synthetic dataset to CSV file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    all_rows = VALID_EXAMPLES + INVALID_EXAMPLES
    with open(path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['hazard_type', 'description', 'is_valid'])
        writer.writerows(all_rows)
    print(f'[NB] Dataset saved: {path} ({len(all_rows)} rows, '
          f'{len(VALID_EXAMPLES)} valid, {len(INVALID_EXAMPLES)} invalid)')


def train_and_save(csv_path: Path = CSV_PATH) -> None:
    """
    Generate CSV (if missing), train MultinomialNB + CountVectorizer, save pkl files.

    # Using synthetic training data (temporary)
    # Replace with MDRRMO historical data when available
    """
    try:
        from sklearn.naive_bayes import MultinomialNB
        from sklearn.feature_extraction.text import CountVectorizer
        import numpy as np
    except ImportError:
        print('[NB] scikit-learn not installed — skipping training.')
        return

    if not csv_path.exists():
        generate_csv(csv_path)

    # Load CSV
    texts, labels = [], []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Combine hazard_type + description as the text input
            text = f"{row['hazard_type']} {row['description']}"
            texts.append(text)
            labels.append(int(row['is_valid']))

    print(f'[NB] Training on {len(texts)} examples '
          f'({sum(labels)} valid, {len(labels)-sum(labels)} invalid) ...')

    vectorizer = CountVectorizer(ngram_range=(1, 2), min_df=1)
    X = vectorizer.fit_transform(texts)
    y = np.array(labels)

    model = MultinomialNB(alpha=0.5)  # Laplace smoothing
    model.fit(X, y)

    train_acc = model.score(X, y)
    print(f'[NB] Training accuracy: {train_acc:.3f}')

    # Save models
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    nb_path = MODELS_DIR / 'naive_bayes_model.pkl'
    vec_path = MODELS_DIR / 'vectorizer.pkl'
    with open(nb_path, 'wb') as f:
        pickle.dump(model, f)
    with open(vec_path, 'wb') as f:
        pickle.dump(vectorizer, f)
    print(f'[NB] Models saved: {nb_path.name}, {vec_path.name}')


if __name__ == '__main__':
    train_and_save()
