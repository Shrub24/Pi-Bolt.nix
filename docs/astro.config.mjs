import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { unified } from '@astrojs/markdown-remark';
import { base, repositoryMarkdown } from './markdown.mjs';

export default defineConfig({
  site: 'https://shrub24.github.io',
  base,
  markdown: { processor: unified({ remarkPlugins: [repositoryMarkdown] }) },
  integrations: [
    starlight({
      title: 'Pi-Bolt.nix',
      description: 'Pi-Bolt and compiled Pi extensions, configured with Nix.',
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/Shrub24/Pi-Bolt.nix' }],
      markdown: { processedDirs: ['.'] },
      sidebar: [
        { slug: 'index' },
        { label: 'Getting started', items: [{ slug: 'getting-started' }] },
        { label: 'Guides', items: ['guides/plugins', 'guides/dependencies', 'guides/settings', 'guides/launchers', 'guides/sources'] },
        { label: 'Reference', items: ['reference/package', 'reference/plugin-builder', 'reference/selection', 'reference/plugin-lock'] },
        { label: 'Architecture', items: ['architecture/build-and-resolution'] },
        { label: 'Contributing', items: ['contributing/development', 'contributing/documentation', 'contributing/releases'] },
      ],
    }),
  ],
});
