"""Extract one API-verified rigid mask-header delta onto the original SLX."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from zipfile import ZipFile

from scipy.io import loadmat


ENTRY = 'simulink/systems/system_8_4071.xml'
BLOCK_PATH = ('Rigid Body', 'Hydrodynamic Body', 'Wave Diffraction and Excitation Force Calculation')
OLD = 'nWaves = size(waveGroup,2);'
NEW = 'nWaves = importedExcitationBranches(cb,waveGroup);'
INFO_FIELDS = ('filename', 'orig_filename', 'date_time', 'compress_type', 'comment', 'extra',
               'create_system', 'create_version', 'extract_version', 'reserved', 'flag_bits',
               'volume', 'internal_attr', 'external_attr')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unique(items, label):
    if len(items) != 1:
        raise ValueError(label+': missing or ambiguous structural target')
    return items[0]


def verify_receipt(args, before, after):
    # Execution provenance, not authenticated author-time byte history.
    receipt = loadmat(args.api_receipt, simplify_cells=True).get('report')
    if not isinstance(receipt, dict) or Path(receipt.get('input', '')).resolve() != args.stock.resolve():
        raise ValueError('API receipt does not identify the selected original library')
    if Path(receipt.get('output', '')).resolve() != args.api_candidate.resolve():
        raise ValueError('API receipt does not identify the selected API candidate')
    expected_path = 'WECSim_Lib_Body_Elements/'+'/'.join(BLOCK_PATH)
    if receipt.get('path') != expected_path or receipt.get('before') != before or receipt.get('after') != after:
        raise ValueError('API receipt active mask path or complete script differs')


def target(archive):
    if len(archive.namelist()) != len(set(archive.namelist())):
        raise ValueError('Duplicate archive entries')
    root = ET.fromstring(archive.read('simulink/blockdiagram.xml'))
    system = unique(list(root.iter('System')), 'Library root System')
    entry = None
    for index, name in enumerate(BLOCK_PATH):
        ref = system.get('Ref')
        if ref is None or '/' in ref or '\\' in ref or '..' in ref:
            raise ValueError('Expected a simple separately stored System reference')
        entry = 'simulink/systems/'+ref+'.xml'
        system_root = ET.fromstring(archive.read(entry))
        block = unique([b for b in system_root.findall('Block') if b.get('Name') == name], name)
        if index < len(BLOCK_PATH)-1:
            system = unique(block.findall('System'), name+' child System')
    if entry != ENTRY or block.get('BlockType') != 'SubSystem' or block.get('SID') != '8:4071:6252':
        raise ValueError('Active rigid excitation parent identity differs')
    mask = unique(block.findall('Mask'), 'Rigid excitation mask')
    initialization = unique(mask.findall('Initialization'), 'Rigid mask Initialization')
    if not initialization.text:
        raise ValueError('Empty rigid mask script')
    return initialization.text


def changed_xml(original, before_script, api_script):
    if before_script.count(OLD) != 1 or NEW in before_script or api_script != before_script.replace(OLD, NEW, 1):
        raise ValueError('API-authored script differs beyond the single accepted header line')
    before = ET.fromstring(original)
    unique([p for p in before.iter('Initialization') if p.text == before_script], 'Original rigid script')
    matches = [m for m in re.finditer(br'<Initialization>([^<]*)</Initialization>', original)
               if ET.fromstring(m.group(0)).text == before_script]
    match = unique(matches, 'Original lexical rigid Initialization')
    start, end = match.span(1)
    old_text = original[start:end]
    if old_text.count(OLD.encode('ascii')) != 1:
        raise ValueError('Expected exactly one original ASCII header in the lexical script')
    # Change only the header bytes; all existing XML entity spellings survive.
    new_text = old_text.replace(OLD.encode('ascii'), NEW.encode('ascii'), 1)
    changed = original[:start]+new_text+original[end:]
    if changed[:start]+old_text+changed[start+len(new_text):] != original:
        raise ValueError('Header byte edit is not exactly reversible')
    after = ET.fromstring(changed)
    p = unique([p for p in after.iter('Initialization') if p.text == api_script], 'Changed rigid script')
    p.text = before_script
    if ET.tostring(before) != ET.tostring(after):
        raise ValueError('XML tree changed beyond the single rigid mask header')
    return changed


def verify_archive(stock, output, expected_script, candidate):
    compressed_size_changes = []
    with ZipFile(stock) as original, ZipFile(output) as result:
        if original.namelist() != result.namelist() or original.comment != result.comment:
            raise ValueError('Archive entry order/names/comment changed')
        changed = []
        for left, right in zip(original.infolist(), result.infolist()):
            a, b = original.read(left), result.read(right)
            if a != b:
                changed.append(left.filename)
            for field in INFO_FIELDS:
                if getattr(left, field) != getattr(right, field):
                    raise ValueError('ZipInfo metadata changed: '+left.filename+' / '+field)
            if a == b and (left.CRC != right.CRC or left.file_size != right.file_size):
                raise ValueError('Unchanged payload CRC/length differs')
            if left.compress_size != right.compress_size:
                compressed_size_changes.append(dict(entry=left.filename, old=left.compress_size, new=right.compress_size))
        if changed != ([ENTRY] if candidate else []):
            raise ValueError('Unexpected uncompressed archive-entry changes')
        if target(result) != expected_script:
            raise ValueError('Final complete rigid mask script differs')
        for name in ('metadata/coreProperties.xml', 'metadata/mwcoreProperties.xml'):
            releases = [node.text for node in ET.fromstring(result.read(name)).iter()
                        if node.tag.rsplit('}', 1)[-1] in {'version', 'matlabRelease'}]
            if 'R2020b' not in releases:
                raise ValueError('Original R2020b metadata differs')
    return compressed_size_changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('stock', 'api-candidate', 'api-receipt', 'api-source', 'output'):
        parser.add_argument('--'+name, type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError('Use a new private output directory')
    inputs = [args.stock, args.api_candidate, args.api_receipt, args.api_source]
    hashes = {str(path.resolve()): digest(path) for path in inputs}
    hashes[str(Path(__file__).resolve())] = digest(Path(__file__))
    with ZipFile(args.stock) as stock, ZipFile(args.api_candidate) as candidate:
        before_script, api_script = target(stock), target(candidate)
        verify_receipt(args, before_script, api_script)
        replacement = changed_xml(stock.read(ENTRY), before_script, api_script)
    output.mkdir(parents=True)
    control_path = output/'control'/'WECSim_Lib_Body_Elements.slx'
    candidate_path = output/'candidate'/'WECSim_Lib_Body_Elements.slx'
    control_path.parent.mkdir()
    candidate_path.parent.mkdir()
    # The untouched control is an exact original ZIP, not a model reserialization.
    with control_path.open('xb') as stream:
        stream.write(args.stock.read_bytes())
    with ZipFile(args.stock) as original, ZipFile(candidate_path, 'x') as result:
        result.comment = original.comment
        for info in original.infolist():
            if info.flag_bits != 0 or info.extra:
                raise ValueError('Unsupported ZIP flags/extra fields; do not normalize them silently')
            copied = copy.copy(info)
            payload = replacement if info.filename == ENTRY else original.read(info)
            result.writestr(copied, payload)
            # zipfile assigns default permissions when external_attr==0; restore
            # original central-directory metadata before final directory writing.
            copied.external_attr = info.external_attr
    control_sizes = verify_archive(args.stock, control_path, before_script, False)
    candidate_sizes = verify_archive(args.stock, candidate_path, api_script, True)
    if digest(control_path) != hashes[str(args.stock.resolve())]:
        raise ValueError('Control is not byte-identical to original')
    if any(digest(Path(path)) != expected for path, expected in hashes.items()):
        raise RuntimeError('Frozen original/API evidence changed')
    report = dict(status='PRIVATE EXTRACTION ONLY: strict audit, API reopen and native PR-head tests still required',
        input_sha256=hashes, outputs=dict(control_sha256=digest(control_path), candidate_sha256=digest(candidate_path)),
        active_block='/'.join(BLOCK_PATH), entry=ENTRY, original_header=OLD, api_authored_header=NEW,
        receipt_limit='MAT receipt is execution provenance, not authenticated historical bytes; runtime hashes bind the supplied files',
        changed_uncompressed_entries=[ENTRY], control_compressed_size_changes=control_sizes,
        candidate_compressed_size_changes=candidate_sizes,
        zip_metadata='All INFO_FIELDS preserved; payload-derived CRC/size and physical offsets necessarily recomputed',
        scope='Only active rigid Mask.Initialization header; no API-saved metadata, other entry payload, Drag or Flex transplanted')
    (output/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
