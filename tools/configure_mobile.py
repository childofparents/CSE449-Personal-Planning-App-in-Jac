"""Apply reproducible Cadence metadata/dependencies after `jac setup mobile`."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
rn = root / '.jac/mobile-rn'
if not (rn / 'package.json').exists():
    raise SystemExit('Run jac setup mobile first.')
package = json.loads((rn / 'package.json').read_text())
package['name'] = 'cadence-mobile'
package.setdefault('dependencies', {})['luxon'] = '3.7.2'
(rn / 'package.json').write_text(json.dumps(package, indent=2) + '\n')
config = json.loads((rn / 'app.json').read_text())
expo = config['expo']
expo.update(name='Cadence', slug='cadence-planner', userInterfaceStyle='light')
expo.setdefault('ios', {})['bundleIdentifier'] = 'edu.umich.beinilan.cadence'
expo.setdefault('android', {})['package'] = 'edu.umich.beinilan.cadence'
(rn / 'app.json').write_text(json.dumps(config, indent=2) + '\n')
print('Configured Cadence. Run jac setup mobile again to install dependencies, then jac run --dev mobile.')
