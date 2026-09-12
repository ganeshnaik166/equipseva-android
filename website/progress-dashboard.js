(function (root) {
  'use strict';
  const states = {
    implemented: 'Implemented', verification: 'Verification pending',
    in_progress: 'In progress', planned: 'Planned', paused: 'Paused',
    complete: 'Review complete', active: 'Working at capture', unknown: 'Not observed'
  };
  const isText = value => typeof value === 'string';
  const isDate = value => isText(value) && Number.isFinite(Date.parse(value));
  const isPercent = value => typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 100;
  const isCount = value => Number.isSafeInteger(value) && value >= 0;
  const nonblank=value=>isText(value)&&Boolean(value.trim());
  const score=value=>typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=10;
  const criticalKeys=['correctness','security','integrity','accessibility'];
  const provenance=evidence=>evidence&&nonblank(evidence.reviewer)&&nonblank(evidence.reference)&&isDate(evidence.reviewedAt);
  function validate(data) {
    if (!data || data.schemaVersion !== 3 || !isDate(data.generatedAt) ||
        !data.source || !['branch', 'head', 'base'].every(key => isText(data.source[key])) ||
        !isCount(data.source.commits) || !data.focus || !isText(data.focus.title) || !isText(data.focus.detail)) {
      throw new Error('Snapshot header is invalid');
    }
    const major=data.majorMilestone;
    if (!major || major.major !== true || !isText(major.id) || !major.id.trim() || !isText(major.title) ||
        !isCount(major.sequence) || major.sequence < 1 || !isDate(major.recordedAt)) throw new Error('Major milestone is invalid');
    if (!Array.isArray(data.headquarters) || data.headquarters.length !== 9 || new Set(data.headquarters.map(item=>item?.id)).size !== 9 ||
        !data.headquarters.every(item=>item && ['center','hospital','engineer','admin','login','security','qa','plan','main'].includes(item.id) &&
        ['name','status','description','work','next','evidence'].every(key=>isText(item[key])))) throw new Error('Headquarters are invalid');
    const release=data.release;
    const sha=value=>isText(value)&&/^[a-f0-9]{40}$/.test(value);
    if (!release || !isText(release.scope)) throw new Error('Release scope is invalid');
    if (release.candidate!==null && (!release.candidate || release.candidate.scope!==release.scope || !sha(release.candidate.sha) || !sha(release.candidate.tree))) throw new Error('Candidate is invalid');
    for (const name of ['security','qa','critic']) {
      const evidence=release[name];
      if (evidence!==null && (!provenance(evidence) || !isText(evidence.scope) || !sha(evidence.tree) || typeof evidence.requiredChecksPassed!=='boolean' || !isCount(evidence.openBlockers) ||
          (name!=='security' && (!score(evidence.score) || !criticalKeys.every(key=>score(evidence.criticalDimensions?.[key])))))) throw new Error('Review evidence is invalid');
    }
    if (release.mainObservation!==null && (!release.mainObservation || !sha(release.mainObservation.candidateSha) || !sha(release.mainObservation.remoteMainSha) || !nonblank(release.mainObservation.reference) || typeof release.mainObservation.containsCandidate!=='boolean' || !isDate(release.mainObservation.observedAt))) throw new Error('Main observation is invalid');
    for (const key of ['milestones', 'agents', 'changes', 'verification']) {
      if (!Array.isArray(data[key]) || data[key].length > 100) throw new Error('Snapshot list is invalid');
    }
    for (const item of data.milestones) {
      if (!item || !['id', 'name', 'notes', 'owner'].every(key => isText(item[key])) ||
          typeof item.implementationComplete !== 'boolean' ||
          !['implemented', 'verification', 'in_progress', 'planned', 'paused'].includes(item.status)) throw new Error('Milestone is invalid');
    }
    if (!isDate(data.agentsObservedAt)) throw new Error('Agent capture time is invalid');
    for (const item of data.agents) {
      if (!item || !isText(item.name) || !isText(item.focus) || !Object.hasOwn(states, item.status)) throw new Error('Agent is invalid');
    }
    for (const item of data.changes) {
      if (!item || !isText(item.sha) || !isText(item.summary) || !isDate(item.time)) throw new Error('Change is invalid');
    }
    for (const item of data.verification) {
      if (!item || !['title', 'revision', 'command', 'note', 'evidence'].every(key => isText(item[key])) ||
          !(item.tests === null || isCount(item.tests)) || !(item.failures === null || isCount(item.failures))) throw new Error('Evidence is invalid');
    }
    if (!data.usage || !isDate(data.usage.observedAt) || !Array.isArray(data.usage.windows) || data.usage.windows.length > 20) throw new Error('Usage is invalid');
    for (const item of data.usage.windows) {
      if (!item || !isText(item.name) || !isCount(item.minutes) || item.minutes === 0 ||
          !(item.usedPercent === null || isPercent(item.usedPercent)) ||
          !(item.resetsAt === null || isDate(item.resetsAt))) throw new Error('Usage window is invalid');
    }
    return data;
  }
  function nextMilestone(current, incoming) {
    validate(incoming);
    if (!current) return incoming;
    if (incoming.majorMilestone.id === current.majorMilestone.id || incoming.majorMilestone.sequence <= current.majorMilestone.sequence) return current;
    if (Date.parse(incoming.majorMilestone.recordedAt) < Date.parse(current.majorMilestone.recordedAt)) throw new Error('Milestone timestamp moved backwards');
    return incoming;
  }
  function freezeRecord(value) {
    if (value && typeof value === 'object' && !Object.isFrozen(value)) {
      Object.values(value).forEach(freezeRecord); Object.freeze(value);
    }
    return value;
  }
  function releaseReadiness(release) {
    const candidate=release?.candidate;
    const validCandidate=release?.scope==='android-renewal' && candidate && candidate.scope===release.scope && /^[a-f0-9]{40}$/.test(candidate.tree??'') && /^[a-f0-9]{40}$/.test(candidate.sha??'');
    const matches=evidence=>validCandidate && provenance(evidence) && evidence.scope===candidate.scope && evidence.tree===candidate.tree && evidence.requiredChecksPassed===true && evidence.openBlockers===0;
    const reviewPassed=evidence=>matches(evidence)&&score(evidence.score)&&evidence.score>=9.5&&criticalKeys.every(key=>score(evidence.criticalDimensions?.[key])&&evidence.criticalDimensions[key]>=9.5);
    const security=Boolean(matches(release?.security));
    const qa=Boolean(reviewPassed(release?.qa));
    const critic=Boolean(reviewPassed(release?.critic));
    const independentReviews=qa&&critic&&release.qa.reviewer.trim().toLowerCase()!==release.critic.reviewer.trim().toLowerCase();
    const ready=Boolean(security&&independentReviews);
    const integrated=Boolean(ready && release?.mainObservation?.candidateSha===candidate.sha && /^[a-f0-9]{40}$/.test(release.mainObservation.remoteMainSha??'') && nonblank(release.mainObservation.reference) && release.mainObservation.containsCandidate===true && isDate(release.mainObservation.observedAt));
    return {security,qa,critic,ready,integrated};
  }
  function duration(minutes) {
    if (minutes % 1440 === 0) return (minutes / 1440) + '-day';
    if (minutes % 60 === 0) return (minutes / 60) + '-hour';
    return minutes + '-minute';
  }
  function usageView(item, now = Date.now()) {
    const expired = item.resetsAt !== null && Date.parse(item.resetsAt) <= now;
    const available = isPercent(item.usedPercent) && !expired;
    return { expired, available, remaining: available ? 100 - item.usedPercent : null };
  }
  const api = { validate, duration, usageView, nextMilestone, freezeRecord, releaseReadiness };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (!root.document) return;
  const doc = root.document;
  const get = id => doc.getElementById(id);
  const node = (tag, text, className) => {
    const element = doc.createElement(tag);
    if (text !== undefined) element.textContent = String(text);
    if (className) element.className = className;
    return element;
  };
  const localTime = value => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
  function render(data) {
    const implemented = data.milestones.filter(item => item.implementationComplete).length;
    get('slices').textContent = implemented + ' / ' + data.milestones.length;
    get('slice-note').textContent = data.milestones.length ? Math.round(implemented / data.milestones.length * 100) + '% of the listed slices. Not whole-app completion.' : 'No slices recorded.';
    get('commits').textContent = String(data.source.commits);
    get('commit-note').textContent = 'Since checkpoint ' + data.source.base.slice(0, 8) + '.';
    get('focus-title').textContent = data.focus.title;
    get('focus-detail').textContent = data.focus.detail;
    get('milestones').replaceChildren(...data.milestones.map(item => {
      const article = node('article', undefined, 'milestone');
      const row = node('div', undefined, 'row');
      row.append(node('h3', item.id + ' · ' + item.name), node('span', states[item.status], 'tag ' + (item.status === 'implemented' ? 'complete' : 'pending')));
      article.append(row, node('p', item.notes), node('p', 'Owner: ' + item.owner, 'caption'));
      return article;
    }));
    get('usage-observed').textContent = 'Captured ' + localTime(data.usage.observedAt) + '. Refreshing this page does not recapture quotas.';
    get('usage').replaceChildren(...data.usage.windows.map(item => {
      const article = node('article', undefined, 'usage-item');
      const state = usageView(item);
      article.append(node('h3', item.name + ' · ' + duration(item.minutes)), node('strong', state.available ? state.remaining + '% remaining' : 'Unavailable'));
      if (state.available) {
        const progress = node('progress');
        progress.max = 100;
        progress.value = item.usedPercent;
        progress.setAttribute('aria-label', item.name + ' ' + duration(item.minutes) + ': ' + item.usedPercent + '% used');
        article.append(progress, node('p', item.usedPercent + '% used at capture'));
      }
      article.append(node('p', state.expired ? 'This window ended. A new account snapshot is needed.' : item.resetsAt ? 'Resets ' + localTime(item.resetsAt) : 'Reset time unavailable.'));
      return article;
    }));
    if (!data.usage.windows.length) get('usage').append(node('p', 'No account usage snapshot available.'));
    get('agents-observed').textContent='Captured '+localTime(data.agentsObservedAt)+'. Robot loops do not refresh agent observations.';
    get('agents').replaceChildren(...data.agents.map(item => {
      const article = node('article', undefined, 'agent');
      article.append(node('h3', item.name), node('p', states[item.status], 'caption'), node('p', item.focus));
      return article;
    }));
    if (!data.agents.length) get('agents').append(node('p', 'No agent observation captured.'));
    get('verification').replaceChildren(...data.verification.map(item => {
      const article = node('article', undefined, 'card');
      article.append(node('h3', item.title), node('p', item.tests === null ? 'Verification pending' : item.tests + ' tests · ' + (item.failures === null ? 'failures not recorded' : item.failures + ' failures')),
        node('code', 'Revision: ' + item.revision), node('code', item.command), node('p', item.note), node('p', 'Evidence: ' + item.evidence, 'caption'));
      return article;
    }));
    get('changes').replaceChildren(...data.changes.map(item => {
      const li = node('li');
      const detail = node('div');
      detail.append(node('p', item.summary), node('span', localTime(item.time), 'caption'));
      li.append(detail, node('span', item.sha.slice(0, 8), 'sha'));
      return li;
    }));
    get('source').textContent = 'Development branch: ' + data.source.branch + ' · Snapshot source: ' + data.source.head + ' · Base: ' + data.source.base + '. Verification above is historical unless explicitly tied to this revision.';
    get('dashboard').hidden = false;
  }
  let lastGood = null;
  root.EquipSevaDashboard={...api,getSnapshot:()=>lastGood};
  let busy = false;
  async function refresh() {
    if (busy) return;
    busy = true;
    get('refresh').disabled = true;
    const controller = new AbortController();
    const timeout = root.setTimeout(() => controller.abort(), 10000);
    try {
      const response = await root.fetch('/progress-dashboard-data.json', { cache: 'no-store', signal: controller.signal });
      if (!response.ok) throw new Error('Snapshot unavailable');
      const data = freezeRecord(nextMilestone(lastGood, await response.json()));
      const changed=data!==lastGood;
      render(data);
      lastGood = data;
      get('load-status').textContent = 'Major milestone '+data.majorMilestone.id+' · '+localTime(data.majorMilestone.recordedAt);
      get('load-status').parentElement.classList.remove('stale');
      if (changed && typeof root.dispatchEvent==='function') root.dispatchEvent(new root.CustomEvent('equipseva:milestone',{detail:data}));
    } catch (_) {
      // Recalculate expired quota windows even when the next fetch fails.
      if (lastGood) render(lastGood);
      get('load-status').textContent = lastGood ? 'Update unavailable. Showing snapshot from ' + localTime(lastGood.generatedAt) + '. Retry with Refresh snapshot.' : 'Snapshot unavailable. Check your connection, then choose Refresh snapshot. No metrics have been assumed.';
      get('load-status').parentElement.classList.add('stale');
    } finally {
      root.clearTimeout(timeout);
      busy = false;
      get('refresh').disabled = false;
    }
  }
  get('refresh').addEventListener('click', refresh);
  const motionButton = get('motion-toggle');
  const motion = root.matchMedia('(prefers-reduced-motion: reduce)');
  function syncMotionPreference() {
    motionButton.hidden = motion.matches;
  }
  syncMotionPreference();
  motion.addEventListener('change', syncMotionPreference);
  motionButton.addEventListener('click', () => {
    const paused = doc.body.classList.toggle('motion-paused');
    motionButton.setAttribute('aria-pressed', String(paused));
    motionButton.textContent = paused ? 'Resume illustration' : 'Pause illustration';
  });
  root.setInterval(() => { if (!doc.hidden) refresh(); }, 60000);
  doc.addEventListener('visibilitychange', () => { if (!doc.hidden) refresh(); });
  refresh();
})(typeof window === 'undefined' ? globalThis : window);
