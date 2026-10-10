import tempfile
import unittest
from pathlib import Path
from tools.validate_finisher_assets import validate


class FinisherAssetTests(unittest.TestCase):
    def test_stubs_skip_missing_assets(self):
        self.assertEqual([], validate(Path('.'), {'finishers': {'bennet': {'implemented': False, 'events': [{'asset': 'missing.png'}]}}, 'celebrations': {}}))

    def test_implemented_missing_and_escaping_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for asset in ['res://assets/finishers/bennet/props/missing.png', 'res://../outside.png', 'missing.png']:
                data = {'finishers': {'bennet': {'implemented': True, 'celebration_id': 'win', 'events': [{'type': 'spawn_prop', 'asset': asset}]}}, 'celebrations': {'win': {'implemented': True, 'events': []}}}
                self.assertTrue(validate(root, data), asset)

    def test_valid_resources_and_separate_celebration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'assets/finishers/bennet/props/laptop.png'
            path.parent.mkdir(parents=True)
            path.write_bytes(b'fixture')
            data = {'finishers': {'bennet': {'implemented': True, 'celebration_id': 'win', 'events': [{'type': 'spawn_prop', 'asset': 'res://assets/finishers/bennet/props/laptop.png'}]}}, 'celebrations': {'win': {'implemented': True, 'events': []}}}
            self.assertEqual([], validate(root, data))
            data['celebrations']['win']['events'] = [{'type': 'sound', 'asset': 'res://missing.wav'}]
            self.assertTrue(validate(root, data))

    def test_wrong_types_produce_errors(self):
        for data in [[], {}, {'finishers': [], 'celebrations': {}}, {'finishers': {'bennet': {'implemented': 'true'}}, 'celebrations': {}}]:
            self.assertTrue(validate(Path('.'), data))
