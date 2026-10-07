
import {test,expect} from '@playwright/test';
const userId='11111111-1111-4111-8111-111111111111',workspaceId='22222222-2222-4222-8222-222222222222';
async function login(page,role='owner'){
 const basins=[],writes=[];
 await page.route('https://**/*',route=>route.abort());
 await page.route('**/auth/v1/token?**',route=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({access_token:'test-access-token',refresh_token:'test-refresh-token',token_type:'bearer',expires_in:3600,user:{id:userId,email:'owner@example.com',aud:'authenticated',role:'authenticated',email_confirmed_at:'2026-10-07T10:00:00Z'}})}));
 await page.route('**/rest/v1/**',async route=>{const req=route.request(),path=new URL(req.url()).pathname;let body=[];
 if(path.endsWith('/sp_workspaces'))body=[{id:workspaceId,name:'Ferme de test',currency:'EUR',version:1}];
 if(path.endsWith('/sp_members'))body=[{workspace_id:workspaceId,user_id:userId,role}];
 if(path.endsWith('/sp_basins'))body=basins;
 if(path.endsWith('/rpc/sp_save_record')){const payload=req.postDataJSON();writes.push(payload);const record={...payload.p_record,id:'33333333-3333-4333-8333-333333333333',workspace_id:workspaceId,version:1};basins.push(record);body=record;}
 await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
 });
 await page.goto('./');await page.getByLabel('Adresse e-mail').fill('owner@example.com');await page.getByLabel('Mot de passe',{exact:true}).fill('test-password-long');
 await page.getByRole('button',{name:'Se connecter',exact:true}).click();await expect(page.getByRole('heading',{name:'Vue d’ensemble',exact:true})).toBeVisible();await expect(page.getByText('Stock disponible',{exact:true})).toBeVisible();
 return {basins,writes};
}
async function navigate(page,name){const menu=page.getByRole('button',{name:'Ouvrir le menu'});if(await menu.isVisible())await menu.click();await page.getByRole('navigation').getByRole('button',{name,exact:true}).click();}
test('création de bassin par RPC puis affichage du résultat',async({page})=>{const {writes}=await login(page);await navigate(page,'Bassins');await page.getByRole('button',{name:'＋ Ajouter un bassin',exact:true}).click();await page.getByLabel('Nom du bassin').fill('Bassin A');await page.getByLabel('Volume (litres)').fill('1250');await page.getByRole('button',{name:'Enregistrer',exact:true}).click();await expect(page.getByRole('cell',{name:'Bassin A',exact:true})).toBeVisible();expect(writes).toHaveLength(1);expect(writes[0]).toMatchObject({p_workspace:workspaceId,p_kind:'basin',p_expected_version:null,p_record:{name:'Bassin A',volume_l:1250,active:true}});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();});
test('lecteur sans actions d’écriture',async({page})=>{await login(page,'viewer');await navigate(page,'Bassins');await expect(page.getByRole('button',{name:'＋ Ajouter un bassin',exact:true})).toHaveCount(0);await expect(page.getByRole('button',{name:'Historique',exact:true})).toHaveCount(0);});
test('commande impossible sans client et lot libéré',async({page})=>{await login(page);await navigate(page,'Commandes');await page.getByRole('button',{name:'＋ Ajouter une commande',exact:true}).click();await expect(page.getByRole('alert')).toContainText('Ajoutez un client');await expect(page.getByRole('button',{name:'Enregistrer',exact:true})).toBeDisabled();});
