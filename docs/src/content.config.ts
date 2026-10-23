import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsSchema, i18nSchema } from '@astrojs/starlight/schema';

export const collections = {
  i18n: defineCollection({ loader: async () => [{ id: 'en' }], schema: i18nSchema() }),
  docs: defineCollection({
    loader: glob({
      base: '.',
      pattern: ['index.md', 'getting-started.md', '404.md', 'guides/**/*.md', 'reference/**/*.md', 'architecture/**/*.md', 'contributing/**/*.md', 'PLUGINS.md', 'RELEASES.md', 'MAINTAINING.md'],
    }),
    schema: docsSchema(),
  }),
};
