"""Publicar backlog uma vez; reexecução reutiliza issues por identificador Txx."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = 'ADSSTech/na_lata'

def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()

for name, color in [('prioridade:principal','0E8A16'), ('prioridade:extra','FBCA04'), ('flutter','02569B'), ('aula','5319E7')]:
    gh('label', 'create', name, '--repo', REPO, '--color', color, '--force')
existing = json.loads(gh('issue','list','--repo',REPO,'--state','all','--limit','200','--json','title,url,number'))
links = ['# Issues publicadas', '', '| Tarefa | Issue |', '|---|---|']
for task in json.loads((ROOT/'docs/tasks.json').read_text()):
    prefix = '[' + task['id'] + ']'
    match = next((i for i in existing if i['title'].startswith(prefix)), None)
    url = match['url'] if match else gh('issue','create','--repo',REPO,'--title',prefix+' '+task['title'],
        '--body-file',str(ROOT/'docs/issues'/f"{task['id']}.md"),
        '--label','flutter','--label','aula','--label',task['priority'])
    links.append(f"| {task['id']} | [{task['title']}]({url}) |")
    print(task['id'], url, flush=True)
(ROOT/'docs/ISSUES_GITHUB.md').write_text('\n'.join(links)+'\n')
