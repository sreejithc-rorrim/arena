import { Component, output } from '@angular/core';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { TermsSettings } from './terms-settings';

/** Settings › Staff: the staff terms everyone but owners accepts on the floor app. */
@Component({
  selector: 'app-staff-settings',
  imports: [DetailPane, TermsSettings],
  template: `
    <app-detail-pane
      crumb="Settings / Staff"
      icon="badge"
      heading="Staff"
      subtitle="The terms your team accepts on the floor app"
      (closed)="closed.emit()"
    >
      <app-terms-settings />
    </app-detail-pane>
  `,
})
export class StaffSettings {
  readonly closed = output<void>();
}
