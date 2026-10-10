"""Validate referenced resources for implemented finishers without modifying art."""
from __future__ import annotations
import json
from pathlib import Path
import sys


def validate(root: Path, data: dict) -> list[str]:
    errors = []
    if not isinstance(data, dict) or not isinstance(data.get('finishers'), dict) or not isinstance(data.get('celebrations'), dict):
        return ['Catalog finishers and celebrations must be objects']
    root = root.resolve()
    for collection in ('finishers', 'celebrations'):
        for identifier, definition in data[collection].items():
            label = f'{collection}/{identifier}'
            if not isinstance(definition, dict) or type(definition.get('implemented')) is not bool:
                errors.append(f'{label}: implemented must be boolean')
                continue
            if not definition['implemented']:
                continue
            if collection == 'finishers':
                link = definition.get('celebration_id')
                if not isinstance(link, str) or link not in data['celebrations']:
                    errors.append(f'{label}: missing celebration link')
                elif not isinstance(data['celebrations'][link], dict) or data['celebrations'][link].get('implemented') is not True:
                    errors.append(f'{label}: linked celebration is not implemented')
            events = definition.get('events')
            if not isinstance(events, list):
                errors.append(f'{label}: events must be an array')
                continue
            for index, event in enumerate(events):
                if not isinstance(event, dict):
                    errors.append(f'{label}[{index}]: event must be an object')
                    continue
                if 'asset' not in event and event.get('type') not in ('spawn_actor', 'spawn_prop', 'sound'):
                    continue
                asset = event.get('asset')
                if not isinstance(asset, str) or not asset.startswith('res://'):
                    errors.append(f'{label}[{index}]: asset must be a res:// path')
                    continue
                path = (root / asset[6:]).resolve()
                if not path.is_relative_to(root) or not path.is_file():
                    errors.append(f'{label}[{index}]: missing or escaping resource {asset}')
    return errors


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    try:
        errors = validate(root, json.loads((root / 'data/finishers.json').read_text(encoding='utf-8-sig')))
    except (OSError, ValueError) as exc:
        errors = [str(exc)]
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print('Finisher asset references valid (planned stubs skipped)')
    raise SystemExit(bool(errors))
