"""Strict private SLX audit for the active rigid Hydro expression only."""
import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile


ENTRY = 'simulink/systems/system_8_4071_6208.xml'
OLD = "body.hydroForce.(['hf' num2str(body.variableHydro.hydroForceIndexInitial)]).adjustedInertiaProducts"
VOLATILE = {'created','modified','lastModifiedBy','revision'}


def normalized(node,metadata=False):
    children = [normalized(child,metadata) for child in node
                if not (metadata and child.tag.rsplit('}',1)[-1] in VOLATILE)]
    text = node.text or ''
    if children and not text.strip():
        text = ''
    return [node.tag,sorted(node.attrib.items()),text,children]


def audit(stock,candidate,mode):
    report = dict(stock_sha256=hashlib.sha256(stock.read_bytes()).hexdigest(),
        candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),mode=mode,
        intended_changes=0,unexplained_changes=[],changed_entries=[])
    with ZipFile(stock) as before,ZipFile(candidate) as after:
        left_names,right_names = set(before.namelist()),set(after.namelist())
        report['added_entries'] = sorted(right_names-left_names)
        report['removed_entries'] = sorted(left_names-right_names)
        for name in sorted(left_names & right_names):
            left,right = before.read(name),after.read(name)
            if left == right:
                continue
            report['changed_entries'].append(name)
            if not name.endswith('.xml'):
                report['unexplained_changes'].append([name,'opaque payload differs'])
                continue
            a,b = ET.fromstring(left),ET.fromstring(right)
            if mode == 'candidate' and name == ENTRY:
                original = [p for p in a.iter('P') if p.get('Name') == 'ProductsOfInertia']
                changed = [p for p in b.iter('P') if p.get('Name') == 'ProductsOfInertia']
                if (len(original) == len(changed) == 1 and original[0].text == OLD
                        and changed[0].text == OLD+'([3 2 1])'):
                    changed[0].text = original[0].text
                    report['intended_changes'] += 1
                else:
                    report['unexplained_changes'].append([name,'unexpected product expression'])
            metadata = name == 'metadata/coreProperties.xml'
            if normalized(a,metadata) != normalized(b,metadata):
                report['unexplained_changes'].append([name,'XML differs beyond permitted expression'])
        report['release_metadata'] = {}
        for name in ('metadata/coreProperties.xml','metadata/mwcoreProperties.xml'):
            tree = ET.fromstring(after.read(name))
            report['release_metadata'][name] = [p.text for p in tree.iter()
                if p.tag.rsplit('}',1)[-1] in {'version','matlabRelease'}]
    report['passed'] = (report['intended_changes'] == (1 if mode == 'candidate' else 0)
        and not report['added_entries'] and not report['removed_entries']
        and not report['unexplained_changes']
        and all('R2020b' in values for values in report['release_metadata'].values()))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stock',type=Path,required=True)
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--mode',choices=('control','candidate'),required=True)
    parser.add_argument('--report',type=Path,required=True)
    args = parser.parse_args()
    report = audit(args.stock.resolve(),args.candidate.resolve(),args.mode)
    with args.report.open('x',encoding='utf-8') as output:
        json.dump(report,output,indent=2)
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
