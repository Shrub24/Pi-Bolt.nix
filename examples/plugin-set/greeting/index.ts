import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import yaml from 'yaml';

export default function greeting(pi: ExtensionAPI) {
  pi.registerCommand('greet', {
    description: 'Show a YAML greeting',
    handler: async (_args, ctx) => {
      ctx.ui.notify(yaml.stringify({ greeting: 'Hello from a compiled plugin' }), 'info');
    },
  });
}
