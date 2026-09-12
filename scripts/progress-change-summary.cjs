'use strict';
// Curated labels preserve useful project activity without exposing commit subjects.
const outcomes = {
  '14cd1f71': 'Record dashboard test results and independent QA evidence',
  'f7f433f9': 'Add reliable refresh, quota reset times and mobile dashboard layout',
  '3fb2e8a6': 'Save the first development-progress snapshot',
  '0a5f8aeb': 'Add the progress dashboard and links from the website',
  '567625e6': 'Save the draft notification-navigation policy for integration',
  '5f0f48ec': 'Expand engineer-state and role-screen contrast regression checks',
  '8749ff71': 'Integrate the helper handoffs and workflow review documents',
  'a9b35f3c': 'Record engineer-state tests and helper milestone evidence',
  '311643de': 'Document accessibility issues across login and profile screens',
  '8955046f': 'Add notification parsing tests for edge cases',
  '16b405b8': 'Isolate engineer verification status across account changes',
  '0d4269ea': 'Save the navigation, account ownership and UX review handoff',
  '6297d056': 'Plan secure navigation and hospital/engineer workflows'
};
module.exports = function summarizeFiles(files, sha = '') {
  if (Object.hasOwn(outcomes, sha.slice(0,8))) return outcomes[sha.slice(0,8)];
  const scopes = [];
  if (files.some(file => /^app\/src\/main\//.test(file))) scopes.push('Android implementation');
  if (files.some(file => /^app\/src\/(?:test|androidTest)\//.test(file))) scopes.push('Android regression tests');
  if (files.some(file => /^website\//.test(file))) scopes.push('Website and dashboard');
  if (files.some(file => /^docs\//.test(file))) scopes.push('Project handoff and review');
  if (files.some(file => /^(?:scripts|\.github)\//.test(file))) scopes.push('Verification and delivery tooling');
  return scopes.length ? scopes.join(' · ') + ' updated; outcome review pending' : 'Project checkpoint; outcome review pending';
};
