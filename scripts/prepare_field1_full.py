"""Copy only the validated ORIGINAL pilot into a separate full-field session.

No annotation editing. Safe to run again: refuses an existing destination.
"""
from pathlib import Path
import csv
import hashlib
import json
import shutil
import struct
import zipfile
from datetime import datetime, timezone


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def validate_snapshot(original):
    pointer = (original / 'latest.txt').read_text().strip()
    if not pointer.startswith('checkpoint_') or not pointer[11:].isdigit():
        raise ValueError('Invalid original checkpoint pointer')
    snapshot = original / pointer
    if not (snapshot / 'READY.txt').is_file():
        raise ValueError('Original checkpoint is not ready')
    metadata = (snapshot / 'session.txt').read_text().splitlines()
    if (len(metadata) != 14 or metadata[0] != 'PCNA_FIELD1_PILOT_V1'
            or metadata[3] != 'protoplasts 2h post irradiation image 1'
            or metadata[11] != 'INCOMPLETE_PILOT'):
        raise ValueError('Expected the original field-1 pilot')
    with (snapshot / 'annotations_INCOMPLETE.tsv').open(newline='') as stream:
        rows = list(csv.DictReader(stream, delimiter='\t'))
    if [r['nucleus_id'] for r in rows] != [f'F01_N{i:03d}' for i in range(1, 16)]:
        raise ValueError('Expected all 15 original IDs in order')
    by_id = {r['nucleus_id']: r for r in rows}
    four, five = by_id['F01_N004'], by_id['F01_N005']
    if not (four['eligibility'] == 'eligible' and four['pattern_or_status'] == 'punctate'
            and 'boundary' in four['reason'].lower() and 'margin' in four['reason'].lower()):
        raise ValueError('Save N004 boundary decision through the pilot macro first')
    if not (five['eligibility'] == 'excluded' and five['pattern_or_status'] == 'uncertain'
            and 'truncation' in five['reason'].lower() and '46' in five['reason']):
        raise ValueError('Save N005 exclusion and retained explanation through the pilot macro first')
    with zipfile.ZipFile(snapshot / 'locators.zip') as archive:
        if sorted(Path(n).stem for n in archive.namelist()) != sorted(by_id):
            raise ValueError('ROI IDs do not match annotation IDs')
        for row in rows:
            if not 1 <= int(row['first_z']) <= int(row['reference_z']) <= int(row['last_z']) <= 46:
                raise ValueError('Invalid saved z-range')
            roi = archive.read(row['nucleus_id'] + '.roi')
            top, left, bottom, right = struct.unpack_from('>hhhh', roi, 8)
            if (left, top, right-left, bottom-top) != tuple(int(row[k]) for k in ('x_px','y_px','width_px','height_px')):
                raise ValueError('ROI/table locator bounds differ')
    return snapshot, rows


def prepare(original, destination):
    if destination.exists():
        raise FileExistsError('Full-field destination already exists; never overwrite or recopy an active survey')
    snapshot, rows = validate_snapshot(original)
    files = {str(p.relative_to(original)): digest(p) for p in original.rglob('*') if p.is_file()}
    shutil.copytree(original, destination)
    if files != {str(p.relative_to(destination)): digest(p) for p in destination.rglob('*') if p.is_file()}:
        raise RuntimeError('Copy verification failed; do not open the copied session')
    provenance = {
        'source_session': str(original.resolve()),
        'parent_checkpoint': snapshot.name,
        'created_utc': datetime.now(timezone.utc).isoformat(),
        'inherited_ids': [r['nucleus_id'] for r in rows],
        'original_file_sha256': files,
        'all_grid_areas_initially_unreviewed': True,
    }
    (destination / 'origin.json').write_text(json.dumps(provenance, indent=2))
    # Write authorization marker last; full-field macro refuses unmarked folders.
    (destination / 'FIELD1_FULL_SESSION.txt').write_text(
        'PCNA_FIELD1_FULL_COPY_V1\n' + str(original.resolve()) + '\n' + snapshot.name + '\n')
    return snapshot


if __name__ == '__main__':
    workspace = Path(__file__).resolve().parents[1]
    parent = prepare(workspace / 'results', workspace / 'results_field1_full')
    print('Verified separate full-field copy: results_field1_full')
    print('Parent: results/' + parent.name + '; all 15 IDs/annotations/ROIs retained unchanged')
    print('The full-field macro initializes coverage on first Resume; no survey has been performed.')
