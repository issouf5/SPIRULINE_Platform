
import React,{useEffect,useState} from 'react';
import {db,rpc,spaces,errorMessage,rootUrl} from './api.js';
import {Field,Notice} from './ui.jsx';
import Platform from './Platform.jsx';
function Auth({recovery,onRecovered}){
 const [mode,setMode]=useState(recovery?'recovery':'login'),[busy,setBusy]=useState(false),[error,setError]=useState(''),[info,setInfo]=useState('');
 async function submit(e){e.preventDefault();const form=new FormData(e.currentTarget);setBusy(true);setError('');setInfo('');try{
 const email=String(form.get('email')||'').trim(),password=String(form.get('password')||'');let result;
 if(mode==='login')result=await db.auth.signInWithPassword({email,password});
 if(mode==='signup'){result=await db.auth.signUp({email,password,options:{emailRedirectTo:rootUrl()}});if(!result.error&&!result.data.session)setInfo('Consultez votre messagerie pour confirmer votre adresse, puis connectez-vous.');}
 if(mode==='forgot'){result=await db.auth.resetPasswordForEmail(email,{redirectTo:rootUrl()});if(!result.error)setInfo('Si un compte correspond à cette adresse, les instructions ont été envoyées.');}
 if(mode==='recovery'){result=await db.auth.updateUser({password});if(!result.error)onRecovered();}
 if(result?.error)throw result.error;
 }catch(err){setError(errorMessage(err));}finally{setBusy(false);}}
 const change=m=>{setMode(m);setError('');setInfo('');};
 return <div className="auth"><section className="auth-intro"><div className="brand"><b className="symbol">S</b><div>SPIRULINE<small>PLATFORM</small></div></div><div><p className="eyebrow">DE LA CULTURE À LA COMMANDE</p><h1>Votre production.<br/>Votre équipe.<br/><em>Un seul espace.</em></h1><p>Suivez chaque lot, gardez un stock fiable et travaillez ensemble, où que vous soyez.</p><div className="pills"><span>Production</span><span>Traçabilité</span><span>Ventes</span></div></div><small>La gestion quotidienne des producteurs de spiruline.</small></section><section className="auth-content"><form className="auth-card" onSubmit={submit}><p className="eyebrow">BIENVENUE SUR SPIRULINE</p><h2>{{login:'Retrouvez votre espace',signup:'Créez votre compte',forgot:'Mot de passe oublié ?',recovery:'Nouveau mot de passe'}[mode]}</h2><p className="muted">Votre entreprise, vos données et votre équipe.</p><Notice>{error}</Notice><Notice success>{info}</Notice>{mode!=='recovery'&&<Field label="Adresse e-mail" name="email" type="email" required autoComplete="email" maxLength={200}/>}
 {mode!=='forgot'&&<Field label="Mot de passe" name="password" type="password" required minLength={mode==='login'?1:12} autoComplete={mode==='login'?'current-password':'new-password'}/>}
 {['signup','recovery'].includes(mode)&&<small>Au moins 12 caractères.</small>}
 <button className="primary full" disabled={busy}>{busy?'Veuillez patienter…':{login:'Se connecter',signup:'Créer mon compte',forgot:'Recevoir les instructions',recovery:'Enregistrer le mot de passe'}[mode]}</button>
 {!recovery&&<div className="auth-links">{mode==='login'?<><button type="button" className="quiet" onClick={()=>change('forgot')}>Mot de passe oublié</button><button type="button" className="quiet" onClick={()=>change('signup')}>Créer un compte</button></>:<button type="button" className="quiet" onClick={()=>change('login')}>Retour à la connexion</button>}</div>}</form></section></div>;
}
function Onboarding({invite,reload,cancel}){
 const [mode,setMode]=useState(invite?'join':'create'),[busy,setBusy]=useState(false),[error,setError]=useState('');
 return <main className="center"><div className="auth-card"><p className="eyebrow">SPIRULINE PLATFORM</p><h1>Votre espace de travail</h1><p>Créez votre entreprise ou rejoignez votre équipe.</p><div className="tabs"><button onClick={()=>setMode('create')} aria-pressed={mode==='create'}>Créer un espace</button><button onClick={()=>setMode('join')} aria-pressed={mode==='join'}>Rejoindre une équipe</button></div><Notice>{error}</Notice><form onSubmit={async e=>{e.preventDefault();const v=new FormData(e.currentTarget);setBusy(true);setError('');try{const id=await rpc(mode==='create'?'sp_create_workspace':'sp_accept_invitation',mode==='create'?{p_name:v.get('name'),p_currency:v.get('currency')}:{p_token:String(v.get('token')).trim()});sessionStorage.removeItem('sp.invite');await reload(id);}catch(err){setError(errorMessage(err));}finally{setBusy(false);}}}>
 {mode==='create'?<><Field label="Nom de l’entreprise" name="name" required maxLength={120}/><Field label="Devise"><select name="currency"><option value="EUR">Euro — EUR</option><option value="XOF">Franc CFA — XOF</option></select></Field></>:<Field label="Code d’invitation" name="token" required pattern="[0-9a-f]{64}" defaultValue={invite} maxLength={64}/>}
 <button disabled={busy} className="primary full">{busy?'En cours…':mode==='create'?'Créer mon espace':'Rejoindre cette équipe'}</button></form>{cancel&&<button className="quiet" onClick={cancel}>Retour à mon espace</button>}<button className="quiet" onClick={()=>db.auth.signOut({scope:'local'})}>Se déconnecter</button></div></main>;
}
function WorkspaceApp({user}){
 const [list,setList]=useState(null),[selected,setSelected]=useState(''),[error,setError]=useState(''),[adding,setAdding]=useState(false),[invite,setInvite]=useState(()=>sessionStorage.getItem('sp.invite')||'');
 const choose=(data,preferred)=>{setList(data);const id=data.some(w=>w.id===preferred)?preferred:data[0]?.id||'';setSelected(id);if(id)localStorage.setItem('sp.workspace.'+user.id,id);};
 const reload=async id=>{const data=await spaces(user.id);choose(data,id||selected||localStorage.getItem('sp.workspace.'+user.id));setError('');setAdding(false);setInvite('');};
 useEffect(()=>{let alive=true;spaces(user.id).then(data=>{if(alive)choose(data,localStorage.getItem('sp.workspace.'+user.id));}).catch(e=>alive&&setError(errorMessage(e)));return()=>{alive=false;};},[user.id]);
 if(error)return <main className="center"><Notice>{error}</Notice><button onClick={()=>reload().catch(e=>setError(errorMessage(e)))}>Réessayer</button><button onClick={()=>db.auth.signOut({scope:'local'})}>Se déconnecter</button></main>;
 if(!list)return <main className="center" role="status">Chargement de vos espaces…</main>;
 if(!list.length||adding||invite)return <Onboarding invite={invite} reload={reload} cancel={list.length?()=>{setAdding(false);setInvite('');sessionStorage.removeItem('sp.invite');}:null}/>;
 const workspace=list.find(w=>w.id===selected);
 return <Platform key={workspace.id} workspace={workspace} user={user} spaces={list} onSelect={id=>{setSelected(id);localStorage.setItem('sp.workspace.'+user.id,id);}} onAdd={()=>setAdding(true)} reloadSpaces={reload}/>;
}
export default function App(){
 const [session,setSession]=useState(null),[ready,setReady]=useState(false),[recovery,setRecovery]=useState(false),[error,setError]=useState('');
 useEffect(()=>{const invite=new URLSearchParams(location.hash.slice(1)).get('invite');if(invite&&/^[0-9a-f]{64}$/.test(invite)){sessionStorage.setItem('sp.invite',invite);history.replaceState(null,'',location.pathname+location.search);}
 let alive=true;db.auth.getSession().then(({data,error})=>{if(!alive)return;if(error)setError(errorMessage(error));setSession(data.session);setReady(true);}).catch(e=>{if(alive){setError(errorMessage(e));setReady(true);}});
 const {data:{subscription}}=db.auth.onAuthStateChange((event,s)=>{if(!alive)return;setSession(s);setReady(true);if(event==='PASSWORD_RECOVERY')setRecovery(true);if(event==='SIGNED_OUT')setRecovery(false);});
 return()=>{alive=false;subscription.unsubscribe();};},[]);
 if(!ready)return <main className="center" role="status">Ouverture de SPIRULINE…</main>;
 return <><Notice>{error}</Notice>{!session||recovery?<Auth key={recovery?'recovery':'login'} recovery={recovery} onRecovered={()=>setRecovery(false)}/>:<WorkspaceApp key={session.user.id} user={session.user}/>}</>;
}
