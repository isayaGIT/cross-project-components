#!/usr/bin/env python3
"""Migrate one complete backend subsystem per 15-minute cycle, using one fresh ChatGPT chat."""
from __future__ import annotations
import ast
import fcntl
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent
SOURCE = pathlib.Path('/Users/koripor/Repos/人机恋开发/tests/html-app/app1_v2.2_cloud_ver_')
CLOUD = SOURCE / 'cloud'
CLI = pathlib.Path('/Users/koripor/Repos/Public Repos/chatgptwebcli/chatgpt-web/run')
PROMPT_FILE = ROOT / 'automation_prompt.md'
LOG_DIR = ROOT / 'logs'
STATE = ROOT / 'MODULES.json'
STATUS = ROOT / 'STATUS.md'
CHECKPOINT_DIR = ROOT / '.checkpoints'
LOCK_FILE = ROOT / '.cycle.lock'
EXCLUDE_PARTS = {'.git', '.cursor', '.traces', '__pycache__', 'tests', 'test', 'node_modules', 'vendor', 'tools', '.venv', 'venv', 'dist', 'build', 'coverage', 'saves', 'assets', 'uploads', 'cache', 'logs'}
SOURCE_EXTS = {'.py', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx', '.html', '.htm', '.css', '.json'}
BACKEND_EXTS = {'.py'}
BACKEND_EXCLUDE_PARTS = {'static', 'public', 'frontend', 'front_end', 'client', 'client-side', 'web', 'templates', 'views', 'assets', 'css', 'js', 'images', 'fonts', 'icons', 'stickers', 'effects', 'themes', 'saves', 'uploads', 'cache'}
MAX_SOURCE_BUNDLE_BYTES = 70_000
CYCLE_SECONDS = 14 * 60
TURN_INTERVAL_SECONDS = 180
TURN_TIMEOUT_SECONDS = 165
ENV = {**os.environ, 'PATH': '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', 'CHATGPT_WEB_AGENT_MAX_ATTEMPTS': '1'}

DISCOVERY_INSTRUCTIONS = r'''You are the subsystem architect for the user's actual HTML application project, being migrated into reusable native Swift.
SOURCE PROJECT ROOT: /Users/koripor/Repos/人机恋开发/tests/html-app/app1_v2.2_cloud_ver_
The user has NOT defined the project's canonical subsystem list or boundaries. You must discover them from the source project itself; do not assume a roadmap or predefined list. HARD CONSTRAINT: BACKEND ONLY. Select and implement only server-side/backend subsystems (primarily Python server/service/business logic, persistence, auth, integrations, background jobs, backend LLM infrastructure, configuration and backend contracts). NEVER migrate frontend UI, HTML/CSS, browser-side JS/TS, DOM behavior, visual themes/effects, client interactions, or SwiftUI. The supplied catalog can include files for context, but candidate source_paths MUST be backend-only. Use directory/package role, imports, callers, data flow, configuration, persistence, runtime dependencies and public contracts as evidence.
Each cycle must choose one materially useful backend task: prefer an uncovered subsystem, but select an existing subsystem for improvement when module summaries, source contracts, or implementation evidence suggest a concrete high-impact gap. Historical module records are evidence to audit for correctness, compatibility, security, reliability, maintainability, and completeness; they are not a fixed roadmap. Do not automatically resume a partial candidate without identifying a specific gap. When feasible, use available web/repository search to identify reputable open-source alternatives or reference implementations, and evaluate licensing, maintenance, dependencies, compatibility, and security before recommending/adapting them. Never invent research results; if search is unavailable, state that limitation. The LLM Provider layer in cloud/llm/ is merely an example of cohesive granularity; do not prefer it by default.
Choose a cohesive backend system, not one arbitrary file/helper/class, and do not combine unrelated responsibilities or migrate the whole application. Exclude tests, generated/vendor/dependency/build artifacts and all frontend/static assets. The runner supplies complete selected backend source files in the next turn. If the available source evidence does not support a meaningful backend subsystem, report that honestly instead of selecting frontend work.
Return ONLY JSON: {"candidate_name":"PascalCaseName","source_paths":["project/relative/path.py"],"rationale":"source-evidence-based explanation of why these files form an important reusable subsystem","expected_capabilities":["..."],"external_dependencies":["..."]}. source_paths must be nonempty, unique, exact project-relative paths from the supplied inventory. Include multiple related files when the subsystem actually spans multiple files; do not inflate the boundary artificially. Do not write Swift in this discovery turn.'''


def load_state():
    if STATE.exists():
        try:
            data = json.loads(STATE.read_text(encoding='utf-8'))
            if isinstance(data, dict):
                data.setdefault('modules', [])
                data.setdefault('cycles', [])
                return data
        except Exception:
            pass
    return {'modules': [], 'cycles': []}

def excluded(path: pathlib.Path) -> bool:
    return any(part in EXCLUDE_PARTS for part in path.parts)

def source_inventory():
    """Index source files across the entire HTML project, not only cloud/."""
    files = []
    for path in sorted(SOURCE.rglob('*')):
        if not path.is_file() or path.suffix.lower() not in SOURCE_EXTS:
            continue
        if path.name.endswith('.bundle.js') or path.name.endswith('.min.js'):
            continue
        rel = path.relative_to(SOURCE)
        if excluded(rel) or path.name.startswith('test_') or path.name.endswith('_test.py') or path.name.endswith('.min.js') or path.name.endswith('.bundle.js') or path.name in {'package-lock.json', 'pnpm-lock.json', 'yarn.lock'}:
            continue
        size = path.stat().st_size
        doc = ''
        imports = []
        symbols = []
        suffix = path.suffix.lower()
        try:
            content = path.read_text(encoding='utf-8', errors='replace')
            if suffix == '.py':
                tree = ast.parse(content)
                doc = (ast.get_docstring(tree) or '').splitlines()[0][:180]
                for node in ast.walk(tree):
                    if isinstance(node, ast.Import): imports.extend(n.name for n in node.names)
                    elif isinstance(node, ast.ImportFrom): imports.append('.' * node.level + (node.module or ''))
                symbols = [n.name for n in tree.body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))][:20]
            elif suffix in {'.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx'}:
                import_patterns = (r"from\s+['\"]([^'\"]+)['\"]", r"import\s*\(\s*['\"]([^'\"]+)['\"]\s*\)", r"require\(\s*['\"]([^'\"]+)['\"]\s*\)")
                for pattern in import_patterns:
                    imports.extend(re.findall(pattern, content)[:30])
                symbols = re.findall(r"(?:export\s+)?(?:async\s+)?(?:function|class|const|let|var)\s+([A-Za-z_$][\w$]*)", content)[:20]
                doc = ' '.join(line.strip(' /*#\t') for line in content[:1000].splitlines() if line.strip().startswith(('//', '/*', '*', '#')))[:180]
            elif suffix == '.json':
                parsed = json.loads(content)
                if isinstance(parsed, dict):
                    symbols = [str(k) for k in list(parsed.keys())[:20]]
                    doc = 'JSON object keys: ' + ', '.join(symbols[:12])
                elif isinstance(parsed, list):
                    doc = f'JSON array with {len(parsed)} items'
            else:
                doc = ' '.join(line.strip(' /*#\t') for line in content[:1000].splitlines() if line.strip().startswith(('<!--', '//', '/*', '*', '#')))[:180]
        except Exception:
            pass
        files.append({'path': rel.as_posix(), 'bytes': size, 'directory': rel.parent.as_posix(), 'extension': suffix, 'description': doc, 'imports': sorted(set(imports))[:24], 'symbols': symbols})
    return files

