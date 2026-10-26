"""Strict source audit of the private supported-API rigid mask preparation."""
import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile


ENTRY = 'simulink/systems/system_8_4071.xml'
OLD = 'nWaves = size(waveGroup,2);'
NEW = 'nWaves = importedExcitationBranches(cb,waveGroup);'
VOLATILE = {'created','modified','lastModifiedBy','revision'}


def normalized(node,metadata=False):
    children = [normalized(child,metadata) for child in node
                if not (metadata and child.tag.rsplit('}',1)[-1] in VOLATILE)]
    text = node.text or ''
    if children and not text.strip():
        text = ''
    return [node.tag,sorted(node.attrib.items()),text,children]


def audit(stock,candidate):
    report = dict(stock=str(stock),candidate=str(candidate),
        stock_sha256=hashlib.sha256(stock.read_bytes()).hexdigest(),
        candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),
        intended_header_changes=0,unexplained_changes=[],changed_entries=[])
    with ZipFile(stock) as before, ZipFile(candidate) as after:
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
                old_nodes = [n for n in left.iter('Initialization') if OLD in (n.text or '')]
                new_nodes = [n for n in right.iter('Initialization') if NEW in (n.text or '')]
                if (len(old_nodes) == len(new_nodes) == 1 and old_nodes[0].text.count(OLD) == 1
                        and new_nodes[0].text == old_nodes[0].text.replace(OLD,NEW)):
                    report['intended_header_changes'] += 1
                    new_nodes[0].text = old_nodes[0].text
                else:
                    report['unexplained_changes'].append(dict(entry=name,reason='rigid header delta is not exact'))
            metadata = name == 'metadata/coreProperties.xml'
            if normalized(left,metadata) != normalized(right,metadata):
                report['unexplained_changes'].append(dict(entry=name,reason='XML semantics differ beyond intended header'))
    report['passed'] = (report['intended_header_changes'] == 1 and not report['added_entries']
        and not report['removed_entries'] and not report['unexplained_changes'])
    report['scope'] = 'Every archive entry audited; version/serialization changes need separate review, no physical proof'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('stock','candidate','report'):
        parser.add_argument('--'+name,type=Path,required=True)
    args = parser.parse_args()
    report = audit(args.stock.resolve(),args.candidate.resolve())
    with args.report.open('x',encoding='utf-8') as stream:
        json.dump(report,stream,indent=2)
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
