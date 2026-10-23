import { dirname, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
export const base = '/Pi-Bolt.nix';

// Keep repository headings and .md links readable on GitHub; adapt only the rendered site.
export function repositoryMarkdown() {
  return (tree, file) => {
    if (tree.children[0]?.type === 'heading' && tree.children[0].depth === 1) {
      tree.children.shift();
    }
    function visit(node) {
      if ((node.type === 'link' || node.type === 'definition') && !/^(?:[a-z]+:|\/|#)/i.test(node.url)) {
        const [path, fragment] = node.url.split('#');
        if (path.endsWith('.md')) {
          const target = relative(root, resolve(dirname(file.path), decodeURIComponent(path)));
          if (target.startsWith('..')) throw new Error(`Documentation link leaves docs/: ${node.url}`);
          const slug = target.replace(/\.md$/, '').replace(/(^|\/)index$/, '').toLowerCase();
          node.url = `${base}/${slug}${slug && !slug.endsWith('/') ? '/' : ''}${fragment ? `#${fragment}` : ''}`;
        }
      }
      for (const child of node.children ?? []) visit(child);
    }
    visit(tree);
  };
}
