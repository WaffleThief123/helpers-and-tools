#!/usr/bin/env python3
"""
Scan qBittorrent torrents, find their files under /mediaserver/,
update save paths, and force recheck.
"""

import argparse
import os
import sys
from collections import defaultdict

ERROR_STATES = {"error", "missingFiles"}


def build_file_index(search_root):
    """Build a map of filename -> list of full paths under search_root."""
    print(f"Indexing files under {search_root} ...")
    index = defaultdict(list)
    for dirpath, _, filenames in os.walk(search_root):
        for fname in filenames:
            index[fname].append(dirpath)
    print(f"  Indexed {sum(len(v) for v in index.values())} files")
    return index


def find_torrent_location(torrent, files, file_index):
    """
    Given a torrent and its file list, try to locate the content
    under the indexed search root.

    For a single-file torrent the save path is the directory containing
    that file. For a multi-file torrent the save path is the parent of
    the torrent's root folder.

    Returns (new_save_path, renamed_folder) or (None, None).
    renamed_folder is the on-disk folder name when it differs from the
    torrent's expected root folder name, or None if it matches.
    """
    if not files:
        return None, None

    # Use the first file in the torrent to locate it
    first_file = files[0]
    # first_file.name is relative, e.g. "Movie (2024)/movie.mkv" or just "movie.mkv"
    rel_path = first_file.name
    parts = rel_path.replace("\\", "/").split("/")
    basename = parts[-1]

    candidates = file_index.get(basename, [])
    if not candidates:
        return None, None

    # For multi-file torrents, the first path component is the folder name
    is_multi = len(files) > 1 or len(parts) > 1

    for dirpath in candidates:
        full = os.path.join(dirpath, basename)
        if not os.path.isfile(full):
            continue

        # Verify file size matches what the torrent expects
        if os.path.getsize(full) != first_file.size:
            continue

        if is_multi:
            # rel_path = "FolderName/sub/file.ext"
            # We need dirpath to end with the subdirectory portion
            # and save_path = parent of FolderName
            sub_parts = parts[:-1]  # directories inside the torrent
            renamed_folder = None

            if sub_parts:
                expected_suffix = os.path.join(*sub_parts)

                if dirpath.endswith(expected_suffix):
                    # Exact match — folder name unchanged
                    save_path = dirpath[: -len(expected_suffix)].rstrip(os.sep)
                else:
                    # Relaxed match — base folder may have been renamed.
                    # sub_parts[0] is the torrent root folder name,
                    # sub_parts[1:] are subdirectories within it.
                    inner_parts = sub_parts[1:]

                    if inner_parts:
                        inner_suffix = os.path.join(*inner_parts)
                        if not dirpath.endswith(inner_suffix):
                            continue
                        # dirpath = .../RenamedFolder/sub/path
                        renamed_folder_path = dirpath[: -len(inner_suffix)].rstrip(os.sep)
                    else:
                        # File sits directly inside the root folder
                        renamed_folder_path = dirpath

                    renamed_folder = os.path.basename(renamed_folder_path)
                    save_path = os.path.dirname(renamed_folder_path)
            else:
                save_path = dirpath
        else:
            save_path = dirpath
            renamed_folder = None

        # Verify a second file also exists with correct size (sanity check for multi-file)
        if len(files) > 1:
            second_file = files[1]
            second_rel = second_file.name.replace("\\", "/")
            if renamed_folder:
                # Substitute the original root folder with the renamed one
                second_parts = second_rel.split("/")
                second_parts[0] = renamed_folder
                second_rel = "/".join(second_parts)
            second_full = os.path.join(save_path, second_rel)
            if not os.path.isfile(second_full):
                continue
            if os.path.getsize(second_full) != second_file.size:
                continue

        return save_path, renamed_folder

    return None, None


