
import React,{useEffect,useState} from 'react';
import {db,loginProviders,rootUrl,errorMessage} from './api.js';
import './social-login.css';
export default function SocialLogin({busy,setBusy,onError}){
 const [providers,setProviders]=useState([]),[pending,setPending]=useState('');
 useEffect(()=>{
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),5000);
  loginProviders(controller.signal).then(enabled=>{if(!controller.signal.aborted)setProviders(enabled);}).catch(()=>{}).finally(()=>clearTimeout(timer));
  const reset=()=>{setPending('');setBusy(false);};window.addEventListener('pageshow',reset);
  return()=>{controller.abort();clearTimeout(timer);window.removeEventListener('pageshow',reset);};
 },[setBusy]);
 async function login(provider){
  if(busy)return;setPending(provider);setBusy(true);onError('');
  try{
   const {data,error}=await db.auth.signInWithOAuth({provider,options:{redirectTo:rootUrl(),skipBrowserRedirect:true,...(provider==='facebook'?{scopes:'email'}:{})}});
   if(error)throw error;
   if(!data?.url)throw Error('Ce service est temporairement indisponible.');
   window.location.assign(data.url);
  }catch(error){onError(errorMessage(error));setPending('');setBusy(false);}
 }
 if(!providers.length)return null;
 return <><div className="social-login">{providers.map(provider=><button key={provider} className={'social-button '+provider} type="button" disabled={busy} onClick={()=>login(provider)}><span aria-hidden="true" className="social-symbol">{provider==='google'?'G':'f'}</span>{pending===provider?'Redirection…':'Continuer avec '+(provider==='google'?'Google':'Facebook')}</button>)}</div><div className="auth-divider"><span>ou avec votre adresse e-mail</span></div></>;
}
