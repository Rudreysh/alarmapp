#!/usr/bin/env python3
import os
import re
import shutil

ROOT_DIR = os.path.join(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))), "HostedAssets")

# Prefixes that don't add value to the name
JUNK_PREFIXES = [
    "pexels", "unsplash", "mixkit", "grand_project", "ethnicsoundscapes",
    "tunetank", "royalty_free_music", "kalsstockmedia", "mandakimdk",
    "sonican", "clavier-music", "quietphase", "petrushkasound", "vem_click",
    "audiopapkin", "freesound_community", "tanweraman", "microsammy",
    "8footdino_on_scratch", "soundgallerybydmitrytaras", "withoguz",
    "theshuttervision", "vision-plug", "wong-peter"
]


def clean_filename(filename):
    name, ext = os.path.splitext(filename)

    # 1. Lowercase for processing
    name = name.lower()

    # 2. Remove Junk Prefixes
    for prefix in JUNK_PREFIXES:
        if prefix in name:
            name = name.replace(prefix, "")

    # 3. Remove "unsplash" suffix common in downloads
    name = name.replace("unsplash", "")

    # 4. Remove common patterns like (1), _1, -123456
    name = re.sub(r'\(\d+\)', '', name)
    name = re.sub(r'[-_]\d{4,}', '', name)  # Remove long serial numbers

    # 5. Clean separators
    name = name.replace("-", " ").replace("_", " ")

    # 6. Filter words
    parts = name.split()
    clean_parts = []
    for part in parts:
        # specific skip for random hashes often found in unsplash/pexels
        if len(part) > 12 and any(c.isdigit() for c in part):
            continue
        if part.isdigit():
            continue  # Skip standalone numbers
        clean_parts.append(part)

    # 7. Reassemble
    new_name = " ".join(clean_parts).strip().title()

    if not new_name:
        return filename  # Fallback to original if we stripped everything

    return f"{new_name}{ext}"


def main():
    if not os.path.exists(ROOT_DIR):
        print(f"Error: {ROOT_DIR} not found.")
        return

    renamed_count = 0

    for root, dirs, files in os.walk(ROOT_DIR):
        for filename in files:
            if filename.startswith("."):
                continue
            if filename == "catalog.json":
                continue

            old_path = os.path.join(root, filename)
            new_name = clean_filename(filename)

            # Handle collisions
            base, ext = os.path.splitext(new_name)
            counter = 1
            while os.path.exists(os.path.join(root, new_name)) and new_name != filename:
                new_name = f"{base} {counter}{ext}"
                counter += 1

            if new_name != filename:
                new_path = os.path.join(root, new_name)
                os.rename(old_path, new_path)
                print(f"Refined: {filename} -> {new_name}")
                renamed_count += 1

    print(f"\n✅ Finished! Renamed {renamed_count} files.")


if __name__ == "__main__":
    main()
