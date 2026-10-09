
import {test,expect} from '@playwright/test';
test.beforeEach(async({page})=>{await page.route('https://**/*',r=>r.abort());});
async function providers(page,external){await page.route('**/auth/v1/settings',r=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify({external})}));}
test('propose uniquement les fournisseurs activés',async({page})=>{await providers(page,{google:true,facebook:false});await page.goto('./');await expect(page.getByRole('button',{name:'Continuer avec Google'})).toBeVisible();await expect(page.getByRole('button',{name:'Continuer avec Facebook'})).toHaveCount(0);await page.getByRole('button',{name:'Créer un compte',exact:true}).click();await expect(page.getByRole('button',{name:'Continuer avec Google'})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();});
for(const [provider,label] of [['google','Google'],['facebook','Facebook']]){
test('redirige vers '+label+' avec le bon retour',async({page,baseURL})=>{
 await providers(page,{google:true,facebook:true});
 await page.route('**/auth/v1/authorize?**',r=>r.fulfill({status:200,contentType:'text/html',body:'<h1>Connexion fournisseur</h1>'}));
 await page.goto('./');const pending=page.waitForRequest(r=>r.url().includes('/auth/v1/authorize?'));
 await page.getByRole('button',{name:'Continuer avec '+label}).click();const url=new URL((await pending).url());
 expect(url.searchParams.get('provider')).toBe(provider);expect(url.searchParams.get('redirect_to')).toBe(baseURL);
 if(provider==='facebook')expect(url.searchParams.get('scopes')).toBe('email');
 await expect(page.getByRole('heading',{name:'Connexion fournisseur'})).toBeVisible();
});}
test('e-mail utilisable pendant une panne des fournisseurs',async({page})=>{await page.route('**/auth/v1/settings',r=>r.fulfill({status:503,body:'Unavailable'}));await page.goto('./');await expect(page.getByRole('button',{name:'Se connecter',exact:true})).toBeEnabled();await expect(page.getByRole('button',{name:'Continuer avec Google'})).toHaveCount(0);});
test('annulation OAuth lisible',async({page})=>{await providers(page,{google:true,facebook:true});await page.goto('./#error=access_denied&error_description=User+cancelled');await expect(page.getByRole('alert')).toContainText('Connexion annulée');await expect(page.getByRole('button',{name:'Se connecter',exact:true})).toBeEnabled();await expect(page).not.toHaveURL(/error_description/);});
test('conserve le code d’invitation',async({page})=>{await providers(page,{google:true});const token='a'.repeat(64);await page.goto('./#invite='+token);await expect(page.getByRole('button',{name:'Continuer avec Google'})).toBeVisible();expect(await page.evaluate(()=>sessionStorage.getItem('sp.invite'))).toBe(token);});
test('minimum de huit caractères',async({page})=>{await providers(page,{});await page.goto('./');await page.getByRole('button',{name:'Créer un compte',exact:true}).click();const password=page.getByLabel('Mot de passe',{exact:true});await expect(password).toHaveAttribute('minlength','8');await password.fill('Abcd123');expect(await password.evaluate(el=>el.validity.tooShort)).toBeTruthy();await password.fill('Abcd1234');expect(await password.evaluate(el=>el.validity.tooShort)).toBeFalsy();});