def write_json_atomic(path, value):
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(temp, path)

def write_status(state, current=None, outcome=None):
    lines = ['# Automation Status', '', f"Updated: {time.strftime('%Y-%m-%d %H:%M:%S')}", '']
    if current:
        lines += [f"**Current cycle:** {current.get('state', 'running')}", f"**Subsystem:** `{current.get('subsystem', 'discovering')}`", f"**Chat turns:** {current.get('turns', 0)}", f"**Log:** `{current.get('log', '—')}`", '']
    if outcome: lines += [f'**Latest result:** {outcome}', '']
    modules = state.get('modules', [])
    complete = sum(1 for m in modules if m.get('status') == 'complete' and m.get('candidate_name'))
    legacy = sum(1 for m in modules if not m.get('candidate_name'))
    lines += [f'**Subsystem records:** {len(modules)} ({complete} complete subsystem records; {legacy} historical single-file fragments)', '', '## Recent subsystem results', '']
    if not modules: lines.append('No subsystem has been recorded yet.')
    for m in reversed(modules[-10:]):
        paths = ', '.join(m.get('source_paths', []))
        kind = 'historical fragment' if not m.get('candidate_name') else 'subsystem'
        lines.append(f"- **{m.get('module_name', m.get('candidate_name', 'Unknown'))}** — {kind} / `{m.get('status', 'unknown')}` — {len(m.get('source_paths', []))} source files — `{paths}` — {m.get('summary', m.get('rationale', ''))}")
    lines += ['', '## Recent cycles', '']
    cycles = state.get('cycles', [])
    if not cycles: lines.append('No completed cycles recorded yet.')
    for c in reversed(cycles[-10:]):
        lines.append(f"- {c.get('time', '?')} — **{c.get('module', c.get('candidate', 'no subsystem'))}** — {c.get('status', 'unknown')} — {c.get('turns', 0)} turns")
    lines += ['', '## Where to look', '', '- `PROGRESS.md`: append-only short summaries.', '- `MODULES.json`: subsystem records and cycle history.', '- `.checkpoints/`: durable candidate/turn checkpoints.', '- `logs/`: complete CLI logs.', '- Run `./status.sh` to inspect scheduler and current processes.', '']
    STATUS.write_text('\n'.join(lines), encoding='utf-8')

