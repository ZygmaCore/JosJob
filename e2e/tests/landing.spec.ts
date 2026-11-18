import {test, expect, Page, Locator} from '@playwright/test';

const appUrl = process.env.BASE_URL ?? 'http://localhost:8081';
test.use({launchOptions: {executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE}});

async function frames(page: Page) {
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
}
async function semantics(page:Page) {
  if(await page.locator('flt-semantics').count()) return;
  await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
  await page.locator('flt-semantics-placeholder').evaluate((element:HTMLElement)=>element.click());
}
async function open(page: Page, path = '') {
  await page.goto(appUrl + path);
  await semantics(page);
  await expect(page.getByRole('button', {name:'Start your journey', exact:true})).toBeVisible();
}
async function reveal(page: Page, locator: Locator) {
  for(let i=0;i<20;i++) {
    if(await locator.count() && await locator.first().isVisible()) return;
    const size=page.viewportSize()!;await page.mouse.move(size.width/2,size.height/2);
    await page.mouse.wheel(0,400); await frames(page);
  }
  await expect(locator.first()).toBeVisible();
}

for(const width of [320,768,1440]) {
  test(`landing layout and primary actions at ${width}px`, async({page}) => {
    const errors: string[]=[];page.on('pageerror', e=>errors.push(e.message));
    await page.setViewportSize({width,height:1000});
    await open(page);
    await expect(page.getByRole('button', {name:'Log in',exact:true})).toBeVisible();
    await page.screenshot({path:test.info().outputPath(`landing-${width}.png`)});
    await page.getByRole('button', {name:'Start your journey',exact:true}).click();
    await expect(page).toHaveURL(/#\/register$/);
    await expect(page.getByRole('button',{name:'Continue',exact:true})).toBeVisible();
    expect(errors).toEqual([]);
  });
}

test('guest job action opens published vacancies without authentication', async({page}) => {
  await open(page);
  const result=page.waitForResponse(response=>new URL(response.url()).pathname==='/api/jobs');
  await page.getByRole('button',{name:'Explore jobs',exact:true}).first().click();
  expect((await result).status()).toBe(200);
  await expect(page).toHaveURL(/#\/jobs$/);
  await expect(page.getByRole('textbox').first()).toBeVisible();
});

test('hero searches jobs with the complete entered keyword', async({page}) => {
  await open(page, '/#/welcome');
  const search=page.getByRole('textbox').first();
  const query='Frontend & UX';
  await search.click();await frames(page);
  await search.pressSequentially(query,{delay:20});await frames(page);
  const result=page.waitForResponse(response=>new URL(response.url()).pathname==='/api/jobs');
  await search.press('Enter');
  const response=await result;
  expect(response.status()).toBe(200);
  expect(new URL(response.url()).searchParams.get('q')).toBe(query);
  await expect(page).toHaveURL(/#\/jobs\?q=/);
  expect(new URL(page.url().split('#')[1],'http://localhost').searchParams.get('q')).toBe(query);
  const reloaded=page.waitForResponse(response=>new URL(response.url()).pathname==='/api/jobs');
  await page.reload();
  expect(new URL((await reloaded).url()).searchParams.get('q')).toBe(query);
});

test('empty hero search opens the public job list and welcome reloads', async({page}) => {
  await open(page, '/#/welcome');
  await page.reload();
  await semantics(page);
  await page.getByRole('button',{name:'Search jobs',exact:true}).click();
  await expect(page).toHaveURL(/#\/jobs$/);
  await expect(page.getByRole('textbox').first()).toBeVisible();
});

for(const width of [320,1440]) {
  test(`product tour switches between all three products at ${width}px`,async({page})=>{
    const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
    await page.setViewportSize({width,height:1000});await open(page,'/#/welcome');
    const learning=page.getByRole('checkbox',{name:'Learning',exact:true});
    await reveal(page,learning);await learning.click();
    await expect(learning).toBeChecked();
    await expect(page.getByRole('img',{name:/Illustrative learning preview/})).toBeVisible();
    const coaching=page.getByRole('checkbox',{name:'Coaching',exact:true});await coaching.click();
    await expect(coaching).toBeChecked();
    await expect(page.getByRole('img',{name:/Illustrative coaching preview/})).toBeVisible();
    await page.getByRole('checkbox',{name:'Jobs',exact:true}).click();
    await expect(page.getByRole('img',{name:/Illustrative jobs preview/})).toBeVisible();
    await learning.click();
    const courses=page.getByRole('button',{name:'Explore available courses',exact:true});await reveal(page,courses);await courses.click();
    await expect(page).toHaveURL(/#\/login$/);
    expect(errors).toEqual([]);
  });
}

test('signed-in users can preview welcome and return to their workspace',async({page})=>{
  test.skip(!process.env.LANDING_TEST_EMAIL || !process.env.LANDING_TEST_PASSWORD,'Provide a local demo account to verify signed-in access.');
  await open(page);await page.getByRole('button',{name:'Log in',exact:true}).click();
  for(const [index,value] of [process.env.LANDING_TEST_EMAIL!,process.env.LANDING_TEST_PASSWORD!].entries()) {
    const input=page.getByRole('textbox').nth(index);await input.click();await frames(page);await input.pressSequentially(value,{delay:20});await frames(page);await input.press('Tab');
  }
  await page.getByRole('button',{name:'Log in',exact:true}).click();
  await page.getByRole('button',{name:'Go to dashboard',exact:true}).click();
  await page.goto(appUrl+'/#/welcome');
  await semantics(page);
  await expect(page.getByRole('button',{name:'Start your journey',exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Dashboard',exact:true}).click();
  await expect(page).toHaveURL(/#\/dashboard$/);
});

test('mobile menu navigates to an accessible FAQ and closes', async({page}) => {
  await page.setViewportSize({width:390,height:844});await open(page);
  await page.getByRole('button',{name:'Open menu',exact:true}).click();
  await page.getByRole('button',{name:'FAQ',exact:true}).first().click();
  const question=page.getByRole('button',{name:'Do I need an account to browse jobs?',exact:true});
  await expect(question).toBeVisible();
  await expect(page.getByRole('button',{name:'Close menu',exact:true})).toHaveCount(0);
  await question.focus();await frames(page);await page.keyboard.press('Enter');
  await expect(question).toHaveAttribute('aria-expanded','true');
  await expect(page.getByText(/No\. You can browse active job listings/)).toBeVisible();
  await page.getByRole('button',{name:'Log in',exact:true}).click();
  await expect(page).toHaveURL(/#\/login$/);
});

test('desktop anchors, FAQ and closing CTA work with reduced motion', async({page}) => {
  await page.setViewportSize({width:1440,height:1000});await page.emulateMedia({reducedMotion:'reduce'});await open(page);
  await page.getByRole('button',{name:'How it works',exact:true}).click();
  await expect(page.getByText('You don’t need it all figured out.',{exact:true})).toBeVisible();
  await page.getByRole('button',{name:'FAQ',exact:true}).first().click();
  const question=page.getByRole('button',{name:'Can I use AI CV matching now?',exact:true});
  await question.click();await expect(question).toHaveAttribute('aria-expanded','true');
  await expect(page.getByText(/AI CV extraction, ranked match scores and skill-gap explanations are planned/)).toBeVisible();
  const create=page.getByRole('button',{name:'Create your account',exact:true});await reveal(page,create);await create.click();
  await expect(page).toHaveURL(/#\/register$/);
});

test('headline loops without a pause control and keeps its accessible name',async({page})=>{
  await open(page,'/#/welcome');
  const heading=page.getByRole('heading',{name:'Big ambitions. Clear next steps.',exact:true});
  await expect(heading).toHaveCount(1);
  await heading.hover();
  await expect(page.getByRole('button',{name:/headline animation/})).toHaveCount(0);
  await expect(heading).toHaveCount(1);
});

test('headline stays still when the browser requests reduced motion',async({page})=>{
  await page.emulateMedia({reducedMotion:'reduce'});await open(page,'/#/welcome');
  await expect(page.getByRole('heading',{name:'Big ambitions. Clear next steps.',exact:true})).toBeVisible();
  await expect(page.getByRole('button',{name:/headline animation/})).toHaveCount(0);
});
