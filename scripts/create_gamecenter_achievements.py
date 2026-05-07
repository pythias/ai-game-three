#!/usr/bin/env python3
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from PIL import Image, ImageDraw, ImageFont


API_BASE = "https://api.appstoreconnect.apple.com/v1"


@dataclass(frozen=True)
class Achievement:
    identifier: str
    reference_name: str
    title: str
    before: str
    after: str
    points: int
    badge: str
    color: str


ACHIEVEMENTS = [
    Achievement(
        "com.xiaodao.triyan.achievement.first_game",
        "TriYan First Game",
        "完成首局",
        "完成一局三衍。",
        "你完成了第一局三衍。",
        5,
        "1",
        "#3C7D6B",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.games_10",
        "TriYan Ten Games",
        "十局练习",
        "累计完成 10 局。",
        "你已经完成了 10 局三衍。",
        5,
        "10",
        "#33AACC",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.games_25",
        "TriYan 25 Games",
        "稳定练习",
        "累计完成 25 局。",
        "你已经完成了 25 局三衍。",
        10,
        "25",
        "#318CE7",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.games_50",
        "TriYan 50 Games",
        "五十局突破",
        "累计完成 50 局。",
        "你已经完成了 50 局三衍。",
        15,
        "50",
        "#7A67EE",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.games_100",
        "TriYan 100 Games",
        "百局达人",
        "累计完成 100 局。",
        "你已经完成了 100 局三衍。",
        20,
        "100",
        "#B64FC8",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_100",
        "TriYan Score 100",
        "百分上手",
        "单局分数达到 100。",
        "你打出了一局 100 分。",
        10,
        "100",
        "#F08B4B",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_500",
        "TriYan Score 500",
        "五百分突破",
        "单局分数达到 500。",
        "你打出了一局 500 分。",
        15,
        "500",
        "#DDAA22",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_1000",
        "TriYan Score 1000",
        "千分局",
        "单局分数达到 1000。",
        "你打出了一局 1000 分。",
        20,
        "1K",
        "#33AA88",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_2000",
        "TriYan Score 2000",
        "两千分",
        "单局分数达到 2000。",
        "你打出了一局 2000 分。",
        25,
        "2K",
        "#28A0B8",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_5000",
        "TriYan Score 5000",
        "五千分",
        "单局分数达到 5000。",
        "你打出了一局 5000 分。",
        30,
        "5K",
        "#2474D8",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_10000",
        "TriYan Score 10000",
        "万分挑战",
        "单局分数达到 10000。",
        "你打出了一局 10000 分。",
        40,
        "10K",
        "#6652CC",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_20000",
        "TriYan Score 20000",
        "两万分大师",
        "单局分数达到 20000。",
        "你打出了一局 20000 分。",
        50,
        "20K",
        "#A447C9",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.score_50000",
        "TriYan Score 50000",
        "五万分传说",
        "单局分数达到 50000。",
        "你打出了一局 50000 分。",
        75,
        "50K",
        "#D23C87",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_48",
        "TriYan Tile 48",
        "合成 48",
        "合成一张 48 牌。",
        "你合成了第一张 48 牌。",
        10,
        "48",
        "#BBBB33",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_96",
        "TriYan Tile 96",
        "合成 96",
        "合成一张 96 牌。",
        "你合成了第一张 96 牌。",
        15,
        "96",
        "#88CC44",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_192",
        "TriYan Tile 192",
        "合成 192",
        "合成一张 192 牌。",
        "你合成了第一张 192 牌。",
        20,
        "192",
        "#44BB66",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_384",
        "TriYan Tile 384",
        "合成 384",
        "合成一张 384 牌。",
        "你合成了第一张 384 牌。",
        25,
        "384",
        "#2FAE8E",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_768",
        "TriYan Tile 768",
        "合成 768",
        "合成一张 768 牌。",
        "你合成了第一张 768 牌。",
        30,
        "768",
        "#2E91C2",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_1536",
        "TriYan Tile 1536",
        "合成 1536",
        "合成一张 1536 牌。",
        "你合成了第一张 1536 牌。",
        40,
        "1536",
        "#3F6BD8",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_3072",
        "TriYan Tile 3072",
        "合成 3072",
        "合成一张 3072 牌。",
        "你合成了第一张 3072 牌。",
        50,
        "3072",
        "#664FC9",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_6144",
        "TriYan Tile 6144",
        "合成 6144",
        "合成一张 6144 牌。",
        "你合成了第一张 6144 牌。",
        60,
        "6144",
        "#9B45C0",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_12288",
        "TriYan Tile 12288",
        "合成 12288",
        "合成一张 12288 牌。",
        "你合成了第一张 12288 牌。",
        75,
        "12K",
        "#C04095",
    ),
    Achievement(
        "com.xiaodao.triyan.achievement.tile_24576",
        "TriYan Tile 24576",
        "合成 24576",
        "合成一张 24576 牌。",
        "你合成了第一张 24576 牌。",
        100,
        "24K",
        "#D8445C",
    ),
]


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def make_jwt(key_id: str, issuer_id: str, key_path: Path) -> str:
    private_key = serialization.load_pem_private_key(key_path.read_bytes(), password=None)
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer_id, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header, separators=(',', ':')).encode())}.{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    der_signature = private_key.sign(signing_input.encode("ascii"), ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der_signature)
    signature = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return f"{signing_input}.{b64url(signature)}"


class ASCClient:
    def __init__(self, token: str):
        self.token = token

    def request(self, method: str, path_or_url: str, body=None, headers=None, raw_body=None):
        url = path_or_url if path_or_url.startswith("http") else f"{API_BASE}{path_or_url}"
        request_headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }
        if headers:
            request_headers.update(headers)
        data = raw_body
        if body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method, headers=request_headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                raw = response.read()
                if not raw:
                    return {}
                return json.loads(raw.decode("utf-8"))
        except urllib.error.HTTPError as error:
            raw = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {url} failed: HTTP {error.code}\n{raw}") from error