def cli_call(prompt_text, stamp, turn, conversation_id, timeout):
    # The first turn always creates a fresh chat. Later turns target its exact ID,
    # so activity in another browser tab cannot redirect continuation elsewhere.
    if conversation_id:
        return subprocess.run(
            [str(CLI), 'send', conversation_id, '--output', 'json'],
            input=prompt_text, capture_output=True, text=True, timeout=timeout, env=ENV,
        )
    prompt_file = ROOT / f'.active-prompt-{stamp}-{turn}.txt'
    prompt_file.write_text(prompt_text, encoding='utf-8')
    try:
        return subprocess.run(
            [str(CLI), 'agent', '--prompt-file', str(prompt_file), '--output', 'json', '--max-attempts', '1'],
            capture_output=True, text=True, timeout=timeout, env=ENV,
        )
    finally:
        prompt_file.unlink(missing_ok=True)

def extract_envelope(raw):
    envelope = json.loads(raw)
    messages = envelope.get('messages', [])
    assistant = [m for m in messages if m.get('role') == 'assistant' and isinstance(m.get('text'), str) and m.get('text').strip()]
    if not assistant:
        # Some CLI versions store text only in content parts.
        for m in messages:
            if m.get('role') == 'assistant':
                parts = m.get('parts') or m.get('content', {}).get('parts', []) if isinstance(m.get('content'), dict) else m.get('parts', [])
                text = '\n'.join(x for x in parts if isinstance(x, str))
                if text.strip(): assistant.append({'text': text})
    if not assistant:
        raise ValueError('CLI response contains no assistant text')
    return envelope, assistant[-1]['text']

def parse_json_answer(answer):
    try:
        return json.loads(answer.strip())
    except json.JSONDecodeError:
        match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', answer, re.S)
        if not match: match = re.search(r'\{.*\}', answer, re.S)
        if not match: raise
        return json.loads(match.group(1) if match.lastindex else match.group(0))

