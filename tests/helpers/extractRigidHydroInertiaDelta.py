"""Extract one API-verified property delta onto the original R2020b SLX."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from zipfile import ZipFile

from scipy.io import loadmat


ENTRY = 'simulink/systems/system_8_4071_6208.xml'
BLOCK_PATH = ('Rigid Body', 'Hydrodynamic Body', 'Structure', 'Body Properties')
OLD = "body.hydroForce.(['hf' num2str(body.variableHydro.hydroForceIndexInitial)]).adjustedInertiaProducts"
NEW = OLD+'([3 2 1])'
INFO_FIELDS = ('filename', 'orig_filename', 'date_time', 'compress_type', 'comment', 'extra',
               'create_system', 'create_version', 'extract_version', 'reserved', 'flag_bits',
               'volume', 'internal_attr', 'external_attr')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unique(items, label):
    if len(items) != 1:
        raise ValueError(label+': missing or ambiguous structural target')
    return items[0]


def verify_receipt(args):
    # Execution provenance, not authenticated author-time byte history.
    receipt = loadmat(args.api_receipt, simplify_cells=True).get('report')
    if not isinstance(receipt, dict) or Path(receipt.get('source', '')).resolve() != args.stock.resolve():
        raise ValueError('API receipt does not identify the selected original library')
    records = receipt.get('outputs')
    if not isinstance(records, (list, tuple)) or len(records) != 2:
        raise ValueError('API receipt must contain the control and candidate records')
    for mode, path, expression in [('control', args.api_control, OLD), ('candidate', args.api_candidate, NEW)]:
        record = unique([item for item in records if isinstance(item, dict) and item.get('mode') == mode],
                        'API receipt '+mode)
        if Path(record.get('export', '')).resolve() != path.resolve() or record.get('expression') != expression:
            raise ValueError('API receipt output path/expression differs: '+mode)


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
    if entry != ENTRY or block.get('BlockType') != 'Reference' or block.get('SID') != '8:4071:6210':
        raise ValueError('Active Rigid Hydro File Solid identity differs')
    prop = unique(block.findall("InstanceData/P[@Name='ProductsOfInertia']"), 'File Solid products')
    unique([p for p in system_root.iter('P') if p.get('Name') == 'ProductsOfInertia'], 'Entry products')
    return prop.text


def changed_xml(original, api_value):
    if api_value != NEW:
        raise ValueError('API-authored candidate is not exactly the accepted order correction')
    before = ET.fromstring(original)
    prop = unique([p for p in before.iter('P') if p.get('Name') == 'ProductsOfInertia'], 'Original products')
    if prop.text != OLD:
        raise ValueError('Original property expression differs')
    # Actual R2020b lexical text contains &apos; rather than literal quotes.
    # Locate the one already structurally verified property; never reserialize it.
    match = unique(list(re.finditer(br'<P Name="ProductsOfInertia">([^<]*)</P>', original)),
                   'Original lexical property span')
    if ET.fromstring(match.group(0)).text != OLD:
        raise ValueError('Decoded original lexical property differs')
    start, end = match.span(1)
    old_text = original[start:end]
    new_text = old_text+b'([3 2 1])'
    # Only append the API-verified suffix; keep every original entity spelling.
    changed = original[:start]+new_text+original[end:]
    if changed[:start]+old_text+changed[start+len(new_text):] != original:
        raise ValueError('Property byte edit is not exactly reversible')
    after = ET.fromstring(changed)
    p = unique([p for p in after.iter('P') if p.get('Name') == 'ProductsOfInertia'], 'Changed products')
    if p.text != api_value:
        raise ValueError('Decoded changed property differs from API-authored value')
    p.text = OLD
    if ET.tostring(before) != ET.tostring(after):
        raise ValueError('XML tree changed beyond the single property value')
    return changed


def verify_archive(stock, output, candidate):
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
        if target(result) != (NEW if candidate else OLD):
            raise ValueError('Final structural property value differs')
    return compressed_size_changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('stock', 'api-control', 'api-candidate', 'api-receipt', 'api-source', 'output'):
        parser.add_argument('--'+name, type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError('Use a new private output directory')
    inputs = [args.stock, args.api_control, args.api_candidate, args.api_receipt, args.api_source]
    hashes = {str(path.resolve()): digest(path) for path in inputs}
    hashes[str(Path(__file__).resolve())] = digest(Path(__file__))
    verify_receipt(args)
    with ZipFile(args.stock) as stock, ZipFile(args.api_control) as control, ZipFile(args.api_candidate) as candidate:
        if target(stock) != OLD or target(control) != OLD or target(candidate) != NEW:
            raise ValueError('Verified API before/after expressions do not match')
        replacement = changed_xml(stock.read(ENTRY), target(candidate))
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
    control_sizes = verify_archive(args.stock, control_path, False)
    candidate_sizes = verify_archive(args.stock, candidate_path, True)
    if digest(control_path) != hashes[str(args.stock.resolve())]:
        raise ValueError('Control is not byte-identical to original')
    if any(digest(Path(path)) != expected for path, expected in hashes.items()):
        raise RuntimeError('Frozen original/API evidence changed')
    report = dict(status='PRIVATE EXTRACTION ONLY: strict audit, API reopen and native PR-head tests still required',
        input_sha256=hashes, outputs=dict(control_sha256=digest(control_path), candidate_sha256=digest(candidate_path)),
        active_block='/'.join(BLOCK_PATH), entry=ENTRY, original_expression=OLD, api_authored_expression=NEW,
        receipt_limit='MAT receipt is execution provenance, not authenticated historical bytes; runtime hashes bind the supplied files',
        changed_uncompressed_entries=[ENTRY], control_compressed_size_changes=control_sizes,
        candidate_compressed_size_changes=candidate_sizes,
        zip_metadata='All INFO_FIELDS preserved; payload-derived CRC/size and physical offsets necessarily recomputed',
        scope='Only active Rigid Hydro property text; no API-export model metadata or other entry payload transplanted')
    (output/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