def upload_part(method: str, url: str, headers: dict, data: bytes):
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            response.read()
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {url} failed: HTTP {error.code}\n{raw}") from error


def generate_icon(path: Path, achievement: Achievement):
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGB", (1024, 1024), "#FAF8EF")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((112, 112, 912, 912), radius=124, fill=achievement.color)
    draw.rounded_rectangle((164, 164, 860, 860), radius=96, outline="#FFFFFF", width=10)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 260)
        small_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 86)
    except OSError:
        font = ImageFont.load_default()
        small_font = ImageFont.load_default()

    text = achievement.badge
    bbox = draw.textbbox((0, 0), text, font=font)
    draw.text(((1024 - (bbox[2] - bbox[0])) / 2, 360 - (bbox[3] - bbox[1]) / 2), text, font=font, fill="#FFFFFF")

    subtitle = "TRIYAN"
    bbox = draw.textbbox((0, 0), subtitle, font=small_font)
    draw.text(((1024 - (bbox[2] - bbox[0])) / 2, 662), subtitle, font=small_font, fill="#FFFFFF")
    image.save(path, "PNG")


def app_by_bundle_id(client: ASCClient, bundle_id: str):
    query = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "fields[apps]": "bundleId,name,sku"})
    response = client.request("GET", f"/apps?{query}")
    data = response.get("data", [])
    if not data:
        raise RuntimeError(f"No app found for bundle id {bundle_id}")
    return data[0]


def game_center_detail(client: ASCClient, app_id: str):
    try:
        response = client.request("GET", f"/apps/{app_id}/gameCenterDetail")
        return response["data"]
    except RuntimeError as error:
        if "HTTP 404" not in str(error):
            raise

    body = {
        "data": {
            "type": "gameCenterDetails",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}}
            },
        }
    }
    return client.request("POST", "/gameCenterDetails", body)["data"]


def existing_achievement_ids(client: ASCClient, detail_id: str):
    response = client.request("GET", f"/gameCenterDetails/{detail_id}?include=gameCenterAchievements&limit[gameCenterAchievements]=50")
    result = {}
    for item in response.get("included", []):
        if item.get("type") == "gameCenterAchievements":
            attrs = item.get("attributes", {})
            result[attrs.get("vendorIdentifier")] = item["id"]
    return result


def existing_localization(client: ASCClient, achievement_id: str, locale: str):
    response = client.request("GET", f"/gameCenterAchievements/{achievement_id}/localizations")
    for item in response.get("data", []):
        if item.get("attributes", {}).get("locale") == locale:
            return item
    return None


