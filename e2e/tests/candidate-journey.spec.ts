import {test, expect, Page, Locator} from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

// Explicit, isolated fixtures: fixtures/candidate_journey.exs. Local Docker only.
const manifest = process.env.CANDIDATE_JOURNEY_FIXTURE;
const f = manifest ? JSON.parse(fs.readFileSync(manifest, 'utf8')) : null;
const app = process.env.BASE_URL ?? 'http://localhost:8081';
const api = process.env.API_BASE_URL ?? 'http://localhost:4000';
test.skip(!f, 'Requires the explicitly created local candidate journey fixture.');
test.describe.configure({mode: 'default', timeout: 180_000});
test.use({viewport: {width: 1440, height: 1000}, launchOptions: {
  executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE,
}, actionTimeout: 15000});
test.afterEach(async ({page}, info) => {
  if (info.status !== info.expectedStatus) await screen(page, 'failure');
});

async function frames(p: Page) {
  await p.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));
}
async function semantics(p: Page) {
  if (!await p.locator('flt-semantics').count()) {
    await p.locator('flt-semantics-placeholder').waitFor({state: 'attached'});
    await p.locator('flt-semantics-placeholder').evaluate((el: HTMLElement) => el.click());
  }
  await frames(p);
}
async function reveal(p: Page, loc: Locator) {
  for (let i = 0; i < 18; i++) {
    if (await loc.count() && await loc.first().isVisible()) return;
    await p.mouse.wheel(0, 360); await frames(p);
  }
  await loc.first().waitFor({state: 'visible'});
}
async function click(p: Page, loc: Locator) {await reveal(p, loc); await loc.first().click(); await frames(p);}
async function fill(p: Page, loc: Locator, value: string) {
  await click(p, loc); await loc.first().press('ControlOrMeta+A');
  await loc.first().press('Backspace'); await loc.first().pressSequentially(value, {delay: 8});
  await expect(loc.first()).toHaveValue(value); await loc.first().press('Tab'); await frames(p);
}
async function screen(p: Page, name: string) {
  fs.mkdirSync('test-results/candidate-journey', {recursive: true});
  await p.screenshot({path: `test-results/candidate-journey/${name}.png`});
  fs.writeFileSync(`test-results/candidate-journey/${name}.txt`, await p.locator('flt-semantics').first().innerText());
}

