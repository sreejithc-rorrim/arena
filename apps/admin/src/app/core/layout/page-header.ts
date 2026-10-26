import { Component, input } from '@angular/core';

/**
 * The 64px page top bar from the design: page title and any projected actions on the right
 * (navigation is the side nav or, when compact, the shell's bottom bar).
 */
@Component({
  selector: 'app-page-header',
  host: {
    class:
      'sticky top-0 z-20 flex h-topbar flex-none items-center gap-2 border-b border-border bg-bg pr-4 pl-5',
  },
  template: `
    <h1 class="min-w-0 flex-1 truncate text-xl leading-[1.2] font-semibold">{{ title() }}</h1>
    <ng-content />
  `,
})
export class PageHeader {
  readonly title = input.required<string>();
}
