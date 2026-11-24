import {test, expect, APIRequestContext} from '@playwright/test';
import fs from 'node:fs';

// Read-only checks against the explicitly seeded local CV demo accounts.
// APPLICATION_SUGGESTIONS_API=1 API_BASE_URL=http://localhost:4000
test.skip(process.env.APPLICATION_SUGGESTIONS_API !== '1', 'Requires the local Docker CV demo.');
test.describe.configure({mode: 'serial'});

const apiUrl = process.env.API_BASE_URL ?? 'http://localhost:4000';
const leaders: Record<string, string> = {
  backend: 'Elixir Backend Engineer [CV Demo]',
  frontend: 'React Frontend Developer [CV Demo]',
  design: 'Product Designer [CV Demo]',
  data: 'Data Analyst [CV Demo]',
  finance: 'Financial Accountant [CV Demo]',
  hospitality: 'Cafe Barista [CV Demo]',
};
const tokens: Record<string, string> = {};
const cvIds: Record<string, string> = {};
let request: APIRequestContext;
const courseFixturePath = process.env.APPLICATION_SUGGESTIONS_COURSE_FIXTURE;
const courseFixture = courseFixturePath ? JSON.parse(fs.readFileSync(courseFixturePath, 'utf8')) : null;

test.beforeAll(async ({playwright}) => {
  expect(['localhost', '127.0.0.1']).toContain(new URL(apiUrl).hostname);
  request = await playwright.request.newContext({baseURL: apiUrl});
  for (const role of [...Object.keys(leaders), 'employer']) {
    const response = await request.post('/api/auth/login', {data: {
      email: `${role}@cv-demo.josjob.test`, password: 'JosJobDemo123!',
    }});
    expect(response.status(), `demo login: ${role}`).toBe(200);
    tokens[role] = (await response.json()).token;
  }
});
test.afterAll(async () => { await request?.dispose(); });

async function get(role: string | null, path: string, status = 200) {
  const response = await request.get(path, {
    headers: role ? {authorization: `Bearer ${tokens[role]}`} : {},
  });
  expect(response.status(), `GET ${path}`).toBe(status);
  return response.json();
}

test('suggestions require authentication and reject unknown listings', async () => {
  const page = await get(null, '/api/jobs?q=CV%20Demo&page_size=50');
  expect(page.data.length).toBe(20);
  await get(null, `/api/jobs/${page.data[0].id}/application-suggestions`, 401);
  await get('backend', '/api/jobs/not-a-uuid/application-suggestions', 404);
});

for (const [role, leader] of Object.entries(leaders)) {
  test(`${role}: exact skill match and advisory gaps use its own saved CV`, async () => {
    const page = await get(role, '/api/jobs?q=CV%20Demo&sort=relevance&page_size=50');
    expect(page.data.length).toBe(20);
    cvIds[role] = page.meta.cv_id;
    const full = page.data.find((job: any) => job.title === leader);
    expect(full).toBeTruthy();
    const match = (await get(role, `/api/jobs/${full.id}/application-suggestions`)).data;
    expect(match.status).toBe('matched');
    expect(match.source).toBe('analyzed_cv');
    expect(match.missing_skills).toEqual([]);
    expect(match.courses).toEqual([]);
    expect([...match.matched_skills].sort()).toEqual([...full.requirements].sort());

    const other = page.data.find((job: any) => job.relevance?.relevance_label === 'Less relevant');
    expect(other).toBeTruthy();
    const gap = (await get(role, `/api/jobs/${other.id}/application-suggestions`)).data;
    expect(gap.status).toBe('gap');
    expect(gap.missing_skills.length).toBeGreaterThan(0);
    expect([...gap.matched_skills, ...gap.missing_skills].sort()).toEqual([...other.requirements].sort());
    for (const course of gap.courses) {
      expect(course.matched_skills.length).toBeGreaterThan(0);
      for (const skill of course.matched_skills) expect(gap.missing_skills).toContain(skill);
      const detail = (await get(role, `/api/catalog/courses/${course.id}`)).data;
      expect(course.class_count).toBe(detail.classes.length);
      if (course.class_id) expect(detail.classes.map((c: any) => c.id)).toContain(course.class_id);
    }
    for (const skill of gap.uncovered_skills) {
      expect(gap.missing_skills).toContain(skill);
      expect(gap.courses.flatMap((c: any) => c.matched_skills)).not.toContain(skill);
    }
  });
}

test('saved CV analysis remains private between candidates', async () => {
  expect(cvIds.backend).toBeTruthy();
  await get('frontend', `/api/rag/analyses/${encodeURIComponent(cvIds.backend)}`, 404);
});

test('a missing SQL skill recommends an accessible real course and class', async () => {
  test.skip(!courseFixture, 'Create fixtures/application_suggestion_course.exs in local Docker.');
  const page = await get('frontend', '/api/jobs?q=CV%20Demo&page_size=50');
  const job = page.data.find((item: any) => item.requirements.includes('SQL'));
  expect(job).toBeTruthy();
  const gap = (await get('frontend', `/api/jobs/${job.id}/application-suggestions`)).data;
  expect(gap.missing_skills).toContain('SQL');
  const course = gap.courses.find((item: any) => item.id === courseFixture.course_id);
  expect(course).toBeTruthy();
  expect(course.class_id).toBe(courseFixture.class_id);
  expect(course.class_count).toBe(1);
  expect(course.price_cents).toBe(2500);
  expect(course.matched_skills).toContain('SQL');
  const detail = (await get('frontend', `/api/catalog/courses/${course.id}`)).data;
  expect(detail.classes.map((item: any) => item.id)).toContain(course.class_id);
  expect(detail.classes[0].enrolled).toBe(false);
});

test('draft and expired listings cannot produce application suggestions', async () => {
  const page = await get('employer', '/api/jobs?scope=manage&q=CV%20Demo&page_size=50');
  for (const status of ['draft', 'expired']) {
    const job = page.data.find((item: any) => item.status === status);
    expect(job).toBeTruthy();
    await get('backend', `/api/jobs/${job.id}/application-suggestions`, 404);
    await get('employer', `/api/jobs/${job.id}/application-suggestions`, 409);
  }
});
