'use strict';
// Curated labels preserve useful project activity without exposing commit subjects.
module.exports = function summarizeFiles(files) {
  const scopes = [];
  if (files.some(file => /^app\/src\/main\//.test(file))) scopes.push('Android implementation');
  if (files.some(file => /^app\/src\/(?:test|androidTest)\//.test(file))) scopes.push('Android regression tests');
  if (files.some(file => /^website\//.test(file))) scopes.push('Website and dashboard');
  if (files.some(file => /^docs\//.test(file))) scopes.push('Project handoff and review');
  if (files.some(file => /^(?:scripts|\.github)\//.test(file))) scopes.push('Verification and delivery tooling');
  return scopes.length ? scopes.join(' · ') : 'Project checkpoint';
};