def existing_image(client: ASCClient, localization_id: str):
    try:
        return client.request("GET", f"/gameCenterAchievementLocalizations/{localization_id}/gameCenterAchievementImage")["data"]
    except RuntimeError as error:
        if "HTTP 404" in str(error):
            return None
        raise


def create_achievement(client: ASCClient, detail_id: str, achievement: Achievement):
    body = {
        "data": {
            "type": "gameCenterAchievements",
            "attributes": {
                "referenceName": achievement.reference_name,
                "vendorIdentifier": achievement.identifier,
                "points": achievement.points,
                "showBeforeEarned": True,
                "repeatable": False,
            },
            "relationships": {
                "gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": detail_id}}
            },
        }
    }
    return client.request("POST", "/gameCenterAchievements", body)["data"]


def create_localization(client: ASCClient, achievement_id: str, achievement: Achievement):
    body = {
        "data": {
            "type": "gameCenterAchievementLocalizations",
            "attributes": {
                "locale": "zh-Hans",
                "name": achievement.title,
                "beforeEarnedDescription": achievement.before,
                "afterEarnedDescription": achievement.after,
            },
            "relationships": {
                "gameCenterAchievement": {"data": {"type": "gameCenterAchievements", "id": achievement_id}}
            },
        }
    }
    return client.request("POST", "/gameCenterAchievementLocalizations", body)["data"]


def upload_image(client: ASCClient, localization_id: str, image_path: Path):
    current = existing_image(client, localization_id)
    if current:
        state = current.get("attributes", {}).get("assetDeliveryState", {}).get("state")
        if state == "COMPLETE":
            return current
        client.request("DELETE", f"/gameCenterAchievementImages/{current['id']}")

    file_bytes = image_path.read_bytes()
    body = {
        "data": {
            "type": "gameCenterAchievementImages",
            "attributes": {
                "fileSize": len(file_bytes),
                "fileName": image_path.name,
            },
            "relationships": {
                "gameCenterAchievementLocalization": {
                    "data": {"type": "gameCenterAchievementLocalizations", "id": localization_id}
                }
            },
        }
    }
    image = client.request("POST", "/gameCenterAchievementImages", body)["data"]
    for operation in image["attributes"]["uploadOperations"]:
        offset = operation["offset"]
        length = operation["length"]
        headers = {header["name"]: header["value"] for header in operation.get("requestHeaders", [])}
        upload_part(
            operation["method"],
            operation["url"],
            headers=headers,
            data=file_bytes[offset:offset + length],
        )

    commit_body = {
        "data": {
            "type": "gameCenterAchievementImages",
            "id": image["id"],
            "attributes": {
                "uploaded": True,
            },
        }
    }
    return client.request("PATCH", f"/gameCenterAchievementImages/{image['id']}", commit_body)["data"]


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def main():
    key_id = require_env("ASC_KEY_ID")
    issuer_id = require_env("ASC_ISSUER_ID")
    key_path = Path(require_env("ASC_KEY_PATH")).expanduser()
    bundle_id = os.environ.get("ASC_BUNDLE_ID", "com.xiaodao.triyan")

    if not key_path.exists():
        raise RuntimeError(f"ASC key file not found: {key_path}")

    token = make_jwt(key_id, issuer_id, key_path)
    client = ASCClient(token)

    app = app_by_bundle_id(client, bundle_id)
    print(f"App: {app['attributes'].get('name')} ({bundle_id}), id={app['id']}")

    detail = game_center_detail(client, app["id"])
    detail_id = detail["id"]
    print(f"Game Center detail id: {detail_id}")

    existing = existing_achievement_ids(client, detail_id)
    icon_dir = Path(__file__).resolve().parent / "generated_achievement_icons"

    for achievement in ACHIEVEMENTS:
        icon_path = icon_dir / f"{achievement.identifier.split('.')[-1]}.png"
        generate_icon(icon_path, achievement)

        if achievement.identifier in existing:
            created = {"id": existing[achievement.identifier]}
            print(f"Updating existing achievement: {achievement.identifier}")
        else:
            created = create_achievement(client, detail_id, achievement)

        localization = existing_localization(client, created["id"], "zh-Hans")
        if not localization:
            localization = create_localization(client, created["id"], achievement)
        upload_image(client, localization["id"], icon_path)
        print(f"Ready achievement: {achievement.identifier}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
