"""Generate run_001 once, using installed Fiji libraries. No research-session writes."""
from pathlib import Path
import csv
import hashlib
import json
import math
import os
import shutil
import subprocess
import zipfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
FIJI = Path(r'<FIJI_INSTALLATION>')
JAVA = FIJI / 'java/win64/zulu21.42.19-ca-jdk21.0.7-win_x64/bin/java.exe'
PLUGIN = FIJI / 'plugins/3D_Objects_Counter-2.0.1.jar'
OUT = ROOT / 'trials/nucleus_proposals_A01/run_001'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def rows(path):
    with path.open(newline='') as stream:
        return list(csv.DictReader(stream, delimiter='\t'))


def write_table(path, fields, data):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fields, delimiter='\t', lineterminator='\n')
        writer.writeheader()
        writer.writerows(data)


def main():
    context_only = OUT.is_dir() and sorted(p.name for p in OUT.iterdir()) == ['context_preflight_384']
    if OUT.exists() and not context_only:
        raise SystemExit('run_001 already exists. Refusing to overwrite raw proposals or review work.')
    reference = ROOT / 'results_field1_full/checkpoint_37'
    manual = rows(reference / 'annotations_INCOMPLETE.tsv')
    a01 = [r for r in manual if r['owner_area'] == 'A01']
    expected = ['F01_N009'] + [f'F01_N{i:03d}' for i in range(18, 25)]
    if [r['nucleus_id'] for r in a01] != expected or len(manual) != 24:
        raise SystemExit('Frozen reference differs from the reviewed checkpoint-37 baseline.')
    if rows(reference / 'coverage.tsv')[0]['reviewed_all_46'] != '1':
        raise SystemExit('A01 reference is not marked reviewed.')
    for r in a01:
        if float(r['x_px'])+float(r['width_px']) >= 320 or float(r['y_px'])+float(r['height_px']) >= 320:
            raise SystemExit('Reference locator exceeds planned context; review context before generating.')
    source = ROOT / 'data/vukan protoplasts.lif'
    protected = [source] + [p for d in ['results', 'results_field1_full'] for p in (ROOT/d).rglob('*') if p.is_file()]
    before = {str(p.relative_to(ROOT)): sha(p) for p in protected}
    classpath = str(FIJI/'jars/*') + os.pathsep + str(PLUGIN)
    command = [str(JAVA), '-Xmx4g', '-Djava.awt.headless=true', '-cp', classpath, str(ROOT/'scripts/A01Proposals.java')]
    test = subprocess.run(command + ['--selftest'], check=True, capture_output=True, text=True)
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copytree(reference, OUT/'reference_checkpoint_37')
    (OUT/'selftest.log').write_text(test.stdout+test.stderr)
    manifest = {
        'created_utc': datetime.now(timezone.utc).isoformat(),
        'status': 'GENERATING', 'accuracy_status': 'NOT_EVALUATED_MANUAL_MATCHING_REQUIRED',
        'source_lif': str(source), 'source_sha256': before[str(source.relative_to(ROOT))],
        'source_series_name': 'protoplasts 2h post irradiation image 1', 'series_index_zero_based': 2,
        'frozen_reference': str(reference), 'reference_checkpoint_sha256': {p.name:sha(p) for p in reference.iterdir() if p.is_file()},
        'reference_A01_ids': expected, 'reference_candidates': 8, 'reference_eligible': 6,
        'detector': 'GaussianBlur3D + explicit float threshold + Counter3D 26-connected components',
        'plugin': {'path':str(PLUGIN), 'version':'2.0.1', 'sha256':sha(PLUGIN)},
        'imagej': {'version':'1.54p', 'sha256':sha(FIJI/'jars/ij-1.54p.jar')},
        'bioformats_version':'8.5.0',
        'generator_sha256':sha(ROOT/'scripts/A01Proposals.java'),
        'parameters': {'crop_original_xy_half_open':[0,0,1024,1024], 'crop_to_original_offset_px':[0,0],
            'core_xy_half_open':[0,0,256,256], 'z_slices_inclusive':[1,46],
            'voxel_um':[.180375171,.180375171,.356197778], 'gaussian_sigma_um':[.5,.5,.5],
            'gaussian_sigma_voxels':[.5/.180375171,.5/.180375171,.5/.356197778],
            'foreground_rule':'smoothed original-intensity units >= 0.8', 'threshold':.8,
            'smoothing_precision':'32-bit float', 'connectivity':26, 'minimum_volume_um3':1.0,
            'minimum_voxels':math.ceil(1/(.180375171**2*.356197778)),
            'maximum_volume_filter':False, 'exclude_edge_objects':False, 'roundness_filter':False,
            'background_subtraction':False, 'watershed':False,
            'reference_slice_rule':'largest foreground voxel cross-section; earliest slice on tie',
            'locator_rule':'axis-aligned bounding rectangle of component on reference slice',
            'threshold_rationale':'first conservative development baseline, not fitted to display ranges or selected for best matching score',
            'context_rationale':'384x384 preflight had a connected A01 component reaching its artificial boundary. Expanded context to the complete SAME field, with identical detector settings, to remove all artificial XY boundaries. Only A01 is manually evaluated; other candidates are halo context.',
            'labeler_padding':'one trailing zero plane, removed before any geometry/export, to avoid pinned Counter3D terminal-voxel allocation bug',
            'labeler_api':'pinned Counter3D private findObjects/objID stage; avoids unused Object3D voxel-coordinate allocation'},
    }
    (OUT/'manifest.json').write_text(json.dumps(manifest, indent=2))
    with (OUT/'generation.log').open('w') as log:
        subprocess.run(command+[str(source),str(OUT)], check=True, stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
    proposals = rows(OUT/'proposals_raw.tsv')
    assert len({r['proposal_id'] for r in proposals}) == len(proposals)
    with zipfile.ZipFile(OUT/'proposal_locators.zip') as archive:
        assert sorted(Path(n).stem for n in archive.namelist()) == sorted(r['proposal_id'] for r in proposals)
    for r in proposals:
        assert 1 <= int(r['first_z']) <= int(r['reference_z']) <= int(r['last_z']) <= 46
        assert int(r['width_px']) > 0 and int(r['height_px']) > 0
    fields = ['proposal_id','review_status','action','scoring_scope','raw_outcome','matched_manual_ids',
              'primary_one_to_one_manual_id','duplicate_of_proposal','merge_manual_ids','correction_type',
              'corrected_x_px','corrected_y_px','corrected_width_px','corrected_height_px',
              'corrected_first_z','corrected_reference_z','corrected_last_z','review_reason']
    write_table(OUT/'proposal_review.tsv', fields, [{**{f:'' for f in fields},'proposal_id':r['proposal_id'],'review_status':'UNREVIEWED'} for r in proposals])
    ref_fields = ['manual_id','eligibility','first_z','reference_z','last_z','x_px','y_px','width_px','height_px']
    ref_data = [{f:(r['nucleus_id'] if f=='manual_id' else r[f]) for f in ref_fields} for r in a01]
    write_table(OUT/'manual_A01_reference.tsv', ref_fields, ref_data)
    match_fields = ['manual_id','eligibility','review_status','primary_proposal_id','all_related_proposals','missed_FN','merge_flag','notes']
    write_table(OUT/'manual_matching.tsv', match_fields, [{**{f:'' for f in match_fields}, 'manual_id':r['nucleus_id'], 'eligibility':r['eligibility'], 'review_status':'UNREVIEWED'} for r in a01])
    (OUT/'evaluation_status.json').write_text(json.dumps({'status':'NOT_EVALUATED', 'reference_n':8, 'eligible_reference_n':6,
        'raw_proposal_n':len(proposals), 'TP':None,'FN':None,'FP':None,'duplicates':None,'merges':None,'recall':None,'precision':None},indent=2))
    after = {str(p.relative_to(ROOT)):sha(p) for p in protected}
    if before != after:
        raise RuntimeError('A protected source/session file changed during generation; inspect before proceeding.')
    summary = rows(OUT/'generation_summary.tsv')[0]
    manifest['status']='GENERATED_UNREVIEWED'
    manifest['generation_summary']=summary
    manifest['context_safeguard']='PASS_NO_A01_COMPONENT_REACHES_ARTIFICIAL_EDGE' if int(summary['core_components_touching_artificial_edge'])==0 else 'REVIEW_REQUIRED_CORE_COMPONENT_REACHES_ARTIFICIAL_EDGE'
    manifest['protected_file_sha256']=before
    manifest['preservation_check']='ALL_PROTECTED_FILES_UNCHANGED'
    # These raw assets are immutable by workflow; hashes detect later edits.
    manifest['raw_output_sha256']={p.name:sha(p) for p in OUT.iterdir() if p.is_file() and p.name not in ['manifest.json','proposal_review.tsv','manual_matching.tsv','evaluation_status.json']}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print('Generated run_001, UNREVIEWED. '+json.dumps(summary))
    print('No TP/FN/FP/duplicate/merge decisions or accuracy metrics have been assigned.')


if __name__ == '__main__':
    main()