def source_bundle(paths, inventory_by_path):
    normalized = []
    for p in paths:
        p = str(p).replace('\\', '/').lstrip('./')
        if p not in inventory_by_path: raise ValueError(f'candidate selected unknown project-relative source path: {p}')
        if p not in normalized: normalized.append(p)
    total = sum((SOURCE / p).stat().st_size for p in normalized)
    if total > MAX_SOURCE_BUNDLE_BYTES:
        raise ValueError(f'candidate source bundle too large ({total} bytes); narrow to one cohesive subsystem under {MAX_SOURCE_BUNDLE_BYTES} bytes')
    sections = []
    for rel in normalized:
        content = (SOURCE / rel).read_text(encoding='utf-8', errors='replace')
        suffix = pathlib.Path(rel).suffix.lower()
        lang = {'.py':'python','.js':'javascript','.mjs':'javascript','.cjs':'javascript','.ts':'typescript','.tsx':'tsx','.jsx':'jsx','.html':'html','.htm':'html','.css':'css','.json':'json'}.get(suffix, 'text')
        sections.append(f'\n--- {rel} ({len(content.encode("utf-8"))} bytes) ---\n```{lang}\n{content}\n```')
    selected = set(normalized)
    metadata = [x for x in inventory_by_path.values() if x['path'] in selected]
    return '\n'.join(sections), metadata

def main():
    LOG_DIR.mkdir(exist_ok=True)
    CHECKPOINT_DIR.mkdir(exist_ok=True)
    with LOCK_FILE.open('a+') as lock:
        try: fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('A subsystem cycle is already running; skipping overlapping launch.', flush=True)
            return 0
        return run_cycle()

