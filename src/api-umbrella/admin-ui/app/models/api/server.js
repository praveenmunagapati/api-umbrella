import Ember from 'ember';
import DS from 'ember-data';
import I18n from 'npm:i18n-js';
import { validator, buildValidations } from 'ember-cp-validations';

const Validations = buildValidations({
  host: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  port: [
    validator('presence', true),
    validator('number', { allowString: true }),
  ],
});

export default DS.Model.extend(Validations, {
  host: DS.attr(),
  port: DS.attr('number'),

  hostWithPort: Ember.computed('host', 'port', function() {
    return _.compact([this.get('host'), this.get('port')]).join(':');
  }),
}).reopenClass({
  validationClass: Validations,
});
