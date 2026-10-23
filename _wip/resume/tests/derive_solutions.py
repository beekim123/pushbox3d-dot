#!/usr/bin/env python3
"""Create the minimal resume-only fixture; never changes the source report."""
import hashlib, json, pathlib, sys
root=pathlib.Path(__file__).resolve().parents[1]
source=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else root/'reference/solver_report_full.json'
raw=source.read_bytes(); report=json.loads(raw)
entries=[{'id':entry['id'],'solution':entry['solution']} for entry in report['levels']]
assert len(entries)==204 and len({entry['id'] for entry in entries})==204
assert all(isinstance(e['id'],str) and isinstance(e['solution'],str) and set(e['solution'])<=set('UDLR') for e in entries)
output=(json.dumps({'levels':entries},ensure_ascii=False,separators=(',',':'))+'\n').encode()
(root/'snapshot/resume_solutions.json').write_bytes(output)
provenance={'purpose':'Only id and solution are read by resume tests; all 204 original entries and order preserved. No claims about discarded full report fields.', 'source_name':'solver_report.json','source_sha256':hashlib.sha256(raw).hexdigest(),'source_bytes':len(raw),'entries':len(entries),'derived_name':'resume_solutions.json','derived_sha256':hashlib.sha256(output).hexdigest(),'derived_bytes':len(output),'derivation_script':'tests/derive_solutions.py'}
(root/'snapshot/solutions_provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(provenance))