test('guest → login → real PDF → review → course → corrected profile → application → hiring/chat', async ({page, request}) => {
  expect(['localhost', '127.0.0.1']).toContain(new URL(api).hostname);
  const errors: string[] = []; page.on('pageerror', e => errors.push(e.message));
  const job = `${app}/#/jobs/${f.published_job_id}`;
  await page.goto(job); await semantics(page);
  await click(page, page.getByRole('button', {name: 'Sign in to apply', exact: true}));
  await fill(page, page.getByRole('textbox').nth(0), f.candidate.email);
  await fill(page, page.getByRole('textbox').nth(1), f.candidate.password);
  await click(page, page.getByRole('button', {name: 'Log in', exact: true}));
  await expect(page.getByText(/^Profile to share/)).toBeVisible();
  await screen(page, '01-login-return-to-apply');

  await click(page, page.getByRole('button', {name: 'Edit CV profile & skills', exact: true}));
  await click(page, page.getByRole('button', {name: 'Upload or update matching CV', exact: true}));
  await expect(page.getByText(/^(Your CV is ready|Find the jobs that fit your CV)$/)).toBeVisible();
  if (await page.getByRole('button', {name: 'Change CV', exact: true}).count()) {
    await click(page, page.getByRole('button', {name: 'Change CV', exact: true}));
  }
  await click(page, page.getByRole('checkbox', {name: /I agree to process my CV/}));
  const chooser = page.waitForEvent('filechooser');
  await click(page, page.getByRole('button', {name: 'Upload PDF CV', exact: true}));
  await (await chooser).setFiles(path.resolve('../apps/josjob_web/priv/static/assets/demo-cvs/backend.pdf'));
  const skills = page.getByRole('textbox', {name: /^Review your skills/});
  await reveal(page, skills);
  await fill(page, skills, 'Elixir, PostgreSQL');
  const analyzed = page.waitForResponse(r => new URL(r.url()).pathname === '/api/rag/analyses' && r.request().method() === 'POST');
  await click(page, page.getByRole('button', {name: 'Use this CV for job listings', exact: true}));
  expect((await analyzed).status()).toBe(200);
  await expect(page.getByText('Your CV is ready', {exact: true})).toBeVisible();
  await screen(page, '02-reviewed-real-pdf');
  await click(page, page.getByRole('button', {name: /^Back(?: Back)?$/}));
  await expect(page.getByText('Review your CV profile', {exact: true})).toBeVisible();
  await expect(page.getByText('Explore jobs', {exact: true})).toHaveCount(0);
  await expect(page.getByRole('button', {name: /^Back(?: Back)?$/})).toHaveCount(1);
  await click(page, page.getByRole('button', {name: /^Back(?: Back)?$/}));
  await expect(page.getByText('These required skills were not found in your CV:', {exact: true})).toBeVisible();

  const cover = page.getByRole('textbox', {name: /^Cover letter/});
  const draft = 'Synthetic journey application. My draft survives opening a course and reloading.';
  await fill(page, cover, draft);
  await page.mouse.wheel(0, -1200); await frames(page);
  await click(page, page.getByRole('button', {name: 'View course & classes', exact: true}).first());
  const enrol = page.getByRole('button', {name: 'Enrol', exact: true});
  await expect(page.getByRole('heading', {name: 'Sessions', exact: true})).toBeVisible();
  if (await enrol.count()) await click(page, enrol);
  await expect(page.getByRole('button', {name: 'Leave class', exact: true})).toBeVisible();
  const handout = page.getByRole('button', {name: 'Practice handout [synthetic QA]', exact: true});
  await expect(handout).toBeVisible();
  const handoutTab = page.waitForEvent('popup');
  await click(page, handout);
  const opened = await handoutTab;
  await expect(opened).toHaveURL(`${api}/assets/demo-cvs/backend.pdf`);
  await opened.close();
  await screen(page, '03-class-enrolled');
  await click(page, page.getByRole('button', {name: 'Back to application', exact: true}));
  await click(page, cover); await expect(cover).toHaveValue(draft);
  await page.reload(); await semantics(page); await click(page, cover); await expect(cover).toHaveValue(draft);

  await page.mouse.wheel(0, -1800); await frames(page);
  await click(page, page.getByRole('button', {name: 'Edit CV profile & skills', exact: true}));
  await click(page, page.getByRole('button', {name: 'Edit CV details', exact: true}));
  await fill(page, page.getByRole('textbox', {name: /^Skills/}), 'Elixir, PostgreSQL, Docker');
  await click(page, page.getByRole('button', {name: 'Save CV details', exact: true}));
  await click(page, page.getByRole('button', {name: /^Back(?: Back)?$/}));
  await expect(page.getByText('All listed skill requirements were found. You are ready to apply.', {exact: true})).toBeVisible();
  await page.setViewportSize({width: 390, height: 844});
  await click(page, cover); await expect(cover).toHaveValue(draft); await screen(page, '04-mobile-apply');
  await click(page, page.getByRole('checkbox', {name: /Share this profile/}));
  const submitted = page.waitForResponse(r => r.request().method() === 'POST' && new URL(r.url()).pathname === `/api/jobs/${f.published_job_id}/applications`);
  await click(page, page.getByRole('button', {name: 'Submit application', exact: true}));
  const response = await submitted; expect(response.status()).toBe(201);
  const application = (await response.json()).data;
  expect(application.profile.skills).toContain('Docker'); expect(application.cover_letter).toBe(draft);
  await expect(page.getByText('Application details', {exact: true})).toBeVisible();
  await screen(page, '05-submitted');

  const auth = await request.post(`${api}/api/auth/login`, {data: f.owner});
  expect(auth.status()).toBe(200); const token = (await auth.json()).token;
  const moved = await request.patch(`${api}/api/applications/${application.id}`, {headers: {authorization: `Bearer ${token}`}, data: {
    status: 'reviewing', expected_status: 'applied', note: 'We are reviewing your synthetic application.',
  }});
  expect(moved.status()).toBe(200);
  await click(page, page.getByRole('button', {name: 'Refresh application', exact: true}));
  await expect(page.getByText('Reviewing', {exact: true})).toBeVisible();
  await click(page, page.getByRole('button', {name: 'Open chat', exact: true}));
  await expect(page.getByText('Hiring conversation', {exact: true})).toBeVisible();
  await fill(page, page.getByRole('textbox').last(), 'Candidate journey confirms receipt.');
  const sent = page.waitForResponse(r => r.request().method() === 'POST' && r.url().includes('/chats/application/'));
  await click(page, page.getByRole('button', {name: /Send message/}));
  expect((await sent).status()).toBe(201);
  await screen(page, '06-hiring-chat');
  await page.goto(job); await semantics(page);
  await expect(page.getByRole('button', {name: 'View my application', exact: true})).toBeVisible();
  await page.setViewportSize({width: 1440, height: 1000});
  await page.goto(`${app}/#/dashboard?view=learn&tab=my-courses`); await semantics(page);
  await click(page, page.getByRole('button', {name: 'Open course and classes', exact: true}));
  await expect(page.getByRole('button', {name: 'Practice handout [synthetic QA]', exact: true})).toBeVisible();
  await click(page, page.getByRole('button', {name: 'Leave class', exact: true}));
  await expect(page.getByText('Leave this class?', {exact: true})).toBeVisible();
  await click(page, page.getByRole('button', {name: 'Keep enrollment', exact: true}));
  await screen(page, '08-my-courses-materials');
  expect(errors).toEqual([]);
});

test('new personal account can register and skip optional onboarding to browse jobs', async ({page}) => {
  await page.goto(`${app}/#/register`); await semantics(page);
  await click(page, page.getByRole('button', {name: /^Personal/}).first());
  await click(page, page.getByRole('button', {name: 'Continue', exact: true}));
  await fill(page, page.getByRole('textbox', {name: /^Full name/}), 'Registration Journey QA');
  await fill(page, page.getByRole('textbox', {name: /^Email/}), f.registration_email);
  await fill(page, page.getByRole('textbox', {name: /^Password/}), 'local-journey-password-123');
  await click(page, page.getByRole('checkbox').first());
  await click(page, page.getByRole('button', {name: 'Create account', exact: true}));
  await click(page, page.getByRole('button', {name: /^Student \/ Graduate/}));
  await click(page, page.getByRole('button', {name: /^Continue/}));
  await click(page, page.getByRole('button', {name: /Skip onboarding/}));
  await click(page, page.getByRole('button', {name: 'Skip for now', exact: true}));
  await page.goto(`${app}/#/jobs`); await semantics(page);
  await expect(page.getByRole('textbox').first()).toBeVisible();
  await screen(page, '07-new-account-jobs');
});
