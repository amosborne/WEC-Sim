"""Unchanged-export control audit: zero mask edits and no unexplained changes."""
import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile

from audit_rigid_dispatch_archive import ENTRY,normalized


def audit(stock,control):
    report = dict(stock=str(stock),control=str(control),
        stock_sha256=hashlib.sha256(stock.read_bytes()).hexdigest(),
        control_sha256=hashlib.sha256(control.read_bytes()).hexdigest(),
        expected_header_changes=0,actual_header_changes=0,changed_entries=[],unexplained_changes=[])
    with ZipFile(stock) as before,ZipFile(control) as after:
        old_names,new_names = set(before.namelist()),set(after.namelist())
        report['added_entries'] = sorted(new_names-old_names)
        report['removed_entries'] = sorted(old_names-new_names)
        for name in sorted(old_names & new_names):
            old,new = before.read(name),after.read(name)
            if old == new:
                continue
            report['changed_entries'].append(name)
            if not name.endswith('.xml'):
                report['unexplained_changes'].append(dict(entry=name,reason='opaque payload differs'))
                continue
            left,right = ET.fromstring(old),ET.fromstring(new)
            if name == ENTRY:
                old_scripts = [n.text for n in left.iter('Initialization')]
                new_scripts = [n.text for n in right.iter('Initialization')]
                if old_scripts != new_scripts:
                    report['actual_header_changes'] += 1
            metadata = name == 'metadata/coreProperties.xml'
            if normalized(left,metadata) != normalized(right,metadata):
                report['unexplained_changes'].append(dict(entry=name,reason='control XML semantics differ'))
    report['passed'] = (report['actual_header_changes'] == 0 and not report['added_entries']
        and not report['removed_entries'] and not report['unexplained_changes'])
    report['scope'] = 'Untouched serialization control; existing metadata normalization only; no behavioral equivalence claim'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('stock','control','report'):
        parser.add_argument('--'+name,type=Path,required=True)
    args = parser.parse_args()
    report = audit(args.stock.resolve(),args.control.resolve())
    with args.report.open('x',encoding='utf-8') as stream:
        json.dump(report,stream,indent=2)
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
