
import {createClient} from '@supabase/supabase-js';
const supabaseUrl=import.meta.env.VITE_SUPABASE_URL||'https://wimethopqfbzbwvgiqet.supabase.co';
const publishableKey=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY||'sb_publishable_Y4MlIlHWGFeLQv6LwMDkLg_F3dA7kmR';
export const db=createClient(supabaseUrl,publishableKey);
export async function loginProviders(signal){
 const response=await fetch(supabaseUrl+'/auth/v1/settings',{headers:{apikey:publishableKey},signal});
 if(!response.ok)throw Error('Services de connexion indisponibles.');
 const settings=await response.json();
 return ['google','facebook'].filter(provider=>settings.external?.[provider]===true);
}
export const rootUrl=()=>new URL(import.meta.env.BASE_URL,location.origin).href;
export function errorMessage(e){
 if(e?.code==='23503')return 'Cet élément est lié à un autre enregistrement. Vérifiez les références avant de le modifier ou supprimer.';
 if(e?.code==='23505')return 'Ce nom ou cette référence existe déjà dans votre espace.';
 if(e?.code==='23514'||e?.code==='22P02')return 'Vérifiez les valeurs saisies.';
 if(e?.message?.includes('Invalid login credentials'))return 'Adresse e-mail ou mot de passe incorrect.';
 if(e?.message?.includes('Email not confirmed'))return 'Confirmez votre adresse e-mail avant de vous connecter.';
 if(e?.message?.includes('Failed to fetch'))return 'Connexion impossible. Vérifiez votre réseau puis réessayez.';
 return e?.message||'Une erreur est survenue. Réessayez.';
}
export async function rpc(name,args){const {data,error}=await db.rpc(name,args);if(error)throw error;return data;}
export async function table(name,workspace,signal){let all=[];for(let offset=0;;offset+=500){let q=db.from(name).select('*').eq('workspace_id',workspace).order('id').range(offset,offset+499);if(signal)q=q.abortSignal(signal);const {data,error}=await q;if(error)throw error;all.push(...data);if(data.length<500)return all;}}
export async function spaces(user){const [{data,error},{data:members,error:err}]=await Promise.all([db.from('sp_workspaces').select('*').order('created_at'),db.from('sp_members').select('*').eq('user_id',user)]);if(error||err)throw error||err;return data.map(w=>({...w,role:members.find(m=>m.workspace_id===w.id)?.role}));}