def main():
    parser = argparse.ArgumentParser(
        description="Relocate qBittorrent torrents to paths under a search root.",
        epilog=(
            "examples:\n"
            "  %(prog)s --dry-run\n"
            "      Preview relocations without making changes.\n"
            "\n"
            "  %(prog)s --errored-only\n"
            "      Only process torrents in error/missing-files state.\n"
            "\n"
            "  %(prog)s --search-root /mnt/data/ --host 192.168.1.50 --port 9090\n"
            "      Search a custom path on a remote qBittorrent instance.\n"
            "\n"
            "  %(prog)s --errored-only --dry-run\n"
            "      Preview what would happen for errored torrents only.\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--host", default="localhost", help="qBittorrent Web UI host (default: localhost)"
    )
    parser.add_argument(
        "--port", type=int, default=8080, help="qBittorrent Web UI port (default: 8080)"
    )
    parser.add_argument("--username", default="admin", help="Web UI username (default: admin)")
    parser.add_argument("--password", default="adminadmin", help="Web UI password")
    parser.add_argument(
        "--search-root",
        default="/mediaserver/",
        help="Root path to search for torrent files (default: /mediaserver/)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes",
    )
    parser.add_argument(
        "--errored-only",
        action="store_true",
        help="Only process torrents in error or missing-files state",
    )
    args = parser.parse_args()

    try:
        import qbittorrentapi
    except ImportError:
        sys.exit("Missing dependency: pip install qbittorrentapi")

    # Connect
    client = qbittorrentapi.Client(
        host=args.host, port=args.port, username=args.username, password=args.password
    )
    try:
        client.auth_log_in()
    except qbittorrentapi.LoginFailed:
        sys.exit("Login failed. Check credentials.")
    print(f"Connected to qBittorrent {client.app.version}")

    # Build file index
    file_index = build_file_index(args.search_root)

    # Process torrents
    torrents = client.torrents_info()
    if args.errored_only:
        torrents = [t for t in torrents if t.state in ERROR_STATES]
        print(f"Found {len(torrents)} errored torrents\n")
    else:
        print(f"Found {len(torrents)} torrents\n")

    total = len(torrents)
    relocated = 0
    skipped = 0
    not_found = 0
    failed = 0
    not_found_list = []
    failed_list = []

    for i, t in enumerate(torrents, 1):
        torrent_files = t.files
        current_path = t.save_path or t.content_path
        new_path, renamed_folder = find_torrent_location(t, torrent_files, file_index)

        if new_path is None:
            print(f"[{i}/{total}] [NOT FOUND] {t.name}")
            print(f"            hash: {t.hash}")
            print(f"            current: {current_path}\n")
            not_found += 1
            not_found_list.append(t.name)
            continue

        # Normalize for comparison
        norm_current = os.path.normpath(current_path)
        norm_new = os.path.normpath(new_path)

        if norm_current == norm_new and renamed_folder is None:
            skipped += 1
            continue

        # Work out original folder name for rename operations
        original_folder = None
        if renamed_folder:
            first_rel = torrent_files[0].name.replace("\\", "/")
            original_folder = first_rel.split("/")[0]

        print(f"[{i}/{total}] [RELOCATE]  {t.name}")
        print(f"            hash: {t.hash}")
        print(f"            from: {current_path}")
        print(f"            to:   {new_path}")
        if renamed_folder:
            print(f"            folder rename: {original_folder} -> {renamed_folder}")

        if not args.dry_run:
            try:
                if renamed_folder:
                    t.rename_folder(original_folder, renamed_folder)
                t.set_location(new_path)
                t.recheck()
                print("            -> location updated & recheck started")
            except Exception as e:
                print(f"            -> FAILED: {e}")
                failed += 1
                failed_list.append((t.name, str(e)))
                continue
        else:
            print("            -> dry run, no changes made")
        print()
        relocated += 1

    print("---")
    print(
        f"Relocated: {relocated}  Skipped (already correct): {skipped}  "
        f"Not found: {not_found}  Failed: {failed}"
    )

    if not_found_list:
        print(f"\n--- Not found ({len(not_found_list)}) ---")
        for name in not_found_list:
            print(f"  {name}")

    if failed_list:
        print(f"\n--- Failed ({len(failed_list)}) ---")
        for name, err in failed_list:
            print(f"  {name}: {err}")

    client.auth_log_out()


if __name__ == "__main__":
    main()
