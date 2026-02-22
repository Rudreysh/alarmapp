#!/usr/bin/env python3
import urllib.parse
import os
import json
import uuid

# Configuration
REPO_USER = "Rudreysh"
REPO_NAME = "alarmapp"
BRANCH = "green-theme"  # Change to 'main' when merging to production!

# Paths
ROOT_DIR = os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))  # Root of repo
ASSETS_DIR = os.path.join(ROOT_DIR, "HostedAssets")
CATALOG_PATH = os.path.join(ASSETS_DIR, "catalog.json")

# Base URL for raw content
BASE_URL = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/HostedAssets"


def generate_catalog():
    if not os.path.exists(ASSETS_DIR):
        print(f"Error: {ASSETS_DIR} does not exist.")
        return

    wallpapers = []
    sounds = []

    # Process Wallpapers
    wallpaper_dir = os.path.join(ASSETS_DIR, "wallpapers")
    if os.path.exists(wallpaper_dir):
        for category in os.listdir(wallpaper_dir):
            cat_path = os.path.join(wallpaper_dir, category)
            if os.path.isdir(cat_path):
                items = []
                for filename in os.listdir(cat_path):
                    if filename.startswith('.'):
                        continue

                    file_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, filename))
                    # Encode filename to handle spaces and special chars
                    safe_filename = urllib.parse.quote(filename)
                    url = f"{BASE_URL}/wallpapers/{category}/{safe_filename}"

                    items.append({
                        "id": file_id,
                        "filename": filename,
                        "title": os.path.splitext(filename)[0].replace("-", " ").title(),
                        "url": url,
                        "thumbnail": None
                    })

                if items:
                    wallpapers.append({
                        "id": category.lower(),
                        "title": category.title(),
                        "items": items
                    })

    # Process Sounds
    sound_dir = os.path.join(ASSETS_DIR, "sounds")
    if os.path.exists(sound_dir):
        for category in os.listdir(sound_dir):
            cat_path = os.path.join(sound_dir, category)
            if os.path.isdir(cat_path):
                for filename in os.listdir(cat_path):
                    if filename.startswith('.'):
                        continue

                    file_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, filename))
                    safe_filename = urllib.parse.quote(filename)
                    url = f"{BASE_URL}/sounds/{category}/{safe_filename}"

                    sounds.append({
                        "id": file_id,
                        "filename": filename,
                        "title": os.path.splitext(filename)[0].replace("-", " ").title(),
                        "category": category.title(),
                        "url": url,
                        "isPremium": False
                    })

    # Create Catalog
    catalog = {
        "version": 1,
        "wallpapers": wallpapers,
        "sounds": sounds
    }

    with open(CATALOG_PATH, "w") as f:
        json.dump(catalog, f, indent=2)

    print(f"✅ Generated catalog.json at {CATALOG_PATH}")
    print(
        f"📦 Found {len(wallpapers)} wallpaper categories and {len(sounds)} sounds.")


if __name__ == "__main__":
    generate_catalog()
