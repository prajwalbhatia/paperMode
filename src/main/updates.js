const { version, paperModeReleaseTag } = require('../../package.json');
const comparisonTag = paperModeReleaseTag || `v${version}`;

const RELEASES_API = 'https://api.github.com/repos/prajwalbhatia/paperMode/releases?per_page=30';
const RELEASES_PAGE = 'https://github.com/prajwalbhatia/paperMode/releases';
const TAG_PATTERN = /^v(\d+)\.(\d+)\.(\d+)(?:-preview\.(\d+))?$/;

function parseTag(tag) {
  const match = TAG_PATTERN.exec(tag);
  if (!match) return null;
  return { numbers: match.slice(1, 4).map(Number), preview: match[4] === undefined ? null : Number(match[4]) };
}

function compareTags(left, right) {
  const a = parseTag(left), b = parseTag(right);
  if (!a || !b) throw new Error('Unsupported PaperMode release tag');
  for (let i = 0; i < 3; i++) {
    if (a.numbers[i] !== b.numbers[i]) return Math.sign(a.numbers[i] - b.numbers[i]);
  }
  if (a.preview === null || b.preview === null) return a.preview === b.preview ? 0 : a.preview === null ? 1 : -1;
  return Math.sign(a.preview - b.preview);
}

function newestRelease(releases, currentTag = comparisonTag) {
  if (!parseTag(currentTag) || !Array.isArray(releases)) throw new Error('Invalid release information');
  return releases.filter(release => release && !release.draft && parseTag(release.tag_name) &&
    compareTags(release.tag_name, currentTag) > 0)
    .sort((a, b) => compareTags(b.tag_name, a.tag_name))[0] || null;
}

async function checkForUpdates({ request = fetch, currentTag = comparisonTag } = {}) {
  const response = await request(RELEASES_API, {
    headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'PaperMode' },
    signal: AbortSignal.timeout(8000), redirect: 'error'
  });
  if (!response.ok) throw new Error('GitHub release check failed');
  const release = newestRelease(await response.json(), currentTag);
  return release ? {
    tag: release.tag_name,
    notes: typeof release.body === 'string' ? release.body.trim().slice(0, 1200) : '',
    url: `${RELEASES_PAGE}/tag/${encodeURIComponent(release.tag_name)}`
  } : null;
}

module.exports = { checkForUpdates, compareTags, newestRelease, parseTag, RELEASES_PAGE };