def run_cycle():
    stamp = time.strftime('%Y%m%d-%H%M%S')
    started = time.monotonic()
    deadline = started + CYCLE_SECONDS
    log = LOG_DIR / f'{stamp}.log'
    state = load_state()
    inventory = source_inventory()
    if not inventory:
        write_status(state, {'state': 'failed', 'subsystem': 'none', 'log': str(log.relative_to(ROOT))}, 'No source files discovered across SOURCE project root; check SOURCE root and supported file extensions.')
        return 1
    inventory_by_path = {x['path']: x for x in inventory}
    backend_inventory = [x for x in inventory if x['extension'] in BACKEND_EXTS and not (set(pathlib.Path(x['path']).parts) & BACKEND_EXCLUDE_PARTS)]
    backend_paths = {x['path'] for x in backend_inventory}
    if not backend_inventory:
        write_status(state, {'state': 'failed', 'subsystem': 'none', 'log': str(log.relative_to(ROOT))}, 'No eligible backend Python files found; refusing frontend work.')
        return 1
    partials = [m for m in state.get('modules', []) if m.get('status') != 'complete' and m.get('source_paths')]
    incomplete_checkpoints = []
    for checkpoint_path in sorted(CHECKPOINT_DIR.glob('*.json'), reverse=True)[:20]:
        try:
            cp = json.loads(checkpoint_path.read_text(encoding='utf-8'))
            if cp.get('state') not in ('complete', 'partial') and cp.get('source_paths'):
                incomplete_checkpoints.append({k: cp.get(k) for k in ('cycle', 'candidate_name', 'source_paths', 'rationale', 'state', 'summary', 'last_assistant_excerpt')})
        except Exception:
            continue
    compact_backend_inventory = [
        {k: item.get(k) for k in ('path', 'bytes', 'directory', 'description', 'imports', 'symbols')}
        for item in backend_inventory
    ]
    prior_records = [
        {k: m.get(k) for k in ('module_name', 'candidate_name', 'source_paths', 'status', 'summary', 'capabilities', 'files')}
        for m in state.get('modules', [])
    ]
    catalog = {
        'source_root': str(SOURCE),
        'project_scope': 'inventory paths are relative to SOURCE_PROJECT_ROOT',
        'BACKEND_ONLY_ELIGIBLE_SOURCE_PATHS': sorted(backend_paths),
        'backend_source_inventory': compact_backend_inventory,
        'explicitly_forbidden_frontend_paths_and_extensions': ['.html', '.htm', '.css', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx', 'frontend/static/client/templates/views/assets'],
        'existing_subsystem_records': prior_records,
        'prior_partial_records_are_history_not_mandatory_targets': [
            {k: m.get(k) for k in ('candidate_name', 'source_paths', 'status', 'summary')}
            for m in partials
        ],
        'recent_incomplete_checkpoints_as_historical_evidence_not_mandatory_targets': [
            {k: cp.get(k) for k in ('candidate_name', 'source_paths', 'state', 'summary')}
            for cp in incomplete_checkpoints
        ],
        'already_generated_modules': [p.name for p in ROOT.iterdir() if p.is_dir() and not p.name.startswith('.')],
        'selection_goal': 'choose one cohesive backend migration OR evidence-based improvement to an existing Swift subsystem; open-source alternatives may inform the choice; frontend work is forbidden'
    }
    discovery_prompt = DISCOVERY_INSTRUCTIONS + '\n\nSOURCE CATALOG JSON:\n' + json.dumps(catalog, ensure_ascii=False, separators=(',', ':'))
    write_status(state, {'state': 'discovering subsystem', 'subsystem': 'dynamic selection', 'turns': 0, 'log': str(log.relative_to(ROOT))})
    with log.open('w', encoding='utf-8') as out:
        out.write(f'Started {stamp}\nCycle budget: {CYCLE_SECONDS}s\nSource files in inventory: {len(inventory)}\n')
        out.flush()
        try:
            first = cli_call(discovery_prompt, stamp, 0, None, min(120, max(30, int(deadline-time.monotonic()))))
            out.write('\n--- DISCOVERY STDERR ---\n'+first.stderr+'\n--- DISCOVERY STDOUT ---\n'+first.stdout+'\n'); out.flush()
            if first.returncode != 0: raise RuntimeError(f'discovery CLI exit {first.returncode}')
            envelope, answer = extract_envelope(first.stdout)
            choice = parse_json_answer(answer)
            candidate = str(choice.get('candidate_name', '')).strip()
            if not re.fullmatch(r'[A-Za-z][A-Za-z0-9]*', candidate): raise ValueError('discovery returned invalid candidate_name')
            paths = choice.get('source_paths')
            if not isinstance(paths, list) or not paths: raise ValueError('discovery returned empty source_paths')
            invalid_backend_paths = [str(p).replace('\\', '/') for p in paths if str(p).replace('\\', '/') not in backend_paths]
            if invalid_backend_paths: raise ValueError(f'backend-only policy violation; candidate included non-backend paths: {invalid_backend_paths}')
            try:
                bundle, selected_metadata = source_bundle(paths, inventory_by_path)
            except ValueError as bundle_error:
                if 'source bundle too large' not in str(bundle_error):
                    raise
                conversation_id = envelope.get('conversation_id')
                if not isinstance(conversation_id, str) or not conversation_id:
                    raise
                narrow_prompt = ('Your proposed subsystem source bundle is too large for one faithful migration turn: ' + str(bundle_error) + '. In this SAME conversation, choose a narrower but still cohesive, reusable subsystem boundary. Do not select one arbitrary helper file merely to shrink the bundle. Prefer a package or responsibility cluster; include its public entry point and directly-required contracts. Return ONLY the discovery JSON schema with exact source paths from the catalog, and keep the selected source bundle below ' + str(MAX_SOURCE_BUNDLE_BYTES) + ' bytes.')
                narrowed = cli_call(narrow_prompt, stamp, 1, conversation_id, min(90, max(30, int(deadline-time.monotonic()))))
                out.write('\n--- NARROWING STDERR ---\n'+narrowed.stderr+'\n--- NARROWING STDOUT ---\n'+narrowed.stdout+'\n'); out.flush()
                if narrowed.returncode != 0: raise RuntimeError(f'narrowing CLI exit {narrowed.returncode}')
                envelope, answer = extract_envelope(narrowed.stdout)
                choice = parse_json_answer(answer)
                candidate = str(choice.get('candidate_name', '')).strip()
                if not re.fullmatch(r'[A-Za-z][A-Za-z0-9]*', candidate): raise ValueError('narrowed candidate has invalid candidate_name')
                paths = choice.get('source_paths')
                if not isinstance(paths, list) or not paths: raise ValueError('narrowed candidate returned empty source_paths')
                invalid_backend_paths = [str(p).replace('\\', '/') for p in paths if str(p).replace('\\', '/') not in backend_paths]
                if invalid_backend_paths: raise ValueError(f'backend-only policy violation after narrowing: {invalid_backend_paths}')
                bundle, selected_metadata = source_bundle(paths, inventory_by_path)
        except Exception as e:
            out.write('\nDISCOVERY/APPLY ERROR: '+repr(e)+'\n')
            write_status(load_state(), {'state': 'failed during discovery', 'subsystem': 'dynamic selection', 'turns': 1, 'log': str(log.relative_to(ROOT))}, str(e))
            print(f'Subsystem discovery failed: {e}; see {log}', file=sys.stderr)
            return 2

        conversation_id = envelope.get('conversation_id')
        if not isinstance(conversation_id, str) or not conversation_id.strip():
            write_status(load_state(), {'state': 'failed during discovery', 'subsystem': candidate, 'turns': 1, 'log': str(log.relative_to(ROOT))}, 'CLI response omitted conversation_id; cannot guarantee same-chat continuation.')
            print(f'No conversation_id returned for {candidate}; see {log}', file=sys.stderr)
            return 2
        checkpoint = {'cycle': stamp, 'candidate_name': candidate, 'source_paths': [str(p) for p in paths], 'rationale': choice.get('rationale', ''), 'expected_capabilities': choice.get('expected_capabilities', []), 'external_dependencies': choice.get('external_dependencies', []), 'conversation_id': conversation_id, 'turns': 1, 'state': 'selected'}
        write_json_atomic(CHECKPOINT_DIR / f'{stamp}.json', checkpoint)
        selected_set = {str(p).replace('\\', '/') for p in paths}
        existing_fragments = []
        fragment_budget = 12_000
        for record in state.get('modules', []):
            recorded_sources = {str(p).replace('\\', '/') for p in record.get('source_paths', [])}
            if not (recorded_sources & selected_set):
                continue
            for rel_file in record.get('files', []):
                fp = (ROOT / rel_file).resolve()
                if ROOT.resolve() not in fp.parents or not fp.is_file() or fp.suffix not in ('.swift', '.md'):
                    continue
                content = fp.read_text(encoding='utf-8', errors='replace')
                if len(content.encode('utf-8')) > fragment_budget:
                    continue
                existing_fragments.append(f'\n--- EXISTING FRAGMENT {rel_file} ---\n```{ "swift" if fp.suffix == ".swift" else "markdown" }\n{content}\n```')
                fragment_budget -= len(content.encode('utf-8'))
        implementation_prompt = PROMPT_FILE.read_text(encoding='utf-8') + '\n\nDYNAMICALLY SELECTED SUBSYSTEM:\n' + json.dumps(choice, ensure_ascii=False, indent=2) + '\n\nSELECTED SOURCE CONTENTS (complete files):\n' + bundle + '\n\nSOURCE STRUCTURE METADATA:\n' + json.dumps(selected_metadata, ensure_ascii=False, indent=2) + '\n\nEXISTING RELATED SWIFT FRAGMENTS (integrate or reuse where appropriate; do not delete historical outputs):\n' + ('\n'.join(existing_fragments) if existing_fragments else '(No existing Swift fragments map directly to this candidate.)') + '\n\nEXISTING MODULE RECORDS (preserve unrelated records):\n'  + json.dumps(prior_records, ensure_ascii=False, separators=(',', ':')) + '\n\nOUTPUT ROOT: ' + str(ROOT) + '\n'
        implementation_prompt += '\nThis is the first implementation turn of a 15-minute subsystem session. Implement the whole selected subsystem. If you cannot finish in this turn, return a valid JSON payload with status partial and a concrete next_steps list. The next turns will continue this exact chat; do not restart or change subsystem scope.'
        current_payload = None
        merged_files = {}
        direct_written_paths = set()
        direct_mode = False
        turns = 0
        next_prompt = implementation_prompt
        last_raw = ''
        while time.monotonic() < deadline - 25:
            if turns > 0:
                wait_for = TURN_INTERVAL_SECONDS - (time.monotonic() - last_turn_finished)
                if wait_for > 0:
                    time.sleep(min(wait_for, max(0, deadline-time.monotonic()-20)))
                if time.monotonic() >= deadline - 20: break
                next_prompt = ('Continue the SAME selected subsystem in this SAME conversation. Continue implementation and close the largest remaining gaps. Do not start another subsystem. Return the same JSON schema and metadata, but include ONLY new or changed files with complete contents; do not repeat unchanged files. The runner merges files by path across turns. Set status complete only if the merged subsystem is coherent; otherwise partial with concrete next_steps. Do not run tests/builds or git operations.')
            remaining = max(30, int(deadline-time.monotonic()))
            write_status(load_state(), {'state': 'implementing subsystem', 'subsystem': candidate, 'turns': turns+1, 'log': str(log.relative_to(ROOT))})
            try:
                result = cli_call(next_prompt, stamp, turns+1, conversation_id, min(TURN_TIMEOUT_SECONDS, remaining))
                out.write(f'\n--- TURN {turns+1} STDERR ---\n{result.stderr}\n--- TURN {turns+1} STDOUT ---\n{result.stdout}\n'); out.flush()
                if result.returncode != 0:
                    print(f'Turn {turns+1} CLI exit {result.returncode}; preserving checkpoint.', file=sys.stderr)
                    break
                _, answer = extract_envelope(result.stdout)
                last_raw = answer
                try:
                    parsed = parse_json_answer(answer)
                    if isinstance(parsed, dict) and parsed.get('mode') == 'direct_edit' and isinstance(parsed.get('files_written'), list):
                        direct_mode = True
                        for rel in parsed['files_written']:
                            if isinstance(rel, str):
                                direct_written_paths.add(rel)
                        current_payload = dict(parsed)
                        current_payload['files'] = []
                    elif isinstance(parsed, dict) and isinstance(parsed.get('files'), list):
                        direct_mode = False
                        for item in parsed['files']:
                            if isinstance(item, dict) and isinstance(item.get('path'), str) and isinstance(item.get('content'), str):
                                merged_files[item['path']] = item
                        if merged_files:
                            current_payload = dict(parsed)
                            current_payload['files'] = list(merged_files.values())
                except Exception:
                    # Keep the last valid artifact while the conversation continues.
                    pass
                turns += 1
                last_turn_finished = time.monotonic()
                checkpoint.update({'turns': turns+1, 'state': 'in_progress', 'last_assistant_excerpt': answer[-2500:]})
                write_json_atomic(CHECKPOINT_DIR / f'{stamp}.json', checkpoint)
                if current_payload and current_payload.get('status') == 'complete':
                    # Still allow one continuation turn for a subsystem-level completeness review.
                    if turns >= 3:
                        break
                if time.monotonic() >= deadline - 20: break
            except subprocess.TimeoutExpired:
                out.write(f'\nTURN {turns+1} TIMEOUT\n'); out.flush()
                break
            except Exception as e:
                out.write(f'\nTURN {turns+1} ERROR: {e!r}\n'); out.flush()
                break
        if not current_payload:
            checkpoint.update({'state': 'incomplete_no_artifact', 'turns': turns+1})
            write_json_atomic(CHECKPOINT_DIR / f'{stamp}.json', checkpoint)
            state = load_state()
            state.setdefault('cycles', []).append({'time': stamp, 'candidate': candidate, 'module': candidate, 'status': 'failed', 'source_paths': checkpoint['source_paths'], 'turns': turns+1})
            write_json_atomic(STATE, state)
            write_status(state, {'state': 'incomplete', 'subsystem': candidate, 'turns': turns+1, 'log': str(log.relative_to(ROOT))}, 'No valid implementation artifact returned; checkpoint retained for recovery.')
            return 2

        # Validate and safely apply all files in the final artifact.
        try:
            name = str(current_payload.get('module_name', candidate)).strip()
            if not re.fullmatch(r'[A-Za-z][A-Za-z0-9]*', name): raise ValueError('invalid module_name')
            written = []
            if direct_mode:
                for rel in sorted(direct_written_paths):
                    relpath = pathlib.PurePosixPath(rel)
                    if relpath.is_absolute() or '..' in relpath.parts or not relpath.parts: raise ValueError('unsafe direct-edit path')
                    if relpath.suffix not in ('.swift', '.md'): raise ValueError('direct edit may only report Swift and Markdown files')
                    target = (ROOT / pathlib.Path(*relpath.parts)).resolve()
                    if ROOT.resolve() not in target.parents: raise ValueError('direct-edit path escapes output root')
                    if not target.is_file(): raise ValueError(f'AgentDock reported a file that does not exist: {rel}')
                    target.read_text(encoding='utf-8')
                    written.append(relpath.as_posix())
            else:
                for item in current_payload['files']:
                    relpath = pathlib.PurePosixPath(item.get('path', ''))
                    if relpath.is_absolute() or '..' in relpath.parts or not relpath.parts: raise ValueError('unsafe output path')
                    if not isinstance(item.get('content'), str): raise ValueError('file content must be string')
                    if relpath.suffix not in ('.swift', '.md'): raise ValueError('only Swift and Markdown files allowed')
                    target = (ROOT / pathlib.Path(*relpath.parts)).resolve()
                    if ROOT.resolve() not in target.parents: raise ValueError('output path escapes root')
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text(item['content'], encoding='utf-8')
                    written.append(relpath.as_posix())
            if not any(p.endswith('.swift') for p in written) or not any(p.endswith('README.md') for p in written):
                raise ValueError('subsystem must include Swift implementation and README.md')
            status = current_payload.get('status', 'partial')
            if status not in ('complete', 'partial'): status = 'partial'
            source_paths = current_payload.get('source_paths') or checkpoint['source_paths']
            record = {'module_name': name, 'candidate_name': candidate, 'source_paths': source_paths, 'status': status, 'summary': current_payload.get('summary', choice.get('rationale', '')), 'next_steps': current_payload.get('next_steps', []), 'capabilities': current_payload.get('capabilities', choice.get('expected_capabilities', [])), 'files': written, 'last_updated': stamp, 'conversation_id': envelope.get('conversation_id'), 'turns': turns+1, 'log': str(log.relative_to(ROOT))}
            state = load_state()
            old_modules = state.get('modules', [])
            state['modules'] = [m for m in old_modules if m.get('module_name') != name and not (m.get('candidate_name') == candidate and m.get('status') != 'complete')] + [record]
            state.setdefault('cycles', []).append({'time': stamp, 'candidate': candidate, 'module': name, 'status': status, 'source_paths': source_paths, 'files': written, 'turns': turns+1})
            write_json_atomic(STATE, state)
            with (ROOT / 'PROGRESS.md').open('a', encoding='utf-8') as f:
                f.write(f"\n- {stamp}: **{name}** — {status} — subsystem `{candidate}` — {len(source_paths)} source files — {turns+1} turns — files: {', '.join(written)}\n")
            checkpoint.update({'state': status, 'module_name': name, 'files': written, 'turns': turns+1, 'summary': record['summary']})
            write_json_atomic(CHECKPOINT_DIR / f'{stamp}.json', checkpoint)
            write_status(state, {'state': 'completed' if status == 'complete' else 'partial', 'subsystem': candidate, 'turns': turns+1, 'log': str(log.relative_to(ROOT))}, f"{name} — {status} — {record['summary']}")
            print(f"{name}: {status}; subsystem={candidate}; source_files={len(source_paths)}; turns={turns+1}", flush=True)
            return 0 if status == 'complete' else 3
        except Exception as e:
            out.write('\nAPPLY ERROR: '+repr(e)+'\n'); out.flush()
            checkpoint.update({'state': 'apply_error', 'error': repr(e), 'turns': turns+1})
            write_json_atomic(CHECKPOINT_DIR / f'{stamp}.json', checkpoint)
            write_status(load_state(), {'state': 'failed applying artifact', 'subsystem': candidate, 'turns': turns+1, 'log': str(log.relative_to(ROOT))}, str(e))
            print(f'Could not apply subsystem artifact: {e}; see {log}', file=sys.stderr)
            return 2

if __name__ == '__main__':
    raise SystemExit(main())
